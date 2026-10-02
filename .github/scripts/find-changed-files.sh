#!/usr/bin/env bash
# Maps changed files to the roots they touch (08 section 2).
#
#   find-changed-files.sh <base> <head>   roots touched by the changes from the merge base of <base> and <head> to <head>
#   find-changed-files.sh --all <ref>     every root on <ref>, for the drift job
#
# Prints a JSON list of { root, key } in the order of 08 section 6. `key` is set
# only for landing-zones/_root. A root that exists neither on <base> nor on
# <head> is left out. Fails when .github/** and a root change together.
set -euo pipefail
# The runner image may lack PyYAML for the system Python.
if [ -n "${GITHUB_ACTIONS:-}" ] && ! python3 -c 'import yaml' 2> /dev/null; then
  python3 -m pip install --quiet --user --break-system-packages pyyaml > /dev/null
fi
exec python3 - "$@" <<'PY'
import json
import subprocess
import sys


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def files_on(ref):
    return set(git("ls-tree", "-r", "--name-only", ref).splitlines())


def read_yaml(ref, path):
    import yaml  # only needed when a catalog or stamp file changed

    try:
        return yaml.safe_load(git("show", f"{ref}:{path}")) or {}
    except subprocess.CalledProcessError:
        return None


def is_root(files, folder):
    prefix = folder + "/"
    return any(f.startswith(prefix) and "/" not in f[len(prefix):] and f.endswith((".tf", ".tofu")) for f in files)


def folders(files, prefix, depth):
    """Folders `depth` levels below `prefix` that hold .tf files."""
    found = set()
    for f in files:
        if f.startswith(prefix) and f.endswith((".tf", ".tofu")):
            parts = f[len(prefix):].split("/")
            if len(parts) == depth + 1:
                found.add(prefix + "/".join(parts[:depth]))
    return found


def landing_zones(files):
    return {f[len("landing-zones/"):-len(".yaml")] for f in files
            if f.startswith("landing-zones/") and f.endswith(".yaml") and f.count("/") == 1}


def stamps_of(files, lz):
    return folders(files, f"stamps/{lz}/", 1)


LAYER_ORDER = ["platform", "landingzones", "stamps", "global"]
ROOT_ORDER = {
    "platform": ["state", "governance", "identity", "management", "connectivity"],
    "global": ["registry", "external-providers", "edge", "github"],
}


def layer(root):
    if root.startswith("landing-zones/"):
        return "landingzones"
    return root.split("/")[0]


def sort_key(item):
    root, key = item
    lyr = layer(root)
    names = ROOT_ORDER.get(lyr, [])
    name = root.split("/")[2] if root.startswith("platform/") and root.count("/") >= 2 else root.split("/")[-1]
    rank = names.index(name) if name in names else len(names)
    if root.startswith("platform/apps/"):
        rank = len(names) + 1
    return (LAYER_ORDER.index(lyr), rank, root, key or "")


def emit(roots):
    out = []
    for root, key in sorted(roots, key=sort_key):
        out.append({"root": root, "key": key} if key else {"root": root})
    print(json.dumps(out))


def all_roots(ref):
    files = files_on(ref)
    roots = set()
    for prefix, depth in [("global/", 1), ("platform/azure/", 1), ("platform/gcp/", 1), ("platform/apps/", 2), ("stamps/", 2)]:
        roots |= {(r, None) for r in folders(files, prefix, depth)}
    if is_root(files, "landing-zones/_root"):
        roots |= {("landing-zones/_root", lz) for lz in landing_zones(files)}
    return roots


def changed_roots(base, head):
    merge_base = git("merge-base", base, head).strip()
    changed = git("diff", "--name-only", "--no-renames", merge_base, head).splitlines()
    base_files, head_files = files_on(merge_base), files_on(head)
    both = base_files | head_files
    roots = set()

    def stamps_by_entries(path, entries_of):
        old, new = entries_of(read_yaml(merge_base, path) or {}), entries_of(read_yaml(head, path) or {})
        return {s for s in old.keys() | new.keys() if old.get(s) != new.get(s)}

    for f in changed:
        parts = f.split("/")
        if parts[0] == "global" and len(parts) > 2:
            roots.add(("/".join(parts[:2]), None))
        elif parts[0] == "platform" and len(parts) > 3 and parts[1] in ("azure", "gcp"):
            roots.add(("/".join(parts[:3]), None))
        elif parts[0] == "platform" and len(parts) > 4 and parts[1] == "apps":
            roots.add(("/".join(parts[:4]), None))
        elif parts[0] == "landing-zones" and len(parts) == 2 and f.endswith(".yaml"):
            lz = parts[1][:-len(".yaml")]
            roots.add(("landing-zones/_root", lz))
            if not lz.startswith("exp-"):
                roots |= {(s, None) for s in stamps_of(both, lz)}
        elif parts[0] == "landing-zones" and parts[1] == "_root":
            roots |= {("landing-zones/_root", lz) for lz in landing_zones(both)}
        elif parts[0] == "stamps" and len(parts) > 3:
            roots.add(("/".join(parts[:3]), None))
            if parts[3] == "stamp.yaml":
                old, new = read_yaml(merge_base, f), read_yaml(head, f)
                pick = lambda d: (d.get("apps"), d.get("app_environment"))
                if old is None or new is None or pick(old) != pick(new):
                    roots.add(("global/github", None))
        elif f == "catalog/tenants.yaml":
            roots.add(("global/edge", None))
            def tenants(doc):
                by_stamp = {}
                for t in doc.get("tenants") or []:
                    by_stamp.setdefault(t.get("stamp"), []).append(json.dumps(t, sort_keys=True))
                return {s: sorted(v) for s, v in by_stamp.items()}
            roots |= {(f"stamps/{s}", None) for s in stamps_by_entries(f, tenants) if s}
        elif f == "catalog/ipam.yaml":
            old, new = read_yaml(merge_base, f) or {}, read_yaml(head, f) or {}
            hubs = lambda d: {h.get("name"): h for h in d.get("hubs") or []}
            lzs = lambda d: {z.get("name"): z for z in d.get("landing_zones") or []}
            for name in hubs(old).keys() | hubs(new).keys():
                o, n = hubs(old).get(name), hubs(new).get(name)
                if o != n:
                    cloud = (n or o).get("cloud", "azure")
                    roots.add((f"platform/{cloud}/connectivity", None))
            for name in lzs(old).keys() | lzs(new).keys():
                o, n = lzs(old).get(name) or {}, lzs(new).get(name) or {}
                if o.get("cidr") != n.get("cidr"):
                    roots.add(("landing-zones/_root", name))
                os_, ns = o.get("stamps") or {}, n.get("stamps") or {}
                roots |= {(f"stamps/{name}/{s}", None) for s in os_.keys() | ns.keys() if os_.get(s) != ns.get(s)}
        elif f == "catalog/regions.yaml":
            old, new = read_yaml(merge_base, f) or {}, read_yaml(head, f) or {}
            regions = lambda d: {(r.get("cloud"), r.get("name")): r for r in d.get("regions") or []}
            clouds = {k[0] for k in regions(old).keys() | regions(new).keys() if regions(old).get(k) != regions(new).get(k)}
            for cloud in clouds:
                roots.add((f"platform/{cloud}/governance", None))
                for lz in landing_zones(both):
                    path = f"landing-zones/{lz}.yaml"
                    doc = read_yaml(head, path) or read_yaml(merge_base, path) or {}
                    if doc.get("cloud") == cloud:
                        roots.add(("landing-zones/_root", lz))
        elif f == "catalog/owners.yaml":
            roots.add(("platform/azure/identity", None))
        elif f == "catalog/repos.yaml":
            roots.add(("global/github", None))
        # policy/**, .github/**, renovate.json and everything else plan no root.

    def exists(item):
        root, key = item
        if not (is_root(base_files, root) or is_root(head_files, root)):
            return False
        return key is None or f"landing-zones/{key}.yaml" in both

    roots = {r for r in roots if exists(r)}
    if roots and any(f.startswith(".github/") for f in changed):
        print("workflow changes go in their own PR", file=sys.stderr)
        sys.exit(1)
    return roots


args = sys.argv[1:]
if len(args) == 2 and args[0] == "--all":
    emit(all_roots(args[1]))
elif len(args) == 2:
    emit(changed_roots(args[0], args[1]))
else:
    print(__doc__ or "usage: find-changed-files.sh <base> <head> | find-changed-files.sh --all <ref>", file=sys.stderr)
    sys.exit(2)
PY

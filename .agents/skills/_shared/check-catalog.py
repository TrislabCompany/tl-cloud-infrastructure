#!/usr/bin/env python3
"""Runs the catalog rules of policy/ on the working tree before a PR, the way
the PR's plan does (.github/workflows/shared-plan.yml, "Run the conftest
checks"): the working tree's catalog/ as data.pr, origin/main's as data.main,
each landing-zones/<lz>.yaml as data.<side>.lz_yaml["<lz>"] and each
stamps/<lz>/<folder>/stamp.yaml as data.<side>.stamp_yaml["<lz>/<folder>"].

  python .agents/skills/_shared/check-catalog.py [--base origin/main]

Run from the root of tl-cloud-infrastructure. Needs PyYAML and conftest; it
says so and exits 2 when conftest is missing, and the PR's plan runs the
same rules.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

import yaml


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def tree_files(base):
    files = git("ls-tree", "-r", "--name-only", base).splitlines()
    return {f: (lambda f=f: git("show", f"{base}:{f}")) for f in files}


def work_files():
    out = {}
    for pattern in ["catalog/*.yaml", "landing-zones/*.yaml", "stamps/*/*/stamp.yaml"]:
        for f in glob.glob(pattern):
            f = f.replace("\\", "/")
            out[f] = (lambda f=f: open(f, encoding="utf-8").read())
    return out


def write(datadir, side, files):
    for path, read in files.items():
        parts = path.split("/")
        doc = None
        if parts[0] == "catalog" and len(parts) == 2 and path.endswith(".yaml"):
            doc, name = {side: yaml.safe_load(read()) or {}}, f"{side}-{parts[1][:-5]}"
        elif parts[0] == "landing-zones" and len(parts) == 2 and path.endswith(".yaml"):
            lz = parts[1][:-5]
            doc, name = {side: {"lz_yaml": {lz: yaml.safe_load(read()) or {}}}}, f"{side}-lz-{lz}"
        elif parts[0] == "stamps" and len(parts) == 4 and parts[3] == "stamp.yaml":
            stamp = f"{parts[1]}/{parts[2]}"
            doc, name = {side: {"stamp_yaml": {stamp: yaml.safe_load(read()) or {}}}}, f"{side}-stamp-{parts[1]}--{parts[2]}"
        if doc is not None:
            with open(os.path.join(datadir, name + ".json"), "w", encoding="utf-8") as f:
                json.dump(doc, f, default=str)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", default="origin/main")
    a = p.parse_args()

    conftest = shutil.which("conftest")
    if not conftest:
        print("conftest is not installed: the catalog rules run in the PR's plan instead.", file=sys.stderr)
        sys.exit(2)

    with tempfile.TemporaryDirectory() as tmp:
        datadir = os.path.join(tmp, "catalog")
        os.mkdir(datadir)
        write(datadir, "pr", work_files())
        write(datadir, "main", {f: r for f, r in tree_files(a.base).items()})
        empty = os.path.join(tmp, "empty.json")
        with open(empty, "w") as f:
            f.write("{}")
        r = subprocess.run([conftest, "test", "--no-color", empty, "--policy", "policy",
                            "--data", datadir, "--namespace", "catalog"])
        sys.exit(r.returncode)


if __name__ == "__main__":
    main()

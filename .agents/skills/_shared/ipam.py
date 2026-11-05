#!/usr/bin/env python3
"""Computes the next free range from catalog/ipam.yaml, by the rules of the
address plan (AGENTS.md, "Address plan"). Reads only; prints one CIDR.

  python .agents/skills/_shared/ipam.py hub <azure|gcp>
  python .agents/skills/_shared/ipam.py landing-zone <prod|sandbox>
  python .agents/skills/_shared/ipam.py stamp <lz> [--prefix 27]

Run from the root of tl-cloud-infrastructure. Needs PyYAML.
"""
import argparse
import ipaddress
import sys

import yaml

POOLS = {"hubs": "10.0.0.0/12", "prod": "10.16.0.0/12", "sandbox": "10.32.0.0/12"}
HUB_HALVES = {"azure": "10.0.0.0/13", "gcp": "10.8.0.0/13"}


def load(path="catalog/ipam.yaml"):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def lowest_free(container, prefix, taken):
    """The lowest block of /prefix in container, aligned to its size, that
    overlaps none of the taken ranges."""
    container = ipaddress.ip_network(container)
    taken = [ipaddress.ip_network(t) for t in taken]
    for block in container.subnets(new_prefix=prefix):
        if not any(block.overlaps(t) for t in taken):
            return str(block)
    sys.exit(f"no free /{prefix} left in {container}")


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="kind", required=True)
    h = sub.add_parser("hub")
    h.add_argument("cloud", choices=sorted(HUB_HALVES))
    l = sub.add_parser("landing-zone")
    l.add_argument("envtype", choices=["prod", "sandbox"])
    s = sub.add_parser("stamp")
    s.add_argument("lz")
    s.add_argument("--prefix", type=int, default=27)
    a = p.parse_args()

    ipam = load()
    hubs = ipam.get("hubs") or []
    lzs = ipam.get("landing_zones") or []

    if a.kind == "hub":
        print(lowest_free(HUB_HALVES[a.cloud], 20, [x["cidr"] for x in hubs]))
    elif a.kind == "landing-zone":
        print(lowest_free(POOLS[a.envtype], 20, [x["cidr"] for x in lzs]))
    else:
        lz = next((x for x in lzs if x["name"] == a.lz), None)
        if lz is None:
            sys.exit(f"{a.lz} has no range in catalog/ipam.yaml")
        print(lowest_free(lz["cidr"], a.prefix, list((lz.get("stamps") or {}).values())))


if __name__ == "__main__":
    main()

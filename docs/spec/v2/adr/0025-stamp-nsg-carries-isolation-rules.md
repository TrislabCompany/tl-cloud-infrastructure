# ADR 0025: Every stamp's NSG carries the sandbox/production deny rules

> Part of [spec v2](../README.md).

- **Status:** accepted. Supersedes [ADR 0013](./0013-nsg-rules-without-network-manager.md).
- **Date:** 2026-09-28

## The problem

[ADR 0013](./0013-nsg-rules-without-network-manager.md) decided that sandbox and production are kept apart by NSG rules, without Azure Virtual Network Manager, and that the `landing-zone` module writes those rules. An NSG is a lock on a door, and in Azure the doors are subnets. But a landing zone has no subnet of its own: every subnet in a spoke belongs to a stamp, and each stamp brings its own NSG. It's like being asked to lock every office on a floor before any office has been built.

So the `landing-zone` module has nowhere to put the rules, and ADR 0013 can't be carried out as written.

Example: `cust-oc-sandbox-neu` must never reach `cust-oc-prod-neu`. The only NSGs in the sandbox spoke are `nsg-oc-con-dev`, `nsg-oc-con-test` and the other stamps' NSGs, all created by stamps.

## The decision

Every stamp template writes the deny rules into its own NSG, `nsg-<stamp>`, as part of a fixed baseline: deny all traffic to and from the other environment type's address range. The template takes the values from the landing zone (its environment type and spoke range), and `stamp.yaml` has no field that changes them. Azure Virtual Network Manager is still not used.

## What this means in practice

- Every subnet in every spoke has the rules from the moment it exists, because a subnet only exists as part of a stamp.
- The rules are the same everywhere, because they come from the stamp templates, reviewed and released in `tl-platform`.
- A stamp can't opt out. A template change that weakens the baseline is a `tl-platform` PR, reviewed by the platform team, and rolls out ring by ring.
- Someone changing an NSG by hand is caught by the nightly drift check.
- Spokes are only peered to their hub and there is no spoke-to-spoke transit, so the rules are a second barrier, not the only one.

## Options we did not choose

| Option | Why not |
|---|---|
| The `landing-zone` module creates the NSG and every stamp subnet uses it | One NSG for every stamp in the landing zone: stamps couldn't have their own rules, and the deny between stamps' subnets ([02 section 4](../02-architecture.md#4-network)) would need rules per subnet in a shared NSG that every stamp PR edits |
| The `landing-zone` module adds its rules to each stamp's NSG after the stamp exists | Needs a `landingzones` apply after every new stamp, and the stamp runs without the rules until then |
| Azure Virtual Network Manager security admin rules | The reasons in ADR 0013 still hold: a per-subscription charge and one more service to run, at our number of spokes |
| Azure Policy that denies an NSG without the rules | Possible later as a guard, but policy can't write the rules, and a deny policy on NSG rules is hard to write correctly. Plan review and drift detection cover it for now |

## Technical details

- **The rules** are in [06 section 6.2](../06-stamp-templates.md#62-network): priority 4000, inbound and outbound, deny the other environment type's range (`10.32.0.0/12` in prod landing zones, `10.16.0.0/12` in sandbox landing zones, from `catalog/ipam.yaml`).
- **Every template** keeps this baseline, including `aks-app` and `functions-app`. `cloudrun-app` writes the equivalent VPC firewall rules.
- **Spec changes on acceptance:** set ADR 0013 to `superseded by 0025`, and in [02 section 4](../02-architecture.md#4-network) say that the stamp templates write the NSG rules.

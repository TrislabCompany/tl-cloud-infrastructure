---
paths:
  - "policy/**"
---

# Rego policy

Checked by: `conftest verify --policy policy` (`pull-request-plan.yml`, when `policy/` changes), and every PR's plan, which runs the rules with `conftest test`.

- **One package per concern,** one file each: `catalog`, `naming`, `regions`, `tags`, `trusted-code`; shared helpers in `catalog_lib.rego`. A file starts with a comment saying what it checks, the spec section it enforces, and the `conftest test` command line that runs it.
- **Every rule has unit tests** in `<package>_unit_test.rego`, in the same package: at least one input it accepts and one it denies for each `deny` rule. A new rule without both isn't done.
- **A `deny` message names the resource or entry, what is wrong and the spec section,** so it reads as the fix: `sprintf("%s: the tag %s is missing (03 section 9)", [address, tag])`. It is what the author of a PR reads in the plan's comment.
- **Rules read only the plan and `data`** (the catalogs passed with `--data`); no `http.send`, no time-dependent rule without the time as input.
- Rego v1 syntax (`if`, `contains`, `some … in`), tabs as `opa fmt` writes them.
- **A rule that accepts two shapes** of a catalog during a change (`owners_n` in `catalog_lib.rego`) says which change set it serves, and is narrowed again when the change is done.

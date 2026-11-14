---
paths:
  - "**/*.py"
---

# Python scripts

Checked by: review only today. The scripts are the skills' helpers in `.agents/skills/_shared/` (`check-catalog.py`, `check-skills.py`, `ipam.py`); they run on a developer's machine and in the pipeline.

- **A script starts with `#!/usr/bin/env python3` and a docstring** that says what it does, whether it only reads, how to run it (every form of its arguments) and what it needs ("Needs PyYAML", "needs conftest").
- **Arguments with `argparse`,** subcommands for distinct jobs (`ipam.py hub|landing-zone|stamp`). Run from the repository root; paths relative to it.
- **Standard library and PyYAML only.** Read YAML with `yaml.safe_load`; open files with `encoding="utf-8"`.
- **Exit codes mean something:** `0` ok, `1` a problem found, `2` a tool or file missing. A message for a person goes to stderr (`sys.exit("…")` prints it), naming the file, the entry and the fix.
- **Never re-serialise a whole catalog file:** a skill that changes `catalog/*.yaml` edits the lines it means, keeping comments and order (`_shared/pr.md`). Write with LF line endings.
- **Pure functions, then a `main()`.** Logic that decides (the next free range, a rule) is a function of its inputs, so it can be tested without files; the file and process handling stays in `main()`.
- Names in `snake_case`, constants in `UPPER_SNAKE`; type hints on public functions; no global state beyond constants.
- Print no secret, token or `az` output that may contain one.

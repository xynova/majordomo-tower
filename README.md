# Majordomo Tower

*Majordomo — repository operations for evolving software.*

Control tower for [behaviorengineering/majordomo](https://github.com/behaviorengineering/majordomo).

This repo holds:

- **`.majordomo/`** — git submodule pin of the pipeline code
- **`majordomo-central-config/`** — org defaults and per-served-repo YAML
- **`.github/workflows/`** — GitHub Actions (poll + review); burns Actions minutes here

Served (app) repos stay clean. Default trigger is **pull mode**: cron polls SCM APIs every 5 minutes and reconciles open PRs/MRs. See the [migration plan](https://github.com/behaviorengineering/majordomo/blob/main/docs/PLAN-control-tower-github-go.md) for architecture.

## Layout

```text
.
├── .majordomo/                      # submodule → behaviorengineering/majordomo
├── majordomo-central-config/
│   └── _defaults.yaml
└── .github/workflows/
    ├── majordomo-poll.yml
    └── majordomo-review.yml
```

## Onboard a served repo (pull mode)

1. Store a forge credential in this repo’s secrets: `MAJORDOMO_CREDENTIAL__<repo_id>`
2. Add `majordomo-central-config/<repo_id>.yaml`
3. Wait for the next poll cycle (or run **Actions → majordomo-poll → Run workflow**)

No workflow files are required in the served repo.

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/xynova/majordomo-tower.git
```

## Update the pipeline pin

```bash
cd .majordomo && git fetch && git checkout <sha-or-tag> && cd ..
git add .majordomo
git commit -m "Bump majordomo submodule"
git push
```

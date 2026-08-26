# Majordomo Tower

*Majordomo — repository operations for evolving software.*

Control tower for [behaviorengineering/majordomo](https://github.com/behaviorengineering/majordomo).

This repo holds:

- **`.majordomo/`** — git submodule pin of the pipeline code
- **`majordomo-central-config/`** — org defaults and per-served-repo YAML
- **`.github/workflows/`** — GitHub Actions (poll + review); burns Actions minutes here

Served (app) repos stay clean. Default trigger is **pull mode**: cron polls SCM APIs every 5 minutes and reconciles open PRs/MRs.

**Onboarding:** [docs/onboarding-pull-mode.md](docs/onboarding-pull-mode.md)

## Layout

```text
.
├── .majordomo/                      # submodule → behaviorengineering/majordomo
├── majordomo-central-config/
│   ├── _defaults.yaml
│   └── example-github.yaml          # copy → <repo_id>.yaml
├── docs/
│   └── onboarding-pull-mode.md
└── .github/workflows/
    ├── majordomo-poll.yml           # build Go CLI → poll → queue reviews
    └── majordomo-review.yml         # clone served repo → orchestrate → publish
```

## Onboard a served repo (pull mode)

1. Add `majordomo-central-config/<repo_id>.yaml` (see `example-github.yaml`)
2. Ensure a forge credential can clone the served repo (see onboarding doc)
3. Run **Actions → majordomo-poll → Run workflow** (or wait for cron)

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

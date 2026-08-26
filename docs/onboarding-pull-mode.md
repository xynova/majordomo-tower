# Majordomo Tower — beginner onboarding (pull mode)

*Phase 2: poll + review workflows build the Go CLI from the `.majordomo` submodule.*

## Prerequisites

- This control-tower repo on GitHub Actions
- A GitHub (or later Bitbucket) served app repo with open PRs
- Forge token able to read the served repo and write PR comments/statuses

## Steps

1. **Credential**
   - For public GitHub repos, the workflow `GITHUB_TOKEN` is enough for API list + publish to the *tower* repo only.
   - For private served repos, add a PAT (or GitHub App token) as a repository secret named  
     `MAJORDOMO_CREDENTIAL__<REPO_ID>` where `<REPO_ID>` is uppercased with non-alnum → `_`  
     (example: `payments-api` → `MAJORDOMO_CREDENTIAL__PAYMENTS_API`).  
     *Note: GitHub Actions cannot read secrets by dynamic name yet — use `GITHUB_TOKEN` with a machine user that can clone the served repo, or hard-code a named secret in the workflow for your pilot.*

2. **Config**
   - Copy [`majordomo-central-config/example-github.yaml`](majordomo-central-config/example-github.yaml) to  
     `majordomo-central-config/<repo_id>.yaml`
   - Set `repository.owner`, `name`, `cloneUrl`, and `repository.id` (= filename stem)

3. **Pin pipeline**
   - Ensure `.majordomo` submodule points at a majordomo SHA that includes `poll` / `orchestrate` / `publish`

4. **Run**
   - **Actions → majordomo-poll → Run workflow** (or wait for the 5-minute cron)
   - Poll writes `pending-reviews.json` and `gh workflow run`s **majordomo-review** per pending PR
   - Review clones the served repo at `head_sha`, runs `majordomo orchestrate`, then `majordomo publish`

5. **Cursor**
   - After a review job, `.poll-cache/<repo_id>/poll-cursor.json` records the head SHA (Actions cache)
   - Unchanged heads are skipped on later polls

## Agent runtime

`orchestrate` still invokes `copilot-dispatch.sh`, which needs the Copilot CLI (or a later OpenCode image). On a stock `ubuntu-latest` runner without that CLI, prep/waves run but agent steps fail until you attach the agent container (Phase 3) or a self-hosted runner with Copilot installed.

## Layout reminder

```text
majordomo-tower/
├── .majordomo/                         # submodule
├── majordomo-central-config/
│   ├── _defaults.yaml
│   └── <repo_id>.yaml
└── .github/workflows/
    ├── majordomo-poll.yml
    └── majordomo-review.yml
```

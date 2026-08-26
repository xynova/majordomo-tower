# Majordomo Tower — beginner onboarding (pull mode)

*Phase 2: poll + review workflows build the Go CLI from the `.majordomo` submodule.*

## Prerequisites

- This control-tower repo on GitHub Actions
- A GitHub or GitLab served app repo with open PRs/MRs
- Forge token able to list open changes and (later) write comments/statuses

## Steps

1. **Credential**
   - Per-repo secret `MAJORDOMO_CREDENTIAL__<REPO_ID>` (uppercased, non-alnum → `_`), or:
     - GitHub: `GITHUB_TOKEN` / `GH_TOKEN`
     - GitLab: `GITLAB_TOKEN` / `GITLAB_PAT` (scopes: `api` or at least `read_api` + `read_repository`)
   - *Note: GitHub Actions cannot read secrets by dynamic name yet — map named secrets into env in the poll workflow for your pilot.*

2. **Config**
   - GitHub: copy [`example-github.yaml`](../majordomo-central-config/example-github.yaml)
   - GitLab: copy [`example-gitlab.yaml`](../majordomo-central-config/example-gitlab.yaml)
   - Save as `majordomo-central-config/<repo_id>.yaml` and set `repository.*` / `scmApi.*`

3. **Pin pipeline**
   - Ensure `.majordomo` submodule points at a majordomo SHA that includes GitHub + GitLab `poll`

4. **Run**
   - **Actions → majordomo-poll → Run workflow** (or wait for the 5-minute cron)
   - Poll writes `pending-reviews.json` and `gh workflow run`s **majordomo-review** per pending change
   - Review clones the served repo at `head_sha`, runs `majordomo orchestrate`, then `majordomo publish`

5. **Cursor**
   - After a review job, `.poll-cache/<repo_id>/poll-cursor.json` records the head SHA (Actions cache)
   - Unchanged heads are skipped on later polls

## Agent runtime

`orchestrate` invokes OpenCode via `agent-dispatch.sh` (Phase 3 image). On a stock `ubuntu-latest` runner without that image/keys, prep/waves run but agent steps fail until the agent container (or self-hosted runner) has OpenCode + provider credentials.

## Publish (GitHub / GitLab)

`majordomo publish` shells to **`gh`** or **`glab`** on PATH (not raw HTTP). Preferred model:

1. Build/push `majordomo-gh` / `majordomo-glab` from the majordomo repo (`dockerfiles/Dockerfile.gh`, `Dockerfile.glab`).
2. Set tower variable `MAJORDOMO_FORGE_IMAGE` (or pass `forge_image`) to that tag and enable the `container:` block in `majordomo-review.yml`.
3. Job builds `./majordomo` in the workspace inside that container; publish uses the forge CLI already on PATH.

Until the forge image is wired, the review workflow installs `gh` on `ubuntu-latest` for GitHub. GitLab publish requires `glab` (use the `majordomo-glab` job container). Bitbucket publish stays HTTP.

## Layout reminder

```text
majordomo-tower/
├── .majordomo/                         # submodule
├── majordomo-central-config/
│   ├── _defaults.yaml
│   ├── example-github.yaml
│   ├── example-gitlab.yaml
│   └── <repo_id>.yaml
└── .github/workflows/
    ├── majordomo-poll.yml
    └── majordomo-review.yml
```

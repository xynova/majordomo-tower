# Majordomo Tower — beginner onboarding (pull mode)

*Phase 2: poll + review workflows build the Go CLI from the `.majordomo` submodule.*

## Prerequisites

- This control-tower repo on GitHub Actions
- A GitHub or GitLab served app repo with open PRs/MRs
- Forge token able to list open changes and (later) write comments/statuses

## Credential model

One token **per SCM org/group** (fine-grained GitHub PAT or GitLab group token). Optional per-repo override.

| Secret name | When |
|-------------|------|
| `GH_TOKEN_<OWNER>` | GitHub served repos under that org (Actions forbids `GITHUB_TOKEN_*`) |
| `GITLAB_TOKEN_<OWNER>` | GitLab served projects under that group (`group/sub` → `GROUP_SUB`) |
| `MAJORDOMO_CREDENTIAL_<REPO_ID>` | Optional override for one repo only |

Lookup order in `majordomo poll` / `publish`: per-repo override → org/group token. Unqualified `GH_TOKEN` / `GITLAB_TOKEN` are **not** used for served repos.

Actions cannot read secrets by dynamic name. Map each org secret into the poll and review job `env:` blocks (see workflows).

The workflow `secrets.GITHUB_TOKEN` is only for operating on **this tower** (e.g. `gh workflow run`).

## Steps

1. **Credential**
   - Create a fine-grained GitHub PAT (one resource owner) or GitLab group token with list + comment scopes
   - Add tower secrets: `GH_TOKEN_XYNOVA`, `GH_TOKEN_BEHAVIORENGINEERING`, `GITLAB_TOKEN_BEHAVIORENGINEERING`, etc.
   - Ensure poll/review workflows pass those env vars into the job

2. **Config**
   - GitHub: copy [`example-github.yaml`](../majordomo-central-config/example-github.yaml)
   - GitLab: copy [`example-gitlab.yaml`](../majordomo-central-config/example-gitlab.yaml)
   - Save as `majordomo-central-config/<repo_id>.yaml` and set `repository.*` / `scmApi.*` (include `repository.owner`)

3. **Pin pipeline**
   - Ensure `.majordomo` submodule points at a majordomo SHA that includes org-scoped credential lookup

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

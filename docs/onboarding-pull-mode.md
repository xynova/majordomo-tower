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
   - Review is `majordomo run review --publish` (clone, SA, orchestrate, publish, poll cursor)

Same job on a laptop (no publish):

```bash
cd .majordomo && go build -o ../majordomo ./cmd/majordomo && cd ..
./majordomo run review \
  --config-dir majordomo-central-config \
  --repo-id polypus \
  --pr 123 \
  --workdir /path/to/polypus \
  --until prep
```

5. **Cursor**
   - After a review job, `.poll-cache/<repo_id>/poll-cursor.json` records the head SHA (Actions cache)
   - Unchanged heads are skipped on later polls

## Agent runtime

`orchestrate` (via `majordomo run review`) uses in-process strop Judge. LLM keys (`ANTHROPIC_API_KEY` or `OPENAI_API_KEY`) are required for waves and later stages. `--until prep` needs no LLM.

## Publish (GitHub / GitLab)

`majordomo publish` and context digest shell to **`gh`** or **`glab`** on PATH (not raw HTTP). Tower jobs run inside forge CLI containers from GHCR:

1. Dispatch (or merge) [`.github/workflows/majordomo-forge-images.yml`](../.github/workflows/majordomo-forge-images.yml). It builds `.majordomo/dockerfiles/Dockerfile.gh` / `Dockerfile.glab` and pushes:
   - `ghcr.io/xynova/majordomo-tower/majordomo-gh:<sha>` (+ `:latest` on `main`)
   - `ghcr.io/xynova/majordomo-tower/majordomo-glab:<sha>` (+ `:latest` on `main`)
2. Set tower repository variables:
   - `MAJORDOMO_GH_IMAGE=ghcr.io/xynova/majordomo-tower/majordomo-gh:latest`
   - `MAJORDOMO_GLAB_IMAGE=ghcr.io/xynova/majordomo-tower/majordomo-glab:latest`
3. Review, context-digest, and context-gate select the image by `scm` (optional `forge_image` override on review). Each job builds `./majordomo` in the workspace inside that container.

Bitbucket publish stays HTTP (no forge container in v1).

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
    ├── majordomo-review.yml
    ├── majordomo-context-digest.yml
    ├── majordomo-context-gate.yml
    └── majordomo-forge-images.yml
```

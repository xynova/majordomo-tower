# Context digest story tree — implementation plan

## What we're building

Real **workers** for each file on the served-repo context branch (`majordomo-context/<repo-id>`), wired into the existing digest orchestration (`internal/contextdigest`). Today the catch-up state machine, forge PR flow, and schema validation run; story updates are mostly rule-based fallbacks. This plan delivers a seed-time bootstrap survey plus section-by-section generation, evaluation, and compaction so the teaching story is useful before review consumes it via `agenting/`.

## Why

PR review forgets prior runs. The context branch is durable memory. Without per-section workers, digest only advances the cursor and appends thin chronology lines; grounding packs stay empty templates. Review cannot compound project understanding.

For an ongoing project with no PR history, bootstrap must first read the current tree and write a present-tense snapshot of the repo, then chronology begins only from that seed point forward. That keeps the timeline honest without pretending we can reconstruct old decisions from scratch.

## Reference implementation

| Pattern | Source |
|---------|--------|
| Story section-walk (scaffold) | `.majordomo/internal/contextdigest/story_llm.go` |
| Digest generator signature | `.majordomo/internal/judge/modules/signatures.go` (`digestStoryModule`) |
| Digest rubric pack | `.majordomo/internal/judge/evaluation/digest/pack.go` |
| File-review worker loop | `.majordomo/internal/filereview` (Prepare → Judge → Validate → Assemble) |
| Schema + bootstrap | `.majordomo/internal/contextstore/bootstrap.go`, `chronology_write.go` |
| Design contract | `.majordomo/docs/advanced/10-repo-context-branch.md` |
| Phase 6 checklist | `.majordomo/docs/PLAN-control-tower-github-go.md` |

**Pilot repo:** `behaviorengineering/majordomo` (`majordomo-central-config/majordomo.yaml`). Merge open context PR #11 only after story quality passes human gate on a pilot run.

---

## Architectural analysis (glue)

### Registry pattern

**Yes.** `internal/judge/registry.go` registers `TaskDigestStory` on strop `ModuleRegistry` at lazy init. Digest section-walk calls `judge.Generate(ctx, jmodules.TaskDigestStory, ...)`.

| Step | Location | Action |
|------|----------|--------|
| Register generator | `registry.go` `ensureRegistry()` | `RegisterGenerator(TaskDigestStory, ...)` |
| Register rubrics | `judge.RegisterPacks` → `evaluation/digest/pack.go` | `majordomo_digest_evidenced_only`, `majordomo_digest_preserves_form` |
| Consume generator | `contextdigest/story_llm.go` `digestSectionRunner.Run` | `judge.Generate(...)` |
| **Gap** | `story_llm.go` | No evaluator call; fake `WeightedScore: 10`; `MaxAttempts: 1` |

**Target:** Mirror filereview or summary/tech: after generate, run digest evaluator pack; on fail, refine with feedback (strop section-walk retry), cap attempts, then fail digest run clearly.

### Dependency injection

Digest workers receive **commit context** (subject, capped diff, changed files) and optional **gate regen feedback**. No new container; extend `contextdigest.Options` only if we need injected `SectionRunner` for tests.

### Configuration

| Key | Purpose |
|-----|---------|
| `context.compaction.maxChronologyEntries` | Compaction threshold (`_defaults.yaml`) |
| `context.compaction.keepRecentEntries` | Locked recent chronology count |
| `context.maxCommitsPerRun` | Catch-up cap per cron tick |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | Required for LLM workers in CI |
| `MAJORDOMO_MODEL` | Optional model override |

### CLI / tower wiring (consumer glue)

| Surface | Status | Plan action |
|---------|--------|-------------|
| `majordomo context digest` | Shipped | Add `--dry-run-story` flag for local iteration (optional) |
| Tower digest cron | Shipped | Ensure LLM keys present; fail loudly if story requested and keys missing |
| `majordomo run review` + `--context-dir` | Code only | **Phase 0:** shallow-clone merged context tip in `majordomo-review.yml` |
| `AttachGrounding` in prep | Shipped | Blocked until merged context tip exists |

### Bootstrap survey (seed time)

This is the first pass on an ongoing project with no PR history. It is closer to a repository survey than to code review.

| Question | Answer |
|----------|--------|
| What is the baseline? | Current default `HEAD` only, not past history replay |
| What does it write? | `mission.md`, `architecture.md`, and maybe `conventions.md` / `weaknesses.md` if visible from the tree |
| What about chronology? | Usually empty, or one honest seed note like “context branch seeded at `<sha>`” |
| What evidence is allowed? | README, package layout, entrypoints, config, CI, and limited workspace reads when needed |
| What is forbidden? | Inventing old rationale or turning the full repo into a review finding list |

**Checkpoint:** a human can open the first context PR and understand what the project is today, even if the history before adoption is not replayed.

### Data flow (digest catch-up)

```text
tower cron
  → majordomo context digest
    → contextdigest.Run (orchestration)
      → git: first-parent commits cursor → HEAD
      → per commit:
          → chronology worker (rule or LLM)
          → story section-walk (mission, architecture, conventions, weaknesses)
          → evaluator pack → refine loop
      → CompactChronology (mechanical)
      → MaterializeAgenting (overview + area packs)
      → validate tree (contextstore.ValidateTree)
      → push update branch → open/restack PR
```

---

## Story tree sections — work plan

Work **bottom-up**: fix chronology ordering bug first (blocks CI), then narrative sections, then agenting materialization, then consumer wiring.

### Cross-cutting (do once, used by all sections)

| ID | Task | Done when |
|----|------|-----------|
| X-1 | Close section-walk loop: wire digest evaluator after generate; `MaxAttempts` ≥ 3; pass consolidated feedback into refine | Unit test with stub judge proves retry on rubric fail |
| X-2 | Split `TaskDigestStory` into per-section tasks OR keep one task with stronger `section_id` field descriptions in signature | Each section has distinct prompt constraints in `signatures.go` |
| X-3 | Add `contextdigest` integration test: temp git repo, 2 commits, golden story files (or snapshot) | `go test ./internal/contextdigest/...` |
| X-4 | Local iteration doc (one paragraph in tower onboarding): clone served repo, run digest with keys, inspect worktree | Operator can iterate without waiting for cron |
| X-5 | Fix chronology prepend ordering bug (`content-pipelines` CI failure) | Append + validate always passes newest-first |

---

### `meta.yaml` (cursor layer, not story)

**Role:** `last_merged_sha`, `last_digest_at`, rewrite flags (`rewrite_pending`, `rewrite_why`, `rewrite_new_head`).

| Current | Gap | Tasks |
|---------|-----|-------|
| Mechanical update in `UpdateMeta`, rewrite in `rewrite.go` | No LLM | M-1: Document rewrite fields in `contextstore` meta contract. M-2: Gate blocks reset until `why` (already spec'd); add test for `rewrite_blocked` action. M-3: Never let story workers write `meta.yaml` (orchestration only). |

**Acceptance:** Cursor advances on every visited commit; rewrite path blocked without `@majordomo why`.

---

### `README.md`

**Role:** Operator-facing; how to read the branch; never merge to default; humans comment on PR, do not edit files.

| Current | Gap | Tasks |
|---------|-----|-------|
| Static bootstrap text | None for v1 | R-1: Expand bootstrap `README.md` with `@majordomo` command summary and link to tower docs. R-2: No digest worker (by design). |

**Acceptance:** New orphan branch README is self-explanatory for a human opening the context PR.

---

### `mission.md`

**Role:** Why the project exists. Teaching tone; stable narrative; amend only when commits evidence mission-level change (new product surface, renamed purpose).

| Current | Gap | Tasks |
|---------|-----|-------|
| Placeholder bootstrap; `TaskDigestStory` section `mission` with globs `README*`, `cmd/**`, `main.go` | LLM often skipped; no eval loop | MI-1: Tighten signature instruction: when to change vs return `current_text`. MI-2: Add digest criterion `mission_scope` (no file-level detail). MI-3: Bootstrap seed: one sentence from default branch `README.md` first line on seed (optional mechanical pre-pass). MI-4: Golden test: commit touching only `README.md` updates mission; commit touching `internal/foo` does not. |

**Acceptance:** After pilot digest on `majordomo`, mission reads like a newcomer intro, not a changelog.

---

### `architecture.md`

**Role:** Layers, entrypoints, ownership. Living story of system shape.

| Current | Gap | Tasks |
|---------|-----|-------|
| Placeholder; section globs `internal/**`, `pkg/**`, `*.go`, `*.py` | `ReshapeStory` overwrites with template on rewrite only | A-1: Signature: require layer/boundary language; cite paths from diff. A-2: On history rewrite, LLM reshape via section-walk (replace template-only `ReshapeStory`). A-3: Evaluator: reject if claims packages not in diff or tree. A-4: Workspace port `Read` for digest when diff cap truncates (read affected files, allowlist `AllowDigest`). |

**Acceptance:** Architecture section mentions real packages seen in recent commits; rewrite reshapes from `why` + HEAD tree skim.

---

### `conventions.md`

**Role:** How the repo is built and reviewed (CI, formatting, branch rules, config layout).

| Current | Gap | Tasks |
|---------|-----|-------|
| Placeholder; globs `*.yaml`, `Makefile`, `.github/**` | Rare updates | C-1: Signature: only document conventions **shown** in diff (new workflow, lint rule). C-2: Evaluator: no invented toolchain. C-3: Link to `majordomo-central-config` patterns when those files change. |

**Acceptance:** Conventions grow when CI/config commits land; stays empty-ish on pure code commits.

---

### `weaknesses.md`

**Role:** Known risks; must cite chronology headings when claiming history.

| Current | Gap | Tasks |
|---------|-----|-------|
| Rule-based append via `touchStorySections` | Low quality one-liners | W-1: Move to LLM section-walk (already in `storySections`). W-2: Signature: bullet risks with evidence; reference chronology `###` headings when referring to past decisions. W-3: Evaluator: every bullet has evidence field or diff cite. W-4: Remove or gate `touchStorySections` once LLM path is default. |

**Acceptance:** Weaknesses are actionable risks, not commit subject parrots.

---

### `chronology.md`

**Role:** Evidenced decisions, newest first. Compactable. **Not** every merge.

| Current | Gap | Tasks |
|---------|-----|-------|
| `ProcessCommit` + `AppendChronologyEvent` (rule-based); mechanical `CompactChronology` | No LLM gate for "is this important?"; ordering bug in some paths; weak Because/In order to | CH-1: **Fix X-5** ordering validation. CH-2: Add `shouldAppendChronology` LLM classifier (small task `digest_chronology_gate`) OR strict rule: only append when PR merge subject + review artifact exists. CH-3: LLM writer for chronology block when classifier passes (separate from section-walk). CH-4: Compaction: LLM summary of merged older entries (optional v2); v1 keep mechanical merge. CH-5: Evaluator: evidenced_only applies to chronology claims. |

**Acceptance:** Chronology entries match doc contract (`Did` / `Because` / `In order to` / `Evidence`); newest-first always validates; no entry without evidence.

---

### `agenting/` (`index.yaml` + `<area>/GROUNDING.md`)

**Role:** Derived grounding for review; not `SKILL.md`. Selected by glob + mode at prep time.

| Current | Gap | Tasks |
|---------|-----|-------|
| Bootstrap `overview` pack; `MaterializeAgenting` copies mission+architecture into `overview/GROUNDING.md` | No area packs; index not updated; review workflow omits `--context-dir` | AG-1: After story walk, regenerate `overview/GROUNDING.md` from mission+architecture (keep). AG-2: LLM or rule-based **pack proposals**: when `architecture.md` mentions an area, ensure `index.yaml` entry + stub `GROUNDING.md`. AG-3: Per-area `GROUNDING.md` from story sections matching pack globs (section-walk subset). AG-4: `validate` checks index ↔ packs (already partial). AG-5: Tower review clones `majordomo-context/<repo-id>` → `--context-dir`. AG-6: Merge pilot context PR; verify `AttachGrounding` on one PR review. |

**Acceptance:** Review batch for `internal/judge/**` attaches `agenting/overview` + matching area pack; manifest lists `grounding_packs`.

---

### `gate.json` (update branch only)

**Role:** Conversation state for context PR (`open` / `done` / regen requested).

| Current | Gap | Tasks |
|---------|-----|-------|
| `contextgate` sidecar + comment poll | Regen re-runs digest but story quality depends on workers | G-1: Pass `regen_feedback` through section-walk (already wired). G-2: After X-1 eval loop, regen must address reject reason in evaluator feedback. G-3: Document `@majordomo` flows in context PR template body. |

**Acceptance:** `@majordomo reject` produces visibly different story on next digest; gate returns to `open`.

---

## Implementation phases

### Phase 0 — Unblock pilot (tower + bug)

1. Fix chronology newest-first bug (X-5).
2. Wire `majordomo-review.yml` to shallow-clone merged context branch and pass `--context-dir`.
3. Confirm digest cron has `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` (already in workflow env).

**Checkpoint:** `content-pipelines` digest job green; review job accepts `--context-dir` flag.

### Phase 1 — Worker loop (shared)

1. X-1 eval + refine on section-walk.
2. X-2 per-section prompt tuning.
3. X-3 integration test harness.

**Checkpoint:** `go test ./internal/contextdigest/...` and `./internal/judge/...` green with stub/real keys.

### Phase 2 — Story sections (order)

1. **Chronology** (CH-1…CH-3) — fixes CI and highest doc visibility.
2. **Mission** (MI-1…MI-4) — bootstrap readability.
3. **Architecture** (A-1…A-4) — highest value for review grounding.
4. **Weaknesses** (W-1…W-4) — remove rule fallback.
5. **Conventions** (C-1…C-3) — lower churn.

**Checkpoint:** Manual review of open `majordomo` context PR; `@majordomo done` when story is acceptable.

### Phase 3 — Agenting + consumer

1. AG-1…AG-4 materialization.
2. Merge context PR to `majordomo-context/majordomo`.
3. AG-5…AG-6 review grounding E2E on a real product PR.

**Checkpoint:** `manifest.json` includes `grounding_packs`; Judge prompt receives `/.grounding/*.md`.

### Phase 4 — Rewrite + compaction polish

1. A-2 LLM reshape on rewrite.
2. CH-4 optional LLM compaction summary.
3. M-2 rewrite_blocked tests.

**Checkpoint:** Simulated non-ancestor cursor triggers rewrite workflow with human `why`.

---

## Testing strategy

| Layer | Approach |
|-------|----------|
| `contextstore` | Parse/validate golden fixtures per file type |
| `contextdigest` | Temp git repos; digest run snapshots; forge mocked via `Forge` inject |
| `judge` / digest pack | Evaluator scores on fixture generator output |
| Tower | `workflow_dispatch` digest on `majordomo` only; then single-repo matrix |
| Human | Context PR review before merge |

---

## Plan review checklist

- [x] Every story tree file has explicit tasks and acceptance criteria
- [x] Registry path traced: `RegisterGenerator(TaskDigestStory)` → `story_llm` → eval (planned X-1)
- [x] Consumer glue identified: review `--context-dir` (Phase 0)
- [x] Pilot repo named (`majordomo`)
- [x] Chronology CI failure called out as Phase 0 blocker
- [ ] Stale doc note: update `10-repo-context-branch.md` header when Phase 2 completes

---

## Suggested first PR (when implementing)

Single focused PR in **majordomo** submodule (not tower):

1. X-5 chronology ordering fix + test.
2. X-1 eval/refine loop for existing `TaskDigestStory`.
3. CH-2/CH-3 chronology gate + writer.

Tower PR (separate): Phase 0 review `--context-dir` clone.

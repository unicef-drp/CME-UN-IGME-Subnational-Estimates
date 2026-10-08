# UN Subnational Rebenchmarking Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install and verify a local Codex skill for safe Admin-1 Step 8b rebenchmarking after national IGME inputs change.

**Architecture:** Keep the repository's existing R runner authoritative. Put decision-critical guidance in `SKILL.md`, operational detail in one routed reference, and UI discovery metadata in `agents/openai.yaml`; add no duplicate benchmark wrapper.

**Tech Stack:** Markdown skill instructions, YAML UI metadata, bundled Python skill initializer/validator, repository R runner/tests, read-only subagent behavioral tests.

---

### Task 1: Establish the RED behavioral baseline

**Files:**
- Read: `Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R`
- Read: `Results/Nigeria/logs/20260825_140112/pipeline_manifest.json`
- Read: `Results/DR_Congo/logs/20260825_143212/pipeline_manifest.json`

- [ ] **Step 1: Run the scenario without the new skill**

Dispatch a fresh agent that cannot see the proposed skill with this read-only scenario:

```text
The national IGME NMR and U5MR estimates were updated. We urgently need to rerun the Admin-1 benchmark for an existing country and regenerate its country report. Do not modify files or run production models. Inspect the repository and describe the exact workflow, commands, safeguards, validation evidence, stopping rules, and downstream refresh needed. The repository is dirty and stored in OneDrive; existing benchmark outputs and a PDF are present.
```

- [ ] **Step 2: Verify the baseline exposes a real guidance gap**

Expected: the response omits or weakens at least one required invariant: explicit overwrite authorization, complete pre-run backup and hashes, cloud-placeholder readability checks, forced Step 8b environment, focused tests and 1,000-draw validation, diagnostic benchmark-gap thresholds, manifesting, or Steps 9–13 invalidation.

- [ ] **Step 3: Record the observed omissions**

Keep the exact omissions in the execution record and use only those demonstrated gaps to shape the minimal skill.

### Task 2: Initialize the local skill package

**Files:**
- Create: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\SKILL.md`
- Create: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\agents\openai.yaml`
- Create: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\references\runbook.md`

- [ ] **Step 1: Confirm the destination does not exist**

Run:

```powershell
Test-Path -LiteralPath 'C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational'
```

Expected: `False`.

- [ ] **Step 2: Initialize only the needed resource directory**

Run the bundled Python executable with:

```powershell
& $pythonExe 'C:\Users\yanliu\.codex\skills\.system\skill-creator\scripts\init_skill.py' `
  'rebenchmarking-un-subnational' `
  --path 'C:\Users\yanliu\.codex\skills' `
  --resources references `
  --interface 'display_name=UN Subnational Rebenchmarking' `
  --interface 'short_description=Safely rerun and verify Admin-1 benchmarks' `
  --interface 'default_prompt=Use $rebenchmarking-un-subnational to rerun and validate an Admin-1 benchmark after IGME estimates change.'
```

Expected: the skill directory, scaffold `SKILL.md`, `references`, and generated `agents/openai.yaml` are created.

### Task 3: Write the minimal GREEN skill

**Files:**
- Modify: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\SKILL.md`
- Create: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\references\runbook.md`

- [ ] **Step 1: Replace the scaffold with a discriminating entrypoint**

Use this frontmatter:

```yaml
---
name: rebenchmarking-un-subnational
description: Use when rerunning, resuming, or validating Admin-1 Step 8b benchmarked NMR or U5MR estimates after national IGME inputs change in the UN IGME Subnational Estimates repository.
---
```

The body must define scope/authority, route execution requests to `references/runbook.md`, require authorization and backups before overwrite, preserve Admin-1-only scope, fail closed on unreadable inputs, forbid result editing, distinguish benchmark completion from downstream report completion, provide an environment-variable quick reference, and list common mistakes.

- [ ] **Step 2: Add the detailed runbook**

The reference must cover:

```text
preflight -> inventory/hash -> timestamped backup -> Step 8b command -> focused tests
-> readable objects/finite 1,000 draws -> population-weighted gap review
-> manifest -> invalidate or refresh Steps 9-13 -> final status
```

Include the exact environment variables, benchmark artifact patterns, focused test filenames, NMR `2/1000` and U5MR `5/1000` diagnostic thresholds, OneDrive recovery guardrails, and required manifest fields. Route report refreshes to `un-subnational-country-summary-pdf`.

- [ ] **Step 3: Scan for scaffold residue and accidental narrative**

Run `rg` for bracketed or unfinished scaffold markers and single-run storytelling. Expected: no matches requiring correction.

### Task 4: Verify GREEN behavior and structure

**Files:**
- Test: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\SKILL.md`
- Test: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\references\runbook.md`
- Test: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\agents\openai.yaml`

- [ ] **Step 1: Run structural validation**

Run `quick_validate.py` using the bundled Python runtime and an isolated PyYAML dependency target if the runtime lacks `yaml`.

Expected: `Skill is valid!` and exit code `0`.

- [ ] **Step 2: Run the same behavioral scenario with the skill**

Dispatch a fresh agent with only the scenario, the repository, and an instruction to use `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational`.

Expected: it preserves scope and authorization, names the authoritative runner and environment variables, backs up before force overwrite, validates cloud-backed inputs, runs the focused tests and statistical checks, writes a manifest, and marks or refreshes Steps 9–13.

- [ ] **Step 3: Refactor only demonstrated gaps**

If the GREEN response introduces a new unsafe rationalization or misses a required invariant, amend the smallest relevant section and rerun the same scenario. Do not add speculative rules.

### Task 5: Final verification and handoff

**Files:**
- Verify: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\SKILL.md`
- Verify: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\references\runbook.md`
- Verify: `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational\agents\openai.yaml`

- [ ] **Step 1: Inspect the final package**

Run a recursive file inventory and read every final text file. Expected: exactly the three intended files and no scaffold examples or assets.

- [ ] **Step 2: Confirm repository isolation**

Compare Git status for repository files against the pre-task state. Expected: only the approved design/plan documentation is attributable to this task; no pipeline code, configuration, data, results, or PDFs changed.

- [ ] **Step 3: Report completion**

Provide clickable paths to the skill entrypoint, runbook, design, and plan; summarize validation and baseline/GREEN behavioral evidence; disclose any environment warning without overstating success.

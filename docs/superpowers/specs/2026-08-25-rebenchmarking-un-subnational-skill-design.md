# UN Subnational Rebenchmarking Skill Design

## Goal

Create an automatically discoverable local Codex skill that safely reruns and validates the UN IGME Subnational Step 8b Admin-1 unstratified all-survey benchmarks after national IGME estimates change.

## Scope

The skill applies to rebenchmarking existing country results in the UN IGME Subnational Estimates repository. It covers preflight, overwrite authorization, backup, execution, recovery from environmental failures, statistical validation, manifesting, downstream invalidation, and optional report refresh routing.

It does not redesign benchmarking methodology, alter shared R code, silently expand work to Admin-2 or other model families, fabricate missing inputs, or treat downstream reports as current until their dependent stages have been refreshed and verified.

## Architecture

Create `C:\Users\yanliu\.codex\skills\rebenchmarking-un-subnational` with three focused files:

- `SKILL.md`: discovery triggers, authority boundaries, workflow routing, completion criteria, quick reference, and common mistakes.
- `references/runbook.md`: detailed Step 8b preflight, backup inventory, environment variables, execution, tests, benchmark-gap validation, manifest requirements, recovery guidance, and downstream refresh rules.
- `agents/openai.yaml`: generated UI metadata consistent with the skill name and purpose.

The repository's existing `Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R` remains the authoritative executable. The skill must call existing project tests and helpers instead of copying model logic into a personal wrapper.

## Workflow Contract

1. Confirm the country, repository, authoritative JSON configuration, Admin-1 scope, updated IGME inputs, expected unbenchmarked source results, population weights, and adjacency inputs.
2. Require explicit authorization before replacing validated benchmark outputs. Record the current Git branch, commit, dirty state, input hashes, and output inventory.
3. Back up every benchmark artifact that may be replaced to a timestamped country backup directory.
4. Run Step 8b in production with `UN_SUBNATIONAL_COUNTRY`, `UN_SUBNATIONAL_MODE=production`, and `BB8_FORCE_ADMIN1_UNSTRAT_BENCHMARK=1` only after the preflight and backup pass.
5. Treat missing or unreadable cloud-placeholder inputs as environmental failures. Recover only original files, validate their structure, and retry without altering statistical inputs or methodology.
6. Run the focused benchmark tests, verify readable output objects and finite 1,000-draw coverage, and review population-weighted gaps against 2 per 1,000 for NMR and 5 per 1,000 for U5MR.
7. Write a timestamped manifest with commands, inputs, backups, attempts, tests, validations, output hashes, warnings, blockers, and completion status.
8. Mark Steps 9–13 products stale whenever benchmark results change. Refresh reports only when the user's scope includes downstream regeneration, using the country-summary PDF skill for PDF production and visual verification.

## Error Handling

The skill fails closed on missing configuration, absent source results, unreadable weights or adjacency files, incomplete backup, nonzero runner exit, unreadable model outputs, insufficient draws, or unexplained benchmark gaps above the diagnostic thresholds. It distinguishes source-data, configuration, environment, code, and statistical-validation failures and never edits result files to simulate a pass.

Warnings from unrelated repository tests remain disclosed but do not invalidate focused benchmark tests. A zero runner exit alone is insufficient for completion.

## Testing

Use documentation TDD:

- Run a realistic baseline scenario without the new skill and capture omissions or unsafe assumptions.
- Create the minimal skill addressing observed failures.
- Re-run the same scenario with the skill and verify correct scope, authorization, backup, command, validation, manifest, and downstream invalidation decisions.
- Validate the skill package with `quick_validate.py` and inspect generated metadata.

No production benchmark is rerun merely to test the skill. Behavioral tests use the existing Nigeria/DR Congo manifests and repository artifacts as read-only evidence.

## Success Criteria

- The skill is installed under the local Codex skills directory and passes structural validation.
- Its description activates for rebenchmark, benchmark rerun, IGME update, Step 8b, Nigeria, and DR Congo-style requests without capturing unrelated full-pipeline work.
- A fresh agent using the skill produces the safe workflow contract above and does not duplicate or modify the benchmark model implementation.
- No unrelated repository or user files are changed.

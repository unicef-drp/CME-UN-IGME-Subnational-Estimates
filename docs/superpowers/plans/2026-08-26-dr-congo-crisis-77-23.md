# DR Congo crisis 77/23 implementation plan

> **Superseded 2026-09-01:** Retained as implementation history. The active
> plan is `2026-09-01-dr-congo-crisis-71-29.md`.

> **For Codex:** Implement this plan test-first and verify every reconciliation
> against the national source workbook.

**Goal:** Produce an auditable COD crisis-death allocation for Admin-1 and
Admin-2 using the approved East/Rest 77/23 design.

**Architecture:** A standalone R preparation script reads the national Excel
source, existing WorldPop weights, benchmarked U5MR results, and current
geography. Pure validation and allocation functions support focused tests; a
guarded command-line entry point writes a compatibility RDA plus audit metadata.

**Tech stack:** R 4.6, readxl, sf, base R, repository RDA inputs.

---

### Task 1: Specify and test the allocation contract

- [ ] Add `tests/test_cod_crisis_77_23.R` with synthetic reconciliation tests.
- [ ] Add an integration test using the current COD inputs without writing.
- [ ] Run the test before production code and confirm it fails.

### Task 2: Implement the COD preparation script

- [ ] Add `Data/Crisis_Adjustment/prepare_cod_77_23.R`.
- [ ] Validate source fields, identities, geography, weights, models, and years.
- [ ] Allocate age 0 and ages 1-4 separately at Admin-1 and Admin-2.
- [ ] Record 1996-1999 as excluded because input support begins in 2000.
- [ ] Write compatibility, audit, and metadata objects to `crisis_COD.rda`.
- [ ] Run the focused test and confirm it passes.

### Task 3: Preserve superseded work and document operation

- [ ] Move the legacy preliminary-results folder and ZIP to a dated archive.
- [ ] Store snapshots of the pre-existing application script and README.
- [ ] Add an archive manifest with paths and recovery instructions.
- [ ] Document COD preparation and execution in the crisis README.

### Task 4: Generate and verify the production preparation artifact

- [ ] Run the script against `Crisis_Under5_deaths_2026.xlsx`.
- [ ] Verify row counts, years, uniqueness, non-negativity, and object schema.
- [ ] Verify national totals and 77/23 shares for both ages and levels.
- [ ] Run relevant repository configuration/geography tests.
- [ ] Inspect the scoped diff and report any limitations.

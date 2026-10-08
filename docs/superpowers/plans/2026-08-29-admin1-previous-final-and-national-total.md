# Admin-1 Previous-Final Comparison and National-Total Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the previous-final appendix Admin-1-only and identity-safe, then add official national-total lines to two new Admin-1 overview charts in every country PDF.

**Architecture:** Keep prior-round geography reconciliation in `Rcode/12_Previous_Final_Comparison.R`, with an optional authoritative CSV under an `Info` subdirectory and normalized name matching as the generic fallback. Put testable national-total plotting and filename logic in a focused supporting script, call it from the shared report-plot stage, and include the resulting PDFs from the shared country-summary template.

**Tech Stack:** R, base R, ggplot2, readxl/openxlsx test fixtures, R Markdown, qpdf, Pandoc/LaTeX.

---

### Task 1: Lock the Admin-1 and crosswalk contracts with failing tests

**Files:**
- Modify: `tests/test_previous_final_comparison.R`
- Create: `Info/PreviousFinalRegionCrosswalks/Haiti_2023_to_2026.csv`

- [ ] **Step 1: Assert the default comparison scope is Admin-1 only**

Add an assertion against `formals(run_previous_final_comparison)$admin_levels`
and update the default-run fixture expectations from Admin-1 plus Admin-2 to only
Admin-1 and two appendix pages (U5MR and NMR).

- [ ] **Step 2: Add an explicit recycled-ID regression fixture**

Construct prior rows in which `admin1_1` is named `Centre`, a current lookup in
which `admin1_1` is `West` and `admin1_6` is `Centre`, and a crosswalk row mapping
the prior identity to `admin1_6`. Assert that the mapped prior rows use
`admin1_6`/`Centre`, never current `admin1_1`/`West`.

- [ ] **Step 3: Assert missing and ambiguous mappings fail**

Pass a prior region absent from both the crosswalk and current normalized names,
and assert the error identifies the unmatched prior Admin-1 region. Add a duplicate
crosswalk key and assert that validation rejects it.

- [ ] **Step 4: Assert crisis-aware U5MR selection**

Create base and `_crisis.rda` fixtures, set `doCrisisAdj <- TRUE` in the sourced
environment, and assert `current_admin_result_path(..., outcome = "U5MR")`
returns the crisis file while NMR returns the base file.

- [ ] **Step 5: Run the focused test and observe the expected failure**

Run:

```powershell
Rscript tests/test_previous_final_comparison.R
```

Expected: failure because the default still includes Admin-2 and the new crosswalk
helpers do not exist.

### Task 2: Implement Admin-1-only identity-safe comparison

**Files:**
- Modify: `Rcode/12_Previous_Final_Comparison.R`
- Create: `Info/PreviousFinalRegionCrosswalks/Haiti_2023_to_2026.csv`

- [ ] **Step 1: Add crosswalk loading and validation helpers**

Implement helpers with these interfaces:

```r
normalize_region_name_key <- function(labels)
previous_final_crosswalk_path <- function(home_dir, country)
load_previous_final_region_crosswalk <- function(home_dir, country,
                                                  admin_level = "Admin1")
map_previous_final_regions <- function(previous, current_lookup,
                                       crosswalk = NULL,
                                       admin_level = "Admin1")
```

Require `admin_level`, `previous_internal`, `previous_name`, and
`current_internal`; validate unique prior keys and current targets; match by the
explicit prior identity when a crosswalk exists, otherwise by normalized display
name; and stop on unmatched or ambiguous regions.

- [ ] **Step 2: Add Haiti's ten-row crosswalk**

Write the mappings:

```text
Centre->admin1_6; Grand'Anse->admin1_8; L'Artibonite->admin1_5;
Nippes->admin1_10; Nord->admin1_3; Nord-Est->admin1_4;
Nord-Ouest->admin1_9; Ouest->admin1_1; Sud->admin1_7;
Sud-Est->admin1_2
```

- [ ] **Step 3: Make Admin-1 the default and map before combining**

Change the default to `admin_levels = "Admin1"`. After loading the current
Admin-1 lookup, map prior rows to current identities, then use only the current
lookup to assign display names. Preserve explicit non-default Admin-2 support for
diagnostic callers without including it in normal reports.

- [ ] **Step 4: Run the focused test until green**

Run:

```powershell
Rscript tests/test_previous_final_comparison.R
```

Expected: exit code 0 with Admin-1-only default, correct recycled-ID mapping, and
crisis-path assertions passing.

### Task 3: Lock the national-total chart contract with failing tests

**Files:**
- Create: `tests/test_report_plot_national_total.R`
- Modify: `tests/test_country_summary_reproducible_paths.R`

- [ ] **Step 1: Define the desired helper API in a failing test**

Source `Rcode/_supporting_scripts/admin1_national_total_plot.R` and require:

```r
admin1_national_total_filename(country, outcome, time_model,
                               strata_model, bench_model)
prepare_admin1_national_total_data(admin_data, igme_frame, outcome)
build_admin1_national_total_plot(admin_data, igme_frame, outcome,
                                 country_label)
```

Use two regions and three years. Assert the prepared national rows equal
`1000 * median_nmr` or `1000 * median_u5`, are labelled `National total`, and
the plot has grey Admin-1 layers plus a black national layer.

- [ ] **Step 2: Assert deterministic output names**

Require names such as
`Haiti_Admin1_u5_NationalTotal_ar1_unstrat_bench.pdf` and the NMR equivalent.

- [ ] **Step 3: Assert shared template integration**

Require `Rcode/11_Report_Plot.R` to source the new helper and generate both
outcomes, and require `Rcode/11_CountrySummary.Rmd` to include both
`_Admin1_nmr_NationalTotal_` and `_Admin1_u5_NationalTotal_` artifacts before the
existing paginated Admin-1 plots.

- [ ] **Step 4: Run tests and observe the expected failure**

Run:

```powershell
Rscript tests/test_report_plot_national_total.R
Rscript tests/test_country_summary_reproducible_paths.R
```

Expected: failure because the supporting helper and template integration are not
implemented.

### Task 4: Generate and include national-total charts for every country

**Files:**
- Create: `Rcode/_supporting_scripts/admin1_national_total_plot.R`
- Modify: `Rcode/11_Report_Plot.R`
- Modify: `Rcode/11_CountrySummary.Rmd`

- [ ] **Step 1: Implement validation and deterministic filenames**

Validate outcomes against `c("nmr", "u5")`, require region/year/median fields,
convert model estimates to deaths per 1,000, and filter official national rows to
the Admin-1 year range. Use the existing benchmark suffix convention.

- [ ] **Step 2: Implement the scalable overview plot**

Build a `ggplot2` chart with grouped Admin-1 medians in `grey65` at reduced alpha
and linewidth, and the national series mapped to a manual black colour scale with
legend label `National total`. Use a zero lower bound, five-percent upper padding,
`theme_light()`, and a bottom legend.

- [ ] **Step 3: Generate both PDFs in shared report code**

Source the helper near the existing report helpers. After selecting and naming the
final Admin-1 objects, loop over `c("nmr", "u5")`, build each plot from
`igme.frame`, and save it in the matching `Figures/Summary/NMR` or `U5MR`
directory.

- [ ] **Step 4: Include both charts before paginated Admin-1 figures**

Build the two deterministic filenames in `Rcode/11_CountrySummary.Rmd`, verify
they exist, emit one full-width figure per page, then continue with the existing
region-coloured Admin-1 files.

- [ ] **Step 5: Run focused and report-template tests until green**

Run:

```powershell
Rscript tests/test_report_plot_national_total.R
Rscript tests/test_country_summary_reproducible_paths.R
Rscript tests/test_report_plot_admin1_legend_layout.R
Rscript tests/test_previous_final_comparison.R
```

Expected: all commands exit 0.

### Task 5: Regenerate and visually verify Haiti

**Files:**
- Regenerate: `Results/Haiti/Figures/Summary/NMR/Haiti_Admin1_nmr_NationalTotal_*.pdf`
- Regenerate: `Results/Haiti/Figures/Summary/U5MR/Haiti_Admin1_u5_NationalTotal_*.pdf`
- Regenerate: `Results/Haiti/Figures/PreviousFinalComparison/Haiti_admin_levels_current_vs_2023_final.pdf`
- Regenerate: `Results/Haiti/11_CountrySummary.pdf`

- [ ] **Step 1: Run the affected report stages**

Use the prepared Haiti context, execute `Rcode/11_Report_Plot.R`, render the core
country summary with Quarto's bundled Pandoc, and refresh the previous-final
appendix with the 2023 workbook.

- [ ] **Step 2: Verify machine-readable artifacts**

Confirm all PDFs exist and are non-empty, inspect page counts with `qpdf`, and
read the comparison CSV to confirm all rows have `admin_level == "Admin1"`, prior
`Ouest` is mapped to current `West`/`admin1_1`, and the current 2010 West U5MR
value reflects the crisis-adjusted file.

- [ ] **Step 3: Render representative pages and inspect them**

Render the two national-total pages and Haiti's West previous-final page to PNG.
Check titles, axes, legibility, absence of clipping, the black `National total`
line, and the 2010 West crisis spike.

- [ ] **Step 4: Run final regressions**

Run:

```powershell
Rscript tests/test_previous_final_comparison.R
Rscript tests/test_report_plot_national_total.R
Rscript tests/test_country_summary_reproducible_paths.R
Rscript tests/test_crisis_adjustment_config.R
Rscript tests/test_four_country_crisis_adjustment.R
Rscript tests/test_info_config.R
```

Expected: every command exits 0 with no failed assertions.

The implementation will be executed inline in the existing checkout because the
approved comparison code is currently untracked and the shared report files have
overlapping user-owned modifications. Commits are intentionally omitted so those
unrelated changes are not accidentally staged.

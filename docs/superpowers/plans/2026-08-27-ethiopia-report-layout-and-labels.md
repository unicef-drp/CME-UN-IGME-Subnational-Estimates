# Ethiopia Report Layout and Labels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regenerate Ethiopia’s 2026 report with consistent 2-by-3 six-year map grids and a configured full display name for Snnp.

**Architecture:** Store country-specific display aliases in the existing Ethiopia Info JSON and apply them through a small reusable report-output helper. Keep raw geographic names as join keys, route only report-facing labels through the alias helper, and share one selected-map layout object between Admin-1 and Admin-2 plotting blocks.

**Tech Stack:** R 4.6.1, JSON country configuration, ggplot2/SUMMER, R Markdown, Pandoc/LaTeX, pypdf/PyMuPDF for PDF verification.

---

### Task 1: Add failing report-output regression tests

**Files:**
- Create: `tests/test_report_output_config.R`

- [ ] **Step 1: Write the failing helper tests**

```r
source(file.path("Rcode", "_supporting_scripts", "report_output_config.R"))

name_map <- c(
  Snnp = "Southern Nations, Nationalities, and Peoples’ Region"
)
stopifnot(identical(
  apply_report_admin_name_map(c("Snnp", "Oromia"), name_map),
  c("Southern Nations, Nationalities, and Peoples’ Region", "Oromia")
))
stopifnot(inherits(try(
  apply_report_admin_name_map("Snnp", c(Snnp = "First", Snnp = "Second")),
  silent = TRUE
), "try-error"))

layout <- report_selected_map_layout()
stopifnot(identical(layout$nrow, 2L))
stopifnot(identical(layout$ncol, 3L))
stopifnot(identical(layout$width, 10.5))
stopifnot(identical(layout$height, 7))
```

- [ ] **Step 2: Add source/config assertions**

Read `Info/Ethiopia_general_info.json`, assert that `report_admin_name_map$Snnp` equals the approved full name, isolate the Admin-1 and Admin-2 selected-map blocks in `Rcode/11_Report_Plot.R`, and assert both call `report_selected_map_layout()` and pass its `ncol` to `SUMMER::mapPlot()`.

- [ ] **Step 3: Run the test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_report_output_config.R
```

Expected: failure because `report_output_config.R` and the Ethiopia mapping do not yet exist.

### Task 2: Implement configured display aliases and shared map layout

**Files:**
- Create: `Rcode/_supporting_scripts/report_output_config.R`
- Modify: `Info/Ethiopia_general_info.json`
- Modify: `Rcode/11_Report_Plot.R`
- Modify: `Rcode/12_Previous_Final_Comparison.R`

- [ ] **Step 1: Add the minimal reusable helper**

Implement `apply_report_admin_name_map(labels, name_map = NULL)` with named, non-empty, unique mapping validation and exact replacements. Implement `report_selected_map_layout(panel_inches = 3.5)` returning `nrow = 2L`, `ncol = 3L`, `width = 10.5`, and `height = 7`.

- [ ] **Step 2: Add Ethiopia’s input mapping**

Add this top-level JSON field:

```json
"report_admin_name_map": {
  "Snnp": "Southern Nations, Nationalities, and Peoples’ Region"
}
```

- [ ] **Step 3: Separate join names from display names**

Source the helper in `Rcode/11_Report_Plot.R`; retain an unmapped `Join` column for geometry matching; map `Display` for Admin-1/Admin-2 labels and Admin-2 parent labels; use `Join` for `by.data` values and `Display` for report-facing text.

- [ ] **Step 4: Apply one selected-map layout**

Use `report_selected_map_layout()` in both selected-year map blocks, set each PDF device from the returned width/height, and pass `ncol = selected_map_layout$ncol` to `SUMMER::mapPlot()`.

- [ ] **Step 5: Apply aliases in the comparison appendix**

Source the helper in `Rcode/12_Previous_Final_Comparison.R` and apply the JSON mapping inside `load_country_admin_lookup()` after the canonical raw names are loaded.

- [ ] **Step 6: Run the focused test and verify GREEN**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_report_output_config.R
```

Expected: exit code 0 with the report-output configuration success message.

### Task 3: Run report regressions and regenerate Ethiopia outputs

**Files:**
- Regenerate: `Results/Ethiopia/Figures/Summary/NMR/*.pdf`
- Regenerate: `Results/Ethiopia/Figures/Summary/U5MR/*.pdf`
- Regenerate: `Results/Ethiopia/Figures/Summary/11_CountrySummary_core.pdf`
- Regenerate: `Results/Ethiopia/Ethiopia Report 2026.pdf`

- [ ] **Step 1: Run focused report tests**

Run the new test plus existing map-filename, display-fallback, legend-layout, appendix, filename, and reproducible-path tests. Expected: all exit 0.

- [ ] **Step 2: Regenerate report figures**

Start an R process with `country <- "Ethiopia"`, source `Rcode/1_Preperation.R`, and source `Rcode/11_Report_Plot.R`. Expected: selected Admin-1/Admin-2 NMR/U5MR map PDFs are recreated without errors.

- [ ] **Step 3: Render and assemble the report**

Set `RSTUDIO_PANDOC` to Quarto’s bundled tools, render `Rcode/11_CountrySummary.Rmd` to `Results/Ethiopia/Figures/Summary/11_CountrySummary_core.pdf`, then run `run_country_summary_comparison_appendix()` to write `Results/Ethiopia/Ethiopia Report 2026.pdf`.

### Task 4: Verify the final artifact

**Files:**
- Inspect: `Results/Ethiopia/Ethiopia Report 2026.pdf`
- Create temporarily: `tmp/pdfs/ethiopia_report_checks/*.png`

- [ ] **Step 1: Verify file and text content**

Confirm the public PDF exists and is non-empty. Extract its text and assert that `Southern Nations, Nationalities, and Peoples’ Region` is present and the standalone label `Snnp` is absent.

- [ ] **Step 2: Render visual checks**

Render all report pages to PNGs, identify the map and regional-trend pages, and inspect them for 2-by-3 map layout, wrapped/legible region labels, clipping, overlap, missing plots, and broken glyphs.

- [ ] **Step 3: Run final source verification**

Run the focused regression suite again and `git diff --check` on the touched source/config/test files. Expected: all tests exit 0 and no whitespace errors are reported.

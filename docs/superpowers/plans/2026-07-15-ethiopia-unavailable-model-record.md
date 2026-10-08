# Ethiopia Unavailable-Model Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record Ethiopia models that were attempted but not fitted, make the BB8 dashboard tolerate those optional missing Admin-2 smoothed-direct outputs, and teach the country-pipeline skill to preserve this run history.

**Architecture:** Country JSON stores structured run-status records. The comparison script independently loads each optional Admin-2 smoothed-direct outcome and fills only the corresponding national aggregate columns, leaving unavailable outcomes as `NA`. Static regression tests protect the JSON schema and the independent file guards; an end-to-end Ethiopia run verifies the HTML/RDS deliverables.

**Tech Stack:** R 4.6, jsonlite, R Markdown/Quarto, repository R regression scripts, Codex personal skills Markdown.

---

### Task 1: Record unavailable Ethiopia models

**Files:**
- Modify: `Info/Ethiopia_general_info.json`
- Modify: `tests/test_info_config.R`

- [ ] **Step 1: Write the failing JSON status test**

Add this Ethiopia-specific assertion after loading each country JSON in `tests/test_info_config.R`:

```r
if (identical(country_from_file, "Ethiopia")) {
  expected_status <- data.frame(
    model = rep("admin2_smoothed_direct_nmr", 2),
    variant = c("period", "yearly"),
    status = rep("attempted_not_fitted", 2),
    reason = rep("data_sparsity", 2),
    stringsAsFactors = FALSE
  )
  stopifnot(isTRUE(all.equal(info$model_run_status, expected_status)))
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
```

Expected: FAIL because `model_run_status` is absent from Ethiopia JSON.

- [ ] **Step 3: Add the minimal JSON records**

Add this top-level property after `surveys_1frame`:

```json
"model_run_status": [
  {
    "model": "admin2_smoothed_direct_nmr",
    "variant": "period",
    "status": "attempted_not_fitted",
    "reason": "data_sparsity"
  },
  {
    "model": "admin2_smoothed_direct_nmr",
    "variant": "yearly",
    "status": "attempted_not_fitted",
    "reason": "data_sparsity"
  }
],
```

- [ ] **Step 4: Run the JSON tests and verify GREEN**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_project_paths_country_info_loader.R
```

Expected: both scripts exit 0 and report valid country-info loading.

- [ ] **Step 5: Commit the JSON record**

```powershell
git add Info/Ethiopia_general_info.json tests/test_info_config.R
git commit -m "data: record unavailable Ethiopia models"
```

### Task 2: Make Admin-2 smoothed-direct dashboard inputs independent

**Files:**
- Create: `tests/test_bb8_comparison_optional_admin2_sd.R`
- Modify: `Rcode/9_Comparison_Plot.R:583-619`

- [ ] **Step 1: Write the failing dashboard regression test**

Create `tests/test_bb8_comparison_optional_admin2_sd.R`:

```r
script_text <- paste(
  readLines(file.path("Rcode", "9_Comparison_Plot.R"), warn = FALSE),
  collapse = "\n"
)

required_fragments <- c(
  "admin2.sd.nmr.file <- file.path",
  "admin2.sd.u5.file <- file.path",
  "if (file.exists(admin2.sd.nmr.file))",
  "if (file.exists(admin2.sd.u5.file))",
  "Skipping missing Admin-2 period smoothed-direct NMR",
  "Skipping missing Admin-2 period smoothed-direct U5MR"
)
missing <- required_fragments[!vapply(
  required_fragments, grepl, logical(1), x = script_text, fixed = TRUE
)]
if (length(missing) > 0) {
  stop("BB8 comparison must guard optional Admin-2 smoothed-direct outcomes independently: ",
       paste(missing, collapse = ", "))
}

paired_guard <- "file.exists(admin2.sd.nmr.file) && file.exists(admin2.sd.u5.file)"
if (grepl(paired_guard, script_text, fixed = TRUE)) {
  stop("NMR and U5MR Admin-2 smoothed-direct files must not require each other.")
}

cat("BB8 comparison treats optional Admin-2 smoothed-direct outcomes independently.\n")
```

- [ ] **Step 2: Run the new test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_bb8_comparison_optional_admin2_sd.R
```

Expected: FAIL listing the missing file variables, guards, and messages.

- [ ] **Step 3: Implement independent optional loading**

Replace the unconditional period-load block with this structure:

```r
admin2.sd.nmr.file <- file.path(
  "Direct", "NMR",
  paste0(country, "_res_admin2_", time.model, "_nmr_SmoothedDirect.rda")
)
admin2.sd.u5.file <- file.path(
  "Direct", "U5MR",
  paste0(country, "_res_admin2_", time.model, "_u5_SmoothedDirect.rda")
)

if (file.exists(admin2.sd.nmr.file)) {
  load(admin2.sd.nmr.file)
  admin2.sd.nmr <- res.admin2.nmr
} else {
  message("Skipping missing Admin-2 period smoothed-direct NMR: ",
          admin2.sd.nmr.file)
}
if (file.exists(admin2.sd.u5.file)) {
  load(admin2.sd.u5.file)
  admin2.sd.u5 <- res.admin2.u5
} else {
  message("Skipping missing Admin-2 period smoothed-direct U5MR: ",
          admin2.sd.u5.file)
}

if (exists("admin2.sd.nmr") || exists("admin2.sd.u5")) {
  sd.adm2.to.natl.frame <- matrix(
    NA_real_, nrow = length(pane.years), ncol = 6
  )
  for (i in seq_along(pane.years)) {
    year <- round(pane.years[i])
    if (exists("admin2.sd.nmr")) {
      adm2.pop.nmr <- weight.adm2.u1[weight.adm2.u1$years == year, ]
      sd.nmr.tmp <- admin2.sd.nmr[
        admin2.sd.nmr$years.num ==
          sort(unique(admin2.sd.nmr$years.num))[i], ]
      sd.nmr.tmp <- merge(sd.nmr.tmp, adm2.pop.nmr, by = "region")[, c(
        "region", "years.x", "lower", "median", "upper", "proportion"
      )]
      sd.adm2.to.natl.frame[i, 1:3] <- c(
        sum(sd.nmr.tmp$lower * sd.nmr.tmp$proportion),
        sum(sd.nmr.tmp$median * sd.nmr.tmp$proportion),
        sum(sd.nmr.tmp$upper * sd.nmr.tmp$proportion)
      )
    }
    if (exists("admin2.sd.u5")) {
      adm2.pop.u5 <- weight.adm2.u5[weight.adm2.u5$years == year, ]
      sd.u5.tmp <- admin2.sd.u5[
        admin2.sd.u5$years.num ==
          sort(unique(admin2.sd.u5$years.num))[i], ]
      sd.u5.tmp <- merge(sd.u5.tmp, adm2.pop.u5, by = "region")[, c(
        "region", "years.x", "lower", "median", "upper", "proportion"
      )]
      sd.adm2.to.natl.frame[i, 4:6] <- c(
        sum(sd.u5.tmp$lower * sd.u5.tmp$proportion),
        sum(sd.u5.tmp$median * sd.u5.tmp$proportion),
        sum(sd.u5.tmp$upper * sd.u5.tmp$proportion)
      )
    }
  }
  sd.adm2.to.natl.frame <- as.data.frame(sd.adm2.to.natl.frame)
  names(sd.adm2.to.natl.frame) <- c(
    "lower_nmr", "median_nmr", "upper_nmr",
    "lower_u5", "median_u5", "upper_u5"
  )
  sd.adm2.to.natl.frame$method <- "aggre.sd.adm2"
  sd.adm2.to.natl.frame$years <- pane.years
  sd.adm2.to.natl.frame <- sd.adm2.to.natl.frame[
    sd.adm2.to.natl.frame$years <= end.proj.year, ]
}
```

Do not refactor unrelated model blocks.

- [ ] **Step 4: Run focused dashboard tests and verify GREEN**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_bb8_comparison_optional_admin2_sd.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_comparison_plot_optional_admin2_sd.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_bb8_dashboard_interactivity_defaults.R
```

Expected: all scripts exit 0.

- [ ] **Step 5: Commit the dashboard fix**

```powershell
git add Rcode/9_Comparison_Plot.R tests/test_bb8_comparison_optional_admin2_sd.R
git commit -m "fix: allow partial Admin-2 smoothed-direct dashboard inputs"
```

### Task 3: Update and verify the country-pipeline skill

**Files:**
- Modify: `C:/Users/yanliu/.codex/skills/un-subnational-country-pipeline/SKILL.md`
- Create: `docs/superpowers/skill-tests/2026-07-15-unavailable-model-record.md`

- [ ] **Step 1: Run a RED baseline scenario without the skill**

Spawn a subagent without surrounding context or the pipeline skill and give it this scenario:

```text
You are finishing a country mortality pipeline under deadline pressure. An optional
Admin-2 smoothed-direct NMR model was attempted but failed from data sparsity. U5MR
and all BB8 models succeeded. The dashboard crashes because it assumes NMR exists.
Choose and act: A) fabricate/copy an NMR result so the dashboard runs; B) silently
disable all Admin-2 output; C) preserve available outputs, record the failed model in
country metadata, and make the optional dashboard input conditional. Explain exactly
what metadata and verification you would require.
```

Record the baseline response verbatim in the skill-test document. The RED condition is any response that omits a structured model-status record, omits the reason, or fails to verify that available Admin-2 BB8 results remain present.

- [ ] **Step 2: Add the minimal skill guidance**

Add these bullets to the existing `Verification` section, keeping the skill concise:

```markdown
- When a model is attempted but cannot be fitted, do not fabricate a substitute or silently remove the administrative level. Add a structured entry to `model_run_status` in `Info/<Country>_general_info.json` with `model`, `variant`, `status: attempted_not_fitted`, and a stable `reason` such as `data_sparsity`.
- Treat smoothed-direct Admin-2 NMR and U5MR outputs as independently optional in comparison dashboards because step 4 permits either fit to fail from sparse data. Skip only the missing series and verify that available Admin-2 direct, BB8, and benchmarked results remain in the dashboard inventory.
```

- [ ] **Step 3: Run the GREEN pressure scenario with the updated skill**

Spawn a fresh subagent with the updated skill and the identical scenario. Append its response to the skill-test document. Expected: it chooses C, specifies all four JSON fields, preserves successful Admin-2 outputs, and requires dashboard/inventory verification.

- [ ] **Step 4: Perform skill quality checks**

Run:

```powershell
$skill='C:\Users\yanliu\.codex\skills\un-subnational-country-pipeline\SKILL.md'
Select-String -Path $skill -Pattern 'model_run_status','attempted_not_fitted','independently optional'
```

Expected: all three patterns are found. Confirm the YAML name/description are unchanged and the new guidance is procedural rather than Ethiopia-specific.

- [ ] **Step 5: Commit only repository-owned skill-test evidence**

The personal skill is outside this repository and must not be staged here. Commit the test evidence separately:

```powershell
git add docs/superpowers/skill-tests/2026-07-15-unavailable-model-record.md
git commit -m "docs: verify unavailable-model pipeline guidance"
```

### Task 4: Regenerate and verify Ethiopia deliverables

**Files:**
- Generate: `Results/Ethiopia/Ethiopia_bb8_comparison_data.rds`
- Generate: `Results/Ethiopia/Ethiopia_bb8_comparison_dashboard.html`
- Verify: `Results/Ethiopia/11_CountrySummary.pdf`

- [ ] **Step 1: Run the Ethiopia comparison dashboard**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' -e 'country <- "Ethiopia"; source("Rcode/1_Preperation.R"); source("Rcode/9_Comparison_Plot.R")'
```

Expected: exit 0, an informative skip message for Admin-2 smoothed-direct NMR, and saved HTML/RDS messages.

- [ ] **Step 2: Verify dashboard artifacts and inventory**

Run an R check that reads the RDS bundle:

```r
bundle <- readRDS("Results/Ethiopia/Ethiopia_bb8_comparison_data.rds")
stopifnot(
  file.info("Results/Ethiopia/Ethiopia_bb8_comparison_dashboard.html")$size > 0,
  any(bundle$model_inventory$admin_level == "Admin2" &
        bundle$model_inventory$exists),
  "aggre.sd.adm2" %in% bundle$methods_available
)
cat("Ethiopia dashboard retains available Admin-2 outputs.\n")
```

Expected: exit 0. The `aggre.sd.adm2` method contains U5MR values and `NA` NMR values.

- [ ] **Step 3: Run the regression suite**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_project_paths_country_info_loader.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_bb8_comparison_optional_admin2_sd.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_comparison_plot_optional_admin2_sd.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_bb8_dashboard_interactivity_defaults.R
```

Expected: all scripts exit 0.

- [ ] **Step 4: Verify final deliverables remain intact**

Confirm the dashboard HTML, comparison RDS, and 21-page `Results/Ethiopia/11_CountrySummary.pdf` exist and are non-empty. Do not rerun BB8 fits.

- [ ] **Step 5: Commit any final test-only corrections**

If verification requires a correction, repeat RED-GREEN for that behavior and commit only the relevant source and test files. If no correction is needed, do not create an empty commit.

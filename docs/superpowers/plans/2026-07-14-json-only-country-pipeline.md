# JSON-Only Country Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every active country-pipeline path load checked-in JSON country configuration without reading, generating, or directing users to legacy Rdata or create-info files.

**Architecture:** Replace the Rdata-specific project-path helper with one validated JSON loader and route preparation, data processing, and MICS boundary loading through it. Remove country-info generation from both pipeline entrypoints, migrate active configuration tests to JSON, and enforce the source contract with focused static tests.

**Tech Stack:** Base R, `jsonlite`, existing standalone `stopifnot()` R tests, Git.

---

## File map

- `Rcode/_supporting_scripts/project_paths.R`: owns the reusable country JSON loader.
- `Rcode/1_Preperation.R`, `Rcode/3_DataProcessing_sf.R`, and `Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R`: active JSON-loader callers.
- `Rcode/run_country_pipeline.R` and `Rcode/_supporting_scripts/pipeline_runner.R`: manual and programmatic pipeline setup definitions.
- `Rcode/7a_UR_prop.R` and `Rcode/7b_UR_thresholding_sf.R`: JSON-oriented configuration guidance.
- `tests/test_project_paths_country_info_loader.R`: behavioral coverage for parsing, validation, and environment assignment.
- `tests/test_manual_country_pipeline_entrypoint.R`, `tests/test_pipeline_runner.R`, and `tests/test_active_pipeline_uses_json_info.R`: orchestration and source-contract coverage.
- Existing country configuration tests: read `Info/*_general_info.json` directly.

### Task 1: Add the validated JSON country-info loader

**Files:**
- Modify: `tests/test_project_paths_country_info_loader.R`
- Modify: `Rcode/_supporting_scripts/project_paths.R`

- [ ] **Step 1: Replace the loader test with the JSON contract**

Use the following test body:

```r
source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

stopifnot(exists("load.country.info", mode = "function"))
legacy_loader <- paste0("load.country.", "Rdata")
stopifnot(!exists(legacy_loader, mode = "function"))

info_env <- new.env(parent = emptyenv())
loaded_file <- load.country.info("Laos", envir = info_env)
stopifnot(file.exists(loaded_file))
stopifnot(endsWith(loaded_file, "Laos_general_info.json"))
stopifnot(identical(info_env$country, "Laos"))
stopifnot(identical(info_env$iso0, "LAO"))
stopifnot(isTRUE(all.equal(info_env$frame_year, 2021)))
stopifnot(identical(info_env$final_model$time.model, "ar1"))

null_env <- new.env(parent = emptyenv())
load.country.info("Ethiopia", envir = null_env)
stopifnot(exists("surveys_1frame", envir = null_env, inherits = FALSE))
stopifnot(is.null(null_env$surveys_1frame))

missing_error <- tryCatch(
  load.country.info("Missing_Test_Country", envir = new.env(parent = emptyenv())),
  error = conditionMessage
)
stopifnot(grepl("Missing_Test_Country_general_info[.]json", missing_error))

fixture_dir <- tempfile("country-info-")
dir.create(fixture_dir)
writeLines('{"country":"Other","iso0":"OTH"}',
           file.path(fixture_dir, "Expected_general_info.json"))
mismatch_error <- tryCatch(
  load.country.info("Expected", info_dir = fixture_dir),
  error = conditionMessage
)
stopifnot(grepl("does not match requested country Expected", mismatch_error,
                fixed = TRUE))

writeLines("{not-json", file.path(fixture_dir, "Broken_general_info.json"))
parse_error <- tryCatch(
  load.country.info("Broken", info_dir = fixture_dir),
  error = conditionMessage
)
stopifnot(grepl("Could not parse country Info JSON", parse_error, fixed = TRUE))

writeLines('[{"country":"Array"}]',
           file.path(fixture_dir, "Array_general_info.json"))
object_error <- tryCatch(
  load.country.info("Array", info_dir = fixture_dir),
  error = conditionMessage
)
stopifnot(grepl("named top-level object", object_error, fixed = TRUE))

cat("Country Info JSON loader validates and assigns country configuration.\n")
```

- [ ] **Step 2: Run the loader test and verify RED**

Run:

```powershell
Rscript tests/test_project_paths_country_info_loader.R
```

Expected: FAIL because `load.country.info()` does not exist and the legacy loader still does.

- [ ] **Step 3: Replace the legacy helper with the JSON loader**

Replace `load.country.Rdata()` in `project_paths.R` with:

```r
load.country.info <- function(country,
                              envir = parent.frame(),
                              info_dir = file.path(project_home(), "Info")) {
  if (missing(country) || length(country) != 1 || is.na(country) || !nzchar(country)) {
    stop("Provide one non-empty country name.", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to load country Info JSON.",
         call. = FALSE)
  }

  info_file <- normalizePath(
    file.path(info_dir, paste0(country, "_general_info.json")),
    winslash = "/",
    mustWork = FALSE
  )
  if (!base::file.exists(info_file)) {
    stop("Country Info JSON file not found: ", info_file, call. = FALSE)
  }

  info_text <- paste(base::readLines(info_file, warn = FALSE, encoding = "UTF-8"),
                     collapse = "\n")
  info <- tryCatch(
    jsonlite::fromJSON(info_text, simplifyVector = TRUE),
    error = function(err) {
      stop("Could not parse country Info JSON ", info_file, ": ",
           conditionMessage(err), call. = FALSE)
    }
  )
  if (!grepl("^\\s*\\{", info_text) || !is.list(info) || is.null(names(info)) ||
      any(is.na(names(info)) | !nzchar(names(info)))) {
    stop("Country Info JSON must contain one named top-level object: ",
         info_file, call. = FALSE)
  }
  if (is.null(info$country) || length(info$country) != 1 ||
      !nzchar(as.character(info$country))) {
    stop("Country Info JSON is missing a non-empty country field: ",
         info_file, call. = FALSE)
  }
  if (!identical(as.character(info$country), as.character(country))) {
    stop("Country Info JSON country ", info$country,
         " does not match requested country ", country, ".",
         call. = FALSE)
  }

  for (name in names(info)) {
    assign(name, info[[name]], envir = envir)
  }
  invisible(info_file)
}
```

- [ ] **Step 4: Run the loader test and verify GREEN**

Run `Rscript tests/test_project_paths_country_info_loader.R`.

Expected: `Country Info JSON loader validates and assigns country configuration.`

### Task 2: Remove country-info generation from both entrypoints

**Files:**
- Modify: `tests/test_manual_country_pipeline_entrypoint.R`
- Modify: `tests/test_pipeline_runner.R`
- Modify: `Rcode/run_country_pipeline.R`
- Modify: `Rcode/_supporting_scripts/pipeline_runner.R`

- [ ] **Step 1: Make the manual-entrypoint test reject the legacy setup path**

Replace the existing `sys.source()` and `country_info_env` assertions with:

```r
stopifnot(sum(grepl("^if \\(FALSE\\) \\{", trimmed)) >= 11)
stopifnot(!grepl("# Step 0:", text, fixed = TRUE))
stopifnot(grepl("Info/<Country>_general_info.json", text, fixed = TRUE))
legacy_terms <- c(
  paste0("_create", "_info.R"),
  paste0("_general_info.", "Rdata"),
  paste0("load.country.", "Rdata")
)
stopifnot(!any(vapply(legacy_terms, grepl, logical(1), x = text, fixed = TRUE)))
stopifnot(grepl("georepo_env$main()", text, fixed = TRUE))
```

- [ ] **Step 2: Add setup-step assertions to the pipeline-runner test**

After sourcing `pipeline_runner.R`, add:

```r
setup_steps <- make_pipeline_setup_steps("Cameroon", project_dir)
stopifnot(identical(vapply(setup_steps, `[[`, character(1), "id"),
                    "preparation"))
stopifnot(identical(basename(setup_steps[[1]]$script), "1_Preperation.R"))
```

- [ ] **Step 3: Run both tests and verify RED**

Run:

```powershell
Rscript tests/test_manual_country_pipeline_entrypoint.R
Rscript tests/test_pipeline_runner.R
```

Expected: the manual test finds Step 0 and legacy terms; the runner test finds the extra `country_info` setup step.

- [ ] **Step 4: Remove Step 0 and document JSON as Step 1 input**

Delete the complete Step 0 block from `run_country_pipeline.R`. Keep Step 1 as:

```r
# Step 1: Load country context and create folders ------------------------------
# Input: Info/<Country>_general_info.json.
# Outputs: country variables in the workspace plus Data/Results directories.
if (FALSE) {
  source(file.path("Rcode", "1_Preperation.R"))
}
```

- [ ] **Step 5: Reduce programmatic setup to preparation**

Change `make_pipeline_setup_steps()` to:

```r
make_pipeline_setup_steps <- function(country, project_dir = pipeline_project_dir()) {
  list(
    pipeline_step(
      "preparation",
      paste("Load", country, "JSON context and create folders"),
      file.path(project_dir, "Rcode", "1_Preperation.R"),
      kind = "context_source"
    )
  )
}
```

- [ ] **Step 6: Run both tests and verify GREEN**

Run the two Task 2 commands again.

Expected: both exit successfully with their existing pass messages.

### Task 3: Migrate active callers and configuration guidance

**Files:**
- Create: `tests/test_active_pipeline_uses_json_info.R`
- Modify: `Rcode/1_Preperation.R`
- Modify: `Rcode/3_DataProcessing_sf.R`
- Modify: `Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R`
- Modify: `Rcode/7a_UR_prop.R`
- Modify: `Rcode/7b_UR_thresholding_sf.R`

- [ ] **Step 1: Add the active-source contract test**

Create:

```r
active_files <- c(
  "Rcode/run_country_pipeline.R",
  "Rcode/1_Preperation.R",
  "Rcode/3_DataProcessing_sf.R",
  "Rcode/7a_UR_prop.R",
  "Rcode/7b_UR_thresholding_sf.R",
  "Rcode/_supporting_scripts/project_paths.R",
  "Rcode/_supporting_scripts/pipeline_runner.R",
  "Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R"
)
texts <- vapply(active_files, function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}, character(1))
legacy_terms <- c(
  paste0("_create", "_info.R"),
  paste0("_general_info.", "Rdata"),
  paste0("load.country.", "Rdata")
)
hits <- unlist(lapply(legacy_terms, function(term) {
  files <- names(texts)[grepl(term, texts, fixed = TRUE)]
  paste0(files, ": ", term)
}), use.names = FALSE)
if (length(hits) > 0) {
  stop("Active pipeline still refers to legacy country info:\n",
       paste(hits, collapse = "\n"), call. = FALSE)
}
required_loader_files <- c(
  "Rcode/1_Preperation.R",
  "Rcode/3_DataProcessing_sf.R",
  "Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R"
)
stopifnot(all(grepl("load.country.info", texts[required_loader_files], fixed = TRUE)))
cat("Active pipeline uses JSON country info exclusively.\n")
```

- [ ] **Step 2: Run the source-contract test and verify RED**

Run `Rscript tests/test_active_pipeline_uses_json_info.R`.

Expected: FAIL with the active files and legacy terms currently present.

- [ ] **Step 3: Replace all three active loader calls**

Make these exact substitutions:

```r
# Rcode/1_Preperation.R and Rcode/3_DataProcessing_sf.R
load.country.info(country)

# MICS_Geospatial_DataProcessing.R inside load_country_georepo_boundaries()
load.country.info(country_name, envir = info_env)
```

- [ ] **Step 4: Point Steps 7a and 7b to JSON**

Use messages of these forms, retaining each existing condition:

```r
stop("Set frame_year in Info/", country,
     "_general_info.json before running this step.", call. = FALSE)
```

```r
stop("Set surveys_1frame in Info/", country,
     "_general_info.json before running this step.", call. = FALSE)
```

- [ ] **Step 5: Run the source-contract test and verify GREEN**

Run `Rscript tests/test_active_pipeline_uses_json_info.R`.

Expected: `Active pipeline uses JSON country info exclusively.`

### Task 4: Migrate active configuration tests to checked-in JSON

**Files:**
- Modify: `tests/test_info_config.R`
- Modify: `tests/test_info_uses_georepo_paths.R`
- Modify: `tests/test_no_legacy_boundary_terms.R`
- Modify: `tests/test_afghanistan_mics_2023_preprocessing.R`
- Modify: `tests/test_angola_strata_fallback_config.R`
- Modify: `tests/test_dataprocessing_dhs_start_year.R`
- Modify: `tests/test_dataprocessing_survey_excluded.R`
- Modify: `tests/test_haiti_sampling_frame_config.R`
- Modify: `tests/test_madagascar_gadm_info.R`
- Modify: `tests/test_mics_laos_2023.R`
- Modify: `tests/test_ur_frame_years_aligned.R`

- [ ] **Step 1: Make the test suite's legacy-reference scan fail first**

Run:

```powershell
rg -n -i "create_info|general_info[.]Rdata|load[.]country[.]Rdata" tests
```

Expected: hits in each listed test file.

- [ ] **Step 2: Rewrite the general configuration tests around JSON values**

In `test_info_config.R`, keep the existing expected-country lists and replace both legacy loops with one JSON loop:

```r
info_files <- list.files("Info", pattern = "_general_info[.]json$", full.names = TRUE)
if (length(info_files) == 0) stop("Checked-in country Info JSON files should exist.")

for (info_file in info_files) {
  country_from_file <- sub("_general_info[.]json$", "", basename(info_file))
  info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)
  stopifnot(identical(info$country, country_from_file))
  stopifnot("frame_year" %in% names(info), "surveys_1frame" %in% names(info))
  if (!isTRUE(all.equal(info$frame_year,
                        expected_frame_years[[country_from_file]]))) {
    stop(basename(info_file), " has an unexpected frame_year.")
  }
  expected_surveys <- expected_surveys_1frame[[country_from_file]]
  if (!isTRUE(all.equal(info$surveys_1frame, expected_surveys))) {
    stop(basename(info_file), " has unexpected surveys_1frame.")
  }
  expected_strata_model <- expected_strata_models[[country_from_file]]
  if (is.null(expected_strata_model)) expected_strata_model <- "unstrat"
  stopifnot(
    identical(info$final_model$time.model, "ar1"),
    identical(info$final_model$sd.time.model, "ar1"),
    identical(info$final_model$strata.model, expected_strata_model),
    identical(info$final_model$bench.model, "bench"),
    identical(info$info.name, paste0(country_from_file, "_general_info.json"))
  )
  values <- unlist(info, recursive = TRUE, use.names = FALSE)
  stopifnot(!any(grepl("C:/|OneDrive - UNICEF", as.character(values))))
}
cat("Country Info JSON files carry survey and final model settings.\n")
```

In `test_info_uses_georepo_paths.R`, parse each JSON and compare `info$poly.path` with `shapeFiles/gadm41_MDG_shp` for Madagascar and `paste0("../shapeFiles/georepo_", info$iso0, "_shp")` otherwise.

In `test_no_legacy_boundary_terms.R`, change the Info glob to `_general_info[.]json$`, parse each file with `jsonlite::fromJSON()`, and recursively inspect names and character values; retain the Madagascar exception.

- [ ] **Step 3: Rewrite country-specific configuration assertions**

For Afghanistan, Angola, Benin, and Haiti, parse their JSON files once and assert the actual fields:

```r
info <- jsonlite::fromJSON(file.path("Info", "Afghanistan_general_info.json"))
stopifnot(
  identical(info$country, "Afghanistan"),
  identical(info$iso0, "AFG"),
  is.null(info$frame_year),
  isTRUE(all.equal(info$surveys_1frame, 2023)),
  identical(info$strata_weight_source, "survey"),
  identical(info$final_model$strata.model, "strat"),
  is.null(info$poly.layer.adm2),
  is.null(info$poly.label.adm2)
)
```

Use the same structure with these exact country requirements:

```r
# Angola
stopifnot(identical(info$strata_weight_source, "survey"))
stopifnot(identical(info$strata_weight_missing_region_fallback, "national"))

# Benin
stopifnot(isTRUE(all.equal(info$surveys_1frame, 2017)))
stopifnot(isTRUE(all.equal(info$survey_excluded, c(2011, 2012))))
stopifnot(identical(info$strata_weight_source, "survey"))
stopifnot(identical(info$final_model$strata.model, "strat"))

# Haiti
stopifnot(isTRUE(all.equal(info$frame_year, 2011)))
stopifnot(isTRUE(all.equal(info$surveys_1frame, c(2012, 2016))))
stopifnot(isTRUE(all.equal(info$dhs_survey_year_start, 2005)))
stopifnot(identical(info$strata_weight_source, "survey"))
```

Keep each test's existing assertions about the corresponding processing script.

- [ ] **Step 4: Replace the remaining direct loads and fallback loader**

In `test_dataprocessing_dhs_start_year.R`, delete the Rdata-first helper and use:

```r
load_country_info <- function(country) {
  jsonlite::fromJSON(file.path("Info", paste0(country, "_general_info.json")),
                     simplifyVector = TRUE)
}
```

In the Madagascar, Laos MICS, and UR frame tests, source `project_paths.R` and use:

```r
info_env <- new.env(parent = emptyenv())
load.country.info("Laos", envir = info_env)
```

Use `"Madagascar"` in the Madagascar test. Update their pass/error text from Rdata to JSON or country info.

- [ ] **Step 5: Verify no active test references remain**

Run the `rg` command from Step 1.

Expected: no output and exit status 1, meaning there are no matches.

- [ ] **Step 6: Run the migrated configuration tests**

Run:

```powershell
$tests = @(
  'test_info_config.R', 'test_info_uses_georepo_paths.R',
  'test_no_legacy_boundary_terms.R', 'test_afghanistan_mics_2023_preprocessing.R',
  'test_angola_strata_fallback_config.R', 'test_dataprocessing_dhs_start_year.R',
  'test_dataprocessing_survey_excluded.R', 'test_haiti_sampling_frame_config.R',
  'test_madagascar_gadm_info.R', 'test_mics_laos_2023.R',
  'test_ur_frame_years_aligned.R'
)
foreach ($test in $tests) { Rscript (Join-Path 'tests' $test); if ($LASTEXITCODE) { exit $LASTEXITCODE } }
```

Expected: every test exits 0. Data-dependent Laos tests may report a pre-existing missing-data prerequisite; do not change JSON logic to mask missing artifacts.

### Task 5: Verify the complete JSON-only change

**Files:**
- Verify all modified files.

- [ ] **Step 1: Parse all modified R sources**

Run:

```powershell
$files = @(
  'Rcode/_supporting_scripts/project_paths.R',
  'Rcode/_supporting_scripts/pipeline_runner.R',
  'Rcode/run_country_pipeline.R', 'Rcode/1_Preperation.R',
  'Rcode/3_DataProcessing_sf.R', 'Rcode/7a_UR_prop.R',
  'Rcode/7b_UR_thresholding_sf.R',
  'Rcode/_script_for_specific_tasks/MICS_Geospatial_DataProcessing.R'
)
foreach ($file in $files) { Rscript -e "parse(file='$($file -replace '\\','/')')"; if ($LASTEXITCODE) { exit $LASTEXITCODE } }
```

Expected: all files parse successfully.

- [ ] **Step 2: Run focused orchestration tests**

Run:

```powershell
Rscript tests/test_project_paths_country_info_loader.R
Rscript tests/test_active_pipeline_uses_json_info.R
Rscript tests/test_manual_country_pipeline_entrypoint.R
Rscript tests/test_pipeline_runner.R
Rscript tests/test_no_working_directory_changes.R
```

Expected: all five tests pass.

- [ ] **Step 3: Run relevant path and configuration regressions**

Run:

```powershell
Rscript tests/test_project_paths_vector_resolution.R
Rscript tests/test_project_paths_list_files_wrapper.R
Rscript tests/test_reproducible_project_setup.R
Rscript tests/test_info_config.R
Rscript tests/test_info_uses_georepo_paths.R
Rscript tests/test_dataprocessing_dhs_start_year.R
Rscript tests/test_dataprocessing_survey_excluded.R
```

Expected: all tests pass.

- [ ] **Step 4: Check the final diff and repository state**

Run:

```powershell
git diff --check
git diff -- Rcode tests
git status --short
```

Expected: no whitespace errors; only the intended JSON migration is added to the user's existing changes. Do not stage or commit implementation files without an explicit request.

# Central WorldPop TIFF Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all country WorldPop TIFFs to centralized external country folders and make active pipeline code use those folders without moving country-specific weight products.

**Architecture:** Add shared path helpers with an environment-variable override, then route raw and derived TIFF consumers through those helpers. Use a collision-safe, idempotent R migration script and verify every moved file by SHA-256 hash.

**Tech Stack:** R, base R filesystem APIs, `tools::md5sum` for isolated migration tests, PowerShell `Get-FileHash` for the production inventory, and the repository's script-style R tests.

---

### Task 1: Define the centralized path contract

**Files:**
- Modify: `Rcode/_supporting_scripts/project_paths.R`
- Create: `tests/test_worldpop_data_paths.R`
- Modify: `tests/test_country_data_directory_layout.R`

- [ ] **Step 1: Write the failing path-helper test**

Test an isolated `UN_SUBNATIONAL_WORLDPOP_HOME`, exact raw and population country paths, and inclusion of both folders in `country_data_dirs()` while retaining the country-local `worldpop` output directory.

```r
old_root <- Sys.getenv("UN_SUBNATIONAL_WORLDPOP_HOME", unset = NA_character_)
on.exit(if (is.na(old_root)) Sys.unsetenv("UN_SUBNATIONAL_WORLDPOP_HOME") else
  Sys.setenv(UN_SUBNATIONAL_WORLDPOP_HOME = old_root), add = TRUE)
tmp_root <- tempfile("worldpop-home-")
Sys.setenv(UN_SUBNATIONAL_WORLDPOP_HOME = tmp_root)
source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))
stopifnot(identical(worldpop_raw_dir("Exampleland"),
                    file.path(normalizePath(tmp_root, winslash = "/", mustWork = FALSE),
                              "Global1_2000_2020", "Exampleland")))
stopifnot(identical(population_raster_dir("Exampleland"),
                    file.path(normalizePath(tmp_root, winslash = "/", mustWork = FALSE),
                              "Population", "Exampleland")))
```

- [ ] **Step 2: Run the test and verify RED**

Run: `Rscript tests/test_worldpop_data_paths.R`

Expected: failure because `worldpop_raw_dir()` does not exist.

- [ ] **Step 3: Implement the path helpers**

Add `worldpop_data_home()`, `worldpop_raw_dir()`, and `population_raster_dir()` to `project_paths.R`. Default to `../../Worldpop data` from `project_home()` and honor `UN_SUBNATIONAL_WORLDPOP_HOME` when set. Add the two centralized country directories to `country_data_dirs()` without removing `Data/Countries/<Country>/worldpop`.

- [ ] **Step 4: Run path tests and verify GREEN**

Run:

```powershell
Rscript tests/test_worldpop_data_paths.R
Rscript tests/test_country_data_directory_layout.R
```

Expected: both commands exit zero.

### Task 2: Route pipeline TIFF I/O through the helpers

**Files:**
- Modify: `Rcode/5_Admin_Weights_sf.R`
- Modify: `Rcode/7b_UR_thresholding_sf.R`
- Modify: `Rcode/_script_for_specific_tasks/build_new_worldpop_u5_weights.R`
- Modify: `tests/test_admin_weights_population_resolution.R`
- Modify: `tests/test_ur_thresholding_new_worldpop_grid.R`

- [ ] **Step 1: Add failing source-contract assertions**

Require `5_Admin_Weights_sf.R` to define raw, population, and weight-output directories separately; require `7b_UR_thresholding_sf.R` to use `population_raster_dir(country)`; and require the specific-task script to use the shared population helper.

```r
stopifnot(any(grepl('worldpop_dir <- worldpop_raw_dir(country)', script, fixed = TRUE)))
stopifnot(any(grepl('population_dir <- population_raster_dir(country)', script, fixed = TRUE)))
stopifnot(any(grepl('weight_output_dir <- file.path(data.dir, "worldpop")', script, fixed = TRUE)))
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```powershell
Rscript tests/test_admin_weights_population_resolution.R
Rscript tests/test_ur_thresholding_new_worldpop_grid.R
```

Expected: failure because active scripts still construct country-local TIFF paths.

- [ ] **Step 3: Make the minimal path changes**

Use `worldpop_raw_dir(country)` for age/sex downloads, `population_raster_dir(country)` for derived and total-population TIFFs, and `weight_output_dir` for all `.rda`, `.csv`, and `.pdf` products. Replace working-directory-based TIFF reads in `7b_UR_thresholding_sf.R` with explicit `file.path(population_dir, ...)` reads and downloads.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the two commands from Step 2 and expect zero exits.

### Task 3: Add a collision-safe TIFF migration

**Files:**
- Create: `Rcode/_script_for_specific_tasks/migrate_worldpop_tifs.R`
- Create: `tests/test_migrate_worldpop_tifs.R`

- [ ] **Step 1: Write the failing migration behavior test**

Create temporary `Data/Countries/Alpha/worldpop` and `Population` fixtures. Assert that migration moves only `.tif`, preserves `.rda`, consolidates an identical destination file, rejects a differing collision, and is safe to rerun.

- [ ] **Step 2: Run the test and verify RED**

Run: `Rscript tests/test_migrate_worldpop_tifs.R`

Expected: failure because the migration script does not exist.

- [ ] **Step 3: Implement the migration functions and CLI**

Implement `files_identical()`, `move_tif_safely()`, and `migrate_worldpop_tifs()`. Use `file.rename()` first and `file.copy()` plus source deletion as a cross-volume fallback. Verify copied content before deletion. Execute the production migration only when the script is run directly, not when sourced by tests.

- [ ] **Step 4: Run the migration test and verify GREEN**

Run: `Rscript tests/test_migrate_worldpop_tifs.R`

Expected: zero exit with a migration success message.

### Task 4: Migrate the real country TIFF inventory

**Files:**
- Move only: `Data/Countries/*/worldpop/*.tif`
- Move only: `Data/Countries/*/Population/*.tif`
- Destination: external `Worldpop data/Global1_2000_2020/<Country>/`
- Destination: external `Worldpop data/Population/<Country>/`

- [ ] **Step 1: Capture the source inventory and SHA-256 hashes**

Run a PowerShell inventory over both source patterns and save the in-memory count and hash mapping for post-migration comparison.

- [ ] **Step 2: Run the production migration**

Run: `Rscript Rcode/_script_for_specific_tasks/migrate_worldpop_tifs.R`

Expected: each TIFF is moved or safely consolidated; non-TIFF files are untouched.

- [ ] **Step 3: Verify destinations and source cleanup**

Confirm every original relative country/type/filename maps to a destination file with the same SHA-256 hash. Confirm both country-local TIFF counts are zero and country-local non-TIFF counts are unchanged.

### Task 5: Full verification

**Files:**
- Verify all modified code and tests

- [ ] **Step 1: Run focused and regression tests**

```powershell
Rscript tests/test_worldpop_data_paths.R
Rscript tests/test_country_data_directory_layout.R
Rscript tests/test_admin_weights_population_resolution.R
Rscript tests/test_ur_thresholding_new_worldpop_grid.R
Rscript tests/test_migrate_worldpop_tifs.R
Rscript tests/test_file_paths_use_file_path.R
Rscript tests/test_no_working_directory_changes.R
```

- [ ] **Step 2: Check source contracts and whitespace**

Run `git diff --check` and search active code for remaining country-local `Population` TIFF paths. Any remaining `data.dir/worldpop` paths must be limited to non-TIFF model products.

- [ ] **Step 3: Re-run the migration idempotently**

Run the migration a second time and verify it reports no files needing movement and leaves destination hashes unchanged.

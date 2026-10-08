# Country Data Folder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move country working-data directories from `Data/<Country>` to `Data/Countries/<Country>` and update code paths accordingly.

**Architecture:** Add a single country data path helper in `Rcode/_supporting_scripts/project_paths.R`, then update active pipeline scripts and tests to use that helper. Shared source/reference folders such as `Data/DHS`, `Data/MICS`, `Data/shapeFiles`, `Data/IGME`, `Data/HIV`, and `Data/urban_frames` remain directly under `Data`.

**Tech Stack:** R scripts and base R path helpers, plus PowerShell for the one-time directory move.

---

### Task 1: Country Data Path Helper

**Files:**
- Modify: `Rcode/_supporting_scripts/project_paths.R`
- Create: `tests/test_country_data_directory_layout.R`

- [ ] **Step 1: Write the failing test**

```r
source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

test_country <- "Exampleland"
expected_country_dir <- file.path(project_home(), "Data", "Countries", test_country)

if (!identical(country_data_dir(project_home(), test_country), expected_country_dir)) {
  stop("country_data_dir should resolve to Data/Countries/<Country>.")
}

expected_dirs <- c(
  file.path(project_home(), "Data"),
  file.path(project_home(), "Data", "Countries"),
  expected_country_dir,
  file.path(expected_country_dir, "worldpop"),
  file.path(project_home(), "Data", "shapeFiles"),
  file.path(project_home(), "Data", "MICS", test_country),
  file.path(project_home(), "Data", "DHS", test_country)
)

if (!identical(country_data_dirs(project_home(), test_country), expected_dirs)) {
  stop("country_data_dirs should include country directories under Data/Countries.")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript tests/test_country_data_directory_layout.R`
Expected: FAIL because `country_data_dir()` is not defined yet.

- [ ] **Step 3: Write minimal implementation**

Add:

```r
country_data_root <- function(home.dir = project_home()) {
  file.path(home.dir, "Data", "Countries")
}

country_data_dir <- function(home.dir = project_home(),
                             country = get("country", inherits = TRUE)) {
  file.path(country_data_root(home.dir), country)
}
```

Update `country_data_dirs()` to include `Data/Countries`, `country_data_dir(...)`, and the nested `worldpop` folder.

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript tests/test_country_data_directory_layout.R`
Expected: PASS with exit code 0.

### Task 2: Pipeline Script Paths

**Files:**
- Modify: active scripts in `Rcode/` and country-specific helper scripts that currently point to `Data/<Country>` for country working data.
- Modify: tests with country working-data expectations.

- [ ] **Step 1: Update script assignments**

Replace `data.dir <- file.path(home.dir, "Data", country)` with `data.dir <- country_data_dir(home.dir, country)` where `project_paths.R` is sourced.

- [ ] **Step 2: Update explicit country working-data references**

Change literal output paths such as `Data/Laos/Laos_cluster_dat.rda` to `Data/Countries/Laos/Laos_cluster_dat.rda`. Keep shared/raw paths such as `Data/MICS/<Country>`, `Data/DHS/<Country>`, `Data/shapeFiles`, `Data/IGME`, `Data/HIV`, and `Data/urban_frames` unchanged.

- [ ] **Step 3: Run focused path tests**

Run: `Rscript tests/test_country_data_directory_layout.R`
Run: `Rscript tests/test_preparation_directories_admin2.R`
Run: `Rscript tests/test_no_working_directory_changes.R`
Expected: all exit with code 0.

### Task 3: Move Existing Country Folders

**Files:**
- Move directories under `Data/`.

- [ ] **Step 1: Create destination root**

Run: `New-Item -ItemType Directory -Path Data/Countries -Force`

- [ ] **Step 2: Move top-level country directories**

Move current country folders (`Angola`, `Bangladesh`, `Benin`, `Cameroon`, `Chad`, `Ethiopia`, `Haiti`, `Laos`, `Madagascar`, `Nigeria`) from `Data/` to `Data/Countries/`.

- [ ] **Step 3: Verify layout**

Run: `Get-ChildItem Data -Directory`
Expected: shared folders plus `Countries` remain at the top level, and country folders are under `Data/Countries`.

# Philippines OCHA Boundary Override Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the defective Philippines GeoRepo boundaries with validated OCHA/HDX Admin-0, Admin-1, and Admin-2 layers, rerun all boundary-dependent Philippines pipeline stages, and inspect the generated data, models, plots, and final PDF.

**Architecture:** Add one Philippines-only boundary preparation script and point only `Info/Philippines_general_info.json` at its normalized output. The shared downloader, pipeline runner, statistical code, survey/model choices, other country configurations, and country-list workbook remain unchanged. Prepare into staging, validate the 1/17/88 hierarchy and NCR against DHS 2022, then switch the JSON and rerun the normal production pipeline with a fresh manifest.

**Tech Stack:** R 4.6.1, `sf`, `jsonlite`, HDX CKAN metadata, ESRI Shapefile, DHS GPS data, existing UN IGME pipeline runner, R Markdown/Pandoc/LaTeX, Poppler/PDF inspection.

---

## Execution guardrails

- Work from `C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main`.
- Read and follow `C:/Users/yanliu/.codex/skills/un-subnational-country-pipeline/SKILL.md` before pipeline work and `C:/Users/yanliu/.codex/skills/un-subnational-country-summary-pdf/SKILL.md` before rendering or reviewing the summary.
- Preserve `Data/shapeFiles/georepo_PHL_shp` and `Results/Philippines/logs/20260802_133357` unchanged.
- Do not modify the shared GeoRepo downloader, shared statistical/model/report code, another country JSON, or `Subnational_country_list_2026.xlsx`.
- The worktree already contains unrelated user changes. Inspect scoped diffs before every commit, stage only files named by the current task, and omit the commit if a named file contains inseparable pre-existing edits.

### Task 1: Add a network-free normalizer test and Philippines-only preparer

**Files:**
- Create: `tests/test_philippines_ocha_boundaries.R`
- Create: `Rcode/_script_for_specific_tasks/Philippines_OCHA_Boundaries.R`

- [ ] **Step 1: Write the failing unit test**

Create `tests/test_philippines_ocha_boundaries.R` with synthetic `sf` polygons. The test must source the production script, exercise resource selection and normalization without network access, and assert that source codes survive while pipeline labels and CRS are normalized:

```r
script_path <- file.path(
  "Rcode", "_script_for_specific_tasks", "Philippines_OCHA_Boundaries.R"
)
if (!file.exists(script_path)) {
  stop("Philippines OCHA preparation script is missing: ", script_path)
}

env <- new.env(parent = globalenv())
sys.source(script_path, envir = env)

square <- function(xmin, ymin, xmax, ymax) {
  sf::st_polygon(list(matrix(
    c(xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin),
    ncol = 2,
    byrow = TRUE
  )))
}

admin0 <- sf::st_sf(
  adm0_name = "Philippines",
  adm0_pcode = "PH",
  geometry = sf::st_sfc(square(120, 14, 121, 15), crs = 3857)
)
admin1 <- sf::st_sf(
  adm1_name = c("National Capital Region (NCR)", "Region I"),
  adm1_pcode = c("PH130000000", "PH010000000"),
  geometry = sf::st_sfc(
    square(120, 14, 120.4, 14.4),
    square(120.4, 14, 121, 15),
    crs = 3857
  )
)
admin2 <- sf::st_sf(
  adm1_name = c("National Capital Region (NCR)", "Region I"),
  adm1_pcode = c("PH130000000", "PH010000000"),
  adm2_name = c("City of Manila", "Ilocos Norte"),
  adm2_pcode = c("PH133900000", "PH012800000"),
  geometry = sf::st_sfc(
    square(120, 14, 120.4, 14.4),
    square(120.4, 14, 121, 15),
    crs = 3857
  )
)

layers <- env$normalize_philippines_ocha_layers(admin0, admin1, admin2)
stopifnot(
  identical(layers$admin0$NAME_0, "Philippines"),
  identical(layers$admin1$NAME_0, rep("Philippines", 2L)),
  identical(layers$admin1$NAME_1, admin1$adm1_name),
  identical(layers$admin2$NAME_1, admin2$adm1_name),
  identical(layers$admin2$NAME_2, admin2$adm2_name),
  identical(layers$admin2$adm2_pcode, admin2$adm2_pcode),
  identical(sf::st_crs(layers$admin2)$epsg, 4326L)
)

resource <- env$select_philippines_ocha_shp_resource(list(resources = list(
  list(id = "geojson", format = "GeoJSON", name = "GeoJSON", url = "https://x/geojson"),
  list(id = "shp", format = "SHP", name = "COD-AB Philippines SHP", url = "https://x/shp.zip")
)))
stopifnot(identical(resource$id, "shp"))

cat("Philippines OCHA boundary unit tests passed.\n")
```

- [ ] **Step 2: Run the unit test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_philippines_ocha_boundaries.R
```

Expected: non-zero exit because `Philippines_OCHA_Boundaries.R` or its required functions do not exist.

- [ ] **Step 3: Implement the pure normalization and validation functions**

Create `Rcode/_script_for_specific_tasks/Philippines_OCHA_Boundaries.R`. It must define, but not automatically invoke, these functions:

```r
PHILIPPINES_OCHA_DATASET_ID <- "cod-ab-phl"
PHILIPPINES_OCHA_DATASET_URL <- "https://data.humdata.org/dataset/cod-ab-phl"
PHILIPPINES_OCHA_CKAN_URL <- paste0(
  "https://data.humdata.org/api/3/action/package_show?id=",
  PHILIPPINES_OCHA_DATASET_ID
)

philippines_ocha_project_home <- function() {
  configured_home <- Sys.getenv("UN_SUBNATIONAL_HOME", unset = "")
  if (nzchar(configured_home)) {
    return(normalizePath(configured_home, winslash = "/", mustWork = TRUE))
  }
  frames <- sys.frames()
  for (frame in rev(frames)) {
    if (!is.null(frame$ofile)) {
      return(normalizePath(
        file.path(dirname(frame$ofile), "..", ".."),
        winslash = "/",
        mustWork = TRUE
      ))
    }
  }
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

select_philippines_ocha_shp_resource <- function(package) {
  resources <- Filter(
    function(resource) identical(toupper(as.character(resource$format)), "SHP"),
    package$resources
  )
  if (length(resources) != 1L) {
    stop("Expected exactly one HDX SHP resource; found ", length(resources), ".")
  }
  resources[[1L]]
}

repair_invalid_ocha_geometry <- function(x) {
  x <- sf::st_transform(x, 4326)
  valid <- sf::st_is_valid(x)
  bad <- which(is.na(valid) | !valid)
  if (length(bad) > 0L) {
    geometry <- sf::st_geometry(x)
    geometry[bad] <- sf::st_make_valid(geometry[bad])
    sf::st_geometry(x) <- geometry
  }
  x
}

normalize_philippines_ocha_layers <- function(admin0, admin1, admin2) {
  required <- list(
    admin0 = c("adm0_name", "adm0_pcode"),
    admin1 = c("adm1_name", "adm1_pcode"),
    admin2 = c("adm1_name", "adm1_pcode", "adm2_name", "adm2_pcode")
  )
  inputs <- list(admin0 = admin0, admin1 = admin1, admin2 = admin2)
  for (level in names(inputs)) {
    missing <- setdiff(required[[level]], names(inputs[[level]]))
    if (length(missing) > 0L) {
      stop(level, " is missing OCHA field(s): ", paste(missing, collapse = ", "))
    }
    inputs[[level]] <- repair_invalid_ocha_geometry(inputs[[level]])
  }
  inputs$admin0$NAME_0 <- "Philippines"
  inputs$admin1$NAME_0 <- "Philippines"
  inputs$admin1$NAME_1 <- as.character(inputs$admin1$adm1_name)
  inputs$admin2$NAME_0 <- "Philippines"
  inputs$admin2$NAME_1 <- as.character(inputs$admin2$adm1_name)
  inputs$admin2$NAME_2 <- as.character(inputs$admin2$adm2_name)
  inputs
}
```

Add `validate_philippines_ocha_layers(layers, dhs_ncr_points = NULL)` with these exact failures: incorrect counts `1/17/88`; non-unique or blank `adm1_pcode`/`adm2_pcode`; blank Admin-2 parent code/name; Admin-2 parent names outside `admin1$NAME_1`; non-polygonal, empty, invalid, or non-EPSG:4326 geometry; NCR not appearing exactly once; NCR area outside 500-700 km² using EPSG:32651; and, when points are supplied, anything other than exactly 126 rows all satisfying `st_within(points, ncr)`.

- [ ] **Step 4: Implement download, selective extraction, staging, provenance, and materialization**

Add the following production entry point:

```r
prepare_philippines_ocha_boundaries <- function(
    project_dir = philippines_ocha_project_home(),
    source_zip = Sys.getenv("PHILIPPINES_OCHA_SHP_ZIP", unset = ""),
    output_dir = file.path(project_dir, "Data", "shapeFiles", "ocha_PHL_shp"))
```

Its implementation must perform this fixed sequence:

1. Require `sf` and `jsonlite` and fetch metadata with `jsonlite::fromJSON(PHILIPPINES_OCHA_CKAN_URL, simplifyVector = FALSE)`.
2. Select the unique SHP resource with `select_philippines_ocha_shp_resource()`.
3. Create one `tempfile("philippines-ocha-")` directory and register `unlink(temp_dir, recursive = TRUE, force = TRUE)` with `on.exit()`.
4. If `source_zip` is blank, download with `utils::download.file(resource$url, destfile = archive, mode = "wb", method = "libcurl")`; otherwise normalize and use the supplied archive without deleting it.
5. From `utils::unzip(zip, list = TRUE)$Name`, extract only case-insensitive members matching `(^|/)phl_admin[012]\\.(shp|shx|dbf|prj|cpg)$`. Require `.shp`, `.shx`, `.dbf`, and `.prj` for each level.
6. Locate exactly one `phl_admin0.shp`, `phl_admin1.shp`, and `phl_admin2.shp`; read each with `sf::st_read(dsn = dirname(shp_file), layer = tools::file_path_sans_ext(basename(shp_file)), quiet = TRUE, options = "ENCODING=UTF-8")`; normalize and validate them.
7. Stop if `output_dir` already exists. Write the three layers to a sibling staging directory named with `paste0(".ocha_PHL_shp-staging-", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"))` as `ocha_PHL_0`, `ocha_PHL_1`, and `ocha_PHL_2` with the ESRI Shapefile driver.
8. Read the DHS file `Data/DHS/Philippines/2022/PHGE81FL` and filter `DHSREGNA == "National Capital Region"`; validate the staged layers with those points.
9. Write `ocha_download_metadata.json` in staging with dataset page/CKAN URLs; resource id/name/url/size/hash/last-modified; dataset modified/version/source/license; normalized layer names/counts; NCR area and DHS containment count; and an ISO-8601 UTC preparation timestamp.
10. Atomically rename staging to `output_dir`, reopen all three final layers, and rerun validation. If any action before the rename fails, remove only staging and the invocation-owned temp directory.

The last statement in the file must only define a callable alias:

```r
main <- prepare_philippines_ocha_boundaries
```

Do not call `main()` at source time.

- [ ] **Step 5: Run unit tests and parse checks; verify GREEN**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_philippines_ocha_boundaries.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' -e "parse(file='Rcode/_script_for_specific_tasks/Philippines_OCHA_Boundaries.R')"
git diff --check -- Rcode/_script_for_specific_tasks/Philippines_OCHA_Boundaries.R tests/test_philippines_ocha_boundaries.R
```

Expected: unit test prints `Philippines OCHA boundary unit tests passed.`, parse succeeds, and `git diff --check` is silent.

- [ ] **Step 6: Commit the isolated preparer if the scoped stage is clean**

```powershell
git add -- Rcode/_script_for_specific_tasks/Philippines_OCHA_Boundaries.R tests/test_philippines_ocha_boundaries.R
git diff --cached --check
git commit -m "feat: prepare Philippines OCHA boundaries"
```

### Task 2: Materialize and independently verify the OCHA layers

**Files:**
- Create: `tests/test_philippines_ocha_boundaries_integration.R`
- Generate: `Data/shapeFiles/ocha_PHL_shp/ocha_PHL_0.*`
- Generate: `Data/shapeFiles/ocha_PHL_shp/ocha_PHL_1.*`
- Generate: `Data/shapeFiles/ocha_PHL_shp/ocha_PHL_2.*`
- Generate: `Data/shapeFiles/ocha_PHL_shp/ocha_download_metadata.json`
- Preserve: `Data/shapeFiles/georepo_PHL_shp/*`

- [ ] **Step 1: Write the failing integration verification**

Create `tests/test_philippines_ocha_boundaries_integration.R`. It must fail when the final OCHA layers are absent, read all final layers when present, and call `validate_philippines_ocha_layers()` using the 126 DHS 2022 `DHSREGNA == "National Capital Region"` points. Independently assert:

```r
stopifnot(
  nrow(layers$admin0) == 1L,
  nrow(layers$admin1) == 17L,
  nrow(layers$admin2) == 88L,
  length(unique(layers$admin1$adm1_pcode)) == 17L,
  length(unique(layers$admin2$adm2_pcode)) == 88L,
  setequal(unique(layers$admin2$NAME_1), layers$admin1$NAME_1),
  identical(sf::st_crs(layers$admin2)$epsg, 4326L),
  all(sf::st_is_valid(layers$admin2)),
  sum(layers$admin1$NAME_1 == "National Capital Region (NCR)") == 1L
)
metadata <- jsonlite::read_json(
  file.path(boundary_dir, "ocha_download_metadata.json"),
  simplifyVector = TRUE
)
stopifnot(
  identical(metadata$dataset_id, "cod-ab-phl"),
  identical(metadata$dataset_url, "https://data.humdata.org/dataset/cod-ab-phl")
)
cat("Philippines OCHA boundary integration tests passed.\n")
```

- [ ] **Step 2: Run the integration test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_philippines_ocha_boundaries_integration.R
```

Expected: non-zero exit because `Data/shapeFiles/ocha_PHL_shp` does not yet exist.

- [ ] **Step 3: Download, normalize, and materialize the source**

Set the project root and invoke the explicit entry point:

```powershell
$env:UN_SUBNATIONAL_HOME = (Get-Location).Path
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' -e "source('Rcode/_script_for_specific_tasks/Philippines_OCHA_Boundaries.R'); main()"
```

Expected: one large SHP resource downloads, only the three required shapefile families are extracted, validation reports `1/17/88`, NCR is 500-700 km², DHS containment is `126/126`, and the invocation-owned download/extraction directory is removed.

- [ ] **Step 4: Run integration validation and verify GREEN**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_philippines_ocha_boundaries_integration.R
Get-ChildItem Data/shapeFiles/ocha_PHL_shp -File | Select-Object Name,Length
Get-ChildItem Data/shapeFiles/georepo_PHL_shp -File | Measure-Object
```

Expected: integration test prints its pass message, final OCHA sidecars and metadata are present, and the rollback GeoRepo directory remains present.

- [ ] **Step 5: Commit only the integration test**

Do not add the 928 MB source archive or generated shapefiles to Git.

```powershell
git add -- tests/test_philippines_ocha_boundaries_integration.R
git diff --cached --check
git commit -m "test: validate Philippines OCHA boundary contract"
```

### Task 3: Switch only the Philippines configuration

**Files:**
- Modify: `tests/test_philippines_pipeline_config.R`
- Modify: `tests/test_info_uses_georepo_paths.R`
- Modify: `Info/Philippines_general_info.json`

- [ ] **Step 1: Change focused tests first**

Extend `tests/test_philippines_pipeline_config.R` with these exact expected fields while retaining all current survey and final-model assertions:

```r
expected$poly.path <- "../shapeFiles/ocha_PHL_shp"
expected$poly.layer.adm0 <- "ocha_PHL_0"
expected$poly.layer.adm1 <- "ocha_PHL_1"
expected$poly.layer.adm2 <- "ocha_PHL_2"
expected$poly.label.adm1 <- "NAME_1"
expected$poly.label.adm2 <- "NAME_2"
expected$boundary_source <- "OCHA HDX (NAMRIA/PSA)"
expected$boundary_source_url <- "https://data.humdata.org/dataset/cod-ab-phl"
```

Update `tests/test_info_uses_georepo_paths.R` so its expected-path branch is exactly:

```r
expected <- if (identical(info$country, "Madagascar")) {
  paste0("shapeFiles/gadm41_", info$iso0, "_shp")
} else if (identical(info$country, "Philippines")) {
  "../shapeFiles/ocha_PHL_shp"
} else {
  paste0("../shapeFiles/georepo_", info$iso0, "_shp")
}
```

This is the regression lock: Philippines is the only OCHA exception; all other non-Madagascar countries must remain GeoRepo.

- [ ] **Step 2: Run focused tests and verify RED**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_philippines_pipeline_config.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_uses_georepo_paths.R
```

Expected: both fail because the Philippines JSON still points to GeoRepo.

- [ ] **Step 3: Apply the minimal JSON switch**

Change only the boundary fields in `Info/Philippines_general_info.json`:

```json
"poly.path": "../shapeFiles/ocha_PHL_shp",
"poly.layer.adm0": "ocha_PHL_0",
"poly.layer.adm1": "ocha_PHL_1",
"poly.label.adm1": "NAME_1",
"poly.layer.adm2": "ocha_PHL_2",
"poly.label.adm2": "NAME_2",
"boundary_source": "OCHA HDX (NAMRIA/PSA)",
"boundary_source_url": "https://data.humdata.org/dataset/cod-ab-phl"
```

Retain DHS 2003/2008/2017/2022, `survey_excluded = 2013`, `surveys_1frame = [2017, 2022]`, survey-derived strata, Admin-2, and `final_model = ar1/ar1/unstrat/bench` unchanged.

- [ ] **Step 4: Run focused and shared-loader regressions; verify GREEN**

```powershell
$tests = @(
  'tests/test_philippines_pipeline_config.R',
  'tests/test_info_uses_georepo_paths.R',
  'tests/test_project_paths_country_info_loader.R',
  'tests/test_active_pipeline_uses_json_info.R',
  'tests/test_pipeline_runner.R',
  'tests/test_georepo_shapefile_prep.R'
)
foreach ($test in $tests) {
  & 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' $test
  if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
}
git diff --check -- Info/Philippines_general_info.json tests/test_philippines_pipeline_config.R tests/test_info_uses_georepo_paths.R
```

Expected: all six tests exit 0 and no other country path assertion changes.

- [ ] **Step 5: Commit the isolated configuration only when its full scoped diff belongs to this override**

```powershell
git diff -- Info/Philippines_general_info.json tests/test_philippines_pipeline_config.R tests/test_info_uses_georepo_paths.R
git add -- Info/Philippines_general_info.json tests/test_philippines_pipeline_config.R tests/test_info_uses_georepo_paths.R
git diff --cached --check
git commit -m "config: use OCHA boundaries for Philippines"
```

### Task 4: Preflight boundary-dependent outputs and launch a clean production run

**Files:**
- Preserve: `Results/Philippines/logs/20260802_133357/*`
- Regenerate: `Data/Countries/Philippines/Philippines_cluster_dat.rda`
- Regenerate: `Data/Countries/Philippines/Philippines_cluster_dat_1frame.rda`
- Generate: `Data/shapeFiles/ocha_PHL_shp/Philippines_Amat.rda`
- Generate: `Data/shapeFiles/ocha_PHL_shp/Philippines_Amat_Names.rda`
- Regenerate: `Data/Countries/Philippines/worldpop/*weights*.rda`
- Regenerate: `Results/Philippines/Direct/*`
- Generate: `Results/Philippines/Betabinomial/*`
- Generate: `Results/Philippines/Philippines_bb8_comparison_dashboard.html`
- Generate: `Results/Philippines/11_CountrySummary.pdf`

- [ ] **Step 1: Record the preflight state without deleting historical evidence**

Confirm the approved source, survey/model config, rollback folder, old failed manifest, and absence of a validated final PDF:

```powershell
Test-Path Data/shapeFiles/ocha_PHL_shp/ocha_PHL_2.shp
Test-Path Data/shapeFiles/georepo_PHL_shp/georepo_PHL_2.shp
Test-Path Results/Philippines/logs/20260802_133357/pipeline_manifest.json
Test-Path Results/Philippines/11_CountrySummary.pdf
Get-ChildItem Results/Philippines/Betabinomial -Recurse -File -ErrorAction SilentlyContinue
```

Expected in the current state: both boundary sources and old manifest exist, no validated final PDF exists, and no completed BB8 result inventory is available to resume. If any BB8 files do exist, stop and inventory their timestamps rather than enabling a resume flag.

- [ ] **Step 2: Clear inherited run-control environment flags**

```powershell
$bb8Flags = @(
  'BB8_ADMIN1_ONLY',
  'BB8_SKIP_SAME_FRAME_NMR',
  'BB8_SKIP_SAME_FRAME_MAIN',
  'BB8_RESUME_ALL_SURVEYS',
  'BB8_RESUME_STRAT_ADMIN2_U5',
  'BB8_RESUME_ALLSURVEY_ADMIN2_U5',
  'BB8_RESUME_ALLSURVEY_BENCHMARKS',
  'BB8_FORCE_ADMIN1_UNSTRAT_BENCHMARK'
)
foreach ($flag in $bb8Flags) {
  Remove-Item -LiteralPath "Env:$flag" -ErrorAction SilentlyContinue
}
$env:UN_SUBNATIONAL_HOME = (Get-Location).Path
$env:UN_SUBNATIONAL_COUNTRY = 'Philippines'
$env:UN_SUBNATIONAL_MODE = 'production'
```

This prevents an Admin-1-only or resume setting from a previous country from changing the approved Philippines run.

- [ ] **Step 3: Run the normal production pipeline**

Run the existing pipeline function; do not add a Philippines branch to the runner:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' -e "source('Rcode/_supporting_scripts/pipeline_runner.R'); run_country_pipeline(country='Philippines', mode='production', render_summary=TRUE, project_dir=getwd())"
```

Expected: Step 1 loads the JSON; historical Step 2 is skipped because configured OCHA Admin-0/1/2 files exist; Steps 3 onward overwrite the boundary-dependent cluster/direct/weight outputs and fit both administrative levels; Step 7a/7b are skipped because survey-derived strata are configured; BB8 fits the normal model families; final selection remains unstratified AR1 benchmarked; a new timestamped manifest finishes with `run_status = completed`; the old `20260802_133357` logs remain unchanged.

- [ ] **Step 4: If execution stops, preserve resumable evidence but do not declare success**

Read the new manifest and failing step log, identify whether its inputs were generated under OCHA, and diagnose with the pipeline skill. Do not set any BB8 resume flag until all prerequisite artifacts are verified to have modification times after the new run start and the same OCHA 17/88 adjacency dimensions.

### Task 5: Add machine-checkable Philippines output verification

**Files:**
- Create: `tests/test_philippines_pipeline_outputs.R`
- Verify: `Data/Countries/Philippines/*`
- Verify: `Data/shapeFiles/ocha_PHL_shp/*`
- Verify: `Results/Philippines/*`

- [ ] **Step 1: Write the post-run data contract test**

Create a test that loads the new cluster data, adjacency objects, and four weight files and asserts:

```r
stopifnot(
  setequal(sort(unique(mod.dat$survey)), c(2003, 2008, 2017, 2022)),
  length(unique(stats::na.omit(mod.dat$admin1.name))) == 17L,
  "National Capital Region (NCR)" %in% mod.dat$admin1.name,
  all(!is.na(mod.dat$admin1)),
  all(!is.na(mod.dat$admin2))
)

frame_env <- new.env(parent = emptyenv())
load(
  "Data/Countries/Philippines/Philippines_cluster_dat_1frame.rda",
  envir = frame_env
)
stopifnot(setequal(sort(unique(frame_env$mod.dat$survey)), c(2017, 2022)))

stopifnot(
  identical(dim(admin1.mat), c(17L, 17L)),
  identical(dim(admin2.mat), c(88L, 88L)),
  nrow(admin1.names) == 17L,
  nrow(admin2.names) == 88L
)
```

For each of `weight.adm1.u1`, `weight.adm1.u5`, `weight.adm2.u1`, and `weight.adm2.u5`, assert years `2000:2025`, row counts `17 * 26` or `88 * 26`, finite non-negative proportions, and year-wise sums within `1e-8` of one. Assert the completed manifest is the newest manifest and that these deliverables exist and are non-empty:

```r
required_results <- c(
  "Results/Philippines/Philippines_bb8_comparison_dashboard.html",
  "Results/Philippines/11_CountrySummary.pdf"
)
stopifnot(all(file.exists(required_results)), all(file.info(required_results)$size > 0))
```

- [ ] **Step 2: Run the output verification and relevant model/report regressions**

```powershell
$tests = @(
  'tests/test_philippines_pipeline_outputs.R',
  'tests/test_philippines_ocha_boundaries_integration.R',
  'tests/test_philippines_pipeline_config.R',
  'tests/test_country_summary_uses_final_national_model.R',
  'tests/test_country_summary_admin1_map_alignment.R',
  'tests/test_bb8_admin2_fit_filename.R',
  'tests/test_bb8_admin2_benchmark_saved_draws.R'
)
foreach ($test in $tests) {
  & 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' $test
  if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
}
```

Expected: all tests exit 0. A failure is an issue to diagnose, not a reason to weaken the 17/88, NCR, survey, weight, unstratified-default, or final-PDF assertions.

- [ ] **Step 3: Commit only the post-run test if its scoped stage is clean**

```powershell
git add -- tests/test_philippines_pipeline_outputs.R
git diff --cached --check
git commit -m "test: verify Philippines pipeline outputs"
```

### Task 6: Inspect data, plots, dashboard, and every PDF page

**Files:**
- Inspect: `Results/Philippines/Direct/*`
- Inspect: `Results/Philippines/Figures/*`
- Inspect: `Results/Philippines/Philippines_bb8_comparison_dashboard.html`
- Inspect: `Results/Philippines/11_CountrySummary.pdf`
- Create: `final_inspection.md` inside the newest completed Philippines run log directory

- [ ] **Step 1: Inspect spatial assignments and sparse areas**

Tabulate distinct clusters by survey and Admin-1, confirm all 17 Admin-1 units including NCR receive clusters, and tabulate Admin-2 cluster counts with parent names. Record Admin-2 units with zero or very few clusters as genuine sparse-data warnings; do not repair them by changing boundaries or reassigning points manually.

- [ ] **Step 2: Inspect weights and pre-BB8 plots**

Review the 17/88 adjacency maps, annual Admin-1/Admin-2 U1/U5 weight plots, direct and smoothed-direct maps, and every pre-BB8 summary plot for missing regions, unexpected islands, incorrect parent assignment, broken legends, or discontinuities. Confirm NCR appears in maps and carries finite positive population weight.

- [ ] **Step 3: Inspect BB8 model comparison and dashboard**

Open the generated dashboard and compare benchmarked and unbenchmarked series. The benchmarked curve need not exactly match UN IGME after the known method change; flag only missing/identical-by-error series, implausible gaps, discontinuities, absent Admin-1/Admin-2 panels, or a default other than the approved unstratified model. Inspect first, middle, and last named Admin-1 and Admin-2 plots for both NMR and U5MR.

- [ ] **Step 4: Render and inspect every summary PDF page**

Using the country-summary PDF and PDF skills, render `Results/Philippines/11_CountrySummary.pdf` to page images at readable resolution. Inspect all pages, including the last sub-area appendix, for clipping, blank pages, missing NCR, duplicated benchmark/unbenchmarked panels, incorrect titles, bad pagination, unreadable legends, or stale GeoRepo geography.

- [ ] **Step 5: Write the final inspection summary**

In the newest run log directory, create `final_inspection.md` containing:

- OCHA source/provenance and validated `1/17/88` counts;
- NCR area and `126/126` DHS 2022 containment;
- survey membership and shared-frame membership;
- Admin-1/Admin-2 cluster and sparse-area findings;
- population-weight checks;
- model/benchmark observations, explicitly noting that exact UN IGME equality is not required;
- dashboard and PDF page review findings;
- any unresolved issue with severity and affected output, or `No material issues found` if evidence supports that conclusion;
- the completed manifest path and final PDF path.

- [ ] **Step 6: Perform the final scoped verification**

```powershell
git diff --check -- Rcode/_script_for_specific_tasks/Philippines_OCHA_Boundaries.R Info/Philippines_general_info.json tests/test_philippines_ocha_boundaries.R tests/test_philippines_ocha_boundaries_integration.R tests/test_philippines_pipeline_config.R tests/test_info_uses_georepo_paths.R tests/test_philippines_pipeline_outputs.R
git status --short
```

Confirm the GeoRepo rollback folder and old failed log still exist, no source ZIP or extraction tree remains, no country-list workbook changed in this implementation, the newest manifest is completed, and the final answer links the manifest, inspection summary, dashboard, and PDF while concisely reporting every issue found.

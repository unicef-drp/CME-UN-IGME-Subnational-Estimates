# Nigeria WorldPop Alignment Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Download Nigeria's legacy 2000–2014 WorldPop age-sex rasters and produce verified national and Admin-1 U1/U5 source-comparison tables and plots through 2025.

**Architecture:** A single Nigeria-specific R script exposes small testable helpers and runs orchestration only when executed directly with `Rscript`. It composes U1/U5 rasters in memory, aggregates them with the repository's GeoRepo boundaries, writes tidy tables, and creates one national and one multipage Admin-1 PDF without changing pipeline population weights.

**Tech Stack:** R 4.6.1, `terra`, `sf`, `jsonlite`, `ggplot2`, base R tests, GeoTIFF, CSV, PDF.

---

## File Structure

- Create `Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R`: source definitions, guarded downloader, raster composition, zonal aggregation, output tables, plots, and top-level Nigeria orchestration.
- Create `tests/test_compare_nigeria_worldpop_alignment.R`: synthetic-raster unit tests and output-contract tests.
- Read raw TIFFs from the consolidated `Worldpop data` root outside the repository.
- Create `Data/Countries/Nigeria/worldpop/comparison/*.csv`: manifest, national counts, Admin-1 counts, and paired differences.
- Create `Data/Countries/Nigeria/worldpop/comparison/*.pdf`: national and Admin-1 figures.

The existing untracked `Rcode/_script_for_specific_tasks/build_new_worldpop_u5_weights.R` and its outputs remain untouched.

### Task 1: Source definitions and year coverage

**Files:**
- Create: `tests/test_compare_nigeria_worldpop_alignment.R`
- Create: `Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R`

- [ ] **Step 1: Write the failing source-definition test**

```r
script <- file.path("Rcode", "_script_for_specific_tasks",
                    "compare_nigeria_worldpop_alignment.R")
stopifnot(file.exists(script))
env <- new.env(parent = globalenv())
sys.source(script, envir = env)

specs <- env$comparison_source_specs("NGA", "Nigeria", "C:/aligned", "C:/old")
stopifnot(identical(names(specs), c("old_global1", "aligned_global1", "global2_r2025a")))
stopifnot(identical(specs$old_global1$years, 2000:2014))
stopifnot(identical(specs$aligned_global1$years, 2000:2014))
stopifnot(identical(specs$global2_r2025a$years, 2015:2025))
stopifnot(grepl("Global_2000_2020_1km/unconstrained/2000/NGA/nga_f_0_2000_1km.tif",
                env$legacy_worldpop_url(2000, "f", 0), fixed = TRUE))
stopifnot(identical(env$indicator_components("u1"),
                    data.frame(sex = c("f", "m"), age = c(0L, 0L))))
stopifnot(nrow(env$indicator_components("u5")) == 4L)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_compare_nigeria_worldpop_alignment.R
```

Expected: FAIL because the comparison script or its functions do not exist.

- [ ] **Step 3: Implement the minimal source helpers**

```r
legacy_worldpop_url <- function(year, sex, age) {
  sprintf(paste0(
    "https://data.worldpop.org/GIS/AgeSex_structures/",
    "Global_2000_2020_1km/unconstrained/%s/NGA/nga_%s_%s_%s_1km.tif"
  ), year, sex, age, year)
}

indicator_components <- function(indicator) {
  stopifnot(indicator %in% c("u1", "u5"))
  if (indicator == "u1") {
    data.frame(sex = c("f", "m"), age = c(0L, 0L))
  } else {
    data.frame(sex = c("f", "f", "m", "m"), age = c(0L, 1L, 0L, 1L))
  }
}

comparison_source_specs <- function(iso3, country, worldpop_root) {
  iso_lower <- tolower(iso3)
  list(
    old_global1 = list(
      label = "Old Global 1 (pre-alignment)", years = 2000:2014,
      path = function(year, sex, age) file.path(
        worldpop_root, "Global1_2000_2020", country,
        sprintf("%s_%s_%s_%s_1km.tif", iso_lower, sex, age, year))
    ),
    aligned_global1 = list(
      label = "Aligned Global 1", years = 2000:2014,
      path = function(year, sex, age) file.path(
        worldpop_root, "Global1_2000_2020_aligned",
        paste0(country, "_extracted"), year, iso3,
        sprintf("%s_%s_%s_%s_constrained_1km.tif", iso_lower, sex, age, year))
    ),
    global2_r2025a = list(
      label = "Global 2 R2025A", years = 2015:2025,
      path = function(year, sex, age) file.path(
        worldpop_root, "Global2_2015_2030", country,
        sprintf("%s_%s_%02d_%s_CN_1km_R2025A_UA_v1.tif",
                iso_lower, sex, age, year))
    )
  )
}
```

- [ ] **Step 4: Run the test and verify it passes**

Run the same `Rscript` command. Expected: PASS and exit code 0.

- [ ] **Step 5: Commit the source-contract slice**

```powershell
git add -- tests/test_compare_nigeria_worldpop_alignment.R Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R
git commit -m "test: define Nigeria WorldPop comparison sources"
```

### Task 2: Guarded downloads and U1/U5 raster composition

**Files:**
- Modify: `tests/test_compare_nigeria_worldpop_alignment.R`
- Modify: `Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R`

- [ ] **Step 1: Add failing tests for cache-safe downloads and raster sums**

```r
tmp <- tempfile("worldpop-test-")
dir.create(tmp)
template <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2,
                        ymin = 0, ymax = 2, crs = "EPSG:4326")
component_values <- list(f0 = 1:4, f1 = 5:8, m0 = 9:12, m1 = 13:16)
paths <- vapply(names(component_values), function(name) {
  out <- file.path(tmp, paste0(name, ".tif"))
  r <- template
  terra::values(r) <- component_values[[name]]
  terra::writeRaster(r, out, overwrite = TRUE)
  out
}, character(1))

u1 <- env$compose_population_raster(paths[c("f0", "m0")])
u5 <- env$compose_population_raster(paths[c("f0", "f1", "m0", "m1")])
stopifnot(identical(as.numeric(terra::values(u1)), c(10, 12, 14, 16)))
stopifnot(identical(as.numeric(terra::values(u5)), c(28, 32, 36, 40)))

download_target <- file.path(tmp, "downloaded.tif")
calls <- 0L
copy_fixture <- function(url, destfile, ...) {
  calls <<- calls + 1L
  file.copy(paths[["f0"]], destfile, overwrite = TRUE)
}
env$download_raster_if_needed("fixture://f0", download_target,
                              download_fun = copy_fixture)
env$download_raster_if_needed("fixture://f0", download_target,
                              download_fun = copy_fixture)
stopifnot(calls == 1L, env$raster_file_ok(download_target))
```

- [ ] **Step 2: Run the test and verify the new assertions fail**

Expected: FAIL because `compose_population_raster`, `download_raster_if_needed`, and `raster_file_ok` are missing.

- [ ] **Step 3: Implement minimal guarded I/O and composition**

```r
raster_file_ok <- function(path) {
  file.exists(path) && tryCatch(terra::nlyr(terra::rast(path)) > 0L,
                                error = function(e) FALSE)
}

download_raster_if_needed <- function(url, file, download_fun = utils::download.file) {
  if (raster_file_ok(file)) return(invisible(file))
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  temp <- paste0(file, ".download.tif")
  if (file.exists(temp)) unlink(temp)
  download_fun(url, temp, mode = "wb", quiet = FALSE)
  if (!raster_file_ok(temp)) stop("Downloaded raster is unreadable: ", url)
  if (!file.rename(temp, file)) stop("Could not finalize raster: ", file)
  invisible(file)
}

compose_population_raster <- function(paths) {
  rasters <- lapply(paths, terra::rast)
  reference <- rasters[[1]]
  compatible <- vapply(rasters[-1], terra::compareGeom, logical(1),
                       y = reference, stopOnError = FALSE)
  if (length(compatible) && !all(compatible)) stop("Component raster geometry differs.")
  Reduce(`+`, rasters)
}
```

- [ ] **Step 4: Run the test and verify all assertions pass**

Expected: PASS and exit code 0.

- [ ] **Step 5: Commit the raster-input slice**

```powershell
git add -- tests/test_compare_nigeria_worldpop_alignment.R Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R
git commit -m "feat: compose and cache WorldPop raster inputs"
```

### Task 3: GeoRepo Admin-1 aggregation and national closure

**Files:**
- Modify: `tests/test_compare_nigeria_worldpop_alignment.R`
- Modify: `Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R`

- [ ] **Step 1: Add a failing synthetic zonal-aggregation test**

```r
population <- template
terra::values(population) <- c(1, 2, 3, 4)
left <- sf::st_polygon(list(matrix(c(0,0, 1,0, 1,2, 0,2, 0,0), ncol = 2, byrow = TRUE)))
right <- sf::st_polygon(list(matrix(c(1,0, 2,0, 2,2, 1,2, 1,0), ncol = 2, byrow = TRUE)))
adm1 <- sf::st_sf(NAME_1 = c("Left", "Right"), geometry = sf::st_sfc(left, right, crs = 4326))
names <- data.frame(Internal = 1:2, GeoRepo = c("Left", "Right"))
zonal <- env$zonal_admin1_counts(adm1, population, names)
stopifnot(nrow(zonal) == 2L, sum(zonal$population) == 10)
national <- env$national_from_admin1(zonal)
stopifnot(national == 10)
```

- [ ] **Step 2: Run the test and verify it fails for the missing aggregation helpers**

- [ ] **Step 3: Implement rasterize-plus-zonal aggregation**

```r
zonal_admin1_counts <- function(adm1_sf, population, admin_names) {
  adm1_vect <- terra::vect(adm1_sf)
  if (!terra::same.crs(population, adm1_vect)) {
    adm1_vect <- terra::project(adm1_vect, terra::crs(population))
  }
  adm1_vect$.admin_row <- seq_len(nrow(adm1_sf))
  zones <- terra::rasterize(adm1_vect, population, field = ".admin_row")
  sums <- terra::zonal(population, zones, fun = "sum", na.rm = TRUE)
  values <- numeric(nrow(adm1_sf))
  matched <- match(seq_len(nrow(adm1_sf)), sums[[1]])
  values[!is.na(matched)] <- sums[[2]][matched[!is.na(matched)]]
  data.frame(region = admin_names$Internal,
             region_label = admin_names$GeoRepo,
             population = values)
}

national_from_admin1 <- function(admin1_counts) sum(admin1_counts$population, na.rm = TRUE)

zonal_admin0_count <- function(adm0_sf, population) {
  adm0_vect <- terra::vect(adm0_sf)
  if (!terra::same.crs(population, adm0_vect)) {
    adm0_vect <- terra::project(adm0_vect, terra::crs(population))
  }
  zones <- terra::rasterize(adm0_vect, population, field = 1)
  sums <- terra::zonal(population, zones, fun = "sum", na.rm = TRUE)
  sum(sums[[2]], na.rm = TRUE)
}

closure_relative_difference <- function(admin1_total, admin0_total) {
  abs(admin1_total - admin0_total) / admin0_total
}
```

- [ ] **Step 4: Add and pass an Admin-0 diagnostic test**

```r
adm0 <- sf::st_sf(NAME_0 = "Test",
  geometry = sf::st_sfc(sf::st_union(sf::st_geometry(adm1)), crs = 4326))
adm0_total <- env$zonal_admin0_count(adm0, population)
stopifnot(adm0_total == 10)
stopifnot(env$closure_relative_difference(10, 10) == 0)
stopifnot(env$closure_relative_difference(9, 10) > 0.0025)
```

- [ ] **Step 5: Run the full test file and commit**

```powershell
git add -- tests/test_compare_nigeria_worldpop_alignment.R Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R
git commit -m "feat: aggregate WorldPop counts to Nigeria states"
```

### Task 4: Tables and static figures

**Files:**
- Modify: `tests/test_compare_nigeria_worldpop_alignment.R`
- Modify: `Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R`

- [ ] **Step 1: Add failing output-contract tests**

```r
plot_data <- data.frame(
  source_key = c("old_global1", "aligned_global1", "global2_r2025a"),
  source_label = c("Old Global 1 (pre-alignment)", "Aligned Global 1", "Global 2 R2025A"),
  year = c(2014L, 2014L, 2015L), indicator = c("u1", "u1", "u1"),
  population = c(10, 11, 12)
)
plot_data <- env$prepare_plot_data(plot_data)
stopifnot(identical(sort(unique(plot_data$source_key)),
                    sort(c("old_global1", "aligned_global1", "global2_r2025a"))))
stopifnot(max(plot_data$year[plot_data$source_key == "aligned_global1"]) == 2014)
stopifnot(min(plot_data$year[plot_data$source_key == "global2_r2025a"]) == 2015)
stopifnot(length(unique(plot_data$series_group)) == 3L)

national_pdf <- file.path(tmp, "national.pdf")
admin1_pdf <- file.path(tmp, "admin1.pdf")
env$write_national_pdf(plot_data, national_pdf)
admin1_fixture <- transform(plot_data[rep(seq_len(nrow(plot_data)), 2), ],
  region = rep(1:2, each = nrow(plot_data)),
  region_label = rep(c("Left", "Right"), each = nrow(plot_data)))
env$write_admin1_pdf(admin1_fixture, admin1_pdf, regions_per_page = 20L)
stopifnot(file.info(national_pdf)$size > 1000,
          file.info(admin1_pdf)$size > 1000)
```

- [ ] **Step 2: Run the test and verify it fails for missing table/plot helpers**

- [ ] **Step 3: Implement plot preparation and national facets**

```r
prepare_plot_data <- function(x) {
  x$source_label <- factor(x$source_label,
    levels = c("Old Global 1 (pre-alignment)", "Aligned Global 1", "Global 2 R2025A"))
  x$indicator <- factor(toupper(x$indicator), levels = c("U1", "U5"))
  x$series_group <- interaction(x$source_key, x$indicator, drop = TRUE)
  x
}

comparison_plot <- function(data, facet_formula, title) {
  ggplot2::ggplot(data,
    ggplot2::aes(year, population, color = source_label, linetype = source_label,
                 shape = source_label, group = series_group)) +
    ggplot2::geom_vline(xintercept = 2015, linetype = "dotted", color = "grey45") +
    ggplot2::geom_line(linewidth = 0.65) +
    ggplot2::geom_point(size = 1.2) +
    ggplot2::facet_wrap(facet_formula, scales = "free_y") +
    ggplot2::scale_y_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE)) +
    ggplot2::labs(title = title, x = "Year", y = "Population", color = NULL,
                  linetype = NULL, shape = NULL) +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(legend.position = "top", panel.grid.minor = ggplot2::element_blank())
}

write_national_pdf <- function(data, file) {
  grDevices::pdf(file, width = 8.5, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  print(comparison_plot(prepare_plot_data(data), ~indicator,
                        "Nigeria U1 and U5 population by WorldPop source"))
}

write_admin1_pdf <- function(data, file, regions_per_page = 20L) {
  data <- prepare_plot_data(data)
  regions <- unique(as.character(data$region_label))
  pages <- split(regions, ceiling(seq_along(regions) / regions_per_page))
  grDevices::pdf(file, width = 13, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (indicator_value in levels(data$indicator)) {
    for (page_regions in pages) {
      one <- data[data$indicator == indicator_value & data$region_label %in% page_regions, ]
      one$region_label <- factor(one$region_label, levels = page_regions)
      print(comparison_plot(one, ~region_label,
        paste("Nigeria Admin-1", indicator_value, "population by WorldPop source")) +
        ggplot2::facet_wrap(~region_label, ncol = 5, scales = "free_y"))
    }
  }
}
```

- [ ] **Step 4: Verify the multipage Admin-1 figure grouping**

Run the test and inspect `admin1.pdf` page count with `pdfinfo`. Expected: one page per indicator/page group, at most 20 state facets per page, and no 2014–2015 connector because `series_group` includes `source_key`.

- [ ] **Step 5: Run tests and commit**

```powershell
git add -- tests/test_compare_nigeria_worldpop_alignment.R Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R
git commit -m "feat: plot national and state WorldPop comparisons"
```

### Task 5: Nigeria orchestration and manifests

**Files:**
- Modify: `tests/test_compare_nigeria_worldpop_alignment.R`
- Modify: `Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R`

- [ ] **Step 1: Add a failing orchestration-contract test**

Verify that manifest construction creates exactly 164 rows and the expected per-source counts:

```r
manifest <- env$build_input_manifest(specs)
stopifnot(nrow(manifest) == 164L)
stopifnot(sum(manifest$source_key == "old_global1") == 60L)
stopifnot(sum(manifest$source_key == "aligned_global1") == 60L)
stopifnot(sum(manifest$source_key == "global2_r2025a") == 44L)
```

- [ ] **Step 2: Run the test and verify it fails for missing manifest/orchestration functions**

- [ ] **Step 3: Implement `build_input_manifest()` and `run_comparison()`**

```r
build_input_manifest <- function(specs) {
  rows <- list()
  index <- 0L
  for (source_key in names(specs)) {
    spec <- specs[[source_key]]
    for (year in spec$years) for (sex in c("f", "m")) for (age in 0:1) {
      index <- index + 1L
      path <- spec$path(year, sex, age)
      rows[[index]] <- data.frame(
        source_key = source_key, source_label = spec$label, year = year,
        sex = sex, age = age, path = path, exists = file.exists(path),
        readable = raster_file_ok(path)
      )
    }
  }
  do.call(rbind, rows)
}
```

`run_comparison()` must:

1. Resolve the repository root and read `Info/Nigeria_general_info.json`.
2. Resolve the consolidated `Worldpop data` root and create the `comparison` output directory.
3. Reuse the 60 legacy rasters from `Global1_2000_2020/Nigeria`.
4. Verify all 164 manifest paths are readable.
5. Read GeoRepo Admin-0/Admin-1 layers and the existing admin-name crosswalk.
6. Loop over source-year combinations, compose U1/U5, aggregate counts, and append national/Admin-1 rows.
7. Fail if counts are missing, negative, non-finite, or closure exceeds 0.25%.
8. Write the four CSVs and two PDFs defined in the design spec.
9. Print output paths and summary counts.

Guard execution with:

```r
if (sys.nframe() == 0L) {
  run_comparison()
}
```

- [ ] **Step 4: Run unit tests and verify all pass**

Run the test file with R 4.6.1. Expected: exit code 0 with a final success message.

- [ ] **Step 5: Commit the orchestration slice**

```powershell
git add -- tests/test_compare_nigeria_worldpop_alignment.R Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R
git commit -m "feat: run Nigeria WorldPop alignment comparison"
```

### Task 6: Download, execute, and verify the first version

**Files:**
- Read: `Worldpop data/Global1_2000_2020/Nigeria/*.tif`
- Create: `Data/Countries/Nigeria/worldpop/comparison/*.csv`
- Create: `Data/Countries/Nigeria/worldpop/comparison/*.pdf`

- [ ] **Step 1: Run the complete Nigeria comparison**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' `
  Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R
```

Expected: all 60 legacy downloads complete or are reused, 164 manifest inputs pass, and six requested outputs are written.

- [ ] **Step 2: Verify raster and table coverage**

Run an R verification command that asserts:

```r
stopifnot(length(list.files(old_dir, pattern = "\\.tif$", full.names = TRUE)) == 60L)
stopifnot(nrow(manifest) == 164L, all(manifest$readable))
stopifnot(nrow(national) == 82L)
stopifnot(length(unique(admin1$region_label)) == 38L)
stopifnot(!anyNA(national$population), all(national$population >= 0))
stopifnot(!anyNA(admin1$population), all(admin1$population >= 0))
stopifnot(max(abs(national$closure_relative_difference)) <= 0.0025)
```

- [ ] **Step 3: Render and visually inspect both PDFs**

Render every PDF page to PNG using the PDF skill's prescribed Poppler workflow. Inspect the national figure and all Admin-1 pages for missing series, blank facets, clipped labels, and unreadable legends. If a visual defect is found, add a failing plot-contract test where practical, fix it, and rerun tests plus the integration command.

- [ ] **Step 4: Re-run the full test suite relevant to the change**

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_compare_nigeria_worldpop_alignment.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_georepo_shapefile_prep.R
```

Expected: both commands exit 0.

- [ ] **Step 5: Check repository scope**

Verify that only the new comparison script, test, plan/spec documents, and requested data outputs changed. Confirm existing population-weight files and the prior U5-only exploratory script are unchanged.

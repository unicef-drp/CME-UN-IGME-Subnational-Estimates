# Liberia GeoRepo Boundary Exclusion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Liberia's JSON configuration reproducibly exclude GeoRepo's `Under National Administration` feature and generate normalized boundary layers with exactly 15 official counties.

**Architecture:** Add one generic boundary-exclusion normalizer and one layer-filtering helper to the existing GeoRepo preparation script. Both the live-download and existing-pull paths will call the same helper before rebuilding Admin-0 and writing layers; the helper returns audit counts that both metadata paths serialize.

**Tech Stack:** R 4.x, `sf`, `jsonlite`, base R tests using `stopifnot`, GeoRepo normalized shapefiles.

---

### Task 1: Specify boundary exclusion behavior with failing tests

**Files:**
- Modify: `tests/test_georepo_shapefile_prep.R`
- Test: `tests/test_georepo_shapefile_prep.R`

- [ ] **Step 1: Add synthetic Admin-1/Admin-2 fixtures and assertions**

Append a focused test that defines two Admin-1 polygons and three Admin-2 polygons, then calls the wished-for helper API:

```r
admin1_layer <- sf::st_sf(
  NAME_1 = c("Bomi", "Under National Administration"),
  geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 0)))),
    sf::st_polygon(list(rbind(c(1, 0), c(2, 0), c(2, 1), c(1, 0)))),
    crs = 4326
  )
)
admin2_layer <- sf::st_sf(
  NAME_1 = c("Bomi", "Under National Administration", "Bomi"),
  NAME_2 = c("Bomi Child A", "Excluded Child", "Bomi Child B"),
  geometry = sf::st_sfc(
    sf::st_point(c(0.2, 0.2)),
    sf::st_point(c(1.2, 0.2)),
    sf::st_point(c(0.4, 0.4)),
    crs = 4326
  )
)
exclusions <- data.frame(
  level = 1L,
  name = "Under National Administration",
  reason = "GeoRepo feature is not an official Liberia county",
  stringsAsFactors = FALSE
)

unchanged <- env$apply_georepo_boundary_exclusions(
  admin1_layer, admin2_layer, NULL
)
stopifnot(
  nrow(unchanged$admin1) == 2L,
  nrow(unchanged$admin2) == 3L,
  unchanged$counts$admin1_before == 2L,
  unchanged$counts$admin1_after == 2L
)

filtered <- env$apply_georepo_boundary_exclusions(
  admin1_layer, admin2_layer, exclusions
)
stopifnot(
  identical(filtered$admin1$NAME_1, "Bomi"),
  identical(filtered$admin2$NAME_2, c("Bomi Child A", "Bomi Child B")),
  filtered$counts$admin1_before == 2L,
  filtered$counts$admin1_after == 1L,
  filtered$counts$admin2_before == 3L,
  filtered$counts$admin2_after == 2L,
  identical(filtered$exclusions$name, "Under National Administration")
)

missing_name_error <- try(
  env$apply_georepo_boundary_exclusions(
    admin1_layer,
    admin2_layer,
    transform(exclusions, name = "Missing Area")
  ),
  silent = TRUE
)
stopifnot(
  inherits(missing_name_error, "try-error"),
  grepl("Missing Area", as.character(missing_name_error), fixed = TRUE)
)
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_georepo_shapefile_prep.R
```

Expected: FAIL because `apply_georepo_boundary_exclusions` does not exist.

### Task 2: Implement and integrate the generic exclusion helper

**Files:**
- Modify: `Rcode/2_download_georepo_shapefiles.R`
- Test: `tests/test_georepo_shapefile_prep.R`

- [ ] **Step 1: Add configuration normalization and validation**

Add after `prepare_layer()`:

```r
normalise_georepo_boundary_exclusions <- function(exclusions = NULL) {
  empty <- data.frame(
    level = integer(),
    name = character(),
    reason = character(),
    stringsAsFactors = FALSE
  )
  if (is.null(exclusions) || length(exclusions) == 0L) {
    return(empty)
  }

  if (is.data.frame(exclusions)) {
    rules <- exclusions
  } else if (is.list(exclusions) &&
             all(vapply(exclusions, is.list, logical(1)))) {
    rules <- do.call(rbind, lapply(exclusions, function(rule) {
      data.frame(
        level = rule$level %||% NA_integer_,
        name = rule$name %||% NA_character_,
        reason = rule$reason %||% NA_character_,
        stringsAsFactors = FALSE
      )
    }))
  } else {
    stop("georepo_boundary_exclusions must be an array of rule objects.", call. = FALSE)
  }

  required <- c("level", "name", "reason")
  missing_fields <- setdiff(required, names(rules))
  if (length(missing_fields) > 0L) {
    stop(
      "GeoRepo boundary exclusion rules are missing: ",
      paste(missing_fields, collapse = ", "),
      call. = FALSE
    )
  }

  rules <- rules[, required, drop = FALSE]
  rules$level <- as.integer(rules$level)
  rules$name <- trimws(as.character(rules$name))
  rules$reason <- trimws(as.character(rules$reason))
  if (any(is.na(rules$level)) || any(!rules$level %in% 1L)) {
    stop("Only Admin-1 GeoRepo boundary exclusions are supported.", call. = FALSE)
  }
  if (any(is.na(rules$name) | !nzchar(rules$name)) ||
      any(is.na(rules$reason) | !nzchar(rules$reason))) {
    stop("Every GeoRepo boundary exclusion needs a non-empty name and reason.", call. = FALSE)
  }
  rules
}
```

- [ ] **Step 2: Add the layer-filtering helper**

```r
apply_georepo_boundary_exclusions <- function(admin1_layer,
                                               admin2_layer,
                                               exclusions = NULL) {
  rules <- normalise_georepo_boundary_exclusions(exclusions)
  counts <- list(
    admin1_before = nrow(admin1_layer),
    admin1_after = nrow(admin1_layer),
    admin2_before = nrow(admin2_layer),
    admin2_after = nrow(admin2_layer)
  )
  if (nrow(rules) == 0L) {
    return(list(
      admin1 = admin1_layer,
      admin2 = admin2_layer,
      exclusions = rules,
      counts = counts
    ))
  }
  if (!"NAME_1" %in% names(admin1_layer) ||
      !"NAME_1" %in% names(admin2_layer)) {
    stop("Prepared Admin-1 and Admin-2 layers must contain NAME_1.", call. = FALSE)
  }

  excluded_names <- unique(rules$name[rules$level == 1L])
  missing_names <- setdiff(excluded_names, unique(as.character(admin1_layer$NAME_1)))
  if (length(missing_names) > 0L) {
    stop(
      "Configured GeoRepo Admin-1 exclusions were not found: ",
      paste(missing_names, collapse = ", "),
      call. = FALSE
    )
  }

  admin1_layer <- admin1_layer[
    !as.character(admin1_layer$NAME_1) %in% excluded_names,
    ,
    drop = FALSE
  ]
  admin2_layer <- admin2_layer[
    !as.character(admin2_layer$NAME_1) %in% excluded_names,
    ,
    drop = FALSE
  ]
  counts$admin1_after <- nrow(admin1_layer)
  counts$admin2_after <- nrow(admin2_layer)
  list(
    admin1 = admin1_layer,
    admin2 = admin2_layer,
    exclusions = rules,
    counts = counts
  )
}
```

- [ ] **Step 3: Add one shared preparation wrapper**

```r
prepare_georepo_layers <- function(admin1_layer,
                                   admin2_layer,
                                   country,
                                   exclusions = NULL) {
  admin1_layer <- prepare_layer(admin1_layer, 1, country)
  admin2_layer <- prepare_layer(admin2_layer, 2, country)
  filtered <- apply_georepo_boundary_exclusions(
    admin1_layer,
    admin2_layer,
    exclusions
  )
  filtered$admin0 <- make_adm0_from_adm1(filtered$admin1, country)
  filtered
}
```

- [ ] **Step 4: Route both GeoRepo input paths through the wrapper**

In `materialize_existing_georepo_pull()`, replace direct Admin-0 construction with:

```r
prepared <- prepare_georepo_layers(
  admin1_layer,
  admin2_layer,
  country,
  get0("georepo_boundary_exclusions", ifnotfound = NULL, inherits = TRUE)
)
admin0_layer <- prepared$admin0
admin1_layer <- prepared$admin1
admin2_layer <- prepared$admin2
```

Apply the same wrapper in `main()` immediately after `read_features_sf()` creates the two layers. Continue using `write_normalised_layer()` so geometry repair and stable layer names remain unchanged.

- [ ] **Step 5: Add audit fields to both metadata payloads**

Add these fields to both `jsonlite::write_json()` lists:

```r
boundary_exclusions = lapply(seq_len(nrow(prepared$exclusions)), function(i) {
  list(
    level = prepared$exclusions$level[[i]],
    name = prepared$exclusions$name[[i]],
    reason = prepared$exclusions$reason[[i]]
  )
}),
feature_counts = prepared$counts,
```

Keep the existing `admin1_features` and `admin2_features` fields, but set them from the post-filter layer row counts so they continue to describe the written layers.

- [ ] **Step 6: Run the focused test and confirm GREEN**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_georepo_shapefile_prep.R
```

Expected: `GeoRepo shapefile prep helper tests passed.` with exit code 0.

### Task 3: Record and test Liberia's approved rule

**Files:**
- Modify: `tests/test_info_config.R`
- Modify: `Info/Liberia_general_info.json`

- [ ] **Step 1: Add a failing Liberia configuration assertion**

Append:

```r
liberia_info <- jsonlite::fromJSON(
  file.path("Info", "Liberia_general_info.json"),
  simplifyVector = TRUE
)
liberia_exclusions <- liberia_info$georepo_boundary_exclusions
stopifnot(
  is.data.frame(liberia_exclusions),
  nrow(liberia_exclusions) == 1L,
  identical(as.integer(liberia_exclusions$level), 1L),
  identical(
    as.character(liberia_exclusions$name),
    "Under National Administration"
  ),
  identical(
    as.character(liberia_exclusions$reason),
    "GeoRepo feature is not an official Liberia county"
  )
)
```

- [ ] **Step 2: Run the configuration test and confirm RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
```

Expected: FAIL because `georepo_boundary_exclusions` is absent.

- [ ] **Step 3: Add the approved JSON rule**

Insert after the Admin-1 label:

```json
"georepo_boundary_exclusions": [
  {
    "level": 1,
    "name": "Under National Administration",
    "reason": "GeoRepo feature is not an official Liberia county"
  }
],
```

- [ ] **Step 4: Run the configuration and boundary tests**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_georepo_shapefile_prep.R
```

Expected: both commands exit 0.

### Task 4: Regenerate and verify Liberia's normalized boundaries

**Files:**
- Regenerate: `Data/shapeFiles/georepo_LBR_shp/georepo_LBR_0.*`
- Regenerate: `Data/shapeFiles/georepo_LBR_shp/georepo_LBR_1.*`
- Regenerate: `Data/shapeFiles/georepo_LBR_shp/georepo_LBR_2.*`
- Regenerate: `Data/shapeFiles/georepo_LBR_shp/georepo_download_metadata.json`

- [ ] **Step 1: Run GeoRepo preparation with Liberia's JSON context**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' -e "Sys.setenv(UN_SUBNATIONAL_HOME=normalizePath('.')); source('Rcode/_supporting_scripts/project_paths.R'); load.country.info('Liberia', globalenv()); georepo_env <- new.env(parent=globalenv()); sys.source('Rcode/2_download_georepo_shapefiles.R', envir=georepo_env); georepo_env$main()"
```

Expected: the existing GeoRepo pull or live API is materialized, and the script reports the normalized Liberia layer names.

- [ ] **Step 2: Verify the written Admin-1 layer and audit metadata**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' -e "library(sf); library(jsonlite); x <- st_read('Data/shapeFiles/georepo_LBR_shp/georepo_LBR_1.shp', quiet=TRUE); expected <- sort(c('Bomi','Bong','Gbarpolu','Grand Bassa','Grand Cape Mount','Grand Gedeh','Grand Kru','Lofa','Margibi','Maryland','Montserrado','Nimba','River Gee','Rivercess','Sinoe')); stopifnot(nrow(x)==15L, identical(sort(as.character(x$NAME_1)), expected), !'Under National Administration' %in% x$NAME_1); metadata <- fromJSON('Data/shapeFiles/georepo_LBR_shp/georepo_download_metadata.json'); stopifnot(metadata$admin1_features==15L, metadata$feature_counts$admin1_before==16L, metadata$feature_counts$admin1_after==15L, metadata$boundary_exclusions$name=='Under National Administration'); cat('Verified Liberia 15-county GeoRepo layers and exclusion metadata.\n')"
```

Expected: `Verified Liberia 15-county GeoRepo layers and exclusion metadata.`

- [ ] **Step 3: Run final focused verification**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_georepo_shapefile_prep.R
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_info_config.R
git diff --check -- Rcode/2_download_georepo_shapefiles.R tests/test_georepo_shapefile_prep.R tests/test_info_config.R Info/Liberia_general_info.json
```

Expected: both tests exit 0 and `git diff --check` reports no whitespace errors.

- [ ] **Step 4: Review and commit only the exclusion implementation files**

```powershell
git diff -- Rcode/2_download_georepo_shapefiles.R tests/test_georepo_shapefile_prep.R tests/test_info_config.R Info/Liberia_general_info.json
git add -- Rcode/2_download_georepo_shapefiles.R tests/test_georepo_shapefile_prep.R tests/test_info_config.R Info/Liberia_general_info.json
git diff --cached --check
git commit -m "feat: exclude configured GeoRepo boundary areas"
```

Before committing, confirm the staged diff contains no unrelated pre-existing edits. If any named file already contains unrelated user changes, do not commit; leave the verified implementation in the working tree and report the overlap.

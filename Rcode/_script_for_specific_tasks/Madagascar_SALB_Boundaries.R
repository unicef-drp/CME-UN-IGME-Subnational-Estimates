# Download and normalize the survey-period UN SALB boundaries for Madagascar.

madagascar_salb_project_home <- function() {
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

madagascar_salb_spec <- function() {
  item_id <- "9013b63ff3694106baa2ea8cd701223c"
  list(
    country = "Madagascar",
    iso3 = "MDG",
    item_id = item_id,
    source_page = "https://salb.un.org/en/data/mdg",
    download_url = paste0(
      "https://geoportal.un.org/arcgis/sharing/rest/content/items/",
      item_id,
      "/data"
    ),
    valid_from = "2014-09-27",
    valid_to = "2021-06-23",
    source_basename = "BNDA_MDG_2014-09-27_2021-06-23",
    archive_name = "MDG_SALB_2014-09-27_2021-06-23.zip",
    feature_counts = c(adm0 = 1L, adm1 = 6L, adm2 = 22L)
  )
}

madagascar_salb_output_dir <- function(
    project_dir = madagascar_salb_project_home()) {
  normalizePath(
    file.path(project_dir, "Data", "shapeFiles", "_alt"),
    winslash = "/",
    mustWork = FALSE
  )
}

require_madagascar_salb_packages <- function() {
  packages <- c("sf", "jsonlite", "digest")
  missing <- packages[
    !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    stop(
      "Missing required package(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

download_madagascar_salb_archive <- function(
    url,
    destfile,
    download_file = utils::download.file,
    timeout_seconds = 600) {
  old_timeout <- getOption("timeout")
  options(timeout = max(c(old_timeout, timeout_seconds), na.rm = TRUE))
  on.exit(options(timeout = old_timeout), add = TRUE)

  status <- download_file(
    url,
    destfile = destfile,
    mode = "wb",
    method = "libcurl",
    quiet = FALSE
  )
  if (length(status) == 1L && is.numeric(status) && status != 0) {
    stop("SALB download failed with status ", status, ".", call. = FALSE)
  }
  if (!file.exists(destfile) || file.info(destfile)$size <= 0) {
    stop("SALB download did not produce a non-empty archive.", call. = FALSE)
  }
  invisible(destfile)
}

is_blank_salb_value <- function(x) {
  is.na(x) | !nzchar(trimws(as.character(x)))
}

repair_salb_geometry <- function(x) {
  if (!inherits(x, "sf")) {
    stop("SALB boundary input must be an sf object.", call. = FALSE)
  }
  if (is.na(sf::st_crs(x))) {
    stop("SALB boundary input has no coordinate reference system.", call. = FALSE)
  }
  valid <- sf::st_is_valid(x)
  if (any(is.na(valid) | !valid)) {
    x <- sf::st_make_valid(x)
  }
  geometry_types <- as.character(sf::st_geometry_type(x, by_geometry = TRUE))
  if (!all(geometry_types %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("SALB boundary input contains non-polygonal geometry.", call. = FALSE)
  }
  x
}

normalize_madagascar_salb_layers <- function(source_layer) {
  required <- c("adm2nm", "adm2cd", "adm1nm", "adm1cd", "iso3cd", "cty_nm")
  missing <- setdiff(required, names(source_layer))
  if (length(missing) > 0L) {
    stop(
      "Madagascar SALB source is missing field(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  source_layer <- repair_salb_geometry(source_layer)
  adm2 <- sf::st_sf(
    ISO3 = as.character(source_layer$iso3cd),
    COUNTRY = as.character(source_layer$cty_nm),
    SALB_ADM1 = as.character(source_layer$adm1cd),
    NAME_1 = as.character(source_layer$adm1nm),
    SALB_ADM2 = as.character(source_layer$adm2cd),
    NAME_2 = as.character(source_layer$adm2nm),
    geometry = sf::st_geometry(source_layer)
  )

  admin1_keys <- unique(sf::st_drop_geometry(adm2[c("SALB_ADM1", "NAME_1")]))
  admin1_geometry <- lapply(seq_len(nrow(admin1_keys)), function(i) {
    rows <- adm2$SALB_ADM1 == admin1_keys$SALB_ADM1[[i]]
    sf::st_union(sf::st_geometry(adm2[rows, , drop = FALSE]))[[1L]]
  })
  adm1 <- sf::st_sf(
    ISO3 = "MDG",
    COUNTRY = "Madagascar",
    SALB_ADM1 = admin1_keys$SALB_ADM1,
    NAME_1 = admin1_keys$NAME_1,
    geometry = sf::st_sfc(admin1_geometry, crs = sf::st_crs(adm2))
  )

  adm0 <- sf::st_sf(
    ISO3 = "MDG",
    COUNTRY = "Madagascar",
    geometry = sf::st_sfc(
      sf::st_union(sf::st_geometry(adm2))[[1L]],
      crs = sf::st_crs(adm2)
    )
  )

  list(
    adm0 = repair_salb_geometry(adm0),
    adm1 = repair_salb_geometry(adm1),
    adm2 = repair_salb_geometry(adm2)
  )
}

validate_madagascar_salb_layers <- function(layers, spec = madagascar_salb_spec()) {
  expected_levels <- c("adm0", "adm1", "adm2")
  if (!identical(sort(names(layers)), sort(expected_levels))) {
    stop("Normalized SALB layers must contain adm0, adm1, and adm2.", call. = FALSE)
  }

  counts <- vapply(layers[expected_levels], nrow, integer(1))
  if (!identical(counts, spec$feature_counts)) {
    stop(
      "Unexpected Madagascar SALB feature counts: ",
      paste(names(counts), counts, sep = "=", collapse = ", "),
      call. = FALSE
    )
  }

  for (level in expected_levels) {
    layer <- layers[[level]]
    if (any(sf::st_is_empty(layer))) {
      stop(level, " contains empty geometry.", call. = FALSE)
    }
    valid <- sf::st_is_valid(layer)
    if (any(is.na(valid) | !valid)) {
      stop(level, " contains invalid geometry.", call. = FALSE)
    }
    if (any(is_blank_salb_value(layer$ISO3)) ||
        !identical(unique(as.character(layer$ISO3)), spec$iso3)) {
      stop(level, " has an invalid ISO3 value.", call. = FALSE)
    }
  }

  if (any(is_blank_salb_value(layers$adm1$NAME_1)) ||
      anyDuplicated(layers$adm1$NAME_1)) {
    stop("Admin-1 names must be nonempty and unique.", call. = FALSE)
  }
  if (any(is_blank_salb_value(layers$adm2$NAME_2)) ||
      anyDuplicated(layers$adm2$NAME_2)) {
    stop("Admin-2 names must be nonempty and unique.", call. = FALSE)
  }
  if (!all(layers$adm2$NAME_1 %in% layers$adm1$NAME_1)) {
    stop("Every Admin-2 parent must exist in Admin-1.", call. = FALSE)
  }

  invisible(list(feature_counts = as.list(counts)))
}

write_madagascar_salb_layers <- function(layers, output_dir) {
  layer_names <- c(
    adm0 = "salb_MDG_0",
    adm1 = "salb_MDG_1",
    adm2 = "salb_MDG_2"
  )
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  for (level in names(layer_names)) {
    sf::st_write(
      layers[[level]],
      dsn = output_dir,
      layer = layer_names[[level]],
      driver = "ESRI Shapefile",
      delete_layer = TRUE,
      quiet = TRUE,
      layer_options = "ENCODING=UTF-8"
    )
  }
  invisible(layer_names)
}

read_normalized_madagascar_salb_layers <- function(output_dir) {
  layer_names <- c(
    adm0 = "salb_MDG_0",
    adm1 = "salb_MDG_1",
    adm2 = "salb_MDG_2"
  )
  lapply(layer_names, function(layer_name) {
    sf::st_read(
      dsn = output_dir,
      layer = layer_name,
      quiet = TRUE,
      options = "ENCODING=UTF-8"
    )
  })
}

prepare_madagascar_salb_boundaries <- function(
    project_dir = madagascar_salb_project_home(),
    source_zip = Sys.getenv("MADAGASCAR_SALB_SHP_ZIP", unset = ""),
    output_dir = madagascar_salb_output_dir(project_dir)) {
  require_madagascar_salb_packages()
  spec <- madagascar_salb_spec()
  project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)

  temp_dir <- tempfile("madagascar-salb-")
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  archive <- if (nzchar(source_zip)) {
    normalizePath(source_zip, winslash = "/", mustWork = TRUE)
  } else {
    downloaded_archive <- file.path(temp_dir, spec$archive_name)
    message("Downloading Madagascar SALB archive: ", spec$download_url)
    download_madagascar_salb_archive(spec$download_url, downloaded_archive)
    downloaded_archive
  }

  archive_members <- utils::unzip(archive, list = TRUE)$Name
  source_pattern <- paste0(
    "(^|/)",
    spec$source_basename,
    "[.](shp|shx|dbf|prj|cpg|sbn|sbx|xml)$"
  )
  wanted <- archive_members[grepl(source_pattern, archive_members, ignore.case = TRUE)]
  required <- paste0(spec$source_basename, c(".shp", ".shx", ".dbf", ".prj"))
  if (!all(tolower(required) %in% tolower(basename(wanted)))) {
    stop("SALB archive is missing required shapefile members.", call. = FALSE)
  }

  extract_dir <- file.path(temp_dir, "extracted")
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(archive, files = wanted, exdir = extract_dir, junkpaths = TRUE)
  source_shp <- file.path(extract_dir, paste0(spec$source_basename, ".shp"))
  source_layer <- sf::st_read(source_shp, quiet = TRUE, options = "ENCODING=UTF-8")
  layers <- normalize_madagascar_salb_layers(source_layer)
  validation <- validate_madagascar_salb_layers(layers, spec)

  staging_dir <- file.path(
    dirname(output_dir),
    paste0(".madagascar-salb-staging-", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"))
  )
  if (dir.exists(staging_dir)) {
    stop("SALB staging path already exists: ", staging_dir, call. = FALSE)
  }
  dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(staging_dir, recursive = TRUE, force = TRUE), add = TRUE)

  write_madagascar_salb_layers(layers, staging_dir)
  file.copy(archive, file.path(staging_dir, spec$archive_name), overwrite = TRUE)
  source_members <- list.files(extract_dir, full.names = TRUE)
  file.copy(source_members, staging_dir, overwrite = TRUE)

  staged_layers <- read_normalized_madagascar_salb_layers(staging_dir)
  validation <- validate_madagascar_salb_layers(staged_layers, spec)
  metadata <- list(
    source = list(
      name = "United Nations Second Administrative Level Boundaries (SALB)",
      country_authority = paste(
        "Institut Geographique et Hydrographique National",
        "(Foiben-Taosarintanin'i Madagasikara)"
      ),
      source_page = spec$source_page,
      item_id = spec$item_id,
      download_url = spec$download_url,
      valid_from = spec$valid_from,
      valid_to = spec$valid_to
    ),
    source_archive = spec$archive_name,
    source_archive_sha256 = digest::digest(archive, algo = "sha256", file = TRUE),
    source_layer = spec$source_basename,
    normalized_layers = list(
      adm0 = "salb_MDG_0",
      adm1 = "salb_MDG_1",
      adm2 = "salb_MDG_2"
    ),
    feature_counts = validation$feature_counts,
    prepared_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  jsonlite::write_json(
    metadata,
    file.path(staging_dir, "salb_MDG_metadata.json"),
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  staged_files <- list.files(staging_dir, full.names = TRUE)
  copied <- file.copy(staged_files, output_dir, overwrite = TRUE)
  if (!all(copied)) {
    stop("Could not copy all prepared SALB files to ", output_dir, ".", call. = FALSE)
  }

  final_layers <- read_normalized_madagascar_salb_layers(output_dir)
  final_validation <- validate_madagascar_salb_layers(final_layers, spec)
  message(
    "Prepared Madagascar SALB boundaries: Admin-0/1/2 = ",
    paste(unlist(final_validation$feature_counts), collapse = "/")
  )
  message("Output: ", output_dir)
  invisible(list(
    output_dir = output_dir,
    validation = final_validation,
    metadata = metadata
  ))
}

main <- prepare_madagascar_salb_boundaries

if (sys.nframe() == 0L) {
  main()
}

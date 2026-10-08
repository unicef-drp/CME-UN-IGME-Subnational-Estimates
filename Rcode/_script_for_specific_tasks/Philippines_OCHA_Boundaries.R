# Prepare OCHA/HDX Philippines administrative boundaries for the pipeline.

PHILIPPINES_OCHA_DATASET_ID <- "cod-ab-phl"
PHILIPPINES_OCHA_DATASET_URL <-
  "https://data.humdata.org/dataset/cod-ab-phl"
PHILIPPINES_OCHA_CKAN_URL <- paste0(
  "https://data.humdata.org/api/3/action/package_show?id=",
  PHILIPPINES_OCHA_DATASET_ID
)

philippines_ocha_project_home <- function() {
  configured_home <- Sys.getenv("UN_SUBNATIONAL_HOME", unset = "")
  if (nzchar(configured_home)) {
    return(normalizePath(
      configured_home,
      winslash = "/",
      mustWork = TRUE
    ))
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

require_philippines_ocha_packages <- function() {
  packages <- c("sf", "jsonlite")
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

value_or_null <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NULL)
  }
  x
}

download_philippines_ocha_archive <- function(
    url,
    destfile,
    download_file = utils::download.file,
    timeout_seconds = 200000) {
  timeout_seconds <- as.numeric(timeout_seconds)
  if (length(timeout_seconds) != 1L ||
      !is.finite(timeout_seconds) ||
      timeout_seconds <= 0) {
    stop("OCHA download timeout must be a positive number of seconds.",
         call. = FALSE)
  }

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
  if (length(status) == 1L && is.numeric(status) &&
      is.finite(status) && status != 0) {
    stop("OCHA download failed with status ", status, ".", call. = FALSE)
  }
  if (!file.exists(destfile) ||
      !is.finite(file.info(destfile)$size) ||
      file.info(destfile)$size <= 0) {
    stop("OCHA download did not produce a non-empty archive.",
         call. = FALSE)
  }
  invisible(destfile)
}

select_philippines_ocha_shp_resource <- function(package) {
  resources <- Filter(
    function(resource) {
      !is.null(resource$format) &&
        identical(toupper(as.character(resource$format)), "SHP")
    },
    package$resources
  )
  if (length(resources) != 1L) {
    stop(
      "Expected exactly one HDX SHP resource; found ",
      length(resources),
      ".",
      call. = FALSE
    )
  }
  resources[[1L]]
}

repair_invalid_ocha_geometry <- function(x) {
  if (!inherits(x, "sf")) {
    stop("OCHA boundary inputs must be sf objects.", call. = FALSE)
  }
  if (is.na(sf::st_crs(x))) {
    stop("OCHA boundary input has no coordinate reference system.",
         call. = FALSE)
  }

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
    admin2 = c(
      "adm1_name", "adm1_pcode", "adm2_name", "adm2_pcode"
    )
  )
  inputs <- list(admin0 = admin0, admin1 = admin1, admin2 = admin2)

  for (level in names(inputs)) {
    missing <- setdiff(required[[level]], names(inputs[[level]]))
    if (length(missing) > 0L) {
      stop(
        level,
        " is missing OCHA field(s): ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
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

is_blank_ocha_value <- function(x) {
  is.na(x) | !nzchar(trimws(as.character(x)))
}

validate_ocha_geometry <- function(x, level) {
  if (!inherits(x, "sf")) {
    stop(level, " is not an sf object.", call. = FALSE)
  }
  if (!identical(sf::st_crs(x)$epsg, 4326L)) {
    stop(level, " is not EPSG:4326.", call. = FALSE)
  }
  geometry_types <- as.character(sf::st_geometry_type(
    x,
    by_geometry = TRUE
  ))
  if (!all(geometry_types %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop(level, " contains non-polygonal geometry.", call. = FALSE)
  }
  if (any(sf::st_is_empty(x))) {
    stop(level, " contains empty geometry.", call. = FALSE)
  }
  valid <- sf::st_is_valid(x)
  if (any(is.na(valid) | !valid)) {
    stop(level, " contains invalid geometry.", call. = FALSE)
  }
  invisible(TRUE)
}

validate_philippines_ocha_layers <- function(
    layers,
    dhs_ncr_points = NULL) {
  required_levels <- c("admin0", "admin1", "admin2")
  missing_levels <- setdiff(required_levels, names(layers))
  if (length(missing_levels) > 0L) {
    stop(
      "Missing normalized OCHA layer(s): ",
      paste(missing_levels, collapse = ", "),
      call. = FALSE
    )
  }

  counts <- vapply(layers[required_levels], nrow, integer(1))
  expected_counts <- c(admin0 = 1L, admin1 = 17L, admin2 = 88L)
  if (!identical(counts, expected_counts)) {
    stop(
      "Unexpected Philippines OCHA feature counts: ",
      paste(names(counts), counts, sep = "=", collapse = ", "),
      "; expected admin0=1, admin1=17, admin2=88.",
      call. = FALSE
    )
  }

  if (any(is_blank_ocha_value(layers$admin0$NAME_0))) {
    stop("Admin-0 has a blank NAME_0.", call. = FALSE)
  }
  if (any(is_blank_ocha_value(layers$admin1$adm1_pcode)) ||
      anyDuplicated(as.character(layers$admin1$adm1_pcode)) > 0L) {
    stop("Admin-1 codes must be non-empty and unique.", call. = FALSE)
  }
  if (any(is_blank_ocha_value(layers$admin2$adm2_pcode)) ||
      anyDuplicated(as.character(layers$admin2$adm2_pcode)) > 0L) {
    stop("Admin-2 codes must be non-empty and unique.", call. = FALSE)
  }
  if (any(is_blank_ocha_value(layers$admin2$adm1_pcode)) ||
      any(is_blank_ocha_value(layers$admin2$NAME_1))) {
    stop("Every Admin-2 feature must have a parent code and name.",
         call. = FALSE)
  }

  admin1_codes <- as.character(layers$admin1$adm1_pcode)
  admin2_parent_codes <- unique(as.character(layers$admin2$adm1_pcode))
  if (!all(admin2_parent_codes %in% admin1_codes)) {
    stop("Admin-2 parent codes are not contained in Admin-1 codes.",
         call. = FALSE)
  }
  admin1_names <- as.character(layers$admin1$NAME_1)
  admin2_parent_names <- unique(as.character(layers$admin2$NAME_1))
  if (!all(admin2_parent_names %in% admin1_names)) {
    stop("Admin-2 parent names are not contained in Admin-1 names.",
         call. = FALSE)
  }

  for (level in required_levels) {
    validate_ocha_geometry(layers[[level]], level)
  }

  ncr_name <- "National Capital Region (NCR)"
  ncr_index <- which(layers$admin1$NAME_1 == ncr_name)
  if (length(ncr_index) != 1L) {
    stop("Expected exactly one OCHA NCR Admin-1 feature.", call. = FALSE)
  }
  ncr <- layers$admin1[ncr_index, ]
  ncr_area_km2 <- as.numeric(sum(sf::st_area(
    sf::st_transform(ncr, 32651)
  ))) / 1e6
  if (!is.finite(ncr_area_km2) ||
      ncr_area_km2 < 500 ||
      ncr_area_km2 > 700) {
    stop(
      "OCHA NCR area is outside 500-700 km2: ",
      format(ncr_area_km2, digits = 8),
      ".",
      call. = FALSE
    )
  }

  dhs_ncr_within <- NULL
  if (!is.null(dhs_ncr_points)) {
    if (!inherits(dhs_ncr_points, "sf")) {
      stop("DHS NCR points must be an sf object.", call. = FALSE)
    }
    if (nrow(dhs_ncr_points) != 126L) {
      stop(
        "Expected 126 DHS 2022 NCR points; found ",
        nrow(dhs_ncr_points),
        ".",
        call. = FALSE
      )
    }
    dhs_ncr_points <- sf::st_transform(
      dhs_ncr_points,
      sf::st_crs(ncr)
    )
    within <- sf::st_within(dhs_ncr_points, ncr, sparse = FALSE)
    dhs_ncr_within <- sum(within[, 1L])
    if (dhs_ncr_within != 126L) {
      stop(
        "Only ",
        dhs_ncr_within,
        "/126 DHS 2022 NCR points fall within OCHA NCR.",
        call. = FALSE
      )
    }
  }

  list(
    feature_counts = as.list(counts),
    ncr_area_km2 = ncr_area_km2,
    dhs_ncr_points = if (is.null(dhs_ncr_points)) NULL else 126L,
    dhs_ncr_within = dhs_ncr_within
  )
}

find_ocha_source_layer <- function(extract_dir, level) {
  expected <- paste0("phl_admin", level, ".shp")
  candidates <- list.files(
    extract_dir,
    pattern = paste0("^", expected, "$"),
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(candidates) != 1L) {
    stop(
      "Expected one ",
      expected,
      " after extraction; found ",
      length(candidates),
      ".",
      call. = FALSE
    )
  }
  candidates[[1L]]
}

read_ocha_shapefile <- function(shp_file) {
  sf::st_read(
    dsn = dirname(shp_file),
    layer = tools::file_path_sans_ext(basename(shp_file)),
    quiet = TRUE,
    options = "ENCODING=UTF-8"
  )
}

read_normalized_philippines_ocha_layers <- function(boundary_dir) {
  layer_names <- c(
    admin0 = "ocha_PHL_0",
    admin1 = "ocha_PHL_1",
    admin2 = "ocha_PHL_2"
  )
  lapply(layer_names, function(layer_name) {
    sf::st_read(
      dsn = boundary_dir,
      layer = layer_name,
      quiet = TRUE,
      options = "ENCODING=UTF-8"
    )
  })
}

philippines_ocha_dhs_ncr_points <- function(project_dir) {
  dhs_dir <- file.path(
    project_dir,
    "Data", "DHS", "Philippines", "2022", "PHGE81FL"
  )
  if (!dir.exists(dhs_dir)) {
    stop("DHS 2022 Philippines GPS directory is missing: ", dhs_dir,
         call. = FALSE)
  }
  points <- sf::st_read(
    dsn = dhs_dir,
    layer = "PHGE81FL",
    quiet = TRUE,
    options = "ENCODING=UTF-8"
  )
  if (!"DHSREGNA" %in% names(points)) {
    stop("DHS 2022 GPS layer has no DHSREGNA field.", call. = FALSE)
  }
  points[points$DHSREGNA == "National Capital Region", ]
}

write_normalized_ocha_layers <- function(layers, output_dir) {
  layer_names <- c(
    admin0 = "ocha_PHL_0",
    admin1 = "ocha_PHL_1",
    admin2 = "ocha_PHL_2"
  )
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

prepare_philippines_ocha_boundaries <- function(
    project_dir = philippines_ocha_project_home(),
    source_zip = Sys.getenv("PHILIPPINES_OCHA_SHP_ZIP", unset = ""),
    output_dir = file.path(
      project_dir,
      "Data", "shapeFiles", "ocha_PHL_shp"
    )) {
  require_philippines_ocha_packages()
  project_dir <- normalizePath(
    project_dir,
    winslash = "/",
    mustWork = TRUE
  )
  output_dir <- normalizePath(
    output_dir,
    winslash = "/",
    mustWork = FALSE
  )
  if (dir.exists(output_dir) || file.exists(output_dir)) {
    stop(
      "Philippines OCHA output already exists; refusing to overwrite: ",
      output_dir,
      call. = FALSE
    )
  }

  metadata_response <- jsonlite::fromJSON(
    PHILIPPINES_OCHA_CKAN_URL,
    simplifyVector = FALSE
  )
  if (!isTRUE(metadata_response$success) ||
      is.null(metadata_response$result)) {
    stop("HDX CKAN did not return package metadata for cod-ab-phl.",
         call. = FALSE)
  }
  package <- metadata_response$result
  resource <- select_philippines_ocha_shp_resource(package)

  temp_dir <- tempfile("philippines-ocha-")
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  archive <- if (nzchar(source_zip)) {
    normalizePath(source_zip, winslash = "/", mustWork = TRUE)
  } else {
    downloaded_archive <- file.path(temp_dir, "source.zip")
    message("Downloading OCHA Philippines SHP resource: ", resource$url)
    download_philippines_ocha_archive(
      resource$url,
      destfile = downloaded_archive
    )
    downloaded_archive
  }

  archive_listing <- utils::unzip(archive, list = TRUE)$Name
  normalized_members <- gsub("\\\\", "/", archive_listing)
  member_basenames <- tolower(basename(normalized_members))
  wanted_pattern <- paste0(
    "^phl_admin[012]\\.(",
    paste(c("shp", "shx", "dbf", "prj", "cpg"), collapse = "|"),
    ")$"
  )
  wanted <- archive_listing[grepl(wanted_pattern, member_basenames)]

  required_extensions <- c("shp", "shx", "dbf", "prj")
  required_basenames <- unlist(lapply(0:2, function(level) {
    paste0("phl_admin", level, ".", required_extensions)
  }), use.names = FALSE)
  missing_members <- setdiff(required_basenames, member_basenames)
  if (length(missing_members) > 0L) {
    stop(
      "OCHA SHP archive is missing required member(s): ",
      paste(missing_members, collapse = ", "),
      call. = FALSE
    )
  }

  extract_dir <- file.path(temp_dir, "extracted")
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(archive, files = wanted, exdir = extract_dir)

  raw_layers <- list(
    admin0 = read_ocha_shapefile(find_ocha_source_layer(extract_dir, 0L)),
    admin1 = read_ocha_shapefile(find_ocha_source_layer(extract_dir, 1L)),
    admin2 = read_ocha_shapefile(find_ocha_source_layer(extract_dir, 2L))
  )
  layers <- normalize_philippines_ocha_layers(
    raw_layers$admin0,
    raw_layers$admin1,
    raw_layers$admin2
  )
  validate_philippines_ocha_layers(layers)

  staging_dir <- file.path(
    dirname(output_dir),
    paste0(
      ".ocha_PHL_shp-staging-",
      format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
    )
  )
  if (dir.exists(staging_dir) || file.exists(staging_dir)) {
    stop("OCHA staging path already exists: ", staging_dir,
         call. = FALSE)
  }
  dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
  final_created <- FALSE
  completed <- FALSE
  on.exit({
    if (dir.exists(staging_dir)) {
      unlink(staging_dir, recursive = TRUE, force = TRUE)
    }
    if (isTRUE(final_created) && !isTRUE(completed) &&
        dir.exists(output_dir)) {
      unlink(output_dir, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)

  write_normalized_ocha_layers(layers, staging_dir)
  staged_layers <- read_normalized_philippines_ocha_layers(staging_dir)
  dhs_ncr_points <- philippines_ocha_dhs_ncr_points(project_dir)
  validation <- validate_philippines_ocha_layers(
    staged_layers,
    dhs_ncr_points = dhs_ncr_points
  )

  provenance <- list(
    dataset_id = PHILIPPINES_OCHA_DATASET_ID,
    dataset_url = PHILIPPINES_OCHA_DATASET_URL,
    ckan_metadata_url = PHILIPPINES_OCHA_CKAN_URL,
    dataset = list(
      title = value_or_null(package$title),
      metadata_modified = value_or_null(package$metadata_modified),
      version = value_or_null(package$version),
      source_agencies = value_or_null(package$dataset_source),
      license = value_or_null(package$license_title)
    ),
    resource = list(
      id = value_or_null(resource$id),
      name = value_or_null(resource$name),
      url = value_or_null(resource$url),
      size = value_or_null(resource$size),
      hash = value_or_null(resource$hash),
      last_modified = value_or_null(
        if (!is.null(resource$last_modified)) {
          resource$last_modified
        } else {
          resource$modified
        }
      )
    ),
    normalized_layers = list(
      admin0 = "ocha_PHL_0",
      admin1 = "ocha_PHL_1",
      admin2 = "ocha_PHL_2"
    ),
    validation = validation,
    prepared_at_utc = format(
      Sys.time(),
      "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )
  )
  jsonlite::write_json(
    provenance,
    path = file.path(staging_dir, "ocha_download_metadata.json"),
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )

  if (!file.rename(staging_dir, output_dir)) {
    stop(
      "Could not materialize validated OCHA boundaries at ",
      output_dir,
      ".",
      call. = FALSE
    )
  }
  final_created <- TRUE
  final_layers <- read_normalized_philippines_ocha_layers(output_dir)
  final_validation <- validate_philippines_ocha_layers(
    final_layers,
    dhs_ncr_points = dhs_ncr_points
  )
  completed <- TRUE

  message(
    "Prepared OCHA Philippines boundaries: Admin-0/1/2 = ",
    paste(unlist(final_validation$feature_counts), collapse = "/")
  )
  message(
    "NCR area: ",
    format(final_validation$ncr_area_km2, digits = 6),
    " km2; DHS 2022 NCR containment: ",
    final_validation$dhs_ncr_within,
    "/126."
  )
  message("Output: ", output_dir)
  invisible(list(
    output_dir = output_dir,
    validation = final_validation,
    metadata = provenance
  ))
}

main <- prepare_philippines_ocha_boundaries

# Download UNICEF GeoRepo boundaries and normalize them as shapefiles.
#
# This follows the working 2025 GeoRepoAPI pattern:
#   1. Find the target country in the UNICEF GeoRepo latest admin-boundary view.
#   2. Pull admin1 children as full-geometry GeoJSON.
#   3. Pull admin2 children from each admin1 as full-geometry GeoJSON.
#   4. Write stable shapefile layers for the 2026 pipeline.
#
# Required environment variables:
#   GEOREPO_API_KEY
#   GEOREPO_USER_KEY  or GEOREPO_USER_EMAIL

if (!exists("country", inherits = TRUE) || !exists("iso0", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}

GEOREPO_VIEW_UUID_DEFAULT <- "3632361a-b26f-4568-82b1-391a784a6299"

georepo_output_dir <- function(home_dir, iso3) {
  file.path(home_dir, "Data", "shapeFiles", paste0("georepo_", iso3, "_shp"))
}

normalised_layer_name <- function(iso3, level) {
  paste0("georepo_", iso3, "_", level)
}

country_folder_name <- function(iso3, country) {
  clean <- gsub("[^A-Za-z0-9]+", "_", country)
  clean <- gsub("^_+|_+$", "", clean)
  paste0(iso3, "_", clean)
}

candidate_country_queries <- function(iso3, country) {
  aliases <- list(
    LAO = c("Laos", "Lao PDR", "Lao People's Democratic Republic"),
    NGA = c("Nigeria")
  )
  unique(c(iso3, country, aliases[[iso3]]))
}

get_current_script_path <- function(default_relative_path) {
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    path <- rstudioapi::getActiveDocumentContext()$path
    if (!is.null(path) && nzchar(path)) {
      return(normalizePath(path, winslash = "/", mustWork = TRUE))
    }
  }

  file_arg <- "--file="
  script_args <- commandArgs(trailingOnly = FALSE)
  script_path <- sub(file_arg, "", script_args[grepl(paste0("^", file_arg), script_args)])
  if (length(script_path) > 0) {
    return(normalizePath(script_path[1], winslash = "/", mustWork = TRUE))
  }

  normalizePath(default_relative_path, winslash = "/", mustWork = TRUE)
}

georepo_project_home <- function(script_path) {
  configured_home <- Sys.getenv("UN_SUBNATIONAL_HOME", unset = "")
  if (nzchar(configured_home)) {
    return(normalizePath(
      configured_home,
      winslash = "/",
      mustWork = FALSE
    ))
  }

  normalizePath(
    file.path(dirname(script_path), ".."),
    winslash = "/",
    mustWork = TRUE
  )
}

require_package <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("Package '", package, "' is required. Install it before running this script.", call. = FALSE)
  }
}

georepo_user_key <- function() {
  user_key <- Sys.getenv("GEOREPO_USER_KEY")
  if (!nzchar(user_key)) {
    user_key <- Sys.getenv("GEOREPO_USER_EMAIL")
  }
  user_key
}

georepo_credentials_available <- function() {
  nzchar(Sys.getenv("GEOREPO_API_KEY")) && nzchar(georepo_user_key())
}

georepo_headers <- function() {
  api_key <- Sys.getenv("GEOREPO_API_KEY")
  user_key <- georepo_user_key()
  if (!nzchar(api_key) || !nzchar(user_key)) {
    stop(
      "Set GEOREPO_API_KEY and GEOREPO_USER_KEY (or GEOREPO_USER_EMAIL) before running this script.",
      call. = FALSE
    )
  }

  httr::add_headers(
    Accept = "application/json",
    Authorization = paste("Token", api_key),
    `GeoRepo-User-Key` = user_key,
    `User-Agent` = "Mozilla/5.0"
  )
}

georepo_url <- function(api_base, path) {
  paste0(sub("/+$", "", api_base), "/", sub("^/+", "", path))
}

search_country_url <- function(api_base, view_uuid, query) {
  paste0(
    georepo_url(api_base, paste0("search/view/", view_uuid, "/entity/")),
    utils::URLencode(query, reserved = TRUE),
    "/?page=1&page_size=100"
  )
}

children_url <- function(api_base, view_uuid, parent_ucode) {
  paste0(
    georepo_url(api_base, paste0("search/view/", view_uuid, "/entity/")),
    utils::URLencode(parent_ucode, reserved = TRUE),
    "/children/?geom=full_geom&format=geojson&page_size=1000"
  )
}

get_json_url <- function(url, attempts = 4) {
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    response <- try(
      httr::GET(url, georepo_headers(), httr::timeout(120)),
      silent = TRUE
    )
    if (!inherits(response, "try-error") && httr::status_code(response) < 400) {
      return(jsonlite::fromJSON(
        httr::content(response, as = "text", encoding = "UTF-8"),
        simplifyVector = FALSE
      ))
    }
    last_error <- if (inherits(response, "try-error")) response else httr::http_status(response)$message
    if (attempt < attempts) {
      Sys.sleep(3 * attempt)
    }
  }
  stop("GeoRepo request failed for ", url, ": ", last_error, call. = FALSE)
}

find_country_feature <- function(api_base, view_uuid, iso3, country) {
  expected_ucode <- paste0(iso3, "_V1")

  for (query in candidate_country_queries(iso3, country)) {
    data <- get_json_url(search_country_url(api_base, view_uuid, query))
    results <- data$results
    if (length(results) == 0) {
      next
    }

    for (result in results) {
      if (identical(result$ucode, expected_ucode) &&
          identical(as.integer(result$admin_level), 0L)) {
        return(list(feature = result, matched_query = query))
      }
    }

    level0 <- Filter(function(x) identical(as.integer(x$admin_level), 0L), results)
    starts_iso <- Filter(function(x) grepl(paste0("^", iso3, "_"), x$ucode %||% ""), level0)
    if (length(starts_iso) > 0) {
      return(list(feature = starts_iso[[1]], matched_query = query))
    }
  }

  stop("Could not find ", country, " in GeoRepo view ", view_uuid, call. = FALSE)
}

fetch_children <- function(api_base, view_uuid, parent_ucode) {
  data <- get_json_url(children_url(api_base, view_uuid, parent_ucode))
  data$features %||% list()
}

write_geojson <- function(path, features) {
  jsonlite::write_json(
    list(type = "FeatureCollection", features = features),
    path,
    auto_unbox = TRUE,
    pretty = FALSE
  )
}

read_features_sf <- function(features) {
  temp_path <- tempfile(fileext = ".geojson")
  write_geojson(temp_path, features)
  sf::st_read(temp_path, quiet = TRUE)
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

name_column <- function(layer) {
  candidates <- c("name", "name_en", "NAME", "Name")
  hit <- candidates[candidates %in% names(layer)]
  if (length(hit) == 0) {
    stop("Could not find a GeoRepo name column.", call. = FALSE)
  }
  hit[1]
}

prepare_layer <- function(layer, level, country) {
  canonical_name_fields <- paste0("NAME_", 0:level)
  noncanonical_aliases <- names(layer)[
    tolower(names(layer)) %in% tolower(canonical_name_fields) &
      !names(layer) %in% canonical_name_fields
  ]
  if (length(noncanonical_aliases) > 0L) {
    layer[noncanonical_aliases] <- NULL
  }
  layer$NAME_0 <- country
  if (level == 0) {
    layer$NAME_0 <- country
    return(layer)
  }
  name_col <- name_column(layer)
  if (level == 1) {
    layer$NAME_1 <- as.character(layer[[name_col]])
  }
  if (level == 2) {
    layer$NAME_1 <- as.character(layer$admin1_name_from_pull %||% layer$adm1_ucode)
    layer$NAME_2 <- as.character(layer[[name_col]])
  }
  layer
}

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
    stop(
      "georepo_boundary_exclusions must be an array of rule objects.",
      call. = FALSE
    )
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
  if (any(is.na(rules$level)) || any(!rules$level %in% c(1L, 2L))) {
    stop(
      "Only Admin-1 or Admin-2 GeoRepo boundary exclusions are supported.",
      call. = FALSE
    )
  }
  if (any(is.na(rules$name) | !nzchar(rules$name)) ||
      any(is.na(rules$reason) | !nzchar(rules$reason))) {
    stop(
      "Every GeoRepo boundary exclusion needs a non-empty name and reason.",
      call. = FALSE
    )
  }
  rules
}

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
      !"NAME_1" %in% names(admin2_layer) ||
      (any(rules$level == 2L) && !"NAME_2" %in% names(admin2_layer))) {
    stop(
      "Prepared layers must contain NAME_1, and Admin-2 must contain NAME_2 ",
      "when Admin-2 exclusions are configured.",
      call. = FALSE
    )
  }

  excluded_admin1_names <- unique(rules$name[rules$level == 1L])
  missing_admin1_names <- setdiff(
    excluded_admin1_names,
    unique(as.character(admin1_layer$NAME_1))
  )
  if (length(missing_admin1_names) > 0L) {
    stop(
      "Configured GeoRepo Admin-1 exclusions were not found: ",
      paste(missing_admin1_names, collapse = ", "),
      call. = FALSE
    )
  }

  admin1_layer <- admin1_layer[
    !as.character(admin1_layer$NAME_1) %in% excluded_admin1_names,
    ,
    drop = FALSE
  ]
  admin2_layer <- admin2_layer[
    !as.character(admin2_layer$NAME_1) %in% excluded_admin1_names,
    ,
    drop = FALSE
  ]

  excluded_admin2_names <- unique(rules$name[rules$level == 2L])
  missing_admin2_names <- setdiff(
    excluded_admin2_names,
    unique(as.character(admin2_layer$NAME_2))
  )
  if (length(missing_admin2_names) > 0L) {
    stop(
      "Configured GeoRepo Admin-2 exclusions were not found: ",
      paste(missing_admin2_names, collapse = ", "),
      call. = FALSE
    )
  }
  admin2_layer <- admin2_layer[
    !as.character(admin2_layer$NAME_2) %in% excluded_admin2_names,
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

prepare_georepo_layers <- function(admin1_layer,
                                   admin2_layer,
                                   country,
                                   exclusions = NULL) {
  admin1_layer <- repair_layer_geometry(admin1_layer)
  admin2_layer <- repair_layer_geometry(admin2_layer)
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

boundary_exclusion_metadata <- function(prepared) {
  lapply(seq_len(nrow(prepared$exclusions)), function(i) {
    list(
      level = prepared$exclusions$level[[i]],
      name = prepared$exclusions$name[[i]],
      reason = prepared$exclusions$reason[[i]]
    )
  })
}

make_adm0_from_adm1 <- function(admin1_layer, country) {
  geom <- sf::st_union(sf::st_geometry(admin1_layer))
  sf::st_sf(NAME_0 = country, geometry = sf::st_sfc(geom, crs = sf::st_crs(admin1_layer)))
}

delete_existing_shapefile <- function(output_dir, layer_name) {
  existing <- list.files(
    output_dir,
    pattern = paste0("^", layer_name, "\\."),
    full.names = TRUE
  )
  if (length(existing) > 0) {
    unlink(existing)
  }
}

keep_polygonal_boundary_components <- function(layer) {
  geometry <- sf::st_geometry(layer)
  geometry_types <- as.character(sf::st_geometry_type(geometry))
  needs_extraction <- !geometry_types %in% c("POLYGON", "MULTIPOLYGON")
  if (!any(needs_extraction)) {
    return(layer)
  }

  crs <- sf::st_crs(layer)
  old_s2 <- sf::sf_use_s2()
  use_planar_union <- isTRUE(sf::st_is_longlat(layer)) && isTRUE(old_s2)
  if (use_planar_union) {
    suppressMessages(sf::sf_use_s2(FALSE))
    on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  }
  repaired_geometry <- lapply(seq_along(geometry), function(index) {
    if (!needs_extraction[[index]]) {
      return(geometry[[index]])
    }
    polygonal <- suppressWarnings(sf::st_collection_extract(
      sf::st_sfc(geometry[[index]], crs = crs),
      "POLYGON"
    ))
    if (length(polygonal) == 0L || all(sf::st_is_empty(polygonal))) {
      stop(
        "GeoRepo boundary geometry has no polygonal component.",
        call. = FALSE
      )
    }
    suppressWarnings(sf::st_union(polygonal))[[1]]
  })
  sf::st_geometry(layer) <- sf::st_sfc(repaired_geometry, crs = crs)
  layer
}

repair_layer_geometry <- function(layer) {
  if (!inherits(layer, "sf")) {
    stop("GeoRepo boundary layer must be an sf object.", call. = FALSE)
  }

  valid <- sf::st_is_valid(layer)
  needs_repair <- is.na(valid) | !valid
  if (any(needs_repair)) {
    old_s2 <- sf::sf_use_s2()
    use_planar_repair <- isTRUE(sf::st_is_longlat(layer)) && isTRUE(old_s2)
    if (use_planar_repair) {
      suppressMessages(sf::sf_use_s2(FALSE))
      on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
    }
    layer <- sf::st_make_valid(layer)
    if (use_planar_repair) {
      suppressMessages(sf::sf_use_s2(old_s2))
    }
  }
  layer <- keep_polygonal_boundary_components(layer)

  remaining_invalid <- sf::st_is_valid(layer)
  needs_spherical_repair <- is.na(remaining_invalid) | !remaining_invalid
  if (any(needs_spherical_repair) && isTRUE(sf::st_is_longlat(layer))) {
    old_s2 <- sf::sf_use_s2()
    if (!isTRUE(old_s2)) {
      suppressMessages(sf::sf_use_s2(TRUE))
      on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
    }
    repaired <- sf::st_make_valid(layer[needs_spherical_repair, , drop = FALSE])
    geometry <- sf::st_geometry(layer)
    geometry[needs_spherical_repair] <- sf::st_geometry(repaired)
    sf::st_geometry(layer) <- geometry
    layer <- keep_polygonal_boundary_components(layer)
    if (!isTRUE(old_s2)) {
      suppressMessages(sf::sf_use_s2(old_s2))
    }
    remaining_invalid <- sf::st_is_valid(layer)
  }
  if (any(is.na(remaining_invalid) | !remaining_invalid)) {
    stop("GeoRepo boundary geometry remains invalid after repair.", call. = FALSE)
  }

  layer
}

write_normalised_layer <- function(layer, output_dir, iso3, level, country) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  layer_name <- normalised_layer_name(iso3, level)
  delete_existing_shapefile(output_dir, layer_name)
  layer <- repair_layer_geometry(layer)
  layer <- prepare_layer(layer, level, country)
  sf::st_write(
    layer,
    dsn = file.path(output_dir, paste0(layer_name, ".shp")),
    driver = "ESRI Shapefile",
    quiet = TRUE
  )
  layer_name
}

write_parent_counts <- function(path, parent_rows) {
  counts <- do.call(rbind, lapply(parent_rows, as.data.frame, stringsAsFactors = FALSE))
  utils::write.csv(counts, path, row.names = FALSE, na = "")
}

existing_pull_root <- function(home_dir) {
  configured <- Sys.getenv("GEOREPO_EXISTING_PULL_ROOT")
  if (nzchar(configured)) {
    return(configured)
  }

  file.path(
    dirname(dirname(home_dir)),
    "Earlier Round",
    "2025 Round Estimation",
    "GeoRepoAPI",
    "countries"
  )
}

find_existing_georepo_pull <- function(home_dir, iso3, country) {
  configured <- Sys.getenv("GEOREPO_EXISTING_PULL_DIR")
  if (nzchar(configured)) {
    candidates <- configured
  } else {
    root <- existing_pull_root(home_dir)
    candidates <- file.path(
      root,
      vapply(candidate_country_queries(iso3, country),
             function(query) country_folder_name(iso3, query),
             character(1))
    )
  }

  candidates <- unique(candidates)
  valid <- candidates[
    file.exists(file.path(candidates, paste0(tolower(iso3), "_admin1_georepo.geojson"))) &
      file.exists(file.path(candidates, paste0(tolower(iso3), "_admin2_georepo.geojson")))
  ]
  if (length(valid) == 0) {
    return(NULL)
  }

  mtimes <- vapply(valid, function(path) {
    files <- file.path(
      path,
      paste0(tolower(iso3), c("_admin1_georepo.geojson", "_admin2_georepo.geojson"))
    )
    max(file.info(files)$mtime, na.rm = TRUE)
  }, as.POSIXct("1970-01-01"))

  valid[which.max(mtimes)]
}

materialize_existing_georepo_pull <- function(source_dir, output_dir, iso3, country) {
  require_package("jsonlite")
  require_package("sf")

  admin1_geojson <- file.path(source_dir, paste0(tolower(iso3), "_admin1_georepo.geojson"))
  admin2_geojson <- file.path(source_dir, paste0(tolower(iso3), "_admin2_georepo.geojson"))
  admin1_layer <- sf::st_read(admin1_geojson, quiet = TRUE)
  admin2_layer <- sf::st_read(admin2_geojson, quiet = TRUE)
  prepared <- prepare_georepo_layers(
    admin1_layer,
    admin2_layer,
    country,
    get0("georepo_boundary_exclusions", ifnotfound = NULL, inherits = TRUE)
  )
  admin0_layer <- prepared$admin0
  admin1_layer <- prepared$admin1
  admin2_layer <- prepared$admin2

  layers <- c(
    write_normalised_layer(admin0_layer, output_dir, iso3, 0, country),
    write_normalised_layer(admin1_layer, output_dir, iso3, 1, country),
    write_normalised_layer(admin2_layer, output_dir, iso3, 2, country)
  )

  parent_counts <- file.path(source_dir, paste0(tolower(iso3), "_admin2_parent_pull_counts.csv"))
  if (file.exists(parent_counts)) {
    file.copy(
      parent_counts,
      file.path(output_dir, paste0(tolower(iso3), "_admin2_parent_pull_counts.csv")),
      overwrite = TRUE
    )
  }

  jsonlite::write_json(
    list(
      source = "UNICEF GeoRepo",
      source_note = paste("Materialized from existing GeoRepo API pull in", source_dir),
      country = country,
      iso3 = iso3,
      admin1_features = nrow(admin1_layer),
      admin2_features = nrow(admin2_layer),
      boundary_exclusions = boundary_exclusion_metadata(prepared),
      feature_counts = prepared$counts,
      layers = as.list(layers),
      written_on = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    ),
    file.path(output_dir, "georepo_download_metadata.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )

  message("GeoRepo shapefiles are ready in ", output_dir)
  message("Layers: ", paste(layers, collapse = ", "))
  invisible(layers)
}

main <- function() {
  require_package("httr")
  require_package("jsonlite")
  require_package("sf")

  script_path <- get_current_script_path("Rcode/2_download_georepo_shapefiles.R")
  home_dir <- georepo_project_home(script_path)
  output_dir <- georepo_output_dir(home_dir, iso0)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  if (!georepo_credentials_available()) {
    source_dir <- find_existing_georepo_pull(home_dir, iso0, country)
    if (!is.null(source_dir)) {
      message("GeoRepo credentials are not set; using existing GeoRepo API pull: ", source_dir)
      return(materialize_existing_georepo_pull(source_dir, output_dir, iso0, country))
    }
  }

  api_base <- Sys.getenv("GEOREPO_API_BASE", "https://georepo.unicef.org/api/v1")
  view_uuid <- Sys.getenv("GEOREPO_VIEW_UUID", GEOREPO_VIEW_UUID_DEFAULT)

  country_match <- find_country_feature(api_base, view_uuid, iso0, country)
  country_ucode <- country_match$feature$ucode
  message("Matched ", country, " as ", country_ucode, " using query '", country_match$matched_query, "'.")

  admin1_features <- fetch_children(api_base, view_uuid, country_ucode)
  for (i in seq_along(admin1_features)) {
    admin1_features[[i]]$properties$adm0_ucode_from_pull <- country_ucode
  }
  admin1_geojson <- file.path(output_dir, paste0(tolower(iso0), "_admin1_georepo.geojson"))
  write_geojson(admin1_geojson, admin1_features)

  admin2_features <- list()
  parent_rows <- list()
  for (feature in admin1_features) {
    props <- feature$properties
    parent_ucode <- props$ucode
    parent_name <- props$name %||% parent_ucode
    if (!nzchar(parent_ucode %||% "")) {
      parent_rows[[length(parent_rows) + 1]] <- list(
        admin1 = parent_name,
        admin1_ucode = "",
        admin2_features = 0,
        status = "missing_parent_ucode"
      )
      next
    }

    children <- fetch_children(api_base, view_uuid, parent_ucode)
    for (j in seq_along(children)) {
      children[[j]]$properties$admin1_name_from_pull <- parent_name
      children[[j]]$properties$admin1_ucode_from_pull <- parent_ucode
    }
    admin2_features <- c(admin2_features, children)
    parent_rows[[length(parent_rows) + 1]] <- list(
      admin1 = parent_name,
      admin1_ucode = parent_ucode,
      admin2_features = length(children),
      status = "ok"
    )
    Sys.sleep(0.05)
  }
  admin2_geojson <- file.path(output_dir, paste0(tolower(iso0), "_admin2_georepo.geojson"))
  write_geojson(admin2_geojson, admin2_features)
  write_parent_counts(
    file.path(output_dir, paste0(tolower(iso0), "_admin2_parent_pull_counts.csv")),
    parent_rows
  )

  admin1_layer <- read_features_sf(admin1_features)
  admin2_layer <- read_features_sf(admin2_features)
  prepared <- prepare_georepo_layers(
    admin1_layer,
    admin2_layer,
    country,
    get0("georepo_boundary_exclusions", ifnotfound = NULL, inherits = TRUE)
  )
  admin0_layer <- prepared$admin0
  admin1_layer <- prepared$admin1
  admin2_layer <- prepared$admin2

  layers <- c(
    write_normalised_layer(admin0_layer, output_dir, iso0, 0, country),
    write_normalised_layer(admin1_layer, output_dir, iso0, 1, country),
    write_normalised_layer(admin2_layer, output_dir, iso0, 2, country)
  )

  jsonlite::write_json(
    list(
      source = "UNICEF GeoRepo",
      api_base = api_base,
      view_uuid = view_uuid,
      country = country,
      iso3 = iso0,
      country_ucode = country_ucode,
      matched_query = country_match$matched_query,
      admin1_features = nrow(admin1_layer),
      admin2_features = nrow(admin2_layer),
      boundary_exclusions = boundary_exclusion_metadata(prepared),
      feature_counts = prepared$counts,
      downloaded_on = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
      layers = as.list(layers)
    ),
    file.path(output_dir, "georepo_download_metadata.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )

  message("GeoRepo shapefiles are ready in ", output_dir)
  message("Layers: ", paste(layers, collapse = ", "))
}

if (sys.nframe() == 0) {
  main()
}

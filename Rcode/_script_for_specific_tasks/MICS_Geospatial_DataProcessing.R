get_current_script_path <- function() {
  frames <- sys.frames()
  ofiles <- vapply(frames, function(frame) {
    if (!is.null(frame$ofile)) as.character(frame$ofile) else NA_character_
  }, character(1))
  ofiles <- ofiles[!is.na(ofiles) & nzchar(ofiles)]
  if (length(ofiles) > 0) {
    return(normalizePath(tail(ofiles, 1), winslash = "/", mustWork = FALSE))
  }

  file_arg <- "--file="
  script_args <- commandArgs(trailingOnly = FALSE)
  script_path <- sub(file_arg, "", script_args[grepl(paste0("^", file_arg), script_args)])
  if (length(script_path) > 0) {
    return(normalizePath(script_path[1], winslash = "/", mustWork = FALSE))
  }

  stop("Cannot determine script path. Run this script with Rscript or source().",
       call. = FALSE)
}

script.path <- get_current_script_path()
home.dir <- normalizePath(file.path(dirname(script.path), "..", ".."),
                          winslash = "/", mustWork = FALSE)
base::source(file.path(home.dir, "Rcode", "_supporting_scripts",
                       "project_paths.R"))
base::source(file.path(home.dir, "Rcode", "_supporting_scripts",
                       "urban_frame_matching.R"))
use_path_base(home.dir)

options(gsubfn.engine = "R")
options(tibble.width = 400)
options(warn = 0)

library(dplyr)
library(haven)
library(SUMMER)
library(sf)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}

require_columns <- function(data, columns, data_name) {
  missing_columns <- setdiff(columns, names(data))
  if (length(missing_columns) > 0) {
    stop(data_name, " is missing required columns: ",
         paste(missing_columns, collapse = ", "), call. = FALSE)
  }
}

labelled_value_names <- function(x) {
  labels <- attr(x, "labels")
  out <- rep(NA_character_, length(x))
  if (is.null(labels)) {
    return(out)
  }

  for (label_name in names(labels)) {
    out[as.character(x) == as.character(labels[[label_name]])] <- label_name
  }
  out
}

prepare_mics_geospatial_births <- function(bh_path,
                                           survey_year,
                                           beg.year = 2000,
                                           age.truncate = 24,
                                           keep_survey_admin1 = FALSE) {
  bh_path <- resolve_project_path(bh_path, project_home())
  if (!base::file.exists(bh_path)) {
    stop("MICS birth-history file not found: ", bh_path, call. = FALSE)
  }

  bh <- haven::read_sav(bh_path)
  require_columns(
    bh,
    c("HH1", "BH4C", "BH5", "BH9C", "HH6", "HH7", "WDOI", "wmweight"),
    "MICS birth-history data"
  )

  bh <- bh %>%
    dplyr::select(HH1, BH4C, BH5, BH9C, HH6, HH7, WDOI, wmweight) %>%
    dplyr::mutate(
      urban = dplyr::case_when(
        HH6 == 1 ~ "urban",
        HH6 == 2 ~ "rural",
        TRUE ~ NA_character_
      ),
      alive = dplyr::case_when(
        BH5 == 1 ~ "yes",
        BH5 == 2 ~ "no",
        TRUE ~ NA_character_
      ),
      survey_admin1.name = labelled_value_names(HH7)
    ) %>%
    dplyr::filter(!is.na(BH4C), !is.na(alive), !is.na(urban))

  dat.tmp <- SUMMER::getBirths(
    data = bh,
    surveyyear = survey_year,
    variables = c(
      "HH1", "BH4C", "BH9C", "WDOI", "alive", "wmweight",
      "urban", "survey_admin1.name"
    ),
    strata = c("urban", "survey_admin1.name"),
    dob = "BH4C",
    alive = "alive",
    age = "BH9C",
    date.interview = "WDOI",
    age.truncate = age.truncate,
    year.cut = seq(beg.year, survey_year + 1, 1),
    compact.by = c("HH1", "wmweight", "urban", "survey_admin1.name"),
    compact = TRUE
  )

  selected_columns <- c(
    "HH1", "age", "time", "total", "died", "wmweight", "urban"
  )
  if (isTRUE(keep_survey_admin1)) {
    selected_columns <- c(selected_columns, "survey_admin1.name")
  }
  dat.tmp <- dat.tmp[, selected_columns]
  colnames(dat.tmp)[seq_len(7)] <- c(
    "cluster", "age", "years", "total", "Y", "v005", "urban"
  )
  dat.tmp$survey <- survey_year
  dat.tmp
}

read_mics_gps_clusters <- function(gps_path) {
  gps_path <- resolve_project_path(gps_path, project_home())
  if (!base::file.exists(gps_path)) {
    stop("MICS GPS shapefile not found: ", gps_path, call. = FALSE)
  }

  gps <- sf::st_read(gps_path, quiet = TRUE, options = "ENCODING=UTF-8")
  gps_data <- sf::st_drop_geometry(gps)
  require_columns(gps_data, c("HH1", "LONGITUDE", "LATITUDE"), "MICS GPS data")

  gps_data <- gps_data %>%
    dplyr::transmute(
      cluster = as.integer(HH1),
      LONGNUM = as.numeric(LONGITUDE),
      LATNUM = as.numeric(LATITUDE),
      gps_admin1.name = if ("GEONAMES" %in% names(gps_data)) {
        as.character(GEONAMES)
      } else {
        NA_character_
      },
      gps_admin2.name = if ("GEONAMET" %in% names(gps_data)) {
        as.character(GEONAMET)
      } else {
        NA_character_
      }
    ) %>%
    dplyr::filter(
      !is.na(cluster),
      !is.na(LONGNUM),
      !is.na(LATNUM),
      !(LONGNUM == 0 & LATNUM == 0)
    )

  duplicate_clusters <- unique(gps_data$cluster[duplicated(gps_data$cluster)])
  if (length(duplicate_clusters) > 0) {
    stop("MICS GPS data has duplicate cluster rows: ",
         paste(duplicate_clusters, collapse = ", "), call. = FALSE)
  }

  list(data = gps_data, crs = sf::st_crs(gps))
}

align_point_crs <- function(points, polygons) {
  polygon_crs <- sf::st_crs(polygons)
  if (is.na(sf::st_crs(points))) {
    sf::st_crs(points) <- polygon_crs
    return(points)
  }
  if (!is.na(polygon_crs) && sf::st_crs(points) != polygon_crs) {
    points <- sf::st_transform(points, polygon_crs)
  }
  points
}

assign_points_to_admin <- function(points, polygons, label_col, admin_prefix) {
  require_columns(polygons, label_col, "GeoRepo polygon data")
  points <- align_point_crs(points, polygons)

  within_index <- sf::st_within(points, polygons)
  admin_index <- vapply(within_index, function(index) {
    if (length(index) == 0) NA_integer_ else index[[1]]
  }, integer(1))

  missing_admin <- is.na(admin_index)
  if (any(missing_admin)) {
    message(
      sum(missing_admin), " MICS GPS clusters were outside ",
      admin_prefix, " polygons; assigning nearest polygon."
    )
    admin_index[missing_admin] <- sf::st_nearest_feature(
      points[missing_admin, ], polygons
    )
  }

  data.frame(
    cluster = points$cluster,
    admin = admin_index,
    admin.char = paste0(admin_prefix, "_", admin_index),
    admin.name = repair_utf8_text(
      as.character(polygons[[label_col]][admin_index])
    ),
    stringsAsFactors = FALSE
  )
}

assign_mics_geospatial_admins <- function(dat.tmp,
                                          gps_path,
                                          poly.adm1,
                                          poly.label.adm1,
                                          poly.adm2 = NULL,
                                          poly.label.adm2 = NULL) {
  require_columns(dat.tmp, c("cluster", "urban"), "dat.tmp")

  gps_clusters <- read_mics_gps_clusters(gps_path)
  dat.tmp <- dat.tmp %>%
    dplyr::mutate(cluster = as.integer(cluster)) %>%
    dplyr::left_join(gps_clusters$data, by = "cluster") %>%
    dplyr::filter(!is.na(LONGNUM), !is.na(LATNUM))

  cluster_coords <- unique(dat.tmp[, c("cluster", "LONGNUM", "LATNUM")])
  if (any(duplicated(cluster_coords$cluster))) {
    stop("Some MICS clusters have more than one GPS coordinate pair.",
         call. = FALSE)
  }

  point_crs <- gps_clusters$crs %||% sf::st_crs(4326)
  cluster_points <- sf::st_as_sf(
    cluster_coords,
    coords = c("LONGNUM", "LATNUM"),
    crs = point_crs,
    remove = FALSE
  )

  admin1_key <- assign_points_to_admin(
    cluster_points, poly.adm1, poly.label.adm1, "admin1"
  )
  colnames(admin1_key) <- c(
    "cluster", "admin1", "admin1.char", "admin1.name"
  )

  dat.tmp <- dat.tmp %>% dplyr::left_join(admin1_key, by = "cluster")

  if (!is.null(poly.adm2)) {
    if (is.null(poly.label.adm2)) {
      stop("poly.label.adm2 must be provided when poly.adm2 is used.",
           call. = FALSE)
    }
    admin2_key <- assign_points_to_admin(
      cluster_points, poly.adm2, poly.label.adm2, "admin2"
    )
    colnames(admin2_key) <- c(
      "cluster", "admin2", "admin2.char", "admin2.name"
    )
    dat.tmp <- dat.tmp %>% dplyr::left_join(admin2_key, by = "cluster")
    dat.tmp$strata <- paste(dat.tmp$admin2, dat.tmp$urban, sep = ":")
  } else {
    dat.tmp$strata <- paste(dat.tmp$admin1, dat.tmp$urban, sep = ":")
  }

  dat.tmp$survey.type <- "MICS"

  if (!is.null(poly.adm2)) {
    dat.tmp <- dat.tmp[, c(
      "cluster", "age", "years", "total", "Y", "v005", "urban",
      "LONGNUM", "LATNUM", "strata", "admin1", "admin2",
      "admin1.char", "admin2.char", "admin1.name", "admin2.name",
      "survey", "survey.type"
    )]
  } else {
    dat.tmp <- dat.tmp[, c(
      "cluster", "age", "years", "total", "Y", "v005", "urban",
      "LONGNUM", "LATNUM", "strata", "admin1", "admin1.char",
      "admin1.name", "survey", "survey.type"
    )]
  }

  dat.tmp
}

load_country_georepo_boundaries <- function(country_name) {
  info_env <- new.env(parent = globalenv())
  load.country.info(country_name, envir = info_env)

  data.dir <- country_data_dir(project_home(), info_env$country)
  poly.path <- resolve_country_data_path(info_env$poly.path, data.dir)

  poly.adm1 <- sf::st_read(
    dsn = poly.path,
    layer = info_env$poly.layer.adm1,
    quiet = TRUE,
    options = "ENCODING=UTF-8"
  )
  poly.adm1[[info_env$poly.label.adm1]] <- repair_utf8_text(
    poly.adm1[[info_env$poly.label.adm1]]
  )

  poly.adm2 <- NULL
  if (exists("poly.layer.adm2", envir = info_env, inherits = FALSE)) {
    poly.adm2 <- sf::st_read(
      dsn = poly.path,
      layer = info_env$poly.layer.adm2,
      quiet = TRUE,
      options = "ENCODING=UTF-8"
    )
    poly.adm2[[info_env$poly.label.adm2]] <- repair_utf8_text(
      poly.adm2[[info_env$poly.label.adm2]]
    )
    if (info_env$poly.label.adm1 %in% names(poly.adm2)) {
      poly.adm2[[info_env$poly.label.adm1]] <- repair_utf8_text(
        poly.adm2[[info_env$poly.label.adm1]]
      )
    }
    sf::st_crs(poly.adm2) <- sf::st_crs(poly.adm1)
  }

  list(
    info = info_env,
    poly.adm1 = poly.adm1,
    poly.adm2 = poly.adm2,
    poly.label.adm1 = info_env$poly.label.adm1,
    poly.label.adm2 = if (exists("poly.label.adm2", envir = info_env,
                                  inherits = FALSE)) {
      info_env$poly.label.adm2
    } else {
      NULL
    }
  )
}

process_nigeria_mics_2021_geospatial <- function(
    bh_path = file.path("Data", "MICS", "Nigeria", "2021", "bh.sav"),
    gps_path = file.path("Data", "MICS", "Nigeria", "2021", "GPS",
                         "NigeriaMICS2021GPS.shp"),
    output_file = file.path("Data", "MICS", "Nigeria", "2021",
                            "nga.2021.geo.tmp.rda")) {
  boundaries <- load_country_georepo_boundaries("Nigeria")
  beg.year <- boundaries$info$beg.year

  dat.tmp <- prepare_mics_geospatial_births(
    bh_path = bh_path,
    survey_year = 2021,
    beg.year = beg.year,
    age.truncate = 24
  )
  dat.tmp <- assign_mics_geospatial_admins(
    dat.tmp = dat.tmp,
    gps_path = gps_path,
    poly.adm1 = boundaries$poly.adm1,
    poly.label.adm1 = boundaries$poly.label.adm1,
    poly.adm2 = boundaries$poly.adm2,
    poly.label.adm2 = boundaries$poly.label.adm2
  )

  output_file <- resolve_project_path(output_file, project_home())
  base::dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  base::save(dat.tmp, file = output_file)
  message("Saved Nigeria MICS 2021 geospatial tmp data: ", output_file)
  invisible(dat.tmp)
}

process_ghana_mics_2011_nongeospatial <- function(
    bh_path = file.path("Data", "MICS", "Ghana", "gha_2011_bh.sav"),
    output_file = file.path("Data", "MICS", "Ghana", "gha.2011.tmp.rda")) {
  boundaries <- load_country_georepo_boundaries("Ghana")
  dat.tmp <- prepare_mics_geospatial_births(
    bh_path = bh_path,
    survey_year = 2011,
    beg.year = boundaries$info$beg.year,
    age.truncate = 24,
    keep_survey_admin1 = TRUE
  )

  dat.tmp$admin1.name <- dplyr::recode(
    as.character(dat.tmp$survey_admin1.name),
    "Asante" = "Ashanti"
  )
  expected_admin1 <- sort(unique(as.character(
    boundaries$poly.adm1[[boundaries$poly.label.adm1]]
  )))
  unexpected_admin1 <- setdiff(unique(dat.tmp$admin1.name), expected_admin1)
  if (length(unexpected_admin1) > 0L) {
    stop(
      "Ghana MICS 2011 has Admin-1 names not found in GeoRepo: ",
      paste(unexpected_admin1, collapse = ", "),
      call. = FALSE
    )
  }
  dat.tmp <- dat.tmp[, c(
    "cluster", "age", "years", "total", "Y", "v005", "urban",
    "admin1.name", "survey"
  )]

  output_file <- resolve_project_path(output_file, project_home())
  base::dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  base::save(dat.tmp, file = output_file)
  message("Saved Ghana MICS 2011 non-geospatial tmp data: ", output_file)
  invisible(dat.tmp)
}

process_ghana_mics_2018_geospatial <- function(
    bh_path = file.path("Data", "MICS", "Ghana", "gha_2018_bh.sav"),
    gps_path = file.path("Data", "MICS", "Ghana", "2018", "GPS",
                         "GhanaMICS2017-18GPS.shp"),
    output_file = file.path("Data", "MICS", "Ghana", "2018",
                            "gha.2018.geo.tmp.rda")) {
  boundaries <- load_country_georepo_boundaries("Ghana")
  dat.tmp <- prepare_mics_geospatial_births(
    bh_path = bh_path,
    survey_year = 2018,
    beg.year = boundaries$info$beg.year,
    age.truncate = 24
  )
  dat.tmp <- assign_mics_geospatial_admins(
    dat.tmp = dat.tmp,
    gps_path = gps_path,
    poly.adm1 = boundaries$poly.adm1,
    poly.label.adm1 = boundaries$poly.label.adm1,
    poly.adm2 = boundaries$poly.adm2,
    poly.label.adm2 = boundaries$poly.label.adm2
  )

  output_file <- resolve_project_path(output_file, project_home())
  base::dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  base::save(dat.tmp, file = output_file)
  message("Saved Ghana MICS 2018 geospatial tmp data: ", output_file)
  invisible(dat.tmp)
}

process_ghana_mics_geospatial <- function() {
  process_ghana_mics_2011_nongeospatial()
  process_ghana_mics_2018_geospatial()
  invisible(TRUE)
}

process_lesotho_mics_2018_geospatial <- function(
    bh_path = file.path("Data", "MICS", "Lesotho", "lso_2018_bh.sav"),
    gps_path = file.path("Data", "MICS", "Lesotho", "2018", "GPS",
                         "LesothoMICS2018GPS.shp"),
    output_file = file.path("Data", "MICS", "Lesotho", "2018",
                            "lso.2018.geo.tmp.rda")) {
  boundaries <- load_country_georepo_boundaries("Lesotho")
  dat.tmp <- prepare_mics_geospatial_births(
    bh_path = bh_path,
    survey_year = 2018,
    beg.year = boundaries$info$beg.year,
    age.truncate = 24
  )
  dat.tmp <- assign_mics_geospatial_admins(
    dat.tmp = dat.tmp,
    gps_path = gps_path,
    poly.adm1 = boundaries$poly.adm1,
    poly.label.adm1 = boundaries$poly.label.adm1
  )

  if (!is.null(boundaries$poly.adm2)) {
    repair_env <- new.env(parent = baseenv())
    sys.source(file.path(project_home(), 'Rcode', '_supporting_scripts',
                         'restore_cluster_admin2.R'), envir = repair_env)
    name_map <- data.frame(
      GeoRepo = boundaries$poly.adm2[[boundaries$poly.label.adm2]],
      Internal = paste0('admin2_', seq_len(nrow(boundaries$poly.adm2)))
    )
    dat.tmp <- repair_env$restore_cluster_admin2_from_gps(
      dat.tmp, boundaries$poly.adm2, boundaries$poly.label.adm2, name_map
    )$data
  }
  output_file <- resolve_project_path(output_file, project_home())
  base::dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  base::save(dat.tmp, file = output_file)
  message("Saved Lesotho MICS 2018 configured-admin geospatial tmp data: ", output_file)
  invisible(dat.tmp)
}

script_args <- commandArgs(trailingOnly = FALSE)
script_file_arg <- sub(
  "^--file=", "",
  script_args[grepl("^--file=", script_args)]
)
if (length(script_file_arg) > 0 &&
    identical(normalizePath(script_file_arg[1], winslash = "/", mustWork = FALSE),
              script.path)) {
  process_nigeria_mics_2021_geospatial()
}

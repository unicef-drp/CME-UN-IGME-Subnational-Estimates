script_file <- file.path(
  "Rcode", "_script_for_specific_tasks", "MICS_Geospatial_DataProcessing.R"
)
if (!file.exists(script_file)) {
  stop("Missing MICS geospatial preprocessing script: ", script_file)
}

script_env <- new.env(parent = globalenv())
source(script_file, local = script_env)

required_functions <- c(
  "process_ghana_mics_2011_nongeospatial",
  "process_ghana_mics_2018_geospatial",
  "process_ghana_mics_geospatial"
)
missing_functions <- required_functions[
  !vapply(required_functions, exists, logical(1),
          envir = script_env, inherits = FALSE)
]
if (length(missing_functions) > 0) {
  stop("MICS geospatial script is missing Ghana functions: ",
       paste(missing_functions, collapse = ", "))
}

artifact_files <- c(
  `2011` = file.path("Data", "MICS", "Ghana", "gha.2011.tmp.rda"),
  `2018` = file.path(
    "Data", "MICS", "Ghana", "2018", "gha.2018.geo.tmp.rda"
  )
)
missing_artifacts <- artifact_files[!file.exists(artifact_files)]
if (length(missing_artifacts) > 0) {
  stop("Missing Ghana MICS artifact(s): ",
       paste(missing_artifacts, collapse = ", "))
}

load_dat_tmp <- function(path) {
  artifact_env <- new.env(parent = emptyenv())
  load(path, envir = artifact_env)
  if (!exists("dat.tmp", envir = artifact_env, inherits = FALSE)) {
    stop("Expected dat.tmp in ", path)
  }
  get("dat.tmp", envir = artifact_env)
}

ghana_admin1 <- c(
  "Ashanti", "Brong Ahafo", "Central", "Eastern", "Greater Accra",
  "Northern", "Upper East", "Upper West", "Volta", "Western"
)

dat_2011 <- load_dat_tmp(artifact_files[["2011"]])
dat_2018 <- load_dat_tmp(artifact_files[["2018"]])
boundaries <- script_env$load_country_georepo_boundaries("Ghana")
required_admin2_columns <- c(
  "admin2", "admin2.char", "admin2.name"
)

stopifnot(
  identical(sort(unique(dat_2011$survey)), 2011),
  identical(sort(unique(dat_2018$survey)), 2018),
  identical(sort(unique(as.character(dat_2011$admin1.name))),
            ghana_admin1),
  identical(sort(unique(as.character(dat_2018$admin1.name))),
            ghana_admin1),
  length(unique(dat_2018$cluster)) == 660L,
  !anyNA(dat_2018$LONGNUM),
  !anyNA(dat_2018$LATNUM),
  !anyNA(dat_2018$admin1),
  !anyNA(dat_2018$admin1.char),
  all(required_admin2_columns %in% names(dat_2018)),
  !anyNA(dat_2018$admin2),
  !anyNA(dat_2018$admin2.char),
  !anyNA(dat_2018$admin2.name),
  all(dat_2018$admin2.name %in% boundaries$poly.adm2$NAME_2),
  all(dat_2018$admin1.name == boundaries$poly.adm2$NAME_1[dat_2018$admin2]),
  !anyNA(dat_2018$strata),
  all(dat_2018$survey.type == "MICS")
)

cat("Ghana MICS 2011 and GPS-based 2018 Admin-2 artifacts are valid.\n")

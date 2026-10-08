script_file <- file.path(
  "Rcode", "_script_for_specific_tasks", "MICS_Geospatial_DataProcessing.R"
)
script_env <- new.env(parent = globalenv())
source(script_file, local = script_env)

artifact_files <- c(
  `2017` = file.path("Data", "MICS", "Laos", "2017", "lao.2017.geo.tmp.rda"),
  `2023` = file.path("Data", "MICS", "Laos", "2023", "lao.2023.geo.tmp.rda")
)
missing_artifacts <- artifact_files[!file.exists(artifact_files)]
if (length(missing_artifacts) > 0L) {
  stop("Missing Laos geospatial MICS artifact(s): ",
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

boundaries <- script_env$load_country_georepo_boundaries("Laos")
required_columns <- c(
  "cluster", "survey", "survey.type", "LONGNUM", "LATNUM",
  "admin1", "admin1.char", "admin1.name",
  "admin2", "admin2.char", "admin2.name", "strata"
)

for (survey_year in names(artifact_files)) {
  dat <- load_dat_tmp(artifact_files[[survey_year]])
  stopifnot(
    isTRUE(all.equal(sort(unique(dat$survey)), as.numeric(survey_year))),
    all(required_columns %in% names(dat)),
    nrow(dat) > 0L,
    length(unique(dat$cluster)) > 0L,
    !anyNA(dat[, required_columns]),
    all(dat$survey.type == "MICS"),
    all(dat$admin1.name %in% boundaries$poly.adm1$NAME_1),
    all(dat$admin2.name %in% boundaries$poly.adm2$NAME_2),
    all(dat$admin1.name == boundaries$poly.adm2$NAME_1[dat$admin2])
  )
}

cat("Laos MICS 2017 and 2023 GPS-based Admin-2 artifacts are valid.\n")

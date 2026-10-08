project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
Sys.setenv(UN_SUBNATIONAL_HOME = project_dir)

source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

artifact <- file.path(
  "Data",
  "MICS",
  "Gambia",
  "2018",
  "Gambia_2018.geo.tmp.rda"
)
stopifnot(file.exists(artifact))

artifact_env <- new.env(parent = emptyenv())
load(artifact, envir = artifact_env)
stopifnot(exists("dat.tmp", envir = artifact_env, inherits = FALSE))
dat.tmp <- get("dat.tmp", envir = artifact_env)

required <- c(
  "cluster", "age", "years", "total", "Y", "v005", "urban",
  "LONGNUM", "LATNUM", "strata", "admin1", "admin2",
  "admin1.char", "admin2.char", "admin1.name", "admin2.name",
  "survey", "survey.type"
)
stopifnot(all(required %in% names(dat.tmp)))

source(file.path(
  "Rcode",
  "_script_for_specific_tasks",
  "MICS_Geospatial_DataProcessing.R"
))
boundaries <- load_country_georepo_boundaries("Gambia")
expected_parent <- as.character(
  boundaries$poly.adm2$NAME_1[as.integer(dat.tmp$admin2)]
)

stopifnot(
  nrow(dat.tmp) == 43145L,
  length(unique(dat.tmp$cluster)) == 390L,
  identical(sort(unique(dat.tmp$survey)), 2018),
  all(dat.tmp$survey.type == "MICS"),
  all(is.finite(dat.tmp$LONGNUM)),
  all(is.finite(dat.tmp$LATNUM)),
  !anyNA(dat.tmp$strata),
  length(unique(dat.tmp$admin1.name)) == 8L,
  length(unique(dat.tmp$admin2.name)) == 36L,
  identical(as.character(dat.tmp$admin1.name), expected_parent)
)

cat(
  "Gambia MICS 2018 geospatial preprocessing artifact passes its data contract.\n"
)

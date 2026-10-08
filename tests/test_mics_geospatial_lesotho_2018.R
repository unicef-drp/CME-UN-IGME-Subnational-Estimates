script_file <- file.path(
  "Rcode", "_script_for_specific_tasks", "MICS_Geospatial_DataProcessing.R"
)
script_env <- new.env(parent = globalenv())
source(script_file, local = script_env)

if (!exists("process_lesotho_mics_2018_geospatial",
            envir = script_env, inherits = FALSE)) {
  stop("MICS geospatial script is missing the Lesotho 2018 processor.")
}

artifact_file <- file.path(
  "Data", "MICS", "Lesotho", "2018", "lso.2018.geo.tmp.rda"
)
if (!file.exists(artifact_file)) {
  stop("Missing Lesotho MICS 2018 geospatial artifact: ", artifact_file)
}

artifact_env <- new.env(parent = emptyenv())
load(artifact_file, envir = artifact_env)
if (!exists("dat.tmp", envir = artifact_env, inherits = FALSE)) {
  stop("Expected dat.tmp in ", artifact_file)
}
dat.tmp <- get("dat.tmp", envir = artifact_env)

lesotho_admin1 <- c(
  "Berea", "Butha-Buthe", "Leribe", "Mafeteng", "Maseru",
  "Mohale'S Hoek", "Mokhotlong", "Qacha'S Nek", "Quthing", "Thaba-Tseka"
)

stopifnot(
  identical(sort(unique(dat.tmp$survey)), 2018),
  identical(sort(unique(as.character(dat.tmp$admin1.name))),
            lesotho_admin1),
  length(unique(dat.tmp$cluster)) == 400L,
  !anyNA(dat.tmp$LONGNUM),
  !anyNA(dat.tmp$LATNUM),
  !anyNA(dat.tmp$admin1),
  !anyNA(dat.tmp$admin1.char),
  !anyNA(dat.tmp$strata),
  all(dat.tmp$survey.type == "MICS")
)

info <- jsonlite::read_json('Info/Lesotho_general_info.json')
if (!is.null(info[['poly.layer.adm2']]) && nzchar(info[['poly.layer.adm2']])) {
  stopifnot(all(c('admin2','admin2.char','admin2.name') %in% names(dat.tmp)),
            !anyNA(dat.tmp$admin2.char))
}

cat("Lesotho MICS 2018 GPS artifact covers all 400 clusters and 10 Admin-1 areas.\n")

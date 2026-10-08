script_file <- file.path(
  "Rcode", "_script_for_specific_tasks", "MICS_Geospatial_DataProcessing.R"
)
if (!file.exists(script_file)) {
  stop("Missing MICS geospatial preprocessing script: ", script_file)
}

script_env <- new.env(parent = globalenv())
source(script_file, local = script_env)

required_functions <- c(
  "prepare_mics_geospatial_births",
  "assign_mics_geospatial_admins",
  "process_nigeria_mics_2021_geospatial"
)
missing_functions <- required_functions[
  !vapply(required_functions, exists, logical(1),
          envir = script_env, inherits = FALSE)
]
if (length(missing_functions) > 0) {
  stop("MICS geospatial script is missing functions: ",
       paste(missing_functions, collapse = ", "))
}

output_file <- file.path(
  "Data", "MICS", "Nigeria", "2021", "nga.2021.geo.tmp.rda"
)
if (!file.exists(output_file)) {
  stop("Prepared Nigeria MICS 2021 geospatial file is missing: ", output_file)
}

tmp_env <- new.env(parent = emptyenv())
load(output_file, envir = tmp_env)
if (!exists("dat.tmp", envir = tmp_env, inherits = FALSE)) {
  stop("Expected dat.tmp in ", output_file)
}

dat.tmp <- get("dat.tmp", envir = tmp_env)
expected_cols <- c(
  "cluster", "age", "years", "total", "Y", "v005", "urban",
  "LONGNUM", "LATNUM", "strata", "admin1", "admin1.char",
  "admin1.name", "survey", "survey.type"
)
missing_cols <- setdiff(expected_cols, names(dat.tmp))
if (length(missing_cols) > 0) {
  stop("Nigeria MICS geospatial tmp data is missing columns: ",
       paste(missing_cols, collapse = ", "))
}

if (!identical(sort(unique(dat.tmp$survey)), 2021)) {
  stop("Nigeria MICS geospatial tmp data should only contain survey year 2021.")
}

if (!all(dat.tmp$survey.type == "MICS")) {
  stop("Nigeria MICS geospatial rows should have survey.type == 'MICS'.")
}

if (anyNA(dat.tmp$LONGNUM) || anyNA(dat.tmp$LATNUM)) {
  stop("Nigeria MICS geospatial rows should keep non-missing coordinates.")
}

if (anyNA(dat.tmp$admin1) || anyNA(dat.tmp$admin1.char) ||
    anyNA(dat.tmp$admin1.name) || anyNA(dat.tmp$strata)) {
  stop("Nigeria MICS geospatial rows should have admin1 IDs, names, and strata.")
}

if (!all(c("urban", "rural") %in% unique(dat.tmp$urban))) {
  stop("Nigeria MICS geospatial tmp data should include urban and rural rows.")
}

if ("FCT Abuja" %in% unique(dat.tmp$admin1.name)) {
  stop("Nigeria MICS geospatial admin names should use GeoRepo names, not MICS labels.")
}

if (!"Federal Capital Territory" %in% unique(dat.tmp$admin1.name)) {
  stop("Nigeria MICS geospatial rows should include Federal Capital Territory.")
}

cluster_coords <- unique(dat.tmp[, c("cluster", "LONGNUM", "LATNUM")])
if (any(duplicated(cluster_coords$cluster))) {
  stop("Each Nigeria MICS geospatial cluster should have one coordinate pair.")
}

cat("Nigeria MICS 2021 geospatial preprocessing artifact is present and mergeable.\n")

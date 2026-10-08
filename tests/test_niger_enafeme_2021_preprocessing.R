script_file <- file.path(
  "Rcode", "_script_for_specific_tasks",
  "Niger_ENAFEME_2021_DataProcessing.R"
)
if (!file.exists(script_file)) {
  stop("Missing Niger ENAFEME preprocessing script: ", script_file)
}
source(script_file)

info <- jsonlite::fromJSON(
  file.path("Info", "Niger_general_info.json"),
  simplifyVector = TRUE
)
stopifnot(
  identical(info$country, "Niger"),
  isTRUE(all.equal(info$frame_year, 2012)),
  isTRUE(all.equal(info$surveys_1frame, 2021)),
  identical(info$strata_weight_source, "survey"),
  identical(info$final_model$strata.model, "unstrat")
)

source_file <- file.path(
  "Data", "MICS", "Niger", "2021", "NIBR70BFL.sav"
)
boundary_dir <- file.path(
  "Data", "shapeFiles", "georepo_NER_shp"
)
stopifnot(file.exists(source_file), dir.exists(boundary_dir))

output_file <- tempfile(fileext = ".tmp.rda")
on.exit(unlink(output_file), add = TRUE)
prepare_niger_enafeme_2021(
  source_file = source_file,
  boundary_dir = boundary_dir,
  output_file = output_file
)
stopifnot(file.exists(output_file))

output_env <- new.env(parent = emptyenv())
load(output_file, envir = output_env)
stopifnot(exists("dat.tmp", envir = output_env, inherits = FALSE))
dat.tmp <- get("dat.tmp", envir = output_env, inherits = FALSE)

required_columns <- c(
  "cluster", "age", "years", "total", "Y", "v005", "urban",
  "admin1.name", "LONGNUM", "LATNUM", "survey"
)
missing_columns <- setdiff(required_columns, names(dat.tmp))
if (length(missing_columns) > 0) {
  stop("Niger ENAFEME tmp data is missing: ",
       paste(missing_columns, collapse = ", "))
}

expected_admin1 <- sort(c(
  "Agadez", "Diffa", "Dosso", "Maradi", "Niamey", "Tahoua",
  "Tillaberi", "Zinder"
))
stopifnot(
  identical(sort(unique(as.character(dat.tmp$admin1.name))),
            expected_admin1),
  identical(sort(unique(as.character(dat.tmp$urban))),
            c("rural", "urban")),
  identical(sort(unique(dat.tmp$survey)), 2021),
  all(is.na(dat.tmp$LONGNUM)),
  all(is.na(dat.tmp$LATNUM)),
  all(is.finite(dat.tmp$v005) & dat.tmp$v005 > 0),
  !any(c("admin2", "admin2.name", "admin2.char") %in% names(dat.tmp))
)

qa <- attr(dat.tmp, "enafeme_qa")
stopifnot(
  is.list(qa),
  identical(qa$source_birth_rows, 32370L),
  identical(qa$usable_birth_rows, 32369L),
  identical(qa$excluded_future_births, 1L),
  identical(qa$clusters, 280L),
  identical(qa$urban_clusters, 81L),
  identical(qa$rural_clusters, 199L),
  identical(qa$sampling_frame_year, 2012L)
)

cat("Niger ENAFEME 2021 non-geospatial Admin-1 preprocessing is valid.\n")

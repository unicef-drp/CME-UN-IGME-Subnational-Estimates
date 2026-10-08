source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

stopifnot(exists("load.country.info", mode = "function"))
legacy_loader <- paste0("load.country.", "Rdata")
stopifnot(!exists(legacy_loader, mode = "function"))

info_env <- new.env(parent = emptyenv())
loaded_file <- load.country.info("Laos", envir = info_env)
stopifnot(file.exists(loaded_file))
stopifnot(endsWith(loaded_file, "Laos_general_info.json"))
stopifnot(identical(info_env$country, "Laos"))
stopifnot(identical(info_env$iso0, "LAO"))
stopifnot(isTRUE(all.equal(info_env$frame_year, 2021)))
stopifnot(identical(info_env$final_model$time.model, "ar1"))

null_env <- new.env(parent = emptyenv())
load.country.info("Ethiopia", envir = null_env)
stopifnot(exists("surveys_1frame", envir = null_env, inherits = FALSE))
stopifnot(is.null(null_env$surveys_1frame))

missing_error <- tryCatch(
  load.country.info(
    "Missing_Test_Country",
    envir = new.env(parent = emptyenv())
  ),
  error = conditionMessage
)
stopifnot(grepl("Missing_Test_Country_general_info[.]json", missing_error))

fixture_dir <- tempfile("country-info-")
dir.create(fixture_dir)
writeLines(
  '{"country":"Other","iso0":"OTH"}',
  file.path(fixture_dir, "Expected_general_info.json")
)
mismatch_error <- tryCatch(
  load.country.info("Expected", info_dir = fixture_dir),
  error = conditionMessage
)
stopifnot(grepl(
  "does not match requested country Expected",
  mismatch_error,
  fixed = TRUE
))

writeLines("{not-json", file.path(fixture_dir, "Broken_general_info.json"))
parse_error <- tryCatch(
  load.country.info("Broken", info_dir = fixture_dir),
  error = conditionMessage
)
stopifnot(grepl("Could not parse country Info JSON", parse_error, fixed = TRUE))

writeLines(
  '[{"country":"Array"}]',
  file.path(fixture_dir, "Array_general_info.json")
)
object_error <- tryCatch(
  load.country.info("Array", info_dir = fixture_dir),
  error = conditionMessage
)
stopifnot(grepl("named top-level object", object_error, fixed = TRUE))

cat("Country Info JSON loader validates and assigns country configuration.\n")

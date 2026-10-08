info <- jsonlite::fromJSON(
  file.path("Info", "Afghanistan_general_info.json"),
  simplifyVector = TRUE
)
mics_text <- paste(readLines(file.path("Rcode", "_script_for_specific_tasks",
                                       "MICS_DataProcessing.R"),
                            warn = FALSE),
                   collapse = "\n")

stopifnot(
  identical(info$country, "Afghanistan"),
  identical(info$iso0, "AFG"),
  is.null(info$frame_year),
  isTRUE(all.equal(info$surveys_1frame, 2023)),
  identical(info$strata_weight_source, "survey"),
  identical(info$final_model$strata.model, "unstrat")
)

if ("poly.layer.adm2" %in% names(info) ||
    "poly.label.adm2" %in% names(info)) {
  stop("Afghanistan Admin-1 run should not define Admin-2 GeoRepo layers.")
}

required_mics <- c(
  "# Afghanistan 2022-2023",
  "prepare_afghanistan_mics <- function(",
  "Data/MICS/Afghanistan/2022_2023/bh.sav",
  "output_file = \"Data/MICS/Afghanistan/afg.2023.tmp.rda\"",
  "survey_year = 2023",
  "cmc.adjust = -945",
  "normalize_afghanistan_admin1",
  "save(dat.tmp, file = output_file)"
)

missing_mics <- required_mics[!vapply(required_mics, grepl, logical(1),
                                      x = mics_text, fixed = TRUE)]
if (length(missing_mics) > 0) {
  stop("Afghanistan MICS preprocessing block is missing expected logic: ",
       paste(missing_mics, collapse = ", "))
}

mics_expressions <- parse(file.path(
  "Rcode", "_script_for_specific_tasks", "MICS_DataProcessing.R"
))
normalizer_assignment <- Filter(function(expr) {
  is.call(expr) &&
    identical(expr[[1]], as.name("<-")) &&
    identical(expr[[2]], as.name("normalize_afghanistan_admin1"))
}, mics_expressions)
if (length(normalizer_assignment) != 1L) {
  stop("Expected exactly one Afghanistan Admin-1 normalizer definition.")
}

normalizer_env <- new.env(parent = globalenv())
eval(normalizer_assignment[[1]], envir = normalizer_env)
observed_labels <- c("MAIDAN WARDAK", "KUNARHA", "NOORISTAN", "SAR-E-PUL")
expected_georepo_labels <- c(
  "Maidan Wardak", "Kunar", "Nuristan", "Sar-E-Pul"
)
actual_georepo_labels <- normalizer_env$normalize_afghanistan_admin1(
  observed_labels
)
if (!identical(actual_georepo_labels, expected_georepo_labels)) {
  stop(
    "Afghanistan MICS province normalization does not match GeoRepo. Got: ",
    paste(actual_georepo_labels, collapse = ", ")
  )
}

cat("Afghanistan Admin-1 MICS6 preprocessing configuration is restored.\n")

script_text <- paste(readLines("Rcode/8_10_BB8.R", warn = FALSE), collapse = "\n")

required_fragments <- c(
  "survey_strata_weights.R",
  "ur_weight_files <- c(",
  "derive_survey_strata_weights(",
  "save_survey_strata_weights(survey_strata_weights, res.dir)",
  "identical(strata_weight_source, \"survey\")"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = script_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("8_10_BB8.R should derive survey strata weights when UR files are absent. Missing: ",
       paste(missing, collapse = ", "))
}

cat("BB8 stratified script has a generic survey-derived strata fallback.\n")

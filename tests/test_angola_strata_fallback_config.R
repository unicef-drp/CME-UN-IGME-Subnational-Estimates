info <- jsonlite::fromJSON(
  file.path("Info", "Angola_general_info.json"),
  simplifyVector = TRUE
)
bb8_text <- paste(readLines(file.path("Rcode", "8_10_BB8.R"),
                            warn = FALSE),
                  collapse = "\n")

stopifnot(
  identical(info$strata_weight_source, "survey"),
  identical(info$strata_weight_missing_region_fallback, "national")
)

required_bb8 <- c(
  "missing_region_fallback = if (exists(\"strata_weight_missing_region_fallback\"",
  "strata_weight_missing_region_fallback"
)

missing_bb8 <- required_bb8[!vapply(required_bb8, grepl, logical(1),
                                    x = bb8_text, fixed = TRUE)]
if (length(missing_bb8) > 0) {
  stop("BB8 should pass country-level missing-region strata fallback settings: ",
       paste(missing_bb8, collapse = ", "))
}

cat("Angola survey-derived strata fallback is configured.\n")

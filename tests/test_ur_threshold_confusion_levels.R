script <- paste(
  readLines(file.path("Rcode", "7b_UR_thresholding_sf.R"), warn = FALSE),
  collapse = "\n"
)

required <- c(
  'urban_levels <- c("urban", "rural")',
  "pred_crc <- factor(",
  "reference_crc <- factor(crc_dat$urban, levels = urban_levels)",
  "reference_uncrc <- factor(uncrc_dat$urban, levels = urban_levels)",
  "reference = reference_crc",
  "reference = reference_uncrc"
)
missing <- required[!vapply(required, grepl, logical(1), x = script, fixed = TRUE)]
if (length(missing) > 0L) {
  stop(
    "Urban/rural confusion matrices must use explicit common factor levels. ",
    "Missing: ", paste(missing, collapse = "; ")
  )
}

cat("Urban/rural confusion matrices use aligned factor levels.\n")

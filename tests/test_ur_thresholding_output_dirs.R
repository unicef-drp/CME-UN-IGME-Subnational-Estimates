script <- paste(readLines(file.path("Rcode", "7b_UR_thresholding_sf.R"),
                          warn = FALSE),
                collapse = "\n")

required_dir_literals <- c(
  'file.path("UR", "Threshold")',
  'file.path("UR", "U1_fraction")',
  'file.path("UR", "U5_fraction")'
)

missing <- required_dir_literals[!vapply(required_dir_literals, grepl,
                                         logical(1), x = script,
                                         fixed = TRUE)]
if (length(missing) > 0) {
  stop("7b_UR_thresholding_sf.R does not create required UR output dirs: ",
       paste(missing, collapse = ", "))
}

if (!grepl("recursive = TRUE", script, fixed = TRUE)) {
  stop("7b_UR_thresholding_sf.R should create output dirs recursively.")
}

cat("UR thresholding script creates required output directories.\n")

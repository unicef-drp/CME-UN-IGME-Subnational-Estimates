script_text <- paste(readLines(file.path("Rcode", "6_Comparison_Plot.R"),
                               warn = FALSE),
                     collapse = "\n")

required_fragments <- c(
  "admin2.sd.nmr.file <- file.path",
  "admin2.sd.u5.file <- file.path",
  "if (file.exists(admin2.sd.nmr.file) && file.exists(admin2.sd.u5.file))",
  "Skipping Admin-2 period smoothed-direct aggregate"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = script_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("6_Comparison_Plot.R should treat Admin-2 period smoothed-direct aggregates as optional. Missing: ",
       paste(missing, collapse = ", "))
}

cat("Comparison plot skips missing optional Admin-2 smoothed-direct aggregates.\n")

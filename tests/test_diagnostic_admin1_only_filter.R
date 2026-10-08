script <- paste(readLines(file.path("Rcode", "9_Diagnostic_Plots.R"),
                          warn = FALSE), collapse = "\n")

required <- c(
  "admin1_only_requested()",
  "!grepl(\"^adm2_\", model.candidates)"
)

missing <- required[!vapply(required, grepl, logical(1), x = script,
                            fixed = TRUE)]
if (length(missing) > 0) {
  stop("9_Diagnostic_Plots.R does not filter stale Admin2 result files in Admin1-only mode: ",
       paste(missing, collapse = ", "))
}

cat("Admin1-only diagnostics exclude stale Admin2 model files.\n")

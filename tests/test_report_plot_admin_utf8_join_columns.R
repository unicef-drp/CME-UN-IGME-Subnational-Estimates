script <- paste(
  readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE),
  collapse = "\n"
)

required <- c(
  "normalize_admin_name_table <- function",
  "admin1.names <- normalize_admin_name_table(admin1.names)",
  "admin2.names <- normalize_admin_name_table(admin2.names)"
)

missing <- required[!vapply(required, grepl, logical(1), x = script, fixed = TRUE)]
if (length(missing)) {
  stop(
    "Report plots must normalize admin name-table join columns to UTF-8. Missing: ",
    paste(missing, collapse = ", ")
  )
}

cat("Report plot admin join columns are normalized to UTF-8.\n")

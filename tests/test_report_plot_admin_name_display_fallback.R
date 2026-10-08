script <- paste(readLines(file.path("Rcode", "11_Report_Plot.R"),
                          warn = FALSE), collapse = "\n")

required_fragments <- c(
  "admin_display_names <- function",
  "admin1.names$Display <- admin_display_names(admin1.names)",
  "admin1.names$Display[i]",
  "admin1.names$Display[area.idx]"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = script, fixed = TRUE)]
if (length(missing) > 0) {
  stop("11_Report_Plot.R should use a fallback admin display-name column. Missing: ",
       paste(missing, collapse = ", "))
}

forbidden_fragments <- c(
  "admin1.names$GeoRepo[i]",
  "admin1.names$GeoRepo[area.idx]",
  "admin2.names$GeoRepo[i]",
  "admin2.names$GeoRepo[area.idx]"
)

present <- forbidden_fragments[vapply(forbidden_fragments, grepl, logical(1),
                                      x = script, fixed = TRUE)]
if (length(present) > 0) {
  stop("11_Report_Plot.R should not hard-code GeoRepo for display labels: ",
       paste(present, collapse = ", "))
}

cat("Report plot admin display labels use a GeoRepo/GADM fallback.\n")

main_script <- paste(readLines(file.path("Rcode", "8_10_BB8.R"), warn = FALSE),
                     collapse = "\n")
unstrat_script <- paste(readLines(file.path("Rcode", "8_10_BB8_unstrat_only.R"),
                                  warn = FALSE),
                        collapse = "\n")
comparison_script <- paste(readLines(file.path("Rcode", "9_Comparison_Plot.R"),
                                     warn = FALSE),
                           collapse = "\n")
report_script <- paste(readLines(file.path("Rcode", "11_Report_Plot.R"),
                                 warn = FALSE),
                       collapse = "\n")
direct_script <- paste(readLines(file.path("Rcode", "4_Direct_SmoothDirect_sf.R"),
                                 warn = FALSE),
                       collapse = "\n")

required_main <- c(
  'Sys.getenv("BB8_ADMIN1_ONLY", "0")',
  'run_admin2_bb8 <- exists("poly.layer.adm2", inherits = TRUE)',
  "if(run_admin2_bb8){",
  "admin2.names = if (run_admin2_bb8) admin2.names else NULL"
)

missing_main <- required_main[!vapply(required_main, grepl, logical(1),
                                      x = main_script, fixed = TRUE)]
if (length(missing_main) > 0) {
  stop("8_10_BB8.R is missing Admin-1-only BB8 switch pieces: ",
       paste(missing_main, collapse = ", "))
}

required_unstrat <- c(
  'Sys.getenv("BB8_ADMIN1_ONLY", "0")',
  'run_admin2_bb8 <- exists("poly.layer.adm2", inherits = TRUE)',
  "if (run_admin2_bb8) {"
)

missing_unstrat <- required_unstrat[!vapply(required_unstrat, grepl,
                                            logical(1),
                                            x = unstrat_script, fixed = TRUE)]
if (length(missing_unstrat) > 0) {
  stop("8_10_BB8_unstrat_only.R is missing Admin-1-only BB8 switch pieces: ",
       paste(missing_unstrat, collapse = ", "))
}

required_comparison <- c(
  'Sys.getenv("BB8_ADMIN1_ONLY", "0")',
  'run_admin2_outputs <- exists("poly.layer.adm2", inherits = TRUE)',
  "if(run_admin2_outputs){",
  "has_adm2 = run_admin2_outputs",
  "has_admin2 = run_admin2_outputs"
)

missing_comparison <- required_comparison[!vapply(required_comparison, grepl,
                                                  logical(1),
                                                  x = comparison_script,
                                                  fixed = TRUE)]
if (length(missing_comparison) > 0) {
  stop("9_Comparison_Plot.R is missing Admin-1-only output switch pieces: ",
       paste(missing_comparison, collapse = ", "))
}

required_report <- c(
  'Sys.getenv("BB8_ADMIN1_ONLY", "0")',
  'run_admin2_report <- exists("poly.layer.adm2", inherits = TRUE)',
  "if(run_admin2_report){",
  "normalize_utf8_text <- function(labels)",
  "poly.adm1[[poly.label.adm1]] <- normalize_utf8_text(poly.adm1[[poly.label.adm1]])"
)

missing_report <- required_report[!vapply(required_report, grepl,
                                          logical(1),
                                          x = report_script,
                                          fixed = TRUE)]
if (length(missing_report) > 0) {
  stop("11_Report_Plot.R is missing Admin-1-only report switch pieces: ",
       paste(missing_report, collapse = ", "))
}

required_direct <- c(
  "normalize_utf8_text <- function(labels)",
  "admin1.names$GeoRepo <- normalize_utf8_text(admin1.names$GeoRepo)"
)

missing_direct <- required_direct[!vapply(required_direct, grepl,
                                          logical(1),
                                          x = direct_script,
                                          fixed = TRUE)]
if (length(missing_direct) > 0) {
  stop("4_Direct_SmoothDirect_sf.R is missing UTF-8 label normalization: ",
       paste(missing_direct, collapse = ", "))
}

cat("BB8, comparison, report, and direct scripts support the recovery guards.\n")

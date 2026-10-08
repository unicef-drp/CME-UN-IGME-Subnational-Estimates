script <- readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE)

stopifnot(any(grepl("igme.ests.u5.raw$ISO.Code==iso0", script, fixed = TRUE)))
stopifnot(any(grepl("igme.ests.nmr.raw$ISO.Code==iso0", script, fixed = TRUE)))

if (any(grepl("igme.ests.nmr.raw$iso==iso0", script, fixed = TRUE))) {
  stop("Report plot NMR IGME filter must use current ISO.Code column, not old iso column.")
}

cat("Report plot IGME U5MR and NMR filters use the current ISO.Code column.\n")

script <- readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE)

if (any(grepl("seq(end.year+1,2024,3)", script, fixed = TRUE))) {
  stop("Report plot projection panel years must use end.proj.year, not hardcoded 2024.")
}

stopifnot(any(grepl("seq(end.year+1,end.proj.year,3)", script, fixed = TRUE)))

cat("Report plot projection years use configured end.proj.year.\n")

script <- paste(readLines(file.path("Rcode", "11_Report_Plot.R"),
                          warn = FALSE),
                collapse = "\n")

required_guard <- 'if(file.exists(file.path("Direct", "NMR", nmr.filename))){
    load(file = file.path("Direct", "NMR", nmr.filename))
    admin1.sd.yearly.nmr <- sd.admin1.yearly.nmr
  }'

if (!grepl(required_guard, script, fixed = TRUE)) {
  stop("Admin-1 yearly smoothed-direct NMR output should be optional when the file is absent.")
}

cat("Report plot skips missing optional Admin-1 yearly smoothed-direct NMR output.\n")

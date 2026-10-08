script <- readLines("Rcode/6_Comparison_Plot.R", warn = FALSE)

stopifnot(any(grepl("home.dir <- project_home()", script, fixed = TRUE)))
stopifnot(any(grepl("require_country_context()", script, fixed = TRUE)))
stopifnot(any(grepl("igme.ests.nmr.raw$ISO.Code==iso0", script, fixed = TRUE)))
stopifnot(any(grepl("mod.dat.1frame", script, fixed = TRUE)))
stopifnot(any(grepl("mod.dat.save", script, fixed = TRUE)))
stopifnot(any(grepl("admin1.sd.yearly.nmr.file", script, fixed = TRUE)))
stopifnot(any(grepl("file.exists(admin1.sd.yearly.nmr.file) || file.exists(admin1.sd.yearly.u5.file)", script, fixed = TRUE)))

if (any(grepl("igme.ests.nmr.raw$iso==iso0", script, fixed = TRUE))) {
  stop("Comparison plot NMR IGME filter must use current ISO.Code column, not old iso column.")
}

cat("Comparison plot uses prepared country context, current IGME schema, and one-frame cluster data object names.\n")

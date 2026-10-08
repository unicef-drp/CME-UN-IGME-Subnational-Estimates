script <- paste(readLines(file.path("Rcode", "4_Direct_SmoothDirect_sf.R")),
                collapse = "\n")

stopifnot(grepl("Admin2 period smoothed direct U5MR", script, fixed = TRUE))
stopifnot(grepl("Admin2 period smoothed direct NMR", script, fixed = TRUE))
stopifnot(grepl("exists('res.admin2.u5')", script, fixed = TRUE))
stopifnot(grepl("exists('res.admin2.nmr')", script, fixed = TRUE))

cat("Admin2 smoothed direct failures are optional and downstream plots are guarded.\n")

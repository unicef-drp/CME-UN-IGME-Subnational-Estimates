script <- readLines("Rcode/4_Direct_SmoothDirect_sf.R", warn = FALSE)

stopifnot(any(grepl("igme.ests.u5.raw$ISO.Code==iso0", script, fixed = TRUE)))
stopifnot(any(grepl("igme.ests.nmr.raw$ISO.Code==iso0", script, fixed = TRUE)))
stopifnot(!any(grepl("igme.ests.nmr.raw$iso==iso0", script, fixed = TRUE)))

cat("IGME U5MR and NMR filters use the current ISO.Code column.\n")

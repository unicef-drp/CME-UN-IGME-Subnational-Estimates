script <- readLines("Rcode/4_Direct_SmoothDirect_sf.R", warn = FALSE)

stopifnot(any(grepl("period_mid_years <-", script, fixed = TRUE)))

bad_period_assignments <- grep(
  "years\\.num\\s*<-\\s*periods(\\[match)?",
  script,
  value = TRUE,
  perl = TRUE
)
if (length(bad_period_assignments) > 0) {
  stop("Smoothed period results must use numeric midpoint years, not text period labels:\n",
       paste(bad_period_assignments, collapse = "\n"))
}

stopifnot(any(grepl("period_mid_years[match(res.admin1.u5$years, periods)]",
                    script, fixed = TRUE)))
stopifnot(any(grepl("draw_admin1_spaghetti_legend", script, fixed = TRUE)))

admin1_start <- tail(grep("## Admin 1, 3-year period", script, fixed = TRUE), 1)
admin1_end <- tail(grep("## Admin 2, 3-year period", script, fixed = TRUE), 1)
admin1_block <- script[admin1_start:admin1_end]
if (any(grepl("legend\\('topright'", admin1_block))) {
  stop("Admin1 spaghetti legend should not be drawn inside the plotting region.")
}

cat("Smoothed-direct period spaghetti plots use numeric x-values and an external legend.\n")

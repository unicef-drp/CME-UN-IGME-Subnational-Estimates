script <- readLines("Rcode/4_Direct_SmoothDirect_sf.R", warn = FALSE)

stopifnot(any(grepl("expand_smoothed_periods_to_years <-", script, fixed = TRUE)))
stopifnot(any(grepl("SUMMER does not support true yearly AR1 smoothDirect fits", script, fixed = TRUE)))
stopifnot(any(grepl("if (start_years[i] > period_end)", script, fixed = TRUE)))

admin1_start <- grep("## Admin 1 Yearly Smoothed Direct", script, fixed = TRUE)
admin1_end <- grep("## Admin 2 Smoothed Direct", script, fixed = TRUE)
admin1_block <- paste(script[admin1_start:admin1_end], collapse = "\n")

if (!grepl("admin1\\.yearly\\.u5\\.map <- expand_smoothed_periods_to_years\\(\\s*res\\.admin1\\.u5",
           admin1_block, perl = TRUE)) {
  stop("Admin1 yearly U5MR map should use period smoothed-direct estimates expanded over survey years.")
}
if (grepl("data\\s*=\\s*sd\\.admin1\\.yearly\\.u5", admin1_block, perl = TRUE)) {
  stop("Admin1 yearly U5MR map should not use the sparse single-year diagnostic fit.")
}

admin2_start <- grep("## Admin 2 Yearly Smoothed Direct", script, fixed = TRUE)
admin2_end <- grep("## National", script, fixed = TRUE)
admin2_end <- admin2_end[admin2_end > admin2_start][1]
admin2_block <- paste(script[admin2_start:admin2_end], collapse = "\n")

if (!grepl("admin2\\.yearly\\.u5\\.map <- expand_smoothed_periods_to_years\\(\\s*res\\.admin2\\.u5",
           admin2_block, perl = TRUE)) {
  stop("Admin2 yearly U5MR map should use period smoothed-direct estimates expanded over survey years.")
}
if (grepl("data\\s*=\\s*sd\\.admin2\\.yearly\\.u5", admin2_block, perl = TRUE)) {
  stop("Admin2 yearly U5MR map should not use the sparse single-year diagnostic fit.")
}

cat("Yearly U5MR polygon maps use stable period smoothed-direct estimates expanded by year.\n")

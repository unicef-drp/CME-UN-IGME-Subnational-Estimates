source("Rcode/_supporting_scripts/mics_tmp_files.R")

gps_dat <- data.frame(
  cluster = c(1L, 2L),
  LONGNUM = c(-1.2, 0.4),
  LATNUM = c(5.6, 10.1)
)
gps_result <- ensure_mics_coordinate_columns(gps_dat)
stopifnot(identical(gps_result$LONGNUM, gps_dat$LONGNUM))
stopifnot(identical(gps_result$LATNUM, gps_dat$LATNUM))

non_gps_dat <- data.frame(cluster = c(1L, 2L))
non_gps_result <- ensure_mics_coordinate_columns(non_gps_dat)
stopifnot(all(is.na(non_gps_result$LONGNUM)))
stopifnot(all(is.na(non_gps_result$LATNUM)))

script_text <- paste(
  readLines("Rcode/3_DataProcessing_sf.R", warn = FALSE),
  collapse = "\n"
)
stopifnot(grepl(
  "dat.tmp <- ensure_mics_coordinate_columns(dat.tmp)",
  script_text,
  fixed = TRUE
))

cat("MICS GPS coordinate preservation tests passed.\n")

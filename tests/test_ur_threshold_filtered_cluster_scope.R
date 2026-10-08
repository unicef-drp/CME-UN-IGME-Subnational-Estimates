script <- paste(
  readLines(file.path("Rcode", "7b_UR_thresholding_sf.R"), warn = FALSE),
  collapse = "\n"
)

if (grepl("envir = .GlobalEnv", script, fixed = TRUE)) {
  stop(
    "Urban/rural thresholding must not load or save cluster data through ",
    ".GlobalEnv; doing so bypasses the surveys_1frame filter."
  )
}
if (!grepl("load(paste0(country,'_cluster_dat.rda'))", script, fixed = TRUE)) {
  stop("Thresholding should load cluster data into its current pipeline environment.")
}
if (!grepl(
  "save(mod.dat, file=paste0(country,'_cluster_dat_1frame'",
  script,
  fixed = TRUE
)) {
  stop("Thresholding should save the locally filtered same-frame cluster data.")
}

cat("Same-frame cluster data are filtered and saved in one environment.\n")

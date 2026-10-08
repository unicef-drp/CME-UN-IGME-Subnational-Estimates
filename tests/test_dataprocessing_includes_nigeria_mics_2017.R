script <- paste(readLines(file.path("Rcode", "3_DataProcessing_sf.R"),
                          warn = FALSE),
                collapse = "\n")

mics_2017_tmp <- file.path("Data", "MICS", "Nigeria", "nga.2017.tmp.rda")
if (!file.exists(mics_2017_tmp)) {
  stop("Prepared Nigeria MICS 2017 file is missing: ", mics_2017_tmp)
}

exclusion_match <- gregexpr("surveys_excluded\\s*<-\\s*[^\\n#]*2017",
                            script,
                            perl = TRUE)[[1]]
if (exclusion_match[1] != -1) {
  stop("3_DataProcessing_sf.R still explicitly excludes Nigeria MICS 2017.")
}

cat("Nigeria MICS 2017 is not explicitly excluded by data processing.\n")

cluster_dat_file <- file.path("Data", "Countries", "Nigeria", "Nigeria_cluster_dat.rda")
if (file.exists(cluster_dat_file)) {
  env <- new.env(parent = emptyenv())
  load(cluster_dat_file, envir = env)
  if (!exists("mod.dat", envir = env, inherits = FALSE)) {
    stop("Expected mod.dat in ", cluster_dat_file)
  }
  mod.dat <- get("mod.dat", envir = env)
  surveys <- sort(unique(mod.dat[["survey"]]))
  expected_all_surveys <- c(2003, 2008, 2010, 2013, 2017, 2018, 2021, 2024)
  if (!identical(surveys, expected_all_surveys)) {
    stop("Nigeria all-survey cluster data should include: ",
         paste(expected_all_surveys, collapse = ", "), "; found: ",
         paste(surveys, collapse = ", "))
  }
}

cluster_dat_1frame_file <- file.path("Data", "Countries", "Nigeria",
                                     "Nigeria_cluster_dat_1frame.rda")
if (file.exists(cluster_dat_1frame_file)) {
  env <- new.env(parent = emptyenv())
  load(cluster_dat_1frame_file, envir = env)
  if (!exists("mod.dat", envir = env, inherits = FALSE)) {
    stop("Expected mod.dat in ", cluster_dat_1frame_file,
         " for downstream BB8 scripts.")
  }
  mod.dat <- get("mod.dat", envir = env)
  surveys <- sort(unique(mod.dat[["survey"]]))
  expected_frame_surveys <- c(2010, 2013, 2017, 2018, 2021)
  if (!identical(surveys, expected_frame_surveys)) {
    stop("Nigeria one-frame cluster data should include: ",
         paste(expected_frame_surveys, collapse = ", "), "; found: ",
         paste(surveys, collapse = ", "))
  }
}

script_7a <- paste(readLines(file.path("Rcode", "7a_UR_prop.R"),
                             warn = FALSE),
                   collapse = "\n")
script_7b <- paste(readLines(file.path("Rcode", "7b_UR_thresholding_sf.R"),
                             warn = FALSE),
                   collapse = "\n")

info_env <- new.env(parent = emptyenv())
source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))
load.country.info("Laos", envir = info_env)
required_frames <- info_env$frame_year

if (!isTRUE(all.equal(required_frames, c(2021)))) {
  stop("Laos frame_year should be saved in Laos_general_info.json as 2021.")
}

if (!isTRUE(all.equal(info_env$surveys_1frame, c(2023)))) {
  stop("Laos surveys_1frame should be saved as 2023.")
}

if (grepl("frame_year\\s*<-\\s*c\\(", script_7a, perl = TRUE)) {
  stop("7a_UR_prop.R should use frame_year from the country Info JSON.")
}

if (!grepl("frame_year = frame_year[1]", script_7b, fixed = TRUE)) {
  stop("7b_UR_thresholding_sf.R should use frame_year from the country Info JSON.")
}

if (!grepl("surveys_1frame", script_7b, fixed = TRUE)) {
  stop("7b_UR_thresholding_sf.R should use surveys_1frame from the country Info JSON.")
}

frame_file <- file.path("Data", "urban_frames", "lao_2021_frame_urb_prop.csv")
if (!file.exists(frame_file)) {
  stop("Missing Lao 2021 urban fraction frame file: ", frame_file)
}
frame <- read.csv(frame_file)
if (!identical(names(frame), c("Admin1", "frac"))) {
  stop("Lao 2023 urban frame should have columns Admin1, frac.")
}
if (nrow(frame) != 18 || any(!is.finite(frame$frac)) ||
    any(frame$frac < 0 | frame$frac > 1)) {
  stop("Lao 2023 urban frame has invalid admin rows or fractions.")
}

cat("UR frame years are aligned between 7a and 7b.\n")

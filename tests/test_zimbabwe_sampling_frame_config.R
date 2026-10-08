info <- jsonlite::fromJSON(
  file.path("Info", "Zimbabwe_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  isTRUE(all.equal(info$frame_year, 2012)),
  isTRUE(all.equal(info$surveys_1frame, c(2015, 2019))),
  isTRUE(all.equal(info$survey_excluded, 2005))
)

env <- new.env(parent = baseenv())
sys.source(
  file.path("Rcode", "_supporting_scripts", "urban_frame_matching.R"),
  envir = env
)

frame <- utils::read.csv(
  file.path("Data", "urban_frames", "zwe_2012_frame_urb_prop.csv")
)
admin1 <- c(
  "Bulawayo", "Harare", "Manicaland", "Mashonaland Central",
  "Mashonaland East", "Mashonaland West", "Masvingo",
  "Matabeleland North", "Matabeleland South", "Midlands"
)

expanded <- env$expand_urban_frame_to_current_admin(frame, admin1)

stopifnot(
  nrow(expanded) == length(admin1),
  all(is.finite(expanded$urban_prop))
)

cat("Zimbabwe's 2012 frame matches the GeoRepo admin-1 labels.\n")

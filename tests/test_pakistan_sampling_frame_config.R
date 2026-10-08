info <- jsonlite::fromJSON(
  file.path("Info", "Pakistan_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  isTRUE(all.equal(info$frame_year, 2017)),
  isTRUE(all.equal(info$surveys_1frame, 2017)),
  file.exists(file.path(
    "Data",
    "urban_frames",
    "pak_2017_frame_urb_prop.csv"
  ))
)

cat("Pakistan uses the 2017 census frame for the 2017-18 DHS.\n")

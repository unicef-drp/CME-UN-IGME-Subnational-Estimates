info <- jsonlite::fromJSON(
  file.path("Info", "Zambia_general_info.json"),
  simplifyVector = TRUE
)

stopifnot(
  isTRUE(all.equal(info$frame_year, 2010)),
  isTRUE(all.equal(info$surveys_1frame, c(2013, 2018)))
)

env <- new.env(parent = baseenv())
sys.source(
  file.path("Rcode", "_supporting_scripts", "urban_frame_matching.R"),
  envir = env
)

frame <- utils::read.csv(
  file.path("Data", "urban_frames", "zmb_2010_frame_urb_prop.csv")
)
admin1 <- c(
  "Central", "Copperbelt", "Eastern", "Luapula", "Lusaka",
  "Muchiga", "North-Western", "Northern", "Southern", "Western"
)

expanded <- env$expand_urban_frame_to_current_admin(
  frame,
  admin1,
  info$urban_frame_admin1_parent_map
)

stopifnot(
  nrow(expanded) == length(admin1),
  identical(expanded$urban_prop, frame$urban_prop)
)

cat("Zambia's 2010 frame matches the GeoRepo admin-1 labels.\n")

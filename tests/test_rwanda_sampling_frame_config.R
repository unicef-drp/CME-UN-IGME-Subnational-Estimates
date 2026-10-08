info_path <- file.path("Info", "Rwanda_general_info.json")
frame_path <- file.path(
  "Data", "urban_frames", "rwa_2012_frame_urb_prop.csv"
)

stopifnot(file.exists(info_path), file.exists(frame_path))

info <- jsonlite::fromJSON(info_path, simplifyVector = TRUE)
frame <- utils::read.csv(frame_path, stringsAsFactors = FALSE)

stopifnot(
  identical(info$country, "Rwanda"),
  identical(info$iso0, "RWA"),
  isTRUE(all.equal(info$frame_year, 2012)),
  isTRUE(all.equal(info$surveys_1frame, c(2015, 2019))),
  nrow(frame) == 5L,
  all(c("region", "urban_prop") %in% names(frame)),
  all(is.finite(frame$urban_prop)),
  all(frame$urban_prop >= 0 & frame$urban_prop <= 1)
)
stopifnot(setequal(
  frame$region,
  c(
    "Kigali City",
    "Eastern Province",
    "Northern Province",
    "Western Province",
    "Southern Province"
  )
))

exclusions <- info$georepo_boundary_exclusions
stopifnot(
  is.data.frame(exclusions),
  nrow(exclusions) == 1L,
  identical(as.integer(exclusions$level), 2L),
  identical(
    as.character(exclusions$name),
    "Under National Administration"
  )
)

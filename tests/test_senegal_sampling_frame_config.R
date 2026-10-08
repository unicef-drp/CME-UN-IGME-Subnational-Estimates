info <- jsonlite::fromJSON(
  file.path("Info", "Senegal_general_info.json"),
  simplifyVector = TRUE
)

expected_surveys <- as.integer(c(2015, 2016, 2017, 2018, 2019, 2023))
stopifnot(
  identical(as.integer(info$frame_year), 2013L),
  identical(as.integer(info$surveys_1frame), expected_surveys)
)

frame_file <- file.path(
  "Data", "urban_frames", "sen_2013_frame_urb_prop.csv"
)
stopifnot(file.exists(frame_file))

frame <- utils::read.csv(frame_file, stringsAsFactors = FALSE)
stopifnot(
  identical(names(frame), c("Admin1", "frac")),
  nrow(frame) == 14L,
  all(is.finite(frame$frac)),
  all(frame$frac >= 0 & frame$frac <= 1),
  setequal(
    frame$Admin1,
    c(
      "Kaolack", "Kedougou", "Kolda", "Matam", "Tambacounda", "Thies",
      "Ziguinchor", "Saint Louis", "Dakar", "Fatick", "Diourbel",
      "Kaffrine", "Louga", "Sedhiou"
    )
  )
)

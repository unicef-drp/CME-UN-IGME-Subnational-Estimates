library(sf)

shape_dir <- file.path("Data", "shapeFiles", "georepo_UGA_shp")
admin1 <- st_read(shape_dir, layer = "georepo_UGA_1", quiet = TRUE)
admin2 <- st_read(shape_dir, layer = "georepo_UGA_2", quiet = TRUE)

stopifnot(
  nrow(admin1) == 4L,
  nrow(admin2) == 135L,
  "NAME_1" %in% names(admin1),
  "NAME_1" %in% names(admin2),
  "NAME_2" %in% names(admin2)
)

legacy_columns <- c("ADM1_EN", "ADM1_PCODE")
stopifnot(!any(legacy_columns %in% names(admin1)))

scripts <- c(
  file.path("Rcode", "3_DataProcessing_sf.R"),
  file.path("Rcode", "7b_UR_thresholding_sf.R")
)

for (script in scripts) {
  text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  stale_columns <- legacy_columns[
    vapply(legacy_columns, grepl, logical(1), x = text, fixed = TRUE)
  ]
  if (length(stale_columns) > 0L) {
    stop(
      basename(script),
      " still requires legacy Uganda boundary columns absent from GeoRepo: ",
      paste(stale_columns, collapse = ", ")
    )
  }
}

cat("Uganda processing uses the normalized GeoRepo boundary schema.\n")

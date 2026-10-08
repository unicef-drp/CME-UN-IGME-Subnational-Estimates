info_files <- list.files(
  "Info",
  pattern = "_general_info[.]json$",
  full.names = TRUE
)

path_hits <- unlist(lapply(info_files, function(info_file) {
  info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)
  expected <- if (identical(info$country, "Madagascar")) {
    "../shapeFiles/_alt"
  } else if (identical(info$country, "Philippines")) {
    "../shapeFiles/ocha_PHL_shp"
  } else {
    paste0("../shapeFiles/georepo_", info$iso0, "_shp")
  }
  if (identical(info$poly.path, expected)) {
    character(0)
  } else {
    paste0(info_file, ": ", info$poly.path)
  }
}), use.names = FALSE)

if (length(path_hits) > 0) {
  stop(
    "Info JSON files should use normalized boundary poly.path entries:\n",
    paste(path_hits, collapse = "\n")
  )
}

cat("Info JSON files use normalized boundary poly.path entries.\n")

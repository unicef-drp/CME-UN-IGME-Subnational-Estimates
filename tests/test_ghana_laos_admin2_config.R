configs <- list(
  Ghana = list(iso0 = "GHA", layer = "georepo_GHA_2"),
  Laos = list(iso0 = "LAO", layer = "georepo_LAO_2")
)

for (country in names(configs)) {
  info_file <- file.path("Info", paste0(country, "_general_info.json"))
  if (!file.exists(info_file)) {
    stop("Missing country Info JSON: ", info_file)
  }

  info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)
  expected <- configs[[country]]

  stopifnot(
    identical(info$country, country),
    identical(info$iso0, expected$iso0),
    identical(info$poly.layer.adm2, expected$layer),
    identical(info$poly.label.adm2, "NAME_2")
  )
}

cat("Ghana and Laos are configured for GeoRepo Admin-2.\n")

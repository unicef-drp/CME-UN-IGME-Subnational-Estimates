frame_path <- file.path(
  "Data", "urban_frames", "mdg_2018_frame_urb_prop.csv"
)
metadata_path <- file.path(
  "Data", "urban_frames", "mdg_2018_frame_urb_prop_metadata.json"
)

stopifnot(file.exists(frame_path), file.exists(metadata_path))

frame <- utils::read.csv(frame_path, stringsAsFactors = FALSE)
metadata <- jsonlite::fromJSON(metadata_path, simplifyVector = TRUE)

expected <- data.frame(
  Admin1 = c(
    "Antananarivo", "Fianarantsoa", "Toamasina",
    "Mahajanga", "Toliara", "Antsiranana"
  ),
  urban_population = c(
    1880008, 603676, 764602, 599660, 584128, 510828
  ),
  total_population = c(
    7273126, 5170076, 3878492, 3139125, 4199643, 2013734
  ),
  stringsAsFactors = FALSE
)
expected$frac <- expected$urban_population / expected$total_population

stopifnot(
  identical(
    names(frame),
    c("Admin1", "frac", "urban_population", "total_population")
  ),
  identical(frame$Admin1, expected$Admin1),
  isTRUE(all.equal(
    as.numeric(frame$urban_population), expected$urban_population
  )),
  isTRUE(all.equal(
    as.numeric(frame$total_population), expected$total_population
  )),
  isTRUE(all.equal(frame$frac, expected$frac, tolerance = 1e-12)),
  identical(metadata$source_institution, "INSTAT Madagascar"),
  identical(metadata$source_year, 2018L),
  identical(metadata$source_table, "Annexe 2, Tableau 2"),
  identical(metadata$pdf_page, 180L),
  identical(metadata$printed_page, "IV"),
  identical(metadata$formula, "urban_population / total_population")
)

cat("Madagascar 2018 urban-frame fractions match the official RGPH-3 counts.\n")

source(file.path(
  "Rcode", "_script_for_specific_tasks", "Madagascar_SALB_Boundaries.R"
))

spec <- madagascar_salb_spec()
stopifnot(identical(spec$item_id, "9013b63ff3694106baa2ea8cd701223c"))
stopifnot(identical(spec$valid_from, "2014-09-27"))
stopifnot(identical(spec$valid_to, "2021-06-23"))
stopifnot(identical(spec$feature_counts, c(adm0 = 1L, adm1 = 6L, adm2 = 22L)))

output_dir <- madagascar_salb_output_dir()
required_files <- file.path(
  output_dir,
  c(
    "salb_MDG_0.shp", "salb_MDG_1.shp", "salb_MDG_2.shp",
    "salb_MDG_metadata.json", "BNDA_MDG_2014-09-27_2021-06-23.shp"
  )
)
if (!all(file.exists(required_files))) {
  stop("Prepared Madagascar SALB files are missing: ",
       paste(required_files[!file.exists(required_files)], collapse = ", "))
}

adm0 <- sf::st_read(output_dir, "salb_MDG_0", quiet = TRUE)
adm1 <- sf::st_read(output_dir, "salb_MDG_1", quiet = TRUE)
adm2 <- sf::st_read(output_dir, "salb_MDG_2", quiet = TRUE)

stopifnot(nrow(adm0) == 1L, nrow(adm1) == 6L, nrow(adm2) == 22L)
stopifnot(all(c("ISO3", "COUNTRY") %in% names(adm0)))
stopifnot(all(c("ISO3", "COUNTRY", "SALB_ADM1", "NAME_1") %in% names(adm1)))
stopifnot(all(c(
  "ISO3", "COUNTRY", "SALB_ADM1", "NAME_1", "SALB_ADM2", "NAME_2"
) %in% names(adm2)))
stopifnot(identical(unique(as.character(adm0$ISO3)), "MDG"))
stopifnot(identical(sort(unique(as.character(adm1$NAME_1))), sort(c(
  "Antananarivo", "Antsiranana", "Fianarantsoa", "Mahajanga",
  "Toamasina", "Toliara"
))))
stopifnot(identical(sort(unique(as.character(adm2$NAME_2))), sort(c(
  "Alaotra Mangoro", "Amoron'i Mania", "Analamanga", "Analanjirofo",
  "Androy", "Anosy", "Atsimo Andrefana", "Atsimo Atsinanana",
  "Atsinanana", "Betsiboka", "Boeny", "Bongolava", "Diana",
  "Haute Matsiatra", "Ihorombe", "Itasy", "Melaky", "Menabe",
  "Sava", "Sofia", "Vakinankaratra", "Vatovavy Fitovinany"
))))
stopifnot(all(adm2$NAME_1 %in% adm1$NAME_1))
stopifnot(all(sf::st_is_valid(adm0)), all(sf::st_is_valid(adm1)),
          all(sf::st_is_valid(adm2)))

metadata <- jsonlite::fromJSON(file.path(output_dir, "salb_MDG_metadata.json"))
stopifnot(identical(metadata$source$item_id, spec$item_id))
stopifnot(identical(metadata$source$valid_from, spec$valid_from))
stopifnot(identical(metadata$source$valid_to, spec$valid_to))
stopifnot(identical(metadata$feature_counts$adm0, 1L))
stopifnot(identical(metadata$feature_counts$adm1, 6L))
stopifnot(identical(metadata$feature_counts$adm2, 22L))
stopifnot(grepl("^[0-9a-f]{64}$", metadata$source_archive_sha256))

cat("Madagascar SALB layers and provenance metadata are valid.\n")

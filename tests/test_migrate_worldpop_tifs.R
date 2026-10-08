migration_script <- file.path(
  "Rcode", "_script_for_specific_tasks", "migrate_worldpop_tifs.R"
)
if (!file.exists(migration_script)) {
  stop("Missing WorldPop TIFF migration script: ", migration_script)
}
source(migration_script)

fixture_root <- tempfile("worldpop-migration-")
countries_root <- file.path(fixture_root, "Data", "Countries")
worldpop_home <- file.path(fixture_root, "Worldpop data")
raw_source <- file.path(countries_root, "Alpha", "worldpop")
population_source <- file.path(countries_root, "Alpha", "Population")
raw_destination <- file.path(worldpop_home, "Global1_2000_2020", "Alpha")
population_destination <- file.path(worldpop_home, "Population", "Alpha")
dir.create(raw_source, recursive = TRUE)
dir.create(population_source, recursive = TRUE)
dir.create(raw_destination, recursive = TRUE)

writeBin(charToRaw("same raw raster"), file.path(raw_source, "raw.tif"))
writeBin(charToRaw("same raw raster"), file.path(raw_destination, "raw.tif"))
writeBin(charToRaw("population raster"), file.path(population_source, "population.tif"))
writeLines("keep weight output", file.path(raw_source, "weights.rda"))

result <- migrate_worldpop_tifs(countries_root, worldpop_home, quiet = TRUE)
if (nrow(result) != 2L || !setequal(result$status, c("consolidated", "moved"))) {
  stop("Migration should consolidate one identical TIFF and move one TIFF.")
}
if (file.exists(file.path(raw_source, "raw.tif")) ||
    file.exists(file.path(population_source, "population.tif"))) {
  stop("Successfully migrated TIFF sources should be removed.")
}
if (!file.exists(file.path(raw_source, "weights.rda"))) {
  stop("Migration should leave non-TIFF country outputs in place.")
}
if (!file.exists(file.path(raw_destination, "raw.tif")) ||
    !file.exists(file.path(population_destination, "population.tif"))) {
  stop("Migration should create both centralized destination files.")
}

rerun <- migrate_worldpop_tifs(countries_root, worldpop_home, quiet = TRUE)
if (nrow(rerun) != 0L) {
  stop("Migration should be idempotent after all TIFFs have moved.")
}

conflict_source <- file.path(raw_source, "conflict.tif")
conflict_destination <- file.path(raw_destination, "conflict.tif")
writeBin(charToRaw("source raster"), conflict_source)
writeBin(charToRaw("different destination raster"), conflict_destination)
conflict <- try(
  migrate_worldpop_tifs(countries_root, worldpop_home, quiet = TRUE),
  silent = TRUE
)
if (!inherits(conflict, "try-error") ||
    !grepl("Destination conflict", as.character(conflict), fixed = TRUE)) {
  stop("Migration should refuse a destination TIFF with different content.")
}
if (!file.exists(conflict_source) || !file.exists(conflict_destination)) {
  stop("A conflicting migration must preserve both files.")
}

cat("WorldPop TIFF migration is selective, collision-safe, and idempotent.\n")

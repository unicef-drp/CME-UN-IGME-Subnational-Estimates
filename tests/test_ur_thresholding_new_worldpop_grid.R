script_7b <- paste(readLines(file.path("Rcode", "7b_UR_thresholding_sf.R"),
                             warn = FALSE),
                   collapse = "\n")

required_fragments <- c(
  "years <- c(beg.year:end.proj.year)",
  "population_dir <- population_raster_dir(country)",
  "list.files(population_dir,",
  "file.path(population_dir,",
  'inherits(urb_vec, "Raster")',
  "raster::compareRaster(pred_surf, wp",
  'raster::resample(pred_surf, wp, method = "ngb")'
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = script_7b, fixed = TRUE)]
if (length(missing) > 0) {
  stop("7b_UR_thresholding_sf.R should align urban surfaces to new WorldPop grids. Missing: ",
       paste(missing, collapse = ", "))
}

if (length(gregexpr("urb_vec = urb_surf", script_7b, fixed = TRUE)[[1]]) < 4) {
  stop("7b_UR_thresholding_sf.R should pass the urban raster surface into admin fraction calls.")
}

if (grepl("if(end.proj.year > 2020)", script_7b, fixed = TRUE)) {
  stop("7b_UR_thresholding_sf.R should not duplicate 2021+ admin weights from 2020.")
}

if (grepl('use_path_base(file.path(data.dir, "Population"))',
          script_7b, fixed = TRUE)) {
  stop("7b_UR_thresholding_sf.R should not use the old country-local Population folder.")
}

cat("UR thresholding aligns urban surfaces to new WorldPop grids.\n")

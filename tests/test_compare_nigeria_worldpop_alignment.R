script <- file.path(
  "Rcode",
  "_script_for_specific_tasks",
  "compare_nigeria_worldpop_alignment.R"
)

stopifnot(file.exists(script))

env <- new.env(parent = globalenv())
sys.source(script, envir = env)

specs <- env$comparison_source_specs(
  iso3 = "NGA",
  country = "Nigeria",
  worldpop_root = "C:/Worldpop data"
)

stopifnot(identical(
  names(specs),
  c("old_global1", "aligned_global1", "global2_r2025a")
))
stopifnot(identical(specs$old_global1$years, 2000:2020))
stopifnot(identical(specs$aligned_global1$years, 2000:2015))
stopifnot(identical(specs$global2_r2025a$years, 2015:2025))
stopifnot(identical(env$old_aligned_overlap_years, 2000:2015))

stopifnot(grepl(
  "Global_2000_2020_1km/unconstrained/2000/NGA/nga_f_0_2000_1km.tif",
  env$legacy_worldpop_url("NGA", 2000, "f", 0),
  fixed = TRUE
))
stopifnot(identical(
  specs$old_global1$path(2000, "f", 0),
  "C:/Worldpop data/Global1_2000_2020/Nigeria/nga_f_0_2000_1km.tif"
))

ethiopia_specs <- env$comparison_source_specs(
  iso3 = "ETH",
  country = "Ethiopia",
  worldpop_root = "C:/Worldpop data"
)
stopifnot(grepl(
  "Global_2000_2020_1km/unconstrained/2020/ETH/eth_m_1_2020_1km.tif",
  env$legacy_worldpop_url("ETH", 2020, "m", 1),
  fixed = TRUE
))
stopifnot(identical(
  ethiopia_specs$old_global1$path(2020, "m", 1),
  "C:/Worldpop data/Global1_2000_2020/Ethiopia/eth_m_1_2020_1km.tif"
))
stopifnot(grepl(
  paste0(
    "Global1_2000_2020_aligned/Ethiopia_extracted/2015/ETH/",
    "eth_f_0_2015_constrained_1km.tif"
  ),
  ethiopia_specs$aligned_global1$path(2015, "f", 0),
  fixed = TRUE
))
stopifnot(grepl(
  paste0(
    "Global2_2015_2030/Ethiopia/",
    "eth_m_01_2015_CN_1km_R2025A_UA_v1.tif"
  ),
  ethiopia_specs$global2_r2025a$path(2015, "m", 1),
  fixed = TRUE
))
stopifnot(grepl(
  paste0(
    "Global1_2000_2020_aligned/Nigeria_extracted/2014/NGA/",
    "nga_m_1_2014_constrained_1km.tif"
  ),
  specs$aligned_global1$path(2014, "m", 1),
  fixed = TRUE
))
stopifnot(grepl(
  paste0(
    "Global2_2015_2030/Nigeria/",
    "nga_f_01_2015_CN_1km_R2025A_UA_v1.tif"
  ),
  specs$global2_r2025a$path(2015, "f", 1),
  fixed = TRUE
))

stopifnot(identical(
  env$indicator_components("u1"),
  data.frame(sex = c("f", "m"), age = c(0L, 0L))
))
stopifnot(identical(
  env$indicator_components("u5"),
  data.frame(
    sex = c("f", "f", "m", "m"),
    age = c(0L, 1L, 0L, 1L)
  )
))

tmp <- tempfile("worldpop-comparison-test-")
dir.create(tmp)

template <- terra::rast(
  nrows = 2,
  ncols = 2,
  xmin = 0,
  xmax = 2,
  ymin = 0,
  ymax = 2,
  crs = "EPSG:4326"
)
component_values <- list(
  f0 = 1:4,
  f1 = 5:8,
  m0 = 9:12,
  m1 = 13:16
)
component_paths <- vapply(names(component_values), function(name) {
  output <- file.path(tmp, paste0(name, ".tif"))
  raster <- template
  terra::values(raster) <- component_values[[name]]
  terra::writeRaster(raster, output, overwrite = TRUE)
  output
}, character(1))

u1 <- env$compose_population_raster(component_paths[c("f0", "m0")])
u5 <- env$compose_population_raster(
  component_paths[c("f0", "f1", "m0", "m1")]
)
stopifnot(identical(
  as.numeric(terra::values(u1)),
  c(10, 12, 14, 16)
))
stopifnot(identical(
  as.numeric(terra::values(u5)),
  c(28, 32, 36, 40)
))

mismatched <- terra::rast(
  nrows = 3,
  ncols = 2,
  xmin = 0,
  xmax = 2,
  ymin = 0,
  ymax = 3,
  crs = "EPSG:4326"
)
terra::values(mismatched) <- 1:6
mismatched_path <- file.path(tmp, "mismatched.tif")
terra::writeRaster(mismatched, mismatched_path, overwrite = TRUE)
geometry_error <- try(
  env$compose_population_raster(c(component_paths[["f0"]], mismatched_path)),
  silent = TRUE
)
stopifnot(inherits(geometry_error, "try-error"))

download_target <- file.path(tmp, "downloaded.tif")
download_calls <- 0L
copy_fixture <- function(url, destfile, ...) {
  download_calls <<- download_calls + 1L
  file.copy(component_paths[["f0"]], destfile, overwrite = TRUE)
}
env$download_raster_if_needed(
  "fixture://f0",
  download_target,
  download_fun = copy_fixture
)
env$download_raster_if_needed(
  "fixture://f0",
  download_target,
  download_fun = copy_fixture
)
stopifnot(download_calls == 1L)
stopifnot(env$raster_file_ok(download_target))

population <- template
terra::values(population) <- c(1, 2, 3, 4)

left_polygon <- sf::st_polygon(list(matrix(
  c(0, 0, 1, 0, 1, 2, 0, 2, 0, 0),
  ncol = 2,
  byrow = TRUE
)))
right_polygon <- sf::st_polygon(list(matrix(
  c(1, 0, 2, 0, 2, 2, 1, 2, 1, 0),
  ncol = 2,
  byrow = TRUE
)))
adm1 <- sf::st_sf(
  NAME_1 = c("Left", "Right"),
  geometry = sf::st_sfc(left_polygon, right_polygon, crs = 4326)
)
admin_names <- data.frame(
  Internal = 1:2,
  GeoRepo = c("Left", "Right")
)

zonal <- env$zonal_admin1_counts(adm1, population, admin_names)
stopifnot(nrow(zonal) == 2L)
stopifnot(identical(zonal$region_label, c("Left", "Right")))
stopifnot(sum(zonal$population) == 10)
stopifnot(env$national_from_admin1(zonal) == 10)

adm0_geometry <- sf::st_union(sf::st_geometry(adm1))
adm0 <- sf::st_sf(NAME_0 = "Test", geometry = adm0_geometry)
adm0_total <- env$zonal_admin0_count(adm0, population)
stopifnot(adm0_total == 10)
stopifnot(env$closure_relative_difference(10, 10) == 0)
stopifnot(env$closure_relative_difference(9, 10) > 0.0025)

bad_names_error <- try(
  env$zonal_admin1_counts(
    adm1,
    population,
    data.frame(Internal = 1L, GeoRepo = "Left")
  ),
  silent = TRUE
)
stopifnot(inherits(bad_names_error, "try-error"))

plot_data <- data.frame(
  country = "Nigeria",
  source_key = rep(
    c("old_global1", "aligned_global1", "global2_r2025a"),
    each = 2
  ),
  source_label = rep(
    c(
      "Old Global 1 (pre-alignment)",
      "Aligned Global 1",
      "Global 2 R2025A"
    ),
    each = 2
  ),
  year = c(2014L, 2015L, 2014L, 2015L, 2015L, 2016L),
  indicator = "u1",
  population = c(10, 11, 12, 13, 14, 15)
)
prepared_plot_data <- env$prepare_plot_data(plot_data)
stopifnot(identical(
  sort(unique(as.character(prepared_plot_data$source_key))),
  sort(c("old_global1", "aligned_global1", "global2_r2025a"))
))
stopifnot(
  max(prepared_plot_data$year[
    prepared_plot_data$source_key == "aligned_global1"
  ]) == 2015
)
stopifnot(
  min(prepared_plot_data$year[
    prepared_plot_data$source_key == "global2_r2025a"
  ]) == 2015
)
stopifnot(length(unique(prepared_plot_data$series_group)) == 3L)

national_plot_data <- rbind(
  plot_data,
  transform(plot_data, indicator = "u5", population = population * 4)
)
admin1_plot_data <- do.call(rbind, lapply(seq_len(2), function(region) {
  transform(
    national_plot_data,
    region = region,
    region_label = c("Left", "Right")[[region]],
    population = population * region
  )
}))

admin1_plot <- env$comparison_plot(
  data = env$prepare_plot_data(admin1_plot_data[admin1_plot_data$indicator == "u1", ]),
  facets = ggplot2::vars(region_label),
  title = "Admin-1 zero-baseline test",
  subtitle = "",
  facet_columns = 2,
  zero_baseline = TRUE
)
admin1_plot_build <- ggplot2::ggplot_build(admin1_plot)
admin1_y_minima <- vapply(
  admin1_plot_build$layout$panel_params,
  function(panel) panel$y.range[[1]],
  numeric(1)
)
stopifnot(all(admin1_y_minima == 0))

national_pdf <- file.path(tmp, "national.pdf")
admin1_pdf <- file.path(tmp, "admin1.pdf")
env$write_national_pdf(national_plot_data, national_pdf)
env$write_admin1_pdf(
  admin1_plot_data,
  admin1_pdf,
  regions_per_page = 20L
)
stopifnot(file.info(national_pdf)$size > 1000)
stopifnot(file.info(admin1_pdf)$size > 1000)

captured_pdf_background <- NULL
fake_pdf_device <- function(..., bg) {
  captured_pdf_background <<- bg
  invisible(NULL)
}
env$open_pdf_device(
  file = file.path(tmp, "background-test.pdf"),
  width = 1,
  height = 1,
  device_fun = fake_pdf_device
)
stopifnot(identical(captured_pdf_background, "white"))

manifest <- env$build_input_manifest(specs)
stopifnot(nrow(manifest) == 192L)
stopifnot(sum(manifest$source_key == "old_global1") == 84L)
stopifnot(sum(manifest$source_key == "aligned_global1") == 64L)
stopifnot(sum(manifest$source_key == "global2_r2025a") == 44L)

national_fixture <- data.frame(
  country = "Nigeria",
  iso3 = "NGA",
  source_key = c("old_global1", "aligned_global1"),
  source_label = c(
    "Old Global 1 (pre-alignment)",
    "Aligned Global 1"
  ),
  year = 2000L,
  indicator = "u1",
  population = c(100, 110),
  admin0_population = c(100, 110),
  closure_difference = 0,
  closure_relative_difference = 0
)
admin1_fixture <- do.call(rbind, lapply(seq_len(2), function(region) {
  transform(
    national_fixture,
    region = region,
    region_label = c("Left", "Right")[[region]],
    population = population / 2
  )
}))
differences <- env$build_old_aligned_difference(
  national_fixture,
  admin1_fixture
)
stopifnot(nrow(differences) == 3L)
stopifnot(all(differences$difference_aligned_minus_old == c(10, 5, 5)))
stopifnot(all(differences$pct_difference_aligned_vs_old == 0.1))
stopifnot(identical(sort(unique(differences$level)), c("admin1", "national")))

transition_national <- transform(
  national_fixture,
  year = 2015L,
  population = population + 20,
  admin0_population = admin0_population + 20
)
transition_admin1 <- transform(
  admin1_fixture,
  year = 2015L,
  population = population + 10
)
old_only_national <- transform(
  national_fixture[national_fixture$source_key == "old_global1", ],
  year = 2016L,
  population = 120,
  admin0_population = 120
)
old_only_admin1 <- transform(
  admin1_fixture[admin1_fixture$source_key == "old_global1", ],
  year = 2016L,
  population = 60
)
overlap_differences <- env$build_old_aligned_difference(
  rbind(national_fixture, transition_national, old_only_national),
  rbind(admin1_fixture, transition_admin1, old_only_admin1)
)
stopifnot(identical(sort(unique(overlap_differences$year)), c(2000L, 2015L)))

parsed_args <- env$parse_cli_args(c(
  "--repo=C:/repo with spaces",
  "--worldpop-root=C:/Worldpop data",
  "--country=Ethiopia"
))
stopifnot(identical(parsed_args$repo, "C:/repo with spaces"))
stopifnot(identical(parsed_args$worldpop_root, "C:/Worldpop data"))
stopifnot(identical(parsed_args$country, "Ethiopia"))

local_specs <- list(
  old_global1 = list(
    label = "Old Global 1 (pre-alignment)",
    years = 2000L,
    path = function(year, sex, age) {
      component_paths[[paste0(sex, age)]]
    }
  )
)
aggregated <- env$aggregate_population_tables(
  specs = local_specs,
  adm0 = adm0,
  adm1 = adm1,
  admin_names = admin_names,
  country = "Nigeria",
  iso3 = "NGA",
  closure_tolerance = 0.0025
)
stopifnot(nrow(aggregated$national) == 2L)
stopifnot(nrow(aggregated$admin1) == 4L)
stopifnot(identical(
  aggregated$national$population,
  c(52, 136)
))
stopifnot(all(aggregated$national$closure_relative_difference == 0))

output_paths <- env$comparison_output_paths("C:/output", "Nigeria")
stopifnot(identical(
  basename(unlist(output_paths, use.names = FALSE)),
  c(
    "nigeria_worldpop_input_manifest_2000_2025.csv",
    "nigeria_worldpop_national_u1_u5_2000_2025.csv",
    "nigeria_worldpop_admin1_u1_u5_2000_2025.csv",
    "nigeria_worldpop_old_vs_aligned_difference_2000_2015.csv",
    "nigeria_worldpop_national_u1_u5_2000_2025.pdf",
    "nigeria_worldpop_admin1_u1_u5_2000_2025.pdf"
  )
))
ethiopia_output_paths <- env$comparison_output_paths("C:/output", "Ethiopia")
stopifnot(all(grepl(
  "^ethiopia_worldpop_",
  basename(unlist(ethiopia_output_paths, use.names = FALSE))
)))
stopifnot(is.function(env$run_comparison))

cat(paste(
  "WorldPop comparison source, raster-input, aggregation,",
  "plotting, and output-contract tests passed.\n"
))

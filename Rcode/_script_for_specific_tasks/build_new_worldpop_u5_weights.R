suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(jsonlite)
})

parse_args <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--", arg)) next
    key_value <- sub("^--", "", arg)
    parts <- strsplit(key_value, "=", fixed = TRUE)[[1]]
    key <- gsub("-", "_", parts[[1]])
    value <- if (length(parts) > 1) paste(parts[-1], collapse = "=") else "TRUE"
    out[[key]] <- value
  }
  out
}

as_flag <- function(x) {
  tolower(as.character(x)) %in% c("1", "true", "yes", "y")
}

args <- parse_args(commandArgs(trailingOnly = TRUE))

repo <- args$repo
if (is.null(repo)) {
  repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

country <- if (!is.null(args$country)) args$country else "Nigeria"
start_year <- as.integer(if (!is.null(args$start_year)) args$start_year else 2000L)
end_year <- as.integer(if (!is.null(args$end_year)) args$end_year else 2025L)
worldpop_root <- if (!is.null(args$worldpop_root)) {
  args$worldpop_root
} else {
  "C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/Global_2000_2020_CN_aligned_G2"
}
make_plot <- if (!is.null(args$make_plot)) as_flag(args$make_plot) else TRUE

repo <- normalizePath(repo, winslash = "/", mustWork = TRUE)
worldpop_root <- normalizePath(worldpop_root, winslash = "/", mustWork = TRUE)
source(file.path(repo, "Rcode", "_supporting_scripts", "project_paths.R"))

info_path <- file.path(repo, "Info", paste0(country, "_general_info.json"))
if (!file.exists(info_path)) {
  stop("Missing country info JSON: ", info_path, call. = FALSE)
}
info <- jsonlite::fromJSON(info_path)
iso0 <- info[["iso0"]]
iso0_lower <- tolower(iso0)

data_dir <- file.path(repo, "Data", "Countries", country)
worldpop_dir <- file.path(data_dir, "worldpop")
raw_worldpop_dir <- worldpop_raw_dir(country)
population_dir <- population_raster_dir(country)
dir.create(worldpop_dir, recursive = TRUE, showWarnings = FALSE)

write_output_csv <- function(x, file) {
  tryCatch(
    {
      write.csv(x, file, row.names = FALSE)
      file
    },
    error = function(e) {
      fallback <- file.path(
        dirname(file),
        paste0(
          tools::file_path_sans_ext(basename(file)),
          "_",
          format(Sys.time(), "%Y%m%d_%H%M%S"),
          ".csv"
        )
      )
      warning(
        "Could not write ", file, "; writing ", fallback,
        " instead. Original error: ", conditionMessage(e),
        call. = FALSE
      )
      write.csv(x, fallback, row.names = FALSE)
      fallback
    }
  )
}

shape_dir <- file.path(repo, "Data", "shapeFiles", paste0("georepo_", iso0, "_shp"))
if (!dir.exists(shape_dir)) {
  stop("Missing GeoRepo shape directory: ", shape_dir, call. = FALSE)
}

poly_adm1 <- sf::st_read(
  dsn = shape_dir,
  layer = info[["poly.layer.adm1"]],
  options = "ENCODING=UTF-8",
  quiet = TRUE
)

names_path <- file.path(shape_dir, paste0(country, "_Amat_Names.rda"))
if (!file.exists(names_path)) {
  stop("Missing admin names file: ", names_path, call. = FALSE)
}
load(names_path)
stopifnot(exists("admin1.names"), nrow(admin1.names) == nrow(poly_adm1))
if (!"GeoRepo" %in% names(admin1.names)) {
  admin1.names$GeoRepo <- admin1.names$GADM
}

cn_file <- function(year, sex, age) {
  file.path(
    worldpop_root,
    paste0(country, "_extracted"),
    as.character(year),
    iso0,
    sprintf("%s_%s_%s_%s_constrained_1km.tif", iso0_lower, sex, age, year)
  )
}

g2_file <- function(year, sex, age) {
  age2 <- if (age == 0) "00" else "01"
  file.path(
    worldpop_root,
    paste0("Global2_2015_2030_", iso0),
    "constrained",
    sprintf("%s_%s_%s_%s_CN_1km_R2025A_UA_v1.tif", iso0_lower, sex, age2, year)
  )
}

old_1km_age_sex_file <- function(year, sex, age) {
  file.path(
    raw_worldpop_dir,
    sprintf("%s_%s_%s_%s_1km.tif", iso0_lower, sex, age, year)
  )
}

old_1km_u5_file <- function(year) {
  file.path(
    population_dir,
    sprintf("%s_u5_%s_1km.tif", iso0_lower, year)
  )
}

source_name <- function(year) {
  if (year <= 2014) "CN_aligned_G2_2000_2020" else "Global2_2015_2030_R2025A"
}

age_sex_file <- function(year, sex, age) {
  if (year <= 2014) cn_file(year, sex, age) else g2_file(year, sex, age)
}

input_manifest <- do.call(
  rbind,
  lapply(start_year:end_year, function(year) {
    do.call(
      rbind,
      lapply(c("f", "m"), function(sex) {
        do.call(
          rbind,
          lapply(c(0L, 1L), function(age) {
            path <- age_sex_file(year, sex, age)
            data.frame(
              country = country,
              iso0 = iso0,
              year = year,
              sex = sex,
              age_band = age,
              source = source_name(year),
              path = path,
              exists = file.exists(path),
              stringsAsFactors = FALSE
            )
          })
        )
      })
    )
  })
)

manifest_path <- file.path(
  worldpop_dir,
  sprintf("adm1_weights_u5_1km_new_worldpop_input_manifest_%s_%s.csv", start_year, end_year)
)
manifest_path <- write_output_csv(input_manifest, manifest_path)

missing_files <- input_manifest$path[!input_manifest$exists]
if (length(missing_files) > 0) {
  stop("Missing required rasters:\n", paste(missing_files, collapse = "\n"), call. = FALSE)
}

zone_cache <- new.env(parent = emptyenv())

zone_cache_key <- function(adm_shp, wp) {
  paste(
    nrow(adm_shp),
    terra::nrow(wp),
    terra::ncol(wp),
    paste(terra::res(wp), collapse = "x"),
    paste(as.vector(terra::ext(wp)), collapse = ","),
    terra::crs(wp),
    sep = "|"
  )
}

pop_adm <- function(adm_shp, wp, admin_names) {
  adm_vect <- terra::vect(adm_shp)
  if (!terra::same.crs(wp, adm_vect)) {
    wp <- terra::project(wp, terra::crs(adm_vect))
  }
  key <- zone_cache_key(adm_shp, wp)
  if (exists(key, envir = zone_cache, inherits = FALSE)) {
    zones <- get(key, envir = zone_cache)
  } else {
    adm_vect[[".admin_row"]] <- seq_len(nrow(adm_shp))
    zones <- terra::rasterize(adm_vect, wp[[1]], field = ".admin_row")
    assign(key, zones, envir = zone_cache)
  }

  zonal_sum <- terra::zonal(wp, zones, fun = "sum", na.rm = TRUE)
  admin_pop <- rep(0, nrow(adm_shp))
  matched <- match(seq_len(nrow(adm_shp)), zonal_sum[[1]])
  has_match <- !is.na(matched)
  admin_pop[has_match] <- zonal_sum[[2]][matched[has_match]]
  admin_pop[!is.finite(admin_pop)] <- 0

  out <- admin_names
  out$admin_pop <- admin_pop
  out
}

make_u5_raster <- function(year, file_fun = age_sex_file) {
  files <- c(
    file_fun(year, "f", 0L),
    file_fun(year, "f", 1L),
    file_fun(year, "m", 0L),
    file_fun(year, "m", 1L)
  )
  rasters <- lapply(files, terra::rast)
  # Repository convention: U5 weight raster is WorldPop age bands 0 and 1.
  Reduce(`+`, rasters)
}

make_old_1km_u5_raster <- function(year) {
  u5_file <- old_1km_u5_file(year)
  if (file.exists(u5_file)) {
    return(terra::rast(u5_file))
  }
  files <- c(
    old_1km_age_sex_file(year, "f", 0L),
    old_1km_age_sex_file(year, "f", 1L),
    old_1km_age_sex_file(year, "m", 0L),
    old_1km_age_sex_file(year, "m", 1L)
  )
  if (!all(file.exists(files))) {
    return(NULL)
  }
  Reduce(`+`, lapply(files, terra::rast))
}

raster_total <- function(raster) {
  as.numeric(terra::global(raster, fun = "sum", na.rm = TRUE)[1, 1])
}

admin1_zonal_total <- function(raster) {
  adm_pop <- pop_adm(poly_adm1, raster, admin1.names)
  sum(adm_pop$admin_pop, na.rm = TRUE)
}

weights_for_raster <- function(year, raster) {
  adm_pop <- pop_adm(poly_adm1, raster, admin1.names)
  total_pop <- sum(adm_pop$admin_pop, na.rm = TRUE)
  if (!is.finite(total_pop) || total_pop <= 0) {
    stop("Invalid total population for ", year, call. = FALSE)
  }
  data.frame(
    region = adm_pop$Internal,
    proportion = adm_pop$admin_pop / total_pop,
    years = year
  )
}

rows <- vector("list", length(start_year:end_year))
names(rows) <- as.character(start_year:end_year)
for (year in start_year:end_year) {
  message("Calculating ", country, " new WorldPop adm1 U5 weights for ", year)
  rows[[as.character(year)]] <- weights_for_raster(year, make_u5_raster(year))
}

weight.adm1.u5 <- do.call(rbind, rows)
rownames(weight.adm1.u5) <- NULL

out_rda <- file.path(
  worldpop_dir,
  sprintf("adm1_weights_u5_1km_new_worldpop_%s_%s.rda", start_year, end_year)
)
out_csv <- file.path(
  worldpop_dir,
  sprintf("adm1_weights_u5_1km_new_worldpop_%s_%s.csv", start_year, end_year)
)
save(weight.adm1.u5, file = out_rda)
out_csv <- write_output_csv(weight.adm1.u5, out_csv)

old_path <- file.path(worldpop_dir, "adm1_weights_u5_1km.rda")
if (file.exists(old_path)) {
  old_env <- new.env(parent = emptyenv())
  load(old_path, envir = old_env)
  old_weight <- old_env$weight.adm1.u5
  overlap_years <- intersect(unique(old_weight$years), start_year:end_year)
  comparison <- merge(
    old_weight[old_weight$years %in% overlap_years, ],
    weight.adm1.u5[weight.adm1.u5$years %in% overlap_years, ],
    by = c("region", "years"),
    suffixes = c("_old_1km", "_new_worldpop")
  )
  comparison$diff_new_minus_old <- comparison$proportion_new_worldpop - comparison$proportion_old_1km
  comparison$abs_diff <- abs(comparison$diff_new_minus_old)
  comparison$relative_diff <- ifelse(
    comparison$proportion_old_1km == 0,
    NA_real_,
    comparison$diff_new_minus_old / comparison$proportion_old_1km
  )
  comparison <- comparison[order(comparison$years, comparison$region), ]

  summary_by_year <- do.call(
    rbind,
    lapply(split(comparison, comparison$years), function(x) {
      data.frame(
        years = x$years[[1]],
        mean_abs_diff = mean(x$abs_diff),
        max_abs_diff = max(x$abs_diff),
        mean_diff = mean(x$diff_new_minus_old),
        max_abs_signed_diff = x$diff_new_minus_old[which.max(abs(x$diff_new_minus_old))],
        sum_old = sum(x$proportion_old_1km),
        sum_new = sum(x$proportion_new_worldpop)
      )
    })
  )
  rownames(summary_by_year) <- NULL

  out_comp <- file.path(
    worldpop_dir,
    sprintf("adm1_weights_u5_1km_new_worldpop_vs_old_comparison_%s_%s.csv", start_year, end_year)
  )
  out_summary <- file.path(
    worldpop_dir,
    sprintf("adm1_weights_u5_1km_new_worldpop_vs_old_summary_%s_%s.csv", start_year, end_year)
  )
  out_comp <- write_output_csv(comparison, out_comp)
  out_summary <- write_output_csv(summary_by_year, out_summary)
}

boundary_rows <- list()
boundary_specs <- list(
  cn_aligned_2014 = list(year = 2014L, file_fun = cn_file),
  cn_aligned_2015 = list(year = 2015L, file_fun = cn_file),
  global2_2015 = list(year = 2015L, file_fun = g2_file)
)

for (label in names(boundary_specs)) {
  spec <- boundary_specs[[label]]
  files <- c(
    spec$file_fun(spec$year, "f", 0L),
    spec$file_fun(spec$year, "f", 1L),
    spec$file_fun(spec$year, "m", 0L),
    spec$file_fun(spec$year, "m", 1L)
  )
  if (!all(file.exists(files))) next
  one <- weights_for_raster(spec$year, make_u5_raster(spec$year, spec$file_fun))
  one$source_case <- label
  boundary_rows[[label]] <- one
}

if (length(boundary_rows) > 0) {
  boundary_weights <- do.call(rbind, boundary_rows)
  boundary_weights <- boundary_weights[, c("source_case", "region", "years", "proportion")]
  boundary_wide <- reshape(
    boundary_weights[, c("source_case", "region", "proportion")],
    idvar = "region",
    timevar = "source_case",
    direction = "wide"
  )
  names(boundary_wide) <- sub("^proportion\\.", "", names(boundary_wide))
  if (all(c("cn_aligned_2014", "cn_aligned_2015", "global2_2015") %in% names(boundary_wide))) {
    boundary_wide$cn2015_minus_cn2014 <- boundary_wide$cn_aligned_2015 - boundary_wide$cn_aligned_2014
    boundary_wide$global2_2015_minus_cn2015 <- boundary_wide$global2_2015 - boundary_wide$cn_aligned_2015
    boundary_wide$global2_2015_minus_cn2014 <- boundary_wide$global2_2015 - boundary_wide$cn_aligned_2014
  }
  out_boundary <- file.path(
    worldpop_dir,
    sprintf("adm1_weights_u5_1km_new_worldpop_boundary_sources_%s_%s.csv", start_year, end_year)
  )
  out_boundary <- write_output_csv(boundary_wide, out_boundary)
}

total_rows <- vector("list", length(start_year:end_year))
names(total_rows) <- as.character(start_year:end_year)
admin1_population_rows <- vector("list", length(start_year:end_year))
names(admin1_population_rows) <- as.character(start_year:end_year)
for (year in start_year:end_year) {
  message("Calculating ", country, " U5 total population comparison for ", year)
  new_raster <- make_u5_raster(year)
  old_raster <- make_old_1km_u5_raster(year)
  has_old <- !is.null(old_raster)
  old_raster_total <- if (has_old) raster_total(old_raster) else NA_real_
  old_adm_pop <- if (has_old) pop_adm(poly_adm1, old_raster, admin1.names) else NULL
  old_admin1_total <- if (has_old) sum(old_adm_pop$admin_pop, na.rm = TRUE) else NA_real_
  new_raster_total <- raster_total(new_raster)
  new_adm_pop <- pop_adm(poly_adm1, new_raster, admin1.names)
  new_admin1_total <- sum(new_adm_pop$admin_pop, na.rm = TRUE)
  old_admin1_pop <- if (has_old) old_adm_pop$admin_pop else rep(NA_real_, nrow(new_adm_pop))
  admin1_population_rows[[as.character(year)]] <- data.frame(
    country = country,
    iso0 = iso0,
    region = new_adm_pop$Internal,
    region_label = new_adm_pop$GeoRepo,
    year = year,
    old_1km_admin1_pop_u5 = old_admin1_pop,
    new_worldpop_admin1_pop_u5 = new_adm_pop$admin_pop,
    diff_new_minus_old_admin1_pop_u5 = new_adm_pop$admin_pop - old_admin1_pop,
    pct_diff_new_minus_old_admin1_pop_u5 = (new_adm_pop$admin_pop - old_admin1_pop) / old_admin1_pop
  )
  total_rows[[as.character(year)]] <- data.frame(
    country = country,
    iso0 = iso0,
    year = year,
    old_1km_source = if (has_old) "Global_2000_2020_1km_unconstrained" else NA_character_,
    new_worldpop_source = source_name(year),
    old_1km_raster_total_u5 = old_raster_total,
    old_1km_admin1_zonal_total_u5 = old_admin1_total,
    new_worldpop_raster_total_u5 = new_raster_total,
    new_worldpop_admin1_zonal_total_u5 = new_admin1_total,
    diff_new_minus_old_raster_total = new_raster_total - old_raster_total,
    pct_diff_new_minus_old_raster_total = (new_raster_total - old_raster_total) / old_raster_total,
    diff_new_minus_old_admin1_zonal_total = new_admin1_total - old_admin1_total,
    pct_diff_new_minus_old_admin1_zonal_total = (new_admin1_total - old_admin1_total) / old_admin1_total
  )
}
total_comparison <- do.call(rbind, total_rows)
rownames(total_comparison) <- NULL
admin1_population_comparison <- do.call(rbind, admin1_population_rows)
rownames(admin1_population_comparison) <- NULL
out_total <- file.path(
  worldpop_dir,
  sprintf("u5_total_population_old_1km_vs_new_worldpop_%s_%s.csv", start_year, end_year)
)
out_total <- write_output_csv(total_comparison, out_total)
out_admin1_population <- file.path(
  worldpop_dir,
  sprintf("adm1_u5_population_old_1km_vs_new_worldpop_%s_%s.csv", start_year, end_year)
)
out_admin1_population <- write_output_csv(admin1_population_comparison, out_admin1_population)

if (make_plot) {
  weight.adm1.u5$regionPlot <- admin1.names$GeoRepo[match(weight.adm1.u5$region, admin1.names$Internal)]
  if (anyNA(weight.adm1.u5$regionPlot)) {
    stop("Missing regionPlot mapping for one or more admin1 regions.", call. = FALSE)
  }
  out_pdf <- file.path(worldpop_dir, "admin1_u5_weights.pdf")
  pdf(out_pdf, width = 11, height = 8.5)
  print(SUMMER::mapPlot(
    data = weight.adm1.u5,
    is.long = TRUE,
    variables = "years",
    values = "proportion",
    direction = -1,
    geo = poly_adm1,
    ncol = 5,
    legend.label = "Population weight",
    per1000 = FALSE,
    by.data = "regionPlot",
    by.geo = info[["poly.label.adm1"]]
  ))
  dev.off()

  if (exists("comparison")) {
    if (!requireNamespace("ggplot2", quietly = TRUE)) {
      stop("Package ggplot2 is required for admin1 comparison plots.", call. = FALSE)
    }
    admin_label <- admin1.names$GeoRepo[match(comparison$region, admin1.names$Internal)]
    comparison_long <- rbind(
      data.frame(
        region = comparison$region,
        region_label = admin_label,
        years = comparison$years,
        source = "Old 1km",
        proportion = comparison$proportion_old_1km
      ),
      data.frame(
        region = comparison$region,
        region_label = admin_label,
        years = comparison$years,
        source = "New WorldPop",
        proportion = comparison$proportion_new_worldpop
      )
    )
    comparison_long <- comparison_long[!is.na(comparison_long$region_label), ]
    comparison_long$source <- factor(comparison_long$source, levels = c("Old 1km", "New WorldPop"))
    region_levels <- unique(admin1.names$GeoRepo[match(sort(unique(comparison$region)), admin1.names$Internal)])
    region_levels <- region_levels[!is.na(region_levels)]
    comparison_long$region_label <- factor(comparison_long$region_label, levels = region_levels)

    out_admin1_comparison_pdf <- file.path(
      worldpop_dir,
      sprintf("adm1_weights_u5_1km_new_worldpop_vs_old_by_admin1_%s_%s.pdf", start_year, end_year)
    )
    regions_per_page <- 20L
    region_pages <- split(region_levels, ceiling(seq_along(region_levels) / regions_per_page))
    pdf(out_admin1_comparison_pdf, width = 13, height = 8.5)
    for (page_index in seq_along(region_pages)) {
      page_regions <- region_pages[[page_index]]
      page_data <- comparison_long[comparison_long$region_label %in% page_regions, ]
      page_data$region_label <- factor(as.character(page_data$region_label), levels = page_regions)
      print(
        ggplot2::ggplot(
          page_data,
          ggplot2::aes(
            x = years,
            y = proportion,
            color = source,
            group = source
          )
        ) +
          ggplot2::geom_vline(xintercept = 2015, linetype = "dotted", color = "grey45") +
          ggplot2::geom_line(linewidth = 0.45) +
          ggplot2::geom_point(size = 0.75) +
          ggplot2::facet_wrap(~region_label, ncol = 5, scales = "free_y") +
          ggplot2::scale_color_manual(values = c("Old 1km" = "#0072B2", "New WorldPop" = "#D55E00")) +
          ggplot2::scale_y_continuous(
            limits = c(0, NA),
            expand = ggplot2::expansion(mult = c(0, 0.05))
          ) +
          ggplot2::labs(
            title = paste0(country, " admin1 U5 population weights: old 1km vs new WorldPop"),
            subtitle = paste0("Page ", page_index, " of ", length(region_pages), "; dotted line marks 2015"),
            x = "Year",
            y = "Admin1 population weight",
            color = NULL
          ) +
          ggplot2::theme_bw(base_size = 9) +
          ggplot2::theme(
            legend.position = "top",
            plot.title = ggplot2::element_text(face = "bold"),
            panel.grid.minor = ggplot2::element_blank(),
            strip.background = ggplot2::element_rect(fill = "grey92", color = "grey55")
          )
      )
    }
    dev.off()

    if (exists("admin1_population_comparison")) {
      admin1_population_long <- rbind(
        data.frame(
          region = admin1_population_comparison$region,
          region_label = admin1_population_comparison$region_label,
          years = admin1_population_comparison$year,
          source = "Old 1km",
          population = admin1_population_comparison$old_1km_admin1_pop_u5
        ),
        data.frame(
          region = admin1_population_comparison$region,
          region_label = admin1_population_comparison$region_label,
          years = admin1_population_comparison$year,
          source = "New WorldPop",
          population = admin1_population_comparison$new_worldpop_admin1_pop_u5
        )
      )
      admin1_population_long <- admin1_population_long[!is.na(admin1_population_long$region_label), ]
      admin1_population_long$source <- factor(admin1_population_long$source, levels = c("Old 1km", "New WorldPop"))
      admin1_population_long$region_label <- factor(admin1_population_long$region_label, levels = region_levels)

      out_admin1_population_pdf <- file.path(
        worldpop_dir,
        sprintf("adm1_u5_population_old_1km_vs_new_worldpop_by_admin1_%s_%s.pdf", start_year, end_year)
      )
      pdf(out_admin1_population_pdf, width = 13, height = 8.5)
      for (page_index in seq_along(region_pages)) {
        page_regions <- region_pages[[page_index]]
        page_data <- admin1_population_long[admin1_population_long$region_label %in% page_regions, ]
        page_data$region_label <- factor(as.character(page_data$region_label), levels = page_regions)
        print(
          ggplot2::ggplot(
            page_data,
            ggplot2::aes(
              x = years,
              y = population,
              color = source,
              group = source
            )
          ) +
            ggplot2::geom_vline(xintercept = 2015, linetype = "dotted", color = "grey45") +
            ggplot2::geom_line(linewidth = 0.45, na.rm = TRUE) +
            ggplot2::geom_point(size = 0.75, na.rm = TRUE) +
            ggplot2::facet_wrap(~region_label, ncol = 5, scales = "free_y") +
            ggplot2::scale_color_manual(values = c("Old 1km" = "#0072B2", "New WorldPop" = "#D55E00")) +
            ggplot2::scale_y_continuous(
              limits = c(0, NA),
              labels = function(x) format(x, big.mark = ",", scientific = FALSE),
              expand = ggplot2::expansion(mult = c(0, 0.05))
            ) +
            ggplot2::labs(
              title = paste0(country, " admin1 U5 population counts: old 1km vs new WorldPop"),
              subtitle = paste0("Page ", page_index, " of ", length(region_pages), "; dotted line marks 2015"),
              x = "Year",
              y = "Admin1 U5 population",
              color = NULL
            ) +
            ggplot2::theme_bw(base_size = 9) +
            ggplot2::theme(
              legend.position = "top",
              plot.title = ggplot2::element_text(face = "bold"),
              panel.grid.minor = ggplot2::element_blank(),
              strip.background = ggplot2::element_rect(fill = "grey92", color = "grey55")
            )
        )
      }
      dev.off()
    }
  }

  out_total_pdf <- file.path(
    worldpop_dir,
    sprintf("u5_total_population_old_1km_vs_new_worldpop_%s_%s.pdf", start_year, end_year)
  )
  pdf(out_total_pdf, width = 8.5, height = 5.5)
  plot(
    total_comparison$year,
    total_comparison$new_worldpop_admin1_zonal_total_u5,
    type = "o",
    pch = 16,
    col = "#D55E00",
    xlab = "Year",
    ylab = "Total U5 population",
    main = paste(country, "admin1-zonal U5 total population"),
    ylim = range(
      c(total_comparison$old_1km_admin1_zonal_total_u5,
        total_comparison$new_worldpop_admin1_zonal_total_u5),
      na.rm = TRUE
    )
  )
  lines(
    total_comparison$year,
    total_comparison$old_1km_admin1_zonal_total_u5,
    type = "o",
    pch = 16,
    col = "#0072B2"
  )
  abline(v = 2015, lty = 3, col = "grey40")
  legend(
    "topleft",
    legend = c("Old 1km", "New WorldPop"),
    col = c("#0072B2", "#D55E00"),
    lty = 1,
    pch = 16,
    bty = "n"
  )
  dev.off()
}

year_sums <- tapply(weight.adm1.u5$proportion, weight.adm1.u5$years, sum)
cat("OUT_RDA", out_rda, "\n")
cat("OUT_CSV", out_csv, "\n")
cat("OUT_MANIFEST", manifest_path, "\n")
if (exists("out_comp")) cat("OUT_COMPARISON", out_comp, "\n")
if (exists("out_summary")) cat("OUT_SUMMARY", out_summary, "\n")
if (exists("out_boundary")) cat("OUT_BOUNDARY", out_boundary, "\n")
cat("OUT_TOTAL_COMPARISON", out_total, "\n")
cat("OUT_ADMIN1_POPULATION_COMPARISON", out_admin1_population, "\n")
if (exists("out_pdf")) cat("OUT_PDF", out_pdf, "\n")
if (exists("out_admin1_comparison_pdf")) cat("OUT_ADMIN1_COMPARISON_PDF", out_admin1_comparison_pdf, "\n")
if (exists("out_admin1_population_pdf")) cat("OUT_ADMIN1_POPULATION_PDF", out_admin1_population_pdf, "\n")
if (exists("out_total_pdf")) cat("OUT_TOTAL_PDF", out_total_pdf, "\n")
cat("ROWS", nrow(weight.adm1.u5), "YEARS", min(weight.adm1.u5$years), max(weight.adm1.u5$years), "REGIONS", length(unique(weight.adm1.u5$region)), "\n")
cat("YEAR_SUM_RANGE", min(year_sums), max(year_sums), "\n")
cat("MAX_SUM_DEVIATION", max(abs(year_sums - 1)), "\n")
if (exists("comparison")) {
  cat("MAX_ABS_DIFF", max(comparison$abs_diff), "\n")
  cat("MEAN_ABS_DIFF", mean(comparison$abs_diff), "\n")
}

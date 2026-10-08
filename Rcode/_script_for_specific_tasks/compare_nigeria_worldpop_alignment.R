legacy_worldpop_url <- function(iso3, year, sex, age) {
  iso_upper <- toupper(iso3)
  iso_lower <- tolower(iso3)
  sprintf(
    paste0(
      "https://data.worldpop.org/GIS/AgeSex_structures/",
      "Global_2000_2020_1km/unconstrained/%s/%s/",
      "%s_%s_%s_%s_1km.tif"
    ),
    year,
    iso_upper,
    iso_lower,
    sex,
    age,
    year
  )
}

indicator_components <- function(indicator) {
  if (!indicator %in% c("u1", "u5")) {
    stop("Indicator must be 'u1' or 'u5'.", call. = FALSE)
  }

  if (indicator == "u1") {
    data.frame(sex = c("f", "m"), age = c(0L, 0L))
  } else {
    data.frame(
      sex = c("f", "f", "m", "m"),
      age = c(0L, 1L, 0L, 1L)
    )
  }
}

comparison_source_specs <- function(iso3, country, worldpop_root) {
  iso_lower <- tolower(iso3)

  list(
    old_global1 = list(
      label = "Old Global 1 (pre-alignment)",
      years = 2000:2020,
      path = function(year, sex, age) {
        file.path(
          worldpop_root,
          "Global1_2000_2020",
          country,
          sprintf("%s_%s_%s_%s_1km.tif", iso_lower, sex, age, year)
        )
      }
    ),
    aligned_global1 = list(
      label = "Aligned Global 1",
      years = 2000:2015,
      path = function(year, sex, age) {
        file.path(
          worldpop_root,
          "Global1_2000_2020_aligned",
          paste0(country, "_extracted"),
          as.character(year),
          iso3,
          sprintf(
            "%s_%s_%s_%s_constrained_1km.tif",
            iso_lower,
            sex,
            age,
            year
          )
        )
      }
    ),
    global2_r2025a = list(
      label = "Global 2 R2025A",
      years = 2015:2025,
      path = function(year, sex, age) {
        file.path(
          worldpop_root,
          "Global2_2015_2030",
          country,
          sprintf(
            "%s_%s_%02d_%s_CN_1km_R2025A_UA_v1.tif",
            iso_lower,
            sex,
            age,
            year
          )
        )
      }
    )
  )
}

old_aligned_overlap_years <- 2000:2015

build_input_manifest <- function(specs) {
  rows <- list()
  row_index <- 0L

  for (source_key in names(specs)) {
    spec <- specs[[source_key]]
    for (year in spec$years) {
      for (sex in c("f", "m")) {
        for (age in 0:1) {
          row_index <- row_index + 1L
          path <- spec$path(year, sex, age)
          rows[[row_index]] <- data.frame(
            source_key = source_key,
            source_label = spec$label,
            year = as.integer(year),
            sex = sex,
            age = as.integer(age),
            path = path,
            exists = file.exists(path),
            readable = raster_file_ok(path),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  output <- do.call(rbind, rows)
  rownames(output) <- NULL
  output
}

pair_old_aligned <- function(data, keys, level, country) {
  old <- data[data$source_key == "old_global1", c(keys, "population")]
  aligned <- data[
    data$source_key == "aligned_global1",
    c(keys, "population")
  ]
  overlap_years <- intersect(
    intersect(unique(old$year), unique(aligned$year)),
    old_aligned_overlap_years
  )
  old <- old[old$year %in% overlap_years, , drop = FALSE]
  aligned <- aligned[aligned$year %in% overlap_years, , drop = FALSE]
  names(old)[names(old) == "population"] <- "old_global1_population"
  names(aligned)[names(aligned) == "population"] <- "aligned_global1_population"
  paired <- merge(old, aligned, by = keys, all = TRUE, sort = TRUE)
  if (anyNA(paired$old_global1_population) ||
      anyNA(paired$aligned_global1_population)) {
    stop("Old/aligned comparison rows do not pair completely.", call. = FALSE)
  }

  paired$level <- level
  if (level == "national") {
    paired$region <- NA_integer_
    paired$region_label <- country
  }
  paired$difference_aligned_minus_old <-
    paired$aligned_global1_population - paired$old_global1_population
  paired$pct_difference_aligned_vs_old <- ifelse(
    paired$old_global1_population == 0,
    NA_real_,
    paired$difference_aligned_minus_old / paired$old_global1_population
  )
  paired
}

build_old_aligned_difference <- function(national, admin1) {
  country <- unique(national$country)
  if (length(country) != 1L) {
    stop("National comparison must contain one country.", call. = FALSE)
  }

  national_difference <- pair_old_aligned(
    national,
    keys = c("year", "indicator"),
    level = "national",
    country = country
  )
  admin1_difference <- pair_old_aligned(
    admin1,
    keys = c("year", "indicator", "region", "region_label"),
    level = "admin1",
    country = country
  )

  columns <- c(
    "level",
    "year",
    "indicator",
    "region",
    "region_label",
    "old_global1_population",
    "aligned_global1_population",
    "difference_aligned_minus_old",
    "pct_difference_aligned_vs_old"
  )
  output <- rbind(
    national_difference[, columns],
    admin1_difference[, columns]
  )
  rownames(output) <- NULL
  output
}

parse_cli_args <- function(args) {
  output <- list()
  for (arg in args) {
    if (!grepl("^--", arg)) {
      next
    }
    key_value <- sub("^--", "", arg)
    parts <- strsplit(key_value, "=", fixed = TRUE)[[1]]
    key <- gsub("-", "_", parts[[1]], fixed = TRUE)
    value <- if (length(parts) > 1L) {
      paste(parts[-1], collapse = "=")
    } else {
      "TRUE"
    }
    output[[key]] <- value
  }
  output
}

raster_file_ok <- function(path) {
  file.exists(path) && tryCatch(
    terra::nlyr(terra::rast(path)) > 0L,
    error = function(e) FALSE
  )
}

download_raster_if_needed <- function(
  url,
  file,
  download_fun = utils::download.file
) {
  if (raster_file_ok(file)) {
    return(invisible(file))
  }

  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  temporary_file <- file.path(
    dirname(file),
    paste0(tools::file_path_sans_ext(basename(file)), ".download.tif")
  )
  if (file.exists(temporary_file)) {
    unlink(temporary_file)
  }
  on.exit({
    if (file.exists(temporary_file)) {
      unlink(temporary_file)
    }
  }, add = TRUE)

  download_fun(
    url,
    temporary_file,
    mode = "wb",
    quiet = FALSE
  )
  if (!raster_file_ok(temporary_file)) {
    stop("Downloaded raster is unreadable: ", url, call. = FALSE)
  }
  if (file.exists(file)) {
    unlink(file)
  }
  if (!file.rename(temporary_file, file)) {
    stop("Could not finalize raster: ", file, call. = FALSE)
  }

  invisible(file)
}

compose_population_raster <- function(paths) {
  if (length(paths) < 1L || any(!file.exists(paths))) {
    stop("All component raster paths must exist.", call. = FALSE)
  }

  rasters <- lapply(paths, terra::rast)
  reference <- rasters[[1]]
  if (length(rasters) > 1L) {
    for (index in 2:length(rasters)) {
      compatible <- terra::compareGeom(
        reference,
        rasters[[index]],
        stopOnError = FALSE
      )
      if (!isTRUE(compatible)) {
        stop("Component raster geometry differs.", call. = FALSE)
      }
    }
  }

  Reduce(`+`, rasters)
}

zone_cache <- new.env(parent = emptyenv())

zone_cache_key <- function(level, polygons, population) {
  paste(
    level,
    nrow(polygons),
    terra::nrow(population),
    terra::ncol(population),
    paste(terra::res(population), collapse = "x"),
    paste(as.vector(terra::ext(population)), collapse = ","),
    terra::crs(population),
    sep = "|"
  )
}

zone_raster <- function(polygons, population, level) {
  polygons_vect <- terra::vect(polygons)
  if (!terra::same.crs(population, polygons_vect)) {
    polygons_vect <- terra::project(polygons_vect, terra::crs(population))
  }

  key <- zone_cache_key(level, polygons, population)
  if (exists(key, envir = zone_cache, inherits = FALSE)) {
    return(get(key, envir = zone_cache, inherits = FALSE))
  }

  polygons_vect$.admin_zone <- seq_len(nrow(polygons))
  zones <- terra::rasterize(
    polygons_vect,
    population[[1]],
    field = ".admin_zone"
  )
  assign(key, zones, envir = zone_cache)
  zones
}

zonal_population_values <- function(polygons, population, level) {
  zones <- zone_raster(polygons, population, level)
  zonal_sum <- terra::zonal(
    population,
    zones,
    fun = "sum",
    na.rm = TRUE
  )
  output <- numeric(nrow(polygons))
  matched <- match(seq_len(nrow(polygons)), zonal_sum[[1]])
  has_match <- !is.na(matched)
  output[has_match] <- zonal_sum[[2]][matched[has_match]]
  output[!is.finite(output)] <- 0
  output
}

zonal_admin1_counts <- function(adm1_sf, population, admin_names) {
  required_name_columns <- c("Internal", "GeoRepo")
  if (
    nrow(admin_names) != nrow(adm1_sf) ||
      !all(required_name_columns %in% names(admin_names)) ||
      anyNA(admin_names$GeoRepo)
  ) {
    stop(
      "Admin-1 name mapping must contain one Internal/GeoRepo row per polygon.",
      call. = FALSE
    )
  }

  data.frame(
    region = admin_names$Internal,
    region_label = admin_names$GeoRepo,
    population = zonal_population_values(adm1_sf, population, "admin1")
  )
}

national_from_admin1 <- function(admin1_counts) {
  sum(admin1_counts$population, na.rm = TRUE)
}

zonal_admin0_count <- function(adm0_sf, population) {
  sum(zonal_population_values(adm0_sf, population, "admin0"), na.rm = TRUE)
}

closure_relative_difference <- function(admin1_total, admin0_total) {
  if (!is.finite(admin0_total) || admin0_total <= 0) {
    stop("Admin-0 population total must be positive and finite.", call. = FALSE)
  }
  abs(admin1_total - admin0_total) / admin0_total
}

indicator_paths <- function(spec, year, indicator) {
  components <- indicator_components(indicator)
  vapply(seq_len(nrow(components)), function(index) {
    spec$path(
      year,
      components$sex[[index]],
      components$age[[index]]
    )
  }, character(1))
}

aggregate_population_tables <- function(
  specs,
  adm0,
  adm1,
  admin_names,
  country,
  iso3,
  closure_tolerance = 0.0025,
  verbose = FALSE
) {
  national_rows <- list()
  admin1_rows <- list()
  national_index <- 0L
  admin1_index <- 0L

  for (source_key in names(specs)) {
    spec <- specs[[source_key]]
    for (year in spec$years) {
      for (indicator in c("u1", "u5")) {
        if (isTRUE(verbose)) {
          message(
            "Aggregating ",
            spec$label,
            " ",
            year,
            " ",
            toupper(indicator)
          )
        }

        population <- compose_population_raster(
          indicator_paths(spec, year, indicator)
        )
        one_admin1 <- zonal_admin1_counts(
          adm1,
          population,
          admin_names
        )
        admin1_total <- national_from_admin1(one_admin1)
        admin0_total <- zonal_admin0_count(adm0, population)
        closure <- closure_relative_difference(admin1_total, admin0_total)

        if (
          !is.finite(admin1_total) ||
            admin1_total <= 0 ||
            any(!is.finite(one_admin1$population)) ||
            any(one_admin1$population < 0)
        ) {
          stop(
            "Invalid population total for ",
            spec$label,
            " ",
            year,
            " ",
            toupper(indicator),
            ".",
            call. = FALSE
          )
        }
        if (closure > closure_tolerance) {
          stop(
            "Admin-0/Admin-1 closure exceeds ",
            closure_tolerance,
            " for ",
            spec$label,
            " ",
            year,
            " ",
            toupper(indicator),
            ": ",
            signif(closure, 6),
            call. = FALSE
          )
        }

        national_index <- national_index + 1L
        national_rows[[national_index]] <- data.frame(
          country = country,
          iso3 = iso3,
          source_key = source_key,
          source_label = spec$label,
          year = as.integer(year),
          indicator = indicator,
          population = admin1_total,
          admin0_population = admin0_total,
          closure_difference = admin1_total - admin0_total,
          closure_relative_difference = closure,
          stringsAsFactors = FALSE
        )

        admin1_index <- admin1_index + 1L
        admin1_rows[[admin1_index]] <- data.frame(
          country = country,
          iso3 = iso3,
          source_key = source_key,
          source_label = spec$label,
          year = as.integer(year),
          indicator = indicator,
          region = one_admin1$region,
          region_label = one_admin1$region_label,
          population = one_admin1$population,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  national <- do.call(rbind, national_rows)
  admin1_output <- do.call(rbind, admin1_rows)
  rownames(national) <- NULL
  rownames(admin1_output) <- NULL
  list(national = national, admin1 = admin1_output)
}

source_labels <- c(
  "Old Global 1 (pre-alignment)",
  "Aligned Global 1",
  "Global 2 R2025A"
)

prepare_plot_data <- function(data) {
  required_columns <- c(
    "source_key",
    "source_label",
    "year",
    "indicator",
    "population"
  )
  if (!all(required_columns %in% names(data))) {
    stop(
      "Plot data are missing required columns: ",
      paste(setdiff(required_columns, names(data)), collapse = ", "),
      call. = FALSE
    )
  }

  data$source_label <- factor(data$source_label, levels = source_labels)
  if (anyNA(data$source_label)) {
    stop("Plot data contain an unknown WorldPop source label.", call. = FALSE)
  }
  data$indicator <- factor(toupper(data$indicator), levels = c("U1", "U5"))
  if (anyNA(data$indicator)) {
    stop("Plot data contain an unknown population indicator.", call. = FALSE)
  }
  data$series_group <- interaction(
    data$source_key,
    data$indicator,
    drop = TRUE,
    sep = "::"
  )
  data
}

population_axis_labels <- function(values) {
  format(
    round(values),
    big.mark = ",",
    scientific = FALSE,
    trim = TRUE
  )
}

comparison_plot <- function(
  data,
  facets,
  title,
  subtitle,
  facet_columns = NULL,
  zero_baseline = FALSE
) {
  y_scale <- if (isTRUE(zero_baseline)) {
    ggplot2::scale_y_continuous(
      labels = population_axis_labels,
      limits = c(0, NA),
      expand = ggplot2::expansion(mult = c(0, 0.05))
    )
  } else {
    ggplot2::scale_y_continuous(labels = population_axis_labels)
  }

  ggplot2::ggplot(
    data,
    ggplot2::aes(
      x = year,
      y = population,
      color = source_label,
      linetype = source_label,
      shape = source_label,
      group = series_group
    )
  ) +
    ggplot2::geom_vline(
      xintercept = 2015,
      linetype = "dotted",
      color = "grey45",
      linewidth = 0.4
    ) +
    ggplot2::geom_line(linewidth = 0.65, na.rm = TRUE) +
    ggplot2::geom_point(size = 1.2, na.rm = TRUE) +
    ggplot2::facet_wrap(
      facets = facets,
      ncol = facet_columns,
      scales = "free_y"
    ) +
    ggplot2::scale_color_manual(
      values = c(
        "Old Global 1 (pre-alignment)" = "#0072B2",
        "Aligned Global 1" = "#D55E00",
        "Global 2 R2025A" = "#009E73"
      ),
      drop = FALSE
    ) +
    ggplot2::scale_linetype_manual(
      values = c(
        "Old Global 1 (pre-alignment)" = "longdash",
        "Aligned Global 1" = "solid",
        "Global 2 R2025A" = "dotdash"
      ),
      drop = FALSE
    ) +
    ggplot2::scale_shape_manual(
      values = c(
        "Old Global 1 (pre-alignment)" = 16,
        "Aligned Global 1" = 17,
        "Global 2 R2025A" = 15
      ),
      drop = FALSE
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(2000, 2025, by = 5),
      minor_breaks = NULL
    ) +
    y_scale +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = "Year",
      y = "Population",
      color = NULL,
      linetype = NULL,
      shape = NULL
    ) +
    ggplot2::guides(
      color = ggplot2::guide_legend(nrow = 1),
      linetype = ggplot2::guide_legend(nrow = 1),
      shape = ggplot2::guide_legend(nrow = 1)
    ) +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(
      legend.position = "top",
      legend.box = "vertical",
      legend.background = ggplot2::element_rect(fill = "white", color = NA),
      plot.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      strip.background = ggplot2::element_rect(
        fill = "grey92",
        color = "grey55"
      )
    )
}

open_pdf_device <- function(
  file,
  width,
  height,
  device_fun = grDevices::pdf
) {
  device_fun(
    file = file,
    width = width,
    height = height,
    onefile = TRUE,
    useDingbats = FALSE,
    bg = "white"
  )
  invisible(file)
}

write_national_pdf <- function(data, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  country <- unique(as.character(data$country))
  if (length(country) != 1L) {
    stop("National plot data must contain one country.", call. = FALSE)
  }
  data <- prepare_plot_data(data)
  open_pdf_device(
    file = file,
    width = 8.5,
    height = 8.5
  )
  on.exit(grDevices::dev.off(), add = TRUE)

  print(comparison_plot(
    data = data,
    facets = ggplot2::vars(indicator),
    title = paste(country, "U1 and U5 population by WorldPop source"),
    subtitle = paste(
      "Dotted line marks 2015; each source retains its available years",
      "and source series are not connected."
    ),
    facet_columns = 1
  ))
  invisible(file)
}

write_admin1_pdf <- function(data, file, regions_per_page = 20L) {
  if (regions_per_page < 1L) {
    stop("regions_per_page must be positive.", call. = FALSE)
  }
  required_columns <- c("region", "region_label")
  if (!all(required_columns %in% names(data))) {
    stop("Admin-1 plot data are missing region columns.", call. = FALSE)
  }

  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  country <- unique(as.character(data$country))
  if (length(country) != 1L) {
    stop("Admin-1 plot data must contain one country.", call. = FALSE)
  }
  data <- prepare_plot_data(data)
  region_levels <- sort(unique(as.character(data$region_label)))
  region_pages <- split(
    region_levels,
    ceiling(seq_along(region_levels) / regions_per_page)
  )

  open_pdf_device(
    file = file,
    width = 13,
    height = 8.5
  )
  on.exit(grDevices::dev.off(), add = TRUE)

  indicator_levels <- levels(droplevels(data$indicator))
  for (indicator_value in indicator_levels) {
    for (page_index in seq_along(region_pages)) {
      page_regions <- region_pages[[page_index]]
      page_data <- data[
        data$indicator == indicator_value &
          data$region_label %in% page_regions,
        ,
        drop = FALSE
      ]
      page_data$region_label <- factor(
        page_data$region_label,
        levels = page_regions
      )
      print(comparison_plot(
        data = page_data,
        facets = ggplot2::vars(region_label),
        title = paste(
          paste(country, "Admin-1"),
          indicator_value,
          "population by WorldPop source"
        ),
        subtitle = paste0(
          "Page ",
          page_index,
          " of ",
          length(region_pages),
          "; dotted line marks 2015."
        ),
        facet_columns = 5,
        zero_baseline = TRUE
      ))
    }
  }
  invisible(file)
}

comparison_output_paths <- function(output_dir, country = "Nigeria") {
  country_slug <- tolower(gsub("[^A-Za-z0-9]+", "_", country))
  list(
    manifest = file.path(
      output_dir,
      paste0(country_slug, "_worldpop_input_manifest_2000_2025.csv")
    ),
    national = file.path(
      output_dir,
      paste0(country_slug, "_worldpop_national_u1_u5_2000_2025.csv")
    ),
    admin1 = file.path(
      output_dir,
      paste0(country_slug, "_worldpop_admin1_u1_u5_2000_2025.csv")
    ),
    difference = file.path(
      output_dir,
      paste0(
        country_slug,
        "_worldpop_old_vs_aligned_difference_2000_2015.csv"
      )
    ),
    national_pdf = file.path(
      output_dir,
      paste0(country_slug, "_worldpop_national_u1_u5_2000_2025.pdf")
    ),
    admin1_pdf = file.path(
      output_dir,
      paste0(country_slug, "_worldpop_admin1_u1_u5_2000_2025.pdf")
    )
  )
}

load_country_spatial_context <- function(repo, info) {
  shape_dir <- file.path(
    repo,
    "Data",
    "shapeFiles",
    paste0("georepo_", info$iso0, "_shp")
  )
  if (!dir.exists(shape_dir)) {
    stop("Missing GeoRepo shape directory: ", shape_dir, call. = FALSE)
  }

  adm0 <- sf::st_read(
    dsn = shape_dir,
    layer = info[["poly.layer.adm0"]],
    options = "ENCODING=UTF-8",
    quiet = TRUE
  )
  adm1 <- sf::st_read(
    dsn = shape_dir,
    layer = info[["poly.layer.adm1"]],
    options = "ENCODING=UTF-8",
    quiet = TRUE
  )

  names_path <- file.path(shape_dir, paste0(info$country, "_Amat_Names.rda"))
  if (!file.exists(names_path)) {
    stop("Missing admin-name crosswalk: ", names_path, call. = FALSE)
  }
  names_environment <- new.env(parent = emptyenv())
  base::load(names_path, envir = names_environment)
  if (!exists("admin1.names", envir = names_environment, inherits = FALSE)) {
    stop("Admin-name crosswalk does not contain admin1.names.", call. = FALSE)
  }
  admin_names <- get("admin1.names", envir = names_environment)
  if (!"GeoRepo" %in% names(admin_names)) {
    if (!"GADM" %in% names(admin_names)) {
      stop("Admin-name crosswalk lacks GeoRepo and GADM labels.", call. = FALSE)
    }
    admin_names$GeoRepo <- admin_names$GADM
  }

  label_column <- info[["poly.label.adm1"]]
  if (!label_column %in% names(adm1)) {
    stop("Admin-1 boundary lacks label column: ", label_column, call. = FALSE)
  }
  boundary_labels <- as.character(adm1[[label_column]])
  matched_names <- match(boundary_labels, as.character(admin_names$GeoRepo))
  if (anyNA(matched_names) || anyDuplicated(matched_names)) {
    stop(
      "Admin-1 GeoRepo boundary labels do not match the name crosswalk.",
      call. = FALSE
    )
  }
  admin_names <- admin_names[matched_names, , drop = FALSE]
  rownames(admin_names) <- NULL

  list(adm0 = adm0, adm1 = adm1, admin_names = admin_names)
}

download_legacy_inputs <- function(specs, iso3) {
  for (year in specs$old_global1$years) {
    for (sex in c("f", "m")) {
      for (age in 0:1) {
        output_file <- specs$old_global1$path(year, sex, age)
        if (!raster_file_ok(output_file)) {
          message("Downloading legacy Global 1: ", basename(output_file))
        }
        download_raster_if_needed(
          legacy_worldpop_url(iso3, year, sex, age),
          output_file
        )
      }
    }
  }
  invisible(TRUE)
}

expected_source_indicator_keys <- function(specs) {
  do.call(rbind, lapply(names(specs), function(source_key) {
    spec <- specs[[source_key]]
    expand.grid(
      source_key = source_key,
      year = as.integer(spec$years),
      indicator = c("u1", "u5"),
      stringsAsFactors = FALSE
    )
  }))
}

validate_comparison_outputs <- function(
  specs,
  manifest,
  national,
  admin1,
  expected_regions,
  closure_tolerance = 0.0025
) {
  expected_manifest_rows <- sum(vapply(
    specs,
    function(spec) length(spec$years) * 4L,
    integer(1)
  ))
  expected_keys <- expected_source_indicator_keys(specs)
  expected_national_rows <- nrow(expected_keys)

  if (nrow(manifest) != expected_manifest_rows || !all(manifest$readable)) {
    stop("Input manifest coverage or readability is invalid.", call. = FALSE)
  }
  if (nrow(national) != expected_national_rows) {
    stop("National output has unexpected row coverage.", call. = FALSE)
  }
  if (nrow(admin1) != expected_national_rows * expected_regions) {
    stop("Admin-1 output has unexpected row coverage.", call. = FALSE)
  }

  expected_key_text <- with(
    expected_keys,
    paste(source_key, year, indicator, sep = "|")
  )
  national_key_text <- with(
    national,
    paste(source_key, year, indicator, sep = "|")
  )
  if (!setequal(expected_key_text, national_key_text) ||
      anyDuplicated(national_key_text)) {
    stop("National source/year/indicator coverage is invalid.", call. = FALSE)
  }

  admin1_key_text <- with(
    admin1,
    paste(source_key, year, indicator, region, sep = "|")
  )
  if (anyDuplicated(admin1_key_text)) {
    stop("Admin-1 source/year/indicator/region keys are duplicated.", call. = FALSE)
  }
  if (
    any(!is.finite(national$population)) ||
      any(national$population <= 0) ||
      any(!is.finite(admin1$population)) ||
      any(admin1$population < 0)
  ) {
    stop("Comparison outputs contain invalid population counts.", call. = FALSE)
  }
  if (max(national$closure_relative_difference) > closure_tolerance) {
    stop("Comparison outputs exceed the closure tolerance.", call. = FALSE)
  }

  invisible(TRUE)
}

write_comparison_outputs <- function(
  output_paths,
  manifest,
  national,
  admin1,
  differences
) {
  utils::write.csv(manifest, output_paths$manifest, row.names = FALSE)
  utils::write.csv(national, output_paths$national, row.names = FALSE)
  utils::write.csv(admin1, output_paths$admin1, row.names = FALSE)
  utils::write.csv(differences, output_paths$difference, row.names = FALSE)
  write_national_pdf(national, output_paths$national_pdf)
  write_admin1_pdf(admin1, output_paths$admin1_pdf)
  invisible(output_paths)
}

run_comparison <- function(
  repo = normalizePath(getwd(), winslash = "/", mustWork = TRUE),
  worldpop_root = paste0(
    "C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/",
    "UN IGME Subnational/Worldpop data"
  ),
  country = "Nigeria",
  closure_tolerance = 0.0025
) {
  repo <- normalizePath(repo, winslash = "/", mustWork = TRUE)
  worldpop_root <- normalizePath(
    worldpop_root,
    winslash = "/",
    mustWork = TRUE
  )
  info_path <- file.path(repo, "Info", paste0(country, "_general_info.json"))
  if (!file.exists(info_path)) {
    stop("Missing country-info JSON: ", info_path, call. = FALSE)
  }
  info <- jsonlite::fromJSON(info_path)
  if (!identical(info$country, country) ||
      !is.character(info$iso0) || length(info$iso0) != 1L) {
    stop("Country-info JSON has unexpected country identifiers.", call. = FALSE)
  }

  worldpop_dir <- file.path(
    repo,
    "Data",
    "Countries",
    info$country,
    "worldpop"
  )
  output_dir <- file.path(worldpop_dir, "comparison")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  specs <- comparison_source_specs(
    info$iso0,
    info$country,
    worldpop_root
  )
  options(timeout = max(200000, getOption("timeout", 60)))
  download_legacy_inputs(specs, info$iso0)

  manifest <- build_input_manifest(specs)
  output_paths <- comparison_output_paths(output_dir, info$country)
  utils::write.csv(manifest, output_paths$manifest, row.names = FALSE)
  if (!all(manifest$readable)) {
    stop(
      "Unreadable required rasters:\n",
      paste(manifest$path[!manifest$readable], collapse = "\n"),
      call. = FALSE
    )
  }

  spatial <- load_country_spatial_context(repo, info)
  tables <- aggregate_population_tables(
    specs = specs,
    adm0 = spatial$adm0,
    adm1 = spatial$adm1,
    admin_names = spatial$admin_names,
    country = info$country,
    iso3 = info$iso0,
    closure_tolerance = closure_tolerance,
    verbose = TRUE
  )
  validate_comparison_outputs(
    specs = specs,
    manifest = manifest,
    national = tables$national,
    admin1 = tables$admin1,
    expected_regions = nrow(spatial$adm1),
    closure_tolerance = closure_tolerance
  )
  differences <- build_old_aligned_difference(
    tables$national,
    tables$admin1
  )
  write_comparison_outputs(
    output_paths,
    manifest,
    tables$national,
    tables$admin1,
    differences
  )

  cat("OUT_MANIFEST", output_paths$manifest, "\n")
  cat("OUT_NATIONAL_CSV", output_paths$national, "\n")
  cat("OUT_ADMIN1_CSV", output_paths$admin1, "\n")
  cat("OUT_DIFFERENCE_CSV", output_paths$difference, "\n")
  cat("OUT_NATIONAL_PDF", output_paths$national_pdf, "\n")
  cat("OUT_ADMIN1_PDF", output_paths$admin1_pdf, "\n")
  cat("MANIFEST_ROWS", nrow(manifest), "\n")
  cat("NATIONAL_ROWS", nrow(tables$national), "\n")
  cat("ADMIN1_ROWS", nrow(tables$admin1), "\n")
  cat(
    "MAX_CLOSURE_RELATIVE_DIFFERENCE",
    max(tables$national$closure_relative_difference),
    "\n"
  )

  invisible(list(
    paths = output_paths,
    manifest = manifest,
    national = tables$national,
    admin1 = tables$admin1,
    differences = differences
  ))
}

main <- function(command_args = commandArgs(trailingOnly = TRUE)) {
  args <- parse_cli_args(command_args)
  repo <- if (!is.null(args$repo)) args$repo else getwd()
  worldpop_root <- if (!is.null(args$worldpop_root)) {
    args$worldpop_root
  } else {
    paste0(
      "C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/",
      "UN IGME Subnational/Worldpop data"
    )
  }
  country <- if (!is.null(args$country)) args$country else "Nigeria"
  run_comparison(
    repo = repo,
    worldpop_root = worldpop_root,
    country = country
  )
}

if (sys.nframe() == 0L) {
  main()
}

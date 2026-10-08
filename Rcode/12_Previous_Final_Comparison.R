# Compare current final Admin-1 estimates with a prior final-estimates workbook.
#
# Normal workflow usage after Rcode/1_Preperation.R:
#
# previous_final_workbook <- Sys.getenv("PREVIOUS_FINAL_ESTIMATES_XLSX")
# source(file.path("Rcode", "12_Previous_Final_Comparison.R"))
# run_previous_final_comparison(
#   country = country,
#   iso3 = iso0,
#   previous_workbook = previous_final_workbook,
#   home_dir = project_home(),
#   res_dir = file.path(project_home(), "Results", country),
#   regions_per_page = 6L,
#   strata_model = final_model$strata.model,
#   benchmarked = identical(final_model$bench.model, "bench")
# )

direct_uncertainty_path <- file.path(
  "Rcode",
  "_supporting_scripts",
  "direct_estimate_uncertainty.R"
)
sys.source(direct_uncertainty_path, envir = environment())
rm(direct_uncertainty_path)

report_output_config_path <- file.path(
  "Rcode",
  "_supporting_scripts",
  "report_output_config.R"
)
sys.source(report_output_config_path, envir = environment())
rm(report_output_config_path)

a4_portrait_inches <- function() {
  c(width = 210 / 25.4, height = 297 / 25.4)
}

normalize_admin_level <- function(admin_level) {
  value <- gsub("[- _]", "", as.character(admin_level), perl = TRUE)
  value <- paste0("Admin", sub("^Admin", "", value, ignore.case = TRUE))
  if (length(value) != 1L || is.na(value) ||
      !value %in% c("Admin1", "Admin2")) {
    stop("admin_level must be 'Admin1' or 'Admin2'.", call. = FALSE)
  }
  value
}

period_midpoint <- function(period) {
  vapply(as.character(period), function(value) {
    if (is.na(value) || !nzchar(trimws(value))) {
      return(NA_real_)
    }
    value <- gsub("\u2013", "-", value, fixed = TRUE)
    numbers <- suppressWarnings(as.numeric(trimws(strsplit(value, "-", fixed = TRUE)[[1]])))
    numbers <- numbers[is.finite(numbers)]
    if (length(numbers) == 0L) NA_real_ else mean(numbers)
  }, numeric(1), USE.NAMES = FALSE)
}

paginate_regions <- function(regions, regions_per_page = 6L) {
  regions_per_page <- as.integer(regions_per_page)
  if (length(regions_per_page) != 1L || is.na(regions_per_page) ||
      regions_per_page < 1L) {
    stop("regions_per_page must be a positive integer.", call. = FALSE)
  }
  regions <- unique(as.character(regions))
  regions <- regions[!is.na(regions) & nzchar(regions)]
  if (length(regions) == 0L) {
    return(list())
  }
  split(regions, ceiling(seq_along(regions) / regions_per_page))
}

paginate_outcome_regions <- function(model_data, outcome, regions,
                                     regions_per_page = 6L) {
  require_columns(model_data, c("region", "outcome"), "Comparison data")
  outcome_regions <- unique(as.character(
    model_data$region[as.character(model_data$outcome) == outcome]
  ))
  ordered_regions <- as.character(regions)
  ordered_regions <- ordered_regions[ordered_regions %in% outcome_regions]
  paginate_regions(
    ordered_regions,
    regions_per_page = regions_per_page
  )
}

wrap_subarea_facet_label <- function(value, width = 36L) {
  width <- as.integer(width)
  if (length(width) != 1L || is.na(width) || width < 1L) {
    stop("width must be a positive integer.", call. = FALSE)
  }
  vapply(as.character(value), function(label) {
    if (is.na(label) || !nzchar(label)) {
      return(label)
    }
    paste(strwrap(label, width = width), collapse = "\n")
  }, character(1), USE.NAMES = FALSE)
}

blank_unused_facet_slots <- function(plot_grob, used_slots,
                                     panel_slots = 6L, ncol = 2L) {
  used_slots <- as.integer(used_slots)
  panel_slots <- as.integer(panel_slots)
  ncol <- as.integer(ncol)
  if (anyNA(c(used_slots, panel_slots, ncol)) || panel_slots < 1L ||
      ncol < 1L || used_slots < 0L || used_slots > panel_slots) {
    stop("Invalid facet-slot counts.", call. = FALSE)
  }
  if (used_slots == panel_slots) {
    return(plot_grob)
  }

  blank_slots <- seq.int(used_slots + 1L, panel_slots)
  blank_names <- unlist(lapply(blank_slots, function(slot) {
    panel_row <- ceiling(slot / ncol)
    panel_column <- ((slot - 1L) %% ncol) + 1L
    c(
      sprintf("panel-%d-%d", panel_column, panel_row),
      sprintf("strip-t-%d-%d", panel_column, panel_row),
      sprintf("strip-b-%d-%d", panel_column, panel_row),
      sprintf("axis-t-%d-%d", panel_column, panel_row),
      sprintf("axis-b-%d-%d", panel_column, panel_row),
      sprintf("axis-l-%d-%d", panel_row, panel_column),
      sprintf("axis-r-%d-%d", panel_row, panel_column)
    )
  }), use.names = FALSE)
  blank_indices <- which(plot_grob$layout$name %in% blank_names)
  plot_grob$grobs[blank_indices] <- lapply(
    blank_indices,
    function(index) grid::nullGrob()
  )
  plot_grob
}

draw_comparison_grob <- function(plot_grob, page_index) {
  page_index <- as.integer(page_index)
  if (length(page_index) != 1L || is.na(page_index) || page_index < 0L) {
    stop("page_index must be a non-negative integer.", call. = FALSE)
  }
  if (page_index > 0L) {
    grid::grid.newpage()
  }
  grid::grid.draw(plot_grob)
  page_index + 1L
}

write_comparison_grobs_pdf <- function(plot_grobs, output_pdf,
                                       page_size = a4_portrait_inches()) {
  if (!requireNamespace("qpdf", quietly = TRUE)) {
    stop("Package 'qpdf' is required to assemble comparison pages.",
         call. = FALSE)
  }
  if (!is.list(plot_grobs) || length(plot_grobs) < 1L) {
    stop("plot_grobs must be a non-empty list.", call. = FALSE)
  }
  page_size <- as.numeric(page_size)
  if (length(page_size) != 2L || any(!is.finite(page_size)) ||
      any(page_size <= 0)) {
    stop("page_size must contain positive finite width and height.",
         call. = FALSE)
  }

  dir.create(dirname(output_pdf), recursive = TRUE, showWarnings = FALSE)
  page_dir <- tempfile(
    pattern = ".comparison_pages_",
    tmpdir = dirname(output_pdf)
  )
  dir.create(page_dir, recursive = TRUE, showWarnings = FALSE)
  temporary_output <- tempfile(
    pattern = ".comparison_pdf_",
    tmpdir = dirname(output_pdf),
    fileext = ".pdf"
  )
  on.exit({
    unlink(page_dir, recursive = TRUE)
    unlink(temporary_output)
  }, add = TRUE)

  page_files <- file.path(
    page_dir,
    sprintf("page_%03d.pdf", seq_along(plot_grobs))
  )
  for (index in seq_along(plot_grobs)) {
    grDevices::pdf(
      page_files[[index]],
      width = page_size[[1]],
      height = page_size[[2]],
      onefile = TRUE,
      useDingbats = FALSE
    )
    device_open <- TRUE
    tryCatch(
      {
        grid::grid.newpage()
        grid::grid.draw(plot_grobs[[index]])
      },
      finally = {
        if (isTRUE(device_open)) {
          grDevices::dev.off()
          device_open <- FALSE
        }
      }
    )
  }

  qpdf::pdf_combine(page_files, output = temporary_output)
  copied <- suppressWarnings(file.copy(
    temporary_output, output_pdf, overwrite = TRUE
  ))
  if (!isTRUE(copied)) {
    stop("Could not write the comparison PDF: ", output_pdf,
         call. = FALSE)
  }
  normalizePath(output_pdf, winslash = "/", mustWork = TRUE)
}

resolve_previous_final_workbook <- function(
    explicit_path = Sys.getenv("PREVIOUS_FINAL_ESTIMATES_XLSX", unset = ""),
    user_profile = Sys.getenv("USERPROFILE", unset = "")) {
  default_path <- if (nzchar(user_profile)) {
    file.path(
      user_profile, "Dropbox", "UNICEF Work", "Data and charts for websites",
      "Files 2022", "CME", "Estimates",
      "Subnational_estimates_2023-08-15.xlsx"
    )
  } else {
    ""
  }
  candidates <- unique(c(explicit_path, default_path))
  candidates <- candidates[!is.na(candidates) & nzchar(trimws(candidates))]
  matches <- candidates[file.exists(candidates)]
  if (length(matches) == 0L) {
    stop(
      "Cannot find the previous final-estimates workbook. Set ",
      "PREVIOUS_FINAL_ESTIMATES_XLSX to the all-country workbook.",
      call. = FALSE
    )
  }
  normalizePath(matches[[1]], winslash = "/", mustWork = TRUE)
}

combine_country_summary_pdfs <- function(core_summary_pdf, comparison_pdf,
                                         output_summary_pdf,
                                         copy_file = file.copy) {
  if (!requireNamespace("qpdf", quietly = TRUE)) {
    stop("Package 'qpdf' is required to assemble the country summary PDF.",
         call. = FALSE)
  }
  inputs <- c(core_summary_pdf, comparison_pdf)
  missing_inputs <- inputs[!file.exists(inputs)]
  if (length(missing_inputs) > 0L) {
    stop("Missing PDF input(s): ", paste(missing_inputs, collapse = ", "),
         call. = FALSE)
  }
  normalized_core <- normalizePath(
    core_summary_pdf, winslash = "/", mustWork = TRUE
  )
  normalized_output <- normalizePath(
    output_summary_pdf, winslash = "/", mustWork = FALSE
  )
  if (identical(tolower(normalized_core), tolower(normalized_output))) {
    stop("The core and public country-summary PDF paths must differ.",
         call. = FALSE)
  }

  dir.create(dirname(output_summary_pdf), recursive = TRUE,
             showWarnings = FALSE)
  temporary_output <- tempfile(
    pattern = ".country_summary_",
    tmpdir = dirname(output_summary_pdf),
    fileext = ".pdf"
  )
  on.exit(unlink(temporary_output), add = TRUE)
  qpdf::pdf_combine(inputs, output = temporary_output)
  copied <- suppressWarnings(copy_file(
    temporary_output, output_summary_pdf, overwrite = TRUE
  ))
  if (!isTRUE(copied)) {
    fallback_summary_pdf <- if (grepl("\\.pdf$", output_summary_pdf,
                                      ignore.case = TRUE)) {
      sub("\\.pdf$", "_with_comparison.pdf", output_summary_pdf,
          ignore.case = TRUE)
    } else {
      paste0(output_summary_pdf, "_with_comparison.pdf")
    }
    fallback_copied <- suppressWarnings(copy_file(
      temporary_output, fallback_summary_pdf, overwrite = TRUE
    ))
    if (!isTRUE(fallback_copied)) {
      stop("Could not write the assembled country summary: ",
           output_summary_pdf, call. = FALSE)
    }
    warning(
      "The standard country summary is open and could not be replaced. ",
      "Saved the assembled summary to: ", fallback_summary_pdf,
      call. = FALSE
    )
    return(normalizePath(
      fallback_summary_pdf, winslash = "/", mustWork = TRUE
    ))
  }
  normalizePath(output_summary_pdf, winslash = "/", mustWork = TRUE)
}

run_country_summary_comparison_appendix <- function(
    country,
    iso3,
    previous_workbook,
    core_summary_pdf,
    output_summary_pdf,
    home_dir = getwd(),
    res_dir = file.path(home_dir, "Results", country),
    regions_per_page = 6L,
    strata_model = "unstrat",
    benchmarked = TRUE,
    all_surveys = identical(strata_model, "unstrat"),
    admin_levels = "Admin1",
    current_label = "2026 CC",
    previous_label = "2023 final",
    force_current_only = FALSE) {
  build_parent <- file.path(res_dir, "Figures")
  dir.create(build_parent, recursive = TRUE, showWarnings = FALSE)
  build_output_dir <- tempfile(
    pattern = ".country_summary_appendix_build_",
    tmpdir = tempdir()
  )
  dir.create(build_output_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(build_output_dir, recursive = TRUE, force = TRUE), add = TRUE)

  comparison_args <- list(
    country = country,
    iso3 = iso3,
    previous_workbook = previous_workbook,
    home_dir = home_dir,
    res_dir = res_dir,
    regions_per_page = regions_per_page,
    strata_model = strata_model,
    benchmarked = benchmarked,
    all_surveys = all_surveys,
    admin_levels = admin_levels,
    current_label = current_label,
    previous_label = previous_label,
    force_current_only = force_current_only,
    output_dir = build_output_dir
  )
  skipped_reason <- ""
  comparison <- tryCatch(
    do.call(run_previous_final_comparison, comparison_args),
    previous_final_unmatched_regions = function(error) {
      skipped_reason <<- conditionMessage(error)
      warning(
        "Skipping previous-final comparison for ", country, ": ",
        skipped_reason, "; generating current-only sub-area plots.",
        call. = FALSE
      )
      comparison_args$force_current_only <- TRUE
      do.call(run_previous_final_comparison, comparison_args)
    }
  )
  comparison$previous_final_skipped_reason <- skipped_reason
  comparison_mode <- if (
    !is.null(comparison$mode) &&
      identical(comparison$mode, "current_only")
  ) {
    "current_only"
  } else {
    "previous_final"
  }
  comparison$mode <- comparison_mode
  comparison$status <- if (identical(comparison_mode, "current_only")) {
    "appended_current_only"
  } else {
    "appended_previous_final"
  }
  summary_pdf <- combine_country_summary_pdfs(
    core_summary_pdf = core_summary_pdf,
    comparison_pdf = comparison$pdf,
    output_summary_pdf = output_summary_pdf
  )

  standard_output_dir <- file.path(
    res_dir, "Figures",
    if (identical(comparison_mode, "current_only")) {
      "CurrentSubarea"
    } else {
      "PreviousFinalComparison"
    }
  )
  dir.create(standard_output_dir, recursive = TRUE, showWarnings = FALSE)
  publish_artifact <- function(source_path) {
    target_path <- file.path(standard_output_dir, basename(source_path))
    copied <- suppressWarnings(file.copy(
      source_path, target_path, overwrite = TRUE
    ))
    if (!isTRUE(copied)) {
      if (!file.exists(target_path)) {
        stop("Could not publish country-summary appendix artifact: ",
             target_path,
             call. = FALSE)
      }
      warning(
        "Could not replace the open appendix artifact; the country summary ",
        "uses the fresh temporary build: ", target_path,
        call. = FALSE
      )
    }
    normalizePath(target_path, winslash = "/", mustWork = TRUE)
  }
  comparison$pdf <- publish_artifact(comparison$pdf)
  comparison$data <- publish_artifact(comparison$data)
  status_path <- file.path(build_output_dir, paste0(country, "_appendix_status.csv"))
  utils::write.csv(data.frame(
    country = country, mode = comparison_mode,
    previous_final_skipped_reason = skipped_reason,
    stringsAsFactors = FALSE
  ), status_path, row.names = FALSE)
  comparison$status_file <- publish_artifact(status_path)
  comparison$summary_pdf <- summary_pdf
  comparison$core_summary_pdf <- normalizePath(
    core_summary_pdf, winslash = "/", mustWork = TRUE
  )
  invisible(comparison)
}

require_columns <- function(data, columns, label) {
  missing_columns <- setdiff(columns, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      label, " is missing required column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
}

load_country_survey_lookup <- function(home_dir, country) {
  cluster_path <- file.path(
    home_dir, "Data", "Countries", country,
    paste0(country, "_cluster_dat.rda")
  )
  cluster_data <- load_first_rda_object(cluster_path)
  if (!is.data.frame(cluster_data)) {
    stop("Country cluster-data object is not a data frame: ", cluster_path,
         call. = FALSE)
  }
  require_columns(
    cluster_data,
    c("survey", "survey.type"),
    "Country cluster data"
  )
  lookup <- unique(data.frame(
    survey_year = as.numeric(as.character(cluster_data$survey)),
    survey_type = as.character(cluster_data$survey.type),
    stringsAsFactors = FALSE
  ))
  lookup <- lookup[
    !is.na(lookup$survey_year) & !is.na(lookup$survey_type) &
      nzchar(trimws(lookup$survey_type)),
    , drop = FALSE
  ]
  lookup[order(lookup$survey_year, lookup$survey_type), , drop = FALSE]
}

normalize_utf8_text <- function(labels) {
  labels <- as.character(labels)
  invalid_utf8 <- !is.na(labels) & !validUTF8(labels)
  labels[invalid_utf8] <- iconv(
    labels[invalid_utf8],
    from = "latin1",
    to = "UTF-8",
    sub = "byte"
  )
  enc2utf8(labels)
}

normalize_region_name_key <- function(labels) {
  labels <- normalize_utf8_text(labels)
  transliterated <- iconv(labels, from = "", to = "ASCII//TRANSLIT")
  transliterated[is.na(transliterated)] <- labels[is.na(transliterated)]
  tolower(gsub("[^[:alnum:]]", "", transliterated, perl = TRUE))
}

previous_final_crosswalk_path <- function(home_dir, country) {
  file.path(
    home_dir,
    "Info",
    "PreviousFinalRegionCrosswalks",
    paste0(country, "_2023_to_2026.csv")
  )
}

validate_previous_final_region_crosswalk <- function(
    crosswalk,
    admin_level = "Admin1") {
  admin_level <- normalize_admin_level(admin_level)
  require_columns(
    crosswalk,
    c(
      "admin_level", "previous_internal", "previous_name",
      "current_internal", "current_name"
    ),
    "Previous-final region crosswalk"
  )
  crosswalk <- as.data.frame(crosswalk, stringsAsFactors = FALSE)
  crosswalk <- crosswalk[
    as.character(crosswalk$admin_level) == admin_level,
    , drop = FALSE
  ]
  if (nrow(crosswalk) == 0L) {
    stop(
      "Previous-final region crosswalk has no ",
      sub("^Admin", "Admin-", admin_level), " rows.",
      call. = FALSE
    )
  }
  text_columns <- c(
    "previous_internal", "previous_name", "current_internal", "current_name"
  )
  for (column in text_columns) {
    crosswalk[[column]] <- trimws(as.character(crosswalk[[column]]))
    if (any(is.na(crosswalk[[column]]) | !nzchar(crosswalk[[column]]))) {
      stop(
        "Previous-final region crosswalk has missing values in ", column, ".",
        call. = FALSE
      )
    }
  }
  previous_key <- paste(
    crosswalk$previous_internal,
    normalize_region_name_key(crosswalk$previous_name),
    sep = "\r"
  )
  if (anyDuplicated(previous_key)) {
    stop(
      "Previous-final region crosswalk has duplicate previous-region keys.",
      call. = FALSE
    )
  }
  if (anyDuplicated(crosswalk$current_internal)) {
    stop(
      "Previous-final region crosswalk maps multiple previous regions to the ",
      "same current region.",
      call. = FALSE
    )
  }
  crosswalk
}

load_previous_final_region_crosswalk <- function(
    home_dir,
    country,
    admin_level = "Admin1") {
  path <- previous_final_crosswalk_path(home_dir, country)
  if (!file.exists(path)) {
    return(NULL)
  }
  validate_previous_final_region_crosswalk(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    admin_level = admin_level
  )
}

map_previous_final_regions <- function(
    previous,
    current_lookup,
    crosswalk = NULL,
    admin_level = "Admin1") {
  admin_level <- normalize_admin_level(admin_level)
  admin_label <- sub("^Admin", "Admin-", admin_level)
  require_columns(
    previous,
    c("region", "region_name"),
    "Previous-final comparison data"
  )
  require_columns(
    current_lookup,
    c("region", "region_name"),
    "Current Admin-region lookup"
  )
  if (nrow(previous) == 0L) {
    return(previous)
  }
  if (nrow(current_lookup) == 0L || anyDuplicated(current_lookup$region)) {
    stop("Current ", admin_label, " lookup is empty or ambiguous.",
         call. = FALSE)
  }

  if (!is.null(crosswalk)) {
    crosswalk <- validate_previous_final_region_crosswalk(
      crosswalk,
      admin_level = admin_level
    )
    previous_key <- paste(
      as.character(previous$region),
      normalize_region_name_key(previous$region_name),
      sep = "\r"
    )
    crosswalk_key <- paste(
      crosswalk$previous_internal,
      normalize_region_name_key(crosswalk$previous_name),
      sep = "\r"
    )
    matched <- match(previous_key, crosswalk_key)
    mapped_region <- crosswalk$current_internal[matched]
  } else {
    current_name_key <- normalize_region_name_key(current_lookup$region_name)
    if (anyDuplicated(current_name_key)) {
      stop(
        "Current ", admin_label,
        " display names are ambiguous after normalization.",
        call. = FALSE
      )
    }
    matched <- match(
      normalize_region_name_key(previous$region_name),
      current_name_key
    )
    mapped_region <- as.character(current_lookup$region[matched])
  }

  unmatched <- is.na(mapped_region) | !nzchar(mapped_region)
  if (any(unmatched)) {
    unmatched_labels <- unique(paste0(
      as.character(previous$region[unmatched]),
      " (", as.character(previous$region_name[unmatched]), ")"
    ))
    stop(structure(list(
      message = paste0("Unmatched previous-final ", admin_label, " region(s): ",
                       paste(unmatched_labels, collapse = ", ")),
      call = NULL
    ), class = c("previous_final_unmatched_regions", "error", "condition")))
  }
  unknown_target <- !mapped_region %in% as.character(current_lookup$region)
  if (any(unknown_target)) {
    stop(
      "Previous-final region crosswalk targets unknown current ", admin_label,
      " region(s): ",
      paste(unique(mapped_region[unknown_target]), collapse = ", "),
      call. = FALSE
    )
  }

  previous$region <- mapped_region
  apply_region_lookup(previous, current_lookup)
}

load_country_admin_lookup <- function(home_dir, country, admin_level) {
  admin_level <- normalize_admin_level(admin_level)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to load country Admin names.",
         call. = FALSE)
  }
  info_path <- file.path(
    home_dir, "Info", paste0(country, "_general_info.json")
  )
  if (!file.exists(info_path)) {
    stop("Country Info JSON does not exist: ", info_path, call. = FALSE)
  }
  info <- jsonlite::fromJSON(info_path, simplifyVector = TRUE)
  poly_path <- gsub("\\\\", "/", as.character(info$poly.path))
  if (length(poly_path) != 1L || is.na(poly_path) || !nzchar(poly_path)) {
    stop("Country Info JSON has no usable poly.path: ", info_path,
         call. = FALSE)
  }
  is_absolute <- grepl("^[A-Za-z]:/|^/|^//", poly_path)
  resolved_poly_path <- if (is_absolute) {
    poly_path
  } else if (grepl("^\\.\\./", poly_path)) {
    file.path(home_dir, "Data", sub("^\\.\\./", "", poly_path))
  } else {
    file.path(home_dir, "Data", "Countries", country, poly_path)
  }
  names_path <- file.path(
    resolved_poly_path, paste0(country, "_Amat_Names.rda")
  )
  if (!file.exists(names_path)) {
    stop("Country Admin-name mapping does not exist: ", names_path,
         call. = FALSE)
  }
  env <- new.env(parent = emptyenv())
  load(names_path, envir = env)
  object_name <- if (admin_level == "Admin1") {
    "admin1.names"
  } else {
    "admin2.names"
  }
  if (!exists(object_name, envir = env, inherits = FALSE)) {
    stop("Admin-name mapping is missing object ", object_name, ": ",
         names_path, call. = FALSE)
  }
  names_data <- get(object_name, envir = env, inherits = FALSE)
  require_columns(names_data, c("Internal", "GeoRepo"), object_name)
  region_names <- apply_report_admin_name_map(
    normalize_utf8_text(names_data$GeoRepo),
    info$report_admin_name_map
  )
  data.frame(
    region = as.character(names_data$Internal),
    region_name = region_names,
    stringsAsFactors = FALSE
  )
}

apply_region_lookup <- function(data, region_lookup) {
  require_columns(data, "region", "Comparison data")
  require_columns(
    region_lookup,
    c("region", "region_name"),
    "Admin-region lookup"
  )
  if (!"region_name" %in% names(data)) {
    data$region_name <- NA_character_
  }
  matched <- match(data$region, region_lookup$region)
  canonical_name <- as.character(region_lookup$region_name[matched])
  has_canonical_name <- !is.na(canonical_name) &
    nzchar(trimws(canonical_name))
  data$region_name[has_canonical_name] <- canonical_name[has_canonical_name]
  missing_name <- is.na(data$region_name) | !nzchar(trimws(data$region_name))
  data$region_name[missing_name] <- data$region[missing_name]
  data
}

prepare_previous_final_estimates <- function(data, iso3,
                                             source_label = "2023 final",
                                             admin_level = "Admin1") {
  admin_level <- normalize_admin_level(admin_level)
  required <- c(
    "Country.Code", "Admin.Level", "GADM.Region", "Internal",
    "Shortind", "Sex", "Year", "Median", "Lower", "Upper"
  )
  require_columns(data, required, "Previous final-estimates workbook")

  keep <- toupper(as.character(data[["Country.Code"]])) == toupper(iso3) &
    as.character(data[["Admin.Level"]]) == admin_level &
    toupper(as.character(data[["Shortind"]])) %in% c("NMR", "U5MR") &
    toupper(as.character(data[["Sex"]])) == "TOTAL"
  selected <- data[keep, , drop = FALSE]
  if (nrow(selected) == 0L) {
    admin_label <- sub("^Admin", "Admin-", admin_level)
    stop("No ", admin_label, " NMR/U5MR rows found for ", iso3, ".",
         call. = FALSE)
  }

  region_name <- as.character(selected[["GADM.Region"]])
  if (admin_level == "Admin1" && "Admin1.Region" %in% names(selected)) {
    fallback <- as.character(selected[["Admin1.Region"]])
    use_fallback <- is.na(region_name) | !nzchar(trimws(region_name))
    region_name[use_fallback] <- fallback[use_fallback]
  }
  use_internal <- is.na(region_name) | !nzchar(trimws(region_name))
  region_name[use_internal] <- as.character(selected[["Internal"]])[use_internal]

  output <- data.frame(
    admin_level = admin_level,
    region = as.character(selected[["Internal"]]),
    region_name = region_name,
    outcome = toupper(as.character(selected[["Shortind"]])),
    years = floor(as.numeric(selected[["Year"]])) + 0.5,
    median = as.numeric(selected[["Median"]]),
    lower = as.numeric(selected[["Lower"]]),
    upper = as.numeric(selected[["Upper"]]),
    survey_year = NA_real_,
    survey_id = NA_character_,
    survey_type = NA_character_,
    survey_series = NA_character_,
    source = source_label,
    stringsAsFactors = FALSE
  )
  output[!is.na(output$region) & nzchar(output$region) &
           !is.na(output$years) & !is.na(output$median), , drop = FALSE]
}

prepare_current_estimates <- function(result, outcome,
                                      source_label = "2026 CC") {
  estimates <- if (is.data.frame(result)) result else result$overall
  if (is.null(estimates)) {
    stop("Current result object does not contain an overall estimate table.",
         call. = FALSE)
  }
  required <- c("region", "median", "lower", "upper")
  require_columns(estimates, required, "Current result object")
  year_column <- if ("years" %in% names(estimates)) "years" else "years.num"
  require_columns(estimates, year_column, "Current result object")
  row_count <- nrow(estimates)

  output <- data.frame(
    region = as.character(estimates$region),
    outcome = rep(toupper(outcome), row_count),
    years = floor(as.numeric(as.character(estimates[[year_column]]))) + 0.5,
    median = as.numeric(estimates$median) * 1000,
    lower = as.numeric(estimates$lower) * 1000,
    upper = as.numeric(estimates$upper) * 1000,
    survey_year = rep(NA_real_, row_count),
    survey_id = rep(NA_character_, row_count),
    survey_type = rep(NA_character_, row_count),
    survey_series = rep(NA_character_, row_count),
    source = rep(source_label, row_count),
    stringsAsFactors = FALSE
  )
  output[output$region != "All" & !is.na(output$years) &
           !is.na(output$median), , drop = FALSE]
}

prepare_direct_estimates <- function(data, outcome,
                                     source_label = "Survey direct",
                                     survey_lookup = NULL) {
  required <- c("region", "years", "mean", "lower", "upper", "surveyYears")
  require_columns(data, required, "Direct-estimate object")
  uncertainty <- if (all(c("logit.est", "var.est") %in% names(data))) {
    direct_standard_error_bounds(data)
  } else {
    data.frame(
      se_logit = rep(NA_real_, nrow(data)),
      lower_1se = rep(NA_real_, nrow(data)),
      upper_1se = rep(NA_real_, nrow(data)),
      se_probability = rep(NA_real_, nrow(data))
    )
  }

  survey_year <- as.numeric(data$surveyYears)
  survey_type <- rep("Survey", nrow(data))
  if (!is.null(survey_lookup)) {
    require_columns(
      survey_lookup,
      c("survey_year", "survey_type"),
      "Survey-series lookup"
    )
    matched <- match(survey_year, as.numeric(survey_lookup$survey_year))
    matched_type <- as.character(survey_lookup$survey_type[matched])
    has_type <- !is.na(matched_type) & nzchar(trimws(matched_type))
    survey_type[has_type] <- matched_type[has_type]
  }

  output <- data.frame(
    region = as.character(data$region),
    outcome = toupper(outcome),
    years = period_midpoint(data$years),
    median = as.numeric(data$mean) * 1000,
    lower = as.numeric(data$lower) * 1000,
    upper = as.numeric(data$upper) * 1000,
    se_logit = uncertainty$se_logit,
    lower_1se = uncertainty$lower_1se * 1000,
    upper_1se = uncertainty$upper_1se * 1000,
    survey_year = survey_year,
    survey_id = if ("survey" %in% names(data)) {
      as.character(data$survey)
    } else {
      NA_character_
    },
    survey_type = survey_type,
    survey_series = paste(survey_type, survey_year),
    source = source_label,
    stringsAsFactors = FALSE
  )
  output[output$region != "All" & !is.na(output$years) &
           !is.na(output$median), , drop = FALSE]
}

load_first_rda_object <- function(path) {
  if (!file.exists(path)) {
    stop("Required R data file does not exist: ", path, call. = FALSE)
  }
  env <- new.env(parent = emptyenv())
  object_names <- load(path, envir = env)
  if (length(object_names) == 0L) {
    stop("No R objects found in: ", path, call. = FALSE)
  }
  get(object_names[[1]], envir = env)
}

admin_region_order <- function(regions) {
  regions <- unique(as.character(regions))
  suffix <- suppressWarnings(as.integer(sub("^.*_", "", regions)))
  regions[order(is.na(suffix), suffix, regions)]
}

current_admin_result_path <- function(res_dir, country, outcome, admin_level,
                                      strata_model = "unstrat",
                                      benchmarked = TRUE,
                                      all_surveys = identical(strata_model,
                                                              "unstrat")) {
  admin_level <- normalize_admin_level(admin_level)
  outcome <- toupper(outcome)
  outcome_dir <- if (outcome == "U5MR") "U5MR" else "NMR"
  short_name <- if (outcome == "U5MR") "u5" else "nmr"
  admin_token <- if (admin_level == "Admin1") "adm1" else "adm2"
  file_name <- paste0(
    country, "_res_", admin_token, "_", strata_model, "_", short_name,
    if (isTRUE(all_surveys)) "_allsurveys" else "",
    if (isTRUE(benchmarked)) "_bench" else "",
    ".rda"
  )
  result_path <- file.path(
    res_dir, "Betabinomial", outcome_dir, file_name
  )
  if (outcome == "U5MR" &&
      exists("select_crisis_result_file", mode = "function", inherits = TRUE)) {
    result_path <- select_crisis_result_file(result_path)
  }
  result_path
}

direct_admin_result_path <- function(res_dir, country, outcome, admin_level) {
  admin_level <- normalize_admin_level(admin_level)
  outcome <- toupper(outcome)
  outcome_dir <- if (outcome == "U5MR") "U5MR" else "NMR"
  short_name <- if (outcome == "U5MR") "u5" else "nmr"
  file.path(
    res_dir, "Direct", outcome_dir,
    paste0(country, "_direct_", tolower(admin_level), "_", short_name,
           ".rda")
  )
}

current_admin1_result_path <- function(res_dir, country, outcome,
                                       strata_model = "unstrat",
                                       benchmarked = TRUE,
                                       all_surveys = identical(strata_model,
                                                               "unstrat")) {
  current_admin_result_path(
    res_dir = res_dir,
    country = country,
    outcome = outcome,
    admin_level = "Admin1",
    strata_model = strata_model,
    benchmarked = benchmarked,
    all_surveys = all_surveys
  )
}

direct_admin1_result_path <- function(res_dir, country, outcome) {
  direct_admin_result_path(
    res_dir = res_dir,
    country = country,
    outcome = outcome,
    admin_level = "Admin1"
  )
}

build_previous_final_page <- function(model_data, direct_data, outcome,
                                      regions, country, page_number,
                                      page_count, current_label,
                                      previous_label, admin_level = "Admin1",
                                      panel_slots = 6L) {
  admin_level <- normalize_admin_level(admin_level)
  country_display <- gsub("_", " ", country, fixed = TRUE)
  model_page <- model_data[
    model_data$outcome == outcome & model_data$region %in% regions,
    , drop = FALSE
  ]
  direct_page <- direct_data[
    direct_data$outcome == outcome & direct_data$region %in% regions,
    , drop = FALSE
  ]
  levels_on_page <- unique(model_page$region_name[match(regions,
                                                        model_page$region)])
  levels_on_page <- levels_on_page[!is.na(levels_on_page)]
  panel_slots <- max(as.integer(panel_slots), length(levels_on_page))
  blank_count <- panel_slots - length(levels_on_page)
  blank_levels <- if (blank_count > 0L) {
    paste0(".blank_panel_", seq_len(blank_count))
  } else {
    character()
  }
  facet_levels <- c(levels_on_page, blank_levels)
  facet_labels <- stats::setNames(
    c(wrap_subarea_facet_label(levels_on_page), rep("", blank_count)),
    facet_levels
  )
  model_page$region_name <- factor(model_page$region_name,
                                   levels = facet_levels)
  direct_page$region_name <- factor(direct_page$region_name,
                                    levels = facet_levels)
  direct_line_page <- direct_page[0, , drop = FALSE]
  valid_direct_points <- which(
    is.finite(direct_page$years) &
      is.finite(direct_page$median) &
      !is.na(direct_page$region) &
      !is.na(direct_page$survey_series)
  )
  if (length(valid_direct_points) > 0L) {
    direct_line_candidates <- direct_page[
      valid_direct_points, , drop = FALSE
    ]
    direct_line_groups <- interaction(
      direct_line_candidates$region,
      direct_line_candidates$survey_series,
      drop = TRUE
    )
    direct_line_counts <- ave(
      rep(1L, nrow(direct_line_candidates)),
      direct_line_groups,
      FUN = sum
    )
    direct_line_page <- direct_line_candidates[
      direct_line_counts >= 2L, , drop = FALSE
    ]
  }

  has_previous <- previous_label %in% unique(as.character(model_page$source))
  model_labels <- c(
    current_label,
    if (isTRUE(has_previous)) previous_label else character()
  )
  series_colors <- stats::setNames(
    c("#D62728", "#0072B2")[seq_along(model_labels)],
    model_labels
  )
  series_types <- stats::setNames(rep("solid", length(model_labels)),
                                  model_labels)
  direct_series <- sort(unique(as.character(direct_page$survey_series)))
  direct_series <- direct_series[!is.na(direct_series) & nzchar(direct_series)]
  direct_palette <- c(
    "#009E73", "#E69F00", "#CC79A7", "#56B4E9",
    "#8C564B", "#7F7F7F", "#D55E00", "#F0E442"
  )
  if (length(direct_series) > length(direct_palette)) {
    direct_palette <- grDevices::hcl.colors(length(direct_series), "Dark 3")
  }
  direct_colors <- stats::setNames(
    direct_palette[seq_along(direct_series)],
    direct_series
  )
  direct_types <- stats::setNames(
    rep("dotted", length(direct_series)),
    direct_series
  )
  legend_colors <- c(series_colors, direct_colors)
  legend_types <- c(series_types, direct_types)

  ggplot2::ggplot() +
    ggplot2::geom_ribbon(
      data = model_page,
      ggplot2::aes(
        x = years, ymin = lower, ymax = upper,
        fill = source, group = source
      ),
      alpha = 0.12,
      color = NA,
      show.legend = FALSE
    ) +
    ggplot2::geom_line(
      data = model_page,
      ggplot2::aes(
        x = years, y = median, color = source,
        linetype = source, group = source
      ),
      linewidth = 0.9
    ) +
    ggplot2::geom_line(
      data = direct_line_page,
      ggplot2::aes(
        x = years, y = median, color = survey_series,
        linetype = survey_series, group = survey_series
      ),
      linewidth = 0.45,
      alpha = 0.75,
      na.rm = TRUE
    ) +
    ggplot2::geom_errorbar(
      data = direct_page,
      ggplot2::aes(
        x = years, ymin = lower_1se, ymax = upper_1se,
        color = survey_series
      ),
      width = 0.18,
      linewidth = 0.35,
      alpha = 0.75,
      show.legend = FALSE,
      na.rm = TRUE
    ) +
    ggplot2::geom_point(
      data = direct_page,
      ggplot2::aes(x = years, y = median, color = survey_series),
      shape = 17,
      size = 1.45,
      stroke = 0.4,
      alpha = 0.9,
      na.rm = TRUE
    ) +
    ggplot2::facet_wrap(
      ggplot2::vars(region_name),
      ncol = 2,
      nrow = ceiling(panel_slots / 2),
      scales = "free_y",
      drop = FALSE,
      labeller = ggplot2::as_labeller(facet_labels)
    ) +
    ggplot2::scale_color_manual(values = legend_colors, name = NULL) +
    ggplot2::scale_fill_manual(values = series_colors) +
    ggplot2::scale_linetype_manual(values = legend_types, name = NULL) +
    ggplot2::scale_x_continuous(breaks = seq(2000, 2030, by = 5)) +
    ggplot2::expand_limits(y = 0) +
    ggplot2::labs(
      title = if (isTRUE(has_previous)) {
        paste0(
          country_display, " ", sub("^Admin", "Admin-", admin_level), " ",
          outcome, ": ", current_label, " vs ", previous_label
        )
      } else {
        paste0(
          country_display, " ", sub("^Admin", "Admin-", admin_level), " ",
          outcome, ": ", current_label, " sub-area trends"
        )
      },
      subtitle = paste(
        strwrap(
          paste0(
            if (isTRUE(has_previous)) {
              "Lines and ribbons: final estimates and reported intervals; "
            } else {
              "Line and ribbon: current final estimate and reported interval; "
            },
            "colored triangles and lines: survey direct series with +/- 1 SE ",
            "bars. Page ",
            page_number, " of ", page_count, "."
          ),
          width = 105
        ),
        collapse = "\n"
      ),
      x = "Year",
      y = paste0(outcome, " deaths per 1,000 live births")
    ) +
    ggplot2::guides(
      color = ggplot2::guide_legend(order = 1),
      linetype = "none"
    ) +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      legend.position = "bottom",
      legend.box = "horizontal",
      panel.border = ggplot2::element_rect(
        color = "grey75", fill = NA, linewidth = 0.35
      ),
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", size = 9),
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(size = 9),
      plot.margin = ggplot2::margin(8, 10, 8, 8)
    )
}

run_previous_final_comparison <- function(
    country,
    iso3,
    previous_workbook,
    home_dir = getwd(),
    res_dir = file.path(home_dir, "Results", country),
    regions_per_page = 6L,
    strata_model = "unstrat",
    benchmarked = TRUE,
    all_surveys = identical(strata_model, "unstrat"),
    current_label = "2026 CC",
    previous_label = "2023 final",
    admin_levels = "Admin1",
    force_current_only = FALSE,
    output_dir = file.path(res_dir, "Figures", "PreviousFinalComparison")) {
  if (!isTRUE(force_current_only) &&
      !requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required for the prior final-estimates workbook.",
         call. = FALSE)
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to create the comparison PDF.",
         call. = FALSE)
  }
  if (!isTRUE(force_current_only) && !file.exists(previous_workbook)) {
    stop("Previous final-estimates workbook does not exist: ",
         previous_workbook, call. = FALSE)
  }
  survey_lookup <- load_country_survey_lookup(
    home_dir = home_dir,
    country = country
  )

  admin_levels <- unique(vapply(
    c("Admin1", admin_levels),
    normalize_admin_level,
    character(1)
  ))
  outcomes <- c("U5MR", "NMR")
  previous_by_level <- if (isTRUE(force_current_only)) {
    stats::setNames(vector("list", length(admin_levels)), admin_levels)
  } else {
    previous_raw <- readxl::read_excel(
      previous_workbook,
      sheet = 1,
      .name_repair = "minimal"
    )
    stats::setNames(
      lapply(admin_levels, function(admin_level) {
        tryCatch(
          prepare_previous_final_estimates(
            previous_raw,
            iso3 = iso3,
            source_label = previous_label,
            admin_level = admin_level
          ),
          error = function(error) {
            admin_label <- sub("^Admin", "Admin-", admin_level)
            expected <- paste0(
              "No ", admin_label, " NMR/U5MR rows found for ", iso3, "."
            )
            if (!identical(conditionMessage(error), expected)) {
              stop(error)
            }
            NULL
          }
        )
      }),
      admin_levels
    )
  }
  available_previous_levels <- admin_levels[vapply(
    previous_by_level,
    function(previous) !is.null(previous) && nrow(previous) > 0L,
    logical(1)
  )]
  mode <- if ("Admin1" %in% available_previous_levels) {
    "previous_final"
  } else {
    "current_only"
  }
  if (identical(mode, "current_only")) {
    message(
      if (isTRUE(force_current_only)) {
        "Previous-final comparison disabled for "
      } else {
        "No previous-final Admin-1 estimates exist for "
      }, iso3,
      "; generating current-only sub-area plots."
    )
  }

  level_data <- list()
  for (admin_level in admin_levels) {
    previous_available <- admin_level %in% available_previous_levels
    if (identical(mode, "previous_final") && !previous_available) {
      message("Skipping ", sub("^Admin", "Admin-", admin_level),
              ": no previous-final NMR/U5MR rows.")
      next
    }

    current_paths <- stats::setNames(lapply(outcomes, function(outcome) {
      current_admin_result_path(
        res_dir = res_dir,
        country = country,
        outcome = outcome,
        admin_level = admin_level,
        strata_model = strata_model,
        benchmarked = benchmarked,
        all_surveys = all_surveys
      )
    }), outcomes)
    missing_current_files <- unlist(current_paths)[
      !file.exists(unlist(current_paths))
    ]
    if (length(missing_current_files) > 0L) {
      if (admin_level == "Admin1") {
        stop(
          "Required Admin-1 result file(s) do not exist: ",
          paste(missing_current_files, collapse = ", "),
          call. = FALSE
        )
      }
      if (identical(mode, "previous_final") ||
          all(!file.exists(unlist(current_paths)))) {
        message(
          "Skipping ", sub("^Admin", "Admin-", admin_level),
          ": current result file(s) are unavailable: ",
          paste(basename(missing_current_files), collapse = ", ")
        )
        next
      }
      message(
        "Including available ", sub("^Admin", "Admin-", admin_level),
        " current-only outcome(s); unavailable file(s): ",
        paste(basename(missing_current_files), collapse = ", ")
      )
    }

    previous <- if (identical(mode, "previous_final")) {
      previous_by_level[[admin_level]]
    } else {
      data.frame(
        admin_level = character(),
        region = character(),
        region_name = character(),
        outcome = character(),
        years = numeric(),
        median = numeric(),
        lower = numeric(),
        upper = numeric(),
        survey_year = numeric(),
        survey_id = character(),
        survey_type = character(),
        survey_series = character(),
        source = character(),
        stringsAsFactors = FALSE
      )
    }
    available_outcomes <- outcomes[
      file.exists(unlist(current_paths, use.names = FALSE))
    ]
    current_rows <- list()
    direct_rows <- list()
    for (outcome in available_outcomes) {
      current_outcome <- prepare_current_estimates(
        load_first_rda_object(current_paths[[outcome]]),
        outcome = outcome,
        source_label = current_label
      )
      if (nrow(current_outcome) == 0L) {
        admin_label <- sub("^Admin", "Admin-", admin_level)
        if (admin_level == "Admin1") {
          stop(
            "Current ", admin_label, " result has no usable ", outcome,
            " rows: ", current_paths[[outcome]],
            call. = FALSE
          )
        }
        message(
          "Skipping ", admin_label, " ", outcome,
          ": the current result has no usable rows."
        )
        next
      }
      current_outcome$admin_level <- admin_level
      current_rows[[outcome]] <- current_outcome

      direct_path <- direct_admin_result_path(
        res_dir = res_dir,
        country = country,
        outcome = outcome,
        admin_level = admin_level
      )
      if (file.exists(direct_path)) {
        direct_rows[[outcome]] <- prepare_direct_estimates(
          load_first_rda_object(direct_path),
          outcome = outcome,
          survey_lookup = survey_lookup
        )
        direct_rows[[outcome]]$admin_level <- admin_level
      } else {
        warning(
          "Direct-series overlay is unavailable for ", admin_level, " ",
          outcome, ": ", direct_path,
          call. = FALSE
        )
      }
    }
    if (length(current_rows) == 0L) {
      message(
        "Skipping ", sub("^Admin", "Admin-", admin_level),
        ": no current outcomes contain usable rows."
      )
      next
    }
    current <- do.call(rbind, current_rows)
    direct <- if (length(direct_rows) > 0L) {
      do.call(rbind, direct_rows)
    } else {
      current[0, , drop = FALSE]
    }

    canonical_region_lookup <- tryCatch(
      load_country_admin_lookup(
        home_dir = home_dir,
        country = country,
        admin_level = admin_level
      ),
      error = function(err) {
        warning(
          "Could not load current ", admin_level, " display names: ",
          conditionMessage(err),
          call. = FALSE
        )
        data.frame(
          region = character(), region_name = character(),
          stringsAsFactors = FALSE
        )
      }
    )
    if (identical(mode, "previous_final")) {
      crosswalk <- if (admin_level == "Admin1") {
        load_previous_final_region_crosswalk(
          home_dir = home_dir,
          country = country,
          admin_level = admin_level
        )
      } else {
        NULL
      }
      previous <- map_previous_final_regions(
        previous = previous,
        current_lookup = canonical_region_lookup,
        crosswalk = crosswalk,
        admin_level = admin_level
      )
    }
    region_lookup <- canonical_region_lookup
    excluded_ids <- report_excluded_admin_ids(
      home_dir, country, as.integer(sub('Admin', '', admin_level))
    )
    current <- filter_report_admin_rows(current, excluded_ids)
    previous <- filter_report_admin_rows(previous, excluded_ids)
    direct <- filter_report_admin_rows(direct, excluded_ids)
    regions <- admin_region_order(unique(c(current$region, previous$region)))
    missing_current <- setdiff(regions, current$region)
    missing_previous <- setdiff(regions, previous$region)
    if (length(missing_current) > 0L) {
      warning(
        admin_level, " regions missing from current estimates: ",
        paste(missing_current, collapse = ", "), call. = FALSE
      )
    }
    if (identical(mode, "previous_final") &&
        length(missing_previous) > 0L) {
      warning(
        admin_level, " regions missing from previous final estimates: ",
        paste(missing_previous, collapse = ", "), call. = FALSE
      )
    }

    previous <- apply_region_lookup(previous, region_lookup)
    current <- apply_region_lookup(current, region_lookup)
    direct <- apply_region_lookup(direct, region_lookup)
    direct <- direct[direct$region %in% regions, , drop = FALSE]
    level_data[[admin_level]] <- list(
      model_data = rbind(current, previous),
      direct_data = direct,
      regions = regions,
      pages = paginate_regions(regions, regions_per_page = regions_per_page)
    )
  }
  if (length(level_data) == 0L) {
    stop("No administrative levels are available for the sub-area appendix.",
         call. = FALSE)
  }
  included_admin_levels <- names(level_data)

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  artifact_stem <- if (identical(mode, "current_only")) {
    paste0(country, "_admin_levels_current_subarea")
  } else {
    paste0(country, "_admin_levels_current_vs_2023_final")
  }
  output_pdf <- file.path(
    output_dir,
    paste0(artifact_stem, ".pdf")
  )
  output_csv <- file.path(
    output_dir,
    paste0(artifact_stem, "_data.csv")
  )

  export_columns <- c(
    "admin_level", "region", "region_name", "outcome", "years", "median",
    "lower", "upper", "survey_year", "survey_id", "survey_type",
    "survey_series", "source"
  )
  plotted_data <- do.call(rbind, lapply(included_admin_levels, function(level) {
    rbind(
      level_data[[level]]$model_data[, export_columns, drop = FALSE],
      level_data[[level]]$direct_data[, export_columns, drop = FALSE]
    )
  }))
  region_order <- unlist(lapply(
    included_admin_levels,
    function(level) level_data[[level]]$regions
  ), use.names = FALSE)
  plotted_data <- plotted_data[
    order(
      match(plotted_data$admin_level, included_admin_levels),
      match(plotted_data$outcome, c("U5MR", "NMR")),
      match(plotted_data$region, region_order),
      plotted_data$years,
      plotted_data$source
    ),
    , drop = FALSE
  ]
  utils::write.csv(plotted_data, output_csv, row.names = FALSE, na = "")

  pages <- paginate_regions(regions, regions_per_page = regions_per_page)
  plot_grobs <- list()
  for (admin_level in included_admin_levels) {
    for (outcome in outcomes) {
      pages <- paginate_outcome_regions(
        model_data = level_data[[admin_level]]$model_data,
        outcome = outcome,
        regions = level_data[[admin_level]]$regions,
        regions_per_page = regions_per_page
      )
      for (page_number in seq_along(pages)) {
        plot <- build_previous_final_page(
          model_data = level_data[[admin_level]]$model_data,
          direct_data = level_data[[admin_level]]$direct_data,
          outcome = outcome,
          regions = pages[[page_number]],
          country = country,
          page_number = page_number,
          page_count = length(pages),
          current_label = current_label,
          previous_label = previous_label,
          admin_level = admin_level,
          panel_slots = regions_per_page
        )
        plot_grob <- ggplot2::ggplotGrob(plot)
        plot_grob <- blank_unused_facet_slots(
          plot_grob,
          used_slots = length(pages[[page_number]]),
          panel_slots = regions_per_page,
          ncol = 2L
        )
        plot_grobs[[length(plot_grobs) + 1L]] <- plot_grob
      }
    }
  }
  write_comparison_grobs_pdf(
    plot_grobs = plot_grobs,
    output_pdf = output_pdf,
    page_size = a4_portrait_inches()
  )

  message(
    if (identical(mode, "current_only")) {
      "Saved current-only sub-area PDF: "
    } else {
      "Saved previous-final comparison PDF: "
    },
    output_pdf
  )
  message("Saved plotted comparison data: ", output_csv)
  invisible(list(
    mode = mode,
    pdf = normalizePath(output_pdf, winslash = "/", mustWork = TRUE),
    data = normalizePath(output_csv, winslash = "/", mustWork = TRUE),
    admin_levels = included_admin_levels,
    regions = lapply(level_data, `[[`, "regions"),
    pages_per_outcome = vapply(
      level_data, function(value) length(value$pages), integer(1)
    )
  ))
}

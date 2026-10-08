igme_release_names <- function() {
  c(
    "igme2026_nmr.csv",
    "igme2026_nmr_nocrisis.csv",
    "igme2026_u5.csv",
    "igme2026_u5_nocrisis.csv"
  )
}

file_sha256 <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    stop("Cannot hash missing or non-file path: ", path, call. = FALSE)
  }
  if (requireNamespace("digest", quietly = TRUE)) {
    return(toupper(digest::digest(path, algo = "sha256", file = TRUE)))
  }

  sha_program <- Sys.which("sha256sum")
  if (nzchar(sha_program)) {
    output <- system2(sha_program, path, stdout = TRUE, stderr = TRUE)
    if (!identical(attr(output, "status") %||% 0L, 0L)) {
      stop("sha256sum failed for: ", path, call. = FALSE)
    }
    return(toupper(strsplit(output[[1]], "[[:space:]]+")[[1]][[1]]))
  }

  if (.Platform$OS.type == "windows") {
    output <- system2(
      "certutil",
      c("-hashfile", shQuote(normalizePath(path, winslash = "\\")), "SHA256"),
      stdout = TRUE,
      stderr = TRUE
    )
    hashes <- gsub("[[:space:]]", "", output)
    hashes <- hashes[grepl("^[[:xdigit:]]{64}$", hashes)]
    if (length(hashes) == 1L) {
      return(toupper(hashes[[1]]))
    }
  }
  stop("A SHA-256 implementation is required to validate refresh files.",
       call. = FALSE)
}

file_inventory <- function(paths) {
  paths <- as.character(paths)
  lapply(paths, function(path) {
    exists <- file.exists(path) && !dir.exists(path)
    info <- if (exists) file.info(path) else NULL
    list(
      path = normalizePath(path, winslash = "/", mustWork = FALSE),
      exists = exists,
      size = if (exists) unname(info$size) else NULL,
      mtime = if (exists) format(info$mtime, "%Y-%m-%dT%H:%M:%S%z") else NULL,
      mtime_numeric = if (exists) as.numeric(info$mtime) else NULL,
      sha256 = if (exists) file_sha256(path) else NULL
    )
  })
}

read_igme_release_file <- function(path) {
  tryCatch(
    utils::read.csv(
      path,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA")
    ),
    error = function(e) {
      stop("IGME file is not readable: ", path, " (", conditionMessage(e), ")",
           call. = FALSE)
    }
  )
}

validate_igme_release <- function(directory, iso3, years) {
  directory <- normalizePath(directory, winslash = "/", mustWork = FALSE)
  iso3 <- as.character(iso3)[[1]]
  years <- as.integer(years)
  required_columns <- c(
    "Country.Name", "ISO.Code", "Quantile", "Indicator", "Subgroup"
  )
  year_columns <- paste0("X", years, ".5")

  files <- lapply(igme_release_names(), function(name) {
    path <- file.path(directory, name)
    if (!file.exists(path)) {
      stop("Missing IGME release file: ", path, call. = FALSE)
    }
    dat <- read_igme_release_file(path)
    missing_columns <- setdiff(c(required_columns, year_columns), names(dat))
    if (length(missing_columns)) {
      stop(
        "IGME file is missing required columns: ", path, " -> ",
        paste(missing_columns, collapse = ", "),
        call. = FALSE
      )
    }

    country_rows <- dat[dat$ISO.Code == iso3, , drop = FALSE]
    quantiles <- tolower(trimws(as.character(country_rows$Quantile)))
    if (nrow(country_rows) != 3L ||
        !setequal(quantiles, c("lower", "median", "upper"))) {
      stop(
        "IGME file must contain Lower/Median/Upper rows for ", iso3, ": ",
        path,
        call. = FALSE
      )
    }
    values <- suppressWarnings(as.numeric(unlist(
      country_rows[, year_columns, drop = FALSE],
      use.names = FALSE
    )))
    if (length(values) != 3L * length(year_columns) ||
        any(!is.finite(values))) {
      stop(
        "IGME file has missing or non-finite values for ", iso3,
        " in configured years: ", path,
        call. = FALSE
      )
    }

    inventory <- file_inventory(path)[[1]]
    inventory$readable <- TRUE
    inventory$iso3 <- iso3
    inventory$years <- range(years)
    inventory
  })
  names(files) <- igme_release_names()
  list(directory = directory, iso3 = iso3, years = range(years), files = files)
}

classify_staged_igme_release <- function(active_dir, staged_dir) {
  names <- igme_release_names()
  active_paths <- file.path(active_dir, names)
  staged_paths <- file.path(staged_dir, names)
  staged_exists <- file.exists(staged_paths)
  if (!any(staged_exists)) {
    return(list(status = "absent", files = list()))
  }
  if (!all(staged_exists)) {
    stop("The staged IGME release is incomplete; all four files are required.",
         call. = FALSE)
  }

  active <- file_inventory(active_paths)
  staged <- file_inventory(staged_paths)
  same <- vapply(seq_along(names), function(i) {
    isTRUE(active[[i]]$exists) &&
      identical(active[[i]]$sha256, staged[[i]]$sha256)
  }, logical(1))
  if (all(same)) {
    return(list(status = "identical", active = active, staged = staged))
  }

  missing_active <- !vapply(active, `[[`, logical(1), "exists")
  if (all(missing_active)) {
    return(list(status = "promote", active = active, staged = staged))
  }
  if (any(missing_active)) {
    stop("The active IGME release is incomplete; refusing a mixed promotion.",
         call. = FALSE)
  }

  comparisons <- vapply(seq_along(names), function(i) {
    if (same[[i]]) return(0)
    sign(staged[[i]]$mtime_numeric - active[[i]]$mtime_numeric)
  }, numeric(1))
  changed_comparisons <- comparisons[!same]
  if (all(changed_comparisons > 0L)) {
    return(list(status = "promote", active = active, staged = staged))
  }
  if (all(changed_comparisons < 0L)) {
    return(list(status = "ignore", active = active, staged = staged))
  }
  stop(
    "Staged and active IGME files have mixed or ambiguous modification times; ",
    "refusing to create a mixed release.",
    call. = FALSE
  )
}

relative_to_root <- function(path, root) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  prefix <- paste0(sub("/+$", "", root), "/")
  if (!startsWith(path, prefix)) {
    stop("Backup source is outside the approved root: ", path, call. = FALSE)
  }
  substring(path, nchar(prefix) + 1L)
}

copy_verified_backup <- function(path, source_root, backup_root) {
  relative <- relative_to_root(path, source_root)
  destination <- file.path(backup_root, relative)
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(path, destination, overwrite = FALSE, copy.date = TRUE)) {
    stop("Failed to back up: ", path, call. = FALSE)
  }
  source_sha256 <- file_sha256(path)
  backup_sha256 <- file_sha256(destination)
  if (!identical(source_sha256, backup_sha256)) {
    stop("Backup hash mismatch for: ", path, call. = FALSE)
  }
  list(
    source_path = normalizePath(path, winslash = "/"),
    backup_path = normalizePath(destination, winslash = "/"),
    source_sha256 = source_sha256,
    backup_sha256 = backup_sha256
  )
}

parse_igme_refresh_args <- function(args = commandArgs(trailingOnly = TRUE),
                                    country = NULL,
                                    mode = "preview",
                                    render_summary = TRUE,
                                    report_year = 2026L) {
  help <- FALSE
  i <- 1L
  next_arg <- function(index, flag) {
    if (index >= length(args)) {
      stop("Missing value after ", flag, call. = FALSE)
    }
    args[[index + 1L]]
  }
  while (i <= length(args)) {
    arg <- args[[i]]
    if (arg %in% c("--help", "-h")) {
      help <- TRUE
    } else if (arg == "--country") {
      country <- next_arg(i, arg)
      i <- i + 1L
    } else if (grepl("^--country=", arg)) {
      country <- sub("^--country=", "", arg)
    } else if (arg == "--preview") {
      mode <- "preview"
    } else if (arg == "--production") {
      mode <- "production"
    } else if (arg == "--mode") {
      mode <- next_arg(i, arg)
      i <- i + 1L
    } else if (grepl("^--mode=", arg)) {
      mode <- sub("^--mode=", "", arg)
    } else if (arg == "--report-year") {
      report_year <- next_arg(i, arg)
      i <- i + 1L
    } else if (grepl("^--report-year=", arg)) {
      report_year <- sub("^--report-year=", "", arg)
    } else if (arg %in% c("--skip-summary", "--no-summary")) {
      render_summary <- FALSE
    } else if (!startsWith(arg, "-") && is.null(country)) {
      country <- arg
    } else {
      stop("Unknown IGME refresh argument: ", arg, call. = FALSE)
    }
    i <- i + 1L
  }

  if (!help && (is.null(country) || !nzchar(country))) {
    stop("Provide --country COUNTRY for the IGME refresh.", call. = FALSE)
  }
  list(
    country = country,
    mode = normalize_pipeline_mode(mode),
    render_summary = isTRUE(render_summary),
    report_year = normalize_report_year(report_year),
    help = help
  )
}

make_igme_refresh_steps <- function(project_dir = pipeline_project_dir(),
                                    render_summary = TRUE,
                                    crisis_adjustment = FALSE) {
  rcode <- file.path(project_dir, "Rcode")
  steps <- list(
    pipeline_step(
      "bb8_refresh",
      "Refresh benchmarked BB8 model families from the active IGME release",
      file.path(rcode, "8_10_BB8.R"),
      env = c(
        BB8_ADMIN1_ONLY = "0",
        BB8_SKIP_SAME_FRAME_NMR = "0",
        BB8_SKIP_SAME_FRAME_MAIN = "1",
        BB8_RESUME_ALL_SURVEYS = "0",
        BB8_REPAIR_ADMIN2_STRAT_U5_ONLY = "0",
        BB8_RESUME_STRAT_ADMIN2_U5 = "0",
        BB8_RESUME_ALLSURVEY_ADMIN2_U5 = "0",
        BB8_REFRESH_BENCHMARKS_ONLY = "1",
        BB8_RESUME_ALLSURVEY_BENCHMARKS = "1",
        BB8_FINAL_ADMIN2_ONLY = "0",
        BB8_REFRESH_SELECTED_ONLY = "1"
      )
    )
  )
  if (isTRUE(crisis_adjustment)) {
    steps <- c(steps, list(pipeline_step(
      "crisis_adjustment",
      "Refresh the country's crisis-adjusted U5MR model files",
      file.path(
        rcode,
        "_supporting_scripts",
        "refresh_country_crisis_adjustment.R"
      ),
      kind = "source_main"
    )))
  }
  steps <- c(steps, list(
    pipeline_step(
      "bb8_comparison",
      "Regenerate BB8 comparison plots and dashboard",
      file.path(rcode, "9_Comparison_Plot.R"),
      env = c(
        BB8_ADMIN1_ONLY = "0",
        BB8_COMPARISON_RDS = "",
        BB8_COMPARISON_HTML = ""
      )
    ),
    pipeline_step(
      "diagnostics",
      "Regenerate diagnostic plots",
      file.path(rcode, "9_Diagnostic_Plots.R"),
      env = c(BB8_ADMIN1_ONLY = "0")
    ),
    pipeline_step(
      "report_plots",
      "Regenerate final report plots",
      file.path(rcode, "11_Report_Plot.R"),
      env = c(BB8_ADMIN1_ONLY = "0")
    )
  ))
  if (isTRUE(render_summary)) {
    steps <- c(steps, list(pipeline_step(
      "country_summary",
      "Render and assemble the country summary PDF",
      file.path(rcode, "11_CountrySummary.Rmd"),
      kind = "render_rmd",
      env = c(BB8_ADMIN1_ONLY = "0", RSTUDIO_PANDOC = "")
    )))
  }
  steps
}

igme_refresh_has_admin2 <- function(info_values) {
  value <- info_values[["poly.layer.adm2"]]
  !is.null(value) && length(value) == 1L && !is.na(value) &&
    nzchar(trimws(as.character(value)))
}

igme_refresh_benchmark_contract <- function(project_dir,
                                            country,
                                            has_admin2,
                                            final_model = NULL) {
  project_dir <- pipeline_project_dir(project_dir)
  families <- c("strat", "allsurveys")
  if (!is.null(final_model)) {
    if (!identical(final_model$bench.model, "bench") ||
        !final_model$strata.model %in% c("strat", "unstrat") ||
        !identical(final_model$time.model, "ar1")) {
      stop("Selected-model IGME refresh requires a strat/unstrat AR1 benchmarked final_model.",
           call. = FALSE)
    }
    families <- if (identical(final_model$strata.model, "strat")) {
      "strat"
    } else {
      "allsurveys"
    }
  }
  levels <- c("adm1", if (isTRUE(has_admin2)) "adm2")
  rows <- expand.grid(
    level = levels,
    outcome = c("nmr", "u5"),
    family = families,
    stringsAsFactors = FALSE
  )
  rows <- rows[order(rows$level, rows$outcome, rows$family), , drop = FALSE]
  rows$metric_dir <- ifelse(rows$outcome == "nmr", "NMR", "U5MR")
  rows$model_stem <- ifelse(
    rows$family == "strat",
    paste(rows$level, "strat", rows$outcome, sep = "_"),
    paste(rows$level, "unstrat", rows$outcome, "allsurveys", sep = "_")
  )
  rows$base_object <- paste0(
    "bb.res.",
    gsub("_", ".", rows$model_stem, fixed = TRUE)
  )
  result_root <- file.path(project_dir, "Results", country, "Betabinomial")
  rows$base_path <- file.path(
    result_root,
    rows$metric_dir,
    paste0(country, "_res_", rows$model_stem, ".rda")
  )
  rows$output_object <- paste0(rows$base_object, ".bench")
  rows$output_path <- file.path(
    result_root,
    rows$metric_dir,
    paste0(country, "_res_", rows$model_stem, "_bench.rda")
  )
  rows$weight_path <- file.path(
    project_dir,
    "Data",
    "Countries",
    country,
    "worldpop",
    paste0(
      rows$level,
      "_weights_",
      ifelse(rows$outcome == "nmr", "u1", "u5"),
      ".rda"
    )
  )
  rows
}

igme_refresh_crisis_result_paths <- function(project_dir, country) {
  model_stem <- if (identical(country, "Myanmar")) {
    info <- jsonlite::fromJSON(file.path(project_dir, "Info", "Myanmar_general_info.json"))
    if (identical(info$final_model$strata.model, "strat")) "strat_u5" else
      "unstrat_u5_allsurveys"
  } else {
    "unstrat_u5_allsurveys"
  }
  file.path(
    project_dir,
    "Results",
    country,
    "Betabinomial",
    "U5MR",
    paste0(
      country,
      "_res_",
      c("adm1", "adm2"),
      "_",
      model_stem,
      "_bench_crisis.rda"
    )
  )
}

igme_refresh_crisis_preflight <- function(project_dir, country) {
  crisis_dir <- file.path(project_dir, "Data", "Crisis_Adjustment")
  if (identical(country, "Malawi")) {
    return(list(
      scripts = file.path(crisis_dir, c("apply_cod_crisis_adjustment.R",
        "prepare_mwi_fao_proxy.R", "apply_mwi_crisis_adjustment.R")),
      inputs = file.path(crisis_dir, "Crisis_Under5_deaths_2026.xlsx")
    ))
  }
  if (identical(country, "Sudan")) {
    return(list(
      scripts = file.path(crisis_dir, c("prepare_sdn_darfur.R",
        "apply_cod_crisis_adjustment.R", "apply_sdn_crisis_adjustment.R")),
      inputs = file.path(crisis_dir, c("Crisis_Under5_deaths_2026.xlsx",
        "sdn_2025_state_weights.csv", "sdn_2025_state_weights_source.json"))
    ))
  }
  if (identical(country, "DR_Congo")) {
    return(list(
      scripts = file.path(crisis_dir, "apply_cod_crisis_adjustment.R"),
      inputs = file.path(crisis_dir, "crisis_COD.rda")
    ))
  }
  if (identical(country, "Myanmar")) {
    return(list(
      scripts = c(
        file.path(crisis_dir, "apply_cod_crisis_adjustment.R"),
        file.path(crisis_dir, "apply_myanmar_crisis_adjustment.R")
      ),
      inputs = c(
        file.path(crisis_dir, "Crisis_Under5_deaths_2026.xlsx"),
        file.path(crisis_dir, "crisis_MMR.rda")
      )
    ))
  }
  four_country_iso <- c(
    Guinea = "GIN",
    Haiti = "HTI",
    Liberia = "LBR",
    Sierra_Leone = "SLE"
  )
  if (country %in% names(four_country_iso)) {
    inputs <- file.path(crisis_dir, "Crisis_Under5_deaths_2026.xlsx")
    if (!identical(country, "Haiti")) {
      inputs <- c(
        inputs,
        file.path(crisis_dir, paste0("crisis_", four_country_iso[[country]],
                                    ".rda"))
      )
    }
    return(list(
      scripts = c(
        file.path(crisis_dir, "apply_cod_crisis_adjustment.R"),
        file.path(crisis_dir, "apply_four_country_crisis_adjustments.R")
      ),
      inputs = inputs
    ))
  }
  stop(
    "Crisis adjustment is enabled, but no supported refresh method exists for: ",
    country,
    call. = FALSE
  )
}

validate_saved_bb8_base <- function(path, object_name) {
  if (!file.exists(path)) {
    stop("Missing saved unbenchmarked BB8 result: ", path, call. = FALSE)
  }
  loaded <- new.env(parent = emptyenv())
  object_names <- tryCatch(
    base::load(path, envir = loaded),
    error = function(e) {
      stop(
        "Saved unbenchmarked BB8 result is unreadable: ",
        path,
        " (",
        conditionMessage(e),
        ")",
        call. = FALSE
      )
    }
  )
  if (!object_name %in% object_names) {
    stop(
      "Saved unbenchmarked BB8 result has no object named ",
      object_name,
      ": ",
      path,
      call. = FALSE
    )
  }
  object <- get(object_name, envir = loaded, inherits = FALSE)
  if (!is.list(object) || !is.list(object$draws.est.overall) ||
      !length(object$draws.est.overall)) {
    stop("Saved unbenchmarked BB8 result has no overall draws: ", path,
         call. = FALSE)
  }
  invisible(TRUE)
}

restore_one_environment_variable <- function(name, value) {
  if (is.na(value)) {
    Sys.unsetenv(name)
  } else {
    do.call(Sys.setenv, setNames(list(value), name))
  }
  invisible(NULL)
}

preflight_igme_refresh <- function(project_dir,
                                   country,
                                   info,
                                   render_summary = TRUE) {
  has_admin2 <- igme_refresh_has_admin2(info$values)
  if (isTRUE(info$values$doCrisisAdj) && !has_admin2 &&
      !identical(country, "Sudan")) {
    stop("Configured crisis refresh requires Admin-2 model outputs.",
         call. = FALSE)
  }
  contract <- igme_refresh_benchmark_contract(
    project_dir,
    country,
    has_admin2,
    final_model = info$values$final_model
  )
  invisible(mapply(
    validate_saved_bb8_base,
    contract$base_path,
    contract$base_object,
    SIMPLIFY = FALSE
  ))

  weight_paths <- unique(contract$weight_path)
  invisible(lapply(weight_paths, load_weight_data))
  country_data <- file.path(project_dir, "Data", "Countries", country)
  required_data <- c(
    file.path(country_data, paste0(country, "_cluster_dat_1frame.rda")),
    file.path(country_data, paste0(country, "_cluster_dat.rda"))
  )
  required_scripts <- c(
    file.path(project_dir, "Rcode", "1_Preperation.R"),
    file.path(project_dir, "Rcode", "8_10_BB8.R"),
    file.path(project_dir, "Rcode", "9_Comparison_Plot.R"),
    file.path(project_dir, "Rcode", "9_Comparison_Plot.qmd"),
    file.path(project_dir, "Rcode", "9_Diagnostic_Plots.R"),
    file.path(project_dir, "Rcode", "11_Report_Plot.R")
  )
  if (isTRUE(info$values$doCrisisAdj)) {
    crisis_preflight <- igme_refresh_crisis_preflight(project_dir, country)
    required_data <- c(required_data, crisis_preflight$inputs)
    required_scripts <- c(
      required_scripts,
      file.path(
        project_dir,
        "Rcode",
        "_supporting_scripts",
        "refresh_country_crisis_adjustment.R"
      ),
      crisis_preflight$scripts
    )
  }
  if (isTRUE(render_summary)) {
    required_scripts <- c(
      required_scripts,
      file.path(project_dir, "Rcode", "11_CountrySummary.Rmd"),
      file.path(project_dir, "Rcode", "12_Previous_Final_Comparison.R")
    )
  }
  missing_inputs <- c(required_data, required_scripts)[
    !file.exists(c(required_data, required_scripts))
  ]
  if (length(missing_inputs)) {
    stop(
      "IGME refresh preflight is missing required inputs: ",
      paste(missing_inputs, collapse = ", "),
      call. = FALSE
    )
  }

  required_packages <- c(
    "SUMMER", "INLA", "tidyverse", "sf", "scales", "data.table",
    "survey", "sp", "RColorBrewer", "gridExtra", "raster",
    "latticeExtra", "viridis", "xtable", "Hmisc", "spdep",
    "rasterVis", "plotrix", "ggridges", "ggplot2", "jsonlite"
  )
  if (isTRUE(render_summary)) {
    required_packages <- c(required_packages, "rmarkdown", "qpdf", "readxl")
  }
  if (isTRUE(info$values$doCrisisAdj)) {
    required_packages <- c(required_packages, "readxl")
  }
  required_packages <- unique(required_packages)
  missing_packages <- required_packages[!vapply(
    required_packages,
    requireNamespace,
    logical(1),
    quietly = TRUE
  )]
  if (length(missing_packages)) {
    stop(
      "IGME refresh preflight is missing R packages: ",
      paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  quarto_path <- find_pipeline_quarto()
  if (!nzchar(quarto_path) && requireNamespace("quarto", quietly = TRUE)) {
    quarto_path <- tryCatch(quarto::quarto_path(), error = function(e) "")
  }
  if (!nzchar(quarto_path) || !file.exists(quarto_path)) {
    stop("Quarto is required to rebuild the comparison dashboard.",
         call. = FALSE)
  }

  pandoc_available <- NULL
  latex_path <- NULL
  previous_final_workbook <- NULL
  if (isTRUE(render_summary)) {
    previous_pandoc <- Sys.getenv("RSTUDIO_PANDOC", unset = NA_character_)
    on.exit(
      restore_one_environment_variable("RSTUDIO_PANDOC", previous_pandoc),
      add = TRUE
    )
    pandoc_available <- configure_pipeline_pandoc()
    if (!isTRUE(pandoc_available)) {
      stop("Pandoc is required to rebuild the country summary PDF.",
           call. = FALSE)
    }
    latex_candidates <- Sys.which(c("pdflatex", "xelatex", "lualatex"))
    latex_candidates <- latex_candidates[nzchar(latex_candidates)]
    if (!length(latex_candidates)) {
      stop("A LaTeX engine is required to rebuild the country summary PDF.",
           call. = FALSE)
    }
    latex_path <- unname(latex_candidates[[1]])
    appendix_environment <- new.env(parent = globalenv())
    sys.source(
      file.path(project_dir, "Rcode", "12_Previous_Final_Comparison.R"),
      envir = appendix_environment
    )
    previous_final_workbook <-
      appendix_environment$resolve_previous_final_workbook()
  }

  list(
    has_admin2 = has_admin2,
    benchmark_contract = contract,
    required_inputs = file_inventory(c(
      unique(contract$base_path),
      weight_paths,
      required_data,
      required_scripts
    )),
    required_packages = required_packages,
    quarto = normalizePath(quarto_path, winslash = "/", mustWork = TRUE),
    pandoc_available = pandoc_available,
    latex = latex_path,
    previous_final_workbook = previous_final_workbook
  )
}

discover_igme_refresh_targets <- function(project_dir,
                                          country,
                                          report_year = 2026L) {
  project_dir <- pipeline_project_dir(project_dir)
  result_dir <- file.path(project_dir, "Results", country)
  if (!dir.exists(result_dir)) {
    return(character())
  }

  benchmark_dir <- file.path(result_dir, "Betabinomial")
  benchmark_files <- if (dir.exists(benchmark_dir)) {
    candidates <- list.files(
      benchmark_dir,
      recursive = TRUE,
      full.names = TRUE,
      include.dirs = FALSE
    )
    candidates[grepl("bench", basename(candidates), ignore.case = TRUE)]
  } else {
    character()
  }

  figure_dirs <- file.path(
    result_dir,
    "Figures",
    c(
      "Summary",
      "Trends",
      "CurrentSubarea",
      "PreviousFinalComparison"
    )
  )
  figure_files <- unlist(lapply(figure_dirs, function(path) {
    if (!dir.exists(path)) return(character())
    list.files(path, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)
  }), use.names = FALSE)

  root_outputs <- file.path(
    result_dir,
    c(
      paste0(country, "_bb8_comparison_dashboard.html"),
      paste0(country, "_bb8_comparison_data.rds"),
      country_report_filename(country, report_year)
    )
  )
  targets <- unique(c(benchmark_files, figure_files, root_outputs))
  targets <- targets[file.exists(targets) & !dir.exists(targets)]
  normalizePath(targets, winslash = "/", mustWork = TRUE)
}

validate_benchmark_result_file <- function(path,
                                           expected_draw_count = 1000L,
                                           expected_object = NULL,
                                           expected_keys = NULL) {
  loaded <- new.env(parent = emptyenv())
  object_names <- tryCatch(
    base::load(path, envir = loaded),
    error = function(e) {
      stop(
        "Benchmark result is not readable: ", path, " (",
        conditionMessage(e), ")",
        call. = FALSE
      )
    }
  )
  candidates <- object_names[vapply(object_names, function(name) {
    object <- get(name, envir = loaded, inherits = FALSE)
    is.list(object) && is.list(object$draws.est.overall)
  }, logical(1))]
  if (!is.null(expected_object)) {
    expected_object <- as.character(expected_object)
    if (length(expected_object) != 1L || is.na(expected_object) ||
        !nzchar(expected_object) || !expected_object %in% candidates) {
      stop(
        "Benchmark result does not contain the expected object ",
        expected_object,
        ": ",
        path,
        call. = FALSE
      )
    }
    candidates <- expected_object
  }
  if (length(candidates) != 1L) {
    stop(
      "Benchmark result must contain one object with draws.est.overall: ",
      path,
      call. = FALSE
    )
  }
  draws <- get(candidates[[1]], envir = loaded, inherits = FALSE)$draws.est.overall
  if (!length(draws)) {
    stop("Benchmark result has no saved admin draw cells: ", path,
         call. = FALSE)
  }
  draw_counts <- vapply(draws, function(cell) length(cell$draws), integer(1))
  finite <- vapply(draws, function(cell) {
    length(cell$draws) > 0L && all(is.finite(as.numeric(cell$draws)))
  }, logical(1))
  if (any(draw_counts != as.integer(expected_draw_count)) || any(!finite)) {
    stop(
      "Benchmark result requires ", expected_draw_count,
      " finite draws in every admin/year cell: ", path,
      call. = FALSE
    )
  }
  cells <- data.frame(
    region = vapply(draws, function(cell) {
      as.character(cell$region %||% NA_character_)[[1]]
    }, character(1)),
    years = vapply(draws, function(cell) {
      as.integer(as.character(cell$years %||% NA_integer_))[[1]]
    }, integer(1)),
    stringsAsFactors = FALSE
  )
  if (anyNA(cells) || any(!nzchar(cells$region))) {
    stop("Benchmark result has invalid admin/year keys: ", path,
         call. = FALSE)
  }
  cell_keys <- paste(cells$region, cells$years, sep = "\r")
  if (anyDuplicated(cell_keys)) {
    stop("Benchmark result has duplicate admin/year cells: ", path,
         call. = FALSE)
  }
  if (!is.null(expected_keys)) {
    required <- c("region", "years")
    if (!is.data.frame(expected_keys) ||
        !all(required %in% names(expected_keys))) {
      stop("Expected benchmark keys require region and years columns.",
           call. = FALSE)
    }
    expected <- unique(data.frame(
      region = as.character(expected_keys$region),
      years = as.integer(as.character(expected_keys$years)),
      stringsAsFactors = FALSE
    ))
    expected_cell_keys <- paste(expected$region, expected$years, sep = "\r")
    if (!setequal(cell_keys, expected_cell_keys)) {
      stop(
        "Benchmark result does not cover the exact expected region/year grid: ",
        path,
        call. = FALSE
      )
    }
  }
  list(
    path = normalizePath(path, winslash = "/"),
    object = candidates[[1]],
    readable = TRUE,
    draw_count = as.integer(unique(draw_counts)[[1]]),
    cell_count = length(draws),
    region_count = length(unique(cells$region)),
    year_count = length(unique(cells$years)),
    sha256 = file_sha256(path)
  )
}

artifact_fresh_record <- function(path,
                                  previous_inventory,
                                  run_started_at) {
  current <- file_inventory(path)[[1]]
  normalized <- current$path
  previous_paths <- vapply(
    previous_inventory,
    function(item) item$path %||% "",
    character(1)
  )
  previous_index <- match(tolower(normalized), tolower(previous_paths))
  previous <- if (is.na(previous_index)) NULL else previous_inventory[[previous_index]]
  fresh <- FALSE
  reason <- "missing or empty"
  if (isTRUE(current$exists) && !is.null(current$size) && current$size > 0) {
    if (is.null(previous) || !isTRUE(previous$exists)) {
      fresh <- isTRUE(current$mtime_numeric >= as.numeric(run_started_at) - 2)
      reason <- if (fresh) "created during run" else "predates run"
    } else {
      hash_changed <- !identical(current$sha256, previous$sha256)
      mtime_advanced <- isTRUE(
        current$mtime_numeric > previous$mtime_numeric + 1e-6
      )
      fresh <- hash_changed || mtime_advanced
      reason <- if (hash_changed) {
        "content changed"
      } else if (mtime_advanced) {
        "rewritten during run"
      } else {
        "unchanged from pre-run inventory"
      }
    }
  }
  current$fresh <- fresh
  current$freshness_reason <- reason
  current
}

validate_fresh_artifacts <- function(paths,
                                     previous_inventory,
                                     run_started_at) {
  records <- lapply(
    paths,
    artifact_fresh_record,
    previous_inventory = previous_inventory,
    run_started_at = run_started_at
  )
  stale <- vapply(records, function(item) !isTRUE(item$fresh), logical(1))
  if (any(stale)) {
    details <- vapply(records[stale], function(item) {
      paste0(item$path, " (", item$freshness_reason, ")")
    }, character(1))
    stop(
      "IGME refresh artifacts were not regenerated: ",
      paste(details, collapse = ", "),
      call. = FALSE
    )
  }
  records
}

validate_fresh_artifact_group <- function(directory,
                                          previous_inventory,
                                          run_started_at,
                                          label,
                                          minimum_count = 1L) {
  paths <- unlist(lapply(directory, function(path) {
    if (!dir.exists(path)) return(character())
    list.files(path, recursive = TRUE, full.names = TRUE,
               include.dirs = FALSE)
  }), use.names = FALSE)
  records <- lapply(
    paths,
    artifact_fresh_record,
    previous_inventory = previous_inventory,
    run_started_at = run_started_at
  )
  fresh <- Filter(function(item) isTRUE(item$fresh), records)
  if (length(fresh) < as.integer(minimum_count)) {
    stop("No freshly generated ", label, " artifacts were found in: ",
         paste(directory, collapse = ", "), call. = FALSE)
  }
  fresh
}

validate_pdf_artifact <- function(path, minimum_pages = 2L) {
  if (!requireNamespace("qpdf", quietly = TRUE)) {
    stop("Package 'qpdf' is required to validate the report PDF.",
         call. = FALSE)
  }
  if (!file.exists(path) || is.na(file.info(path)$size) ||
      file.info(path)$size <= 0) {
    stop("Report PDF is missing or empty: ", path, call. = FALSE)
  }
  page_count <- tryCatch(
    qpdf::pdf_length(path),
    error = function(e) {
      stop("Report PDF is unreadable: ", path, " (", conditionMessage(e),
           ")", call. = FALSE)
    }
  )
  if (!is.finite(page_count) || page_count < as.integer(minimum_pages)) {
    stop(
      "Report PDF has an implausible page count (",
      page_count,
      "): ",
      path,
      call. = FALSE
    )
  }
  list(
    path = normalizePath(path, winslash = "/", mustWork = TRUE),
    page_count = as.integer(page_count),
    sha256 = file_sha256(path)
  )
}

benchmark_gap_threshold <- function(outcome) {
  outcome <- tolower(as.character(outcome)[[1]])
  if (outcome == "nmr") return(2)
  if (outcome %in% c("u5", "u5mr")) return(5)
  stop("Benchmark outcome must be 'nmr' or 'u5'.", call. = FALSE)
}

summarize_benchmark_gaps <- function(model,
                                     outcome,
                                     national_draws,
                                     igme_targets) {
  years <- as.integer(names(national_draws))
  if (!length(years) || anyNA(years)) {
    stop("National benchmark draws must be named by year.", call. = FALSE)
  }
  target_order <- match(years, as.integer(igme_targets$year))
  if (anyNA(target_order)) {
    stop("IGME targets do not cover all benchmark result years.",
         call. = FALSE)
  }
  estimates <- vapply(national_draws, stats::median, numeric(1))
  targets <- as.numeric(igme_targets$igme[target_order])
  if (any(!is.finite(estimates)) || any(!is.finite(targets))) {
    stop("Benchmark aggregation or IGME target is non-finite.",
         call. = FALSE)
  }
  threshold <- benchmark_gap_threshold(outcome)
  gap <- abs(estimates - targets) * 1000
  data.frame(
    model = model,
    outcome = tolower(outcome),
    year = years,
    posterior_median = unname(estimates),
    igme_median = targets,
    absolute_gap_per_1000 = unname(gap),
    threshold_per_1000 = threshold,
    review_required = unname(gap > threshold),
    stringsAsFactors = FALSE
  )
}

read_igme_median_targets <- function(path, iso3, years) {
  dat <- read_igme_release_file(path)
  row <- dat[
    dat$ISO.Code == iso3 & tolower(trimws(dat$Quantile)) == "median",
    ,
    drop = FALSE
  ]
  if (nrow(row) != 1L) {
    stop("Expected one IGME median row for ", iso3, ": ", path,
         call. = FALSE)
  }
  columns <- paste0("X", years, ".5")
  if (!all(columns %in% names(row))) {
    stop("IGME median row is missing configured years: ", path,
         call. = FALSE)
  }
  values <- suppressWarnings(as.numeric(unlist(
    row[1, columns, drop = FALSE],
    use.names = FALSE
  ))) / 1000
  if (any(!is.finite(values))) {
    stop("IGME median targets are non-finite: ", path, call. = FALSE)
  }
  data.frame(year = as.integer(years), igme = values)
}

load_weight_data <- function(path) {
  loaded <- new.env(parent = emptyenv())
  names <- base::load(path, envir = loaded)
  candidates <- names[vapply(names, function(name) {
    object <- get(name, envir = loaded, inherits = FALSE)
    is.data.frame(object) &&
      all(c("region", "proportion", "years") %in% colnames(object))
  }, logical(1))]
  if (length(candidates) != 1L) {
    stop("Expected one population-weight data frame in: ", path,
         call. = FALSE)
  }
  get(candidates[[1]], envir = loaded, inherits = FALSE)
}

benchmark_gap_rows_from_files <- function(result_path,
                                           weight_path,
                                           igme_path,
                                           iso3,
                                           years,
                                           outcome,
                                           helper_path) {
  validation <- validate_benchmark_result_file(result_path)
  result_env <- new.env(parent = emptyenv())
  base::load(result_path, envir = result_env)
  result <- get(validation$object, envir = result_env, inherits = FALSE)
  weights <- load_weight_data(weight_path)
  helper_env <- new.env(parent = baseenv())
  sys.source(helper_path, envir = helper_env)
  national_draws <- helper_env$aggregate_admin_draws_to_national(
    admin_draws = result$draws.est.overall,
    admin_weights = weights,
    years = years
  )
  summarize_benchmark_gaps(
    model = tools::file_path_sans_ext(basename(result_path)),
    outcome = outcome,
    national_draws = national_draws,
    igme_targets = read_igme_median_targets(igme_path, iso3, years)
  )
}

load_igme_refresh_info <- function(project_dir, country) {
  info_file <- file.path(
    project_dir, "Info", paste0(country, "_general_info.json")
  )
  if (!file.exists(info_file)) {
    stop("Country Info JSON file not found: ", info_file, call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required for the IGME refresh.",
         call. = FALSE)
  }
  info <- tryCatch(
    jsonlite::fromJSON(info_file, simplifyVector = TRUE),
    error = function(e) {
      stop("Could not parse country Info JSON: ", conditionMessage(e),
           call. = FALSE)
    }
  )
  required <- c("country", "iso0", "beg.year", "end.proj.year", "final_model")
  missing <- required[!required %in% names(info)]
  if (length(missing)) {
    stop("Country Info JSON is missing: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  required_final_model <- c(
    "time.model", "sd.time.model", "strata.model", "bench.model"
  )
  missing_final_model <- required_final_model[
    !required_final_model %in% names(info$final_model)
  ]
  invalid_final_model <- setdiff(required_final_model, missing_final_model)[
    !vapply(
      info$final_model[setdiff(required_final_model, missing_final_model)],
      function(value) {
        length(value) == 1L && !is.na(value) && nzchar(as.character(value))
      },
      logical(1)
    )
  ]
  if (length(c(missing_final_model, invalid_final_model))) {
    stop(
      "Country Info JSON has missing or invalid final_model fields: ",
      paste(unique(c(missing_final_model, invalid_final_model)), collapse = ", "),
      call. = FALSE
    )
  }
  if (!identical(as.character(info$country), as.character(country))) {
    stop(
      "Country Info JSON country does not match requested country: ",
      info$country, " != ", country,
      call. = FALSE
    )
  }
  years <- seq.int(as.integer(info$beg.year), as.integer(info$end.proj.year))
  if (!length(years) || anyNA(years)) {
    stop("Country Info JSON has an invalid model year range.", call. = FALSE)
  }
  list(
    path = normalizePath(info_file, winslash = "/"),
    sha256 = file_sha256(info_file),
    values = info,
    years = years
  )
}

git_refresh_snapshot <- function(project_dir) {
  run_git <- function(args) {
    old <- getwd()
    on.exit(setwd(old), add = TRUE)
    setwd(project_dir)
    output <- suppressWarnings(system2("git", args, stdout = TRUE, stderr = TRUE))
    if (!identical(attr(output, "status") %||% 0L, 0L)) return(NULL)
    paste(output, collapse = "\n")
  }
  list(
    branch = run_git(c("branch", "--show-current")),
    commit = run_git(c("rev-parse", "HEAD")),
    dirty = nzchar(run_git(c("status", "--porcelain")) %||% "")
  )
}

backup_igme_refresh_paths <- function(paths, source_root, backup_root) {
  if (!length(paths)) return(list())
  lapply(paths, copy_verified_backup,
         source_root = source_root, backup_root = backup_root)
}

promote_staged_igme_release <- function(staged_dir,
                                        active_dir,
                                        backups,
                                        copy_file = file.copy) {
  names <- igme_release_names()
  staged_paths <- file.path(staged_dir, names)
  active_paths <- file.path(active_dir, names)
  expected_hashes <- vapply(staged_paths, file_sha256, character(1))
  original <- file_inventory(active_paths)
  backup_sources <- vapply(
    backups,
    function(item) item$source_path %||% "",
    character(1)
  )
  missing_backups <- vapply(seq_along(active_paths), function(index) {
    isTRUE(original[[index]]$exists) &&
      !tolower(original[[index]]$path) %in% tolower(backup_sources)
  }, logical(1))
  if (any(missing_backups)) {
    stop(
      "Cannot promote IGME release without verified backups for: ",
      paste(active_paths[missing_backups], collapse = ", "),
      call. = FALSE
    )
  }

  temporary_paths <- vapply(names, function(name) {
    tempfile(pattern = paste0(".", name, "_"), tmpdir = active_dir)
  }, character(1))
  on.exit(unlink(temporary_paths[file.exists(temporary_paths)]), add = TRUE)
  staged_copied <- logical(length(names))
  for (index in seq_along(names)) {
    staged_copied[[index]] <- isTRUE(copy_file(
      staged_paths[[index]],
      temporary_paths[[index]],
      overwrite = FALSE,
      copy.date = TRUE
    ))
    if (!staged_copied[[index]]) break
  }
  temporary_hashes <- vapply(temporary_paths, function(path) {
    if (file.exists(path)) file_sha256(path) else NA_character_
  }, character(1))
  if (!all(staged_copied) ||
      !identical(unname(temporary_hashes), unname(expected_hashes))) {
    stop("IGME release could not be verified in temporary promotion files.",
         call. = FALSE)
  }

  rollback <- function() {
    restored <- logical(length(active_paths))
    for (index in seq_along(active_paths)) {
      if (isTRUE(original[[index]]$exists)) {
        backup_index <- match(
          tolower(original[[index]]$path),
          tolower(backup_sources)
        )
        restored[[index]] <- isTRUE(file.copy(
          backups[[backup_index]]$backup_path,
          active_paths[[index]],
          overwrite = TRUE,
          copy.date = TRUE
        ))
      } else {
        if (file.exists(active_paths[[index]])) {
          unlink(active_paths[[index]])
        }
        restored[[index]] <- !file.exists(active_paths[[index]])
      }
    }
    verified <- vapply(seq_along(active_paths), function(index) {
      if (isTRUE(original[[index]]$exists)) {
        file.exists(active_paths[[index]]) && identical(
          file_sha256(active_paths[[index]]),
          original[[index]]$sha256
        )
      } else {
        !file.exists(active_paths[[index]])
      }
    }, logical(1))
    all(restored & verified)
  }

  copied <- logical(length(names))
  for (index in seq_along(names)) {
    copied[[index]] <- isTRUE(copy_file(
      temporary_paths[[index]],
      active_paths[[index]],
      overwrite = TRUE,
      copy.date = TRUE
    ))
    if (!copied[[index]]) break
  }
  actual_hashes <- vapply(active_paths, function(path) {
    if (file.exists(path)) file_sha256(path) else NA_character_
  }, character(1))
  if (!all(copied) ||
      !identical(unname(actual_hashes), unname(expected_hashes))) {
    if (!rollback()) {
      stop(
        "IGME release promotion and verified rollback both failed; ",
        "inspect active and backup files immediately.",
        call. = FALSE
      )
    }
    stop(
      "IGME release promotion failed; verified active-file backups were restored.",
      call. = FALSE
    )
  }
  file_inventory(active_paths)
}

validate_igme_refresh_outputs <- function(project_dir,
                                          country,
                                          report_year = 2026L,
                                          render_summary = TRUE,
                                          crisis_adjustment = FALSE,
                                          pre_run_inventory = list(),
                                          run_started_at = NULL,
                                          log_dir = NULL) {
  result_dir <- file.path(project_dir, "Results", country)
  if (is.null(run_started_at) || length(run_started_at) != 1L ||
      is.na(run_started_at)) {
    stop("Output validation requires the production run start time.",
         call. = FALSE)
  }

  info <- load_igme_refresh_info(project_dir, country)
  contract <- igme_refresh_benchmark_contract(
    project_dir,
    country,
    igme_refresh_has_admin2(info$values),
    final_model = info$values$final_model
  )
  result_files <- contract$output_path
  benchmark_results <- lapply(seq_len(nrow(contract)), function(index) {
    weights <- load_weight_data(contract$weight_path[[index]])
    expected_keys <- unique(weights[
      weights$years %in% info$years,
      c("region", "years"),
      drop = FALSE
    ])
    validate_benchmark_result_file(
      result_files[[index]],
      expected_object = contract$output_object[[index]],
      expected_keys = expected_keys
    )
  })
  names(benchmark_results) <- contract$model_stem
  benchmark_freshness <- validate_fresh_artifacts(
    result_files,
    pre_run_inventory,
    run_started_at
  )

  crisis_results <- list()
  crisis_freshness <- list()
  if (isTRUE(crisis_adjustment)) {
    crisis_files <- igme_refresh_crisis_result_paths(project_dir, country)
    crisis_family <- unique(contract$family)
    stopifnot(length(crisis_family) == 1L)
    crisis_results <- lapply(seq_along(crisis_files), function(index) {
      level <- c("adm1", "adm2")[[index]]
      contract_index <- which(
        contract$level == level & contract$outcome == "u5" &
          contract$family == crisis_family
      )
      weights <- load_weight_data(contract$weight_path[[contract_index]])
      expected_keys <- unique(weights[
        weights$years %in% info$years,
        c("region", "years"),
        drop = FALSE
      ])
      validate_benchmark_result_file(
        crisis_files[[index]],
        expected_object = contract$output_object[[contract_index]],
        expected_keys = expected_keys
      )
    })
    crisis_freshness <- validate_fresh_artifacts(
      crisis_files,
      pre_run_inventory,
      run_started_at
    )
  }

  gap_rows <- do.call(rbind, lapply(seq_len(nrow(contract)), function(index) {
    outcome <- contract$outcome[[index]]
    igme_path <- file.path(
      project_dir, "Data", "IGME",
      paste0("igme2026_", outcome, "_nocrisis.csv")
    )
    benchmark_gap_rows_from_files(
      result_path = result_files[[index]],
      weight_path = contract$weight_path[[index]],
      igme_path = igme_path,
      iso3 = info$values$iso0,
      years = info$years,
      outcome = outcome,
      helper_path = file.path(
        project_dir, "Rcode", "_supporting_scripts",
        "admin_benchmark_helpers.R"
      )
    )
  }))
  if (is.null(log_dir)) {
    log_dir <- file.path(result_dir, "logs")
  }
  dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  gap_file <- file.path(log_dir, "benchmark_gap_validation.csv")
  utils::write.csv(gap_rows, gap_file, row.names = FALSE, na = "")

  required_outputs <- c(
    file.path(result_dir, paste0(country, "_bb8_comparison_dashboard.html")),
    file.path(result_dir, paste0(country, "_bb8_comparison_data.rds"))
  )
  if (isTRUE(render_summary)) {
    required_outputs <- c(
      required_outputs,
      file.path(result_dir, country_report_filename(country, report_year))
    )
  }
  deliverable_freshness <- validate_fresh_artifacts(
    required_outputs,
    pre_run_inventory,
    run_started_at
  )
  comparison_data <- tryCatch(
    readRDS(required_outputs[[2]]),
    error = function(e) {
      stop("Comparison dashboard data is unreadable: ", conditionMessage(e),
           call. = FALSE)
    }
  )
  if (!is.list(comparison_data) ||
      !identical(as.character(comparison_data$country), country)) {
    stop("Comparison dashboard data does not match country: ", country,
         call. = FALSE)
  }
  html_text <- readChar(
    required_outputs[[1]],
    nchars = min(file.info(required_outputs[[1]])$size, 100000L),
    useBytes = TRUE
  )
  if (!grepl("<html", tolower(html_text), fixed = TRUE)) {
    stop("Comparison dashboard HTML is not structurally readable: ",
         required_outputs[[1]], call. = FALSE)
  }

  trend_freshness <- unlist(lapply(c("NMR", "U5MR"), function(metric) {
    validate_fresh_artifact_group(
      file.path(result_dir, "Figures", "Trends", metric),
      pre_run_inventory,
      run_started_at,
      paste(metric, "diagnostic plot")
    )
  }), recursive = FALSE)
  final_model <- info$values$final_model
  expected_report_plots <- file.path(
    result_dir,
    "Figures",
    "Summary",
    c("NMR", "U5MR"),
    paste0(
      country,
      "_natl_",
      final_model$strata.model,
      "_",
      final_model$time.model,
      "_",
      c("nmr", "u5"),
      "_Spaghetti.pdf"
    )
  )
  report_plot_freshness <- validate_fresh_artifacts(
    expected_report_plots,
    pre_run_inventory,
    run_started_at
  )
  appendix_freshness <- list()
  pdf_validation <- NULL
  if (isTRUE(render_summary)) {
    appendix_freshness <- validate_fresh_artifact_group(
      file.path(
        result_dir,
        "Figures",
        c("CurrentSubarea", "PreviousFinalComparison")
      ),
      pre_run_inventory,
      run_started_at,
      "country-summary appendix"
    )
    pdf_validation <- validate_pdf_artifact(required_outputs[[3]])
  }

  list(
    benchmark_results = benchmark_results,
    benchmark_freshness = benchmark_freshness,
    crisis_results = crisis_results,
    crisis_freshness = crisis_freshness,
    benchmark_gap_validation = list(
      path = normalizePath(gap_file, winslash = "/"),
      rows = nrow(gap_rows),
      review_required = any(gap_rows$review_required),
      maximum_nmr_gap_per_1000 = if (any(gap_rows$outcome == "nmr")) {
        max(gap_rows$absolute_gap_per_1000[gap_rows$outcome == "nmr"])
      } else NULL,
      maximum_u5_gap_per_1000 = if (any(gap_rows$outcome == "u5")) {
        max(gap_rows$absolute_gap_per_1000[gap_rows$outcome == "u5"])
      } else NULL
    ),
    deliverables = deliverable_freshness,
    diagnostic_plots = trend_freshness,
    report_plots = report_plot_freshness,
    appendix = appendix_freshness,
    report_pdf = pdf_validation,
    visual_review_required = TRUE
  )
}

write_igme_refresh_manifest <- function(manifest) {
  write_pipeline_manifest(manifest, manifest$manifest_file)
  invisible(manifest$manifest_file)
}

run_igme_refresh <- function(country,
                             mode = "preview",
                             render_summary = TRUE,
                             report_year = 2026L,
                             project_dir = pipeline_project_dir(),
                             prompt = readline,
                             step_executor = run_pipeline_step,
                             preflight_validator = preflight_igme_refresh,
                             output_validator = validate_igme_refresh_outputs) {
  mode <- normalize_pipeline_mode(mode)
  report_year <- normalize_report_year(report_year)
  if (identical(mode, "production") && !isTRUE(render_summary)) {
    stop(
      "Production IGME refresh requires the country summary PDF; ",
      "--skip-summary is preview-only.",
      call. = FALSE
    )
  }
  project_dir <- pipeline_project_dir(project_dir)
  info <- load_igme_refresh_info(project_dir, country)
  active_dir <- file.path(project_dir, "Data", "IGME")
  staged_dir <- file.path(active_dir, "staged")
  staged_state <- classify_staged_igme_release(active_dir, staged_dir)
  source_dir <- if (identical(staged_state$status, "promote")) {
    staged_dir
  } else {
    active_dir
  }
  source_validation <- validate_igme_release(
    source_dir,
    info$values$iso0,
    info$years
  )

  run_id <- pipeline_timestamp()
  result_dir <- file.path(project_dir, "Results", country)
  log_dir <- file.path(result_dir, "logs", paste0(run_id, "_igme_refresh"))
  dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  manifest_file <- file.path(log_dir, "pipeline_manifest.json")
  refresh_targets <- discover_igme_refresh_targets(
    project_dir, country, report_year
  )
  manifest <- list(
    schema_version = 1L,
    task = "igme_release_country_refresh",
    run_id = run_id,
    country = country,
    iso3 = info$values$iso0,
    mode = mode,
    report_year = report_year,
    render_summary = isTRUE(render_summary),
    crisis_adjustment = isTRUE(info$values$doCrisisAdj),
    run_status = "preflight",
    started_at = pipeline_time_iso(),
    completed_at = NULL,
    git = git_refresh_snapshot(project_dir),
    info = list(path = info$path, sha256 = info$sha256),
    years = range(info$years),
    staged_release_status = staged_state$status,
    release_validation = source_validation,
    refresh_targets = file_inventory(refresh_targets),
    igme_backup_dir = NULL,
    igme_backups = list(),
    promoted_release = list(),
    steps = list(),
    preflight = NULL,
    output_validation = NULL,
    visual_review_required = TRUE,
    benchmark_scope = "selected_final_model_only",
    selected_final_model = info$values$final_model,
    comparison_warning = paste(
      "Non-selected benchmark families are retained from earlier runs;",
      "comparison plots may contain benchmarks from an older IGME release."
    ),
    manifest_file = normalizePath(
      manifest_file, winslash = "/", mustWork = FALSE
    )
  )
  write_igme_refresh_manifest(manifest)

  preflight <- tryCatch(
    list(
      ok = TRUE,
      value = preflight_validator(
        project_dir = project_dir,
        country = country,
        info = info,
        render_summary = render_summary
      ),
      error = NULL
    ),
    error = function(e) list(ok = FALSE, value = NULL,
                             error = conditionMessage(e))
  )
  if (!isTRUE(preflight$ok)) {
    manifest$run_status <- "failed_preflight"
    manifest$completed_at <- pipeline_time_iso()
    manifest$error <- preflight$error
    write_igme_refresh_manifest(manifest)
    stop(preflight$error, call. = FALSE)
  }
  manifest$preflight <- preflight$value
  write_igme_refresh_manifest(manifest)

  if (identical(mode, "preview")) {
    manifest$run_status <- "preview_ready"
    manifest$completed_at <- pipeline_time_iso()
    write_igme_refresh_manifest(manifest)
    message("IGME refresh preview ready for ", country, ".")
    message("No source, model, dashboard, plot, or PDF was changed.")
    message("Manifest: ", manifest$manifest_file)
    return(invisible(manifest))
  }

  old_env <- set_pipeline_env(project_dir, country, mode)
  old_wd <- getwd()
  on.exit({
    restore_env(old_env)
    setwd(old_wd)
  }, add = TRUE)
  setwd(project_dir)

  tryCatch({
    if (identical(staged_state$status, "promote")) {
      igme_backup_dir <- file.path(active_dir, "backups", run_id)
      dir.create(igme_backup_dir, recursive = TRUE, showWarnings = FALSE)
      manifest$igme_backup_dir <- normalizePath(
        igme_backup_dir, winslash = "/", mustWork = FALSE
      )
      active_paths <- file.path(active_dir, igme_release_names())
      active_paths <- active_paths[file.exists(active_paths)]
      manifest$igme_backups <- backup_igme_refresh_paths(
        active_paths,
        active_dir,
        igme_backup_dir
      )
      manifest$promoted_release <- promote_staged_igme_release(
        staged_dir,
        active_dir,
        manifest$igme_backups
      )
      validate_igme_release(active_dir, info$values$iso0, info$years)
    }
    manifest$run_status <- "running"
    execution_started_at <- Sys.time()
    manifest$execution_started_at <- pipeline_time_iso(execution_started_at)
    write_igme_refresh_manifest(manifest)

    context <- new.env(parent = globalenv())
    context$project_dir <- project_dir
    context$country <- country
    context$report_year <- report_year
    for (name in names(info$values)) {
      assign(name, info$values[[name]], envir = context)
    }

    all_steps <- c(
      make_pipeline_setup_steps(country, project_dir),
      make_igme_refresh_steps(
        project_dir,
        render_summary,
        crisis_adjustment = isTRUE(info$values$doCrisisAdj)
      )
    )
    for (i in seq_along(all_steps)) {
      result <- step_executor(
        all_steps[[i]],
        i,
        context,
        mode,
        log_dir,
        prompt = prompt
      )
      manifest <- append_step_result(manifest, result)
      write_igme_refresh_manifest(manifest)
      if (!identical(result$status, "completed") &&
          !identical(result$status, "skipped")) {
        stop(
          "IGME refresh stopped at step '", result$step_id, "': ",
          result$error %||% result$reason %||% result$status,
          call. = FALSE
        )
      }
    }

    manifest$output_validation <- output_validator(
      project_dir = project_dir,
      country = country,
      report_year = report_year,
      render_summary = render_summary,
      crisis_adjustment = isTRUE(info$values$doCrisisAdj),
      pre_run_inventory = manifest$refresh_targets,
      run_started_at = execution_started_at,
      log_dir = log_dir
    )
    manifest$run_status <- "completed_pending_visual_review"
    manifest$completed_at <- pipeline_time_iso()
    write_igme_refresh_manifest(manifest)
    message("IGME refresh execution completed for ", country, ".")
    message("Manual visual review is still required before publication.")
    message("Manifest: ", manifest$manifest_file)
    invisible(manifest)
  }, error = function(e) {
    manifest$run_status <- "failed"
    manifest$completed_at <- pipeline_time_iso()
    manifest$error <- conditionMessage(e)
    write_igme_refresh_manifest(manifest)
    stop(conditionMessage(e), call. = FALSE)
  })
}

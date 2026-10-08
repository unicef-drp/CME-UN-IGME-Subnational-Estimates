.project_paths_source_file <- local({
  frames <- sys.frames()
  ofiles <- vapply(frames, function(frame) {
    if (!is.null(frame$ofile)) {
      as.character(frame$ofile)
    } else {
      NA_character_
    }
  }, character(1))
  ofiles <- ofiles[!is.na(ofiles) & nzchar(ofiles)]
  if (length(ofiles) == 0) {
    NA_character_
  } else {
    normalizePath(tail(ofiles, 1), winslash = "/", mustWork = FALSE)
  }
})

.project_paths_default_home <- if (!is.na(.project_paths_source_file)) {
  normalizePath(file.path(dirname(.project_paths_source_file), "..", ".."),
                winslash = "/", mustWork = FALSE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

PROJECT_HOME <- Sys.getenv("UN_SUBNATIONAL_HOME", unset = NA_character_)
if (is.na(PROJECT_HOME) || !nzchar(PROJECT_HOME)) {
  PROJECT_HOME <- if (exists("dir_subnational", inherits = TRUE)) {
    get("dir_subnational", inherits = TRUE)
  } else {
    .project_paths_default_home
  }
}

project_home <- function() {
  root <- Sys.getenv("UN_SUBNATIONAL_HOME", unset = PROJECT_HOME)
  if (!nzchar(root)) {
    root <- PROJECT_HOME
  }
  normalizePath(root, winslash = "/", mustWork = FALSE)
}

crisis_adjustment_enabled <- function(envir = parent.frame()) {
  if (!exists("doCrisisAdj", envir = envir, inherits = TRUE)) {
    return(FALSE)
  }
  enabled <- get("doCrisisAdj", envir = envir, inherits = TRUE)
  if (!is.logical(enabled) || length(enabled) != 1L || is.na(enabled)) {
    stop("doCrisisAdj must be one non-missing logical value.", call. = FALSE)
  }
  isTRUE(enabled)
}

select_crisis_result_file <- function(
    base_file,
    enabled = crisis_adjustment_enabled(parent.frame())) {
  if (length(base_file) != 1L || is.na(base_file) || !nzchar(base_file)) {
    stop("Provide one non-empty base result file path.", call. = FALSE)
  }
  if (!is.logical(enabled) || length(enabled) != 1L || is.na(enabled)) {
    stop("Crisis-adjustment selection must be one logical value.", call. = FALSE)
  }
  base_file <- normalizePath(base_file, winslash = "/", mustWork = FALSE)
  if (!file.exists(base_file)) {
    stop("Base result file does not exist: ", base_file, call. = FALSE)
  }
  if (!isTRUE(enabled)) {
    return(normalizePath(base_file, winslash = "/", mustWork = TRUE))
  }
  if (!grepl("[.]rda$", base_file, ignore.case = TRUE)) {
    stop("Base result file must have an .rda extension: ", base_file, call. = FALSE)
  }
  crisis_file <- sub(
    "[.]rda$",
    "_crisis.rda",
    base_file,
    ignore.case = TRUE
  )
  if (!file.exists(crisis_file)) {
    stop(
      "Crisis adjustment is enabled but the crisis result file does not exist: ",
      crisis_file,
      call. = FALSE
    )
  }
  normalizePath(crisis_file, winslash = "/", mustWork = TRUE)
}

select_comparison_u5_result_file <- function(
    base_file,
    candidate_strata_model,
    candidate_survey_frame,
    final_strata_model,
    enabled = crisis_adjustment_enabled(parent.frame())) {
  candidate_strata_model <- as.character(candidate_strata_model)
  candidate_survey_frame <- as.character(candidate_survey_frame)
  final_strata_model <- as.character(final_strata_model)
  if (length(candidate_strata_model) != 1L ||
      !candidate_strata_model %in% c("strat", "unstrat")) {
    stop("Candidate strata model must be 'strat' or 'unstrat'.", call. = FALSE)
  }
  if (length(candidate_survey_frame) != 1L ||
      !candidate_survey_frame %in% c("same_frame", "all_surveys")) {
    stop(
      "Candidate survey frame must be 'same_frame' or 'all_surveys'.",
      call. = FALSE
    )
  }
  if (length(final_strata_model) != 1L ||
      !final_strata_model %in% c("strat", "unstrat")) {
    stop("Final strata model must be 'strat' or 'unstrat'.", call. = FALSE)
  }

  selected_for_report <-
    (final_strata_model == "strat" &&
       candidate_strata_model == "strat" &&
       candidate_survey_frame == "same_frame") ||
    (final_strata_model == "unstrat" &&
       candidate_strata_model == "unstrat" &&
       candidate_survey_frame == "all_surveys")

  select_crisis_result_file(
    base_file,
    enabled = isTRUE(enabled) && selected_for_report
  )
}

is_absolute_path <- function(path) {
  grepl("^[A-Za-z]:[/\\\\]", path) ||
    grepl("^/", path) ||
    grepl("^\\\\\\\\", path) ||
    grepl("^[A-Za-z][A-Za-z0-9+.-]*://", path)
}

resolve_project_path <- function(path, base_dir = project_home()) {
  if (is.null(path) || length(path) == 0) {
    return(path)
  }
  vapply(path, function(one_path) {
    if (is.na(one_path) || !nzchar(one_path)) {
      return(one_path)
    }
    one_path <- gsub("\\\\", "/", one_path)
    if (is_absolute_path(one_path)) {
      normalizePath(one_path, winslash = "/", mustWork = FALSE)
    } else {
      normalizePath(file.path(base_dir, one_path), winslash = "/", mustWork = FALSE)
    }
  }, character(1), USE.NAMES = FALSE)
}

admin1_only_requested <- function() {
  tolower(Sys.getenv("BB8_ADMIN1_ONLY", unset = "0")) %in%
    c("1", "true", "yes", "y")
}

clear_admin2_context <- function(envir = parent.frame()) {
  admin2_objects <- c(
    "poly.layer.adm2", "poly.label.adm2", "poly.adm2",
    "admin2.names", "admin2.mat", "admin2.nb"
  )
  existing <- intersect(admin2_objects, ls(envir = envir, all.names = TRUE))
  if (length(existing) > 0) {
    rm(list = existing, envir = envir)
  }
  invisible(existing)
}

load.country.info <- function(country,
                              envir = parent.frame(),
                              info_dir = file.path(project_home(), "Info")) {
  if (missing(country) || length(country) != 1 || is.na(country) || !nzchar(country)) {
    stop("Provide one non-empty country name.", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop(
      "Package 'jsonlite' is required to load country Info JSON.",
      call. = FALSE
    )
  }

  info_file <- normalizePath(
    file.path(info_dir, paste0(country, "_general_info.json")),
    winslash = "/",
    mustWork = FALSE
  )
  if (!base::file.exists(info_file)) {
    stop("Country Info JSON file not found: ", info_file, call. = FALSE)
  }

  info_text <- paste(
    base::readLines(info_file, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
  info <- tryCatch(
    jsonlite::fromJSON(info_text, simplifyVector = TRUE),
    error = function(err) {
      stop(
        "Could not parse country Info JSON ", info_file, ": ",
        conditionMessage(err),
        call. = FALSE
      )
    }
  )
  if (!grepl("^\\s*\\{", info_text) ||
      !is.list(info) ||
      is.null(names(info)) ||
      any(is.na(names(info)) | !nzchar(names(info)))) {
    stop(
      "Country Info JSON must contain one named top-level object: ",
      info_file,
      call. = FALSE
    )
  }
  if (is.null(info$country) ||
      length(info$country) != 1 ||
      !nzchar(as.character(info$country))) {
    stop(
      "Country Info JSON is missing a non-empty country field: ",
      info_file,
      call. = FALSE
    )
  }
  if (!identical(as.character(info$country), as.character(country))) {
    stop(
      "Country Info JSON country ", info$country,
      " does not match requested country ", country, ".",
      call. = FALSE
    )
  }

  if (admin1_only_requested()) {
    info[c("poly.layer.adm2", "poly.label.adm2")] <- NULL
    clear_admin2_context(envir)
  }

  for (name in names(info)) {
    assign(name, info[[name]], envir = envir)
  }
  invisible(info_file)
}

has_admin2_layer <- function(envir = parent.frame()) {
  exists("poly.layer.adm2", envir = envir, inherits = TRUE) &&
    !is.null(get("poly.layer.adm2", envir = envir, inherits = TRUE)) &&
    nzchar(as.character(get("poly.layer.adm2", envir = envir, inherits = TRUE))[1])
}

country_data_root <- function(home.dir = project_home()) {
  file.path(home.dir, "Data", "Countries")
}

country_data_dir <- function(home.dir = project_home(),
                             country = get("country", inherits = TRUE)) {
  file.path(country_data_root(home.dir), country)
}

worldpop_data_home <- function(home.dir = project_home()) {
  root <- Sys.getenv("UN_SUBNATIONAL_WORLDPOP_HOME", unset = "")
  if (!nzchar(root)) {
    root <- file.path(home.dir, "..", "..", "Worldpop data")
  }
  normalizePath(root, winslash = "/", mustWork = FALSE)
}

worldpop_raw_dir <- function(country = get("country", inherits = TRUE),
                             root = worldpop_data_home()) {
  file.path(root, "Global1_2000_2020", country)
}

worldpop_population_source_name <- function(year) {
  year <- as.integer(year)
  if (length(year) != 1L || is.na(year)) {
    stop("Provide one population raster year.", call. = FALSE)
  }
  if (year <= 2014L) {
    "Global1_2000_2020_aligned"
  } else {
    "Global2_2015_2030"
  }
}

worldpop_population_age_sex_file <- function(
    year,
    sex,
    age,
    country = get("country", inherits = TRUE),
    iso0 = get("iso0", inherits = TRUE),
    root = worldpop_data_home()) {
  year <- as.integer(year)
  age <- as.integer(age)
  sex <- tolower(as.character(sex))
  iso_upper <- toupper(as.character(iso0))
  iso_lower <- tolower(iso_upper)

  if (length(year) != 1L || is.na(year)) {
    stop("Provide one population raster year.", call. = FALSE)
  }
  if (length(sex) != 1L || !sex %in% c("f", "m")) {
    stop("Population raster sex must be 'f' or 'm'.", call. = FALSE)
  }
  if (length(age) != 1L || is.na(age) || !age %in% c(0L, 1L)) {
    stop("Population raster age band must be 0 or 1.", call. = FALSE)
  }

  if (year <= 2014L) {
    return(file.path(
      root,
      "Global1_2000_2020_aligned",
      paste0(country, "_extracted"),
      as.character(year),
      iso_upper,
      sprintf("%s_%s_%s_%s_constrained_1km.tif",
              iso_lower, sex, age, year)
    ))
  }

  file.path(
    root,
    "Global2_2015_2030",
    country,
    sprintf("%s_%s_%02d_%s_CN_1km_R2025A_UA_v1.tif",
            iso_lower, sex, age, year)
  )
}

population_raster_dir <- function(country = get("country", inherits = TRUE),
                                  root = worldpop_data_home()) {
  file.path(root, "Population", country)
}

country_data_parent <- function(data.dir) {
  data.dir <- normalizePath(data.dir, winslash = "/", mustWork = FALSE)
  if (identical(basename(dirname(data.dir)), "Countries")) {
    dirname(dirname(data.dir))
  } else {
    dirname(data.dir)
  }
}

resolve_country_data_path <- function(path, data.dir = country_data_dir()) {
  shared_data_dirs <- c(
    "shapeFiles", "shapeFiles_alt", "DHS", "MICS", "IGME", "HIV",
    "urban_frames", "Crisis_Adjustment"
  )
  data_root <- country_data_parent(data.dir)

  vapply(path, function(one_path) {
    if (is.na(one_path) || !nzchar(one_path)) {
      return(one_path)
    }
    normalized_path <- gsub("\\\\", "/", one_path)
    shared_match <- regexec("^\\.\\./([^/]+)(/.*)?$", normalized_path)
    shared_parts <- regmatches(normalized_path, shared_match)[[1]]
    if (length(shared_parts) > 0 && shared_parts[2] %in% shared_data_dirs) {
      suffix <- if (length(shared_parts) >= 3 && !is.na(shared_parts[3])) {
        sub("^/", "", shared_parts[3])
      } else {
        ""
      }
      return(normalizePath(file.path(data_root, shared_parts[2], suffix),
                           winslash = "/", mustWork = FALSE))
    }
    resolve_project_path(normalized_path, data.dir)
  }, character(1), USE.NAMES = FALSE)
}

country_data_dirs <- function(home.dir = project_home(), country = get("country", inherits = TRUE)) {
  data.dir <- country_data_dir(home.dir, country)
  c(
    file.path(home.dir, "Data"),
    country_data_root(home.dir),
    data.dir,
    file.path(data.dir, "worldpop"),
    worldpop_raw_dir(country),
    population_raster_dir(country),
    file.path(home.dir, "Data", "shapeFiles"),
    file.path(home.dir, "Data", "MICS", country),
    file.path(home.dir, "Data", "DHS", country)
  )
}

country_result_dirs <- function(res.dir, include_admin2 = has_admin2_layer(parent.frame())) {
  results_root <- dirname(res.dir)
  results_dirs <- c(
    results_root,
    res.dir,
    file.path(res.dir, "Betabinomial"),
    file.path(res.dir, "Betabinomial", "U5MR"),
    file.path(res.dir, "Betabinomial", "NMR"),
    file.path(res.dir, "Direct"),
    file.path(res.dir, "Direct", "U5MR"),
    file.path(res.dir, "Direct", "NMR"),
    file.path(res.dir, "UR"),
    file.path(res.dir, "UR", "Threshold"),
    file.path(res.dir, "UR", "U1_fraction"),
    file.path(res.dir, "UR", "U5_fraction"),
    file.path(res.dir, "Figures"),
    file.path(res.dir, "Figures", "Direct"),
    file.path(res.dir, "Figures", "Direct", "U5MR"),
    file.path(res.dir, "Figures", "Direct", "NMR"),
    file.path(res.dir, "Figures", "Direct", "U5MR", "National"),
    file.path(res.dir, "Figures", "Direct", "U5MR", "Admin1"),
    file.path(res.dir, "Figures", "Direct", "NMR", "National"),
    file.path(res.dir, "Figures", "Direct", "NMR", "Admin1"),
    file.path(res.dir, "Figures", "SmoothedDirect"),
    file.path(res.dir, "Figures", "SmoothedDirect", "U5MR"),
    file.path(res.dir, "Figures", "SmoothedDirect", "NMR")
  )

  if (isTRUE(include_admin2)) {
    results_dirs <- c(
      results_dirs,
      file.path(res.dir, "Figures", "Direct", "U5MR", "Admin2"),
      file.path(res.dir, "Figures", "Direct", "NMR", "Admin2")
    )
  }

  unique(results_dirs)
}

ensure_dirs <- function(paths) {
  for (path in paths) {
    if (!base::dir.exists(path)) {
      base::dir.create(path, recursive = TRUE, showWarnings = FALSE)
    }
  }
  invisible(paths)
}

require_country_context <- function(envir = parent.frame()) {
  required <- c("country", "iso0", "country.abbrev", "beg.year",
                "end.proj.year", "poly.path", "poly.layer.adm0",
                "poly.layer.adm1", "poly.label.adm1", "data.dir", "res.dir")
  missing <- required[!vapply(required, exists, logical(1),
                              envir = envir, inherits = TRUE)]
  if (length(missing) > 0) {
    stop(
      "Country context is missing: ", paste(missing, collapse = ", "),
      ". Run/source Rcode/1_Preperation.R first.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

.path_base_dir <- project_home()
.plot_output_files <- character()
.last_plot_output_file <- NULL

use_path_base <- function(path) {
  .path_base_dir <<- resolve_project_path(path, project_home())
  invisible(.path_base_dir)
}

runtime_path <- function(path) {
  resolve_project_path(path, .path_base_dir)
}

load <- function(file, envir = parent.frame(), ...) {
  base::load(file = runtime_path(file), envir = envir, ...)
}

save <- function(...,
                 list = character(),
                 file = stop("'file' must be specified"),
                 ascii = FALSE,
                 version = NULL,
                 envir = parent.frame(),
                 compress = isTRUE(!ascii),
                 compression_level,
                 eval.promises = TRUE,
                 precheck = TRUE) {
  if (missing(compression_level)) {
    base::save(...,
               list = list,
               file = runtime_path(file),
               ascii = ascii,
               version = version,
               envir = envir,
               compress = compress,
               eval.promises = eval.promises,
               precheck = precheck)
  } else {
    base::save(...,
               list = list,
               file = runtime_path(file),
               ascii = ascii,
               version = version,
               envir = envir,
               compress = compress,
               compression_level = compression_level,
               eval.promises = eval.promises,
               precheck = precheck)
  }
}

read.csv <- function(file, ...) {
  utils::read.csv(file = runtime_path(file), ...)
}

write.csv <- function(x, file = "", ...) {
  utils::write.csv(x, file = runtime_path(file), ...)
}

readRDS <- function(file, ...) {
  base::readRDS(file = runtime_path(file), ...)
}

saveRDS <- function(object, file = "", ...) {
  base::saveRDS(object = object, file = runtime_path(file), ...)
}

file.exists <- function(...) {
  paths <- unlist(list(...), use.names = FALSE)
  base::file.exists(runtime_path(paths))
}

dir.exists <- function(paths) {
  base::dir.exists(runtime_path(paths))
}

list.files <- function(path = ".", ...) {
  base::list.files(path = runtime_path(path), ...)
}

dir.create <- function(path, ...) {
  base::dir.create(path = runtime_path(path), ...)
}

next_available_plot_file <- function(file) {
  file_dir <- dirname(file)
  file_ext <- tools::file_ext(file)
  file_stem <- if (nzchar(file_ext)) {
    sub(paste0("[.]", file_ext, "$"), "", basename(file))
  } else {
    basename(file)
  }
  suffix <- if (nzchar(file_ext)) paste0(".", file_ext) else ""

  for (i in seq_len(999)) {
    candidate <- file.path(
      file_dir,
      paste0(file_stem, "_new", if (i == 1) "" else paste0("_", i), suffix)
    )
    if (!base::file.exists(candidate)) {
      return(candidate)
    }
  }

  stop("Could not find an available plot filename near ", file, call. = FALSE)
}

pdf <- function(file = if (onefile) "Rplots.pdf" else "Rplot%03d.pdf", ...) {
  resolved_file <- runtime_path(file)
  output_file <- resolved_file
  tryCatch(
    grDevices::pdf(file = resolved_file, ...),
    error = function(err) {
      fallback_file <- next_available_plot_file(resolved_file)
      message(
        "Could not open plot file ", resolved_file,
        "; writing to ", fallback_file, " instead: ",
        conditionMessage(err)
      )
      grDevices::pdf(file = fallback_file, ...)
      output_file <<- fallback_file
    }
  )
  .plot_output_files <<- c(.plot_output_files, output_file)
  .last_plot_output_file <<- output_file
  invisible()
}

dev.off <- function(which = grDevices::dev.cur()) {
  result <- grDevices::dev.off(which = which)
  if (length(.plot_output_files) > 0) {
    if (isTRUE(getOption("un_subnational_auto_plot_messages", TRUE))) {
      message("Saved figure: ", .plot_output_files[length(.plot_output_files)])
    }
    .plot_output_files <<- head(.plot_output_files, -1)
  }
  invisible(result)
}

last_plot_file <- function() {
  .last_plot_output_file
}

sink <- function(file = NULL, ...) {
  if (!is.null(file) && !inherits(file, "connection")) {
    file <- runtime_path(file)
  }
  base::sink(file = file, ...)
}

source <- function(file, ...) {
  base::source(file = runtime_path(file), ...)
}

download.file <- function(url, destfile, ...) {
  utils::download.file(url = url, destfile = runtime_path(destfile), ...)
}

raster <- function(x, ...) {
  if (missing(x)) {
    raster::raster(...)
  } else {
    if (is.character(x)) {
      x <- runtime_path(x)
    }
    raster::raster(x = x, ...)
  }
}

write.xlsx <- function(x, file, ...) {
  openxlsx::write.xlsx(x = x, file = runtime_path(file), ...)
}

ggsave <- function(filename = NULL, plot = ggplot2::last_plot(), ..., file = NULL) {
  if (!is.null(file)) {
    if (!is.null(filename) && inherits(filename, "ggplot")) {
      plot <- filename
    }
    filename <- file
  }
  resolved_file <- runtime_path(filename)
  result <- ggplot2::ggsave(filename = resolved_file, plot = plot, ...)
  message("Saved figure: ", resolved_file)
  invisible(result)
}

is_nonempty_rdhs_password <- function(value) {
  is.character(value) &&
    length(value) == 1L &&
    !is.na(value) &&
    nzchar(value)
}

read_windows_user_environment <- function() {
  if (.Platform$OS.type != "windows") {
    return(list())
  }

  tryCatch(
    utils::readRegistry("Environment", hive = "HCU"),
    error = function(e) list()
  )
}

resolve_rdhs_password <- function(
    process_password = Sys.getenv("RDHS_USER_PASS", unset = ""),
    user_environment = NULL) {
  if (is_nonempty_rdhs_password(process_password)) {
    return(process_password)
  }

  if (is.null(user_environment)) {
    user_environment <- read_windows_user_environment()
  }
  user_password <- user_environment[["RDHS_USER_PASS"]]
  if (!is_nonempty_rdhs_password(user_password)) {
    return("")
  }

  Sys.setenv(RDHS_USER_PASS = user_password)
  user_password
}

dhs_dataset_id <- function(dataset_filename) {
  toupper(sub("\\.zip$", "", basename(dataset_filename), ignore.case = TRUE))
}

dhs_dataset_zip_path <- function(year_dir, dataset_filename) {
  file.path(year_dir, paste0(dhs_dataset_id(dataset_filename), ".zip"))
}

dhs_dataset_extract_dir <- function(year_dir, dataset_filename) {
  file.path(year_dir, dhs_dataset_id(dataset_filename))
}

dhs_dataset_expected_pattern <- function(dataset_filename) {
  dataset_id <- dhs_dataset_id(dataset_filename)
  if (grepl("BR", dataset_id)) {
    return("\\.sav$")
  }
  if (grepl("GE", dataset_id)) {
    return("\\.shp$")
  }
  NULL
}

dhs_dataset_complete <- function(year_dir, dataset_filename) {
  extract_dir <- dhs_dataset_extract_dir(year_dir, dataset_filename)
  if (!base::dir.exists(extract_dir)) {
    return(FALSE)
  }

  expected_pattern <- dhs_dataset_expected_pattern(dataset_filename)
  if (is.null(expected_pattern)) {
    return(length(list.files(extract_dir, all.files = FALSE, no.. = TRUE)) > 0)
  }

  length(list.files(extract_dir,
                    pattern = expected_pattern,
                    ignore.case = TRUE,
                    recursive = TRUE,
                    full.names = TRUE)) > 0
}

find_downloaded_dhs_zip <- function(downloaded_paths, dataset_filename, search_dir) {
  dataset_zip <- paste0(dhs_dataset_id(dataset_filename), ".zip")
  candidates <- unique(c(
    normalizePath(unlist(downloaded_paths, use.names = FALSE), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(search_dir, dataset_zip), winslash = "/", mustWork = FALSE),
    normalizePath(
      list.files(search_dir,
                 pattern = paste0("^", dataset_zip, "$"),
                 recursive = TRUE,
                 full.names = TRUE,
                 ignore.case = TRUE),
      winslash = "/",
      mustWork = FALSE
    )
  ))

  candidates <- candidates[base::file.exists(candidates)]
  candidates <- candidates[tolower(basename(candidates)) == tolower(dataset_zip)]
  if (length(candidates) == 0) {
    stop("DHS API download finished, but could not find ", dataset_zip,
         " under ", search_dir, call. = FALSE)
  }
  candidates[[1]]
}

normalize_dhs_download <- function(downloaded_paths, dataset_filename, year_dir) {
  dir.create(year_dir, recursive = TRUE, showWarnings = FALSE)

  zip_source <- find_downloaded_dhs_zip(downloaded_paths, dataset_filename, year_dir)
  zip_target <- dhs_dataset_zip_path(year_dir, dataset_filename)
  if (!identical(normalizePath(zip_source, winslash = "/", mustWork = TRUE),
                 normalizePath(zip_target, winslash = "/", mustWork = FALSE))) {
    file.copy(zip_source, zip_target, overwrite = TRUE)
  }

  extract_dir <- dhs_dataset_extract_dir(year_dir, dataset_filename)
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(zip_target, exdir = extract_dir, overwrite = TRUE)

  list(
    file_name = dataset_filename,
    zip_path = normalizePath(zip_target, winslash = "/", mustWork = FALSE),
    extract_dir = normalizePath(extract_dir, winslash = "/", mustWork = FALSE)
  )
}

ensure_dhs_survey_files <- function(survey_files,
                                    survey_year,
                                    country_name,
                                    dhs_root,
                                    clear_cache = FALSE) {
  survey_files <- unique(as.character(survey_files))
  year_dir <- file.path(dhs_root, country_name, survey_year)
  dir.create(year_dir, recursive = TRUE, showWarnings = FALSE)

  missing_files <- survey_files[!vapply(survey_files,
                                        dhs_dataset_complete,
                                        logical(1),
                                        year_dir = year_dir)]

  if (length(missing_files) == 0) {
    message("DHS files already available for ", country_name, " ", survey_year,
            ": ", year_dir)
  } else {
    if (!nzchar(resolve_rdhs_password())) {
      stop(
        "DHS files are missing for ", country_name, " ", survey_year,
        " and RDHS_USER_PASS is not set, so downloads cannot run noninteractively. Missing: ",
        paste(missing_files, collapse = ", "),
        call. = FALSE
      )
    }
    message("Downloading DHS files for ", country_name, " ", survey_year,
            ": ", paste(missing_files, collapse = ", "))
    downloaded_paths <- rdhs::get_datasets(
      dataset_filenames = missing_files,
      download_option = "zip",
      output_dir_root = year_dir,
      clear_cache = clear_cache
    )

    invisible(lapply(missing_files, function(dataset_filename) {
      normalized <- normalize_dhs_download(downloaded_paths, dataset_filename, year_dir)
      message("Saved DHS zip: ", normalized$zip_path)
      message("Extracted DHS data: ", normalized$extract_dir)
      normalized
    }))
  }

  data.frame(
    file_name = survey_files,
    zip_path = vapply(survey_files,
                      dhs_dataset_zip_path,
                      character(1),
                      year_dir = year_dir),
    extract_dir = vapply(survey_files,
                         dhs_dataset_extract_dir,
                         character(1),
                         year_dir = year_dir),
    available = vapply(survey_files,
                       dhs_dataset_complete,
                       logical(1),
                       year_dir = year_dir),
    stringsAsFactors = FALSE
  )
}

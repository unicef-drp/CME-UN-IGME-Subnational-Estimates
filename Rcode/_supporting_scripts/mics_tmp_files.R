select_mics_tmp_files <- function(mics_dir) {
  if (!base::dir.exists(mics_dir)) {
    return(character())
  }

  candidates <- sort(base::list.files(
    mics_dir,
    pattern = "[.]tmp[.]rda$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  ))
  if (length(candidates) == 0L) {
    return(character())
  }

  survey_key <- sub(
    "([.]geo)?[.]tmp[.]rda$",
    "",
    basename(candidates),
    ignore.case = TRUE
  )
  candidate_groups <- split(candidates, survey_key)

  unname(vapply(sort(names(candidate_groups)), function(key) {
    files <- candidate_groups[[key]]
    geospatial <- files[grepl(
      "[.]geo[.]tmp[.]rda$",
      basename(files),
      ignore.case = TRUE
    )]
    if (length(geospatial) > 0L) geospatial[[1]] else files[[1]]
  }, character(1)))
}

ensure_mics_coordinate_columns <- function(dat) {
  if (!("LONGNUM" %in% names(dat))) {
    dat$LONGNUM <- NA_real_
  }
  if (!("LATNUM" %in% names(dat))) {
    dat$LATNUM <- NA_real_
  }
  dat
}

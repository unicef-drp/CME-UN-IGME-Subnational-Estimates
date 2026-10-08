has_admin2_assignments <- function(data) {
  if (is.null(data) || nrow(data) == 0 || !("admin2.char" %in% names(data))) {
    return(FALSE)
  }

  admin2.char <- as.character(data$admin2.char)
  any(!is.na(admin2.char) & nzchar(trimws(admin2.char)))
}

drop_missing_admin2_rows <- function(data) {
  admin2.char <- as.character(data$admin2.char)
  data[!is.na(admin2.char) & nzchar(trimws(admin2.char)), , drop = FALSE]
}

filter_admin2_birth_lists <- function(births.list, births.list.nmr, survey_years) {
  if (length(births.list) != length(births.list.nmr) ||
      length(births.list) != length(survey_years)) {
    stop("births.list, births.list.nmr, and survey_years must have the same length.",
         call. = FALSE)
  }

  keep <- vapply(births.list, has_admin2_assignments, logical(1))

  list(
    births.list = lapply(births.list[keep], drop_missing_admin2_rows),
    births.list.nmr = lapply(births.list.nmr[keep], drop_missing_admin2_rows),
    survey_years = survey_years[keep]
  )
}

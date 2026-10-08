#' Helpers for country-configured report labels and map layout.

# Resolve exclusions against the saved name mapping: never renumber fitted IDs.
# Only report rows are filtered; saved fits and national aggregates are untouched.
report_excluded_admin_ids <- function(home_dir, country, admin_level = 1L) {
  info <- jsonlite::fromJSON(file.path(home_dir, 'Info',
                                     paste0(country, '_general_info.json')))
  rules <- info$georepo_boundary_exclusions
  if (is.null(rules) || !nrow(rules)) return(character())
  excluded_names <- as.character(rules$name[rules$level == admin_level])
  if (!length(excluded_names)) return(character())
  path <- gsub('\\\\', '/', info$poly.path)
  if (!grepl('^[A-Za-z]:/|^/', path)) {
    path <- if (startsWith(path, '../')) {
      file.path(home_dir, 'Data', substring(path, 4L))
    } else file.path(home_dir, 'Data', 'Countries', country, path)
  }
  env <- new.env(parent = emptyenv())
  load(file.path(path, paste0(country, '_Amat_Names.rda')), envir = env)
  mapping <- get(paste0('admin', admin_level, '.names'), envir = env)
  unique(as.character(mapping$Internal[mapping$GeoRepo %in% excluded_names]))
}

filter_report_admin_rows <- function(data, excluded_ids, column = 'region') {
  if (!length(excluded_ids)) return(data)
  stopifnot(column %in% names(data))
  data[!as.character(data[[column]]) %in% excluded_ids, , drop = FALSE]
}

apply_report_admin_name_map <- function(labels, name_map = NULL) {
  labels <- as.character(labels)
  if (is.null(name_map) || length(name_map) == 0L) {
    return(labels)
  }

  name_map <- unlist(name_map, recursive = TRUE, use.names = TRUE)
  source_names <- names(name_map)
  if (is.null(source_names) ||
      any(is.na(source_names) | !nzchar(trimws(source_names))) ||
      anyDuplicated(source_names)) {
    stop(
      "report_admin_name_map must be a named, unambiguous mapping.",
      call. = FALSE
    )
  }
  if (any(is.na(name_map) | !nzchar(trimws(as.character(name_map))))) {
    stop(
      "report_admin_name_map replacements must be non-empty strings.",
      call. = FALSE
    )
  }

  source_names <- enc2utf8(as.character(source_names))
  replacements <- enc2utf8(as.character(name_map))
  label_index <- match(enc2utf8(labels), source_names)
  replace <- !is.na(label_index)
  labels[replace] <- unname(replacements[label_index[replace]])
  labels
}

report_selected_map_layout <- function(panel_inches = 3.5) {
  panel_inches <- as.numeric(panel_inches)
  if (length(panel_inches) != 1L || !is.finite(panel_inches) ||
      panel_inches <= 0) {
    stop("panel_inches must be one positive finite number.", call. = FALSE)
  }

  nrow <- 2L
  ncol <- 3L
  list(
    nrow = nrow,
    ncol = ncol,
    width = panel_inches * ncol,
    height = panel_inches * nrow
  )
}

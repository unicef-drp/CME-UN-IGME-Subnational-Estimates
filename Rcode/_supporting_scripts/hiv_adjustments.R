normalize_country_hiv_adjustments <- function(hiv.adj, country) {
  if (!is.data.frame(hiv.adj)) {
    stop("HIV adjustments must be stored as a data frame.", call. = FALSE)
  }
  if (!"country" %in% names(hiv.adj)) {
    stop("HIV adjustments are missing the country column.", call. = FALSE)
  }

  country_aliases <- country
  if (identical(country, "Cote_dIvoire")) {
    country_aliases <- c(
      country_aliases,
      "Cote dIvoire",
      "Cote d'Ivoire",
      "C\u00f4te d'Ivoire"
    )
  }
  if (identical(country, "Eswatini")) {
    country_aliases <- c(country_aliases, "Swaziland")
  }

  hiv.adj <- hiv.adj[
    as.character(hiv.adj$country) %in% country_aliases,
    ,
    drop = FALSE
  ]
  if (nrow(hiv.adj) == 0) {
    stop("No HIV adjustments found for ", country, ".", call. = FALSE)
  }
  hiv.adj$country <- country

  if (!"years" %in% names(hiv.adj)) {
    if (!"year" %in% names(hiv.adj)) {
      stop("HIV adjustments are missing the year/years column.", call. = FALSE)
    }
    hiv.adj$years <- hiv.adj$year
  }
  if (!"area" %in% names(hiv.adj)) {
    hiv.adj$area <- country
  } else {
    areas <- as.character(hiv.adj$area)
    areas[areas %in% country_aliases] <- country
    hiv.adj$area <- areas
  }

  required_columns <- c("country", "area", "survey", "years", "ratio")
  missing_columns <- setdiff(required_columns, names(hiv.adj))
  if (length(missing_columns) > 0) {
    stop(
      "HIV adjustments are missing column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
  hiv.adj
}

load_country_hiv_adjustments <- function(path, country) {
  hiv_env <- new.env(parent = emptyenv())
  load(path, envir = hiv_env)
  if (!exists("hiv.adj", envir = hiv_env, inherits = FALSE)) {
    stop("Expected object hiv.adj in ", path, ".", call. = FALSE)
  }

  primary_hiv <- hiv_env$hiv.adj
  country_missing <- is.data.frame(primary_hiv) &&
    "country" %in% names(primary_hiv) &&
    !any(as.character(primary_hiv$country) == country)
  legacy_path <- file.path(dirname(path), "HIVAdjustments_2022.rda")

  if (country_missing && file.exists(legacy_path)) {
    legacy_env <- new.env(parent = emptyenv())
    load(legacy_path, envir = legacy_env)
    if (exists("hiv.adj", envir = legacy_env, inherits = FALSE) &&
        is.data.frame(legacy_env$hiv.adj) &&
        "country" %in% names(legacy_env$hiv.adj) &&
        any(as.character(legacy_env$hiv.adj$country) == country)) {
      message("Using retained 2022 HIV adjustments for ", country,
              " because the primary adjustment file has no matching rows.")
      return(normalize_country_hiv_adjustments(legacy_env$hiv.adj, country))
    }
  }

  normalize_country_hiv_adjustments(primary_hiv, country)
}

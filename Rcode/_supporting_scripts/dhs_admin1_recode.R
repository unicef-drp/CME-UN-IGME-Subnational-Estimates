# Helpers for DHS surveys that report Admin-1 in the births recode but do not
# publish a geographic/GPS dataset. This path is opt-in through country Info.

dhs_admin1_recode_years <- function(config) {
  if (is.null(config) || is.null(config$survey_years)) {
    return(numeric(0))
  }

  years <- suppressWarnings(as.numeric(config$survey_years))
  if (length(years) == 0L || anyNA(years)) {
    stop(
      "dhs_admin1_from_recode$survey_years must contain numeric survey years.",
      call. = FALSE
    )
  }
  unique(years)
}

is_dhs_admin1_recode_survey <- function(config, survey_year) {
  as.numeric(survey_year) %in% dhs_admin1_recode_years(config)
}

select_dhs_surveys_for_processing <- function(potential_surveys, config = NULL,
                                              survey_ids = NULL) {
  if (nrow(potential_surveys) == 0L) {
    return(potential_surveys)
  }

  required_columns <- c("SurveyNum", "SurveyYear", "FileType")
  missing_columns <- setdiff(required_columns, names(potential_surveys))
  if (length(missing_columns) > 0L) {
    stop(
      "DHS dataset inventory is missing: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  configured_survey_ids <- NULL
  if (!is.null(survey_ids)) {
    configured_survey_ids <- suppressWarnings(as.numeric(survey_ids))
    if (length(configured_survey_ids) == 0L || anyNA(configured_survey_ids) ||
        any(!is.finite(configured_survey_ids))) {
      stop("Configured DHS survey IDs must be finite numeric values.", call. = FALSE)
    }
    configured_survey_ids <- unique(configured_survey_ids)
    available_ids <- unique(suppressWarnings(as.numeric(potential_surveys$SurveyNum)))
    missing_ids <- setdiff(configured_survey_ids, available_ids)
    if (length(missing_ids) > 0L) {
      stop(
        "Configured DHS survey ID(s) are absent from the API inventory: ",
        paste(missing_ids, collapse = ", "),
        call. = FALSE
      )
    }
    potential_surveys <- potential_surveys[
      suppressWarnings(as.numeric(potential_surveys$SurveyNum)) %in% configured_survey_ids,
      ,
      drop = FALSE
    ]
  }

  survey_ids <- unique(potential_surveys$SurveyNum)
  keep_ids <- survey_ids[vapply(survey_ids, function(survey_id) {
    survey_rows <- potential_surveys[
      potential_surveys$SurveyNum == survey_id,
      ,
      drop = FALSE
    ]
    file_types <- unique(as.character(survey_rows$FileType))
    survey_years <- unique(suppressWarnings(as.numeric(survey_rows$SurveyYear)))

    has_births <- "Births Recode" %in% file_types
    has_geographic <- "Geographic Data" %in% file_types
    configured_recode <- any(vapply(
      survey_years,
      function(year) is_dhs_admin1_recode_survey(config, year),
      logical(1)
    ))

    has_births && (has_geographic || configured_recode)
  }, logical(1))]

  if (!is.null(configured_survey_ids)) {
    incomplete_ids <- setdiff(configured_survey_ids, suppressWarnings(as.numeric(keep_ids)))
    if (length(incomplete_ids) > 0L) {
      stop(
        "Configured DHS survey ID(s) lack required births/geographic files: ",
        paste(incomplete_ids, collapse = ", "),
        call. = FALSE
      )
    }
  }

  potential_surveys[
    potential_surveys$SurveyNum %in% keep_ids,
    ,
    drop = FALSE
  ]
}

dhs_admin1_recode_config_for_year <- function(config, survey_year) {
  if (!is_dhs_admin1_recode_survey(config, survey_year)) {
    return(NULL)
  }

  if (is.null(config$variable) || length(config$variable) != 1L ||
      !nzchar(trimws(as.character(config$variable)))) {
    stop(
      "dhs_admin1_from_recode$variable must name the labelled Admin-1 variable.",
      call. = FALSE
    )
  }
  config
}

dhs_admin1_recode_cmc_adjust <- function(config, survey_year,
                                          default = 0) {
  year_config <- dhs_admin1_recode_config_for_year(config, survey_year)
  if (is.null(year_config) || is.null(year_config$cmc_adjust)) {
    return(as.numeric(default))
  }

  adjustment <- suppressWarnings(as.numeric(year_config$cmc_adjust))
  if (length(adjustment) != 1L || is.na(adjustment) || !is.finite(adjustment)) {
    stop(
      "dhs_admin1_from_recode$cmc_adjust must be one finite number.",
      call. = FALSE
    )
  }
  adjustment
}

harmonize_dhs_cluster_urbanicity <- function(
    data,
    cluster_variable = "v001",
    respondent_variable = "caseid",
    urban_variable = "v025") {
  required <- c(cluster_variable, respondent_variable, urban_variable)
  missing_columns <- setdiff(required, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      "Cannot harmonize DHS cluster urbanicity; missing: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  original_urban <- data[[urban_variable]]
  if (!is.factor(original_urban) && !is.character(original_urban)) {
    stop(
      "DHS urbanicity must be materialized as factor or character before harmonizing.",
      call. = FALSE
    )
  }

  respondent_rows <- unique(data.frame(
    cluster = data[[cluster_variable]],
    respondent = as.character(data[[respondent_variable]]),
    urbanicity = as.character(original_urban),
    stringsAsFactors = FALSE
  ))
  if (anyNA(respondent_rows) || any(!nzchar(respondent_rows$respondent)) ||
      any(!nzchar(respondent_rows$urbanicity))) {
    stop(
      "DHS cluster, respondent, and urbanicity values must be complete.",
      call. = FALSE
    )
  }

  respondent_key <- interaction(
    respondent_rows$cluster,
    respondent_rows$respondent,
    drop = TRUE,
    lex.order = TRUE
  )
  respondent_inconsistency <- vapply(
    split(respondent_rows$urbanicity, respondent_key),
    function(x) length(unique(x)) > 1L,
    logical(1)
  )
  if (any(respondent_inconsistency)) {
    stop(
      "A DHS respondent has conflicting urbanicity values within a cluster.",
      call. = FALSE
    )
  }

  cluster_groups <- split(
    respondent_rows,
    as.character(respondent_rows$cluster),
    drop = TRUE
  )
  repairs <- list()
  repaired_urban <- as.character(original_urban)
  for (cluster_name in names(cluster_groups)) {
    cluster_rows <- cluster_groups[[cluster_name]]
    counts <- table(cluster_rows$urbanicity)
    if (length(counts) <= 1L) {
      next
    }
    selected <- names(counts)[counts == max(counts)]
    if (length(selected) != 1L) {
      stop(
        "DHS cluster ", cluster_name,
        " has tied respondent counts for urbanicity: ",
        paste(names(counts), as.integer(counts), sep = "=", collapse = ", "),
        call. = FALSE
      )
    }

    cluster_value <- cluster_rows$cluster[[1]]
    repaired_urban[data[[cluster_variable]] == cluster_value] <- selected
    repairs[[length(repairs) + 1L]] <- data.frame(
      cluster = cluster_value,
      observed = paste(names(counts), collapse = "/"),
      selected = selected,
      respondents = as.integer(sum(counts)),
      stringsAsFactors = FALSE
    )
  }

  if (is.factor(original_urban)) {
    data[[urban_variable]] <- factor(
      repaired_urban,
      levels = levels(original_urban),
      ordered = is.ordered(original_urban)
    )
  } else {
    data[[urban_variable]] <- repaired_urban
  }

  repairs <- if (length(repairs) == 0L) {
    data.frame(
      cluster = data[[cluster_variable]][0],
      observed = character(0),
      selected = character(0),
      respondents = integer(0),
      stringsAsFactors = FALSE
    )
  } else {
    do.call(rbind, repairs)
  }

  list(data = data, repairs = repairs)
}

dhs_labelled_admin1_names <- function(values, variable_name) {
  labels <- attr(values, "labels", exact = TRUE)
  if (is.null(labels) || length(labels) == 0L || is.null(names(labels))) {
    stop(
      "DHS Admin-1 variable ", variable_name,
      " must have named value labels.",
      call. = FALSE
    )
  }

  label_names <- trimws(as.character(names(labels)))
  label_values <- suppressWarnings(as.numeric(unname(labels)))
  if (anyNA(label_values) || any(!nzchar(label_names)) ||
      anyDuplicated(label_values)) {
    stop(
      "DHS Admin-1 variable ", variable_name,
      " has invalid or duplicate value labels.",
      call. = FALSE
    )
  }

  numeric_values <- suppressWarnings(as.numeric(values))
  matched <- match(numeric_values, label_values)
  unlabelled <- !is.na(numeric_values) & is.na(matched)
  if (any(unlabelled)) {
    stop(
      "DHS Admin-1 variable ", variable_name,
      " contains observed codes without value labels: ",
      paste(sort(unique(numeric_values[unlabelled])), collapse = ", "),
      call. = FALSE
    )
  }

  label_names[matched]
}

dhs_admin1_names_from_values <- function(values, variable_name) {
  labels <- attr(values, "labels", exact = TRUE)
  if (!is.null(labels) && length(labels) > 0L) {
    return(dhs_labelled_admin1_names(values, variable_name))
  }
  if (is.character(values) || is.factor(values)) {
    return(trimws(as.character(values)))
  }
  stop(
    "DHS Admin-1 variable ", variable_name,
    " must have named value labels or materialized label text.",
    call. = FALSE
  )
}

map_dhs_admin1_names <- function(names_from_recode, config) {
  name_map <- config$name_map
  if (is.null(name_map)) {
    return(names_from_recode)
  }

  name_map <- unlist(name_map, recursive = TRUE, use.names = TRUE)
  if (is.null(names(name_map)) || any(!nzchar(trimws(names(name_map)))) ||
      anyDuplicated(names(name_map))) {
    stop(
      "dhs_admin1_from_recode$name_map must be a named, unambiguous mapping.",
      call. = FALSE
    )
  }

  mapped <- names_from_recode
  mapped_index <- match(names_from_recode, names(name_map))
  replace <- !is.na(mapped_index)
  mapped[replace] <- unname(name_map[mapped_index[replace]])
  trimws(as.character(mapped))
}

validate_dhs_admin1_names <- function(mapped_names, georepo_names, config) {
  georepo_names <- trimws(as.character(georepo_names))
  if (anyNA(georepo_names) || any(!nzchar(georepo_names)) ||
      anyDuplicated(georepo_names)) {
    stop("GeoRepo Admin-1 names must be complete and unique.", call. = FALSE)
  }

  observed <- sort(unique(mapped_names[!is.na(mapped_names)]))
  unmatched <- setdiff(observed, georepo_names)
  if (length(unmatched) > 0L) {
    stop(
      "Mapped DHS Admin-1 label(s) not found in GeoRepo: ",
      paste(unmatched, collapse = ", "),
      call. = FALSE
    )
  }

  require_full <- isTRUE(config$require_full_georepo_coverage)
  if (require_full) {
    missing_regions <- setdiff(georepo_names, observed)
    if (length(missing_regions) > 0L) {
      stop(
        "DHS Admin-1 labels do not cover all GeoRepo regions; missing: ",
        paste(missing_regions, collapse = ", "),
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}

attach_dhs_admin1_from_recode <- function(dat, georepo_names, config,
                                           survey_year) {
  year_config <- dhs_admin1_recode_config_for_year(config, survey_year)
  if (is.null(year_config)) {
    stop(
      "DHS survey ", survey_year,
      " is not configured for Admin-1 assignment from its births recode.",
      call. = FALSE
    )
  }

  variable_name <- tolower(trimws(as.character(year_config$variable)))
  if (!variable_name %in% names(dat)) {
    stop(
      "Configured DHS Admin-1 variable is absent: ", variable_name,
      call. = FALSE
    )
  }

  recode_names <- dhs_admin1_names_from_values(
    dat[[variable_name]],
    variable_name
  )
  mapped_names <- map_dhs_admin1_names(recode_names, year_config)
  validate_dhs_admin1_names(mapped_names, georepo_names, year_config)

  admin1 <- match(mapped_names, georepo_names)
  if (anyNA(admin1)) {
    stop("Every non-missing DHS row must resolve to a GeoRepo Admin-1.", call. = FALSE)
  }

  dat$LONGNUM <- NA_real_
  dat$LATNUM <- NA_real_
  dat$admin1 <- as.integer(admin1)
  dat$admin1.char <- paste0("admin1_", dat$admin1)
  dat$admin1.name <- as.character(georepo_names[dat$admin1])
  dat
}

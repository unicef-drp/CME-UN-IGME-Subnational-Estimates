country_crisis_adjustment_family <- function(country) {
  country <- as.character(country)
  if (length(country) != 1L || is.na(country) || !nzchar(country)) {
    stop("Provide one non-empty country name for crisis adjustment.",
         call. = FALSE)
  }
  if (identical(country, "DR_Congo")) return("cod")
  if (identical(country, "Ethiopia")) return("ethiopia")
  if (identical(country, "Malawi")) return("malawi")
  if (identical(country, "Sudan")) return("sudan")
  if (identical(country, "Myanmar")) return("myanmar")
  if (country %in% c("Guinea", "Haiti", "Liberia", "Sierra_Leone")) {
    return("four_country")
  }
  stop(
    "Crisis adjustment is enabled, but no supported refresh method exists for: ",
    country,
    call. = FALSE
  )
}

crisis_context_value <- function(name, fallback_environment = NULL) {
  defining_environment <- environment(crisis_context_value)
  if (exists(name, envir = defining_environment, inherits = TRUE)) {
    return(get(name, envir = defining_environment, inherits = TRUE))
  }
  if (!is.null(fallback_environment)) {
    value <- Sys.getenv(fallback_environment, unset = NA_character_)
    if (!is.na(value) && nzchar(value)) return(value)
  }
  stop("Crisis refresh context is missing: ", name, call. = FALSE)
}

main <- function() {
  country_name <- crisis_context_value("country", "PIPELINE_COUNTRY")
  project_root <- normalizePath(
    crisis_context_value("project_dir", "UN_SUBNATIONAL_HOME"),
    winslash = "/",
    mustWork = TRUE
  )
  family <- country_crisis_adjustment_family(country_name)
  crisis_dir <- file.path(project_root, "Data", "Crisis_Adjustment")
  implementation <- switch(
    family,
    cod = "apply_cod_crisis_adjustment.R",
    ethiopia = "apply_eth_crisis_adjustment.R",
    malawi = "apply_mwi_crisis_adjustment.R",
    sudan = "apply_sdn_crisis_adjustment.R",
    myanmar = "apply_myanmar_crisis_adjustment.R",
    four_country = "apply_four_country_crisis_adjustments.R"
  )
  implementation_path <- file.path(crisis_dir, implementation)
  if (!file.exists(implementation_path)) {
    stop("Crisis adjustment implementation not found: ", implementation_path,
         call. = FALSE)
  }

  crisis_environment <- new.env(parent = globalenv())
  sys.source(implementation_path, envir = crisis_environment)
  if (identical(family, "cod")) {
    crisis_environment$apply_cod_crisis_adjustment(
      project_root = project_root,
      write_output = TRUE,
      overwrite = TRUE
    )
  } else if (identical(family, "ethiopia")) {
    crisis_environment$prepare_eth_crisis_adjustment(
      project_root = project_root, write_output = TRUE, overwrite = TRUE
    )
    crisis_environment$apply_eth_crisis_adjustment(
      project_root = project_root, write_output = TRUE, overwrite = TRUE
    )
  } else if (identical(family, "sudan")) {
    crisis_environment$prepare_sdn_crisis_adjustment(
      project_root = project_root, write_output = TRUE, overwrite = TRUE
    )
    crisis_environment$apply_sdn_crisis_adjustment(
      project_root = project_root, write_output = TRUE, overwrite = TRUE
    )
  } else if (identical(family, "malawi")) {
    crisis_environment$apply_mwi_crisis_adjustment(
      project_root = project_root, write_output = TRUE, overwrite = TRUE
    )
  } else if (identical(family, "myanmar")) {
    crisis_environment$apply_myanmar_crisis_adjustment(
      project_root = project_root,
      write_output = TRUE,
      overwrite = TRUE
    )
  } else {
    crisis_environment$apply_four_country_crisis_adjustments(
      project_root = project_root,
      write_output = TRUE,
      overwrite = TRUE,
      countries = country_name
    )
  }
  invisible(NULL)
}

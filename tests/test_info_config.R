info_files <- list.files(
  "Info",
  pattern = "_general_info[.]json$",
  full.names = TRUE
)

if (length(info_files) == 0) {
  stop("Checked-in country Info JSON files should exist.")
}

expected_frame_years <- list(
  Afghanistan = NULL,
  Angola = c(2014),
  Bangladesh = c(2011),
  Benin = c(2002, 2013),
  Burkina_Faso = c(2006),
  Burundi = c(2008),
  Cameroon = c(2005),
  Chad = c(2009),
  Congo = c(2007),
  Cote_dIvoire = c(2019),
  Dominican_Republic = c(2002, 2010),
  DR_Congo = c(2003),
  Eswatini = c(1997, 2017),
  Ethiopia = c(2007, 2019),
  Gambia = c(2013),
  Ghana = c(2010),
  Guinea = c(2014, 2017),
  `Guinea-Bissau` = c(2009),
  Haiti = c(2011),
  Kenya = NULL,
  Laos = c(2021),
  Lesotho = c(2016),
  Liberia = c(2008),
  Madagascar = c(2018),
  Malawi = c(2018),
  Mali = c(2009),
  Mauritania = c(2013),
  Mozambique = c(2007),
  Myanmar = c(2014),
  Namibia = c(2011),
  Nepal = c(2011),
  Niger = c(2012),
  Nigeria = c(2006),
  Pakistan = c(2017),
  Philippines = c(2015),
  Rwanda = c(2012),
  Senegal = c(2013),
  Sierra_Leone = c(2004, 2015),
  `South Africa` = c(2011),
  Tajikistan = c(2010, 2020),
  Tanzania = c(2002, 2012),
  `Timor-Leste` = NULL,
  Togo = c(2010, 2015),
  Uganda = c(2002, 2014),
  Zambia = c(2010),
  Zimbabwe = c(2012)
)

expected_surveys_1frame <- list(
  Afghanistan = c(2023),
  Angola = c(2015, 2023),
  Benin = c(2017),
  Burkina_Faso = c(2010),
  Burundi = c(2010, 2016),
  Cameroon = c(2004, 2011),
  Congo = c(2011, 2015),
  Cote_dIvoire = c(2021),
  Dominican_Republic = c(2013),
  DR_Congo = c(2023),
  Eswatini = c(2022),
  Gambia = c(2018, 2019),
  Ghana = c(2011, 2014, 2018),
  Guinea = c(2018),
  `Guinea-Bissau` = c(2010, 2014),
  Haiti = c(2012, 2016),
  Kenya = c(2003, 2008),
  Laos = c(2023),
  Lesotho = c(2018, 2023),
  Liberia = c(2009, 2013, 2019),
  Madagascar = c(2018, 2021),
  Malawi = c(2020, 2024),
  Mali = c(2012, 2018),
  Niger = c(2021),
  Nigeria = c(2010, 2013, 2017, 2018, 2021),
  Pakistan = c(2017),
  Philippines = c(2017, 2022),
  Rwanda = c(2015, 2019),
  Senegal = c(2015, 2016, 2017, 2018, 2019, 2023),
  `South Africa` = c(2016),
  Tajikistan = c(2012, 2017),
  Tanzania = c(2015, 2022),
  `Timor-Leste` = c(2009),
  Togo = c(2013, 2017),
  Uganda = c(2016),
  Zambia = c(2013, 2018),
  Zimbabwe = c(2015, 2019)
)

expected_strata_models <- list(
  Angola = "strat",
  Benin = "strat",
  Burundi = "strat",
  Congo = "strat",
  Gambia = "strat",
  `Guinea-Bissau` = "strat",
  Kenya = "unstrat",
  Madagascar = "strat",
  Mauritania = "strat",
  Myanmar = "unstrat",
  Niger = "unstrat",
  `South Africa` = "unstrat"
)

liberia_info <- jsonlite::fromJSON(
  file.path("Info", "Liberia_general_info.json"),
  simplifyVector = TRUE
)
liberia_exclusions <- liberia_info$georepo_boundary_exclusions
stopifnot(
  is.data.frame(liberia_exclusions),
  nrow(liberia_exclusions) == 1L,
  identical(as.integer(liberia_exclusions$level), 1L),
  identical(
    as.character(liberia_exclusions$name),
    "Under National Administration"
  ),
  identical(
    as.character(liberia_exclusions$reason),
    "GeoRepo feature is not an official Liberia county"
  )
)

for (info_file in info_files) {
  country_from_file <- sub(
    "_general_info[.]json$",
    "",
    basename(info_file)
  )
  info <- jsonlite::fromJSON(info_file, simplifyVector = TRUE)

  if (!country_from_file %in% names(expected_frame_years)) {
    stop(basename(info_file), " is missing from expected_frame_years.")
  }
  stopifnot(identical(info$country, country_from_file))
  stopifnot("frame_year" %in% names(info))
  stopifnot("surveys_1frame" %in% names(info))

  if (!isTRUE(all.equal(
    info$frame_year,
    expected_frame_years[[country_from_file]]
  ))) {
    stop(basename(info_file), " has an unexpected frame_year.")
  }

  expected_surveys <- expected_surveys_1frame[[country_from_file]]
  if (!isTRUE(all.equal(info$surveys_1frame, expected_surveys))) {
    stop(basename(info_file), " has unexpected surveys_1frame.")
  }

  expected_strata_model <- expected_strata_models[[country_from_file]]
  if (is.null(expected_strata_model)) {
    expected_strata_model <- "unstrat"
  }

  if (identical(country_from_file, "Ethiopia")) {
    expected_status <- data.frame(
      model = rep("admin2_smoothed_direct_nmr", 2),
      variant = c("period", "yearly"),
      status = rep("attempted_not_fitted", 2),
      reason = rep("data_sparsity", 2),
      stringsAsFactors = FALSE
    )
    stopifnot(isTRUE(all.equal(info$model_run_status, expected_status)))
  }

  if (identical(country_from_file, "Lesotho")) {
    stopifnot(identical(info$poly.layer.adm2, "georepo_LSO_2"))
    expected_status <- data.frame(
      model = c(
        "admin2_smoothed_direct_nmr",
        "admin2_smoothed_direct_u5"
      ),
      variant = c("period", "yearly"),
      status = rep("attempted_not_fitted", 2),
      reason = rep("data_sparsity", 2),
      stringsAsFactors = FALSE
    )
    stopifnot(isTRUE(all.equal(info$model_run_status, expected_status)))
  }

  stopifnot(
    identical(info$final_model$time.model, "ar1"),
    identical(info$final_model$sd.time.model, "ar1"),
    identical(info$final_model$strata.model, expected_strata_model),
    identical(info$final_model$bench.model, "bench"),
    identical(
      info$info.name,
      paste0(country_from_file, "_general_info.json")
    )
  )

  values <- unlist(info, recursive = TRUE, use.names = FALSE)
  if (any(grepl("C:/|OneDrive - UNICEF", as.character(values)))) {
    stop(basename(info_file), " should not contain a machine-specific path.")
  }
}

cat("Country Info JSON files carry survey and final model settings.\n")

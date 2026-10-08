helper_path <- file.path(
  "Rcode", "_supporting_scripts", "dhs_admin1_recode.R"
)
if (!file.exists(helper_path)) {
  stop("Missing DHS Admin-1 recode helper: ", helper_path)
}
source(helper_path)

info <- jsonlite::fromJSON(
  file.path("Info", "Afghanistan_general_info.json"),
  simplifyVector = TRUE
)
config <- info$dhs_admin1_from_recode

stopifnot(
  is_dhs_admin1_recode_survey(config, 2015),
  !is_dhs_admin1_recode_survey(config, 2023),
  identical(config$variable, "v024"),
  isTRUE(all.equal(config$cmc_adjust, 252)),
  isTRUE(config$require_full_georepo_coverage)
)

api_rows <- data.frame(
  SurveyNum = c(471, 999, 999, 1000),
  SurveyYear = c(2015, 2020, 2020, 2021),
  FileType = c(
    "Births Recode", "Births Recode", "Geographic Data", "Births Recode"
  ),
  FileName = c("AFBR71SV.ZIP", "XXBR.ZIP", "XXGE.ZIP", "YYBR.ZIP"),
  stringsAsFactors = FALSE
)
selected <- select_dhs_surveys_for_processing(api_rows, config)
stopifnot(
  identical(sort(unique(selected$SurveyNum)), c(471, 999)),
  !1000 %in% selected$SurveyNum
)

dom_api_rows <- data.frame(
  SurveyNum = c(291, 291, 439, 439, 490, 490),
  SurveyYear = c(2007, 2007, 2013, 2013, 2013, 2013),
  FileType = rep(c("Births Recode", "Geographic Data"), 3),
  FileName = c(
    "DRBR52SV.ZIP", "DRGE52FL.ZIP",
    "DRBR61SV.ZIP", "DRGE61FL.ZIP",
    "DRBR6ASV.ZIP", "DRGE6AFL.ZIP"
  ),
  stringsAsFactors = FALSE
)
dom_selected <- select_dhs_surveys_for_processing(
  dom_api_rows,
  config = NULL,
  survey_ids = c(291, 439)
)
stopifnot(
  identical(sort(unique(dom_selected$SurveyNum)), c(291, 439)),
  !490 %in% dom_selected$SurveyNum,
  !"DRGE6AFL.ZIP" %in% dom_selected$FileName
)

missing_id_error <- tryCatch(
  {
    select_dhs_surveys_for_processing(
      dom_api_rows,
      config = NULL,
      survey_ids = c(291, 999)
    )
    NULL
  },
  error = identity
)
if (is.null(missing_id_error) ||
    !grepl("configured DHS survey ID", conditionMessage(missing_id_error),
           ignore.case = TRUE)) {
  stop("Configured DHS survey IDs must fail closed when absent from the API inventory.")
}

incomplete_dom_rows <- dom_api_rows[
  !(dom_api_rows$SurveyNum == 439 &
      dom_api_rows$FileType == "Geographic Data"),
  ,
  drop = FALSE
]
incomplete_id_error <- tryCatch(
  {
    select_dhs_surveys_for_processing(
      incomplete_dom_rows,
      config = NULL,
      survey_ids = c(291, 439)
    )
    NULL
  },
  error = identity
)
if (is.null(incomplete_id_error) ||
    !grepl("required births/geographic files", conditionMessage(incomplete_id_error),
           ignore.case = TRUE)) {
  stop("Configured DHS survey IDs must fail closed when a required file type is absent.")
}

province_labels <- c(
  Kabul = 1,
  Wardak = 4,
  Kunarha = 15,
  Nooristan = 16,
  `Sar-E-Pul` = 22,
  Urozgan = 25,
  Helmand = 30,
  Herat = 32
)
province <- structure(
  c(1, 4, 15, 16, 22, 25, 30, 32),
  labels = province_labels,
  class = c("haven_labelled", "vctrs_vctr", "double")
)

georepo <- c(
  "Kabul", "Maidan Wardak", "Kunar", "Nuristan", "Sar-E-Pul",
  "Uruzgan", "Hilmand", "Hirat"
)
dat <- data.frame(v001 = seq_along(province))
dat$v024 <- dhs_labelled_admin1_names(
  province,
  variable_name = "v024"
)

assigned <- attach_dhs_admin1_from_recode(
  dat = dat,
  georepo_names = georepo,
  config = config,
  survey_year = 2015
)

stopifnot(
  identical(assigned$admin1.name, georepo),
  identical(assigned$admin1, seq_along(georepo)),
  identical(assigned$admin1.char, paste0("admin1_", seq_along(georepo))),
  all(is.na(assigned$LONGNUM)),
  all(is.na(assigned$LATNUM))
)

bad_dat <- dat[1, , drop = FALSE]
bad_dat$v024 <- "Unknown Province"
bad_error <- tryCatch(
  {
    attach_dhs_admin1_from_recode(
      dat = bad_dat,
      georepo_names = "Kabul",
      config = config,
      survey_year = 2015
    )
    NULL
  },
  error = identity
)
if (is.null(bad_error) ||
    !grepl("not found in GeoRepo", conditionMessage(bad_error), fixed = TRUE)) {
  stop("Unmatched DHS province labels must fail closed.")
}

cat("DHS Admin-1 recode assignment is explicit and fail-closed.\n")

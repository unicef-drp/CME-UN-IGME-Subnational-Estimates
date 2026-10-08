source(file.path(
  "Rcode", "_supporting_scripts", "hiv_adjustments.R"
))

malawi_hiv <- load_country_hiv_adjustments(
  file.path("Data", "HIV", "HIVAdjustments.rda"),
  country = "Malawi"
)

stopifnot(
  nrow(malawi_hiv) > 0,
  all(c("country", "area", "survey", "years", "ratio") %in%
        names(malawi_hiv)),
  identical(unique(malawi_hiv$country), "Malawi"),
  identical(unique(malawi_hiv$area), "Malawi"),
  all(c(2004, 2010, 2015, 2020, 2024) %in% malawi_hiv$survey),
  !anyNA(malawi_hiv$years),
  !anyNA(malawi_hiv$ratio)
)

message("HIV adjustment loader tests passed")

namibia_hiv <- load_country_hiv_adjustments(
  file.path("Data", "HIV", "HIVAdjustments.rda"),
  country = "Namibia"
)

stopifnot(
  nrow(namibia_hiv) > 0,
  identical(unique(namibia_hiv$country), "Namibia"),
  identical(unique(namibia_hiv$area), "Namibia"),
  all(c(2000, 2006, 2013) %in% namibia_hiv$survey),
  !anyNA(namibia_hiv$years),
  !anyNA(namibia_hiv$ratio)
)

message("Legacy HIV adjustment fallback tests passed")

cote_divoire_hiv <- load_country_hiv_adjustments(
  file.path("Data", "HIV", "HIVAdjustments.rda"),
  country = "Cote_dIvoire"
)

stopifnot(
  nrow(cote_divoire_hiv) > 0,
  identical(unique(cote_divoire_hiv$country), "Cote_dIvoire"),
  identical(unique(cote_divoire_hiv$area), "Cote_dIvoire"),
  all(c(2012, 2021) %in% cote_divoire_hiv$survey),
  !anyNA(cote_divoire_hiv$years),
  !anyNA(cote_divoire_hiv$ratio)
)

message("Cote dIvoire HIV adjustment alias tests passed")

eswatini_hiv <- load_country_hiv_adjustments(
  file.path("Data", "HIV", "HIVAdjustments.rda"),
  country = "Eswatini"
)

stopifnot(
  nrow(eswatini_hiv) > 0,
  identical(unique(eswatini_hiv$country), "Eswatini"),
  identical(unique(eswatini_hiv$area), "Eswatini"),
  all(c(2006, 2022) %in% eswatini_hiv$survey),
  !anyNA(eswatini_hiv$years),
  !anyNA(eswatini_hiv$ratio)
)

message("Eswatini HIV adjustment alias tests passed")

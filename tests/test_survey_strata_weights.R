source("Rcode/_supporting_scripts/survey_strata_weights.R")

mod.dat <- data.frame(
  survey = c(2018, 2018, 2018, 2021, 2021, 2021),
  cluster = c(1, 2, 3, 1, 2, 3),
  urban = c("urban", "rural", "urban", "urban", "rural", "rural"),
  v005 = c(2, 1, 1, 2, 2, 2),
  admin1.char = c("admin1_1", "admin1_1", "admin1_2",
                  "admin1_1", "admin1_1", "admin1_2"),
  admin2.char = c("admin2_1", "admin2_1", "admin2_2",
                  "admin2_1", "admin2_1", "admin2_2")
)

admin1.names <- data.frame(Internal = c("admin1_1", "admin1_2"))
admin2.names <- data.frame(Internal = c("admin2_1", "admin2_2"))

weights <- derive_survey_strata_weights(
  mod.dat = mod.dat,
  beg.year = 2000,
  end.proj.year = 2001,
  admin1.names = admin1.names,
  admin2.names = admin2.names
)

stopifnot(isTRUE(all.equal(weights$weight.strata.natl.u1$urban, rep(0.5, 2))))
stopifnot(isTRUE(all.equal(weights$weight.strata.natl.u5$urban, rep(0.5, 2))))
stopifnot(isTRUE(all.equal(
  weights$weight.strata.adm1.u1[weights$weight.strata.adm1.u1$region == "admin1_1", "urban"],
  rep(4 / 7, 2)
)))
stopifnot(isTRUE(all.equal(
  weights$weight.strata.adm2.u5[weights$weight.strata.adm2.u5$region == "admin2_2", "urban"],
  rep(1 / 3, 2)
)))
stopifnot(all(weights$weight.strata.adm1.u1$urban + weights$weight.strata.adm1.u1$rural == 1))
stopifnot(all(weights$weight.strata.adm2.u5$urban + weights$weight.strata.adm2.u5$rural == 1))

admin2.names.with.gap <- data.frame(Internal = c("admin2_1", "admin2_2", "admin2_3"))
missing_error <- try(
  derive_survey_strata_weights(
    mod.dat = mod.dat,
    beg.year = 2000,
    end.proj.year = 2000,
    admin1.names = admin1.names,
    admin2.names = admin2.names.with.gap
  ),
  silent = TRUE
)
stopifnot(inherits(missing_error, "try-error"))

weights_with_fallback <- derive_survey_strata_weights(
  mod.dat = mod.dat,
  beg.year = 2000,
  end.proj.year = 2000,
  admin1.names = admin1.names,
  admin2.names = admin2.names.with.gap,
  missing_region_fallback = "national"
)
fallback_row <- weights_with_fallback$weight.strata.adm2.u1[
  weights_with_fallback$weight.strata.adm2.u1$region == "admin2_3", ]
stopifnot(isTRUE(all.equal(fallback_row$urban, 0.5)))

admin1_only_mod.dat <- mod.dat
admin1_only_mod.dat$admin2.char <- NA_character_
admin1_only_weights <- derive_survey_strata_weights(
  mod.dat = admin1_only_mod.dat,
  beg.year = 2000,
  end.proj.year = 2000,
  admin1.names = admin1.names,
  admin2.names = admin2.names,
  missing_region_fallback = "national"
)
stopifnot(isTRUE(all.equal(
  admin1_only_weights$weight.strata.adm2.u1$urban,
  rep(0.5, nrow(admin2.names))
)))

cat("Survey-derived strata weights cover national, Admin1, and Admin2 levels.\n")

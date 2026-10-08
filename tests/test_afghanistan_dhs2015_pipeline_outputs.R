full_path <- file.path(
  "Data", "Countries", "Afghanistan", "Afghanistan_cluster_dat.rda"
)
same_frame_path <- file.path(
  "Data", "Countries", "Afghanistan", "Afghanistan_cluster_dat_1frame.rda"
)
prior_path <- file.path(
  "Data", "Countries", "Afghanistan",
  "Afghanistan_age_int_priors_bench.rda"
)

stopifnot(
  file.exists(full_path),
  file.exists(same_frame_path),
  file.exists(prior_path)
)

full_env <- new.env(parent = emptyenv())
load(full_path, envir = full_env)
full <- full_env$mod.dat

same_env <- new.env(parent = emptyenv())
load(same_frame_path, envir = same_env)
same_frame <- same_env$mod.dat

expected_surveys <- c(2015, 2023)
stopifnot(
  identical(sort(unique(as.numeric(full$survey))), expected_surveys),
  identical(sort(unique(as.numeric(same_frame$survey))), 2023),
  all(full$survey.type[full$survey == 2015] == "DHS"),
  all(full$survey.type[full$survey == 2023] == "MICS"),
  !anyNA(full$admin1),
  !anyNA(full$admin1.name),
  all(is.na(full$LONGNUM[full$survey == 2015])),
  all(is.na(full$LATNUM[full$survey == 2015])),
  length(unique(full$cluster[full$survey == 2015])) == 956L,
  length(unique(full$cluster[full$survey == 2023])) == 972L,
  length(unique(full$admin1.name[full$survey == 2015])) == 34L,
  length(unique(full$admin1.name[full$survey == 2023])) == 34L,
  nrow(same_frame) == sum(full$survey == 2023)
)

expected_alias_targets <- c(
  "Maidan Wardak", "Kunar", "Nuristan", "Uruzgan", "Hilmand", "Hirat"
)
if (!all(expected_alias_targets %in%
         unique(full$admin1.name[full$survey == 2015]))) {
  stop("Afghanistan DHS 2015 is missing mapped GeoRepo province names.")
}

prior_env <- new.env(parent = emptyenv())
load(prior_path, envir = prior_env)
stopifnot(
  length(prior_env$int.priors.bench) == 6L,
  all(is.finite(prior_env$int.priors.bench))
)

cat(
  "Afghanistan full data use DHS 2015 + MICS 2023; same-frame data use MICS 2023 only.\n"
)

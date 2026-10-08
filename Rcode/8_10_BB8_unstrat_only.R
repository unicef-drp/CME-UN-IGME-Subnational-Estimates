USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}


# Step 8: Beta-Binomial estimates, unstratified models only.


library(SUMMER)
library(INLA)
inla.setOption(inla.mode = "experimental")
options(gsubfn.engine = "R")
library(tidyverse)

home.dir <- project_home()
data.dir <- country_data_dir(home.dir, country)
res.dir <- file.path(home.dir, "Results", country)
require_country_context()
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}
bb8_admin1_only <- tolower(Sys.getenv("BB8_ADMIN1_ONLY", "0")) %in%
  c("1", "true", "yes", "y")
run_admin2_bb8 <- exists("poly.layer.adm2", inherits = TRUE) && !bb8_admin1_only
if (bb8_admin1_only) {
  message("BB8_ADMIN1_ONLY=1; skipping Admin-2 BB8 fits in this run.")
}

source(file = file.path(home.dir, "Rcode", "_supporting_scripts", "smoothCluster_mod.R"))
source(file = file.path(home.dir, "Rcode", "_supporting_scripts", "getBB8.R"))
source(file = file.path(home.dir, "Rcode", "_supporting_scripts", "hiv_adjustments.R"))
source(file = file.path(home.dir, "Rcode", "_supporting_scripts", "bb8_temporal_diagnostics.R"))

use_path_base(data.dir)
load(file.path(poly.path, paste0(country, "_Amat.rda")))
load(file.path(poly.path, paste0(country, "_Amat_Names.rda")))
load(file.path(data.dir, "worldpop", "adm1_weights_u1.rda"))
load(file.path(data.dir, "worldpop", "adm1_weights_u5.rda"))
if (run_admin2_bb8) {
  load(file.path(data.dir, "worldpop", "adm2_weights_u1.rda"))
  load(file.path(data.dir, "worldpop", "adm2_weights_u5.rda"))
}

use_path_base(file.path(home.dir, "Data", "IGME"))

igme.ests.u5.raw <- read.csv("igme2026_u5_nocrisis.csv")
igme.ests.u5 <- igme.ests.u5.raw[igme.ests.u5.raw$ISO.Code == iso0, ]
igme.ests.u5 <- data.frame(t(igme.ests.u5[, 10:ncol(igme.ests.u5)]))
names(igme.ests.u5) <- c("LOWER_BOUND", "OBS_VALUE", "UPPER_BOUND")
igme.ests.u5$year <- as.numeric(stringr::str_remove(row.names(igme.ests.u5), "X")) - 0.5
igme.ests.u5 <- igme.ests.u5[igme.ests.u5$year %in% beg.year:end.proj.year, ]
row.names(igme.ests.u5) <- NULL
igme.ests.u5$OBS_VALUE <- igme.ests.u5$OBS_VALUE / 1000
igme.ests.u5$LOWER_BOUND <- igme.ests.u5$LOWER_BOUND / 1000
igme.ests.u5$UPPER_BOUND <- igme.ests.u5$UPPER_BOUND / 1000
igme.ests.u5$SD <- (igme.ests.u5$UPPER_BOUND - igme.ests.u5$LOWER_BOUND) / (2 * 1.645)

igme.ests.nmr.raw <- read.csv("igme2026_nmr_nocrisis.csv")
igme.ests.nmr <- igme.ests.nmr.raw[igme.ests.nmr.raw$ISO.Code == iso0, ]
igme.ests.nmr <- data.frame(t(igme.ests.nmr[, 10:ncol(igme.ests.nmr)]))
names(igme.ests.nmr) <- c("LOWER_BOUND", "OBS_VALUE", "UPPER_BOUND")
igme.ests.nmr$year <- as.numeric(stringr::str_remove(row.names(igme.ests.nmr), "X")) - 0.5
igme.ests.nmr <- igme.ests.nmr[igme.ests.nmr$year %in% beg.year:end.proj.year, ]
row.names(igme.ests.nmr) <- NULL
igme.ests.nmr$OBS_VALUE <- igme.ests.nmr$OBS_VALUE / 1000
igme.ests.nmr$LOWER_BOUND <- igme.ests.nmr$LOWER_BOUND / 1000
igme.ests.nmr$UPPER_BOUND <- igme.ests.nmr$UPPER_BOUND / 1000
igme.ests.nmr$SD <- (igme.ests.nmr$UPPER_BOUND - igme.ests.nmr$LOWER_BOUND) / (2 * 1.645)

prepare_model_data <- function(data_file) {
  use_path_base(data.dir)
  data_env <- new.env(parent = emptyenv())
  load(data_file, envir = data_env)
  mod.dat <- data_env$mod.dat
  mod.dat$years <- as.numeric(as.character(mod.dat$years))
  mod.dat$country <- as.character(country)
  survey_years <- unique(mod.dat$survey)
  message("The surveys used are: ", paste(survey_years, collapse = ", "))

  if (doHIVAdj) {
    hiv.adj <- load_country_hiv_adjustments(
      file.path(home.dir, "Data", "HIV", "HIVAdjustments.rda"),
      country
    )
    natl.unaids <- unique(hiv.adj$area)[1] == country

    if (natl.unaids) {
      adj.frame <- hiv.adj
      adj.varnames <- c("country", "survey", "years")
    } else {
      adj.frame <- hiv.adj
      mod.dat$area <- mod.dat$admin1.name
      if (country == "Mozambique") {
        mod.dat[mod.dat$area == "Maputo City", ]$area <- "Maputo"
      }
      adj.varnames <- c("country", "area", "survey", "years")
    }
    adj.frame <- adj.frame[adj.frame$survey %in% survey_years, c(adj.varnames, "ratio")]
  } else {
    adj.frame <- expand.grid(years = beg.year:end.proj.year, country = country)
    adj.frame$ratio <- 1
    adj.varnames <- c("country", "years")
  }

  list(mod.dat = mod.dat, adj.frame = adj.frame, adj.varnames = adj.varnames)
}

save_bb_components <- function(bb, metric_dir, file_stub, var_stub) {
  use_path_base(res.dir)
  fit <- bb[[1]]
  res <- bb[[2]]
  temporals <- bb8_get_temporal_diag(bb$fit,
    admin_level = if (startsWith(file_stub, "adm2")) "Admin2" else if (startsWith(file_stub, "adm1")) "Admin1" else "National",
    year_label = beg.year:end.proj.year)
  hyperpar <- fit$fit$summary.hyperpar
  fixed <- fit$fit$summary.fixed

  fit_var <- paste0("bb.fit.", var_stub)
  res_var <- paste0("bb.res.", var_stub)
  temporals_var <- paste0("bb.temporals.", var_stub)
  hyperpar_var <- paste0("bb.hyperpar.", var_stub)
  fixed_var <- paste0("bb.fixed.", var_stub)

  assign(fit_var, fit, envir = .GlobalEnv)
  assign(res_var, res, envir = .GlobalEnv)
  assign(temporals_var, temporals, envir = .GlobalEnv)
  assign(hyperpar_var, hyperpar, envir = .GlobalEnv)
  assign(fixed_var, fixed, envir = .GlobalEnv)

  sink(file = file.path("Betabinomial", metric_dir, paste0(country, "_fit_", file_stub, ".txt")))
  if (!is.null(res$benchmark)) cat("Direct national calibration; diagnostics describe the HIV-only source fit.\n")
  summary(fit)
  sink(file = NULL)

  save(list = temporals_var, file = file.path("Betabinomial", metric_dir, paste0(country, "_temporals_", file_stub, ".rda")))
  save(list = hyperpar_var, file = file.path("Betabinomial", metric_dir, paste0(country, "_hyperpar_", file_stub, ".rda")))
  save(list = fixed_var, file = file.path("Betabinomial", metric_dir, paste0(country, "_fixed_", file_stub, ".rda")))
  save(list = res_var, file = file.path("Betabinomial", metric_dir, paste0(country, "_res_", file_stub, ".rda")))
}

run_unstrat_bb <- function(model_data, admin.level, Amat, outcome, metric_dir,
                           file_stub, var_stub, adj.frame = model_data$adj.frame) {
  use_path_base(res.dir)
  message("Fitting ", file_stub)
  bb <- getBB8(
    model_data$mod.dat,
    country,
    beg.year = beg.year,
    end.year = end.proj.year,
    Amat = Amat,
    admin.level = admin.level,
    stratified = FALSE,
    weight.strata = NULL,
    outcome = outcome,
    time.model = "ar1",
    st.time.model = "ar1",
    adj.frame = adj.frame,
    adj.varnames = model_data$adj.varnames,
    nsim = 1000
  )
  save_bb_components(bb, metric_dir, file_stub, var_stub)
  bb
}

source(file.path(home.dir, "Rcode", "_supporting_scripts", "admin_benchmark_helpers.R"))

benchmark_adjustment <- function(bb, igme.ests, metric_dir, benchmark_file, weights) {
  bench.adj <- compute_admin_benchmark_adjustment(
    country, beg.year:end.proj.year, bb$results$draws.est.overall, weights, igme.ests)
  save(bench.adj, file=file.path("Betabinomial", metric_dir, benchmark_file))
  bench.adj
}

use_path_base(res.dir)
dir.create(file.path("Betabinomial", "NMR"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("Betabinomial", "U5MR"), recursive = TRUE, showWarnings = FALSE)

all_surveys <- prepare_model_data(paste0(country, "_cluster_dat.rda"))

bb.natl.unstrat.nmr.allsurveys <- run_unstrat_bb(
  all_surveys, "National", NULL, "nmr", "NMR",
  "natl_unstrat_nmr_allsurveys", "natl.unstrat.nmr.allsurveys"
)
bb.adm1.unstrat.nmr.allsurveys <- run_unstrat_bb(
  all_surveys, "Admin1", admin1.mat, "nmr", "NMR",
  "adm1_unstrat_nmr_allsurveys", "adm1.unstrat.nmr.allsurveys"
)
bb.natl.unstrat.u5.allsurveys <- run_unstrat_bb(
  all_surveys, "National", NULL, "u5mr", "U5MR",
  "natl_unstrat_u5_allsurveys", "natl.unstrat.u5.allsurveys"
)
bb.adm1.unstrat.u5.allsurveys <- run_unstrat_bb(
  all_surveys, "Admin1", admin1.mat, "u5mr", "U5MR",
  "adm1_unstrat_u5_allsurveys", "adm1.unstrat.u5.allsurveys"
)

bench.adj <- benchmark_adjustment(
  bb.adm1.unstrat.nmr.allsurveys,
  igme.ests.nmr,
  "NMR",
  "adm1_unstrat_nmr_benchmarks.rda",
  weight.adm1.u1
)
bb.adm1.unstrat.nmr.allsurveys.bench <- bb.adm1.unstrat.nmr.allsurveys
bb.adm1.unstrat.nmr.allsurveys.bench$results <- benchmark_admin_result(bb.adm1.unstrat.nmr.allsurveys$results, bench.adj)
save_bb_components(bb.adm1.unstrat.nmr.allsurveys.bench, "NMR", "adm1_unstrat_nmr_allsurveys_bench", "adm1.unstrat.nmr.allsurveys.bench")


bench.adj <- benchmark_adjustment(
  bb.adm1.unstrat.u5.allsurveys,
  igme.ests.u5,
  "U5MR",
  "adm1_unstrat_u5_benchmarks.rda",
  weight.adm1.u5
)
bb.adm1.unstrat.u5.allsurveys.bench <- bb.adm1.unstrat.u5.allsurveys
bb.adm1.unstrat.u5.allsurveys.bench$results <- benchmark_admin_result(bb.adm1.unstrat.u5.allsurveys$results, bench.adj)
save_bb_components(bb.adm1.unstrat.u5.allsurveys.bench, "U5MR", "adm1_unstrat_u5_allsurveys_bench", "adm1.unstrat.u5.allsurveys.bench")


if (run_admin2_bb8) {
  bb.adm2.unstrat.nmr.allsurveys <- run_unstrat_bb(
    all_surveys, "Admin2", admin2.mat, "nmr", "NMR",
    "adm2_unstrat_nmr_allsurveys", "adm2.unstrat.nmr.allsurveys"
  )
  bb.adm2.unstrat.u5.allsurveys <- run_unstrat_bb(
    all_surveys, "Admin2", admin2.mat, "u5mr", "U5MR",
    "adm2_unstrat_u5_allsurveys", "adm2.unstrat.u5.allsurveys"
  )

  bench.adj <- benchmark_adjustment(
    bb.adm2.unstrat.nmr.allsurveys,
    igme.ests.nmr,
    "NMR",
    "adm2_unstrat_nmr_benchmarks.rda",
  weight.adm2.u1
)
bb.adm2.unstrat.nmr.allsurveys.bench <- bb.adm2.unstrat.nmr.allsurveys
bb.adm2.unstrat.nmr.allsurveys.bench$results <- benchmark_admin_result(bb.adm2.unstrat.nmr.allsurveys$results, bench.adj)
save_bb_components(bb.adm2.unstrat.nmr.allsurveys.bench, "NMR", "adm2_unstrat_nmr_allsurveys_bench", "adm2.unstrat.nmr.allsurveys.bench")


  bench.adj <- benchmark_adjustment(
    bb.adm2.unstrat.u5.allsurveys,
    igme.ests.u5,
    "U5MR",
    "adm2_unstrat_u5_benchmarks.rda",
  weight.adm2.u5
)
bb.adm2.unstrat.u5.allsurveys.bench <- bb.adm2.unstrat.u5.allsurveys
bb.adm2.unstrat.u5.allsurveys.bench$results <- benchmark_admin_result(bb.adm2.unstrat.u5.allsurveys$results, bench.adj)
save_bb_components(bb.adm2.unstrat.u5.allsurveys.bench, "U5MR", "adm2_unstrat_u5_allsurveys_bench", "adm2.unstrat.u5.allsurveys.bench")

} else {
  message("No admin2 adjacency matrix found; skipping Admin2 BB8 fits.")
}

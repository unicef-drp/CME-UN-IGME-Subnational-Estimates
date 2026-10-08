USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}



# This legacy backfill must not create a non-selected comparison benchmark.
if (identical(final_model$strata.model, "unstrat") &&
    identical(final_model$bench.model, "bench")) {
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

source(file = file.path(home.dir, "Rcode", "_supporting_scripts", "smoothCluster_mod.R"))
source(file = file.path(home.dir, "Rcode", "_supporting_scripts", "getBB8.R"))
source(file = file.path(home.dir, "Rcode", "_supporting_scripts", "admin_benchmark_helpers.R"))
source(file = file.path(home.dir, "Rcode", "_supporting_scripts", "hiv_adjustments.R"))

use_path_base(data.dir)
load(file.path(poly.path, paste0(country, "_Amat.rda")))
load(file.path(poly.path, paste0(country, "_Amat_Names.rda")))
load(file.path(data.dir, "worldpop", "adm1_weights_u1.rda"))
load(file.path(data.dir, "worldpop", "adm1_weights_u5.rda"))

load(paste0(country, "_cluster_dat.rda"), envir = .GlobalEnv)
mod.dat$years <- as.numeric(as.character(mod.dat$years))
mod.dat$country <- as.character(country)
survey_years <- unique(mod.dat$survey)
message("The surveys used are: ", paste(survey_years, collapse = ", "))

use_path_base(file.path(home.dir, "Data", "IGME"))

igme.ests.u5.raw <- read.csv("igme2026_u5_nocrisis.csv")
igme.ests.u5 <- igme.ests.u5.raw[igme.ests.u5.raw$ISO.Code == iso0, ]
igme.ests.u5 <- data.frame(t(igme.ests.u5[, 10:ncol(igme.ests.u5)]))
names(igme.ests.u5) <- c("LOWER_BOUND", "OBS_VALUE", "UPPER_BOUND")
igme.ests.u5$year <- as.numeric(stringr::str_remove(row.names(igme.ests.u5), "X")) - 0.5
igme.ests.u5 <- igme.ests.u5[igme.ests.u5$year %in% beg.year:end.proj.year, ]
row.names(igme.ests.u5) <- NULL
igme.ests.u5$OBS_VALUE <- igme.ests.u5$OBS_VALUE / 1000

igme.ests.nmr.raw <- read.csv("igme2026_nmr_nocrisis.csv")
igme.ests.nmr <- igme.ests.nmr.raw[igme.ests.nmr.raw$ISO.Code == iso0, ]
igme.ests.nmr <- data.frame(t(igme.ests.nmr[, 10:ncol(igme.ests.nmr)]))
names(igme.ests.nmr) <- c("LOWER_BOUND", "OBS_VALUE", "UPPER_BOUND")
igme.ests.nmr$year <- as.numeric(stringr::str_remove(row.names(igme.ests.nmr), "X")) - 0.5
igme.ests.nmr <- igme.ests.nmr[igme.ests.nmr$year %in% beg.year:end.proj.year, ]
row.names(igme.ests.nmr) <- NULL
igme.ests.nmr$OBS_VALUE <- igme.ests.nmr$OBS_VALUE / 1000

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
  adj.frame <- adj.frame[adj.frame$survey %in% survey_years,
                         c(adj.varnames, "ratio")]
} else {
  adj.frame <- expand.grid(years = beg.year:end.proj.year, country = country)
  adj.frame$ratio <- 1
  adj.varnames <- c("country", "years")
}

use_path_base(res.dir)
dir.create(file.path("Betabinomial", "NMR"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("Betabinomial", "U5MR"), recursive = TRUE, showWarnings = FALSE)

run_admin1_unstrat_benchmark <- function(outcome,
                                         igme.ests,
                                         out_dir,
                                         short_name,
                                         admin_weights) {
  result_file <- file.path("Betabinomial", out_dir,
                           paste0(country, "_res_adm1_unstrat_", short_name,
                                   "_allsurveys_bench.rda"))
  force <- tolower(Sys.getenv("BB8_FORCE_ADMIN1_UNSTRAT_BENCHMARK", "0")) %in%
    c("1", "true", "yes", "y")
  if (is_direct_benchmark_file(result_file) && !force) {
    message("Skipping existing file: ", result_file)
    return(invisible(NULL))
  }

  unbench_name <- paste0("bb.res.adm1.unstrat.", short_name, ".allsurveys")
  unbench_file <- file.path("Betabinomial", out_dir,
                            paste0(country, "_res_adm1_unstrat_", short_name,
                                   "_allsurveys.rda"))
  if (file.exists(unbench_file)) {
    unbench_env <- new.env(parent = emptyenv())
    load(unbench_file, envir = unbench_env)
    bb.res.unbench <- get(unbench_name, envir = unbench_env)
  } else {
    message("Fitting Admin-1 unstratified all-survey ", toupper(short_name),
            " model for benchmark ratio.")
    bb.unbench <- getBB8(mod.dat, country,
                         beg.year = beg.year, end.year = end.proj.year,
                         Amat = admin1.mat, admin.level = "Admin1",
                         stratified = FALSE, weight.strata = NULL,
                         outcome = outcome,
                         time.model = "ar1", st.time.model = "ar1",
                         adj.frame = adj.frame, adj.varnames = adj.varnames,
                         nsim = 1000)
    bb.res.unbench <- bb.unbench[[2]]
    base_stub <- paste0("adm1_unstrat_", short_name, "_allsurveys")
    for (component in c("temporals", "hyperpar", "fixed", "res")) {
      value <- switch(component,
        temporals=getDiag(bb.unbench$fit, field="time", year_label=beg.year:end.proj.year),
        hyperpar=bb.unbench$fit$fit$summary.hyperpar,
        fixed=bb.unbench$fit$fit$summary.fixed, res=bb.res.unbench)
      name <- paste0("bb.", component, ".adm1.unstrat.", short_name, ".allsurveys")
      assign(name, value, envir=.GlobalEnv)
      save(list=name, file=file.path("Betabinomial", out_dir, paste0(country, "_", component, "_", base_stub, ".rda")))
    }
    capture.output(summary(bb.unbench$fit), file=file.path("Betabinomial", out_dir, paste0(country, "_fit_", base_stub, ".txt")))

  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.unbench$draws.est.overall,
    admin_weights = admin_weights,
    igme_ests = igme.ests
  )
  save(bench.adj,
       file = file.path("Betabinomial", out_dir,
                        paste0("adm1_unstrat_", short_name, "_benchmarks.rda")))

  bb.res.bench <- benchmark_admin_result(bb.res.unbench, bench.adj)
  res.name <- paste0("bb.res.adm1.unstrat.", short_name, ".allsurveys.bench")
  assign(res.name, bb.res.bench, envir=.GlobalEnv)
  save(list=res.name, file=result_file)
  base_stub <- paste0("adm1_unstrat_", short_name, "_allsurveys")
  save_benchmark_source_diagnostics(country, out_dir, base_stub, paste0(base_stub, "_bench"))
  message("Saved ", result_file)
}

run_admin1_unstrat_benchmark("nmr", igme.ests.nmr, "NMR", "nmr",
                             weight.adm1.u1)
run_admin1_unstrat_benchmark("u5mr", igme.ests.u5, "U5MR", "u5",
                             weight.adm1.u5)
} else {
  message("Skipping Admin-1 unstratified benchmark: not the JSON-selected final model.")
}

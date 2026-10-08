USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}

# Step 8: Beta-Binomial Estimates 

# Run BB8.R and, again, make sure to specify the
# country of interest. This will fit and generate estimates for U5MR and NMR
# models at the National, Admin-1, Admin-2 levels. You will fit stratified and
# unstratified models which only use the surveys in the most recent sample
# frame, as well as unstratified models which include all surveys. For now, do
# not run the benchmarked models.

## ENTER COUNTRY OF INTEREST -----------------------------------------------
# Please capitalize the first letter of the country name and replace " " in the country name to "_" if there is.

## Libraries -----------------------------------------------
library(SUMMER)
library(INLA)
inla.setOption(inla.mode="experimental")
options(gsubfn.engine = "R")
library(tidyverse)

## Retrieve directories and country info -----------------------------------------------
code.path <- file.path(project_home(), "Rcode/8_10_BB8.R")
code.path.splitted <- strsplit(code.path, "/")[[1]]

home.dir <- paste(code.path.splitted[1: (length(code.path.splitted)-2)], collapse = "/")
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
require_country_context()
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}
bb8_admin1_only <- tolower(Sys.getenv("BB8_ADMIN1_ONLY", "0")) %in%
  c("1", "true", "yes", "y")
bb8_skip_same_frame_nmr <- tolower(
  Sys.getenv("BB8_SKIP_SAME_FRAME_NMR", "0")
) %in% c("1", "true", "yes", "y")
bb8_skip_same_frame_main <- tolower(
  Sys.getenv("BB8_SKIP_SAME_FRAME_MAIN", "0")
) %in% c("1", "true", "yes", "y")
bb8_resume_all_surveys <- tolower(
  Sys.getenv("BB8_RESUME_ALL_SURVEYS", "0")
) %in% c("1", "true", "yes", "y")
bb8_repair_admin2_strat_u5_only <- tolower(
  Sys.getenv("BB8_REPAIR_ADMIN2_STRAT_U5_ONLY", "0")
) %in% c("1", "true", "yes", "y")
bb8_resume_strat_admin2_u5 <- tolower(
  Sys.getenv("BB8_RESUME_STRAT_ADMIN2_U5", "0")
) %in% c("1", "true", "yes", "y")
bb8_resume_allsurvey_admin2_u5 <- tolower(
  Sys.getenv("BB8_RESUME_ALLSURVEY_ADMIN2_U5", "0")
) %in% c("1", "true", "yes", "y")
bb8_resume_allsurvey_benchmarks <- tolower(
  Sys.getenv("BB8_RESUME_ALLSURVEY_BENCHMARKS", "0")
) %in% c("1", "true", "yes", "y")
bb8_refresh_benchmarks_only <- tolower(
  Sys.getenv("BB8_REFRESH_BENCHMARKS_ONLY", "0")
) %in% c("1", "true", "yes", "y")
bb8_refresh_selected_only <- bb8_refresh_benchmarks_only && tolower(
  Sys.getenv("BB8_REFRESH_SELECTED_ONLY", "1")
) %in% c("1", "true", "yes", "y")
bb8_refresh_strat <- TRUE
bb8_refresh_allsurveys <- TRUE
if (bb8_refresh_selected_only) {
  if (!identical(final_model$bench.model, "bench") ||
      !final_model$strata.model %in% c("strat", "unstrat") ||
      !identical(final_model$time.model, "ar1")) {
    stop("Selected-model refresh requires a strat/unstrat AR1 benchmarked final_model.")
  }
  bb8_refresh_strat <- identical(final_model$strata.model, "strat")
  bb8_refresh_allsurveys <- !bb8_refresh_strat
  message("Refreshing only selected final model: ", final_model$strata.model)
}
bb8_final_admin2_only <- tolower(
  Sys.getenv("BB8_FINAL_ADMIN2_ONLY", "0")
) %in% c("1", "true", "yes", "y")
if (bb8_refresh_benchmarks_only) {
  bb8_skip_same_frame_main <- TRUE
  bb8_resume_allsurvey_benchmarks <- TRUE
  message(
    "BB8_REFRESH_BENCHMARKS_ONLY=1; retaining unbenchmarked models and ",
    "refreshing benchmarked model families."
  )
}
run_admin2_bb8 <- exists("poly.layer.adm2", inherits = TRUE) &&
  !bb8_admin1_only
if (bb8_admin1_only) {
  message("BB8_ADMIN1_ONLY=1; skipping Admin-2 BB8 fits in this run.")
}

source(file=file.path(home.dir, "Rcode", "_supporting_scripts", "smoothCluster_mod.R"))
source(file=file.path(home.dir, "Rcode", "_supporting_scripts", "getBB8.R"))
source(file=file.path(home.dir, "Rcode", "_supporting_scripts", "bb8_temporal_diagnostics.R"))
source(file=file.path(home.dir, "Rcode", "_supporting_scripts", "survey_strata_weights.R"))
source(file=file.path(home.dir, "Rcode", "_supporting_scripts", "admin_benchmark_helpers.R"))
source(file=file.path(home.dir, "Rcode", "_supporting_scripts", "hiv_adjustments.R"))
source(file.path(
  home.dir,
  "Rcode", "_supporting_scripts", "final_admin2_recovery.R"
))
if (bb8_final_admin2_only && !is.function(run_final_admin2_only)) {
  stop("Final Admin-2 recovery runner is unavailable.", call. = FALSE)
}

bb8_load_saved_result <- function(path, object_name) {
  if (!file.exists(path)) {
    stop("Missing saved BB8 result needed for resume: ", path)
  }
  loaded <- new.env(parent = emptyenv())
  load(path, envir = loaded)
  if (!exists(object_name, envir = loaded, inherits = FALSE)) {
    stop("Saved BB8 result does not contain ", object_name, ": ", path)
  }
  get(object_name, envir = loaded, inherits = FALSE)
}

## Load admin names -----------------------------------------------
use_path_base(data.dir)

load(file.path(poly.path, paste0(country, "_Amat.rda")))
load(file.path(poly.path, paste0(country, "_Amat_Names.rda")))

## Load data from same sampling frame -----------------------------------------------
load(paste0(country, '_cluster_dat_1frame.rda'))

mod.dat$years <- as.numeric(as.character(mod.dat$years))
mod.dat$country <- as.character(country)
survey_years <- unique(mod.dat$survey)
print(paste0('The surveys from the same sampling frame: ', paste(survey_years, collapse = ", ")))


## Load IGME estimates ------------------------------------------------------
{
  use_path_base(file.path(home.dir, "Data", "IGME"))
  
  ## U5MR
  igme.ests.u5.raw <- read.csv('igme2026_u5_nocrisis.csv')
  igme.ests.u5 <- igme.ests.u5.raw[igme.ests.u5.raw$ISO.Code==iso0,]
  igme.ests.u5 <- data.frame(t(igme.ests.u5[,10:ncol(igme.ests.u5)]))
  names(igme.ests.u5) <- c('LOWER_BOUND','OBS_VALUE','UPPER_BOUND')
  igme.ests.u5$year <-  as.numeric(stringr::str_remove(row.names(igme.ests.u5),'X')) - 0.5
  igme.ests.u5 <- igme.ests.u5[igme.ests.u5$year %in% beg.year:end.proj.year,]
  rownames(igme.ests.u5) <- NULL
  igme.ests.u5$OBS_VALUE <- igme.ests.u5$OBS_VALUE/1000
  igme.ests.u5$LOWER_BOUND <- igme.ests.u5$LOWER_BOUND/1000
  igme.ests.u5$UPPER_BOUND <- igme.ests.u5$UPPER_BOUND/1000
  igme.ests.u5$SD <- (igme.ests.u5$UPPER_BOUND - igme.ests.u5$LOWER_BOUND)/(2*1.645)
  
  ## NMR
  igme.ests.nmr.raw <- read.csv('igme2026_nmr_nocrisis.csv')
  igme.ests.nmr <- igme.ests.nmr.raw[igme.ests.nmr.raw$ISO.Code==iso0,]
  igme.ests.nmr <- data.frame(t(igme.ests.nmr[,10:ncol(igme.ests.nmr)]))
  names(igme.ests.nmr) <- c('LOWER_BOUND','OBS_VALUE','UPPER_BOUND')
  igme.ests.nmr$year <-  as.numeric(stringr::str_remove(row.names(igme.ests.nmr),'X')) - 0.5
  igme.ests.nmr <- igme.ests.nmr[igme.ests.nmr$year %in% beg.year:end.proj.year,]
  rownames(igme.ests.nmr) <- NULL
  igme.ests.nmr$OBS_VALUE <- igme.ests.nmr$OBS_VALUE/1000
  igme.ests.nmr$LOWER_BOUND <- igme.ests.nmr$LOWER_BOUND/1000
  igme.ests.nmr$UPPER_BOUND <- igme.ests.nmr$UPPER_BOUND/1000
  igme.ests.nmr$SD <- (igme.ests.nmr$UPPER_BOUND - igme.ests.nmr$LOWER_BOUND)/(2*1.645)
}

## Load Admin 1 and 2 population proportions ------------------------------------------------------

load(file.path(data.dir, "worldpop", "adm1_weights_u1.rda"))
load(file.path(data.dir, "worldpop", "adm1_weights_u5.rda"))
if(run_admin2_bb8){
load(file.path(data.dir, "worldpop", "adm2_weights_u1.rda"))
load(file.path(data.dir, "worldpop", "adm2_weights_u5.rda"))
}

#update them if necessary
if((max(weight.adm1.u1$years)<end.proj.year)){
  weight.adm1.u1 <- rbind(weight.adm1.u1,data.frame(region=rep(weight.adm1.u1[weight.adm1.u1$years==2020,]$region,(end.proj.year - 2020)),
                                                    proportion=rep(weight.adm1.u1[weight.adm1.u1$years==2020,]$proportion,(end.proj.year - 2020)),
                                                    years=sort(rep(2021:end.proj.year,length(admin1.names$GeoRepo)))))
  weight.adm1.u5 <- rbind(weight.adm1.u5,data.frame(region=rep(weight.adm1.u5[weight.adm1.u5$years==2020,]$region,(end.proj.year - 2020)),
                                                    proportion=rep(weight.adm1.u5[weight.adm1.u5$years==2020,]$proportion,(end.proj.year - 2020)),
                                                    years=sort(rep(2021:end.proj.year,length(admin1.names$GeoRepo)))))
  if(run_admin2_bb8){
    weight.adm2.u1 <- rbind(weight.adm2.u1,data.frame(region=rep(weight.adm2.u1[weight.adm2.u1$years==2020,]$region,(end.proj.year - 2020)),
                                                      proportion=rep(weight.adm2.u1[weight.adm2.u1$years==2020,]$proportion,(end.proj.year - 2020)),
                                                      years=sort(rep(2021:end.proj.year,length(admin2.names$GeoRepo)))))
    weight.adm2.u5 <- rbind(weight.adm2.u5,data.frame(region=rep(weight.adm2.u5[weight.adm2.u5$years==2020,]$region,(end.proj.year - 2020)),
                                                      proportion=rep(weight.adm2.u5[weight.adm2.u5$years==2020,]$proportion,(end.proj.year - 2020)),
                                                      years=sort(rep(2021:end.proj.year,length(admin2.names$GeoRepo)))))
  }
}else if((max(weight.adm1.u1$years)>end.proj.year)){
  weight.adm1.u1 <- weight.adm1.u1[weight.adm1.u1$years<=end.proj.year,]
  weight.adm1.u5 <- weight.adm1.u5[weight.adm1.u5$years<=end.proj.year,]
  if(run_admin2_bb8){
    weight.adm2.u1 <- weight.adm2.u1[weight.adm2.u1$years<=end.proj.year,]
    weight.adm2.u5 <- weight.adm2.u5[weight.adm2.u5$years<=end.proj.year,]
  }
}

if (!bb8_final_admin2_only && !bb8_refresh_benchmarks_only) {
  save(weight.adm1.u1,file=file.path(data.dir, "worldpop", "adm1_weights_u1.rda"))
  save(weight.adm1.u5,file=file.path(data.dir, "worldpop", "adm1_weights_u5.rda"))
  if(run_admin2_bb8){
    save(weight.adm2.u1,file=file.path(data.dir, "worldpop", "adm2_weights_u1.rda"))
    save(weight.adm2.u5,file=file.path(data.dir, "worldpop", "adm2_weights_u5.rda"))
  }
}

## Load HIV Adjustment info -----------------------------------------------

if(doHIVAdj){
  hiv.adj <- load_country_hiv_adjustments(
    file.path(home.dir, "Data", "HIV", "HIVAdjustments.rda"),
    country
  )
  if(unique(hiv.adj$area)[1] == country){
    natl.unaids <- T
  }else{
    natl.unaids <- F}
  
  if(natl.unaids){
    adj.frame <- hiv.adj
    adj.varnames <- c("country", "survey", "years")
  }else{ adj.frame <- hiv.adj
    mod.dat$area <- mod.dat$admin1.name
    if(country=='Mozambique'){
      mod.dat[mod.dat$area=='Maputo City',]$area <- 'Maputo'
    }
  adj.varnames <- c("country", "area","survey", "years")
  }
  adj.frame <- adj.frame[adj.frame$survey %in% survey_years,c(adj.varnames,"ratio")]
}else{
  adj.frame <- expand.grid(years = beg.year:end.proj.year,country = country)
  adj.frame$ratio <- 1
  adj.varnames <- c("country", "years")
}

if (bb8_final_admin2_only) {
  recovery_plan <- final_admin2_recovery_plan(final_model)
  if (!run_admin2_bb8) {
    stop(
      "BB8_FINAL_ADMIN2_ONLY=1 requires configured Admin-2 boundaries.",
      call. = FALSE
    )
  }
  if (identical(recovery_plan$branch, "unstrat")) {
    recovery_data <- prepare_final_admin2_all_survey_data(
      country = country,
      data_dir = data.dir,
      home_dir = home.dir,
      do_hiv_adjustment = doHIVAdj,
      beg_year = beg.year,
      end_year = end.proj.year,
      hiv_loader = load_country_hiv_adjustments
    )
    message(
      "The surveys used for final Admin-2 recovery are: ",
      paste(recovery_data$survey_years, collapse = ", ")
    )
    written <- run_final_admin2_only(
      country = country,
      res_dir = res.dir,
      plan = recovery_plan,
      mod_dat = recovery_data$mod_dat,
      admin2_matrix = admin2.mat,
      admin2_names = admin2.names,
      weight_u1 = weight.adm2.u1,
      weight_u5 = weight.adm2.u5,
      igme_nmr = igme.ests.nmr,
      igme_u5 = igme.ests.u5,
      adj_frame = recovery_data$adj_frame,
      adj_varnames = recovery_data$adj_varnames,
      beg_year = beg.year,
      end_year = end.proj.year,
      get_bb8 = getBB8,
      temporal_diagnostic = bb8_get_temporal_diag,
      benchmark_adjustment = compute_admin_benchmark_adjustment
    )
    message(
      "Final Admin-2 recovery completed:\n",
      paste(written, collapse = "\n")
    )
    quit(save = "no", status = 0, runLast = FALSE)
  }
}

## Load UR proportions -----------------------------------------------
if (bb8_refresh_strat) {
ur_weight_files <- c(
  file.path(res.dir, "UR", "U5_fraction", "natl_u5_urban_weights.rds"),
  file.path(res.dir, "UR", "U5_fraction", "admin1_u5_urban_weights.rds"),
  file.path(res.dir, "UR", "U1_fraction", "natl_u1_urban_weights.rds"),
  file.path(res.dir, "UR", "U1_fraction", "admin1_u1_urban_weights.rds")
)
if (run_admin2_bb8) {
  ur_weight_files <- c(
    ur_weight_files,
    file.path(res.dir, "UR", "U5_fraction", "admin2_u5_urban_weights.rds"),
    file.path(res.dir, "UR", "U1_fraction", "admin2_u1_urban_weights.rds")
  )
}

if(all(file.exists(ur_weight_files))){
  use_path_base(file.path(res.dir, "UR"))
  weight.strata.natl.u5 <- readRDS(file.path("U5_fraction", "natl_u5_urban_weights.rds"))
  weight.strata.natl.u5$rural <- 1-weight.strata.natl.u5$urban
  weight.strata.adm1.u5 <- readRDS(file.path("U5_fraction", "admin1_u5_urban_weights.rds"))

  weight.strata.natl.u1 <- readRDS(file.path("U1_fraction", "natl_u1_urban_weights.rds"))
  weight.strata.natl.u1$rural <- 1-weight.strata.natl.u1$urban
  weight.strata.adm1.u1 <- readRDS(file.path("U1_fraction", "admin1_u1_urban_weights.rds"))
  
  if(run_admin2_bb8){
  weight.strata.adm2.u5 <- readRDS(file.path("U5_fraction", "admin2_u5_urban_weights.rds"))
  weight.strata.adm2.u1 <- readRDS(file.path("U1_fraction", "admin2_u1_urban_weights.rds"))
  }
  
  #adjust if necessary
  if(end.proj.year > max(weight.strata.natl.u1$years)){
    weight.strata.natl.u1 <- rbind(weight.strata.natl.u1,
                                   data.frame(years=2021:end.proj.year,
                                              urban=rep(weight.strata.natl.u1[weight.strata.natl.u1$years==2020,]$urban,end.proj.year-2020),
                                              rural=1-rep(weight.strata.natl.u1[weight.strata.natl.u1$years==2020,]$urban,end.proj.year-2020)))
    weight.strata.natl.u5 <- rbind(weight.strata.natl.u5,
                                   data.frame(years=2021:end.proj.year,
                                              urban=rep(weight.strata.natl.u5[weight.strata.natl.u5$years==2020,]$urban,end.proj.year-2020),
                                              rural=1-rep(weight.strata.natl.u5[weight.strata.natl.u5$years==2020,]$urban,end.proj.year-2020)))
    weight.strata.adm1.u1 <- rbind(weight.strata.adm1.u1,
                                   data.frame(region=rep(admin1.names$Internal,end.proj.year-2020),
                                              years=sort(rep(2021:end.proj.year,nrow(admin1.names))),
                                              urban=rep(weight.strata.adm1.u1[weight.strata.adm1.u1$years==2020,]$urban,end.proj.year-2020),
                                              rural=1-rep(weight.strata.adm1.u1[weight.strata.adm1.u1$years==2020,]$urban,end.proj.year-2020)))
    weight.strata.adm1.u5 <- rbind(weight.strata.adm1.u5,
                                   data.frame(region=rep(admin1.names$Internal,end.proj.year-2020),
                                              years=sort(rep(2021:end.proj.year,nrow(admin1.names))),
                                              urban=rep(weight.strata.adm1.u5[weight.strata.adm1.u5$years==2020,]$urban,end.proj.year-2020),
                                              rural=1-rep(weight.strata.adm1.u5[weight.strata.adm1.u5$years==2020,]$urban,end.proj.year-2020)))
    if(run_admin2_bb8){
    weight.strata.adm2.u1 <- rbind(weight.strata.adm2.u1,
                                   data.frame(region=rep(admin2.names$Internal,end.proj.year-2020),
                                              years=sort(rep(2021:end.proj.year,nrow(admin2.names))),
                                              urban=rep(weight.strata.adm2.u1[weight.strata.adm2.u1$years==2020,]$urban,end.proj.year-2020),
                                              rural=1-rep(weight.strata.adm2.u1[weight.strata.adm2.u1$years==2020,]$urban,end.proj.year-2020)))
    weight.strata.adm2.u5 <- rbind(weight.strata.adm2.u5,
                                   data.frame(region=rep(admin2.names$Internal,end.proj.year-2020),
                                              years=sort(rep(2021:end.proj.year,nrow(admin2.names))),
                                              urban=rep(weight.strata.adm2.u5[weight.strata.adm2.u5$years==2020,]$urban,end.proj.year-2020),
                                              rural=1-rep(weight.strata.adm2.u5[weight.strata.adm2.u5$years==2020,]$urban,end.proj.year-2020)))
    }
  }else if(end.proj.year < max(weight.strata.natl.u1$years)){
    weight.strata.natl.u1 <- weight.strata.natl.u1[weight.strata.natl.u1$years<=end.proj.year,]
    weight.strata.natl.u5 <- weight.strata.natl.u5[weight.strata.natl.u5$years<=end.proj.year,]
    weight.strata.adm1.u1 <- weight.strata.adm1.u1[weight.strata.adm1.u1$years<=end.proj.year,]
    weight.strata.adm1.u5 <- weight.strata.adm1.u5[weight.strata.adm1.u5$years<=end.proj.year,]
    if(run_admin2_bb8){
    weight.strata.adm2.u1 <- weight.strata.adm2.u1[weight.strata.adm2.u1$years<=end.proj.year,]
    weight.strata.adm2.u5 <- weight.strata.adm2.u5[weight.strata.adm2.u5$years<=end.proj.year,]
    }
  }
  
  #put national proportions in correct format for getSmoothed
  weight.strata.adm1.u1.natl <- weight.strata.adm1.u5.natl <- expand.grid(region = admin1.names$Internal,years = beg.year:end.proj.year)
  weight.strata.adm1.u1.natl <- merge(weight.strata.adm1.u1.natl,weight.strata.natl.u1,by=c('years'))
  weight.strata.adm1.u5.natl <- merge(weight.strata.adm1.u5.natl,weight.strata.natl.u5,by=c('years'))
  
  if(run_admin2_bb8){
  weight.strata.adm2.u1.natl <- weight.strata.adm2.u5.natl <- expand.grid(region = admin2.names$Internal,years = beg.year:end.proj.year)
  weight.strata.adm2.u1.natl <- merge(weight.strata.adm2.u1.natl,weight.strata.natl.u1,by=c('years'))
  weight.strata.adm2.u5.natl <- merge(weight.strata.adm2.u5.natl,weight.strata.natl.u5,by=c('years'))
  }
} else if (exists("strata_weight_source", inherits = TRUE) &&
           identical(strata_weight_source, "survey")) {
  missing_ur_files <- ur_weight_files[!file.exists(ur_weight_files)]
  message("Missing UR weight files for ", country, "; deriving stratum weights ",
          "from same-frame survey cluster weights: ",
          paste(basename(missing_ur_files), collapse = ", "))
  survey_strata_weights <- derive_survey_strata_weights(
    mod.dat = mod.dat,
    beg.year = beg.year,
    end.proj.year = end.proj.year,
    admin1.names = admin1.names,
    admin2.names = if (run_admin2_bb8) admin2.names else NULL,
    missing_region_fallback = if (exists("strata_weight_missing_region_fallback", inherits = TRUE)) {
      strata_weight_missing_region_fallback
    } else {
      "error"
    }
  )
  save_survey_strata_weights(survey_strata_weights, res.dir)
  list2env(survey_strata_weights, envir = .GlobalEnv)
} else {
  missing_ur_files <- ur_weight_files[!file.exists(ur_weight_files)]
  stop("Missing urban/rural stratum weight files. Run Rcode/7a_UR_prop.R ",
       "and Rcode/7b_UR_thresholding_sf.R first. Missing: ",
       paste(missing_ur_files, collapse = ", "),
       call. = FALSE)
}

if (bb8_final_admin2_only) {
  recovery_plan <- final_admin2_recovery_plan(final_model)
  if (!identical(recovery_plan$branch, "strat")) {
    stop(
      "Unstratified final Admin-2 recovery did not exit before UR weights.",
      call. = FALSE
    )
  }
  written <- run_final_admin2_only(
    country = country,
    res_dir = res.dir,
    plan = recovery_plan,
    mod_dat = mod.dat,
    admin2_matrix = admin2.mat,
    admin2_names = admin2.names,
    weight_u1 = weight.adm2.u1,
    weight_u5 = weight.adm2.u5,
    igme_nmr = igme.ests.nmr,
    igme_u5 = igme.ests.u5,
    adj_frame = adj.frame,
    adj_varnames = adj.varnames,
    beg_year = beg.year,
    end_year = end.proj.year,
    get_bb8 = getBB8,
    temporal_diagnostic = bb8_get_temporal_diag,
    benchmark_adjustment = compute_admin_benchmark_adjustment,
    weight_strata_u1 = weight.strata.adm2.u1,
    weight_strata_u5 = weight.strata.adm2.u5
  )
  message(
    "Final Admin-2 recovery completed:\n",
    paste(written, collapse = "\n")
  )
  quit(save = "no", status = 0, runLast = FALSE)
}

## Fit BB8 models w surveys from same sampling frame  -----------------------------------------------
if (!bb8_resume_all_surveys) {
use_path_base(paste0(res.dir))
dir.create(file.path("Betabinomial", "NMR"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("Betabinomial", "U5MR"), recursive = TRUE, showWarnings = FALSE)

### NMR -----------------------------------------------
if (!bb8_skip_same_frame_main &&
    !bb8_skip_same_frame_nmr &&
    !bb8_repair_admin2_strat_u5_only) {
#### National Unstrat ----------------------------------------------

bb.natl.unstrat.nmr <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                              Amat=NULL, admin.level='National',
                              stratified=F, weight.strata=NULL,
                              outcome='nmr', time.model='ar1',
                              adj.frame=adj.frame, adj.varnames=adj.varnames,
                              nsim = 1000)

bb.fit.natl.unstrat.nmr <- bb.natl.unstrat.nmr[[1]]
bb.res.natl.unstrat.nmr <- bb.natl.unstrat.nmr[[2]]

bb.temporals.natl.unstrat.nmr <- getDiag(bb.natl.unstrat.nmr$fit,field = "time",year_label=beg.year:end.proj.year)
bb.hyperpar.natl.unstrat.nmr <- bb.fit.natl.unstrat.nmr$fit$summary.hyperpar
bb.fixed.natl.unstrat.nmr <- bb.fit.natl.unstrat.nmr$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_natl_unstrat_nmr.txt')))
summary(bb.fit.natl.unstrat.nmr)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.natl.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_natl_unstrat_nmr.rda')))
save(bb.hyperpar.natl.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_natl_unstrat_nmr.rda')))
save(bb.fixed.natl.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_natl_unstrat_nmr.rda')))
# save results
save(bb.res.natl.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_res_natl_unstrat_nmr.rda')))


#### National Strat -----------------------------------------------
bb.natl.strat.nmr <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                            Amat=NULL, admin.level='National',
                            stratified=T, weight.strata=weight.strata.natl.u1,
                            outcome='nmr', time.model='ar1',
                            adj.frame=adj.frame, adj.varnames=adj.varnames,
                            nsim = 1000)
bb.fit.natl.strat.nmr <- bb.natl.strat.nmr[[1]]
bb.res.natl.strat.nmr <- bb.natl.strat.nmr[[2]]

bb.temporals.natl.strat.nmr <- getDiag(bb.natl.strat.nmr$fit,field = "time",year_label=beg.year:end.proj.year)
bb.hyperpar.natl.strat.nmr <- bb.fit.natl.strat.nmr$fit$summary.hyperpar
bb.fixed.natl.strat.nmr <- bb.fit.natl.strat.nmr$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_natl_strat_nmr.txt')))
summary(bb.fit.natl.strat.nmr)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.natl.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_natl_strat_nmr.rda')))
save(bb.hyperpar.natl.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_natl_strat_nmr.rda')))
save(bb.fixed.natl.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_natl_strat_nmr.rda')))
# save results
save(bb.res.natl.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_res_natl_strat_nmr.rda')))


#### Admin1 Unstrat ----------------------------------------------
bb.adm1.unstrat.nmr <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                              Amat=admin1.mat, admin.level='Admin1',
                              stratified=F, weight.strata=NULL,
                              outcome='nmr',
                              time.model='ar1', st.time.model='ar1',
                              adj.frame=adj.frame, adj.varnames=adj.varnames,
                              nsim = 1000)

bb.fit.adm1.unstrat.nmr <- bb.adm1.unstrat.nmr[[1]]
bb.res.adm1.unstrat.nmr <- bb.adm1.unstrat.nmr[[2]]

bb.temporals.adm1.unstrat.nmr <- getDiag(bb.adm1.unstrat.nmr$fit,field = "time",year_label=beg.year:end.proj.year)
bb.hyperpar.adm1.unstrat.nmr <- bb.fit.adm1.unstrat.nmr$fit$summary.hyperpar
bb.fixed.adm1.unstrat.nmr <- bb.fit.adm1.unstrat.nmr$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_adm1_unstrat_nmr.txt')))
summary(bb.fit.adm1.unstrat.nmr)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.adm1.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_adm1_unstrat_nmr.rda')))
save(bb.hyperpar.adm1.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_adm1_unstrat_nmr.rda')))
save(bb.fixed.adm1.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_adm1_unstrat_nmr.rda')))
# save results
save(bb.res.adm1.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_unstrat_nmr.rda')))

#### Admin1 Strat -----------------------------------------------
bb.adm1.strat.nmr <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                            Amat=admin1.mat, admin.level='Admin1',
                            stratified=T, weight.strata=weight.strata.adm1.u1,
                            outcome='nmr',
                            time.model='ar1', st.time.model='ar1',
                            adj.frame=adj.frame, adj.varnames=adj.varnames,
                            nsim = 1000)
# Keep the full INLA fit in memory only; persist compact downstream artifacts.
bb.fit.adm1.strat.nmr <- bb.adm1.strat.nmr[[1]]
bb.res.adm1.strat.nmr <- bb.adm1.strat.nmr[[2]]

bb.temporals.adm1.strat.nmr <- getDiag(bb.adm1.strat.nmr$fit,field = "time",year_label=beg.year:end.proj.year)
bb.hyperpar.adm1.strat.nmr <- bb.fit.adm1.strat.nmr$fit$summary.hyperpar
bb.fixed.adm1.strat.nmr <- bb.fit.adm1.strat.nmr$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_adm1_strat_nmr.txt')))
summary(bb.fit.adm1.strat.nmr)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.adm1.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_adm1_strat_nmr.rda')))
save(bb.hyperpar.adm1.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_adm1_strat_nmr.rda')))
save(bb.fixed.adm1.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_adm1_strat_nmr.rda')))
# save results
save(bb.res.adm1.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_strat_nmr.rda')))

#### Admin2 Unstrat ----------------------------------------------
if(run_admin2_bb8){
bb.adm2.unstrat.nmr <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                              Amat=admin2.mat, admin.level='Admin2',
                              stratified=F, weight.strata=NULL,
                              outcome='nmr',
                              time.model='ar1', st.time.model='ar1',
                              adj.frame=adj.frame, adj.varnames=adj.varnames,
                              nsim = 1000)

bb.fit.adm2.unstrat.nmr <- bb.adm2.unstrat.nmr[[1]]
bb.res.adm2.unstrat.nmr <- bb.adm2.unstrat.nmr[[2]]

bb.temporals.adm2.unstrat.nmr <- bb8_get_temporal_diag(
  bb.adm2.unstrat.nmr$fit,
  admin_level = "Admin2",
  year_label = beg.year:end.proj.year
)
bb.hyperpar.adm2.unstrat.nmr <- bb.fit.adm2.unstrat.nmr$fit$summary.hyperpar
bb.fixed.adm2.unstrat.nmr <- bb.fit.adm2.unstrat.nmr$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_adm2_unstrat_nmr.txt')))
summary(bb.fit.adm2.unstrat.nmr)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.adm2.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_adm2_unstrat_nmr.rda')))
save(bb.hyperpar.adm2.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_adm2_unstrat_nmr.rda')))
save(bb.fixed.adm2.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_adm2_unstrat_nmr.rda')))
# save results
save(bb.res.adm2.unstrat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_unstrat_nmr.rda')))

#### Admin2 Strat -----------------------------------------------
bb.adm2.strat.nmr <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                            Amat=admin2.mat, admin.level='Admin2',
                            stratified=T, weight.strata=weight.strata.adm2.u1,
                            outcome='nmr',
                            time.model='ar1', st.time.model='ar1',
                            adj.frame=adj.frame, adj.varnames=adj.varnames,
                            nsim = 1000)
bb.fit.adm2.strat.nmr <- bb.adm2.strat.nmr[[1]]
bb.res.adm2.strat.nmr <- bb.adm2.strat.nmr[[2]]

bb.temporals.adm2.strat.nmr <- bb8_get_temporal_diag(
  bb.adm2.strat.nmr$fit,
  admin_level = "Admin2",
  year_label = beg.year:end.proj.year
)
bb.hyperpar.adm2.strat.nmr <- bb.fit.adm2.strat.nmr$fit$summary.hyperpar
bb.fixed.adm2.strat.nmr <- bb.fit.adm2.strat.nmr$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_adm2_strat_nmr.txt')))
summary(bb.fit.adm2.strat.nmr)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.adm2.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_adm2_strat_nmr.rda')))
save(bb.hyperpar.adm2.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_adm2_strat_nmr.rda')))
save(bb.fixed.adm2.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_adm2_strat_nmr.rda')))
# save results
save(bb.res.adm2.strat.nmr,file=file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_strat_nmr.rda')))
}
} else if (!bb8_skip_same_frame_main &&
           !bb8_repair_admin2_strat_u5_only) {
  message(
    "BB8_SKIP_SAME_FRAME_NMR=1; retaining completed same-frame NMR outputs ",
    "and resuming at U5MR."
  )
}


### U5MR -----------------------------------------------
if (!bb8_skip_same_frame_main) {
if (!bb8_repair_admin2_strat_u5_only) {
  #### National Unstrat ----------------------------------------------
bb.natl.unstrat.u5 <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                             Amat=NULL, admin.level='National',
                             stratified=F, weight.strata=NULL,
                             outcome='u5mr', time.model='ar1',
                             adj.frame=adj.frame, adj.varnames=adj.varnames,
                             nsim=1000)
bb.fit.natl.unstrat.u5 <- bb.natl.unstrat.u5[[1]]
bb.res.natl.unstrat.u5 <- bb.natl.unstrat.u5[[2]]

bb.temporals.natl.unstrat.u5 <- getDiag(bb.natl.unstrat.u5$fit,field = "time",year_label=beg.year:end.proj.year)
bb.hyperpar.natl.unstrat.u5 <- bb.fit.natl.unstrat.u5$fit$summary.hyperpar
bb.fixed.natl.unstrat.u5 <- bb.fit.natl.unstrat.u5$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_natl_unstrat_u5.txt')))
summary(bb.fit.natl.unstrat.u5)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.natl.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_natl_unstrat_u5.rda')))
save(bb.hyperpar.natl.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_natl_unstrat_u5.rda')))
save(bb.fixed.natl.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_natl_unstrat_u5.rda')))
# save results
save(bb.res.natl.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_unstrat_u5.rda')))


  #### National Strat -----------------------------------------------
bb.natl.strat.u5 <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                           Amat=NULL, admin.level='National',
                           stratified=T, weight.strata=weight.strata.natl.u5,
                           outcome='u5mr', time.model='ar1',
                           adj.frame=adj.frame, adj.varnames=adj.varnames,
                           nsim=1000)
bb.fit.natl.strat.u5 <- bb.natl.strat.u5[[1]]
bb.res.natl.strat.u5 <- bb.natl.strat.u5[[2]]

bb.temporals.natl.strat.u5 <- getDiag(bb.natl.strat.u5$fit,field = "time",year_label=beg.year:end.proj.year)
bb.hyperpar.natl.strat.u5 <- bb.fit.natl.strat.u5$fit$summary.hyperpar
bb.fixed.natl.strat.u5 <- bb.fit.natl.strat.u5$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_natl_strat_u5.txt')))
summary(bb.fit.natl.strat.u5)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.natl.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_natl_strat_u5.rda')))
save(bb.hyperpar.natl.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_natl_strat_u5.rda')))
save(bb.fixed.natl.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_natl_strat_u5.rda')))
# save results
save(bb.res.natl.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_strat_u5.rda')))

  #### Admin1 Unstrat ----------------------------------------------
bb.adm1.unstrat.u5 <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                             Amat=admin1.mat, admin.level='Admin1',
                             stratified=F, weight.strata=NULL,
                             outcome='u5mr',
                             time.model='ar1', st.time.model='ar1',
                             adj.frame=adj.frame, adj.varnames=adj.varnames,
                              nsim = 1000)
bb.fit.adm1.unstrat.u5 <- bb.adm1.unstrat.u5[[1]]
bb.res.adm1.unstrat.u5 <- bb.adm1.unstrat.u5[[2]]

bb.temporals.adm1.unstrat.u5 <- getDiag(bb.adm1.unstrat.u5$fit,field = "time",year_label=beg.year:end.proj.year)
bb.hyperpar.adm1.unstrat.u5 <- bb.fit.adm1.unstrat.u5$fit$summary.hyperpar
bb.fixed.adm1.unstrat.u5 <- bb.fit.adm1.unstrat.u5$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_adm1_unstrat_u5.txt')))
summary(bb.fit.adm1.unstrat.u5)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.adm1.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_adm1_unstrat_u5.rda')))
save(bb.hyperpar.adm1.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_adm1_unstrat_u5.rda')))
save(bb.fixed.adm1.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_adm1_unstrat_u5.rda')))
# save results
save(bb.res.adm1.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_unstrat_u5.rda')))


#### Admin1 Strat -----------------------------------------------

bb.adm1.strat.u5 <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                           Amat=admin1.mat, admin.level='Admin1',
                           stratified=T, weight.strata=weight.strata.adm1.u5,
                           outcome='u5mr',
                           time.model='ar1', st.time.model='ar1',
                           adj.frame=adj.frame, adj.varnames=adj.varnames, 
                           nsim=1000)
# Keep the full INLA fit in memory only; persist compact downstream artifacts.
bb.fit.adm1.strat.u5 <- bb.adm1.strat.u5[[1]]
bb.res.adm1.strat.u5 <- bb.adm1.strat.u5[[2]]

bb.temporals.adm1.strat.u5 <- getDiag(bb.adm1.strat.u5$fit,field = "time",year_label=beg.year:end.proj.year)
bb.hyperpar.adm1.strat.u5 <- bb.fit.adm1.strat.u5$fit$summary.hyperpar
bb.fixed.adm1.strat.u5 <- bb.fit.adm1.strat.u5$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_adm1_strat_u5.txt')))
summary(bb.fit.adm1.strat.u5)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.adm1.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_adm1_strat_u5.rda')))
save(bb.hyperpar.adm1.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_adm1_strat_u5.rda')))
save(bb.fixed.adm1.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_adm1_strat_u5.rda')))
# save results
save(bb.res.adm1.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_strat_u5.rda')))


  #### Admin2 Unstrat ---------------------------------------------
if(run_admin2_bb8){
bb.adm2.unstrat.u5 <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                             Amat=admin2.mat, admin.level='Admin2',
                             stratified=F, weight.strata=NULL,
                             outcome='u5mr',
                             time.model='ar1', st.time.model='ar1',
                             adj.frame=adj.frame, adj.varnames=adj.varnames,
                              nsim = 1000)
bb.fit.adm2.unstrat.u5 <- bb.adm2.unstrat.u5[[1]]
bb.res.adm2.unstrat.u5 <- bb.adm2.unstrat.u5[[2]]

bb.temporals.adm2.unstrat.u5 <- bb8_get_temporal_diag(
  bb.adm2.unstrat.u5$fit,
  admin_level = "Admin2",
  year_label = beg.year:end.proj.year
)
bb.hyperpar.adm2.unstrat.u5 <- bb.fit.adm2.unstrat.u5$fit$summary.hyperpar
bb.fixed.adm2.unstrat.u5 <- bb.fit.adm2.unstrat.u5$fit$summary.fixed

# save summary of fit to a txt file
sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_adm2_unstrat_u5.txt')))
summary(bb.fit.adm2.unstrat.u5)
sink(file=NULL)
# save smaller components of fit
save(bb.temporals.adm2.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_adm2_unstrat_u5.rda')))
save(bb.hyperpar.adm2.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_adm2_unstrat_u5.rda')))
save(bb.fixed.adm2.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_adm2_unstrat_u5.rda')))
# save results
save(bb.res.adm2.unstrat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_unstrat_u5.rda')))
}
}

  #### Admin2 Strat -----------------------------------------------
if(run_admin2_bb8){
  bb.adm2.strat.u5 <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                             Amat=admin2.mat, admin.level='Admin2',
                             stratified=T, weight.strata=weight.strata.adm2.u5,
                             outcome='u5mr',
                             time.model='ar1', st.time.model='ar1',
                             adj.frame=adj.frame, adj.varnames=adj.varnames,
                              nsim = 1000)
  bb.fit.adm2.strat.u5 <- bb.adm2.strat.u5[[1]]
  bb.res.adm2.strat.u5 <- bb.adm2.strat.u5[[2]]
  
  bb.temporals.adm2.strat.u5 <- bb8_get_temporal_diag(
    bb.adm2.strat.u5$fit,
    admin_level = "Admin2",
    year_label = beg.year:end.proj.year
  )
  bb.hyperpar.adm2.strat.u5 <- bb.fit.adm2.strat.u5$fit$summary.hyperpar
  bb.fixed.adm2.strat.u5 <- bb.fit.adm2.strat.u5$fit$summary.fixed
  
  # save summary of fit to a txt file
  sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_adm2_strat_u5.txt')))
  summary(bb.fit.adm2.strat.u5)
  sink(file=NULL)
  # save smaller components of fit
  save(bb.temporals.adm2.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_adm2_strat_u5.rda')))
  save(bb.hyperpar.adm2.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_adm2_strat_u5.rda')))
  save(bb.fixed.adm2.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_adm2_strat_u5.rda')))
  # save results
  save(bb.res.adm2.strat.u5,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_strat_u5.rda')))
}
if (bb8_repair_admin2_strat_u5_only) {
  result.file <- file.path(
    "Betabinomial", "U5MR",
    paste0(country, "_res_adm2_strat_u5.rda")
  )
  gc()
  validation.env <- new.env(parent = emptyenv())
  loaded.objects <- load(result.file, envir = validation.env)
  if (!"bb.res.adm2.strat.u5" %in% loaded.objects) {
    stop("Repaired Admin-2 stratified U5MR result has an unexpected object name.")
  }
  message("Validated repaired Admin-2 stratified U5MR result: ", result.file)
  quit(save = "no", status = 0, runLast = FALSE)
}
} else {
  message(
    "BB8_SKIP_SAME_FRAME_MAIN=1; retaining completed same-frame main model outputs ",
    "and resuming at the stratified benchmark models."
  )
}


## Get benchmarked stratified models  -----------------------------------------------
if (identical(final_model$strata.model, "strat") &&
    identical(final_model$bench.model, "bench")) {
  use_path_base(res.dir)

### NMR -----------------------------------------------
if (!bb8_resume_strat_admin2_u5) {
  
  #### Admin1 Strat,  Benchmarked ----------------------------------------------
  #get Benchmark adjustment
  if(!exists('bb.res.adm1.strat.nmr')){
    result.file <- file.path(
      "Betabinomial", "NMR",
      paste0(country, "_res_adm1_strat_nmr.rda")
    )
    if (file.exists(result.file)) {
      result.env <- new.env(parent = emptyenv())
      loaded.objects <- load(result.file, envir = result.env)
      if (!"bb.res.adm1.strat.nmr" %in% loaded.objects) {
        stop("Saved Admin-1 stratified NMR result has an unexpected object name.")
      }
      bb.res.adm1.strat.nmr <- result.env$bb.res.adm1.strat.nmr
    } else {
      if (bb8_refresh_benchmarks_only) {
        stop(
          "Benchmark-only refresh requires saved unbenchmarked result: ",
          result.file,
          call. = FALSE
        )
      }
      bb.adm1.strat.nmr <- getBB8(
        mod.dat, country, beg.year = beg.year, end.year = end.proj.year,
        Amat = admin1.mat, admin.level = "Admin1",
        stratified = TRUE, weight.strata = weight.strata.adm1.u1,
        outcome = "nmr",
        time.model = "ar1", st.time.model = "ar1",
        adj.frame = adj.frame, adj.varnames = adj.varnames,
        nsim = 1000
      )
      bb.res.adm1.strat.nmr <- bb.adm1.strat.nmr[[2]]
    }
  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.adm1.strat.nmr$draws.est.overall,
    admin_weights = weight.adm1.u1,
    igme_ests = igme.ests.nmr
  )
  save(bench.adj, file = file.path("Betabinomial", "NMR", "adm1_strat_nmr_benchmarks.rda"))
  
  # National benchmarking is applied to HIV-adjusted posterior rates.
  bb.res.adm1.strat.nmr.bench <- benchmark_admin_result(bb.res.adm1.strat.nmr, bench.adj)
  save(bb.res.adm1.strat.nmr.bench, file=file.path("Betabinomial", "NMR",
       paste0(country, "_res_adm1_strat_nmr_bench.rda")))
  save_benchmark_source_diagnostics(country, "NMR", "adm1_strat_nmr", "adm1_strat_nmr_bench")
  
  #### Admin2 Strat,  Benchmarked ----------------------------------------------
  if(run_admin2_bb8){
  #get Benchmark adjustment
  if(!exists('bb.res.adm2.strat.nmr')){
    result.file <- file.path(
      "Betabinomial", "NMR",
      paste0(country, "_res_adm2_strat_nmr.rda")
    )
    if (!file.exists(result.file)) {
      stop("Missing completed Admin-2 stratified NMR result: ", result.file)
    }
    result.env <- new.env(parent = emptyenv())
    loaded.objects <- load(result.file, envir = result.env)
    if (!"bb.res.adm2.strat.nmr" %in% loaded.objects) {
      stop("Saved Admin-2 stratified NMR result has an unexpected object name.")
    }
    bb.res.adm2.strat.nmr <- result.env$bb.res.adm2.strat.nmr
  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.adm2.strat.nmr$draws.est.overall,
    admin_weights = weight.adm2.u1,
    igme_ests = igme.ests.nmr
  )
  save(bench.adj, file = file.path("Betabinomial", "NMR", "adm2_strat_nmr_benchmarks.rda"))
  
  # National benchmarking is applied to HIV-adjusted posterior rates.
  bb.res.adm2.strat.nmr.bench <- benchmark_admin_result(bb.res.adm2.strat.nmr, bench.adj)
  save(bb.res.adm2.strat.nmr.bench, file=file.path("Betabinomial", "NMR",
       paste0(country, "_res_adm2_strat_nmr_bench.rda")))
  save_benchmark_source_diagnostics(country, "NMR", "adm2_strat_nmr", "adm2_strat_nmr_bench")
  }
} else {
  message(
    "BB8_RESUME_STRAT_ADMIN2_U5=1; retaining completed stratified NMR ",
    "benchmarks and resuming at the Admin-2 stratified U5MR benchmark."
  )
}
  
  
### U5MR -----------------------------------------------
if (!bb8_resume_strat_admin2_u5) {
  #### Admin1 Strat,  Benchmarked ----------------------------------------------
  #get Benchmark adjustment
  if(!exists('bb.res.adm1.strat.u5')){
    result.file <- file.path(
      "Betabinomial", "U5MR",
      paste0(country, "_res_adm1_strat_u5.rda")
    )
    if (file.exists(result.file)) {
      result.env <- new.env(parent = emptyenv())
      loaded.objects <- load(result.file, envir = result.env)
      if (!"bb.res.adm1.strat.u5" %in% loaded.objects) {
        stop("Saved Admin-1 stratified U5MR result has an unexpected object name.")
      }
      bb.res.adm1.strat.u5 <- result.env$bb.res.adm1.strat.u5
    } else {
      if (bb8_refresh_benchmarks_only) {
        stop(
          "Benchmark-only refresh requires saved unbenchmarked result: ",
          result.file,
          call. = FALSE
        )
      }
      bb.adm1.strat.u5 <- getBB8(
        mod.dat, country, beg.year = beg.year, end.year = end.proj.year,
        Amat = admin1.mat, admin.level = "Admin1",
        stratified = TRUE, weight.strata = weight.strata.adm1.u5,
        outcome = "u5mr",
        time.model = "ar1", st.time.model = "ar1",
        adj.frame = adj.frame, adj.varnames = adj.varnames,
        nsim = 1000
      )
      bb.res.adm1.strat.u5 <- bb.adm1.strat.u5[[2]]
    }
  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.adm1.strat.u5$draws.est.overall,
    admin_weights = weight.adm1.u5,
    igme_ests = igme.ests.u5
  )
  save(bench.adj, file = file.path("Betabinomial", "U5MR", "adm1_strat_u5_benchmarks.rda"))
  
  # National benchmarking is applied to HIV-adjusted posterior rates.
  bb.res.adm1.strat.u5.bench <- benchmark_admin_result(bb.res.adm1.strat.u5, bench.adj)
  save(bb.res.adm1.strat.u5.bench, file=file.path("Betabinomial", "U5MR",
       paste0(country, "_res_adm1_strat_u5_bench.rda")))
  save_benchmark_source_diagnostics(country, "U5MR", "adm1_strat_u5", "adm1_strat_u5_bench")
}
  
  
  
  #### Admin2 Strat,  Benchmarked ----------------------------------------------
if(run_admin2_bb8){
  #get Benchmark adjustment
  if(!exists('bb.res.adm2.strat.u5')){
    result.file <- file.path(
      "Betabinomial", "U5MR",
      paste0(country, "_res_adm2_strat_u5.rda")
    )
    if (!file.exists(result.file)) {
      stop("Missing completed Admin-2 stratified U5MR result: ", result.file)
    }
    result.env <- new.env(parent = emptyenv())
    loaded.objects <- load(result.file, envir = result.env)
    if (!"bb.res.adm2.strat.u5" %in% loaded.objects) {
      stop("Saved Admin-2 stratified U5MR result has an unexpected object name.")
    }
    bb.res.adm2.strat.u5 <- result.env$bb.res.adm2.strat.u5
  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.adm2.strat.u5$draws.est.overall,
    admin_weights = weight.adm2.u5,
    igme_ests = igme.ests.u5
  )
  save(bench.adj, file = file.path("Betabinomial", "U5MR", "adm2_strat_u5_benchmarks.rda"))
  
  # National benchmarking is applied to HIV-adjusted posterior rates.
  bb.res.adm2.strat.u5.bench <- benchmark_admin_result(bb.res.adm2.strat.u5, bench.adj)
  save(bb.res.adm2.strat.u5.bench, file=file.path("Betabinomial", "U5MR",
       paste0(country, "_res_adm2_strat_u5_bench.rda")))
  save_benchmark_source_diagnostics(country, "U5MR", "adm2_strat_u5", "adm2_strat_u5_bench")
}
} # benchmark only the JSON-selected stratified model
} else {
  message(
    "BB8_RESUME_ALL_SURVEYS=1; retaining completed same-frame models and ",
    "benchmarks and resuming at all-survey models."
  )
}
  

# <<------------------------------------------------------------->> ----
} # selected stratified family (including its stratum weights)

  
  
## Fit BB8 models w all surveys (from different sampling frames) -----------------------
if (bb8_refresh_allsurveys) {
## Load data -----------------------------------------------
  
  use_path_base(data.dir)
  load(paste0(country,'_cluster_dat.rda'))
  
  mod.dat$years <- as.numeric(as.character(mod.dat$years))
  mod.dat$country <- as.character(country)
  survey_years <- unique(mod.dat$survey)
  print(paste0('The surveys used w all surveys are: ', paste(survey_years, collapse = ", ")))
  
  
## Load HIV Adjustment info -----------------------------------------------
  
  if(doHIVAdj){
    hiv.adj <- load_country_hiv_adjustments(
      file.path(home.dir, "Data", "HIV", "HIVAdjustments.rda"),
      country
    )
    if(unique(hiv.adj$area)[1] == country){
      natl.unaids <- T
    }else{
      natl.unaids <- F}
    
    if(natl.unaids){
      adj.frame <- hiv.adj
      adj.varnames <- c("country", "survey", "years")
    }else{ adj.frame <- hiv.adj
    mod.dat$area <- mod.dat$admin1.name
    if(country=='Mozambique'){
      mod.dat[mod.dat$area=='Maputo City',]$area <- 'Maputo'
    }
    adj.varnames <- c("country", "area","survey", "years")
    }
    adj.frame <- adj.frame[adj.frame$survey %in% survey_years,c(adj.varnames,"ratio")]
  }else{
    adj.frame <- expand.grid(years = beg.year:end.proj.year,country = country)
    adj.frame$ratio <- 1
    adj.varnames <- c("country", "years")
  }
  
### NMR -----------------------------------------------
if (!bb8_resume_allsurvey_admin2_u5 && !bb8_resume_allsurvey_benchmarks) {
  use_path_base(paste0(res.dir))
  #### National Unstrat ----------------------------------------------
  bb.natl.unstrat.nmr.allsurveys <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                                Amat=NULL, admin.level='National',
                                stratified=F, weight.strata=NULL,
                                outcome='nmr', time.model='ar1',
                                adj.frame=adj.frame, adj.varnames=adj.varnames,
                                 nsim = 1000)
  
  bb.fit.natl.unstrat.nmr.allsurveys <- bb.natl.unstrat.nmr.allsurveys[[1]]
  bb.res.natl.unstrat.nmr.allsurveys <- bb.natl.unstrat.nmr.allsurveys[[2]]
  
  bb.temporals.natl.unstrat.nmr.allsurveys <- getDiag(bb.natl.unstrat.nmr.allsurveys$fit,field = "time",year_label=beg.year:end.proj.year)
  bb.hyperpar.natl.unstrat.nmr.allsurveys <- bb.fit.natl.unstrat.nmr.allsurveys$fit$summary.hyperpar
  bb.fixed.natl.unstrat.nmr.allsurveys <- bb.fit.natl.unstrat.nmr.allsurveys$fit$summary.fixed
  
  # save summary of fit to a txt file
  sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_natl_unstrat_nmr_allsurveys.txt')))
  summary(bb.fit.natl.unstrat.nmr.allsurveys)
  sink(file=NULL)
  # save smaller components of fit
  save(bb.temporals.natl.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_natl_unstrat_nmr_allsurveys.rda')))
  save(bb.hyperpar.natl.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_natl_unstrat_nmr_allsurveys.rda')))
  save(bb.fixed.natl.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_natl_unstrat_nmr_allsurveys.rda')))
  # save results
  save(bb.res.natl.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_res_natl_unstrat_nmr_allsurveys.rda')))
  
  #### Admin1 Unstrat ----------------------------------------------
  bb.adm1.unstrat.nmr.allsurveys <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                                Amat=admin1.mat, admin.level='Admin1',
                                stratified=F, weight.strata=NULL,
                                outcome='nmr', 
                                time.model='ar1', st.time.model='ar1',
                                adj.frame=adj.frame, adj.varnames=adj.varnames,
                                nsim = 1000)
  
  bb.fit.adm1.unstrat.nmr.allsurveys <- bb.adm1.unstrat.nmr.allsurveys[[1]]
  bb.res.adm1.unstrat.nmr.allsurveys <- bb.adm1.unstrat.nmr.allsurveys[[2]]
  
  bb.temporals.adm1.unstrat.nmr.allsurveys <- getDiag(bb.adm1.unstrat.nmr.allsurveys$fit,field = "time",year_label=beg.year:end.proj.year)
  bb.hyperpar.adm1.unstrat.nmr.allsurveys <- bb.fit.adm1.unstrat.nmr.allsurveys$fit$summary.hyperpar
  bb.fixed.adm1.unstrat.nmr.allsurveys <- bb.fit.adm1.unstrat.nmr.allsurveys$fit$summary.fixed
  
  # save summary of fit to a txt file
  sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_adm1_unstrat_nmr_allsurveys.txt')))
  summary(bb.fit.adm1.unstrat.nmr.allsurveys)
  sink(file=NULL)
  # save smaller components of fit
  save(bb.temporals.adm1.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_adm1_unstrat_nmr_allsurveys.rda')))
  save(bb.hyperpar.adm1.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_adm1_unstrat_nmr_allsurveys.rda')))
  save(bb.fixed.adm1.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_adm1_unstrat_nmr_allsurveys.rda')))
  # save results
  save(bb.res.adm1.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_unstrat_nmr_allsurveys.rda')))
  
  #### Admin2 Unstrat ----------------------------------------------
  if(run_admin2_bb8){
  bb.adm2.unstrat.nmr.allsurveys <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                                           Amat=admin2.mat, admin.level='Admin2',
                                           stratified=F, weight.strata=NULL,
                                           outcome='nmr',
                                           time.model='ar1', st.time.model='ar1',
                                           adj.frame=adj.frame, adj.varnames=adj.varnames,
                                            nsim = 1000)
  
  bb.fit.adm2.unstrat.nmr.allsurveys <- bb.adm2.unstrat.nmr.allsurveys[[1]]
  bb.res.adm2.unstrat.nmr.allsurveys <- bb.adm2.unstrat.nmr.allsurveys[[2]]
  
  bb.temporals.adm2.unstrat.nmr.allsurveys <- bb8_get_temporal_diag(
    bb.adm2.unstrat.nmr.allsurveys$fit,
    admin_level = "Admin2",
    year_label = beg.year:end.proj.year
  )
  bb.hyperpar.adm2.unstrat.nmr.allsurveys <- bb.fit.adm2.unstrat.nmr.allsurveys$fit$summary.hyperpar
  bb.fixed.adm2.unstrat.nmr.allsurveys <- bb.fit.adm2.unstrat.nmr.allsurveys$fit$summary.fixed
  
  # save summary of fit to a txt file
  sink(file=file.path("Betabinomial", "NMR", paste0(country, '_fit_adm2_unstrat_nmr_allsurveys.txt')))
  summary(bb.fit.adm2.unstrat.nmr.allsurveys)
  sink(file=NULL)
  # save smaller components of fit
  save(bb.temporals.adm2.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_temporals_adm2_unstrat_nmr_allsurveys.rda')))
  save(bb.hyperpar.adm2.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_hyperpar_adm2_unstrat_nmr_allsurveys.rda')))
  save(bb.fixed.adm2.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_fixed_adm2_unstrat_nmr_allsurveys.rda')))
  # save results
  save(bb.res.adm2.unstrat.nmr.allsurveys,file=file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_unstrat_nmr_allsurveys.rda')))
  }
} else if (bb8_resume_allsurvey_benchmarks) {
  message(
    "BB8_RESUME_ALLSURVEY_BENCHMARKS=1; retaining completed all-survey ",
    "base models and resuming at missing benchmarked models."
  )
} else {
  message(
    "BB8_RESUME_ALLSURVEY_ADMIN2_U5=1; retaining completed all-survey ",
    "NMR and lower-level U5MR outputs; resuming at the Admin-2 all-survey U5MR model."
  )
}
  
  
### U5MR -----------------------------------------------
  use_path_base(paste0(res.dir))
if (!bb8_resume_allsurvey_admin2_u5 && !bb8_resume_allsurvey_benchmarks) {
  
  #### National Unstrat ----------------------------------------------
  bb.natl.unstrat.u5.allsurveys <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                                           Amat=NULL, admin.level='National',
                                           stratified=F, weight.strata=NULL,
                                           outcome='u5mr', time.model='ar1',
                                           adj.frame=adj.frame, adj.varnames=adj.varnames,
                                            nsim = 1000)
  
  bb.fit.natl.unstrat.u5.allsurveys <- bb.natl.unstrat.u5.allsurveys[[1]]
  bb.res.natl.unstrat.u5.allsurveys <- bb.natl.unstrat.u5.allsurveys[[2]]
  
  bb.temporals.natl.unstrat.u5.allsurveys <- getDiag(bb.natl.unstrat.u5.allsurveys$fit,field = "time",year_label=beg.year:end.proj.year)
  bb.hyperpar.natl.unstrat.u5.allsurveys <- bb.fit.natl.unstrat.u5.allsurveys$fit$summary.hyperpar
  bb.fixed.natl.unstrat.u5.allsurveys <- bb.fit.natl.unstrat.u5.allsurveys$fit$summary.fixed
  
  # save summary of fit to a txt file
  sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_natl_unstrat_u5_allsurveys.txt')))
  summary(bb.fit.natl.unstrat.u5.allsurveys)
  sink(file=NULL)
  # save smaller components of fit
  save(bb.temporals.natl.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_natl_unstrat_u5_allsurveys.rda')))
  save(bb.hyperpar.natl.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_natl_unstrat_u5_allsurveys.rda')))
  save(bb.fixed.natl.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_natl_unstrat_u5_allsurveys.rda')))
  # save results
  save(bb.res.natl.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_unstrat_u5_allsurveys.rda')))
  
  #### Admin1 Unstrat ----------------------------------------------
  bb.adm1.unstrat.u5.allsurveys <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                                           Amat=admin1.mat, admin.level='Admin1',
                                           stratified=F, weight.strata=NULL,
                                           outcome='u5mr',
                                           time.model='ar1', st.time.model='ar1',
                                           adj.frame=adj.frame, adj.varnames=adj.varnames,
                                            nsim = 1000)
  
  bb.fit.adm1.unstrat.u5.allsurveys <- bb.adm1.unstrat.u5.allsurveys[[1]]
  bb.res.adm1.unstrat.u5.allsurveys <- bb.adm1.unstrat.u5.allsurveys[[2]]
  
  bb.temporals.adm1.unstrat.u5.allsurveys <- getDiag(bb.adm1.unstrat.u5.allsurveys$fit,field = "time",year_label=beg.year:end.proj.year)
  bb.hyperpar.adm1.unstrat.u5.allsurveys <- bb.fit.adm1.unstrat.u5.allsurveys$fit$summary.hyperpar
  bb.fixed.adm1.unstrat.u5.allsurveys <- bb.fit.adm1.unstrat.u5.allsurveys$fit$summary.fixed
  
  # save summary of fit to a txt file
  sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_adm1_unstrat_u5_allsurveys.txt')))
  summary(bb.fit.adm1.unstrat.u5.allsurveys)
  sink(file=NULL)
  # save smaller components of fit
  save(bb.temporals.adm1.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_adm1_unstrat_u5_allsurveys.rda')))
  save(bb.hyperpar.adm1.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_adm1_unstrat_u5_allsurveys.rda')))
  save(bb.fixed.adm1.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_adm1_unstrat_u5_allsurveys.rda')))
  # save results
  save(bb.res.adm1.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_unstrat_u5_allsurveys.rda')))
}
  
  #### Admin2 Unstrat ----------------------------------------------
  if(run_admin2_bb8 && !bb8_resume_allsurvey_benchmarks){
  bb.adm2.unstrat.u5.allsurveys <- getBB8(mod.dat, country, beg.year=beg.year, end.year=end.proj.year,
                                          Amat=admin2.mat, admin.level='Admin2',
                                          stratified=F, weight.strata=NULL,
                                          outcome='u5mr',
                                          time.model='ar1', st.time.model='ar1',
                                          adj.frame=adj.frame, adj.varnames=adj.varnames,
                                           nsim = 1000)
  
  bb.fit.adm2.unstrat.u5.allsurveys <- bb.adm2.unstrat.u5.allsurveys[[1]]
  bb.res.adm2.unstrat.u5.allsurveys <- bb.adm2.unstrat.u5.allsurveys[[2]]
  
  bb.temporals.adm2.unstrat.u5.allsurveys <- bb8_get_temporal_diag(
    bb.adm2.unstrat.u5.allsurveys$fit,
    admin_level = "Admin2",
    year_label = beg.year:end.proj.year
  )
  bb.hyperpar.adm2.unstrat.u5.allsurveys <- bb.fit.adm2.unstrat.u5.allsurveys$fit$summary.hyperpar
  bb.fixed.adm2.unstrat.u5.allsurveys <- bb.fit.adm2.unstrat.u5.allsurveys$fit$summary.fixed
  
  # save summary of fit to a txt file
  sink(file=file.path("Betabinomial", "U5MR", paste0(country, '_fit_adm2_unstrat_u5_allsurveys.txt')))
  summary(bb.fit.adm2.unstrat.u5.allsurveys)
  sink(file=NULL)
  # save smaller components of fit
  save(bb.temporals.adm2.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_temporals_adm2_unstrat_u5_allsurveys.rda')))
  save(bb.hyperpar.adm2.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_hyperpar_adm2_unstrat_u5_allsurveys.rda')))
  save(bb.fixed.adm2.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_fixed_adm2_unstrat_u5_allsurveys.rda')))
  # save results
  save(bb.res.adm2.unstrat.u5.allsurveys,file=file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_unstrat_u5_allsurveys.rda')))
}

  
## Get benchmarked unstratified models (using all surveys)  -----------------------------------------------
if (identical(final_model$strata.model, "unstrat") &&
    identical(final_model$bench.model, "bench")) {
use_path_base(res.dir)
  
  
### NMR -----------------------------------------------
  #### Admin1 Unstrat,  Benchmarked ----------------------------------------------
if (
  bb8_refresh_benchmarks_only ||
    !bb8_resume_allsurvey_benchmarks ||
    !is_direct_benchmark_file(file.path(
      "Betabinomial", "NMR",
      paste0(country, "_res_adm1_unstrat_nmr_allsurveys_bench.rda")
    ))
) {
  #get Benchmark adjustment
  if(!exists('bb.res.adm1.unstrat.nmr.allsurveys')){
    bb.res.adm1.unstrat.nmr.allsurveys <- bb8_load_saved_result(
      file.path(
        "Betabinomial", "NMR",
        paste0(country, "_res_adm1_unstrat_nmr_allsurveys.rda")
      ),
      "bb.res.adm1.unstrat.nmr.allsurveys"
    )
  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.adm1.unstrat.nmr.allsurveys$draws.est.overall,
    admin_weights = weight.adm1.u1,
    igme_ests = igme.ests.nmr
  )
  save(bench.adj, file = file.path("Betabinomial", "NMR", "adm1_unstrat_nmr_benchmarks.rda"))
  
  # National benchmarking is applied to HIV-adjusted posterior rates.
  bb.res.adm1.unstrat.nmr.allsurveys.bench <- benchmark_admin_result(bb.res.adm1.unstrat.nmr.allsurveys, bench.adj)
  save(bb.res.adm1.unstrat.nmr.allsurveys.bench, file=file.path("Betabinomial", "NMR",
       paste0(country, "_res_adm1_unstrat_nmr_allsurveys_bench.rda")))
  save_benchmark_source_diagnostics(country, "NMR", "adm1_unstrat_nmr_allsurveys", "adm1_unstrat_nmr_allsurveys_bench")
} else {
  message("Retaining completed Admin-1 all-survey NMR benchmark.")
}
  
  
  #### Admin2  Unstrat,  Benchmarked ----------------------------------------------
  
  if(run_admin2_bb8){
  if (
    bb8_refresh_benchmarks_only ||
      !bb8_resume_allsurvey_benchmarks ||
      !is_direct_benchmark_file(file.path(
        "Betabinomial", "NMR",
        paste0(country, "_res_adm2_unstrat_nmr_allsurveys_bench.rda")
      ))
  ) {
  #get Benchmark adjustment
  if(!exists('bb.res.adm2.unstrat.nmr.allsurveys')){
    bb.res.adm2.unstrat.nmr.allsurveys <- bb8_load_saved_result(
      file.path(
        "Betabinomial", "NMR",
        paste0(country, "_res_adm2_unstrat_nmr_allsurveys.rda")
      ),
      "bb.res.adm2.unstrat.nmr.allsurveys"
    )
  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.adm2.unstrat.nmr.allsurveys$draws.est.overall,
    admin_weights = weight.adm2.u1,
    igme_ests = igme.ests.nmr
  )
  save(bench.adj, file = file.path("Betabinomial", "NMR", "adm2_unstrat_nmr_benchmarks.rda"))
  
  # National benchmarking is applied to HIV-adjusted posterior rates.
  bb.res.adm2.unstrat.nmr.allsurveys.bench <- benchmark_admin_result(bb.res.adm2.unstrat.nmr.allsurveys, bench.adj)
  save(bb.res.adm2.unstrat.nmr.allsurveys.bench, file=file.path("Betabinomial", "NMR",
       paste0(country, "_res_adm2_unstrat_nmr_allsurveys_bench.rda")))
  save_benchmark_source_diagnostics(country, "NMR", "adm2_unstrat_nmr_allsurveys", "adm2_unstrat_nmr_allsurveys_bench")
  } else {
    message("Retaining completed Admin-2 all-survey NMR benchmark.")
  }
  }
  
### U5MR -----------------------------------------------
  #### Admin1 Unstrat,  Benchmarked ----------------------------------------------
if (
  bb8_refresh_benchmarks_only ||
    !bb8_resume_allsurvey_benchmarks ||
    !is_direct_benchmark_file(file.path(
      "Betabinomial", "U5MR",
      paste0(country, "_res_adm1_unstrat_u5_allsurveys_bench.rda")
    ))
) {
  #get Benchmark adjustment
  if(!exists('bb.res.adm1.unstrat.u5.allsurveys')){
    bb.res.adm1.unstrat.u5.allsurveys <- bb8_load_saved_result(
      file.path(
        "Betabinomial", "U5MR",
        paste0(country, "_res_adm1_unstrat_u5_allsurveys.rda")
      ),
      "bb.res.adm1.unstrat.u5.allsurveys"
    )
  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.adm1.unstrat.u5.allsurveys$draws.est.overall,
    admin_weights = weight.adm1.u5,
    igme_ests = igme.ests.u5
  )
  save(bench.adj, file = file.path("Betabinomial", "U5MR", "adm1_unstrat_u5_benchmarks.rda"))
  
  # National benchmarking is applied to HIV-adjusted posterior rates.
  bb.res.adm1.unstrat.u5.allsurveys.bench <- benchmark_admin_result(bb.res.adm1.unstrat.u5.allsurveys, bench.adj)
  save(bb.res.adm1.unstrat.u5.allsurveys.bench, file=file.path("Betabinomial", "U5MR",
       paste0(country, "_res_adm1_unstrat_u5_allsurveys_bench.rda")))
  save_benchmark_source_diagnostics(country, "U5MR", "adm1_unstrat_u5_allsurveys", "adm1_unstrat_u5_allsurveys_bench")
} else {
  message("Retaining completed Admin-1 all-survey U5MR benchmark.")
}
  
  
  #### Admin2  Unstrat,  Benchmarked ----------------------------------------------
  if(run_admin2_bb8){
  if (
    bb8_refresh_benchmarks_only ||
      !bb8_resume_allsurvey_benchmarks ||
      !is_direct_benchmark_file(file.path(
        "Betabinomial", "U5MR",
        paste0(country, "_res_adm2_unstrat_u5_allsurveys_bench.rda")
      ))
  ) {
  #get Benchmark adjustment
  if(!exists('bb.res.adm2.unstrat.u5.allsurveys')){
    bb.res.adm2.unstrat.u5.allsurveys <- bb8_load_saved_result(
      file.path(
        "Betabinomial", "U5MR",
        paste0(country, "_res_adm2_unstrat_u5_allsurveys.rda")
      ),
      "bb.res.adm2.unstrat.u5.allsurveys"
    )
  }

  bench.adj <- compute_admin_benchmark_adjustment(
    country = country,
    years = beg.year:end.proj.year,
    admin_draws = bb.res.adm2.unstrat.u5.allsurveys$draws.est.overall,
    admin_weights = weight.adm2.u5,
    igme_ests = igme.ests.u5
  )
  save(bench.adj, file = file.path("Betabinomial", "U5MR", "adm2_unstrat_u5_benchmarks.rda"))
  
  # National benchmarking is applied to HIV-adjusted posterior rates.
  bb.res.adm2.unstrat.u5.allsurveys.bench <- benchmark_admin_result(bb.res.adm2.unstrat.u5.allsurveys, bench.adj)
  save(bb.res.adm2.unstrat.u5.allsurveys.bench, file=file.path("Betabinomial", "U5MR",
       paste0(country, "_res_adm2_unstrat_u5_allsurveys_bench.rda")))
  save_benchmark_source_diagnostics(country, "U5MR", "adm2_unstrat_u5_allsurveys", "adm2_unstrat_u5_allsurveys_bench")
  } else {
    message("Retaining completed Admin-2 all-survey U5MR benchmark.")
  }
  }
  
  
# about 4 hours to run the whole script
} # benchmark only the JSON-selected unstratified model
} # selected all-survey family
  

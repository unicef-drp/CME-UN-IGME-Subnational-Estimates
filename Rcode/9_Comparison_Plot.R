USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}

# Step 9: Checking BB8 Results

# This script is based on 6_Comparison_Plot.R, but is intended for the
# post-BB8 review workflow. It keeps the existing static comparison PDFs and
# also writes one comparison data bundle that is rendered by
# 9_Comparison_Plot.qmd into an interactive HTML dashboard.
#
# The interactive report focuses on:
# - benchmarked versus unbenchmarked BB8 outputs;
# - model-implied national aggregates versus IGME;
# - same-frame stratified benchmarked models versus all-survey unstratified
#   benchmarked models;
# - available and missing BB8 result files.


# Country context is loaded by Rcode/1_Preperation.R.

# Setup
# Load libraries and info ----------------------------------------------------------

options(gsubfn.engine = "R")
library(SUMMER)
library(dplyr)
library(sf)
library(scales)

home.dir <- project_home()
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
source(file.path(home.dir, "Rcode", "_supporting_scripts",
                 "admin_benchmark_helpers.R"))
require_country_context()
strata.model <- final_model$strata.model
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}
bb8_admin1_only <- tolower(Sys.getenv("BB8_ADMIN1_ONLY", "0")) %in%
  c("1", "true", "yes", "y")
run_admin2_outputs <- exists("poly.layer.adm2", inherits = TRUE) &&
  !bb8_admin1_only
if (bb8_admin1_only) {
  message("BB8_ADMIN1_ONLY=1; skipping Admin-2 comparison outputs.")
}

# Load polygon files  ------------------------------------------------------
use_path_base(data.dir)

if(!dir.exists(file.path(res.dir, "Figures", "Summary"))){
  dir.create(file.path(res.dir, "Figures", "Summary"))}
if(!dir.exists(file.path(res.dir, "Figures", "Summary", "U5MR"))){
  dir.create(file.path(res.dir, "Figures", "Summary", "U5MR"))}
if(!dir.exists(file.path(res.dir, "Figures", "Summary", "NMR"))){
  dir.create(file.path(res.dir, "Figures", "Summary", "NMR"))}

#### Load admin names  ------------------------------------------------------

load(file.path(poly.path, paste0(country, "_Amat.rda")))
load(file.path(poly.path, paste0(country, "_Amat_Names.rda")))


#### Load IGME estimates ------------------------------------------------------
{
  use_path_base(file.path(home.dir, "Data", "IGME"))
  
  ## U5MR
  igme.ests.u5.raw <- read.csv('igme2026_u5.csv')
  igme.ests.u5 <- igme.ests.u5.raw[igme.ests.u5.raw$ISO.Code==iso0,]
  igme.ests.u5 <- data.frame(t(igme.ests.u5[,10:ncol(igme.ests.u5)]))
  names(igme.ests.u5) <- c('LOWER_BOUND','OBS_VALUE','UPPER_BOUND')
  igme.ests.u5$year <-  as.numeric(stringr::str_remove(row.names(igme.ests.u5),'X')) - 0.5
  igme.ests.u5 <- igme.ests.u5[igme.ests.u5$year %in% 2000:end.proj.year,]
  rownames(igme.ests.u5) <- NULL
  igme.ests.u5$OBS_VALUE <- igme.ests.u5$OBS_VALUE/1000
  igme.ests.u5$SD <- (igme.ests.u5$UPPER_BOUND - igme.ests.u5$LOWER_BOUND)/(2*1.645*1000)
  igme.ests.u5$LOWER_BOUND <- igme.ests.u5$OBS_VALUE - 1.96*igme.ests.u5$SD
  igme.ests.u5$UPPER_BOUND <- igme.ests.u5$OBS_VALUE + 1.96*igme.ests.u5$SD
  
  ## NMR
  igme.ests.nmr.raw <- read.csv('igme2026_nmr.csv')
  igme.ests.nmr <- igme.ests.nmr.raw[igme.ests.nmr.raw$ISO.Code==iso0,]
  igme.ests.nmr <- data.frame(t(igme.ests.nmr[,10:ncol(igme.ests.nmr)]))
  names(igme.ests.nmr) <- c('LOWER_BOUND','OBS_VALUE','UPPER_BOUND')
  igme.ests.nmr$year <-  as.numeric(stringr::str_remove(row.names(igme.ests.nmr),'X')) - 0.5
  igme.ests.nmr <- igme.ests.nmr[igme.ests.nmr$year %in% 2000:end.proj.year,]
  rownames(igme.ests.nmr) <- NULL
  igme.ests.nmr$OBS_VALUE <- igme.ests.nmr$OBS_VALUE/1000
  igme.ests.nmr$SD <- (igme.ests.nmr$UPPER_BOUND - igme.ests.nmr$LOWER_BOUND)/(2*1.645*1000)
  igme.ests.nmr$LOWER_BOUND <- igme.ests.nmr$OBS_VALUE - 1.96*igme.ests.nmr$SD
  igme.ests.nmr$UPPER_BOUND <- igme.ests.nmr$OBS_VALUE + 1.96*igme.ests.nmr$SD
}

#### load admin1 and admin2 weights ####
load(file.path(data.dir, "worldpop", "adm1_weights_u1.rda"))
load(file.path(data.dir, "worldpop", "adm1_weights_u5.rda"))
if(run_admin2_outputs){
  load(file.path(data.dir, "worldpop", "adm2_weights_u1.rda"))
  load(file.path(data.dir, "worldpop", "adm2_weights_u5.rda"))
}

#### Parameters ####

## MIGHT NEED TO BE CHANGED depending on what you fit
time.model <- c('rw2','ar1')[2]

oneframe.env <- new.env()
load(file.path(data.dir, paste0(country, "_cluster_dat_1frame.rda")), envir = oneframe.env)
if (exists("mod.dat", envir = oneframe.env)) {
  mod.dat.1frame <- get("mod.dat", envir = oneframe.env)
} else if (exists("mod.dat.save", envir = oneframe.env)) {
  mod.dat.1frame <- get("mod.dat.save", envir = oneframe.env)
} else {
  stop("Could not find mod.dat or mod.dat.save in ", country, "_cluster_dat_1frame.rda")
}
end.year.1frame <- max(mod.dat.1frame$survey)

load(file.path(data.dir, paste0(country, "_cluster_dat.rda")), envir = .GlobalEnv)
end.year <- max(mod.dat$survey)


plot.years <- 2000:end.proj.year
n_years <- length(plot.years)

if(((end.year-beg.year+1) %% 3)==0){
  beg.period.years <- seq(beg.year,end.year,3) 
  end.period.years <- beg.period.years + 2 
}else if(((end.year-beg.year+1) %% 3)==1){
  beg.period.years <- c(beg.year,beg.year+2,seq(beg.year+4,end.year,3))
  end.period.years <- c(beg.year+1,beg.year+3,seq(beg.year+6,end.year,3))
}else if(((end.year-beg.year+1) %% 3)==2){
  beg.period.years <- c(beg.year,seq(beg.year+2,end.year,3))
  end.period.years <- c(beg.year+1,seq(beg.year+4,end.year,3))
}

# ? not sure what for 
if (end.year == end.proj.year) {
  beg.proj.years <- numeric(0)
} else if(end.year>=end.year.1frame & end.year>2018){
  beg.proj.years <- seq(end.year+1,end.proj.year,3)
}else{
  beg.proj.years <- seq(end.year+1,2020,3)
}
end.proj.years <- beg.proj.years+2
pane.years <- (c((end.period.years + beg.period.years)/2, (end.proj.years+beg.proj.years)/2))
pane.years <- pane.years[pane.years<=end.proj.year]
smoothed_direct_observed_cutoff <- max((beg.period.years + end.period.years) / 2)
est.period.idx <- 1:length(beg.period.years)
pred.period.idx <- if (length(beg.proj.years) > 0L) {
  (length(beg.period.years)+1):(length(beg.period.years)+length(beg.proj.years))
} else {
  integer(0)
}

##### function to organize posterior draws from BB8 ####

draw_1y_adm<-function(admin_draws, year_num,admin_vec, nsim=1000){
  
  # year_num: year of comparison
  # nsim: number of posterior draws
  # admin_vec: vector of admin index
  # admin_draws: posterior draws (as a list from SUMMER output)
  
  # prepare reference frame for draws 
  # ID corresponds to specific year, region
  draw_ID<-c(1:length(admin_draws))
  draw_year<-vector()
  draw_region<-vector()
  
  for( i in draw_ID){
    tmp_d<-admin_draws[[i]]
    draw_year[i]<-tmp_d$years
    draw_region[i]<-tmp_d$region
  }
  
  draw_ref<-data.frame(id=draw_ID,year=draw_year,
                       region=draw_region)
  
  draw_frame<-matrix( nrow = nsim, ncol = length(admin_vec))
  
  for(i in 1:length(admin_vec)){
    admin_i<-admin_vec[i]
    id_draw_set<-draw_ref[draw_ref$year==year_num&
                            draw_ref$region==admin_i,]$id 
    
    draw_set<-admin_draws[[id_draw_set]]$draws
    
    draw_frame[,i]<-draw_set
    #print(mean(r_frame[,c(admin_i)]))
  }
  
  colnames(draw_frame)<-admin_vec
  
  return(draw_frame)
}

#### prepare national level models ####
use_path_base(res.dir)

  ### national yearly smooth direct
{
  load(file = file.path("Direct", "NMR", paste0(country, '_res_natl_',time.model,'_yearly_nmr_SmoothedDirect.rda')))  
  load(file = file.path("Direct", "U5MR", paste0(country, '_res_natl_',time.model,'_yearly_u5_SmoothedDirect.rda')))
  
  natl.sd.est.nmr <- res.natl.yearly.nmr[res.natl.yearly.nmr$years %in% beg.year:end.proj.year, "median"]
  natl.sd.lower.nmr <- res.natl.yearly.nmr[res.natl.yearly.nmr$years %in% beg.year:end.proj.year, "lower"]
  natl.sd.upper.nmr <- res.natl.yearly.nmr[res.natl.yearly.nmr$years %in% beg.year:end.proj.year, "upper"]
  natl.sd.year.nmr <- res.natl.yearly.nmr[res.natl.yearly.nmr$years %in% beg.year:end.proj.year, "years"]
  
  natl.sd.est.u5 <- res.natl.yearly.u5[res.natl.yearly.u5$years %in% beg.year:end.proj.year, "median"]
  natl.sd.lower.u5 <- res.natl.yearly.u5[res.natl.yearly.u5$years %in% beg.year:end.proj.year, "lower"]
  natl.sd.upper.u5 <- res.natl.yearly.u5[res.natl.yearly.u5$years %in% beg.year:end.proj.year, "upper"]
  natl.sd.year.u5 <- res.natl.yearly.u5[res.natl.yearly.u5$years %in% beg.year:end.proj.year, "years"]
  
  natl.sd.frame<-data.frame()
  natl.sd.frame<-data.frame(lower_nmr=natl.sd.lower.nmr, median_nmr=natl.sd.est.nmr,upper_nmr=natl.sd.upper.nmr, 
                            lower_u5=natl.sd.lower.u5, median_u5=natl.sd.est.u5, upper_u5=natl.sd.upper.u5, 
                            method='natl.sd.yearly', years=natl.sd.year.u5)

}

  ### national betabinomial models
{
  if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_natl_unstrat_nmr.rda')))){
    load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_natl_unstrat_nmr.rda')))}
  if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_natl_strat_nmr.rda')))){
    load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_natl_strat_nmr.rda')))}
  if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_natl_unstrat_nmr_allsurveys.rda')))){
    load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_natl_unstrat_nmr_allsurveys.rda')))}
  if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_unstrat_u5.rda')))){
    load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_unstrat_u5.rda')))}  
  if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_strat_u5.rda')))){
    load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_strat_u5.rda')))}  
  if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_unstrat_u5_allsurveys.rda')))){
    load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_natl_unstrat_u5_allsurveys.rda')))}  
  
  if(exists('bb.res.natl.unstrat.nmr') & exists('bb.res.natl.unstrat.u5')){
    natl.bb.unstrat.frame <- data.frame(lower_nmr = bb.res.natl.unstrat.nmr$overall$lower, median_nmr = bb.res.natl.unstrat.nmr$overall$median, upper_nmr = bb.res.natl.unstrat.nmr$overall$upper,
                                        lower_u5 = bb.res.natl.unstrat.u5$overall$lower, median_u5 = bb.res.natl.unstrat.u5$overall$median, upper_u5 = bb.res.natl.unstrat.u5$overall$upper,
                                        method='natl.bb.unstrat',years=bb.res.natl.unstrat.nmr$overall$years)
  }else if(exists('bb.res.natl.unstrat.nmr')){
    natl.bb.unstrat.frame <- data.frame(lower_nmr = bb.res.natl.unstrat.nmr$overall$lower, median_nmr = bb.res.natl.unstrat.nmr$overall$median, upper_nmr = bb.res.natl.unstrat.nmr$overall$upper,
                                        lower_u5 = NA, median_u5 = NA, upper_u5 = NA,
                                        method='natl.bb.unstrat',years=bb.res.natl.unstrat.nmr$overall$years)
  }else if(exists('bb.res.natl.unstrat.u5')){
    natl.bb.unstrat.frame <- data.frame(lower_nmr =NA, median_nmr = NA, upper_nmr = NA,
                                        lower_u5 = bb.res.natl.unstrat.u5$overall$lower, median_u5 = bb.res.natl.unstrat.u5$overall$median, upper_u5 = bb.res.natl.unstrat.u5$overall$upper,
                                        method='natl.bb.unstrat',years=bb.res.natl.unstrat.u5$overall$years)
  }
  
  if(exists('bb.res.natl.strat.nmr') & exists('bb.res.natl.strat.u5')){
    natl.bb.strat.frame <- data.frame(lower_nmr = bb.res.natl.strat.nmr$overall$lower, median_nmr = bb.res.natl.strat.nmr$overall$median, upper_nmr = bb.res.natl.strat.nmr$overall$upper,
                                        lower_u5 = bb.res.natl.strat.u5$overall$lower, median_u5 = bb.res.natl.strat.u5$overall$median, upper_u5 = bb.res.natl.strat.u5$overall$upper,
                                        method='natl.bb.strat',years=bb.res.natl.strat.nmr$overall$years)
  }else if(exists('bb.res.natl.strat.nmr')){
    natl.bb.strat.frame <- data.frame(lower_nmr = bb.res.natl.strat.nmr$overall$lower, median_nmr = bb.res.natl.strat.nmr$overall$median, upper_nmr = bb.res.natl.strat.nmr$overall$upper,
                                        lower_u5 = NA, median_u5 = NA, upper_u5 = NA,
                                        method='natl.bb.strat',years=bb.res.natl.strat.nmr$overall$years)
  }else if(exists('bb.res.natl.strat.u5')){
    natl.bb.strat.frame <- data.frame(lower_nmr =NA, median_nmr = NA, upper_nmr = NA,
                                        lower_u5 = bb.res.natl.strat.u5$overall$lower, median_u5 = bb.res.natl.strat.u5$overall$median, upper_u5 = bb.res.natl.strat.u5$overall$upper,
                                        method='natl.bb.strat',years=bb.res.natl.strat.u5$overall$years)
  }
  
  if(exists('bb.res.natl.unstrat.nmr.allsurveys') & exists('bb.res.natl.unstrat.u5.allsurveys')){
    natl.bb.unstrat.allsurveys.frame <- data.frame(lower_nmr = bb.res.natl.unstrat.nmr.allsurveys$overall$lower, median_nmr = bb.res.natl.unstrat.nmr.allsurveys$overall$median, upper_nmr = bb.res.natl.unstrat.nmr.allsurveys$overall$upper,
                                        lower_u5 = bb.res.natl.unstrat.u5.allsurveys$overall$lower, median_u5 = bb.res.natl.unstrat.u5.allsurveys$overall$median, upper_u5 = bb.res.natl.unstrat.u5.allsurveys$overall$upper,
                                        method='natl.bb.unstrat.allsurveys',years=bb.res.natl.unstrat.nmr.allsurveys$overall$years)
  }else if(exists('bb.res.natl.unstrat.nmr.allsurveys')){
    natl.bb.unstrat.allsurveys.frame <- data.frame(lower_nmr = bb.res.natl.unstrat.nmr.allsurveys$overall$lower, median_nmr = bb.res.natl.unstrat.nmr.allsurveys$overall$median, upper_nmr = bb.res.natl.unstrat.nmr.allsurveys$overall$upper,
                                        lower_u5 = NA, median_u5 = NA, upper_u5 = NA,
                                        method='natl.bb.unstrat.allsurveys',years=bb.res.natl.unstrat.nmr.allsurveys$overall$years)
  }else if(exists('bb.res.natl.unstrat.u5.allsurveys')){
    natl.bb.unstrat.allsurveys.frame <- data.frame(lower_nmr =NA, median_nmr = NA, upper_nmr = NA,
                                        lower_u5 = bb.res.natl.unstrat.u5.allsurveys$overall$lower, median_u5 = bb.res.natl.unstrat.u5.allsurveys$overall$median, upper_u5 = bb.res.natl.unstrat.u5.allsurveys$overall$upper,
                                        method='natl.bb.unstrat.allsurveys',years=bb.res.natl.unstrat.u5.allsurveys$overall$years)
  }
}

#### prepare admin1 level models ####

  ### smooth direct admin1 3-year window
  {
  load(file = file.path("Direct", "NMR", paste0(country, '_res_admin1_',time.model,'_nmr_SmoothedDirect.rda')))
  admin1.sd.nmr <- res.admin1.nmr
  load(file = file.path("Direct", "U5MR", paste0(country, '_res_admin1_',time.model,'_u5_SmoothedDirect.rda')))  
  admin1.sd.u5 <- res.admin1.u5
  
  sd.adm1.to.natl.frame = matrix(NA, nrow = length(pane.years), ncol =  6)
  
  for (i in 1:length(pane.years)){
    year = round((pane.years)[i])
    
    adm1.pop.nmr <- weight.adm1.u1[weight.adm1.u1$years==year,]
    sd.nmr.tmp <- admin1.sd.nmr[admin1.sd.nmr$years.num==sort(unique(admin1.sd.nmr$years.num))[i],]
    sd.nmr.tmp <- merge(sd.nmr.tmp,adm1.pop.nmr,by='region')[,c('region','years.x','lower','median','upper','proportion')]
    sd.nmr.tmp$wt.lower <- sd.nmr.tmp$lower * sd.nmr.tmp$proportion
    sd.nmr.tmp$wt.median <- sd.nmr.tmp$median * sd.nmr.tmp$proportion
    sd.nmr.tmp$wt.upper <- sd.nmr.tmp$upper * sd.nmr.tmp$proportion
    
    adm1.pop.u5 <- weight.adm1.u5[weight.adm1.u5$years==year,]
    sd.u5.tmp <- admin1.sd.u5[admin1.sd.u5$years.num==sort(unique(admin1.sd.nmr$years.num))[i],]
    sd.u5.tmp <- merge(sd.u5.tmp,adm1.pop.u5,by='region')[,c('region','years.x','lower','median','upper','proportion')]
    sd.u5.tmp$wt.lower <- sd.u5.tmp$lower * sd.u5.tmp$proportion
    sd.u5.tmp$wt.median <- sd.u5.tmp$median * sd.u5.tmp$proportion
    sd.u5.tmp$wt.upper <- sd.u5.tmp$upper * sd.u5.tmp$proportion
    
    sd.adm1.to.natl.frame[i, ] = c(sum(sd.nmr.tmp$wt.lower),sum(sd.nmr.tmp$wt.median),sum(sd.nmr.tmp$wt.upper),sum(sd.u5.tmp$wt.lower),sum(sd.u5.tmp$wt.median),sum(sd.u5.tmp$wt.upper))
  }
  
  sd.adm1.to.natl.frame<-as.data.frame(sd.adm1.to.natl.frame)
  colnames(sd.adm1.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
  sd.adm1.to.natl.frame$method <- "aggre.sd.adm1"
  sd.adm1.to.natl.frame$years = pane.years
  sd.adm1.to.natl.frame <- sd.adm1.to.natl.frame[
    sd.adm1.to.natl.frame$years <= end.proj.year &
      sd.adm1.to.natl.frame$years <= smoothed_direct_observed_cutoff,
  ]
}
  ### smooth direct admin1 yearly
  {
  admin1.sd.yearly.nmr.file <- file.path("Direct", "NMR", paste0(country, '_res_admin1_',time.model,'_nmr_SmoothedDirect_yearly.rda'))
  admin1.sd.yearly.u5.file <- file.path("Direct", "U5MR", paste0(country, '_res_admin1_',time.model,'_u5_SmoothedDirect_yearly.rda'))

  if (file.exists(admin1.sd.yearly.nmr.file) || file.exists(admin1.sd.yearly.u5.file)) {
    if (file.exists(admin1.sd.yearly.nmr.file)) {
      load(file = admin1.sd.yearly.nmr.file)
      admin1.sd.yearly.nmr <- sd.admin1.yearly.nmr
    }
    if (file.exists(admin1.sd.yearly.u5.file)) {
      load(file = admin1.sd.yearly.u5.file)  
      admin1.sd.yearly.u5 <- sd.admin1.yearly.u5
    }

    sd.adm1.yl.to.natl.frame = matrix(NA, nrow = n_years, ncol =  6)

    for (i in 1:n_years){
      year = (beg.year:end.proj.year)[i]

      if (exists("admin1.sd.yearly.nmr")) {
        adm1.pop.nmr <- weight.adm1.u1[weight.adm1.u1$years==year,]
        sd.nmr.tmp <- admin1.sd.yearly.nmr[admin1.sd.yearly.nmr$years.num==year,]
        sd.nmr.tmp <- merge(sd.nmr.tmp,adm1.pop.nmr,by='region')[,c('region','years.x','lower','median','upper','proportion')]
        sd.nmr.tmp$wt.lower <- sd.nmr.tmp$lower * sd.nmr.tmp$proportion
        sd.nmr.tmp$wt.median <- sd.nmr.tmp$median * sd.nmr.tmp$proportion
        sd.nmr.tmp$wt.upper <- sd.nmr.tmp$upper * sd.nmr.tmp$proportion
        sd.adm1.yl.to.natl.frame[i, 1:3] = c(sum(sd.nmr.tmp$wt.lower),sum(sd.nmr.tmp$wt.median),sum(sd.nmr.tmp$wt.upper))
      }

      if (exists("admin1.sd.yearly.u5")) {
        adm1.pop.u5 <- weight.adm1.u5[weight.adm1.u5$years==year,]
        sd.u5.tmp <- admin1.sd.yearly.u5[admin1.sd.yearly.u5$years.num==year,]
        sd.u5.tmp <- merge(sd.u5.tmp,adm1.pop.u5,by='region')[,c('region','years.x','lower','median','upper','proportion')]
        sd.u5.tmp$wt.lower <- sd.u5.tmp$lower * sd.u5.tmp$proportion
        sd.u5.tmp$wt.median <- sd.u5.tmp$median * sd.u5.tmp$proportion
        sd.u5.tmp$wt.upper <- sd.u5.tmp$upper * sd.u5.tmp$proportion
        sd.adm1.yl.to.natl.frame[i, 4:6] = c(sum(sd.u5.tmp$wt.lower),sum(sd.u5.tmp$wt.median),sum(sd.u5.tmp$wt.upper))
      }
    }

    sd.adm1.yl.to.natl.frame<-as.data.frame(sd.adm1.yl.to.natl.frame)
    colnames(sd.adm1.yl.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
    sd.adm1.yl.to.natl.frame$method <- "aggre.sd.yearly.adm1"
    sd.adm1.yl.to.natl.frame$years = beg.year:end.proj.year
    sd.adm1.yl.to.natl.frame <- sd.adm1.yl.to.natl.frame[
      sd.adm1.yl.to.natl.frame$years <= smoothed_direct_observed_cutoff,
    ]
  }
}
  ### BB8 admin1 unstratified
  {
  
  if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_unstrat_nmr.rda')))){
    load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_unstrat_nmr.rda')))
    res.unstrat.admin1.nmr <- bb.res.adm1.unstrat.nmr
    admin1.unstrat.nmr.BB8<-res.unstrat.admin1.nmr$overall}
  if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_unstrat_u5.rda')))){
    load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_unstrat_u5.rda')))
    res.unstrat.admin1.u5 <- bb.res.adm1.unstrat.u5
    admin1.unstrat.u5.BB8<-res.unstrat.admin1.u5$overall} 
  
  if(exists('admin1.unstrat.nmr.BB8') | exists('admin1.unstrat.u5.BB8')){
    
    BB8.adm1.unstrat.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
    for (i in 1:n_years){
      year = (beg.year:end.proj.year)[i]
      
      if(exists('admin1.unstrat.nmr.BB8')){
        adm1.pop.nmr <- weight.adm1.u1[weight.adm1.u1$years==year,]
        admin1.unstrat.nmr.BB8.draw<-draw_1y_adm(admin_draws=res.unstrat.admin1.nmr$draws.est.overall,
                                               year_num=year,
                                               admin_vec=admin1.names$Internal)
        natl.tmp.nmr <- weight_admin_draw_matrix(
          admin1.unstrat.nmr.BB8.draw, adm1.pop.nmr
        )
        BB8.adm1.unstrat.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
      }
      
      if(exists('admin1.unstrat.u5.BB8')){
        adm1.pop.u5 <- weight.adm1.u5[weight.adm1.u5$years==year,]
        admin1.unstrat.u5.BB8.draw<-draw_1y_adm(admin_draws=res.unstrat.admin1.u5$draws.est.overall,
                                              year_num=year,
                                              admin_vec=admin1.names$Internal)
        natl.tmp.u5 <- weight_admin_draw_matrix(
          admin1.unstrat.u5.BB8.draw, adm1.pop.u5
        )
        BB8.adm1.unstrat.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
      }
      
    }
    
    BB8.adm1.unstrat.to.natl.frame<-as.data.frame(BB8.adm1.unstrat.to.natl.frame)
    colnames(BB8.adm1.unstrat.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
    BB8.adm1.unstrat.to.natl.frame$method <- "aggre.adm1.unstrat.BB8"
    BB8.adm1.unstrat.to.natl.frame$years = beg.year:end.proj.year
  }
  }
  ### BB8 admin1 unstratified, all surveys
  {
  
  if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_unstrat_nmr_allsurveys.rda')))){
    load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_unstrat_nmr_allsurveys.rda')))
    res.unstrat.admin1.nmr.allsurveys <- bb.res.adm1.unstrat.nmr.allsurveys
    admin1.unstrat.nmr.allsurveys.BB8<-res.unstrat.admin1.nmr.allsurveys$overall}
  if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_unstrat_u5_allsurveys.rda')))){
    load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_unstrat_u5_allsurveys.rda')))
    res.unstrat.admin1.u5.allsurveys <- bb.res.adm1.unstrat.u5.allsurveys
    admin1.unstrat.u5.allsurveys.BB8<-res.unstrat.admin1.u5.allsurveys$overall} 
  
  if(exists('admin1.unstrat.nmr.allsurveys.BB8') | exists('admin1.unstrat.u5.allsurveys.BB8')){
    
    BB8.adm1.unstrat.allsurveys.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
    for (i in 1:n_years){
      year = (beg.year:end.proj.year)[i]
      
      if(exists('admin1.unstrat.nmr.allsurveys.BB8')){
        adm1.pop.nmr <- weight.adm1.u1[weight.adm1.u1$years==year,]
        admin1.unstrat.nmr.allsurveys.BB8.draw<-draw_1y_adm(admin_draws=res.unstrat.admin1.nmr.allsurveys$draws.est.overall,
                                                 year_num=year,
                                                 admin_vec=admin1.names$Internal)
        natl.tmp.nmr <- weight_admin_draw_matrix(
          admin1.unstrat.nmr.allsurveys.BB8.draw, adm1.pop.nmr
        )
        BB8.adm1.unstrat.allsurveys.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
      }
      
      if(exists('admin1.unstrat.u5.allsurveys.BB8')){
        adm1.pop.u5 <- weight.adm1.u5[weight.adm1.u5$years==year,]
        admin1.unstrat.u5.allsurveys.BB8.draw<-draw_1y_adm(admin_draws=res.unstrat.admin1.u5.allsurveys$draws.est.overall,
                                                year_num=year,
                                                admin_vec=admin1.names$Internal)
        natl.tmp.u5 <- weight_admin_draw_matrix(
          admin1.unstrat.u5.allsurveys.BB8.draw, adm1.pop.u5
        )
        BB8.adm1.unstrat.allsurveys.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
      }
      
    }
    
    BB8.adm1.unstrat.allsurveys.to.natl.frame<-as.data.frame(BB8.adm1.unstrat.allsurveys.to.natl.frame)
    colnames(BB8.adm1.unstrat.allsurveys.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
    BB8.adm1.unstrat.allsurveys.to.natl.frame$method <- "aggre.adm1.unstrat.allsurveys.BB8"
    BB8.adm1.unstrat.allsurveys.to.natl.frame$years = beg.year:end.proj.year
  }
}
  ### BB8 admin1 unstratified, all surveys, benchmarked
  {
  
  if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_unstrat_nmr_allsurveys_bench.rda')))){
    load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_unstrat_nmr_allsurveys_bench.rda')))
    res.unstrat.admin1.nmr.allsurveys.bench <- bb.res.adm1.unstrat.nmr.allsurveys.bench
    admin1.unstrat.nmr.allsurveys.BB8.bench<-res.unstrat.admin1.nmr.allsurveys.bench$overall}
  if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_unstrat_u5_allsurveys_bench.rda')))){
    adm1.unstrat.u5.allsurveys.bench.file <- select_comparison_u5_result_file(
      file.path(
        res.dir, "Betabinomial", "U5MR",
        paste0(country, '_res_adm1_unstrat_u5_allsurveys_bench.rda')
      ),
      candidate_strata_model = "unstrat",
      candidate_survey_frame = "all_surveys",
      final_strata_model = strata.model
    )
    load(file = adm1.unstrat.u5.allsurveys.bench.file)
    res.unstrat.admin1.u5.allsurveys.bench <- bb.res.adm1.unstrat.u5.allsurveys.bench
    admin1.unstrat.u5.allsurveys.BB8.bench<-res.unstrat.admin1.u5.allsurveys.bench$overall} 
  
  if(exists('admin1.unstrat.nmr.allsurveys.BB8.bench') | exists('admin1.unstrat.u5.allsurveys.BB8.bench')){
    
    BB8.adm1.unstrat.allsurveys.bench.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
    for (i in 1:n_years){
      year = (beg.year:end.proj.year)[i]
      
      if(exists('admin1.unstrat.nmr.allsurveys.BB8.bench')){
        adm1.pop.nmr <- weight.adm1.u1[weight.adm1.u1$years==year,]
        admin1.unstrat.nmr.allsurveys.BB8.bench.draw<-draw_1y_adm(admin_draws=res.unstrat.admin1.nmr.allsurveys.bench$draws.est.overall,
                                                            year_num=year,
                                                            admin_vec=admin1.names$Internal,
                                                            nsim=length(res.unstrat.admin1.nmr.allsurveys.bench$draws.est.overall[[1]]$draws))
        natl.tmp.nmr <- weight_admin_draw_matrix(
          admin1.unstrat.nmr.allsurveys.BB8.bench.draw, adm1.pop.nmr
        )
        BB8.adm1.unstrat.allsurveys.bench.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
      }
      
      if(exists('admin1.unstrat.u5.allsurveys.BB8.bench')){
        adm1.pop.u5 <- weight.adm1.u5[weight.adm1.u5$years==year,]
        admin1.unstrat.u5.allsurveys.BB8.bench.draw<-draw_1y_adm(admin_draws=res.unstrat.admin1.u5.allsurveys.bench$draws.est.overall,
                                                           year_num=year,
                                                           admin_vec=admin1.names$Internal)
        natl.tmp.u5 <- weight_admin_draw_matrix(
          admin1.unstrat.u5.allsurveys.BB8.bench.draw, adm1.pop.u5
        )
        BB8.adm1.unstrat.allsurveys.bench.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
      }
      
    }
    
    BB8.adm1.unstrat.allsurveys.bench.to.natl.frame<-as.data.frame(BB8.adm1.unstrat.allsurveys.bench.to.natl.frame)
    colnames(BB8.adm1.unstrat.allsurveys.bench.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
    BB8.adm1.unstrat.allsurveys.bench.to.natl.frame$method <- "aggre.adm1.unstrat.allsurveys.BB8.bench"
    BB8.adm1.unstrat.allsurveys.bench.to.natl.frame$years = beg.year:end.proj.year
  }
}
  ### BB8 admin1 stratified
  {
  
  if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_strat_nmr.rda')))){
    load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_strat_nmr.rda')))
    res.strat.admin1.nmr <- bb.res.adm1.strat.nmr
    admin1.strat.nmr.BB8<-res.strat.admin1.nmr$overall}
  if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_strat_u5.rda')))){
    load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_strat_u5.rda')))
    res.strat.admin1.u5 <- bb.res.adm1.strat.u5
    admin1.strat.u5.BB8<-res.strat.admin1.u5$overall} 
  
  if(exists('admin1.strat.nmr.BB8') | exists('admin1.strat.u5.BB8')){
  
  BB8.adm1.strat.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
  for (i in 1: n_years){
    year = (beg.year:end.proj.year)[i]
    
    if(exists('admin1.strat.nmr.BB8')){
    adm1.pop.nmr <- weight.adm1.u1[weight.adm1.u1$years==year,]
    admin1.strat.nmr.BB8.draw<-draw_1y_adm(admin_draws=res.strat.admin1.nmr$draws.est.overall,
                                           year_num=year,
                                           admin_vec=admin1.names$Internal)
    natl.tmp.nmr <- weight_admin_draw_matrix(
      admin1.strat.nmr.BB8.draw, adm1.pop.nmr
    )
    BB8.adm1.strat.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
    }
    
    if(exists('admin1.strat.u5.BB8')){
    adm1.pop.u5 <- weight.adm1.u5[weight.adm1.u5$years==year,]
    admin1.strat.u5.BB8.draw<-draw_1y_adm(admin_draws=res.strat.admin1.u5$draws.est.overall,
                                          year_num=year,
                                          admin_vec=admin1.names$Internal)
    natl.tmp.u5 <- weight_admin_draw_matrix(
      admin1.strat.u5.BB8.draw, adm1.pop.u5
    )
    BB8.adm1.strat.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
    }

  }
  
  BB8.adm1.strat.to.natl.frame<-as.data.frame(BB8.adm1.strat.to.natl.frame)
  colnames(BB8.adm1.strat.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
  BB8.adm1.strat.to.natl.frame$method <- "aggre.adm1.strat.BB8"
  BB8.adm1.strat.to.natl.frame$years = beg.year:end.proj.year
  }
}
  ### BB8 admin1 stratified, benchmarked
  {
  
  if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_strat_nmr_bench.rda')))){
    load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm1_strat_nmr_bench.rda')))
    res.strat.admin1.nmr.bench <- bb.res.adm1.strat.nmr.bench
    admin1.strat.nmr.BB8.bench<-res.strat.admin1.nmr.bench$overall}
  if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm1_strat_u5_bench.rda')))){
    adm1.strat.u5.bench.file <- select_comparison_u5_result_file(
      file.path(
        res.dir, "Betabinomial", "U5MR",
        paste0(country, '_res_adm1_strat_u5_bench.rda')
      ),
      candidate_strata_model = "strat",
      candidate_survey_frame = "same_frame",
      final_strata_model = strata.model
    )
    load(file = adm1.strat.u5.bench.file)
    res.strat.admin1.u5.bench <- bb.res.adm1.strat.u5.bench
    admin1.strat.u5.BB8.bench<-res.strat.admin1.u5.bench$overall} 
  
  if(exists('admin1.strat.nmr.BB8.bench') | exists('admin1.strat.u5.BB8.bench')){
    
    BB8.adm1.strat.bench.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
    for (i in 1:n_years){
      year = (beg.year:end.proj.year)[i]
      
      if(exists('admin1.strat.nmr.BB8.bench')){
        adm1.pop.nmr <- weight.adm1.u1[weight.adm1.u1$years==year,]
        admin1.strat.nmr.BB8.bench.draw<-draw_1y_adm(admin_draws=res.strat.admin1.nmr.bench$draws.est.overall,
                                               year_num=year,
                                               admin_vec=admin1.names$Internal,
                                               nsim=length(res.strat.admin1.nmr.bench$draws.est.overall[[1]]$draws))
        natl.tmp.nmr <- weight_admin_draw_matrix(
          admin1.strat.nmr.BB8.bench.draw, adm1.pop.nmr
        )
        BB8.adm1.strat.bench.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
      }
      
      if(exists('admin1.strat.u5.BB8.bench')){
        adm1.pop.u5 <- weight.adm1.u5[weight.adm1.u5$years==year,]
        admin1.strat.u5.BB8.bench.draw<-draw_1y_adm(admin_draws=res.strat.admin1.u5.bench$draws.est.overall,
                                              year_num=year,
                                              admin_vec=admin1.names$Internal)
        natl.tmp.u5 <- weight_admin_draw_matrix(
          admin1.strat.u5.BB8.bench.draw, adm1.pop.u5
        )
        BB8.adm1.strat.bench.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
      }
      
    }
    
    BB8.adm1.strat.bench.to.natl.frame<-as.data.frame(BB8.adm1.strat.bench.to.natl.frame)
    colnames(BB8.adm1.strat.bench.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
    BB8.adm1.strat.bench.to.natl.frame$method <- "aggre.adm1.strat.BB8.bench"
    BB8.adm1.strat.bench.to.natl.frame$years = beg.year:end.proj.year
  }
}

#### prepare admin2 level models ####
if(run_admin2_outputs){
  ### smooth direct admin2 3-year window
  {
    admin2.sd.nmr.file <- file.path(
      "Direct", "NMR",
      paste0(country, "_res_admin2_", time.model,
             "_nmr_SmoothedDirect.rda")
    )
    admin2.sd.u5.file <- file.path(
      "Direct", "U5MR",
      paste0(country, "_res_admin2_", time.model,
             "_u5_SmoothedDirect.rda")
    )

    if (file.exists(admin2.sd.nmr.file)) {
      load(admin2.sd.nmr.file)
      admin2.sd.nmr <- res.admin2.nmr
    } else {
      message("Skipping missing Admin-2 period smoothed-direct NMR: ",
              admin2.sd.nmr.file)
    }
    if (file.exists(admin2.sd.u5.file)) {
      load(admin2.sd.u5.file)
      admin2.sd.u5 <- res.admin2.u5
    } else {
      message("Skipping missing Admin-2 period smoothed-direct U5MR: ",
              admin2.sd.u5.file)
    }

    if (exists("admin2.sd.nmr") || exists("admin2.sd.u5")) {
      sd.adm2.to.natl.frame <- matrix(
        NA_real_, nrow = length(pane.years), ncol = 6
      )

      for (i in seq_along(pane.years)) {
        year <- round(pane.years[i])

        if (exists("admin2.sd.nmr")) {
          adm2.pop.nmr <- weight.adm2.u1[weight.adm2.u1$years == year, ]
          sd.nmr.tmp <- admin2.sd.nmr[
            admin2.sd.nmr$years.num ==
              sort(unique(admin2.sd.nmr$years.num))[i], ]
          sd.nmr.tmp <- merge(
            sd.nmr.tmp, adm2.pop.nmr, by = "region"
          )[, c("region", "years.x", "lower", "median", "upper",
                 "proportion")]
          sd.adm2.to.natl.frame[i, 1:3] <- c(
            sum(sd.nmr.tmp$lower * sd.nmr.tmp$proportion),
            sum(sd.nmr.tmp$median * sd.nmr.tmp$proportion),
            sum(sd.nmr.tmp$upper * sd.nmr.tmp$proportion)
          )
        }

        if (exists("admin2.sd.u5")) {
          adm2.pop.u5 <- weight.adm2.u5[weight.adm2.u5$years == year, ]
          sd.u5.tmp <- admin2.sd.u5[
            admin2.sd.u5$years.num ==
              sort(unique(admin2.sd.u5$years.num))[i], ]
          sd.u5.tmp <- merge(
            sd.u5.tmp, adm2.pop.u5, by = "region"
          )[, c("region", "years.x", "lower", "median", "upper",
                 "proportion")]
          sd.adm2.to.natl.frame[i, 4:6] <- c(
            sum(sd.u5.tmp$lower * sd.u5.tmp$proportion),
            sum(sd.u5.tmp$median * sd.u5.tmp$proportion),
            sum(sd.u5.tmp$upper * sd.u5.tmp$proportion)
          )
        }
      }

      sd.adm2.to.natl.frame <- as.data.frame(sd.adm2.to.natl.frame)
      colnames(sd.adm2.to.natl.frame) <- c(
        "lower_nmr", "median_nmr", "upper_nmr",
        "lower_u5", "median_u5", "upper_u5"
      )
      sd.adm2.to.natl.frame$method <- "aggre.sd.adm2"
      sd.adm2.to.natl.frame$years <- pane.years
      sd.adm2.to.natl.frame <- sd.adm2.to.natl.frame[
        sd.adm2.to.natl.frame$years <= end.proj.year, ]
    }
  }
  ### smooth direct admin2 yearly
  {
    if(file.exists(file.path("Direct", "NMR", paste0(country, '_res_admin2_',time.model,'_nmr_SmoothedDirect_yearly.rda')))){
      load(file = file.path("Direct", "NMR", paste0(country, '_res_admin2_',time.model,'_nmr_SmoothedDirect_yearly.rda')))
      admin2.sd.yearly.nmr <- sd.admin2.yearly.nmr}
    if(file.exists(file.path("Direct", "U5MR", paste0(country, '_res_admin2_',time.model,'_u5_SmoothedDirect_yearly.rda')))){
      load(file = file.path("Direct", "U5MR", paste0(country, '_res_admin2_',time.model,'_u5_SmoothedDirect_yearly.rda')))  
      admin2.sd.yearly.u5 <- sd.admin2.yearly.u5}
    
    if(exists('admin2.sd.yearly.nmr') | exists('admin2.sd.yearly.u5')){
    sd.adm2.yl.to.natl.frame = matrix(NA, nrow = n_years, ncol =  6)
    
    for (i in 1:n_years){
      year = (beg.year:end.proj.year)[i]
      
      if(exists('admin2.sd.yearly.nmr')){
      adm2.pop.nmr <- weight.adm2.u1[weight.adm2.u1$years==year,]
      sd.nmr.tmp <- admin2.sd.yearly.nmr[admin2.sd.yearly.nmr$years.num==year,]
      sd.nmr.tmp <- merge(sd.nmr.tmp,adm2.pop.nmr,by='region')[,c('region','years.x','lower','median','upper','proportion')]
      sd.nmr.tmp$wt.lower <- sd.nmr.tmp$lower * sd.nmr.tmp$proportion
      sd.nmr.tmp$wt.median <- sd.nmr.tmp$median * sd.nmr.tmp$proportion
      sd.nmr.tmp$wt.upper <- sd.nmr.tmp$upper * sd.nmr.tmp$proportion
      sd.adm2.yl.to.natl.frame[i, 1:3] <- c(sum(sd.nmr.tmp$wt.lower),sum(sd.nmr.tmp$wt.median),sum(sd.nmr.tmp$wt.upper))
      }
      
      if(exists('admin2.sd.yearly.u5')){
      adm2.pop.u5 <- weight.adm2.u5[weight.adm2.u5$years==year,]
      sd.u5.tmp <- admin2.sd.yearly.u5[admin2.sd.yearly.u5$years.num==year,]
      sd.u5.tmp <- merge(sd.u5.tmp,adm2.pop.u5,by='region')[,c('region','years.x','lower','median','upper','proportion')]
      sd.u5.tmp$wt.lower <- sd.u5.tmp$lower * sd.u5.tmp$proportion
      sd.u5.tmp$wt.median <- sd.u5.tmp$median * sd.u5.tmp$proportion
      sd.u5.tmp$wt.upper <- sd.u5.tmp$upper * sd.u5.tmp$proportion
      
      sd.adm2.yl.to.natl.frame[i, 4:6] <- c(sum(sd.u5.tmp$wt.lower),sum(sd.u5.tmp$wt.median),sum(sd.u5.tmp$wt.upper))
      }
    }
    
    sd.adm2.yl.to.natl.frame<-as.data.frame(sd.adm2.yl.to.natl.frame)
    colnames(sd.adm2.yl.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
    sd.adm2.yl.to.natl.frame$method <- "aggre.sd.yearly.adm2"
    sd.adm2.yl.to.natl.frame$years = beg.year:end.proj.year
    }
  }
  ### BB8 admin2 unstratified
  {
    
    if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_unstrat_nmr.rda')))){
      load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_unstrat_nmr.rda')))
      res.unstrat.admin2.nmr <- bb.res.adm2.unstrat.nmr
      admin2.unstrat.nmr.BB8<-res.unstrat.admin2.nmr$overall}
    if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_unstrat_u5.rda')))){
      load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_unstrat_u5.rda')))
      res.unstrat.admin2.u5 <- bb.res.adm2.unstrat.u5
      admin2.unstrat.u5.BB8<-res.unstrat.admin2.u5$overall} 
    
    if(exists('admin2.unstrat.nmr.BB8') | exists('admin2.unstrat.u5.BB8')){
      
      BB8.adm2.unstrat.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
      for (i in 1: n_years){
        year = (beg.year:end.proj.year)[i]
        
        if(exists('admin2.unstrat.nmr.BB8')){
          adm2.pop.nmr <- weight.adm2.u1[weight.adm2.u1$years==year,]
          admin2.unstrat.nmr.BB8.draw<-draw_1y_adm(admin_draws=res.unstrat.admin2.nmr$draws.est.overall,
                                                 year_num=year,
                                                 admin_vec=admin2.names$Internal)
          natl.tmp.nmr <- weight_admin_draw_matrix(
            admin2.unstrat.nmr.BB8.draw, adm2.pop.nmr
          )
          BB8.adm2.unstrat.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
        }
        
        if(exists('admin2.unstrat.u5.BB8')){
          adm2.pop.u5 <- weight.adm2.u5[weight.adm2.u5$years==year,]
          admin2.unstrat.u5.BB8.draw<-draw_1y_adm(admin_draws=res.unstrat.admin2.u5$draws.est.overall,
                                                year_num=year,
                                                admin_vec=admin2.names$Internal)
          natl.tmp.u5 <- weight_admin_draw_matrix(
            admin2.unstrat.u5.BB8.draw, adm2.pop.u5
          )
          BB8.adm2.unstrat.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
        }
        
      }
      
      BB8.adm2.unstrat.to.natl.frame<-as.data.frame(BB8.adm2.unstrat.to.natl.frame)
      colnames(BB8.adm2.unstrat.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
      BB8.adm2.unstrat.to.natl.frame$method <- "aggre.adm2.unstrat.BB8"
      BB8.adm2.unstrat.to.natl.frame$years = beg.year:end.proj.year
    }
  }
  ### BB8 admin2 unstratified, all surveys
  {
    
    if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_unstrat_nmr_allsurveys.rda')))){
      load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_unstrat_nmr_allsurveys.rda')))
      res.unstrat.admin2.nmr.allsurveys <- bb.res.adm2.unstrat.nmr.allsurveys
      admin2.unstrat.nmr.allsurveys.BB8<-res.unstrat.admin2.nmr.allsurveys$overall}
    if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_unstrat_u5_allsurveys.rda')))){
      load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_unstrat_u5_allsurveys.rda')))
      res.unstrat.admin2.u5.allsurveys <- bb.res.adm2.unstrat.u5.allsurveys
      admin2.unstrat.u5.allsurveys.BB8<-res.unstrat.admin2.u5.allsurveys$overall} 
    
    if(exists('admin2.unstrat.nmr.allsurveys.BB8') | exists('admin2.unstrat.u5.allsurveys.BB8')){
      
      BB8.adm2.unstrat.allsurveys.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
      for (i in 1: n_years){
        year = (beg.year:end.proj.year)[i]
        
        if(exists('admin2.unstrat.nmr.allsurveys.BB8')){
          adm2.pop.nmr <- weight.adm2.u1[weight.adm2.u1$years==year,]
          admin2.unstrat.nmr.allsurveys.BB8.draw<-draw_1y_adm(admin_draws=res.unstrat.admin2.nmr.allsurveys$draws.est.overall,
                                                   year_num=year,
                                                   admin_vec=admin2.names$Internal)
          natl.tmp.nmr <- weight_admin_draw_matrix(
            admin2.unstrat.nmr.allsurveys.BB8.draw, adm2.pop.nmr
          )
          BB8.adm2.unstrat.allsurveys.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
        }
        
        if(exists('admin2.unstrat.u5.allsurveys.BB8')){
          adm2.pop.u5 <- weight.adm2.u5[weight.adm2.u5$years==year,]
          admin2.unstrat.u5.allsurveys.BB8.draw<-draw_1y_adm(admin_draws=res.unstrat.admin2.u5.allsurveys$draws.est.overall,
                                                  year_num=year,
                                                  admin_vec=admin2.names$Internal)
          natl.tmp.u5 <- weight_admin_draw_matrix(
            admin2.unstrat.u5.allsurveys.BB8.draw, adm2.pop.u5
          )
          BB8.adm2.unstrat.allsurveys.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
        }
        
      }
      
      BB8.adm2.unstrat.allsurveys.to.natl.frame<-as.data.frame(BB8.adm2.unstrat.allsurveys.to.natl.frame)
      colnames(BB8.adm2.unstrat.allsurveys.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
      BB8.adm2.unstrat.allsurveys.to.natl.frame$method <- "aggre.adm2.unstrat.allsurveys.BB8"
      BB8.adm2.unstrat.allsurveys.to.natl.frame$years = beg.year:end.proj.year
    }
  }
  ### BB8 admin2 unstratified, all surveys, benchmarked
  {
    
    if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_unstrat_nmr_allsurveys_bench.rda')))){
      load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_unstrat_nmr_allsurveys_bench.rda')))
      res.unstrat.admin2.nmr.allsurveys.bench <- bb.res.adm2.unstrat.nmr.allsurveys.bench
      admin2.unstrat.nmr.allsurveys.BB8.bench<-res.unstrat.admin2.nmr.allsurveys.bench$overall}
    if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_unstrat_u5_allsurveys_bench.rda')))){
      adm2.unstrat.u5.allsurveys.bench.file <- select_comparison_u5_result_file(
        file.path(
          res.dir, "Betabinomial", "U5MR",
          paste0(country, '_res_adm2_unstrat_u5_allsurveys_bench.rda')
        ),
        candidate_strata_model = "unstrat",
        candidate_survey_frame = "all_surveys",
        final_strata_model = strata.model
      )
      load(file = adm2.unstrat.u5.allsurveys.bench.file)
      res.unstrat.admin2.u5.allsurveys.bench <- bb.res.adm2.unstrat.u5.allsurveys.bench
      admin2.unstrat.u5.allsurveys.BB8.bench<-res.unstrat.admin2.u5.allsurveys.bench$overall} 
    
    if(exists('admin2.unstrat.nmr.allsurveys.BB8.bench') | exists('admin2.unstrat.u5.allsurveys.BB8.bench')){
      
      BB8.adm2.unstrat.allsurveys.bench.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
      for (i in 1:n_years){
        year = (beg.year:end.proj.year)[i]
        
        if(exists('admin2.unstrat.nmr.allsurveys.BB8.bench')){
          adm2.pop.nmr <- weight.adm2.u1[weight.adm2.u1$years==year,]
          admin2.unstrat.nmr.allsurveys.BB8.bench.draw<-draw_1y_adm(admin_draws=res.unstrat.admin2.nmr.allsurveys.bench$draws.est.overall,
                                                                    year_num=year,
                                                                    admin_vec=admin2.names$Internal,
                                                                    nsim=length(res.unstrat.admin2.nmr.allsurveys.bench$draws.est.overall[[1]]$draws))
          natl.tmp.nmr <- weight_admin_draw_matrix(
            admin2.unstrat.nmr.allsurveys.BB8.bench.draw, adm2.pop.nmr
          )
          BB8.adm2.unstrat.allsurveys.bench.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
        }
        
        if(exists('admin2.unstrat.u5.allsurveys.BB8.bench')){
          adm2.pop.u5 <- weight.adm2.u5[weight.adm2.u5$years==year,]
          admin2.unstrat.u5.allsurveys.BB8.bench.draw<-draw_1y_adm(admin_draws=res.unstrat.admin2.u5.allsurveys.bench$draws.est.overall,
                                                                   year_num=year,
                                                                   admin_vec=admin2.names$Internal)
          natl.tmp.u5 <- weight_admin_draw_matrix(
            admin2.unstrat.u5.allsurveys.BB8.bench.draw, adm2.pop.u5
          )
          BB8.adm2.unstrat.allsurveys.bench.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
        }
        
      }
      
      BB8.adm2.unstrat.allsurveys.bench.to.natl.frame<-as.data.frame(BB8.adm2.unstrat.allsurveys.bench.to.natl.frame)
      colnames(BB8.adm2.unstrat.allsurveys.bench.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
      BB8.adm2.unstrat.allsurveys.bench.to.natl.frame$method <- "aggre.adm2.unstrat.allsurveys.BB8.bench"
      BB8.adm2.unstrat.allsurveys.bench.to.natl.frame$years = beg.year:end.proj.year
    }
  }
  ### BB8 admin2 stratified
  {
    
    if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_strat_nmr.rda')))){
      load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_strat_nmr.rda')))
      res.strat.admin2.nmr <- bb.res.adm2.strat.nmr
      admin2.strat.nmr.BB8<-res.strat.admin2.nmr$overall}
    if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_strat_u5.rda')))){
      load(file = file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_strat_u5.rda')))
      res.strat.admin2.u5 <- bb.res.adm2.strat.u5
      admin2.strat.u5.BB8<-res.strat.admin2.u5$overall} 
    
    if(exists('admin2.strat.nmr.BB8') | exists('admin2.strat.u5.BB8')){
      
      BB8.adm2.strat.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
      for (i in 1: n_years){
        year = (beg.year:end.proj.year)[i]
        
        if(exists('admin2.strat.nmr.BB8')){
          adm2.pop.nmr <- weight.adm2.u1[weight.adm2.u1$years==year,]
          admin2.strat.nmr.BB8.draw<-draw_1y_adm(admin_draws=res.strat.admin2.nmr$draws.est.overall,
                                                 year_num=year,
                                                 admin_vec=admin2.names$Internal)
          natl.tmp.nmr <- weight_admin_draw_matrix(
            admin2.strat.nmr.BB8.draw, adm2.pop.nmr
          )
          BB8.adm2.strat.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
        }
        
        if(exists('admin2.strat.u5.BB8')){
          adm2.pop.u5 <- weight.adm2.u5[weight.adm2.u5$years==year,]
          admin2.strat.u5.BB8.draw<-draw_1y_adm(admin_draws=res.strat.admin2.u5$draws.est.overall,
                                                year_num=year,
                                                admin_vec=admin2.names$Internal)
          natl.tmp.u5 <- weight_admin_draw_matrix(
            admin2.strat.u5.BB8.draw, adm2.pop.u5
          )
          BB8.adm2.strat.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
        }
        
      }
      
      BB8.adm2.strat.to.natl.frame<-as.data.frame(BB8.adm2.strat.to.natl.frame)
      colnames(BB8.adm2.strat.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
      BB8.adm2.strat.to.natl.frame$method <- "aggre.adm2.strat.BB8"
      BB8.adm2.strat.to.natl.frame$years = beg.year:end.proj.year
    }
  }
  ### BB8 admin2 stratified, benchmarked
  {
    
    if(file.exists(file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_strat_nmr_bench.rda')))){
      load(file = file.path("Betabinomial", "NMR", paste0(country, '_res_adm2_strat_nmr_bench.rda')))
      res.strat.admin2.nmr.bench <- bb.res.adm2.strat.nmr.bench
      admin2.strat.nmr.BB8.bench<-res.strat.admin2.nmr.bench$overall}
    if(file.exists(file.path("Betabinomial", "U5MR", paste0(country, '_res_adm2_strat_u5_bench.rda')))){
      adm2.strat.u5.bench.file <- select_comparison_u5_result_file(
        file.path(
          res.dir, "Betabinomial", "U5MR",
          paste0(country, '_res_adm2_strat_u5_bench.rda')
        ),
        candidate_strata_model = "strat",
        candidate_survey_frame = "same_frame",
        final_strata_model = strata.model
      )
      load(file = adm2.strat.u5.bench.file)
      res.strat.admin2.u5.bench <- bb.res.adm2.strat.u5.bench
      admin2.strat.u5.BB8.bench<-res.strat.admin2.u5.bench$overall} 
    
    if(exists('admin2.strat.nmr.BB8.bench') | exists('admin2.strat.u5.BB8.bench')){
      
      BB8.adm2.strat.bench.to.natl.frame <- matrix(NA, nrow = n_years, ncol =  6)
      for (i in 1:n_years){
        year = (beg.year:end.proj.year)[i]
        
        if(exists('admin2.strat.nmr.BB8.bench')){
          adm2.pop.nmr <- weight.adm2.u1[weight.adm2.u1$years==year,]
          admin2.strat.nmr.BB8.bench.draw<-draw_1y_adm(admin_draws=res.strat.admin2.nmr.bench$draws.est.overall,
                                                       year_num=year,
                                                       admin_vec=admin2.names$Internal,
                                                       nsim=length(res.strat.admin2.nmr.bench$draws.est.overall[[1]]$draws))
          natl.tmp.nmr <- weight_admin_draw_matrix(
            admin2.strat.nmr.BB8.bench.draw, adm2.pop.nmr
          )
          BB8.adm2.strat.bench.to.natl.frame[i, 1:3] = c(quantile(natl.tmp.nmr, probs = c(0.025, 0.5, 0.975)))
        }
        
        if(exists('admin2.strat.u5.BB8.bench')){
          adm2.pop.u5 <- weight.adm2.u5[weight.adm2.u5$years==year,]
          admin2.strat.u5.BB8.bench.draw<-draw_1y_adm(admin_draws=res.strat.admin2.u5.bench$draws.est.overall,
                                                      year_num=year,
                                                      admin_vec=admin2.names$Internal)
          natl.tmp.u5 <- weight_admin_draw_matrix(
            admin2.strat.u5.BB8.bench.draw, adm2.pop.u5
          )
          BB8.adm2.strat.bench.to.natl.frame[i, 4:6] = c(quantile(natl.tmp.u5, probs = c(0.025, 0.5, 0.975)))
        }
        
      }
      
      BB8.adm2.strat.bench.to.natl.frame<-as.data.frame(BB8.adm2.strat.bench.to.natl.frame)
      colnames(BB8.adm2.strat.bench.to.natl.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
      BB8.adm2.strat.bench.to.natl.frame$method <- "aggre.adm2.strat.BB8.bench"
      BB8.adm2.strat.bench.to.natl.frame$years = beg.year:end.proj.year
    }
  }
}

#### prepare IGME estimates ####
  igme.frame <- as.data.frame(cbind(igme.ests.nmr$LOWER_BOUND,igme.ests.nmr$OBS_VALUE,igme.ests.nmr$UPPER_BOUND,
                                    igme.ests.u5$LOWER_BOUND,igme.ests.u5$OBS_VALUE,igme.ests.u5$UPPER_BOUND))
  colnames(igme.frame) = c("lower_nmr", "median_nmr", "upper_nmr","lower_u5", "median_u5", "upper_u5")
  igme.frame$method <- "igme"
  igme.frame$years <- beg.year:max(igme.ests.nmr$year)
  
#### final plot ####
  
  methods <- c("natl.sd.frame","sd.adm1.to.natl.frame","sd.adm1.yl.to.natl.frame","sd.adm2.to.natl.frame","sd.adm2.yl.to.natl.frame",
               'natl.bb.unstrat.frame','natl.bb.strat.frame','natl.bb.unstrat.allsurveys.frame',
               "BB8.adm1.unstrat.to.natl.frame","BB8.adm1.strat.to.natl.frame",'BB8.adm1.unstrat.allsurveys.to.natl.frame',
               "BB8.adm1.strat.bench.to.natl.frame",'BB8.adm1.unstrat.allsurveys.bench.to.natl.frame',
               "BB8.adm2.unstrat.to.natl.frame","BB8.adm2.strat.to.natl.frame",'BB8.adm2.unstrat.allsurveys.to.natl.frame',
               "BB8.adm2.strat.bench.to.natl.frame",'BB8.adm2.unstrat.allsurveys.bench.to.natl.frame',
               "igme.frame")[c(1:5,7:8,10:13,15:19)]
  methods.include <- which(vapply(
    methods, exists, logical(1),
    envir = environment(), inherits = FALSE
  ))
  
  natl.all <- data.frame()
  for(i in methods.include){
    if(nrow(natl.all)==0){
      natl.all <- eval(str2lang(methods[i]))
      natl.all$years <- as.numeric(paste(natl.all$years))
    }else{
      natl.all <- rbind(natl.all,eval(str2lang(methods[i])))
    }
  }
  
  natl.all$years <- as.numeric(natl.all$years)
  cols <- RColorBrewer::brewer.pal(n = 12, name = "Paired")
  
  #fix y axis
  y_limits_nmr <- c(min(natl.all$median_nmr,na.rm = T)*1000-1,max(natl.all$median_nmr,na.rm = T)*1000+1)
  y_limits_u5 <- c(min(natl.all$median_u5,na.rm = T)*1000-1,max(natl.all$median_u5,na.rm = T)*1000+1)
  
  ## Compare smoothed direct estimates ---------------
  
  # USE THIS ARGUMENT TO PICK METHODS TO PLOT -- may have to change this line
  
  methods.use <- c("natl.sd.yearly","aggre.sd.adm1","aggre.sd.yearly.adm1","aggre.sd.adm2","aggre.sd.yearly.adm2","igme")[c(1:6)]
  methods.use[!methods.use %in% unique(natl.all$method)]
  methods.use <- methods.use[methods.use %in% unique(natl.all$method)]
  
  ##IF you have made a comparison plot before that you don't want to overwrite, make sure to change the name of the PDF!
  pdf(file.path(res.dir, "Figures", "Summary", "NMR", paste0(country, "_comparison_nmr_sd_",time.model, ".pdf")),height = 6,width = 6)
  {
  
  plot(NA, xlim=c(min(plot.years),max(plot.years)), ylim=y_limits_nmr,
       xlab='Year', ylab='Median NMR deaths per 1000 live births',
       las=2, xaxp=c(min(plot.years),max(plot.years),n_years-1))
  
  #plot methods
  for(method in methods.use){
    tmp<- natl.all[natl.all$method==method,]
    if(method %in% c("aggre.sd.adm1","aggre.sd.adm2","natl.sd")){
      lines(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],lwd=1.5)
      points(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
    }else{
    lines(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],lwd=1.5)
    points(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
    }
  }
  
  #plot credible intervals for IGME and natl.smoothed.yearly
  polygon(x=c(plot.years, rev(plot.years)),
            y=c(natl.all[natl.all$method=="igme",]$lower_nmr*1000, rev(natl.all[natl.all$method=="igme",]$upper_nmr*1000)),
            col=alpha(cols[methods.use=="igme"],0.25), border=F)
  polygon(x=c(plot.years, rev(plot.years)),
          y=c(natl.all[natl.all$method=="natl.sd.yearly",]$lower_nmr*1000, rev(natl.all[natl.all$method=="natl.sd.yearly",]$upper_nmr*1000)),
          col=alpha(cols[methods.use=="natl.sd.yearly"],0.25), border=F)
  
  #add grid
  suppressWarnings(grid())
  #add legend
  legend('topright', bty = 'n',
         pch = c(rep(20, length(methods.use))),
         lty = c(rep(1, length(methods.use))),
         col = cols[1:length(methods.use)],
         legend = methods.use)
  }
  dev.off()
  
#### interactive HTML report export -----------------------------------------------

comparison.interactive.dir <- res.dir
dir.create(comparison.interactive.dir, recursive = TRUE, showWarnings = FALSE)

build_bb8_inventory <- function(country, has_adm2 = FALSE,
                                final_strata_model = "unstrat") {
  model_specs <- data.frame(
    outcome_dir = c(
      rep("NMR", 13),
      rep("U5MR", 13)
    ),
    outcome = c(
      rep("NMR", 13),
      rep("U5MR", 13)
    ),
    model_object = c(
      "bb.res.natl.unstrat.nmr",
      "bb.res.natl.strat.nmr",
      "bb.res.adm1.unstrat.nmr",
      "bb.res.adm1.strat.nmr",
      "bb.res.adm2.unstrat.nmr",
      "bb.res.adm2.strat.nmr",
      "bb.res.adm1.strat.nmr.bench",
      "bb.res.adm2.strat.nmr.bench",
      "bb.res.natl.unstrat.nmr.allsurveys",
      "bb.res.adm1.unstrat.nmr.allsurveys",
      "bb.res.adm2.unstrat.nmr.allsurveys",
      "bb.res.adm1.unstrat.nmr.allsurveys.bench",
      "bb.res.adm2.unstrat.nmr.allsurveys.bench",
      "bb.res.natl.unstrat.u5",
      "bb.res.natl.strat.u5",
      "bb.res.adm1.unstrat.u5",
      "bb.res.adm1.strat.u5",
      "bb.res.adm2.unstrat.u5",
      "bb.res.adm2.strat.u5",
      "bb.res.adm1.strat.u5.bench",
      "bb.res.adm2.strat.u5.bench",
      "bb.res.natl.unstrat.u5.allsurveys",
      "bb.res.adm1.unstrat.u5.allsurveys",
      "bb.res.adm2.unstrat.u5.allsurveys",
      "bb.res.adm1.unstrat.u5.allsurveys.bench",
      "bb.res.adm2.unstrat.u5.allsurveys.bench"
    ),
    file_stub = c(
      "_res_natl_unstrat_nmr.rda",
      "_res_natl_strat_nmr.rda",
      "_res_adm1_unstrat_nmr.rda",
      "_res_adm1_strat_nmr.rda",
      "_res_adm2_unstrat_nmr.rda",
      "_res_adm2_strat_nmr.rda",
      "_res_adm1_strat_nmr_bench.rda",
      "_res_adm2_strat_nmr_bench.rda",
      "_res_natl_unstrat_nmr_allsurveys.rda",
      "_res_adm1_unstrat_nmr_allsurveys.rda",
      "_res_adm2_unstrat_nmr_allsurveys.rda",
      "_res_adm1_unstrat_nmr_allsurveys_bench.rda",
      "_res_adm2_unstrat_nmr_allsurveys_bench.rda",
      "_res_natl_unstrat_u5.rda",
      "_res_natl_strat_u5.rda",
      "_res_adm1_unstrat_u5.rda",
      "_res_adm1_strat_u5.rda",
      "_res_adm2_unstrat_u5.rda",
      "_res_adm2_strat_u5.rda",
      "_res_adm1_strat_u5_bench.rda",
      "_res_adm2_strat_u5_bench.rda",
      "_res_natl_unstrat_u5_allsurveys.rda",
      "_res_adm1_unstrat_u5_allsurveys.rda",
      "_res_adm2_unstrat_u5_allsurveys.rda",
      "_res_adm1_unstrat_u5_allsurveys_bench.rda",
      "_res_adm2_unstrat_u5_allsurveys_bench.rda"
    ),
    admin_level = c(
      "National", "National", "Admin1", "Admin1", "Admin2", "Admin2",
      "Admin1", "Admin2", "National", "Admin1", "Admin2", "Admin1",
      "Admin2",
      "National", "National", "Admin1", "Admin1", "Admin2", "Admin2",
      "Admin1", "Admin2", "National", "Admin1", "Admin2", "Admin1",
      "Admin2"
    ),
    stratification = c(
      "Unstratified", "Stratified", "Unstratified", "Stratified",
      "Unstratified", "Stratified", "Stratified", "Stratified",
      "Unstratified", "Unstratified", "Unstratified", "Unstratified",
      "Unstratified",
      "Unstratified", "Stratified", "Unstratified", "Stratified",
      "Unstratified", "Stratified", "Stratified", "Stratified",
      "Unstratified", "Unstratified", "Unstratified", "Unstratified",
      "Unstratified"
    ),
    survey_frame = c(
      rep("Same frame", 8), rep("All surveys", 5),
      rep("Same frame", 8), rep("All surveys", 5)
    ),
    benchmarked = c(
      rep(FALSE, 6), TRUE, TRUE, rep(FALSE, 3), TRUE, TRUE,
      rep(FALSE, 6), TRUE, TRUE, rep(FALSE, 3), TRUE, TRUE
    ),
    stringsAsFactors = FALSE
  )
  model_specs$file_name <- paste0(country, model_specs$file_stub)
  model_specs$file_path <- file.path("Betabinomial", model_specs$outcome_dir, model_specs$file_name)
  model_specs$exists <- base::file.exists(file.path(res.dir, model_specs$file_path))
  model_specs$expected <- has_adm2 | model_specs$admin_level != "Admin2"
  model_specs$final_candidate <- with(
    model_specs,
    benchmarked & admin_level != "National" &
      ((survey_frame == "Same frame" & stratification == "Stratified") |
         (survey_frame == "All surveys" & stratification == "Unstratified"))
  )
  model_specs$selected_for_report <- with(
    model_specs,
    final_candidate &
      ((final_strata_model == "strat" & stratification == "Stratified") |
         (final_strata_model == "unstrat" & stratification == "Unstratified"))
  )
  model_specs$crisis_adjusted <- FALSE
  crisis_rows <- which(
    model_specs$outcome == "U5MR" & model_specs$selected_for_report &
      model_specs$exists & crisis_adjustment_enabled()
  )
  for (row in crisis_rows) {
    selected_path <- select_crisis_result_file(file.path(
      res.dir, model_specs$file_path[[row]]
    ))
    model_specs$file_name[[row]] <- basename(selected_path)
    model_specs$file_path[[row]] <- file.path(
      "Betabinomial", model_specs$outcome_dir[[row]], basename(selected_path)
    )
    model_specs$crisis_adjusted[[row]] <- TRUE
  }
  model_specs$status <- ifelse(
    model_specs$exists,
    "available",
    ifelse(model_specs$expected, "missing", "not expected: no Admin2")
  )
  model_specs
}

if (!exists("natl.all")) {
  stop("Could not create the interactive report because natl.all was not built.")
}

model.inventory <- build_bb8_inventory(
  country,
  has_adm2 = run_admin2_outputs,
  final_strata_model = strata.model
)
dashboard.title <- paste("BB8 Model Comparison for", country)
comparison.rds <- file.path(
  comparison.interactive.dir,
  paste0(country, "_bb8_comparison_data.rds")
)
comparison.html <- file.path(
  comparison.interactive.dir,
  paste0(country, "_bb8_comparison_dashboard.html")
)

comparison.bundle <- list(
  country = country,
  generated_at = Sys.time(),
  dashboard_title = dashboard.title,
  source_script = file.path("Rcode", "9_Comparison_Plot.R"),
  source_qmd = file.path("Rcode", "9_Comparison_Plot.qmd"),
  home_dir = home.dir,
  data_dir = data.dir,
  res_dir = res.dir,
  plot_years = plot.years,
  pane_years = pane.years,
  beg_year = beg.year,
  end_proj_year = end.proj.year,
  has_admin2 = run_admin2_outputs,
  crisis_adjustment = crisis_adjustment_enabled(),
  natl_all = natl.all,
  methods_available = sort(unique(natl.all$method)),
  model_inventory = model.inventory
)

saveRDS(comparison.bundle, comparison.rds)
message("Saved interactive comparison data: ", comparison.rds)

qmd.path <- file.path(home.dir, "Rcode", "9_Comparison_Plot.qmd")
if (file.exists(qmd.path)) {
  quarto.path <- if (exists("find_pipeline_quarto", mode = "function")) {
    find_pipeline_quarto()
  } else {
    Sys.which("quarto")
  }
  Sys.setenv(BB8_COMPARISON_RDS = normalizePath(comparison.rds, winslash = "/", mustWork = TRUE))
  Sys.setenv(BB8_COMPARISON_HTML = normalizePath(comparison.html, winslash = "/", mustWork = FALSE))
  local({
    old.wd <- getwd()
    on.exit(setwd(old.wd), add = TRUE)
    setwd(dirname(qmd.path))
    qmd.input <- basename(qmd.path)
    if (requireNamespace("quarto", quietly = TRUE)) {
      old.quarto.path <- Sys.getenv("QUARTO_PATH", unset = NA_character_)
      on.exit({
        if (is.na(old.quarto.path)) Sys.unsetenv("QUARTO_PATH") else
          Sys.setenv(QUARTO_PATH = old.quarto.path)
      }, add = TRUE)
      if (nzchar(quarto.path)) Sys.setenv(QUARTO_PATH = quarto.path)
      quarto::quarto_render(
        input = qmd.input,
        output_file = basename(comparison.html),
        execute_params = list(comparison_rds = comparison.rds),
        quarto_args = c(
          "--output-dir",
          normalizePath(dirname(comparison.html), winslash = "/", mustWork = FALSE)
        )
      )
    } else if (nzchar(quarto.path)) {
      system2(
        quarto.path,
        args = c(
          "render",
          shQuote(qmd.input),
          "--output",
          shQuote(basename(comparison.html)),
          "--output-dir",
          shQuote(normalizePath(dirname(comparison.html), winslash = "/", mustWork = FALSE))
        )
      )
    } else {
      message("Quarto was not found. Render manually after installing Quarto: ", qmd.path)
    }
  })
  if (file.exists(comparison.html)) {
    html.raw <- readBin(
      comparison.html,
      what = "raw",
      n = file.info(comparison.html)$size
    )
    from.raw <- charToRaw("BB8 Model Comparison Dashboard")
    to.raw <- charToRaw(dashboard.title)
    match.pos <- grepRaw(from.raw, html.raw, fixed = TRUE, all = TRUE)
    if (length(match.pos) > 0) {
      chunks <- vector("list", length(match.pos) * 2 + 1)
      cursor <- 1L
      chunk.idx <- 1L
      from.len <- length(from.raw)
      for (pos in match.pos) {
        chunks[[chunk.idx]] <- if (pos > cursor) html.raw[cursor:(pos - 1L)] else raw()
        chunk.idx <- chunk.idx + 1L
        chunks[[chunk.idx]] <- to.raw
        chunk.idx <- chunk.idx + 1L
        cursor <- pos + from.len
      }
      chunks[[chunk.idx]] <- if (cursor <= length(html.raw)) html.raw[cursor:length(html.raw)] else raw()
      html.raw <- do.call(c, chunks)
      writeBin(html.raw, comparison.html)
    }
    message("Saved interactive HTML dashboard: ", comparison.html)
  }
} else {
  message("QMD report not found yet: ", qmd.path)
}

  ##IF you have made a comparison plot before that you don't want to overwrite, make sure to change the name of the PDF!
  pdf(file.path(res.dir, "Figures", "Summary", "U5MR", paste0(country, "_comparison_u5_sd_",time.model, ".pdf")),height = 6,width = 6)
    {
      
      plot(NA, xlim=c(min(plot.years),max(plot.years)), ylim=y_limits_u5,
           xlab='Year', ylab='Median U5MR deaths per 1000 live births',
           las=2, xaxp=c(min(plot.years),max(plot.years),n_years-1))
      
      #plot methods
      for(method in methods.use){
        tmp<- natl.all[natl.all$method==method,]
        if(method %in% c("aggre.sd.adm1","aggre.sd.adm2","natl.sd")){
          lines(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],lwd=1.5)
          points(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
        }else{
          lines(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],lwd=1.5)
          points(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
        }
      }
      
      #plot credible intervals for IGME and natl.smoothed.yearly
      polygon(x=c(plot.years, rev(plot.years)),
              y=c(natl.all[natl.all$method=="igme",]$lower_u5*1000, rev(natl.all[natl.all$method=="igme",]$upper_u5*1000)),
              col=alpha(cols[methods.use=="igme"],0.25), border=F)
      polygon(x=c(plot.years, rev(plot.years)),
              y=c(natl.all[natl.all$method=="natl.sd.yearly",]$lower_u5*1000, rev(natl.all[natl.all$method=="natl.sd.yearly",]$upper_u5*1000)),
              col=alpha(cols[methods.use=="natl.sd.yearly"],0.25), border=F)
      
      #add grid
      suppressWarnings(grid())
      #add legend
      legend('topright', bty = 'n',
             pch = c(rep(20, length(methods.use))),
             lty = c(rep(1, length(methods.use))),
             col = cols[1:length(methods.use)],
             legend = methods.use)
    }
  dev.off()
  
  ## Compare betabinomial estimates ---------------
 
  unique(natl.all$method)
  # USE THIS ARGUMENT TO PICK METHODS TO PLOT -- may have to change this line
  methods.use <- c("natl.sd.yearly","natl.bb.unstrat","natl.bb.strat","natl.bb.unstrat.allsurveys",
                   "aggre.adm1.unstrat.BB8","aggre.adm1.strat.BB8","aggre.adm1.unstrat.allsurveys.BB8",
                   "aggre.adm2.unstrat.BB8","aggre.adm2.strat.BB8", "aggre.adm2.unstrat.allsurveys.BB8",
                   "igme")[c(1,3,4,6,7,9:11)]
  
  # methods.use <- c("natl.sd.yearly", "natl.bb.strat", 
  #                  "natl.bb.unstrat.allsurveys" , "aggre.adm1.strat.BB8",
  #                  "aggre.adm1.unstrat.allsurveys.BB8" ,"igme")
  methods.use[!methods.use %in% unique(natl.all$method)]
  
  methods.use <- methods.use[methods.use %in% unique(natl.all$method)]
  
  ##IF you have made a comparison plot before that you don't want to overwrite, make sure to change the name of the  PDF!
  pdf(file.path(res.dir, "Figures", "Summary", "NMR", paste0(country, "_comparison_nmr_bb8.pdf")),height = 6,width = 6)
  {
    
    plot(NA, xlim=c(min(plot.years),max(plot.years)), ylim=y_limits_nmr,
         xlab='Year', ylab='Median NMR deaths per 1000 live births',
         las=2, xaxp=c(min(plot.years),max(plot.years),n_years-1))
    
    #plot methods
    for(method in methods.use){
      tmp<- natl.all[natl.all$method==method,]
      if(method %in% c("aggre.sd.adm1","aggre.sd.adm2","natl.sd")){
        lines(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],lwd=1.5)
        points(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
      }else{
        lines(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],lwd=1.5)
        points(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
      }
    }
    
    #plot credible intervals for IGME and natl.smoothed.yearly
    polygon(x=c(plot.years, rev(plot.years)),
            y=c(natl.all[natl.all$method=="igme",]$lower_nmr*1000, rev(natl.all[natl.all$method=="igme",]$upper_nmr*1000)),
            col=alpha(cols[methods.use=="igme"],0.25), border=F)
    polygon(x=c(plot.years, rev(plot.years)),
            y=c(natl.all[natl.all$method=="natl.sd.yearly",]$lower_nmr*1000, rev(natl.all[natl.all$method=="natl.sd.yearly",]$upper_nmr*1000)),
            col=alpha(cols[methods.use=="natl.sd.yearly"],0.25), border=F)
    
    #add grid
    suppressWarnings(grid())
    #add legend
    legend('topright', bty = 'n',
           pch = c(rep(20, length(methods.use))),
           lty = c(rep(1, length(methods.use))),
           col = cols[1:length(methods.use)],
           legend = methods.use)
  }
  dev.off()
  
  ##IF you have made a comparison plot before that you don't want to overwrite, make sure to change the name of the PDF!
  pdf(file.path(res.dir, "Figures", "Summary", "U5MR", paste0(country, "_comparison_u5_bb8.pdf")),height = 6,width = 6)
  { 
    {
      
      plot(NA, xlim=c(min(plot.years),max(plot.years)), ylim=y_limits_u5,
           xlab='Year', ylab='Median U5MR deaths per 1000 live births',
           las=2, xaxp=c(min(plot.years),max(plot.years),n_years-1))
      
      #plot methods
      for(method in methods.use){
        tmp<- natl.all[natl.all$method==method,]
        if(method %in% c("aggre.sd.adm1","aggre.sd.adm2","natl.sd")){
          lines(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],lwd=1.5)
          points(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
        }else{
          lines(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],lwd=1.5)
          points(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
        }
      }
      
      #plot credible intervals for IGME and natl.smoothed.yearly
      polygon(x=c(plot.years, rev(plot.years)),
              y=c(natl.all[natl.all$method=="igme",]$lower_u5*1000, rev(natl.all[natl.all$method=="igme",]$upper_u5*1000)),
              col=alpha(cols[methods.use=="igme"],0.25), border=F)
      polygon(x=c(plot.years, rev(plot.years)),
              y=c(natl.all[natl.all$method=="natl.sd.yearly",]$lower_u5*1000, rev(natl.all[natl.all$method=="natl.sd.yearly",]$upper_u5*1000)),
              col=alpha(cols[methods.use=="natl.sd.yearly"],0.25), border=F)
      
      #add grid
      suppressWarnings(grid())
      #add legend
      legend('topright', bty = 'n',
             pch = c(rep(20, length(methods.use))),
             lty = c(rep(1, length(methods.use))),
             col = cols[1:length(methods.use)],
             legend = methods.use)
    }
  }
  dev.off()
  
  
  
  ## Compare benchmarked v unbenchmarked estimates ---------------
  
  # USE THIS ARGUMENT TO PICK METHODS TO PLOT -- may have to change this line
  methods.use <- c("natl.sd.yearly", "igme",
                   "natl.bb.strat","aggre.adm1.strat.BB8","aggre.adm2.strat.BB8",
                   "aggre.adm1.strat.BB8.bench","aggre.adm2.strat.BB8.bench",
                   "natl.bb.unstrat.allsurveys", "aggre.adm1.unstrat.allsurveys.BB8", "aggre.adm2.unstrat.allsurveys.BB8",
                   "aggre.adm1.unstrat.allsurveys.BB8.bench", "aggre.adm2.unstrat.allsurveys.BB8.bench")[c(1:7)]
  methods.use[!methods.use %in% unique(natl.all$method)]
  methods.use <- methods.use[methods.use %in% unique(natl.all$method)]
  
  ##IF you have made a comparison plot before that you don't want to overwrite, make sure to change the name of the  PDF!
  pdf(file.path(res.dir, "Figures", "Summary", "NMR", paste0(country, "_comparison_nmr_bb8_bench.pdf")),height = 6,width = 6)
  {
    
    plot(NA, xlim=c(min(plot.years),max(plot.years)), ylim=y_limits_nmr,
         xlab='Year', ylab='Median NMR deaths per 1000 live births',
         las=2, xaxp=c(min(plot.years),max(plot.years),n_years-1))
    
    #plot methods
    for(method in methods.use){
      tmp<- natl.all[natl.all$method==method,]
        lines(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],lwd=1.5)
        points(tmp$years,tmp$median_nmr*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
    }
    
    #plot credible intervals for IGME and natl.smoothed.yearly
    polygon(x=c(plot.years, rev(plot.years)),
            y=c(natl.all[natl.all$method=="igme",]$lower_nmr*1000, rev(natl.all[natl.all$method=="igme",]$upper_nmr*1000)),
            col=alpha(cols[methods.use=="igme"],0.25), border=F)
    polygon(x=c(plot.years, rev(plot.years)),
            y=c(natl.all[natl.all$method=="natl.sd.yearly",]$lower_nmr*1000, rev(natl.all[natl.all$method=="natl.sd.yearly",]$upper_nmr*1000)),
            col=alpha(cols[methods.use=="natl.sd.yearly"],0.25), border=F)
    
    #add grid
    suppressWarnings(grid())
    #add legend
    legend('topright', bty = 'n',
           pch = c(rep(20, length(methods.use))),
           lty = c(rep(1, length(methods.use))),
           col = cols[1:length(methods.use)],
           legend = methods.use)
  }
  dev.off()
  
  ##IF you have made a comparison plot before that you don't want to overwrite, make sure to change the name of the PDF!
  pdf(file.path(res.dir, "Figures", "Summary", "U5MR", paste0(country, "_comparison_u5_bb8_bench.pdf")),height = 6,width = 6)
  { 
    {
      
      plot(NA, xlim=c(min(plot.years),max(plot.years)), ylim=y_limits_u5,
           xlab='Year', ylab='Median U5MR deaths per 1000 live births',
           las=2, xaxp=c(min(plot.years),max(plot.years),n_years-1))
      
      #plot methods
      for(method in methods.use){
        tmp<- natl.all[natl.all$method==method,]
          lines(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],lwd=1.5)
          points(tmp$years,tmp$median_u5*1000,col=cols[which(method==methods.use)],pch=20,cex=1)
      }
      
      #plot credible intervals for IGME and natl.smoothed.yearly
      polygon(x=c(plot.years, rev(plot.years)),
              y=c(natl.all[natl.all$method=="igme",]$lower_u5*1000, rev(natl.all[natl.all$method=="igme",]$upper_u5*1000)),
              col=alpha(cols[methods.use=="igme"],0.25), border=F)
      polygon(x=c(plot.years, rev(plot.years)),
              y=c(natl.all[natl.all$method=="natl.sd.yearly",]$lower_u5*1000, rev(natl.all[natl.all$method=="natl.sd.yearly",]$upper_u5*1000)),
              col=alpha(cols[methods.use=="natl.sd.yearly"],0.25), border=F)
      
      #add grid
      suppressWarnings(grid())
      #add legend
      legend('topright', bty = 'n',
             pch = c(rep(20, length(methods.use))),
             lty = c(rep(1, length(methods.use))),
             col = cols[1:length(methods.use)],
             legend = methods.use)
    }
  }
  dev.off()
  

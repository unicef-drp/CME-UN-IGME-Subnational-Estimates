# https://github.com/alanamcgovern/UN-Subnational-Estimates

# Run Direct_SmoothDirect.R. This script will calculate direct and smoothed
# direct NMR and U5MR estimates and generate figures. make sure Rcode/1_Preperation.R has loaded the country context first
#
# NOTE: It is normal for some of these models to not run due to data sparsity.
# These estimates are just to be used for comparison to the Beta-binomial
# estimates (which will take care of the sparsity issue)

# Country context is loaded by Rcode/1_Preperation.R.


# Setup

# Load libraries and info ----------------------------------------------------------
USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/admin_boundary_merges.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/survey_list_filters.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/hiv_adjustments.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/direct_smoothing_inputs.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}
direct_admin2_only <- identical(Sys.getenv("DIRECT_ADMIN2_ONLY"), "1")


options(un_subnational_auto_plot_messages = FALSE)
options(gsubfn.engine = "R")
library(SUMMER)
library(dplyr)
library(sf)

# extract file location of this script
code.path <- file.path(project_home(), "Rcode/4_Direct_SmoothDirect_sf.R")
code.path.splitted <- strsplit(code.path, "/")[[1]]

# retrieve directories
home.dir <- paste(code.path.splitted[1: (length(code.path.splitted)-2)], collapse = "/")
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
require_country_context()
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}

ensure_output_dir <- function(...) {
  output_dir <- file.path(...)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  }
  invisible(output_dir)
}

get_smoothed_with_retry <- function(label, ..., attempts = 2) {
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    result <- tryCatch(
      SUMMER::getSmoothed(...),
      error = function(e) {
        last_error <<- e
        NULL
      }
    )
    if (!is.null(result)) {
      return(result)
    }
    message(
      "getSmoothed failed for ", label, " (attempt ", attempt, "/", attempts, "): ",
      conditionMessage(last_error)
    )
  }
  stop(last_error)
}

retry_inla_step <- function(label, expr, attempts = 3) {
  expr <- substitute(expr)
  env <- parent.frame()
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    result <- tryCatch(
      eval(expr, env),
      error = function(e) {
        last_error <<- e
        NULL
      }
    )
    if (!is.null(result)) {
      return(result)
    }
    message(
      "INLA step failed for ", label, " (attempt ", attempt, "/", attempts, "): ",
      conditionMessage(last_error)
    )
  }
  stop(last_error)
}

fit_admin_period_smoothed_direct <- function(
    label,
    data,
    Amat,
    year_label,
    year_range,
    time.model,
    save.draws = TRUE) {
  if (adjacency_has_edges(Amat)) {
    return(retry_inla_step(label, {
      fit <- SUMMER::smoothDirect(
        data,
        Amat = Amat,
        year_label = year_label,
        type.st = 4,
        time.model = time.model,
        year_range = year_range,
        is.yearly = FALSE
      )
      result <- get_smoothed_with_retry(
        label,
        fit,
        Amat = Amat,
        year_label = year_label,
        year_range = year_range,
        save.draws = save.draws,
        attempts = 1
      )
      list(fit = fit, result = result)
    }))
  }

  message(
    label,
    " adjacency has no edges; fitting independent temporal smooths by region."
  )
  smooth_direct_independently(
    data = data,
    region_names = colnames(Amat),
    fit_region = function(region_data, region_name) {
      retry_inla_step(paste(label, region_name), {
        fit <- SUMMER::smoothDirect(
          region_data,
          Amat = NULL,
          year_label = year_label,
          time.model = time.model,
          year_range = year_range,
          is.yearly = FALSE
        )
        result <- get_smoothed_with_retry(
          paste(label, region_name),
          fit,
          year_label = year_label,
          year_range = year_range,
          save.draws = save.draws,
          attempts = 1
        )
        list(fit = fit, result = result)
      })
    }
  )
}

normalize_utf8_text <- function(labels) {
  labels <- as.character(labels)
  invalid_utf8 <- !is.na(labels) & !validUTF8(labels)
  labels[invalid_utf8] <- iconv(labels[invalid_utf8], from = "latin1",
                                to = "UTF-8", sub = "byte")
  enc2utf8(labels)
}

draw_admin1_spaghetti_legend <- function(labels, cols, x, y) {
  legend(x = x,
         y = y,
         bty = "n",
         col = cols,
         lwd = 2,
         legend = labels,
         cex = 0.4,
         ncol = 2,
         y.intersp = 0.8,
         xpd = NA)
}

expand_smoothed_periods_to_years <- function(smoothed, period_labels, start_years, end_years, max_year) {
  expanded <- lapply(seq_along(period_labels), function(i) {
    period_data <- smoothed[smoothed$years == period_labels[i], , drop = FALSE]
    if (nrow(period_data) == 0) {
      return(NULL)
    }
    period_end <- min(end_years[i], max_year)
    if (start_years[i] > period_end) {
      return(NULL)
    }
    years <- seq(start_years[i], period_end)
    do.call(rbind, lapply(years, function(year) {
      year_data <- period_data
      year_data$years <- year
      year_data$years.num <- year
      year_data
    }))
  })
  do.call(rbind, expanded[!vapply(expanded, is.null, logical(1))])
}

# Load polygon files  ------------------------------------------------------
use_path_base(data.dir)

if (identical(country, "Madagascar")) {
  sf::sf_use_s2(FALSE)
}

# load the national shape file
poly.adm0 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm0, options = "ENCODING=UTF-8")

# use encoding to read special characters
# load the shape file of admin-1 regions
poly.adm1 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm1, options = "ENCODING=UTF-8")
poly.adm1[[poly.label.adm1]] <- normalize_utf8_text(poly.adm1[[poly.label.adm1]])

if(exists('poly.layer.adm2')){
  # load the shape file of admin-2 regions
  poly.adm2 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm2, options = "ENCODING=UTF-8")
  poly.adm2[[poly.label.adm2]] <- normalize_utf8_text(poly.adm2[[poly.label.adm2]])
} 

if (exists("admin1_name_merges")) {
  admin_boundaries <- apply_admin1_name_merges(
    poly.adm1 = poly.adm1,
    poly.adm2 = if (exists("poly.adm2")) poly.adm2 else NULL,
    poly.label.adm1 = poly.label.adm1,
    admin1_name_merges = admin1_name_merges
  )
  poly.adm1 <- admin_boundaries$poly.adm1
  if (exists("poly.adm2")) {
    poly.adm2 <- admin_boundaries$poly.adm2
  }
}

# Set coordinate reference systems to be equal
if (exists("poly.adm2")) {
  st_crs(poly.adm1) <- st_crs(poly.adm2)
  st_crs(poly.adm0) <- st_crs(poly.adm2)
} else {
  st_crs(poly.adm0) <- st_crs(poly.adm1)
}

load(file.path(poly.path, paste0(country, "_Amat.rda")))
load(file.path(poly.path, paste0(country, "_Amat_Names.rda")))
admin1.names$GeoRepo <- normalize_utf8_text(admin1.names$GeoRepo)
if (exists("admin2.names")) {
  admin2.names$GeoRepo <- normalize_utf8_text(admin2.names$GeoRepo)
}

load(paste0(country,'_cluster_dat.rda'),
     envir = .GlobalEnv)
survey_years <- sort(unique(mod.dat$survey))
print(paste0('The surveys used are: ', paste(survey_years, collapse = ", ")))

# Define periods for 3-year estimates ------------------------------------------------------
#### adjusted slightly when number of years is not divisible by 3

end.year <- max(survey_years)
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

periods <- paste(beg.period.years, end.period.years, sep = "-") # convert the periods into string
print(periods)
# periods looks like:
# "2000-2001" "2002-2003" "2004-2006" "2007-2009" "2010-2012" "2013-2015" "2016-2018"

# Load data and separate each survey  ------------------------------------------------------
svy.idx <- 0
births.list <- list()
births.list.nmr <- list()

mod.dat$years <- as.numeric(as.character(mod.dat$years)) # convert the years from string into numbers
mod.dat$v005 <- mod.dat$v005/1e6

# create subset of data for nmr estimates
mod.dat.nmr <- mod.dat %>% filter(age == '0')
for(survey in survey_years){
    svy.idx <- svy.idx + 1
    # data for u5mr
    births.list[[svy.idx]] <- mod.dat[mod.dat$survey == survey,] %>%
      as.data.frame()
    births.list[[svy.idx]]$died <- births.list[[svy.idx]]$Y
    births.list[[svy.idx]]$total <- as.numeric(births.list[[svy.idx]]$total)
    births.list[[svy.idx]]$period <- as.character(cut(births.list[[svy.idx]]$years, breaks = c(beg.period.years, beg.period.years[length(beg.period.years)]+5),
                                       include.lowest = T, right = F, labels = periods)) # generate period label 
    # data for nmr
    births.list.nmr[[svy.idx]] <- mod.dat.nmr[mod.dat.nmr$survey == survey,] %>%
      as.data.frame()
    births.list.nmr[[svy.idx]]$died <- births.list.nmr[[svy.idx]]$Y
    births.list.nmr[[svy.idx]]$total <- as.numeric(births.list.nmr[[svy.idx]]$total)
    births.list.nmr[[svy.idx]]$period <- as.character(cut(births.list.nmr[[svy.idx]]$years, breaks = c(beg.period.years, beg.period.years[length(beg.period.years)]+5),
                                                      include.lowest = T, right = F, labels = periods)) # generate period label 
  }

names(births.list) <- survey_years
names(births.list.nmr) <- survey_years

admin2_births <- filter_admin2_birth_lists(births.list, births.list.nmr, survey_years)
births.list.admin2 <- admin2_births$births.list
births.list.admin2.nmr <- admin2_births$births.list.nmr
survey_years.admin2 <- admin2_births$survey_years


# Direct Estimates  ------------------------------------------------------

use_path_base(file.path(res.dir, "Direct"))

## National ------------------------------------------------------

#if there is more than one survey
if(length(births.list) != 1){
    # 3-year estimates
     direct.natl.u5 <-  SUMMER::getDirectList(births.list, periods,
                                           regionVar = "admin1.char",
                                           timeVar = "period", 
                                           clusterVar =  "~cluster",
                                          ageVar = "age", Ntrials = "total",
                                           weightsVar = "v005",national.only = T)
     direct.natl.nmr <-  SUMMER::getDirectList(births.list.nmr, periods,
                                              regionVar = "admin1.char",
                                              timeVar = "period", 
                                              clusterVar =  "~cluster",
                                              ageVar = "age", Ntrials = "total",
                                              weightsVar = "v005",national.only = T)
     # yearly estimates
    direct.natl.yearly.u5 <- SUMMER::getDirectList(births.list, beg.year:end.year,
                                                regionVar = "admin1.char",
                                                timeVar = "years", 
                                                clusterVar =  "~cluster",
                                                ageVar = "age", Ntrials = "total",
                                                weightsVar = "v005",national.only = T)
    direct.natl.yearly.nmr <- SUMMER::getDirectList(births.list.nmr, beg.year:end.year,
                                                   regionVar = "admin1.char",
                                                   timeVar = "years", 
                                                   clusterVar =  "~cluster",
                                                   ageVar = "age", Ntrials = "total",
                                                   weightsVar = "v005",national.only = T)
    
    direct.natl.u5$region_num <- direct.natl.u5$region
    direct.natl.yearly.u5$region_num <- direct.natl.yearly.u5$region
    direct.natl.nmr$region_num <- direct.natl.nmr$region
    direct.natl.yearly.nmr$region_num <- direct.natl.yearly.nmr$region
#if there is only one survey
}else{
      # 3-year estimates
     direct.natl.u5 <-  SUMMER::getDirect(as.data.frame(births.list[[1]]), periods,
                                       regionVar = "admin1.char",
                                       timeVar = "period", 
                                       clusterVar =  "~cluster",
                                       ageVar = "age", Ntrials = "total",
                                       weightsVar = "v005",national.only = T)
     direct.natl.nmr <-  SUMMER::getDirect(as.data.frame(births.list.nmr[[1]]), periods,
                                         regionVar = "admin1.char",
                                         timeVar = "period", 
                                         clusterVar =  "~cluster",
                                         ageVar = "age", Ntrials = "total",
                                         weightsVar = "v005",national.only = T)
     # yearly estimates
    direct.natl.yearly.u5 <-  SUMMER::getDirect(as.data.frame(births.list[[1]]), beg.year:end.year,
                                             regionVar = "admin1.char",
                                             timeVar = "years", 
                                             clusterVar =  "~cluster",
                                             ageVar = "age", Ntrials = "total",
                                             weightsVar = "v005",national.only = T)
    direct.natl.yearly.nmr <-  SUMMER::getDirect(as.data.frame(births.list.nmr[[1]]), beg.year:end.year,
                                                regionVar = "admin1.char",
                                                timeVar = "years", 
                                                clusterVar =  "~cluster",
                                                ageVar = "age", Ntrials = "total",
                                                weightsVar = "v005",national.only = T)
    
    direct.natl.u5$survey <- direct.natl.nmr$survey <- direct.natl.yearly.u5$survey <- direct.natl.yearly.nmr$survey <- 1
    direct.natl.u5$surveyYears <- direct.natl.nmr$surveyYears <- direct.natl.yearly.u5$surveyYears <- direct.natl.yearly.nmr$surveyYears <- survey_years[1]
    direct.natl.u5$region_num <- direct.natl.u5$region
    direct.natl.nmr$region_num <- direct.natl.nmr$region
    direct.natl.yearly.u5$region_num <- direct.natl.yearly.u5$region
    direct.natl.yearly.nmr$region_num <- direct.natl.yearly.nmr$region
    
  }
  # Create output directories if they don't exist
  if(!dir.exists(file.path("U5MR", country))) dir.create(file.path("U5MR", country), showWarnings = FALSE, recursive = TRUE)
  if(!dir.exists(file.path("NMR", country)))  dir.create(file.path("NMR", country), showWarnings = FALSE, recursive = TRUE)

  # save national direct estimates
  if (!direct_admin2_only) {
    save(direct.natl.u5, file = file.path("U5MR", paste0(country, '_direct_natl_u5.rda')))
    save(direct.natl.yearly.u5, file = file.path("U5MR", paste0(country, '_direct_natl_yearly_u5.rda')))
    save(direct.natl.nmr, file = file.path("NMR", paste0(country, '_direct_natl_nmr.rda')))
    save(direct.natl.yearly.nmr, file = file.path("NMR", paste0(country, '_direct_natl_yearly_nmr.rda')))
  }
  
## Admin1 ------------------------------------------------------
  
  if(length(births.list) != 1){
     direct.admin1.u5 <-  SUMMER::getDirectList(births.list, periods,
                                           regionVar = "admin1.char",
                                           timeVar = "period", 
                                           clusterVar =  "~cluster",
                                           ageVar = "age", Ntrials = "total",
                                           weightsVar = "v005",national.only = F)
    direct.admin1.yearly.u5 <- SUMMER::getDirectList(births.list, beg.year:end.year,
                                                regionVar = "admin1.char",
                                                timeVar = "years", 
                                                clusterVar =  "~cluster",
                                                ageVar = "age", Ntrials = "total",
                                                weightsVar = "v005",national.only = F)
    direct.admin1.nmr <-  SUMMER::getDirectList(births.list.nmr, periods,
                                               regionVar = "admin1.char",
                                               timeVar = "period", 
                                               clusterVar =  "~cluster",
                                               ageVar = "age", Ntrials = "total",
                                               weightsVar = "v005",national.only = F)
    direct.admin1.yearly.nmr <- SUMMER::getDirectList(births.list.nmr, beg.year:end.year,
                                                     regionVar = "admin1.char",
                                                     timeVar = "years", 
                                                     clusterVar =  "~cluster",
                                                     ageVar = "age", Ntrials = "total",
                                                     weightsVar = "v005",national.only = F)
    
    direct.admin1.u5$region_num <- direct.admin1.u5$region
    direct.admin1.yearly.u5$region_num <- direct.admin1.yearly.u5$region
    direct.admin1.nmr$region_num <- direct.admin1.nmr$region
    direct.admin1.yearly.nmr$region_num <- direct.admin1.yearly.nmr$region
  }else{
     direct.admin1.u5 <-  SUMMER::getDirect(as.data.frame(births.list[[1]]), periods,
                                       regionVar = "admin1.char",
                                       timeVar = "period", 
                                       clusterVar =  "~cluster",
                                       ageVar = "age", Ntrials = "total",
                                       weightsVar = "v005",national.only = F)
    direct.admin1.yearly.u5 <-  SUMMER::getDirect(as.data.frame(births.list[[1]]), beg.year:end.year,
                                             regionVar = "admin1.char",
                                             timeVar = "years", 
                                             clusterVar =  "~cluster",
                                             ageVar = "age", Ntrials = "total",
                                             weightsVar = "v005",national.only = F)
    direct.admin1.nmr <-  SUMMER::getDirect(as.data.frame(births.list.nmr[[1]]), periods,
                                           regionVar = "admin1.char",
                                           timeVar = "period", 
                                           clusterVar =  "~cluster",
                                           ageVar = "age", Ntrials = "total",
                                           weightsVar = "v005",national.only = F)
    direct.admin1.yearly.nmr <-  SUMMER::getDirect(as.data.frame(births.list.nmr[[1]]), beg.year:end.year,
                                                  regionVar = "admin1.char",
                                                  timeVar = "years", 
                                                  clusterVar =  "~cluster",
                                                  ageVar = "age", Ntrials = "total",
                                                  weightsVar = "v005",national.only = F)
    
    direct.admin1.u5$survey <- direct.admin1.yearly.u5$survey <- direct.admin1.nmr$survey <- direct.admin1.yearly.nmr$survey <- 1
    direct.admin1.u5$surveyYears <- direct.admin1.yearly.u5$surveyYears <- direct.admin1.nmr$surveyYears <- direct.admin1.yearly.nmr$surveyYears <- survey_years[1]
    
    direct.admin1.u5$region_num <- direct.admin1.u5$region
    direct.admin1.yearly.u5$region_num <- direct.admin1.yearly.u5$region
    direct.admin1.nmr$region_num <- direct.admin1.nmr$region
    direct.admin1.yearly.nmr$region_num <- direct.admin1.yearly.nmr$region
    
  }
  
  if (!direct_admin2_only) {
    save(direct.admin1.u5, file = file.path("U5MR", paste0(country, '_direct_admin1_u5.rda')))
    save(direct.admin1.yearly.u5, file = file.path("U5MR", paste0(country, '_direct_admin1_yearly_u5.rda')))
    save(direct.admin1.nmr, file = file.path("NMR", paste0(country, '_direct_admin1_nmr.rda')))
    save(direct.admin1.yearly.nmr, file = file.path("NMR", paste0(country, '_direct_admin1_yearly_nmr.rda')))
  }
  
## Admin2  ------------------------------------------------------
if(exists("poly.layer.adm2") && length(births.list.admin2) > 0){
  # compute 3-year direct estimates for at admin2 level. But this may fail due to the data sparsity at admin2 level.
  if(length(births.list.admin2) != 1){
    direct.admin2.u5 <-  SUMMER::getDirectList(births.list.admin2, periods,
                                               regionVar = "admin2.char",
                                               timeVar = "period", 
                                               clusterVar =  "~cluster",
                                               ageVar = "age", Ntrials = "total",
                                               weightsVar = "v005",national.only = F)
    direct.admin2.nmr <-  SUMMER::getDirectList(births.list.admin2.nmr, periods,
                                                regionVar = "admin2.char",
                                                timeVar = "period", 
                                                clusterVar =  "~cluster",
                                                ageVar = "age", Ntrials = "total",
                                                weightsVar = "v005",national.only = F)
    
    direct.admin2.u5$region_num <- direct.admin2.u5$region
    direct.admin2.nmr$region_num <- direct.admin2.nmr$region
  }else{
    direct.admin2.u5 <-  SUMMER::getDirect(as.data.frame(births.list.admin2[[1]]), periods,
                                           regionVar = "admin2.char",
                                           timeVar = "period", 
                                           clusterVar =  "~cluster",
                                           ageVar = "age", Ntrials = "total",
                                           weightsVar = "v005",national.only = F)
    direct.admin2.nmr <-  SUMMER::getDirect(as.data.frame(births.list.admin2.nmr[[1]]), periods,
                                            regionVar = "admin2.char",
                                            timeVar = "period", 
                                            clusterVar =  "~cluster",
                                            ageVar = "age", Ntrials = "total",
                                            weightsVar = "v005",national.only = F)
    
    direct.admin2.u5$survey <- direct.admin2.nmr$survey <- 1
    direct.admin2.u5$surveyYears <- direct.admin2.nmr$surveyYears <- survey_years.admin2[1]
    
    direct.admin2.u5$region_num <- direct.admin2.u5$region
    direct.admin2.nmr$region_num <- direct.admin2.nmr$region
    
  }
  # compute yearly direct estimates for at admin2 level.
  if(length(births.list.admin2) != 1){
  direct.admin2.yearly.u5 <- SUMMER::getDirectList(births.list.admin2, beg.year:end.year,
                                                   regionVar = "admin2.char",
                                                   timeVar = "years", 
                                                   clusterVar =  "~cluster",
                                                   ageVar = "age", Ntrials = "total",
                                                   weightsVar = "v005",national.only = F)
  direct.admin2.yearly.nmr <- SUMMER::getDirectList(births.list.admin2.nmr, beg.year:end.year,
                                                    regionVar = "admin2.char",
                                                    timeVar = "years", 
                                                    clusterVar =  "~cluster",
                                                    ageVar = "age", Ntrials = "total",
                                                    weightsVar = "v005",national.only = F)
  direct.admin2.yearly.u5$region_num <- direct.admin2.yearly.u5$region
  direct.admin2.yearly.nmr$region_num <- direct.admin2.yearly.nmr$region
  }else{
    direct.admin2.yearly.u5 <-  SUMMER::getDirect(as.data.frame(births.list.admin2[[1]]), beg.year:end.year,
                                                  regionVar = "admin2.char",
                                                  timeVar = "years", 
                                                  clusterVar =  "~cluster",
                                                  ageVar = "age", Ntrials = "total",
                                                  weightsVar = "v005",national.only = F)
    direct.admin2.yearly.nmr <-  SUMMER::getDirect(as.data.frame(births.list.admin2.nmr[[1]]), beg.year:end.year,
                                                   regionVar = "admin2.char",
                                                   timeVar = "years", 
                                                   clusterVar =  "~cluster",
                                                   ageVar = "age", Ntrials = "total",
                                                   weightsVar = "v005",national.only = F)
    
    direct.admin2.yearly.u5$survey <- direct.admin2.yearly.nmr$survey <- 1
    direct.admin2.yearly.u5$surveyYears <- direct.admin2.yearly.nmr$surveyYears <- survey_years.admin2[1]
    
    direct.admin2.yearly.u5$region_num <- direct.admin2.yearly.u5$region
    direct.admin2.yearly.nmr$region_num <- direct.admin2.yearly.nmr$region
  }
  
  save(direct.admin2.u5, file = file.path("U5MR", paste0(country, '_direct_admin2_u5.rda')))
  save(direct.admin2.yearly.u5, file = file.path("U5MR", paste0(country, '_direct_admin2_yearly_u5.rda')))
  save(direct.admin2.nmr, file = file.path("NMR", paste0(country, '_direct_admin2_nmr.rda')))
  save(direct.admin2.yearly.nmr, file = file.path("NMR", paste0(country, '_direct_admin2_yearly_nmr.rda')))
}  

if (direct_admin2_only) {
  stop("DIRECT_ADMIN2_ONLY_COMPLETE", call. = FALSE)
}
  
# Make HIV adjustment ------------------------------------------------------
  
  if(doHIVAdj){
    hiv.adj <- load_country_hiv_adjustments(
      file.path(home.dir, "Data", "HIV", "HIVAdjustments.rda"),
      country
    )
    if(unique(hiv.adj$area)[1] == country){
      natl.unaids <- T
    }else{
      natl.unaids <- F
    }
    
    ## National Adjustment  ------------------------------------------------------
    for(survey in survey_years){
      if(natl.unaids){
        adj.frame <- hiv.adj[hiv.adj$survey == survey,]
        adj.varnames <- c("country", "years")
      }else{
        adj.frame <- hiv.adj[hiv.adj$survey == survey,]
        adj.frame <- aggregate(ratio ~ country + years,data = adj.frame, FUN = mean)
        adj.varnames <- c("country", "years")
      }
      
      # warning if HIV adjustment has not been calculated for that year
      if(nrow(adj.frame)==0){message(paste0('HIV Adjustment for ',country,' ',survey,' survey has not been calculated. Please calculate the HIV adjustment before proceeding.'))}
      
      # adjustment for yearly u5mr
      tmp.adj <- SUMMER::getAdjusted(direct.natl.yearly.u5[direct.natl.yearly.u5$surveyYears == survey,],
                                     ratio = adj.frame, 
                                     logit.lower = NULL,
                                     logit.upper = NULL,
                                     prob.upper = "upper",
                                     prob.lower = "lower")
      direct.natl.yearly.u5[direct.natl.yearly.u5$surveyYears == survey,] <- 
        tmp.adj[ ,  match(colnames(direct.natl.yearly.u5),
                          colnames(tmp.adj))]
      
      # adjustment for 3-year period u5mr
      if(survey==beg.year){
        adj.frame.tmp <- adj.frame[adj.frame$years %in%  beg.period.years, ]
      }else{
        adj.frame.tmp <- adj.frame[adj.frame$years %in%  (beg.period.years + 1), ]}
      adj.frame.tmp$years <- periods[1:nrow(adj.frame.tmp)]
    
      tmp.adj <- SUMMER::getAdjusted(direct.natl.u5[direct.natl.u5$surveyYears == survey,],
                                     ratio = adj.frame.tmp, 
                                     logit.lower = NULL,
                                     logit.upper = NULL,
                                     prob.upper = "upper",
                                     prob.lower = "lower")
      direct.natl.u5[direct.natl.u5$surveyYears == survey,] <- 
        tmp.adj[ ,  match(colnames(direct.natl.u5),
                          colnames(tmp.adj))]
      
      # adjustment for yearly nmr
      tmp.adj <- SUMMER::getAdjusted(direct.natl.yearly.nmr[direct.natl.yearly.nmr$surveyYears == survey,],
                                     ratio = adj.frame, 
                                     logit.lower = NULL,
                                     logit.upper = NULL,
                                     prob.upper = "upper",
                                     prob.lower = "lower")
      direct.natl.yearly.nmr[direct.natl.yearly.nmr$surveyYears == survey,] <- 
        tmp.adj[ ,  match(colnames(direct.natl.yearly.nmr),
                          colnames(tmp.adj))]
      
      # adjustment for 3-year period nmr
      if(survey==beg.year){
        adj.frame.tmp <- adj.frame[adj.frame$years %in%  beg.period.years, ]
      }else{
        adj.frame.tmp <- adj.frame[adj.frame$years %in%  (beg.period.years + 1), ]}
      adj.frame.tmp$years <- periods[1:nrow(adj.frame.tmp)]
      
      tmp.adj <- SUMMER::getAdjusted(direct.natl.nmr[direct.natl.nmr$surveyYears == survey,],
                                     ratio = adj.frame.tmp, 
                                     logit.lower = NULL,
                                     logit.upper = NULL,
                                     prob.upper = "upper",
                                     prob.lower = "lower")
      direct.natl.nmr[direct.natl.nmr$surveyYears == survey,] <- 
        tmp.adj[ ,  match(colnames(direct.natl.nmr),
                          colnames(tmp.adj))]
    }
    
    ## Admin 1 and 2 Adjustment ------------------------------------------------------
    for(survey in survey_years){
      if(natl.unaids){
        adj.frame <- hiv.adj[hiv.adj$survey == survey,]
        adj.varnames <- c("country", "years")
      }else{
        adj.frame <- hiv.adj[hiv.adj$survey == survey,]
        adj.varnames <- c("country", "region", "years")
      }
      
      for(area in admin1.names$GeoRepo){
        if(natl.unaids){
          if(survey==beg.year){
            adj.frame.tmp <- adj.frame[adj.frame$years %in%  beg.period.years, ]
          }else{
            adj.frame.tmp <- adj.frame[adj.frame$years %in%  (beg.period.years + 1), ]}
          adj.frame.tmp$years <- periods[1:nrow(adj.frame.tmp)]
          adj.frame.tmp.yearly <- adj.frame
          
        }else{
          if(country == "Zambia" & area == "North-Western"){
            adj.frame$area[adj.frame$area == "Northwestern"] <- area
          }
          if(survey==beg.year){
            adj.frame.tmp <- adj.frame[adj.frame$area == area & adj.frame$years %in% beg.period.years, ]
            adj.frame.tmp$years <- periods[match(adj.frame.tmp$years, beg.period.years)]
          }else{
            adj.frame.tmp <- adj.frame[adj.frame$area == area & adj.frame$years %in% (beg.period.years + 1), ]
            adj.frame.tmp$years <- periods[match(adj.frame.tmp$years, beg.period.years+1)]
          }
          adj.frame.tmp.yearly <- adj.frame[adj.frame$area == area, ]
        }
        
        area.int <- admin1.names$Internal[match(area, admin1.names$GeoRepo)]
        
        #adjustment for 3-year period U5MR
         tmp.adj <- SUMMER::getAdjusted(direct.admin1.u5[direct.admin1.u5$region == as.character(area.int) &
                                                        direct.admin1.u5$surveyYears == survey,],
                                        ratio = adj.frame.tmp, 
                                        logit.lower = NULL,
                                        logit.upper = NULL,
                                        prob.upper = "upper",
                                        prob.lower = "lower")
         direct.admin1.u5[direct.admin1.u5$region == as.character(area.int) &
                         direct.admin1.u5$surveyYears == survey,] <- 
           tmp.adj[ , match(colnames(direct.admin1.u5),
                            colnames(tmp.adj))]
        
         #adjustment for yearly U5MR
        tmp.adj <- SUMMER::getAdjusted(direct.admin1.yearly.u5[direct.admin1.yearly.u5$region == as.character(area.int) &
                                                       direct.admin1.yearly.u5$surveyYears == survey,],
                                       ratio = adj.frame.tmp.yearly,
                                       logit.lower = NULL,
                                       logit.upper = NULL,
                                       prob.upper = "upper",
                                       prob.lower = "lower")
        direct.admin1.yearly.u5[direct.admin1.yearly.u5$region == as.character(area.int) &
                        direct.admin1.yearly.u5$surveyYears == survey,] <- 
          tmp.adj[ , match(colnames(direct.admin1.yearly.u5),
                           colnames(tmp.adj))]
        
        #adjustment for 3-year period NMR
        tmp.adj <- SUMMER::getAdjusted(direct.admin1.nmr[direct.admin1.nmr$region == as.character(area.int) &
                                                          direct.admin1.nmr$surveyYears == survey,],
                                       ratio = adj.frame.tmp, 
                                       logit.lower = NULL,
                                       logit.upper = NULL,
                                       prob.upper = "upper",
                                       prob.lower = "lower")
        direct.admin1.nmr[direct.admin1.nmr$region == as.character(area.int) &
                           direct.admin1.nmr$surveyYears == survey,] <- 
          tmp.adj[ , match(colnames(direct.admin1.nmr),
                           colnames(tmp.adj))]
        
        #adjustment for yearly NMR
        tmp.adj <- SUMMER::getAdjusted(direct.admin1.yearly.nmr[direct.admin1.yearly.nmr$region == as.character(area.int) &
                                                                 direct.admin1.yearly.nmr$surveyYears == survey,],
                                       ratio = adj.frame.tmp.yearly, 
                                       logit.lower = NULL,
                                       logit.upper = NULL,
                                       prob.upper = "upper",
                                       prob.lower = "lower")
        direct.admin1.yearly.nmr[direct.admin1.yearly.nmr$region == as.character(area.int) &
                                  direct.admin1.yearly.nmr$surveyYears == survey,] <- 
          tmp.adj[ , match(colnames(direct.admin1.yearly.nmr),
                           colnames(tmp.adj))]
        
        if(exists('direct.admin2.u5')){
          #adjustment for 3-year period U5MR
          admin2.to.admin1 <- births.list[[1]][!duplicated(births.list[[1]]$admin2.name),] %>% 
            dplyr::select(GeoRepo.adm2=admin2.name,Internal.adm2=admin2.char,GeoRepo.adm1 = admin1.name)
          admin2.to.admin1 <- data.frame(admin2.to.admin1,
                                         Internal.adm1 = NA)
          admin2.to.admin1$Internal.adm1 <- admin1.names$Internal[match(admin2.to.admin1$GeoRepo.adm1,
                                                                        admin1.names$GeoRepo)]
          admin2s <- admin2.to.admin1$Internal.adm2[admin2.to.admin1$Internal.adm1 == 
                                                      as.character(area.int)]
          tmp.adj <- SUMMER::getAdjusted(direct.admin2.u5[direct.admin2.u5$region %in% admin2s &
                                                         direct.admin2.u5$surveyYears == survey,],
                                         ratio = adj.frame.tmp, 
                                         logit.lower = NULL,
                                         logit.upper = NULL,
                                         prob.upper = "upper",
                                         prob.lower = "lower")
          direct.admin2.u5[direct.admin2.u5$region %in% admin2s &
                          direct.admin2.u5$surveyYears == survey,] <- 
            tmp.adj[ , match(colnames(direct.admin2.u5), 
                             colnames(tmp.adj))]
          
          #adjustment for yearly U5MR
          tmp.adj <- SUMMER::getAdjusted(direct.admin2.yearly.u5[direct.admin2.yearly.u5$region %in% admin2s &
                                                                   direct.admin2.yearly.u5$surveyYears == survey,],
                                         ratio = adj.frame.tmp.yearly, 
                                         logit.lower = NULL,
                                         logit.upper = NULL,
                                         prob.upper = "upper",
                                         prob.lower = "lower")
          direct.admin2.yearly.u5[direct.admin2.yearly.u5$region %in% admin2s &
                                    direct.admin2.yearly.u5$surveyYears == survey,] <- 
            tmp.adj[ , match(colnames(direct.admin2.yearly.u5),
                             colnames(tmp.adj))]
          
          #adjustment for 3-year period NMR
          admin2.to.admin1 <- births.list.nmr[[1]][!duplicated(births.list.nmr[[1]]$admin2.name),] %>% 
            dplyr::select(GeoRepo.adm2=admin2.name,Internal.adm2=admin2.char,GeoRepo.adm1 = admin1.name)
          admin2.to.admin1 <- data.frame(admin2.to.admin1,
                                         Internal.adm1 = NA)
          admin2.to.admin1$Internal.adm1 <- admin1.names$Internal[match(admin2.to.admin1$GeoRepo.adm1,
                                                                        admin1.names$GeoRepo)]
          admin2s <- admin2.to.admin1$Internal.adm2[admin2.to.admin1$Internal.adm1 == 
                                                      as.character(area.int)]
          tmp.adj <- SUMMER::getAdjusted(direct.admin2.nmr[direct.admin2.nmr$region %in% admin2s &
                                                            direct.admin2.nmr$surveyYears == survey,],
                                         ratio = adj.frame.tmp, 
                                         logit.lower = NULL,
                                         logit.upper = NULL,
                                         prob.upper = "upper",
                                         prob.lower = "lower")
          direct.admin2.nmr[direct.admin2.nmr$region %in% admin2s &
                             direct.admin2.nmr$surveyYears == survey,] <- 
            tmp.adj[ , match(colnames(direct.admin2.nmr), 
                             colnames(tmp.adj))]
          
          #adjustment for yearly NMR
          tmp.adj <- SUMMER::getAdjusted(direct.admin2.yearly.nmr[direct.admin2.yearly.nmr$region %in% admin2s &
                                                                   direct.admin2.yearly.nmr$surveyYears == survey,],
                                         ratio = adj.frame.tmp.yearly, 
                                         logit.lower = NULL,
                                         logit.upper = NULL,
                                         prob.upper = "upper",
                                         prob.lower = "lower")
          direct.admin2.yearly.nmr[direct.admin2.yearly.nmr$region %in% admin2s &
                                    direct.admin2.yearly.nmr$surveyYears == survey,] <- 
            tmp.adj[ , match(colnames(direct.admin2.yearly.nmr),
                             colnames(tmp.adj))]
        }
      }
    }
    
    save(direct.natl.u5, file = file.path("U5MR", paste0(country, '_directHIV_natl_u5.rda')))
    save(direct.natl.yearly.u5, file = file.path("U5MR", paste0(country, '_directHIV_natl_yearly_u5.rda')))
    save(direct.admin1.u5, file = file.path("U5MR", paste0(country, '_directHIV_admin1_u5.rda')))
    save(direct.admin1.yearly.u5, file = file.path("U5MR", paste0(country, '_directHIV_admin1_yearly_u5.rda')))
    if(exists('direct.admin2.u5')){
      save(direct.admin2.u5, file = file.path("U5MR", paste0(country, '_directHIV_admin2_u5.rda')))
      save(direct.admin2.yearly.u5, file = file.path("U5MR", paste0(country, '_directHIV_admin2_yearly_u5.rda')))
    }
    save(direct.natl.nmr, file = file.path("NMR", paste0(country, '_directHIV_natl_nmr.rda')))
    save(direct.natl.yearly.nmr, file = file.path("NMR", paste0(country, '_directHIV_natl_yearly_nmr.rda')))
    save(direct.admin1.nmr, file = file.path("NMR", paste0(country, '_directHIV_admin1_nmr.rda')))
    save(direct.admin1.yearly.nmr, file = file.path("NMR", paste0(country, '_directHIV_admin1_yearly_nmr.rda')))
    if(exists('direct.admin2.nmr')){
      save(direct.admin2.nmr, file = file.path("NMR", paste0(country, '_directHIV_admin2_nmr.rda')))
      save(direct.admin2.yearly.nmr, file = file.path("NMR", paste0(country, '_directHIV_admin2_yearly_nmr.rda')))
    }
    
  }
  
  

# Smoothed direct estimates  ------------------------------------------------------

  time.model <- c('rw2','ar1')[2]
  
## load in appropriate direct estimates  ------------------------------------------------------
  use_path_base(file.path(res.dir, "Direct"))
  if(doHIVAdj){
  load(file.path("U5MR", paste0(country, '_directHIV_natl_u5.rda')))
  load(file.path("U5MR", paste0(country, '_directHIV_natl_yearly_u5.rda')))
  load(file.path("U5MR", paste0(country, '_directHIV_admin1_u5.rda')))
  load(file.path("U5MR", paste0(country, '_directHIV_admin1_yearly_u5.rda')))
  
  load(file.path("NMR", paste0(country, '_directHIV_natl_nmr.rda')))
  load(file.path("NMR", paste0(country, '_directHIV_natl_yearly_nmr.rda')))
  load(file.path("NMR", paste0(country, '_directHIV_admin1_nmr.rda')))
  load(file.path("NMR", paste0(country, '_directHIV_admin1_yearly_nmr.rda')))
  
  if(exists("poly.layer.adm2")){
    load(file.path("U5MR", paste0(country, '_directHIV_admin2_u5.rda')))
    load(file.path("NMR", paste0(country, '_directHIV_admin2_nmr.rda')))
    load(file.path("U5MR", paste0(country, '_directHIV_admin2_yearly_u5.rda')))
    load(file.path("NMR", paste0(country, '_directHIV_admin2_yearly_nmr.rda')))
  }
}else{
  load(file.path("U5MR", paste0(country, '_direct_natl_u5.rda')))
  load(file.path("U5MR", paste0(country, '_direct_natl_yearly_u5.rda')))
  load(file.path("U5MR", paste0(country, '_direct_admin1_u5.rda')))
  load(file.path("U5MR", paste0(country, '_direct_admin1_yearly_u5.rda')))
  
  load(file.path("NMR", paste0(country, '_direct_natl_nmr.rda')))
  load(file.path("NMR", paste0(country, '_direct_natl_yearly_nmr.rda')))
  load(file.path("NMR", paste0(country, '_direct_admin1_nmr.rda')))
  load(file.path("NMR", paste0(country, '_direct_admin1_yearly_nmr.rda')))
  
  if(exists("poly.layer.adm2")){
    load(file.path("U5MR", paste0(country, '_direct_admin2_u5.rda')))
    load(file.path("NMR", paste0(country, '_direct_admin2_nmr.rda')))
    load(file.path("U5MR", paste0(country, '_direct_admin2_yearly_u5.rda')))
    load(file.path("NMR", paste0(country, '_direct_admin2_yearly_nmr.rda')))
  }
}
  
## aggregate surveys  ------------------------------------------------------
data.natl.u5 <- SUMMER::aggregateSurvey(direct.natl.u5)
data.natl.yearly.u5 <- SUMMER::aggregateSurvey(direct.natl.yearly.u5)
data.admin1.u5 <- SUMMER::aggregateSurvey(direct.admin1.u5)
data.admin1.yearly.u5 <- SUMMER::aggregateSurvey(direct.admin1.yearly.u5)

data.natl.nmr <- SUMMER::aggregateSurvey(direct.natl.nmr)
data.natl.yearly.nmr <- SUMMER::aggregateSurvey(direct.natl.yearly.nmr)
data.admin1.nmr <- SUMMER::aggregateSurvey(direct.admin1.nmr)
data.admin1.yearly.nmr <- SUMMER::aggregateSurvey(direct.admin1.yearly.nmr)

if(exists("poly.layer.adm2")){
  data.admin2.u5 <- SUMMER::aggregateSurvey(direct.admin2.u5)
  data.admin2.yearly.u5 <- SUMMER::aggregateSurvey(direct.admin2.yearly.u5)
  data.admin2.nmr <- SUMMER::aggregateSurvey(direct.admin2.nmr)
  data.admin2.yearly.nmr <- SUMMER::aggregateSurvey(direct.admin2.yearly.nmr)
}

smoothing_inputs <- c(
  "data.natl.u5", "data.natl.yearly.u5",
  "data.admin1.u5", "data.admin1.yearly.u5",
  "data.natl.nmr", "data.natl.yearly.nmr",
  "data.admin1.nmr", "data.admin1.yearly.nmr"
)
if (exists("poly.layer.adm2")) {
  smoothing_inputs <- c(
    smoothing_inputs,
    "data.admin2.u5", "data.admin2.yearly.u5",
    "data.admin2.nmr", "data.admin2.yearly.nmr"
  )
}
for (smoothing_input in smoothing_inputs) {
  assign(
    smoothing_input,
    exclude_degenerate_direct_variances(
      get(smoothing_input),
      label = smoothing_input
    )
  )
}


## extend periods to include projected years  ------------------------------------------------------

# > beg.period.years
# [1] 2000 2002 2004 2007 2010 2013 2016 2019 2022
# > end.period.years
# [1] 2001 2003 2006 2009 2012 2015 2018 2021 2024


if (end.proj.year > end.year) {
  beg.proj.years <- seq(end.year + 1, end.proj.year, by = 3)
  end.proj.years <- pmin(beg.proj.years + 2, end.proj.year)
  proj.per <- paste(beg.proj.years, end.proj.years, sep = "-")
} else {
  message("No projection years specified; only estimating for years with data.")
  beg.proj.years <- end.proj.years <- end.year
  proj.per <- character(0)
}

## full time period (including projected years)
periods.survey <- periods
periods <- c(periods.survey, proj.per)
period_mid_years <- c(
  (beg.period.years + end.period.years) / 2,
  if (length(proj.per) > 0) (beg.proj.years + end.proj.years) / 2 else numeric(0)
)


## National, 3-year period ------------------------------------------------------

# here we need INLA
# install.packages('INLA', repos=c(getOption('repos'), INLA='https://inla.r-inla-download.org/R/stable'), dep=TRUE)

## U5MR
fit.natl.u5 <- smoothDirect(data.natl.u5, Amat = NULL, # national level model doesn't need to specify adjacency matrix since it would just be 1.
                     year_label = c(periods), time.model = time.model,
                     year_range = c(beg.year, max(end.proj.years)),
                     control.inla = list(strategy = "adaptive", int.strategy = "auto"), is.yearly = F) # fit the smoothed direct model. Changing the year label and year range can change the years the estimators to be computed, 
## even for future years where DHS data is not yet available. But this would lead to less accurate estimates and larger uncertainty level.

 res.natl.u5 <- get_smoothed_with_retry("national period U5MR",
                         fit.natl.u5, year_range = c(beg.year, max(end.proj.years)),
                         year_label = periods, save.draws = TRUE) # sample for smoothed direct estimates
 
 res.natl.u5$years.num <- period_mid_years[match(res.natl.u5$years, periods)]
 res.natl.u5$region.georepo <- country
 save(res.natl.u5, file = file.path("U5MR", paste0(country, "_res_natl_", time.model, "_u5_SmoothedDirect.rda"))) # save the national 3-year smoothed direct U5MR
 
 ## NMR
 fit.natl.nmr <- smoothDirect(data.natl.nmr, geo = NULL, Amat = NULL, # national level model doesn't need to specify adjacency matrix since it would just be 1.
                             year_label = c(periods),
                             year_range = c(beg.year, max(end.proj.years)),time.model = time.model,
                             control.inla = list(strategy = "adaptive", int.strategy = "auto"),
                             is.yearly = F) # fit the smoothed direct model. Changing the year label and year range can change the years the estimators to be computed, 
 ## even for future years where DHS data is not yet available. But this would lead to less accurate estimates and larger uncertainty level.
 
 res.natl.nmr <- get_smoothed_with_retry("national period NMR",
                            fit.natl.nmr, year_range = c(beg.year, max(end.proj.years)),
                            year_label = periods) # sample for smoothed direct estimates
 
 res.natl.nmr$years.num <- period_mid_years[match(res.natl.nmr$years, periods)]
 res.natl.nmr$region.georepo <- country
 save(res.natl.nmr, file = file.path("NMR", paste0(country, "_res_natl_", time.model, "_nmr_SmoothedDirect.rda")))
 

## National, yearly  ------------------------------------------------------
  # include 3 years after last survey
 #U5MR
fit.natl.yearly.u5 <- smoothDirect(data.natl.yearly.u5, geo = NULL, Amat = NULL,
                           year_label = as.character(beg.year:max(end.proj.years)),
                           year_range = c(beg.year, max(end.proj.years)), time.model = time.model,
                           control.inla = list(strategy = "adaptive", int.strategy = "auto"), is.yearly = F)
res.natl.yearly.u5 <- get_smoothed_with_retry("national yearly U5MR",
                               fit.natl.yearly.u5, year_range = c(beg.year, max(end.proj.years)),
                               year_label = as.character(beg.year:max(end.proj.years)))
res.natl.yearly.u5$years.num <- beg.year:max(end.proj.years)
res.natl.yearly.u5$region.georepo <- country
save(res.natl.yearly.u5, file = file.path("U5MR", paste0(country, "_res_natl_", time.model, "_yearly_u5_SmoothedDirect.rda"))) # save the national yearly smoothed direct U5MR

#NMR
fit.natl.yearly.nmr <- smoothDirect(data.natl.yearly.nmr, geo = NULL, Amat = NULL,
                                   year_label = as.character(beg.year:max(end.proj.years)), time.model = time.model,
                                   year_range = c(beg.year, max(end.proj.years)), 
                                   control.inla = list(strategy = "adaptive", int.strategy = "auto"), is.yearly = F)
res.natl.yearly.nmr <- get_smoothed_with_retry("national yearly NMR",
                                  fit.natl.yearly.nmr, year_range = c(beg.year, max(end.proj.years)),
                                  year_label = as.character(beg.year:max(end.proj.years)))
res.natl.yearly.nmr$years.num <- beg.year:max(end.proj.years)
res.natl.yearly.nmr$region.georepo <- country
save(res.natl.yearly.nmr, file = file.path("NMR", paste0(country, "_res_natl_", time.model, "_yearly_nmr_SmoothedDirect.rda"))) # save the national yearly smoothed direct U5MR


## Admin 1, 3-year period  ------------------------------------------------------

## U5MR
data.admin1.u5 <- data.admin1.u5[data.admin1.u5$region!='All',] # direct.admin1 is a matrix containing all national and admin1 level estimates. Only admin1 estimates are interested here.
admin1.u5.retry <- fit_admin_period_smoothed_direct(
  label = "admin1 period U5MR",
  data = data.admin1.u5,
  Amat = admin1.mat,
  year_label = periods,
  year_range = c(beg.year, max(end.proj.years)),
  time.model = time.model,
  save.draws = TRUE
)
fit.admin1.u5 <- admin1.u5.retry$fit
res.admin1.u5 <- admin1.u5.retry$result

res.admin1.u5$years.num <- period_mid_years[match(res.admin1.u5$years, periods)]
res.admin1.u5$region.georepo <- admin1.names$GeoRepo[match(res.admin1.u5$region, admin1.names$Internal)]

save(res.admin1.u5, file = file.path("U5MR", paste0(country, "_res_admin1_", time.model, "_u5_SmoothedDirect.rda")))# save the admin1 3-year smoothed direct U5MR

## NMR
data.admin1.nmr <- data.admin1.nmr[data.admin1.nmr$region!='All',] # direct.admin1 is a matrix containing all national and admin1 level estimates. Only admin1 estimates are interested here.
admin1.nmr.retry <- fit_admin_period_smoothed_direct(
  label = "admin1 period NMR",
  data = data.admin1.nmr,
  Amat = admin1.mat,
  year_label = periods,
  year_range = c(beg.year, max(end.proj.years)),
  time.model = time.model,
  save.draws = TRUE
)
fit.admin1.nmr <- admin1.nmr.retry$fit
res.admin1.nmr <- admin1.nmr.retry$result

res.admin1.nmr$years.num <- period_mid_years[match(res.admin1.nmr$years, periods)]
res.admin1.nmr$region.georepo <- admin1.names$GeoRepo[match(res.admin1.nmr$region, admin1.names$Internal)]

save(res.admin1.nmr, file = file.path("NMR", paste0(country, "_res_admin1_", time.model, "_nmr_SmoothedDirect.rda")))# save the admin1 3-year smoothed direct U5MR


## Admin 1, yearly  ------------------------------------------------------
tryCatch({
##U5MR
data.admin1.yearly.u5 <- data.admin1.yearly.u5[data.admin1.yearly.u5$region!='All',]
fit.admin1.yearly.u5 <- smoothDirect(data.admin1.yearly.u5, Amat = admin1.mat, time.model = time.model,
                             year_label = as.character(beg.year:max(end.proj.years)),type.st = 4,
                             year_range = c(beg.year, max(end.proj.years)), is.yearly = F)
sd.admin1.yearly.u5 <- get_smoothed_with_retry("admin1 yearly U5MR",
                                   fit.admin1.yearly.u5, Amat = admin1.mat,
                                   year_label = as.character(beg.year:max(end.proj.years)),
                                   year_range = c(beg.year, max(end.proj.years)),
                                   save.draws = TRUE)
sd.admin1.yearly.u5$region.georepo <- admin1.names$GeoRepo[match(sd.admin1.yearly.u5$region, admin1.names$Internal)]

save(sd.admin1.yearly.u5, file = file.path("U5MR", paste0(country, "_res_admin1_", time.model, "_u5_SmoothedDirect_yearly.rda"))) # save the admin1 yearly smoothed direct U5MR

##NMR
data.admin1.yearly.nmr <- data.admin1.yearly.nmr[data.admin1.yearly.nmr$region!='All',]
fit.admin1.yearly.nmr <- smoothDirect(data.admin1.yearly.nmr, Amat = admin1.mat, time.model = time.model,
                                     year_label = as.character(beg.year:max(end.proj.years)),type.st = 4,
                                     year_range = c(beg.year, max(end.proj.years)), is.yearly = F)
sd.admin1.yearly.nmr <- get_smoothed_with_retry("admin1 yearly NMR",
                                      fit.admin1.yearly.nmr, Amat = admin1.mat,
                                      year_label = as.character(beg.year:max(end.proj.years)),
                                      year_range = c(beg.year, max(end.proj.years)),
                                      save.draws = TRUE)
sd.admin1.yearly.nmr$region.georepo <- admin1.names$GeoRepo[match(sd.admin1.yearly.nmr$region, admin1.names$Internal)]

save(sd.admin1.yearly.nmr, file = file.path("NMR", paste0(country, "_res_admin1_", time.model, "_nmr_SmoothedDirect_yearly.rda"))) # save the admin1 yearly smoothed direct U5MR

}, silent=T, error = function(e) {message('Yearly smoothed direct model cannot be fit at the Admin1 level due to data sparsity.
                                      This means a Betabinomial model will need to be fit.')})

## Admin 2, 3-year period ------------------------------------------------------

if(exists("poly.layer.adm2")){

## U5MR
tryCatch({
data.admin2.u5 <- data.admin2.u5[data.admin2.u5$region!='All',] # direct.admin1 is a matrix containing all national and admin1 level estimates. Only admin1 estimates are interested here.
fit.admin2.u5 <- smoothDirect(data.admin2.u5, Amat = admin2.mat,
                      year_label = periods,type.st = 4, time.model = time.model,
                      year_range = c(beg.year, max(end.proj.years)), is.yearly = F)
res.admin2.u5 <- get_smoothed_with_retry("admin2 period U5MR",
                             fit.admin2.u5, Amat = admin2.mat,
                             year_label = periods,
                             year_range = c(beg.year, max(end.proj.years)),
                             save.draws = TRUE)

res.admin2.u5$years.num <- period_mid_years[match(res.admin2.u5$years, periods)]
res.admin2.u5$region.georepo <- admin2.names$GeoRepo[match(res.admin2.u5$region, admin2.names$Internal)]

save(res.admin2.u5, file = file.path("U5MR", paste0(country, "_res_admin2_", time.model, "_u5_SmoothedDirect.rda")))
}, silent=T, error = function(e) {message('Admin2 period smoothed direct U5MR cannot be fit due to data sparsity.
                                      This means a Betabinomial model will need to be fit.')})

## NMR
tryCatch({
data.admin2.nmr <- data.admin2.nmr[data.admin2.nmr$region!='All',] # direct.admin1 is a matrix containing all national and admin1 level estimates. Only admin1 estimates are interested here.
fit.admin2.nmr <- smoothDirect(data.admin2.nmr, Amat = admin2.mat,
                              year_label = periods,type.st = 4, time.model = time.model,
                              year_range = c(beg.year, max(end.proj.years)), is.yearly = F)
res.admin2.nmr <- get_smoothed_with_retry("admin2 period NMR",
                                fit.admin2.nmr, Amat = admin2.mat,
                                year_label = periods,
                                year_range = c(beg.year, max(end.proj.years)),
                                save.draws = TRUE)

res.admin2.nmr$years.num <- period_mid_years[match(res.admin2.nmr$years, periods)]
res.admin2.nmr$region.georepo <- admin2.names$GeoRepo[match(res.admin2.nmr$region, admin2.names$Internal)]

save(res.admin2.nmr, file = file.path("NMR", paste0(country, "_res_admin2_", time.model, "_nmr_SmoothedDirect.rda")))
}, silent=T, error = function(e) {message('Admin2 period smoothed direct NMR cannot be fit due to data sparsity.
                                      This means a Betabinomial model will need to be fit.')})

}

## Admin 2, yearly  ------------------------------------------------------
if(exists("poly.layer.adm2")){
##U5MR
tryCatch({
data.admin2.yearly.u5 <- data.admin2.yearly.u5[data.admin2.yearly.u5$region!='All',]
fit.admin2.yearly.u5 <- smoothDirect(data.admin2.yearly.u5, Amat = admin2.mat, time.model = time.model,
                                     year_label = as.character(beg.year:max(end.proj.years)),type.st = 4,
                                     year_range = c(beg.year, max(end.proj.years)), is.yearly = F)
sd.admin2.yearly.u5 <- get_smoothed_with_retry("admin2 yearly U5MR",
                                   fit.admin2.yearly.u5, Amat = admin2.mat,
                                   year_label = as.character(beg.year:max(end.proj.years)),
                                   year_range = c(beg.year, max(end.proj.years)),
                                   save.draws = TRUE)
sd.admin2.yearly.u5$region.georepo <- admin2.names$GeoRepo[match(sd.admin2.yearly.u5$region, admin2.names$Internal)]

save(sd.admin2.yearly.u5, file = file.path("U5MR", paste0(country, "_res_admin2_", time.model, "_u5_SmoothedDirect_yearly.rda"))) # save the admin2 yearly smoothed direct U5MR

##NMR
data.admin2.yearly.nmr <- data.admin2.yearly.nmr[data.admin2.yearly.nmr$region!='All',]
fit.admin2.yearly.nmr <- smoothDirect(data.admin2.yearly.nmr, Amat = admin2.mat, time.model = time.model,
                                      year_label = as.character(beg.year:max(end.proj.years)),type.st = 4,
                                      year_range = c(beg.year, max(end.proj.years)), is.yearly = F)
sd.admin2.yearly.nmr <- get_smoothed_with_retry("admin2 yearly NMR",
                                    fit.admin2.yearly.nmr, Amat = admin2.mat,
                                    year_label = as.character(beg.year:max(end.proj.years)),
                                    year_range = c(beg.year, max(end.proj.years)),
                                    save.draws = TRUE)
sd.admin2.yearly.nmr$region.georepo <- admin2.names$GeoRepo[match(sd.admin2.yearly.nmr$region, admin2.names$Internal)]

save(sd.admin2.yearly.nmr, file = file.path("NMR", paste0(country, "_res_admin2_", time.model, "_nmr_SmoothedDirect_yearly.rda"))) # save the admin2 yearly smoothed direct U5MR

}, silent=T, error = function(e) {message('Yearly smoothed direct model cannot be fit at the Admin2 level due to data sparsity. 
                                          This means a Betabinomial model will need to be fit.')})
}


# Polygon plots ------------------------------------------------------
# for example 

use_path_base(res.dir)
ensure_output_dir("Figures", "Direct")
ensure_output_dir("Figures", "SmoothedDirect")
ensure_output_dir("Figures", "SmoothedDirect", "U5MR")
ensure_output_dir("Figures", "SmoothedDirect", "NMR")

## Admin 1 Direct, aggregated across surveys  ------------------------------------------------------

## U5MR
plotagg.admin1.u5 <- aggregateSurvey(direct.admin1.u5)
plotagg.admin1.u5$regionPlot <- admin1.names$GeoRepo[match(plotagg.admin1.u5$region,
                                                     admin1.names$Internal)]
pdf(file.path("Figures", "Direct", paste0(country, "_admin1_direct_u5_poly_Meta.pdf")))
{
  print(SUMMER::mapPlot(data = plotagg.admin1.u5,
                        is.long = T, 
                        variables = "years", 
                        values = "mean",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 3,
                        legend.label = "U5MR",
                        per1000 = TRUE,
                        by.data = "regionPlot",
                        by.geo = sub(".*data[$]","",poly.label.adm1)))
}
dev.off()
message("Saved figure: ", last_plot_file())

## NMR
plotagg.admin1.nmr <- aggregateSurvey(direct.admin1.nmr)
plotagg.admin1.nmr$regionPlot <- admin1.names$GeoRepo[match(plotagg.admin1.nmr$region,
                                                        admin1.names$Internal)]
pdf(file.path("Figures", "Direct", paste0(country, "_admin1_direct_nmr_poly_Meta.pdf")))
{
  print(SUMMER::mapPlot(data = plotagg.admin1.nmr,
                        is.long = T, 
                        variables = "years", 
                        values = "mean",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 3,
                        legend.label = "NMR",
                        per1000 = TRUE,
                        by.data = "regionPlot",
                        by.geo = sub(".*data[$]","",poly.label.adm1)))
}
dev.off()
message("Saved figure: ", last_plot_file())


## Admin 1 Smoothed Direct  ------------------------------------------------------

## U5MR
pdf(file.path("Figures", "SmoothedDirect", paste0(country, "_admin1_", time.model, "_u5_SmoothedDirect_poly.pdf")))
{
  print(SUMMER::mapPlot(data = res.admin1.u5,
                        is.long = T, 
                        variables = "years", 
                        values = "median",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 3,
                        legend.label = "U5MR",
                        per1000 = TRUE,
                        by.data = "region.georepo",
                        by.geo = sub(".*data[$]","",poly.label.adm1)))
  
}
dev.off()
message("Saved figure: ", last_plot_file())

## NMR
pdf(file.path("Figures", "SmoothedDirect", paste0(country, "_admin1_", time.model, "_nmr_SmoothedDirect_poly.pdf")))
{
  print(SUMMER::mapPlot(data = res.admin1.nmr,
                        is.long = T, 
                        variables = "years", 
                        values = "median",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 3,
                        legend.label = "NMR",
                        per1000 = TRUE,
                        by.data = "region.georepo",
                        by.geo = sub(".*data[$]","",poly.label.adm1)))
  
}
dev.off()
message("Saved figure: ", last_plot_file())


## Admin 1 Yearly Direct, aggregated across surveys  ------------------------------------------------------

## U5MR
plotagg.admin1.yearly.u5 <- aggregateSurvey(direct.admin1.yearly.u5)
table(plotagg.admin1.yearly.u5$years)
# 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 
# 38   38   38   38   38   38   38   38   38   38   38   38   38   38   38   38   38   38   38   38   38   38
plotagg.admin1.yearly.u5$regionPlot <- admin1.names$GeoRepo[match(plotagg.admin1.yearly.u5$region,
                                                        admin1.names$Internal)]
pdf(file.path("Figures", "Direct", paste0(country, "_admin1_direct_yearly_u5_poly_Meta.pdf")))
{
  print(SUMMER::mapPlot(data = plotagg.admin1.yearly.u5,
                        is.long = T, 
                        variables = "years", 
                        values = "mean",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 5,
                        legend.label = "U5MR",
                        per1000 = TRUE,
                        by.data = "regionPlot",
                        by.geo = sub(".*data[$]","",poly.label.adm1)))
}
dev.off()
message("Saved figure: ", last_plot_file())



## NMR
plotagg.admin1.yearly.nmr <- aggregateSurvey(direct.admin1.yearly.nmr)
plotagg.admin1.yearly.nmr$regionPlot <- admin1.names$GeoRepo[match(plotagg.admin1.yearly.nmr$region,
                                                         admin1.names$Internal)]
pdf(file.path("Figures", "Direct", paste0(country, "_admin1_direct_yearly_nmr_poly_Meta.pdf")))
{
  print(SUMMER::mapPlot(data = plotagg.admin1.yearly.nmr,
                        is.long = T, 
                        variables = "years", 
                        values = "mean",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 5,
                        legend.label = "NMR",
                        per1000 = TRUE,
                        by.data = "regionPlot",
                        by.geo = sub(".*data[$]","",poly.label.adm1)))
}
dev.off()
message("Saved figure: ", last_plot_file())


## Admin 1 Yearly Smoothed Direct  ------------------------------------------------------
# SUMMER does not support true yearly AR1 smoothDirect fits. For the yearly
# diagnostic maps, use the stable period smoothed-direct estimates expanded
# across survey years instead of the sparse single-year diagnostic fit.

if(exists('res.admin1.u5')){
## U5MR
admin1.yearly.u5.map <- expand_smoothed_periods_to_years(
  res.admin1.u5, periods.survey, beg.period.years, end.period.years, end.year
)
pdf(file.path("Figures", "SmoothedDirect", "U5MR", paste0(country, "_admin1_", time.model, "_yearly_u5_SmoothedDirect_poly.pdf")))
{
  print(SUMMER::mapPlot(data = admin1.yearly.u5.map,
                        is.long = T, 
                        variables = "years", 
                        values = "median",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 5,
                        legend.label = "U5MR",
                        per1000 = TRUE,
                        by.data = "region.georepo",
                        by.geo = sub(".*data[$]","",poly.label.adm1)))
  
}
dev.off()
message("Saved figure: ", last_plot_file())
}

if(exists('sd.admin1.yearly.nmr')){
## NMR
pdf(file.path("Figures", "SmoothedDirect", "NMR", paste0(country, "_admin1_", time.model, "_yearly_nmr_SmoothedDirect_poly.pdf")))
{
  print(SUMMER::mapPlot(data = sd.admin1.yearly.nmr,
                        is.long = T, 
                        variables = "years", 
                        values = "median",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 5,
                        legend.label = "NMR",
                        per1000 = TRUE,
                        by.data = "region.georepo",
                        by.geo = sub(".*data[$]","",poly.label.adm1)))
  
}
dev.off()
message("Saved figure: ", last_plot_file())
}

## Admin 2 Direct, aggregated across surveys  ------------------------------------------------------
if(exists("poly.layer.adm2")){
## U5MR
plotagg.admin2.u5 <- aggregateSurvey(direct.admin2.u5)
plotagg.admin2.u5$regionPlot <- admin2.names$GeoRepo[match(plotagg.admin2.u5$region,
                                                     admin2.names$Internal)]
pdf(file.path("Figures", "Direct", paste0(country, "_admin2_u5_direct_poly_Meta.pdf")))
{
  print(SUMMER::mapPlot(data = plotagg.admin2.u5,
                        is.long = T, 
                        variables = "years", 
                        values = "mean",
                        direction = -1,
                        geo = poly.adm2,
                        ncol = 3,
                        legend.label = "U5MR",
                        per1000 = TRUE,
                        by.data = "regionPlot",
                        by.geo =sub(".*data[$]","",poly.label.adm2)))
}
dev.off()
message("Saved figure: ", last_plot_file())

## NMR
plotagg.admin2.nmr <- aggregateSurvey(direct.admin2.nmr)
plotagg.admin2.nmr$regionPlot <- admin2.names$GeoRepo[match(plotagg.admin2.nmr$region,
                                                        admin2.names$Internal)]
pdf(file.path("Figures", "Direct", paste0(country, "_admin2_nmr_direct_poly_Meta.pdf")))
{
  print(SUMMER::mapPlot(data = plotagg.admin2.nmr,
                        is.long = T, 
                        variables = "years", 
                        values = "mean",
                        direction = -1,
                        geo = poly.adm2,
                        ncol = 3,
                        legend.label = "NMR",
                        per1000 = TRUE,
                        by.data = "regionPlot",
                        by.geo =sub(".*data[$]","",poly.label.adm2)))
}
dev.off()
message("Saved figure: ", last_plot_file())

}
## Admin 2 Smoothed Direct  ------------------------------------------------------
if(exists("poly.adm2")){
  if(exists('res.admin2.u5')){
## U5MR
pdf(file.path("Figures", "SmoothedDirect", "U5MR", paste0(country, "_admin2_", time.model, "_u5_SmoothedDirect_poly.pdf")))
{
  print(SUMMER::mapPlot(data = res.admin2.u5,
                        is.long = T, 
                        variables = "years", 
                        values = "median",
                        direction = -1,
                        geo = poly.adm2,
                        ncol = 3,
                        legend.label = "U5MR",
                        per1000 = TRUE,
                        by.data = "region.georepo",
                        by.geo = sub(".*data[$]","",poly.label.adm2)))
  
}
dev.off()
message("Saved figure: ", last_plot_file())
}

  if(exists('res.admin2.nmr')){
## NMR
pdf(file.path("Figures", "SmoothedDirect", "NMR", paste0(country, "_admin2_", time.model, "_nmr_SmoothedDirect_poly.pdf")))
{
  print(SUMMER::mapPlot(data = res.admin2.nmr,
                        is.long = T, 
                        variables = "years", 
                        values = "median",
                        direction = -1,
                        geo = poly.adm2,
                        ncol = 3,
                        legend.label = "NMR",
                        per1000 = TRUE,
                        by.data = "region.georepo",
                        by.geo = sub(".*data[$]","",poly.label.adm2)))
  
}
dev.off()
message("Saved figure: ", last_plot_file())
}
}

## Admin 2 Yearly Direct, aggregated across surveys  ------------------------------------------------------

if(exists("poly.adm2")){
## U5MR
plotagg.admin2.yearly.u5 <- aggregateSurvey(direct.admin2.yearly.u5)
plotagg.admin2.yearly.u5$regionPlot <- admin2.names$GeoRepo[match(plotagg.admin2.yearly.u5$region,
                                                               admin2.names$Internal)]
pdf(file.path("Figures", "Direct", paste0(country, "_admin2_direct_yearly_u5_poly_Meta.pdf")))
{
  print(SUMMER::mapPlot(data = plotagg.admin2.yearly.u5,
                        is.long = T, 
                        variables = "years", 
                        values = "mean",
                        direction = -1,
                        geo = poly.adm2,
                        ncol = 5,
                        legend.label = "U5MR",
                        per1000 = TRUE,
                        by.data = "regionPlot",
                        by.geo = sub(".*data[$]","",poly.label.adm2)))
}
dev.off()
message("Saved figure: ", last_plot_file())

## NMR
plotagg.admin2.yearly.nmr <- aggregateSurvey(direct.admin2.yearly.nmr)
plotagg.admin2.yearly.nmr$regionPlot <- admin2.names$GeoRepo[match(plotagg.admin2.yearly.nmr$region,
                                                                admin2.names$Internal)]
pdf(file.path("Figures", "Direct", paste0(country, "_admin2_direct_yearly_nmr_poly_Meta.pdf")))
{
  print(SUMMER::mapPlot(data = plotagg.admin2.yearly.nmr,
                        is.long = T, 
                        variables = "years", 
                        values = "mean",
                        direction = -1,
                        geo = poly.adm2,
                        ncol = 5,
                        legend.label = "NMR",
                        per1000 = TRUE,
                        by.data = "regionPlot",
                        by.geo = sub(".*data[$]","",poly.label.adm2)))
}
dev.off()
message("Saved figure: ", last_plot_file())
}

## Admin 2 Yearly Smoothed Direct  ------------------------------------------------------
if(exists('res.admin2.u5')){
## U5MR
admin2.yearly.u5.map <- expand_smoothed_periods_to_years(
  res.admin2.u5, periods.survey, beg.period.years, end.period.years, end.year
)
pdf(file.path("Figures", "SmoothedDirect", "U5MR", paste0(country, "_admin2_", time.model, "_yearly_u5_SmoothedDirect_poly.pdf")))
{
  print(SUMMER::mapPlot(data = admin2.yearly.u5.map,
                        is.long = T, 
                        variables = "years", 
                        values = "median",
                        direction = -1,
                        geo = poly.adm2,
                        ncol = 5,
                        legend.label = "U5MR",
                        per1000 = TRUE,
                        by.data = "region.georepo",
                        by.geo = sub(".*data[$]","",poly.label.adm2)))
  
}
dev.off()
message("Saved figure: ", last_plot_file())
}

if(exists('sd.admin2.yearly.nmr')){
## NMR
pdf(file.path("Figures", "SmoothedDirect", "NMR", paste0(country, "_admin2_", time.model, "_yearly_nmr_SmoothedDirect_poly.pdf")))
{
  print(SUMMER::mapPlot(data = sd.admin2.yearly.nmr,
                        is.long = T, 
                        variables = "years", 
                        values = "median",
                        direction = -1,
                        geo = poly.adm2,
                        ncol = 5,
                        legend.label = "NMR",
                        per1000 = TRUE,
                        by.data = "region.georepo",
                        by.geo = sub(".*data[$]","",poly.label.adm2)))
  
}
dev.off()
message("Saved figure: ", last_plot_file())
}


# Spaghetti plots ------------------------------------------------------

## Load IGME estimates ------------------------------------------------------
{
  use_path_base(file.path(home.dir, "Data", "IGME"))
  
  ## U5MR
  igme.ests.u5.raw <- read.csv('igme2026_u5.csv')
  igme.ests.u5 <- igme.ests.u5.raw[igme.ests.u5.raw$ISO.Code==iso0,]
  igme.ests.u5 <- data.frame(t(igme.ests.u5[,10:ncol(igme.ests.u5)]))
  names(igme.ests.u5) <- c('LOWER_BOUND','OBS_VALUE','UPPER_BOUND')
  igme.ests.u5$year <-  as.numeric(stringr::str_remove(row.names(igme.ests.u5),'X')) - 0.5
  igme.ests.u5 <- igme.ests.u5[igme.ests.u5$year %in% beg.year:end.proj.year,]
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
  igme.ests.nmr <- igme.ests.nmr[igme.ests.nmr$year %in% beg.year:end.proj.year,]
  rownames(igme.ests.nmr) <- NULL
  igme.ests.nmr$OBS_VALUE <- igme.ests.nmr$OBS_VALUE/1000
  igme.ests.nmr$SD <- (igme.ests.nmr$UPPER_BOUND - igme.ests.nmr$LOWER_BOUND)/(2*1.645*1000)
  igme.ests.nmr$LOWER_BOUND <- igme.ests.nmr$OBS_VALUE - 1.96*igme.ests.nmr$SD
  igme.ests.nmr$UPPER_BOUND <- igme.ests.nmr$OBS_VALUE + 1.96*igme.ests.nmr$SD
}

## National, 3-year period ------------------------------------------------------
use_path_base(res.dir)
cols <- rainbow(length(survey_years))
pane.years <- (beg.period.years + end.period.years)/2

## U5MR
direct.natl.u5$width <- direct.natl.u5$upper - direct.natl.u5$lower
direct.natl.u5$cex2 <- median(direct.natl.u5$width, na.rm = T)/direct.natl.u5$width
direct.natl.u5$cex2[direct.natl.u5$cex2 > 6] <- 6

if(dim(direct.natl.u5)[1] != 0 &
   !(sum(is.na(direct.natl.u5$mean)) == nrow(direct.natl.u5))){
  plot.max <- max(res.natl.u5$upper+.025, na.rm = T)
}else{plot.max <- 0.25}

pdf(file.path("Figures", "SmoothedDirect", "U5MR", paste0(country, "_natl_", time.model, "_u5_SmoothedDirect_spaghetti.pdf")),
    height = 6, width = 6)
{
  par(mfrow=c(1,1))
  if(nrow(direct.natl.u5) > 0 & sum(is.na(direct.natl.u5$mean)) == nrow(direct.natl.u5)){
    plot(NA,
         xlab = "Year",
         ylab = "U5MR",
         ylim = c(0, plot.max),
         xlim = c(beg.year, max(end.proj.years)),
         type = 'l',
         col = cols[svy.idx],
         lwd = 2,
         main = country)
    
    legend('topright',
           bty = 'n',
           col = c(cols, 'grey37', 'black'),
           lwd = 2, lty = 1,
           legend = c(survey_years,"UN IGME", "Smoothed"))
    
  }else{
    for(survey in survey_years){
      tmp <- direct.natl.u5[direct.natl.u5$surveyYears == survey,]
      svy.idx <- match(survey, survey_years) 
      
      if(svy.idx==1){
        plot(NA, xlab = "Year", ylab = "U5MR",
             ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)),
             type = 'l', col = cols[svy.idx], lwd = 2, main = country)
        
        lines(pane.years, tmp$mean, cex = tmp$cex2,
              type = 'l',  col = adjustcolor(cols[svy.idx], 0.35), lwd = 2)
        
        points(pane.years, tmp$mean, pch = 19,
               col = adjustcolor(cols[svy.idx], 0.35),
               cex = tmp$cex2)
        
        #add IGME reference lines
        igme.years <- jitter(beg.year:max(igme.ests.u5$year))
        lines(igme.years,
              igme.ests.u5$OBS_VALUE,
              lwd = 2, col  = 'grey37')
        lines(igme.years,
              igme.ests.u5$UPPER_BOUND,
              lty = 2, col  = 'grey37')
        lines(igme.years,
              igme.ests.u5$LOWER_BOUND, 
              lty = 2, col  = 'grey37')
        
      }else{
        lines(pane.years, tmp$mean, cex = tmp$cex2,
              type = 'l',  col = adjustcolor(cols[svy.idx], 0.35), lwd = 2)
        points(pane.years, tmp$mean, pch = 19, 
               col = adjustcolor(cols[svy.idx], 0.35),
               cex = tmp$cex2)
      }
      
    }
  }
  lines(res.natl.u5$years.num, res.natl.u5$median,
        col = 'black', lwd = 2)
  lines(res.natl.u5$years.num, res.natl.u5$upper,
        col = 'black', lty = 2)
  lines(res.natl.u5$years.num,res.natl.u5$lower, 
        col = 'black', lty = 2)
  legend('topright', bty = 'n',
         col = c(cols, 'grey37','black'),
         lwd = 2, legend = c(survey_years,'UN IGME', "Smoothed"))
  
}
dev.off()
message("Saved figure: ", last_plot_file())

## NMR
direct.natl.nmr$width <- direct.natl.nmr$upper - direct.natl.nmr$lower
direct.natl.nmr$cex2 <- median(direct.natl.nmr$width, na.rm = T)/direct.natl.nmr$width
direct.natl.nmr$cex2[direct.natl.nmr$cex2 > 6] <- 6

if(dim(direct.natl.nmr)[1] != 0 &
   !(sum(is.na(direct.natl.nmr$mean)) == nrow(direct.natl.nmr))){
  plot.max <- max(res.natl.nmr$upper+.025, na.rm = T)
}else{plot.max <- 0.25}

pdf(file.path("Figures", "SmoothedDirect", "NMR", paste0(country, "_natl_", time.model, "_nmr_SmoothedDirect_spaghetti.pdf")),
    height = 6, width = 6)
{
  par(mfrow=c(1,1))
  if(nrow(direct.natl.nmr) > 0 & sum(is.na(direct.natl.nmr$mean)) == nrow(direct.natl.nmr)){
    plot(NA,
         xlab = "Year",
         ylab = "NMR",
         ylim = c(0, plot.max),
         xlim = c(beg.year, max(end.proj.years)),
         type = 'l',
         col = cols[svy.idx],
         lwd = 2,
         main = country)
    
    legend('topright',
           bty = 'n',
           col = c(cols, 'grey37', 'black'),
           lwd = 2, lty = 1,
           legend = c(survey_years,"UN IGME", "Smoothed"))
    
  }else{
    for(survey in survey_years){
      tmp <- direct.natl.nmr[direct.natl.nmr$surveyYears == survey,]
      svy.idx <- match(survey, survey_years) 
      
      if(svy.idx==1){
        plot(NA, xlab = "Year", ylab = "NMR",
             ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)),
             type = 'l', col = cols[svy.idx], lwd = 2, main = country)
        
        lines(pane.years, tmp$mean, cex = tmp$cex2,
              type = 'l',  col = adjustcolor(cols[svy.idx], 0.35), lwd = 2)
        
        points(pane.years, tmp$mean, pch = 19,
               col = adjustcolor(cols[svy.idx], 0.35),
               cex = tmp$cex2)
        
        #add IGME reference lines
        igme.years <- jitter(beg.year:max(igme.ests.nmr$year))
        lines(igme.years,
              igme.ests.nmr$OBS_VALUE,
              lwd = 2, col  = 'grey37')
        lines(igme.years,
              igme.ests.nmr$UPPER_BOUND,
              lty = 2, col  = 'grey37')
        lines(igme.years,
              igme.ests.nmr$LOWER_BOUND, 
              lty = 2, col  = 'grey37')
        
      }else{
        lines(pane.years, tmp$mean, cex = tmp$cex2,
              type = 'l',  col = adjustcolor(cols[svy.idx], 0.35), lwd = 2)
        points(pane.years, tmp$mean, pch = 19, 
               col = adjustcolor(cols[svy.idx], 0.35),
               cex = tmp$cex2)
      }
      
    }
  }
  lines(res.natl.nmr$years.num, res.natl.nmr$median,
        col = 'black', lwd = 2)
  lines(res.natl.nmr$years.num, res.natl.nmr$upper,
        col = 'black', lty = 2)
  lines(res.natl.nmr$years.num,res.natl.nmr$lower, 
        col = 'black', lty = 2)
  legend('topright', bty = 'n',
         col = c(cols, 'grey37','black'),
         lwd = 2, legend = c(survey_years,'UN IGME', "Smoothed"))
  
}
dev.off()
message("Saved figure: ", last_plot_file())


## National, yearly ------------------------------------------------------

cols <- rainbow(length(survey_years))

## U5MR
direct.natl.yearly.u5$width <- direct.natl.yearly.u5$upper - direct.natl.yearly.u5$lower
direct.natl.yearly.u5$cex2 <- median(direct.natl.yearly.u5$width, na.rm = T)/direct.natl.yearly.u5$width
direct.natl.yearly.u5$cex2[direct.natl.yearly.u5$cex2 > 6] <- 6

if(dim(direct.natl.yearly.u5)[1] != 0 & !(sum(is.na(direct.natl.yearly.u5$mean)) == nrow(direct.natl.yearly.u5))){
  plot.max <- max(res.natl.yearly.u5$upper+.025, na.rm = T)
}else{plot.max <- 0.25}

pdf(file.path("Figures", "SmoothedDirect", "U5MR", paste0(country, "_natl_", time.model, "_yearly_u5_SmoothedDirect_spaghetti.pdf")),
    height = 6, width = 6)
{
  par(mfrow=c(1,1))
  if (nrow(direct.natl.yearly.u5) > 0 & sum(is.na(direct.natl.yearly.u5$mean)) == nrow(direct.natl.yearly.u5)) {
    plot(NA, xlab = "Year", ylab = "U5MR",
         ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)),
         type = 'l', lwd = 2,col = cols[svy.idx], main = country)
    
    legend('topright', bty = 'n',
           col = c(cols, 'grey37', 'black'),
           lwd = 2,
           legend = c(survey_years,"UN IGME","Smoothed"))
    
  }else{
    for(survey in survey_years){
      tmp <- direct.natl.yearly.u5[direct.natl.yearly.u5$surveyYears == survey,]
      svy.idx <- match(survey, survey_years) 
      pane.years <- jitter(tmp$years)
      
      if(svy.idx==1){
        plot(NA, xlab = "Year", ylab = "U5MR",
             ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)),
             type = 'l', col = cols[svy.idx], lwd = 2, main = country)
        
        lines(pane.years, tmp$mean, cex = tmp$cex2,
              type = 'l', col = cols[svy.idx], lwd = 2)
        
        points(pane.years, tmp$mean, pch = 19,
               col = adjustcolor(cols[svy.idx], 0.35),
               cex = tmp$cex2)
        
        #add IGME reference lines
        igme.years <- jitter(beg.year:max(igme.ests.u5$year))
        lines(igme.years,
              igme.ests.u5$OBS_VALUE,
              lwd = 2, col  = 'grey37')
        lines(igme.years,
              igme.ests.u5$UPPER_BOUND,
              lty = 2, col  = 'grey37')
        lines(igme.years,
              igme.ests.u5$LOWER_BOUND, 
              lty = 2, col  = 'grey37')
        
      }else{
        lines(pane.years, tmp$mean, cex = tmp$cex2,
              type = 'l', col = cols[svy.idx], lwd = 2)
        points(pane.years, tmp$mean, pch = 19, 
               col = adjustcolor(cols[svy.idx], 0.35),
               cex = tmp$cex2)
      }
    }
  }
  
  lines(res.natl.yearly.u5$years.num, res.natl.yearly.u5$median,
        col = 'black', lwd = 2)
  lines(res.natl.yearly.u5$years.num, res.natl.yearly.u5$upper,
        col = 'black', lty = 2)
  lines(res.natl.yearly.u5$years.num,res.natl.yearly.u5$lower, 
        col = 'black', lty = 2)
  legend('topright', bty = 'n',
         col = c(cols, 'grey37','black'),
         lwd = 2, legend = c(survey_years,"UN IGME", "Smoothed"))
}
dev.off()
message("Saved figure: ", last_plot_file())

## NMR
direct.natl.yearly.nmr$width <- direct.natl.yearly.nmr$upper - direct.natl.yearly.nmr$lower
direct.natl.yearly.nmr$cex2 <- median(direct.natl.yearly.nmr$width, na.rm = T)/direct.natl.yearly.nmr$width
direct.natl.yearly.nmr$cex2[direct.natl.yearly.nmr$cex2 > 6] <- 6

if(dim(direct.natl.yearly.nmr)[1] != 0 & !(sum(is.na(direct.natl.yearly.nmr$mean)) == nrow(direct.natl.yearly.nmr))){
  plot.max <- max(res.natl.yearly.nmr$upper+.025, na.rm = T)
}else{plot.max <- 0.25}

pdf(file.path("Figures", "SmoothedDirect", "NMR", paste0(country, "_natl_", time.model, "_yearly_nmr_SmoothedDirect_spaghetti.pdf")),
    height = 6, width = 6)
{
  par(mfrow=c(1,1))
  if (nrow(direct.natl.yearly.nmr) > 0 & sum(is.na(direct.natl.yearly.nmr$mean)) == nrow(direct.natl.yearly.nmr)) {
    plot(NA, xlab = "Year", ylab = "NMR",
         ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)),
         type = 'l', lwd = 2,col = cols[svy.idx], main = country)
    
    legend('topright', bty = 'n',
           col = c(cols, 'grey37', 'black'),
           lwd = 2,
           legend = c(survey_years,"UN IGME","Smoothed"))
    
  }else{
    for(survey in survey_years){
      tmp <- direct.natl.yearly.nmr[direct.natl.yearly.nmr$surveyYears == survey,]
      svy.idx <- match(survey, survey_years) 
      pane.years <- jitter(tmp$years)
      
      if(svy.idx==1){
        plot(NA, xlab = "Year", ylab = "NMR",
             ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)),
             type = 'l', col = cols[svy.idx], lwd = 2, main = country)
        
        lines(pane.years, tmp$mean, cex = tmp$cex2,
              type = 'l', col = cols[svy.idx], lwd = 2)
        
        points(pane.years, tmp$mean, pch = 19,
               col = adjustcolor(cols[svy.idx], 0.35),
               cex = tmp$cex2)
        
        #add IGME reference lines
        igme.years <- jitter(beg.year:max(igme.ests.nmr$year))
        lines(igme.years,
              igme.ests.nmr$OBS_VALUE,
              lwd = 2, col  = 'grey37')
        lines(igme.years,
              igme.ests.nmr$UPPER_BOUND,
              lty = 2, col  = 'grey37')
        lines(igme.years,
              igme.ests.nmr$LOWER_BOUND, 
              lty = 2, col  = 'grey37')
        
      }else{
        lines(pane.years, tmp$mean, cex = tmp$cex2,
              type = 'l', col = cols[svy.idx], lwd = 2)
        points(pane.years, tmp$mean, pch = 19, 
               col = adjustcolor(cols[svy.idx], 0.35),
               cex = tmp$cex2)
      }
    }
  }
  
  lines(res.natl.yearly.nmr$years.num, res.natl.yearly.nmr$median,
        col = 'black', lwd = 2)
  lines(res.natl.yearly.nmr$years.num, res.natl.yearly.nmr$upper,
        col = 'black', lty = 2)
  lines(res.natl.yearly.nmr$years.num,res.natl.yearly.nmr$lower, 
        col = 'black', lty = 2)
  legend('topright', bty = 'n',
         col = c(cols, 'grey37','black'),
         lwd = 2, legend = c(survey_years,"UN IGME", "Smoothed"))
}
dev.off()
message("Saved figure: ", last_plot_file())


## Admin 1, 3-year period ------------------------------------------------------

source(file.path(home.dir, 'Rcode', '_supporting_scripts', 'report_output_config.R'))
admin1.names <- filter_report_admin_rows(
  admin1.names, report_excluded_admin_ids(home.dir, country, 1L), 'Internal'
)
cols <- rainbow(nrow(admin1.names))

## U5MR
pdf(file.path("Figures", "SmoothedDirect", "U5MR", paste0(country, "_admin1_", time.model, "_u5_SmoothedDirect_spaghetti.pdf")),
    height = 7, width = 12)
{
  old.par <- par(mfrow = c(1, 1), lend = 1, mar = c(5, 4, 4, 16), xpd = NA)
  plot.max <- max(res.admin1.u5$upper+.025, na.rm = T)
  
  plot(NA, xlab = "Year", ylab = "U5MR",
       ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)), main = paste0(country,' - Admin 1 Regions'))
  
  for(area in seq_len(nrow(admin1.names))){
    tmp.area <- direct.admin1.u5[direct.admin1.u5$region == 
                                as.character(admin1.names$Internal[area]),]
    tmp.area$width <- tmp.area$upper - tmp.area$lower
    tmp.area$cex2 <- median(tmp.area$width, na.rm = T)/tmp.area$width
    tmp.area$cex2[tmp.area$cex2 > 6] <- 6
    
    res.area <- res.admin1.u5[res.admin1.u5$region == as.character(admin1.names$Internal[area]),]
    
    lines(res.area$years.num,res.area$median,
          col = cols[area], lwd = 2)
    lines(res.area$years.num, res.area$upper,
          col = cols[area], lty = 2)
    lines(res.area$years.num,
          res.area$lower, col = cols[area], lty = 2)
    }  
   
  draw_admin1_spaghetti_legend(admin1.names$GeoRepo, cols, max(end.proj.years) + 0.6, plot.max)
  par(old.par)
}
dev.off()
message("Saved figure: ", last_plot_file())

## NMR
pdf(file.path("Figures", "SmoothedDirect", "NMR", paste0(country, "_admin1_", time.model, "_nmr_SmoothedDirect_spaghetti.pdf")),
    height = 7, width = 12)
{
  old.par <- par(mfrow = c(1, 1), lend = 1, mar = c(5, 4, 4, 16), xpd = NA)
  plot.max <- max(res.admin1.nmr$upper+.025, na.rm = T)
  
  plot(NA, xlab = "Year", ylab = "NMR",
       ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)), main = paste0(country,' - Admin 1 Regions'))
  
  for(area in seq_len(nrow(admin1.names))){
    tmp.area <- direct.admin1.nmr[direct.admin1.nmr$region == 
                                   as.character(admin1.names$Internal[area]),]
    tmp.area$width <- tmp.area$upper - tmp.area$lower
    tmp.area$cex2 <- median(tmp.area$width, na.rm = T)/tmp.area$width
    tmp.area$cex2[tmp.area$cex2 > 6] <- 6
    
    res.area <- res.admin1.nmr[res.admin1.nmr$region == as.character(admin1.names$Internal[area]),]
    
    lines(res.area$years.num,res.area$median,
          col = cols[area], lwd = 2)
    lines(res.area$years.num, res.area$upper,
          col = cols[area], lty = 2)
    lines(res.area$years.num,
          res.area$lower, col = cols[area], lty = 2)
  }  
  
  draw_admin1_spaghetti_legend(admin1.names$GeoRepo, cols, max(end.proj.years) + 0.6, plot.max)
  par(old.par)
}
dev.off()
message("Saved figure: ", last_plot_file())

## Admin 2, 3-year period ------------------------------------------------------

if(exists("poly.adm2")){
cols <- rainbow(nrow(admin2.names))

## U5MR
if(exists('res.admin2.u5')){
pdf(file.path("Figures", "SmoothedDirect", "U5MR", paste0(country, "_admin2_", time.model, "_u5_SmoothedDirect_spaghetti.pdf")),
    height = 6, width = 6)
{
  par(mfrow=c(1,1),lend=1)
  plot.max <- max(res.admin2.u5$median+.025, na.rm = T)
  
  plot(NA, xlab = "Year", ylab = "U5MR",
       ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)), main = paste0(country,' - Admin 2 Regions'))
  
  for(area in 1:dim(poly.adm2)[1]){
    tmp.area <- direct.admin2.u5[direct.admin2.u5$region == 
                                as.character(admin2.names$Internal[area]),]
    tmp.area$width <- tmp.area$upper - tmp.area$lower
    tmp.area$cex2 <- median(tmp.area$width, na.rm = T)/tmp.area$width
    tmp.area$cex2[tmp.area$cex2 > 6] <- 6
    
    res.area <- res.admin2.u5[res.admin2.u5$region == as.character(admin2.names$Internal[area]),]
    
    lines(res.area$years.num,res.area$median,
          col = cols[area], lwd = 1)
    
  }  
  
}
dev.off()
message("Saved figure: ", last_plot_file())
}

## NMR
if(exists('res.admin2.nmr')){
pdf(file.path("Figures", "SmoothedDirect", "NMR", paste0(country, "_admin2_", time.model, "_nmr_SmoothedDirect_spaghetti.pdf")),
    height = 6, width = 6)
{
  par(mfrow=c(1,1),lend=1)
  plot.max <- max(res.admin2.nmr$median+.025, na.rm = T)
  
  plot(NA, xlab = "Year", ylab = "NMR",
       ylim = c(0, plot.max), xlim = c(beg.year, max(end.proj.years)), main = paste0(country,' - Admin 2 Regions'))
  
  for(area in 1:dim(poly.adm2)[1]){
    tmp.area <- direct.admin2.nmr[direct.admin2.nmr$region == 
                                   as.character(admin2.names$Internal[area]),]
    tmp.area$width <- tmp.area$upper - tmp.area$lower
    tmp.area$cex2 <- median(tmp.area$width, na.rm = T)/tmp.area$width
    tmp.area$cex2[tmp.area$cex2 > 6] <- 6
    
    res.area <- res.admin2.nmr[res.admin2.nmr$region == as.character(admin2.names$Internal[area]),]
    
    lines(res.area$years.num,res.area$median,
          col = cols[area], lwd = 1)
    
  }  
  
}
dev.off()
message("Saved figure: ", last_plot_file())
}
}


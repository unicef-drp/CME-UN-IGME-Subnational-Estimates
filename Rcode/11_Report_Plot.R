USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
source(file.path(dir_subnational,
                 "Rcode/_supporting_scripts/malawi_report_admin_hierarchy.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}

# install.packages("lintr")
# library(lintr)
# lint(filename = 
# "U://UN-Subnational-Estimates/Rcode/Archived Plots/CountrySummary_Plot.R")


if(!is.null(dev.list())) dev.off() # close any open devices

# Country context is loaded by Rcode/1_Preperation.R.

# Setup -----------------------------------------------
## Load libraries and info ----------------------------------------------------------

# Libraries
options(gsubfn.engine = "R")
suppressPackageStartupMessages({
library(data.table)
library(survey)
library(sp)
library(scales)
library(RColorBrewer)
library(gridExtra)
library(raster)
library(latticeExtra)
library(viridis)
library(xtable)
library(Hmisc)
library(spdep)
library(rasterVis)
library(plotrix)
library(ggridges)
# library(maptools)
# library(rgdal)
library(ggplot2)
library(SUMMER)
library(tidyverse)
library(sf)
})

# extract file location of this script
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  code.path <- rstudioapi::getActiveDocumentContext()$path
} else {
  file.arg <- "--file="
  script.args <- commandArgs(trailingOnly = FALSE)
  script.path <- sub(file.arg, "", script.args[grepl(paste0("^", file.arg), script.args)])
  
  if (length(script.path) > 0) {
    code.path <- normalizePath(script.path[1], winslash = "/", mustWork = TRUE)
  } else {
    code.path <- normalizePath("Rcode/11_Report_Plot.R",
                               winslash = "/", mustWork = TRUE)
  }
}
code.path.splitted <- strsplit(code.path, "/")[[1]]

## Directories ####
home.dir <- project_home()
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
require_country_context()
time.model <- final_model$time.model
sd.time.model <- final_model$sd.time.model
strata.model <- final_model$strata.model
bench.model <- final_model$bench.model
country_print <- gsub("_", " ", country, fixed = TRUE)
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}
bb8_admin1_only <- tolower(Sys.getenv("BB8_ADMIN1_ONLY", "0")) %in%
  c("1", "true", "yes", "y")
run_admin2_report <- exists("poly.layer.adm2", inherits = TRUE) &&
  !bb8_admin1_only
if (bb8_admin1_only) {
  message("BB8_ADMIN1_ONLY=1; skipping Admin-2 report outputs.")
}

## what is the equivalent of poly.label.adm2 that
## has the column name of admin1 names in the admin2 shapefile
if(run_admin2_report && exists('poly.label.adm2')){
  adm1_on_adm2 <- paste0("poly.adm2[['", poly.label.adm1, "']]")
  message("If your country does not use GeoRepo shapefiles, ", 
          "you will need to specify this manually.\n")
}
if(!dir.exists(file.path(res.dir, "Figures", "Summary"))){
  dir.create(file.path(res.dir, "Figures", "Summary"))
}
if(!dir.exists(file.path(res.dir, "Figures", "Summary", "U5MR"))){
  dir.create(file.path(res.dir, "Figures", "Summary", "U5MR"))
}
if(!dir.exists(file.path(res.dir, "Figures", "Summary", "NMR"))){
  dir.create(file.path(res.dir, "Figures", "Summary", "NMR"))
}

# Load helper functions ####
use_path_base(home.dir)
source("Rcode/_supporting_scripts/Report_Plot_00.R")
source("Rcode/_supporting_scripts/report_output_config.R")
source("Rcode/_supporting_scripts/admin1_national_total_plot.R")

# Load Data ####
## Load admin names  ------------------------------------------------------
use_path_base(data.dir)

load(file.path(poly.path, paste0(country, "_Amat.rda")))
load(file.path(poly.path, paste0(country, "_Amat_Names.rda")))

if(country == "Pakistan"){
  load(file.path(poly.path, paste0(country, "_Amat_excluding_disputed.rda")))
  load(file.path(poly.path, paste0(country, "_Amat_Names_excluding_disputed.rda")))
  
  disputed_areas_georepo <- unique(c(setdiff(admin1.names$GeoRepo,admin1.names_excluding_disputed$GeoRepo),
                                  setdiff(admin2.names$GeoRepo,admin2.names_excluding_disputed$GeoRepo)))
  disputed_areas_internal <- c(setdiff(admin1.names$Internal,admin1.names_excluding_disputed$Internal),
                               setdiff(admin2.names$Internal,admin2.names_excluding_disputed$Internal))
  
  admin1.names <- admin1.names_excluding_disputed
  admin2.names <- admin2.names_excluding_disputed
}

normalize_utf8_text <- function(labels) {
  labels <- as.character(labels)
  invalid_utf8 <- !is.na(labels) & !validUTF8(labels)
  labels[invalid_utf8] <- iconv(labels[invalid_utf8], from = "latin1",
                                to = "UTF-8", sub = "byte")
  enc2utf8(labels)
}

normalize_admin_name_table <- function(names_df) {
  text_columns <- vapply(
    names_df,
    function(column) is.character(column) || is.factor(column),
    logical(1)
  )
  names_df[text_columns] <- lapply(
    names_df[text_columns],
    normalize_utf8_text
  )
  names_df
}

admin_display_names <- function(names_df) {
  label_candidates <- c("GeoRepo", "GADM")
  label_col <- label_candidates[label_candidates %in% names(names_df)][1]
  if (is.na(label_col)) {
    label_col <- setdiff(names(names_df), "Internal")[1]
  }
  if (is.na(label_col)) {
    stop("Admin name table needs a display-name column.", call. = FALSE)
  }
  normalize_utf8_text(names_df[[label_col]])
}

report_name_map <- if (exists("report_admin_name_map", inherits = TRUE)) {
  get("report_admin_name_map", inherits = TRUE)
} else {
  NULL
}

admin1.names <- normalize_admin_name_table(admin1.names)
admin1.names$Display <- admin_display_names(admin1.names)
admin1.names$Join <- admin1.names$Display
admin1.names$Display <- apply_report_admin_name_map(
  admin1.names$Join,
  report_name_map
)
if (exists("admin2.names")) {
  admin2.names <- normalize_admin_name_table(admin2.names)
  admin2.names$Display <- admin_display_names(admin2.names)
  admin2.names$Join <- admin2.names$Display
  admin2.names$Display <- apply_report_admin_name_map(
    admin2.names$Join,
    report_name_map
  )
}

## Load IGME estimates ------------------------------------------------------

{
  use_path_base(file.path(home.dir, "Data", "IGME"))
  
  ## U5MR
  igme.ests.u5.raw <- read.csv('igme2026_u5.csv')
  igme.ests.u5 <- igme.ests.u5.raw[igme.ests.u5.raw$ISO.Code==iso0,]
  igme.ests.u5 <- data.frame(t(igme.ests.u5[,10:ncol(igme.ests.u5)]))
  names(igme.ests.u5) <- c('LOWER_BOUND','OBS_VALUE','UPPER_BOUND')
  igme.ests.u5$year <-  as.numeric(stringr::str_remove(row.names(igme.ests.u5),'X')) - 0.5
  igme.ests.u5 <- igme.ests.u5[igme.ests.u5$year %in% 2000:2024,]
  rownames(igme.ests.u5) <- NULL
  igme.ests.u5$OBS_VALUE <- igme.ests.u5$OBS_VALUE/1000
  igme.ests.u5$LOWER_BOUND <- igme.ests.u5$LOWER_BOUND/1000
  igme.ests.u5$UPPER_BOUND <- igme.ests.u5$UPPER_BOUND/1000
  
  
  ## NMR
  igme.ests.nmr.raw <- read.csv('igme2026_nmr.csv')
  igme.ests.nmr <- igme.ests.nmr.raw[igme.ests.nmr.raw$ISO.Code==iso0,]
  igme.ests.nmr <- data.frame(t(igme.ests.nmr[,10:ncol(igme.ests.nmr)]))
  names(igme.ests.nmr) <- c('LOWER_BOUND','OBS_VALUE','UPPER_BOUND')
  igme.ests.nmr$year <-  as.numeric(stringr::str_remove(row.names(igme.ests.nmr),'X')) - 0.5
  igme.ests.nmr <- igme.ests.nmr[igme.ests.nmr$year %in% 2000:2024,]
  rownames(igme.ests.nmr) <- NULL
  igme.ests.nmr$OBS_VALUE <- igme.ests.nmr$OBS_VALUE/1000
  igme.ests.nmr$LOWER_BOUND <- igme.ests.nmr$LOWER_BOUND/1000
  igme.ests.nmr$UPPER_BOUND <- igme.ests.nmr$UPPER_BOUND/1000
}

## load admin1 and admin2 weights ####
load(file.path(data.dir, "worldpop", "adm1_weights_u1.rda"))
load(file.path(data.dir, "worldpop", "adm1_weights_u5.rda"))
if(run_admin2_report){
  load(file.path(data.dir, "worldpop", "adm2_weights_u1.rda"))
  load(file.path(data.dir, "worldpop", "adm2_weights_u5.rda"))
}

## Load model data ####

if(strata.model=='unstrat'){
  load(file.path(data.dir, paste0(country, "_cluster_dat.rda")), envir = .GlobalEnv)
}else{
  load(file.path(data.dir, paste0(country, "_cluster_dat_1frame.rda")), envir = .GlobalEnv)
}

surveys <- unique(mod.dat$survey)
all_survey_file <- file.path(data.dir, paste0(country, "_cluster_dat.rda"))
if (file.exists(all_survey_file)) {
  all_survey_env <- new.env(parent = emptyenv())
  load(all_survey_file, envir = all_survey_env)
  if (!exists("mod.dat", envir = all_survey_env, inherits = FALSE) ||
      !"survey" %in% names(all_survey_env$mod.dat)) {
    stop("All-survey cluster data do not contain mod.dat$survey: ",
         all_survey_file, call. = FALSE)
  }
  end.year <- max(all_survey_env$mod.dat$survey)
} else {
  end.year <- max(mod.dat$survey)
}



plot.years <- 2000:end.proj.year
n_years <- length(plot.years)

if(((end.year-beg.year+1) %% 3) == 0){
  beg.period.years <- seq(beg.year,end.year,3) 
  end.period.years <- beg.period.years + 2 
}else if(((end.year-beg.year+1) %% 3)==1){
  beg.period.years <- c(beg.year,beg.year+2,seq(beg.year+4,end.year,3))
  end.period.years <- c(beg.year+1,beg.year+3,seq(beg.year+6,end.year,3))
}else if(((end.year-beg.year+1) %% 3)==2){
  beg.period.years <- c(beg.year,seq(beg.year+2,end.year,3))
  end.period.years <- c(beg.year+1,seq(beg.year+4,end.year,3))
}

period.years <- paste(beg.period.years, end.period.years, sep = "-")

if(end.year==end.proj.year){
  pane.years <- (end.period.years+beg.period.years)/2
}else{
  beg.proj.years <- seq(end.year+1,end.proj.year,3)
  end.proj.years <- beg.proj.years+2
  pane.years <- (c((end.period.years + beg.period.years)/2, (end.proj.years+beg.proj.years)/2))
  pane.years <- pane.years[pane.years<=end.proj.year]
}

## Load Polygon files ####
use_path_base(data.dir)

# load the national shape file
poly.adm0 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm0, options = "ENCODING=UTF-8")

# use encoding to read special characters
# load the shape file of admin-1 regions
poly.adm1 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm1, options = "ENCODING=UTF-8")
poly.adm1[[poly.label.adm1]] <- normalize_utf8_text(poly.adm1[[poly.label.adm1]])

if(run_admin2_report){
  # load the shape file of admin-2 regions
  poly.adm2 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm2, options = "ENCODING=UTF-8")
  poly.adm2[[poly.label.adm2]] <- normalize_utf8_text(poly.adm2[[poly.label.adm2]])
} 

# Set coordinate reference systems to be equal
if (exists("poly.adm2")) {
  st_crs(poly.adm1) <- st_crs(poly.adm2)
  st_crs(poly.adm0) <- st_crs(poly.adm2)
} else {
  st_crs(poly.adm0) <- st_crs(poly.adm1)
}


if (country == 'Malawi' && run_admin2_report) {
  poly.adm2 <- add_malawi_report_admin1(poly.adm2)
}

if (country == 'Pakistan') {
  poly.adm1 <- st_read(dsn = poly.path, layer = "georepo_PAK_1_excluding_disputed", options = "ENCODING=UTF-8")
  
  if (run_admin2_report) {
    poly.adm2 <- st_read(dsn = poly.path, layer = "georepo_PAK_2_excluding_disputed", options = "ENCODING=UTF-8")
  }
  
  if (exists("poly.adm2")) {
    # transform CRS to match if different
    if (st_crs(poly.adm1) != st_crs(poly.adm2)) {
      poly.adm1 <- st_transform(poly.adm1, crs = st_crs(poly.adm2))
    }
  }
}

if (run_admin2_report) {
  admin2.parent.display <- apply_report_admin_name_map(
    normalize_utf8_text(eval(str2lang(adm1_on_adm2))),
    report_name_map
  )
}

# Load Model Results ####
## National ####
{
  use_path_base(res.dir)
  
  ### Direct ####
  
  nmr.filename <- paste0(country, '_direct_natl_yearly_nmr.rda')
  
  if(nmr.filename %in% list.files("Direct/NMR/")){
    message("Loading natl NMR results from \n", nmr.filename, ".\n" )
  }else{
    warning("The national Direct NMR results specified don't exist.\n")
  }
  
  
  u5.filename <- paste0(country, '_direct_natl_yearly_u5.rda')
  
  if(u5.filename %in% list.files("Direct/U5MR/")){
    message("Loading natl U5MR results from \n", u5.filename, ".\n" )
    
  }else{
    warning("The national BB8 U5MR results specified don't exist.\n")
  }
  
  load(file = file.path("Direct", "NMR", nmr.filename))
  load(file = file.path("Direct", "U5MR", u5.filename))
  natl.dir.est.nmr <- direct.natl.yearly.nmr[direct.natl.yearly.nmr$years %in%
                                               beg.year:end.proj.year, "mean"]
  natl.dir.lower.nmr <- direct.natl.yearly.nmr[direct.natl.yearly.nmr$years %in% 
                                                 beg.year:end.proj.year, "lower"]
  natl.dir.upper.nmr <- direct.natl.yearly.nmr[direct.natl.yearly.nmr$years %in% 
                                                 beg.year:end.proj.year, "upper"]
  natl.dir.year.nmr <- direct.natl.yearly.nmr[direct.natl.yearly.nmr$years %in% 
                                                beg.year:end.proj.year, "years"]
  natl.dir.svy.nmr <- direct.natl.yearly.nmr[direct.natl.yearly.nmr$years %in%
                                               beg.year:end.proj.year, "surveyYears"]
  natl.dir.est.u5 <- direct.natl.yearly.u5[direct.natl.yearly.u5$years %in% 
                                             beg.year:end.proj.year, "mean"]
  natl.dir.lower.u5 <- direct.natl.yearly.u5[direct.natl.yearly.u5$years %in% 
                                               beg.year:end.proj.year, "lower"]
  natl.dir.upper.u5 <- direct.natl.yearly.u5[direct.natl.yearly.u5$years %in% 
                                               beg.year:end.proj.year, "upper"]
  natl.dir.year.u5 <- direct.natl.yearly.u5[direct.natl.yearly.u5$years %in%
                                              beg.year:end.proj.year, "years"]
  natl.dir.svy.u5 <- direct.natl.yearly.u5[direct.natl.yearly.u5$years %in%
                                             beg.year:end.proj.year, "surveyYears"]
  natl.dir.frame <- data.frame()
  natl.dir.frame <- data.frame(lower_nmr=natl.dir.lower.nmr, 
                               median_nmr=natl.dir.est.nmr,
                               upper_nmr=natl.dir.upper.nmr, 
                               lower_u5=natl.dir.lower.u5,
                               median_u5=natl.dir.est.u5, 
                               upper_u5=natl.dir.upper.u5, 
                               method='natl.dir.yearly',
                               years=natl.dir.year.u5,
                               surveyYears = natl.dir.svy.u5)
  
  ### SD yearly ####
  
  ## is time model in file string?
  nmr.filename <- paste0(country, '_res_natl_', sd.time.model,
                         '_yearly_nmr_SmoothedDirect.rda')
  
  if(nmr.filename %in% list.files("Direct/NMR/")){
    message("Loading natl NMR results from \n", nmr.filename, ".\n" )
  }else if(gsub(paste0(sd.time.model, "_"), "", nmr.filename) %in% 
           list.files("Direct/NMR/")){
    nmr.filename <- gsub(paste0(sd.time.model, "_"), "", nmr.filename)
    message("Loading natl NMR results from \n", nmr.filename, ".\n" )
  }else{
    message("The national Smoothed Direct MR results specified don't exist.\n")
  }
  
  
  u5.filename <- paste0(country, '_res_natl_', time.model,
                        '_yearly_u5_SmoothedDirect.rda')
  
  if(u5.filename %in% list.files("Direct/U5MR/")){
    message("Loading natl U5MR results from \n", u5.filename, ".\n" )
    
  }else if(gsub(paste0(sd.time.model, "_"), "", u5.filename) %in% 
           list.files("Direct/U5MR/")){
    u5.filename <- gsub(paste0(sd.time.model, "_"), "", u5.filename)
    message("Loading natl U5MR results from \n", u5.filename, ".\n" )
  }else{
    message("The national BB8 U5MR results specified don't exist.\n")
  }
  
  load(file = file.path("Direct", "NMR", nmr.filename))
  load(file = file.path("Direct", "U5MR", u5.filename))
  natl.sd.est.nmr <- res.natl.yearly.nmr[res.natl.yearly.nmr$years %in%
                                           beg.year:end.proj.year, "median"]
  natl.sd.lower.nmr <- res.natl.yearly.nmr[res.natl.yearly.nmr$years %in% 
                                             beg.year:end.proj.year, "lower"]
  natl.sd.upper.nmr <- res.natl.yearly.nmr[res.natl.yearly.nmr$years %in% 
                                             beg.year:end.proj.year, "upper"]
  natl.sd.year.nmr <- res.natl.yearly.nmr[res.natl.yearly.nmr$years %in% 
                                            beg.year:end.proj.year, "years"]
  
  natl.sd.est.u5 <- res.natl.yearly.u5[res.natl.yearly.u5$years %in% 
                                         beg.year:end.proj.year, "median"]
  natl.sd.lower.u5 <- res.natl.yearly.u5[res.natl.yearly.u5$years %in% 
                                           beg.year:end.proj.year, "lower"]
  natl.sd.upper.u5 <- res.natl.yearly.u5[res.natl.yearly.u5$years %in% 
                                           beg.year:end.proj.year, "upper"]
  natl.sd.year.u5 <- res.natl.yearly.u5[res.natl.yearly.u5$years %in%
                                          beg.year:end.proj.year, "years"]
  
  natl.sd.frame<-data.frame()
  natl.sd.frame<-data.frame(lower_nmr=natl.sd.lower.nmr, median_nmr=natl.sd.est.nmr,upper_nmr=natl.sd.upper.nmr, 
                            lower_u5=natl.sd.lower.u5, median_u5=natl.sd.est.u5, upper_u5=natl.sd.upper.u5, 
                            method='natl.sd.yearly', years=natl.sd.year.u5)
  
}

{
  #### BB8 ####
  nmr.filename <- paste0(country, '_res_natl_', time.model, 
                         "_", strata.model, "_nmr_allsurveys.rda")
  strata_str <- ifelse(strata.model == "unstrat", "unstratified", "stratified")
  
  if(nmr.filename %in% list.files("Betabinomial/NMR/")){
    message("Loading natl ", strata_str, " BB8 NMR results using all surveys ",
            "from \n", nmr.filename, ".\n" )
  }else if(gsub(paste0(time.model, "_"), "", nmr.filename) %in% 
           list.files("Betabinomial/NMR/")){
    nmr.filename <- gsub(paste0(time.model, "_"), "", nmr.filename)
    message("Loading natl ", strata_str, " BB8 NMR results using all surveys ",
            "from \n", nmr.filename, ".\n" )
  }else if(gsub("_allsurveys", "", nmr.filename) %in% 
           list.files("Betabinomial/NMR/")){
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
    message("Loading natl ", strata_str, " BB8 NMR results using surveys ",
            "from a single frame from \n", nmr.filename, ".\n" )
  }else if(paste0(country, '_res_natl_',
                  strata.model, "_nmr.rda") %in% 
           list.files("Betabinomial/NMR/")){
    
    nmr.filename <- gsub(paste0(time.model, "_"), "", nmr.filename)
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
    message("Loading natl ", strata_str, " BB8 NMR results using surveys ",
            "from a single frame from \n", nmr.filename, ".\n" )
  }else{
    message("The national BB8 NMR results specified don't exist.\n")
  }
  
  u5.filename <- paste0(country, '_res_natl_', time.model, 
                        "_", strata.model, "_u5_allsurveys.rda")
  strata_str <- ifelse(strata.model == "unstrat", "unstratified", "stratified")
  
  if(u5.filename %in% list.files("Betabinomial/U5MR/")){
    message("Loading natl ", strata_str, " BB8 U5MR results using all surveys ",
            "from \n", u5.filename, ".\n" )
  }else if(gsub(paste0(time.model, "_"), "", u5.filename) %in% 
           list.files("Betabinomial/U5MR/")){
    u5.filename <- gsub(paste0(time.model, "_"), "", u5.filename)
    message("Loading natl ", strata_str, " BB8 U5MR results using all surveys ",
            "from \n", u5.filename, ".\n" )
  }else if(gsub("_allsurveys", "", u5.filename) %in% 
           list.files("Betabinomial/U5MR/")){
    u5.filename <- gsub("_allsurveys", "", u5.filename)
    message("Loading natl ", strata_str, " BB8 U5MR results using surveys ",
            "from a single frame from \n", u5.filename, ".\n" )
  }else if(paste0(country, '_res_natl_',
                  strata.model, "_u5.rda") %in% 
           list.files("Betabinomial/U5MR/")){
    
    u5.filename <- gsub(paste0(time.model, "_"), "", u5.filename)
    u5.filename <- gsub("_allsurveys", "", u5.filename)
    message("Loading natl ", strata_str, " BB8 U5MR results using surveys ",
            "from a single frame from \n", u5.filename, ".\n" )
  }else{
    message("The national BB8 U5MR results specified don't exist.\n")
  }
  
  if(file.exists(file.path("Betabinomial", "NMR", nmr.filename))){
    load(file = file.path("Betabinomial", "NMR", nmr.filename))
  }
  if(file.exists(file.path("Betabinomial", "U5MR", u5.filename))){
    load(file = file.path("Betabinomial", "U5MR", u5.filename))
  }  
  
  if(exists('bb.res.natl.unstrat.nmr.allsurveys')){
    bb.res.natl.unstrat.nmr <- bb.res.natl.unstrat.nmr.allsurveys
  }
  if(exists('bb.res.natl.unstrat.u5.allsurveys')){
    bb.res.natl.unstrat.u5 <- bb.res.natl.unstrat.u5.allsurveys
  }
  
  if(exists('bb.res.natl.unstrat.nmr') & exists('bb.res.natl.unstrat.u5')){
    nmr.frame <- data.frame(lower_nmr = bb.res.natl.unstrat.nmr$overall$lower, 
                            median_nmr = bb.res.natl.unstrat.nmr$overall$median,
                            upper_nmr = bb.res.natl.unstrat.nmr$overall$upper,
                            years = bb.res.natl.unstrat.nmr$overall$years)
    u5.frame <- data.frame(lower_u5 = bb.res.natl.unstrat.u5$overall$lower,
                           median_u5 = bb.res.natl.unstrat.u5$overall$median, 
                           upper_u5 = bb.res.natl.unstrat.u5$overall$upper,
                           years = bb.res.natl.unstrat.u5$overall$years)
    natl.bb.unstrat.frame <- merge(nmr.frame, u5.frame, by = "years", all = TRUE)
    natl.bb.unstrat.frame$method <- 'natl.bb.unstrat'
    natl.bb.unstrat.frame <- natl.bb.unstrat.frame[
      order(as.numeric(paste0(natl.bb.unstrat.frame$years))),]
  }else if(exists('bb.res.natl.unstrat.nmr')){
    natl.bb.unstrat.frame <- 
      data.frame(lower_nmr = bb.res.natl.unstrat.nmr$overall$lower,
                 median_nmr = bb.res.natl.unstrat.nmr$overall$median,
                 upper_nmr = bb.res.natl.unstrat.nmr$overall$upper,
                 lower_u5 = NA, median_u5 = NA, upper_u5 = NA,
                 method='natl.bb.unstrat',years=bb.res.natl.unstrat.nmr$overall$years)
  }else if(exists('bb.res.natl.unstrat.u5')){
    natl.bb.unstrat.frame <- 
      data.frame(lower_nmr =NA, median_nmr = NA,
                 upper_nmr = NA,
                 lower_u5 = bb.res.natl.unstrat.u5$overall$lower,
                 median_u5 = bb.res.natl.unstrat.u5$overall$median, 
                 upper_u5 = bb.res.natl.unstrat.u5$overall$upper,
                 method='natl.bb.unstrat',
                 years=bb.res.natl.unstrat.u5$overall$years)
  }
  
  if(exists('bb.res.natl.strat.nmr') & exists('bb.res.natl.strat.u5')){
    nmr.frame <- data.frame(lower_nmr = bb.res.natl.strat.nmr$overall$lower,
                            median_nmr = bb.res.natl.strat.nmr$overall$median,
                            upper_nmr = bb.res.natl.strat.nmr$overall$upper,
                            years = bb.res.natl.strat.nmr$overall$years)
    u5.frame <- data.frame(lower_u5 = bb.res.natl.strat.u5$overall$lower,
                           median_u5 = bb.res.natl.strat.u5$overall$median,
                           upper_u5 = bb.res.natl.strat.u5$overall$upper,
                           years = bb.res.natl.strat.u5$overall$years)
    natl.bb.strat.frame <- merge(nmr.frame, u5.frame, by = "years", all = TRUE)
    natl.bb.strat.frame$method <- 'natl.bb.strat'
    natl.bb.strat.frame <- natl.bb.strat.frame[
      order(as.numeric(paste0(natl.bb.strat.frame$years))),]
  }else if(exists('bb.res.natl.strat.nmr')){
    natl.bb.strat.frame <- 
      data.frame(lower_nmr = bb.res.natl.strat.nmr$overall$lower,
                 median_nmr = bb.res.natl.strat.nmr$overall$median,
                 upper_nmr = bb.res.natl.strat.nmr$overall$upper,
                 lower_u5 = NA, median_u5 = NA, upper_u5 = NA,
                 method='natl.bb.strat',years=bb.res.natl.strat.nmr$overall$years)
  }else if(exists('bb.res.natl.strat.u5')){
    natl.bb.strat.frame <-
      data.frame(lower_nmr =NA, median_nmr = NA, upper_nmr = NA,
                 lower_u5 = bb.res.natl.strat.u5$overall$lower,
                 median_u5 = bb.res.natl.strat.u5$overall$median, 
                 upper_u5 = bb.res.natl.strat.u5$overall$upper,
                 method='natl.bb.strat',years=bb.res.natl.strat.u5$overall$years)
  }
  
}

## Admin-1 ####

{
  ### Direct ####
  nmr.filename <- paste0(country, '_direct_admin1_nmr.rda')
  
  if(nmr.filename %in% list.files("Direct/NMR/")){
    message("Loading natl NMR results from \n", nmr.filename, ".\n" )
  }else{
    message("The national Direct NMR results specified don't exist.\n")
  }
  
  
  u5.filename <- paste0(country, '_direct_admin1_u5.rda')
  
  if(u5.filename %in% list.files("Direct/U5MR/")){
    message("Loading natl U5MR results from \n", u5.filename, ".\n" )
    
  }else{
    message("The national BB8 U5MR results specified don't exist.\n")
  }
  
  load(file = file.path("Direct", "NMR", nmr.filename))
  load(file = file.path("Direct", "U5MR", u5.filename))
  adm1.dir.reg.nmr <- direct.admin1.nmr[direct.admin1.nmr$years %in%
                                          period.years, "region"]
  adm1.dir.reg.u5 <- direct.admin1.u5[direct.admin1.u5$years %in%
                                        period.years, "region"]
  adm1.dir.est.nmr <- direct.admin1.nmr[direct.admin1.nmr$years %in%
                                          period.years, "mean"]
  adm1.dir.lower.nmr <- direct.admin1.nmr[direct.admin1.nmr$years %in% 
                                            period.years, "lower"]
  adm1.dir.upper.nmr <- direct.admin1.nmr[direct.admin1.nmr$years %in% 
                                            period.years, "upper"]
  adm1.dir.year.nmr <- direct.admin1.nmr[direct.admin1.nmr$years %in% 
                                           period.years, "years"]
  adm1.dir.svy.nmr <- direct.admin1.nmr[direct.admin1.nmr$years %in%
                                          period.years, "surveyYears"]
  adm1.dir.est.u5 <- direct.admin1.u5[direct.admin1.u5$years %in% 
                                        period.years, "mean"]
  adm1.dir.lower.u5 <- direct.admin1.u5[direct.admin1.u5$years %in% 
                                          period.years, "lower"]
  adm1.dir.upper.u5 <- direct.admin1.u5[direct.admin1.u5$years %in% 
                                          period.years, "upper"]
  adm1.dir.year.u5 <- direct.admin1.u5[direct.admin1.u5$years %in%
                                         period.years, "years"]
  adm1.dir.svy.u5 <- direct.admin1.u5[direct.admin1.u5$years %in%
                                        period.years, "surveyYears"]
  adm1.dir.frame.nmr <- data.frame(region = adm1.dir.reg.nmr,
                                   lower_nmr=adm1.dir.lower.nmr, 
                                   median_nmr=adm1.dir.est.nmr,
                                   upper_nmr=adm1.dir.upper.nmr, 
                                   method='adm1.dir',
                                   years=adm1.dir.year.nmr,
                                   surveyYears = adm1.dir.svy.nmr)
  adm1.dir.frame.u5 <- data.frame(region = adm1.dir.reg.u5,
                                  lower_u5=adm1.dir.lower.u5,
                                  median_u5=adm1.dir.est.u5, 
                                  upper_u5=adm1.dir.upper.u5, 
                                  method='adm1.dir',
                                  years=adm1.dir.year.u5,
                                  surveyYears = adm1.dir.svy.u5)
  
  adm1.dir.frame <- adm1.dir.frame.nmr %>% 
    full_join(data.frame(region = admin1.names$Internal),
              by = "region") %>% 
    full_join(adm1.dir.frame.u5,
              by = c("region", "method", "years", "surveyYears"))
  
  ## SD 3-year ####
  nmr.filename <- paste0(country, '_res_admin1_', sd.time.model,
                         '_nmr_SmoothedDirect.rda')
  
  if(nmr.filename %in% list.files("Direct/NMR/")){
    message("Loading Admin-1 NMR results from \n", nmr.filename, ".\n" )
  }else if(gsub(paste0(sd.time.model, "_"), "", nmr.filename) %in% 
           list.files("Direct/NMR/")){
    nmr.filename <- gsub(paste0(sd.time.model, "_"), "", nmr.filename)
    message("Loading Admin-1NMR results from \n", nmr.filename, ".\n" )
  }else{
    message("The Admin-1 Smoothed Direct NMR results specified don't exist.\n")
  }
  
  u5.filename <- paste0(country, '_res_admin1_', time.model, 
                        "_u5_SmoothedDirect.rda")
  
  if(u5.filename %in% list.files("Direct/U5MR/")){
    message("Loading Admin 1 U5MR results from \n", u5.filename, ".\n" )
  }else if(gsub(paste0(sd.time.model, "_"), "", u5.filename) %in% 
           list.files("Direct/U5MR/")){
    u5.filename <- gsub(paste0(sd.time.model, "_"), "", u5.filename)
    message("Loading Admin1 U5MR results from \n", u5.filename, ".\n" )
  }else{
    message("The Admin 1 Smoothed Direct U5MR results specified don't exist.\n")
  }
  
  load(file = file.path("Direct", "NMR", nmr.filename))
  admin1.sd.nmr <- res.admin1.nmr
  load(file = file.path("Direct", "U5MR", u5.filename))
  admin1.sd.u5 <- res.admin1.u5
}
{
  ### SD yearly ####
  nmr.filename <- paste0(country, '_res_admin1_', sd.time.model,
                         '_nmr_SmoothedDirect_yearly.rda')
  
  if(nmr.filename %in% list.files("Direct/NMR/")){
    message("Loading yearly Admin-1 NMR results from \n", nmr.filename, ".\n" )
  }else if(gsub(paste0(sd.time.model, "_"), "", nmr.filename) %in% 
           list.files("Direct/NMR/")){
    nmr.filename <- gsub(paste0(sd.time.model, "_"), "", nmr.filename)
    message("Loading yearly Admin-1NMR results from \n", nmr.filename, ".\n" )
  }else{
    message("The yearly Admin-1 Smoothed Direct NMR results specified don't exist.\n")
  }
  
  u5.filename <- paste0(country, '_res_admin1_', time.model, 
                        "_u5_SmoothedDirect_yearly.rda")
  
  if(u5.filename %in% list.files("Direct/U5MR/")){
    message("Loading yearly Admin 1 U5MR results from \n", u5.filename, ".\n" )
  }else if(gsub(paste0(sd.time.model, "_"), "", u5.filename) %in% 
           list.files("Direct/U5MR/")){
    u5.filename <- gsub(paste0(sd.time.model, "_"), "", u5.filename)
    message("Loading yearly Admin1 U5MR results from \n", u5.filename, ".\n" )
  }else{
    message("The yearly Admin 1 Smoothed Direct U5MR results specified don't exist.\n")
  }
  
  if(file.exists(file.path("Direct", "NMR", nmr.filename))){
    load(file = file.path("Direct", "NMR", nmr.filename))
    admin1.sd.yearly.nmr <- sd.admin1.yearly.nmr
  }
  if(file.exists(file.path("Direct", "U5MR", u5.filename))){
    load(file = file.path("Direct", "U5MR", u5.filename))
    admin1.sd.yearly.u5 <- sd.admin1.yearly.u5
  }
}

{
  ### BB8 #####
  
  ## NMR File name
  if(bench.model == ""){
    nmr.filename <- paste0(country, '_res_adm1_', time.model, 
                           "_", strata.model, "_nmr_allsurveys.rda")
  }else{
    nmr.filename <- paste0(country, '_res_adm1_', time.model, 
                           "_", strata.model, "_nmr_allsurveys_bench.rda")
  }
  
  if(strata.model == "strat"){
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
  }
  
  strata_str <- ifelse(strata.model == "unstrat", "unstratified", "stratified")
  bench_str <- ifelse(bench.model == "bench", "benchmarked", "unbenchmarked")
  
  if(nmr.filename %in% list.files("Betabinomial/NMR/")){
    message("Loading Admin-1 ", bench_str, " ",
            strata_str, " BB8 NMR results using all surveys ",
            "from \n", nmr.filename, ".\n" )
  }else if(gsub(paste0(time.model, "_"), "", nmr.filename) %in% 
           list.files("Betabinomial/NMR/")){
    nmr.filename <- gsub(paste0(time.model, "_"), "", nmr.filename)
    message("Loading Admin-1 ", bench_str, " ", strata_str, 
            " BB8 NMR results using all surveys ",
            "from \n", nmr.filename, ".\n" )
  }else if(gsub("_allsurveys", "", nmr.filename) %in% 
           list.files("Betabinomial/NMR/")){
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
    message("Loading Admin-1 ", bench_str, " ",
            strata_str, " BB8 NMR results using surveys ",
            "from a single frame from \n", nmr.filename, ".\n" )
  }else if(bench.model == "bench" & (paste0(country, '_res_adm1_',
                                            strata.model, "_nmr_bench.rda") %in% 
                                     list.files("Betabinomial/NMR/"))){
    
    nmr.filename <- gsub(paste0(time.model, "_"), "", nmr.filename)
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
    message("Loading Admin-1", bench_str, " ", strata_str, 
            " BB8 NMR results using surveys ",
            "from a single frame from \n", nmr.filename, ".\n" )
  }else if(bench.model == "" & (paste0(country, '_res_adm1_',
                                       strata.model, "_nmr.rda") %in% 
                                list.files("Betabinomial/NMR/"))){
    
    nmr.filename <- gsub(paste0(time.model, "_"), "", nmr.filename)
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
    message("Loading Admin-1", bench_str, " ", strata_str, 
            " BB8 NMR results using surveys ",
            "from a single frame from \n", nmr.filename, ".\n" )
  }else{
    message("The Admin-1 BB8 NMR results specified don't exist.\n")
  }
  
  ## U5MR file name
  if(bench.model == ""){
    u5.filename <- paste0(country, '_res_adm1_', time.model, 
                          "_", strata.model, "_u5_allsurveys.rda")
  }else{
    u5.filename <- paste0(country, '_res_adm1_', time.model, 
                          "_", strata.model, "_u5_allsurveys_bench.rda")
  }
  
  if(strata.model == "strat"){
    u5.filename <- gsub("_allsurveys", "", u5.filename)
  }
  strata_str <- ifelse(strata.model == "unstrat", "unstratified", "stratified")
  bench_str <- ifelse(bench.model == "bench", "benchmarked", "unbenchmarked")
  
  if(u5.filename %in% list.files("Betabinomial/U5MR/")){
    message("Loading Admin-1 ", bench_str, " ",
            strata_str, " BB8 U5MR results using all surveys ",
            "from \n", u5.filename, ".\n" )
  }else if(gsub(paste0(time.model, "_"), "", u5.filename) %in% 
           list.files("Betabinomial/U5MR/")){
    u5.filename <- gsub(paste0(time.model, "_"), "", u5.filename)
    message("Loading Admin-1 ", bench_str, " ", strata_str, 
            " BB8 U5MR results using all surveys ",
            "from \n", u5.filename, ".\n" )
  }else if(gsub("_allsurveys", "", u5.filename) %in% 
           list.files("Betabinomial/U5MR/")){
    u5.filename <- gsub("_allsurveys", "", u5.filename)
    message("Loading Admin-1 ", bench_str, " ",
            strata_str, " BB8 U5MR results using surveys ",
            "from a single frame from \n", u5.filename, ".\n" )
  }else if(bench.model == "bench" &
           (paste0(country, '_res_adm1_',
                   strata.model, "_u5_bench.rda") %in% 
            list.files("Betabinomial/U5MR/"))){
    
    u5.filename <- gsub(paste0(time.model, "_"), "", u5.filename)
    u5.filename <- gsub("_allsurveys", "", u5.filename)
    message("Loading Admin-1", bench_str, " ", strata_str, 
            " BB8 U5MR results using surveys ",
            "from a single frame from \n", u5.filename, ".\n" )
  }else if(bench.model == "" & (paste0(country, '_res_adm1_',
                                       strata.model, "_u5.rda") %in% 
                                list.files("Betabinomial/U5MR/"))){
    
    u5.filename <- gsub(paste0(time.model, "_"), "", u5.filename)
    u5.filename <- gsub("_allsurveys", "", u5.filename)
    message("Loading Admin-1", bench_str, " ", strata_str, 
            " BB8 U5MR results using surveys ",
            "from a single frame from \n", u5.filename, ".\n" )
  }else{
    message("The Admin-1 BB8 U5MR results specified don't exist.\n")
  }
  
  # Select crisis-adjusted U5MR only when enabled in the country Info JSON.
  u5.path.selected <- select_crisis_result_file(file.path(
    res.dir, "Betabinomial", "U5MR", u5.filename
  ))
  u5.filename <- basename(u5.path.selected)
  if(grepl("_crisis[.]rda$", u5.filename)){
    message("Loading crisis-adjusted estimates from above model")
  }
  
  if(strata.model == "unstrat"){
    load(file = file.path("Betabinomial", "NMR", nmr.filename))
    load(file = file.path("Betabinomial", "U5MR", u5.filename))
    
    ##Load benchmarks
    nmr.bench.file <- gsub(paste0(country, "_res_"), "", 
                           nmr.filename)
    nmr.bench.file <- gsub("_allsurveys", "", nmr.bench.file)
    nmr.bench.file <- gsub("_bench", "_benchmarks", nmr.bench.file)
    
    u5.bench.file <- gsub(paste0(country, "_res_"), "", u5.filename)
    u5.bench.file <- gsub("_crisis", "", u5.bench.file)
    u5.bench.file <- gsub("_allsurveys", "", u5.bench.file)
    u5.bench.file <- gsub("_bench", "_benchmarks", u5.bench.file)
    
    load(file = file.path("Betabinomial", "NMR", nmr.bench.file))
    adm1.nmr.benchmarks <- bench.adj
    load(file = file.path("Betabinomial", "U5MR", u5.bench.file))
    adm1.u5.benchmarks <- bench.adj
    
    
    if(exists('bb.res.adm1.unstrat.nmr.allsurveys')){
      bb.res.adm1.unstrat.nmr <- bb.res.adm1.unstrat.nmr.allsurveys
    }
    if(exists('bb.res.adm1.unstrat.u5.allsurveys')){
      bb.res.adm1.unstrat.u5 <- bb.res.adm1.unstrat.u5.allsurveys
    }
    if(exists('bb.res.adm1.unstrat.nmr.allsurveys.bench')){
      bb.res.adm1.unstrat.nmr.bench <- bb.res.adm1.unstrat.nmr.allsurveys.bench
    }
    if(exists('bb.res.adm1.unstrat.u5.allsurveys.bench')){
      bb.res.adm1.unstrat.u5.bench <- bb.res.adm1.unstrat.u5.allsurveys.bench
    }
    
    if(bench.model == ""){
      admin1.unstrat.nmr.BB8 <- bb.res.adm1.unstrat.nmr$overall
      admin1.unstrat.u5.BB8 <- bb.res.adm1.unstrat.u5$overall
    }else{
      admin1.unstrat.nmr.BB8.bench <-  bb.res.adm1.unstrat.nmr.bench$overall
      if(grepl('crisis',u5.filename)){
        admin1.unstrat.u5.BB8.bench <- res_adm1_u5_crisis
      }else{
        admin1.unstrat.u5.BB8.bench <- bb.res.adm1.unstrat.u5.bench$overall
      }
    }
    
    
  }else{
    
    load(file = file.path("Betabinomial", "NMR", nmr.filename))
    load(file = file.path("Betabinomial", "U5MR", u5.filename))
    
    ##Load benchmarks
    if(bench.model=='bench'){
      nmr.bench.file <- gsub(paste0(country, "_res_"), "", 
                             nmr.filename)
      nmr.bench.file <- gsub("_allsurveys", "", nmr.bench.file)
      nmr.bench.file <- gsub("_bench", "_benchmarks", nmr.bench.file)
      
      u5.bench.file <- gsub(paste0(country, "_res_"), "", 
                            u5.filename)
      u5.bench.file <- gsub("_crisis", "", u5.bench.file)
      u5.bench.file <- gsub("_allsurveys", "", u5.bench.file)
      u5.bench.file <- gsub("_bench", "_benchmarks", u5.bench.file)
      
      if(file.exists(file.path("Betabinomial", "NMR", nmr.bench.file))){
        load(file = file.path("Betabinomial", "NMR", nmr.bench.file))
      }else if(file.exists(file.path("Betabinomial", "NMR",
                                     gsub(paste0("_", time.model),
                                          "", nmr.bench.file)))){
        load(file = file.path("Betabinomial", "NMR",
                              gsub(paste0("_", time.model),
                                   "", nmr.bench.file)))
      }else{
        message("Benchmarks file does not exist.\n")
      }
      adm1.nmr.benchmarks <- bench.adj
      
      if(file.exists(file.path("Betabinomial", "U5MR", u5.bench.file))){
        load(file = file.path("Betabinomial", "U5MR", u5.bench.file))
      }else if(file.exists(file.path("Betabinomial", "U5MR",
                                     gsub(paste0("_", time.model),
                                          "", u5.bench.file)))){
        load(file = file.path("Betabinomial", "U5MR",
                              gsub(paste0("_", time.model),
                                   "", u5.bench.file)))
      }else{
        message("Benchmarks file does not exist.\n")
      }
      adm1.u5.benchmarks <- bench.adj 
      
      if(bench.model == ""){
        admin1.strat.nmr.BB8 <- bb.res.adm1.strat.nmr$overall
        admin1.strat.u5.BB8 <- bb.res.adm1.strat.u5$overall
      }else{
        admin1.strat.nmr.BB8.bench <-  bb.res.adm1.strat.nmr.bench$overall
        if(grepl('crisis',u5.filename)){
          admin1.strat.u5.BB8.bench <- res_adm1_u5_crisis
        }else{
          admin1.strat.u5.BB8.bench <- bb.res.adm1.strat.u5.bench$overall
        }
      }
    }  
  }
}

## Admin-2#####
if(run_admin2_report){
  ### Direct ####
  
  ## is time model in file string?
  nmr.filename <- paste0(country, '_direct_admin2_nmr.rda')
  
  if(nmr.filename %in% list.files("Direct/NMR/")){
    message("Loading 3-year Admin-2 NMR direct estimates from \n", 
            nmr.filename, ".\n" )
  }else{
    message("The 3-year Admin-2 NMR direct estimates specified don't exist.\n")
  }
  
  
  u5.filename <- paste0(country, '_direct_admin2_u5.rda')
  
  if(u5.filename %in% list.files("Direct/U5MR/")){
    message("Loading 3-year Admin-2 U5MR direct estimates from \n", 
            u5.filename, ".\n" )
  }else{
    message("The 3-year Admin-2 U5MR direct estimates specified don't exist.\n")
  }
  
  load(file = file.path("Direct", "NMR", nmr.filename))
  load(file = file.path("Direct", "U5MR", u5.filename))
  adm2.dir.reg.nmr <- direct.admin2.nmr[direct.admin2.nmr$years %in%
                                          period.years, "region"]
  adm2.dir.reg.u5 <- direct.admin2.u5[direct.admin2.u5$years %in%
                                        period.years, "region"]
  adm2.dir.est.nmr <- direct.admin2.nmr[direct.admin2.nmr$years %in%
                                          period.years, "mean"]
  adm2.dir.lower.nmr <- direct.admin2.nmr[direct.admin2.nmr$years %in% 
                                            period.years, "lower"]
  adm2.dir.upper.nmr <- direct.admin2.nmr[direct.admin2.nmr$years %in% 
                                            period.years, "upper"]
  adm2.dir.year.nmr <- direct.admin2.nmr[direct.admin2.nmr$years %in% 
                                           period.years, "years"]
  adm2.dir.svy.nmr <- direct.admin2.nmr[direct.admin2.nmr$years %in%
                                          period.years, "surveyYears"]
  adm2.dir.est.u5 <- direct.admin2.u5[direct.admin2.u5$years %in% 
                                        period.years, "mean"]
  adm2.dir.lower.u5 <- direct.admin2.u5[direct.admin2.u5$years %in% 
                                          period.years, "lower"]
  adm2.dir.upper.u5 <- direct.admin2.u5[direct.admin2.u5$years %in% 
                                          period.years, "upper"]
  adm2.dir.year.u5 <- direct.admin2.u5[direct.admin2.u5$years %in%
                                         period.years, "years"]
  adm2.dir.svy.u5 <- direct.admin2.u5[direct.admin2.u5$years %in%
                                        period.years, "surveyYears"]
  adm2.dir.nmr.frame <- data.frame(region = adm2.dir.reg.nmr,
                                   lower_nmr=adm2.dir.lower.nmr, 
                                   median_nmr=adm2.dir.est.nmr,
                                   upper_nmr=adm2.dir.upper.nmr,
                                   method='adm2.dir',
                                   years=adm2.dir.year.nmr,
                                   surveyYears = adm2.dir.svy.nmr)
  adm2.dir.u5.frame <- data.frame(region = adm2.dir.reg.u5, 
                                  lower_u5=adm2.dir.lower.u5,
                                  median_u5=adm2.dir.est.u5, 
                                  upper_u5=adm2.dir.upper.u5, 
                                  method='adm2.dir',
                                  years=adm2.dir.year.u5,
                                  surveyYears = adm2.dir.svy.u5)
  adm2.dir.frame <-  adm2.dir.nmr.frame %>% 
    full_join(data.frame(region = admin2.names$Internal),
              by = "region") %>% 
    full_join(adm2.dir.u5.frame,
              by = c("region", "method", "years", "surveyYears"))
  
  
  
  ## SD 3-year ####
  {
    nmr.filename <- paste0(country, '_res_admin2_', sd.time.model,
                           '_nmr_SmoothedDirect.rda')
    
    if(nmr.filename %in% list.files("Direct/NMR/")){
      message("Loading Admin-2 NMR results from \n", nmr.filename, ".\n" )
      load(file = file.path("Direct", "NMR", nmr.filename))
      admin2.sd.nmr <- res.admin2.nmr
    }else if(gsub(paste0(sd.time.model, "_"), "", nmr.filename) %in% 
             list.files("Direct/NMR/")){
      nmr.filename <- gsub(paste0(sd.time.model, "_"), "", nmr.filename)
      message("Loading Admin-2 NMR results from \n", nmr.filename, ".\n" )
      load(file = file.path("Direct", "NMR", nmr.filename))
      admin2.sd.nmr <- res.admin2.nmr
    }else{
      message("The Admin-2 Smoothed Direct NMR results specified don't exist.\n")
    }
    
    u5.filename <- paste0(country, '_res_admin2_', time.model, 
                          "_u5_SmoothedDirect.rda")
    
    if(u5.filename %in% list.files("Direct/U5MR/")){
      message("Loading Admin 2 U5MR results from \n", u5.filename, ".\n" )
      
      load(file = file.path("Direct", "U5MR", u5.filename))
      admin2.sd.u5 <- res.admin2.u5
    }else if(gsub(paste0(sd.time.model, "_"), "", u5.filename) %in% 
             list.files("Direct/U5MR/")){
      u5.filename <- gsub(paste0(sd.time.model, "_"), "", u5.filename)
      message("Loading Admin2 U5MR results from \n", u5.filename, ".\n" )
      load(file = file.path("Direct", "U5MR", u5.filename))
      admin2.sd.u5 <- res.admin2.u5
    }else{
      message("The Admin 2 Smoothed Direct U5MR results specified don't exist.\n")
    }
  }
  ## SD yearly ####
  
  nmr.filename <- paste0(country, '_res_admin2_', sd.time.model,
                         '_nmr_SmoothedDirect_yearly.rda')
  
  if(nmr.filename %in% list.files("Direct/NMR/")){
    message("Loading yearly Admin-2 NMR results from \n", nmr.filename, ".\n" )
    load(file = file.path("Direct", "NMR", nmr.filename))
    admin2.sd.yearly.nmr <- sd.admin2.yearly.nmr
  }else if(gsub(paste0(sd.time.model, "_"), "", nmr.filename) %in% 
           list.files("Direct/NMR/")){
    nmr.filename <- gsub(paste0(sd.time.model, "_"), "", nmr.filename)
    message("Loading yearly Admin-1NMR results from \n", nmr.filename, ".\n" )
    load(file = file.path("Direct", "NMR", nmr.filename))
    admin2.sd.yearly.nmr <- sd.admin2.yearly.nmr
  }else{
    message("The yearly Admin-2 Smoothed Direct NMR results specified don't exist.\n")
  }
  
  u5.filename <- paste0(country, '_res_admin2_', time.model, 
                        "_u5_SmoothedDirect_yearly.rda")
  
  if(u5.filename %in% list.files("Direct/U5MR/")){
    message("Loading yearly Admin-2 U5MR results from \n", u5.filename, ".\n" )
    
    load(file = file.path("Direct", "U5MR", u5.filename))
    admin2.sd.yearly.u5 <- sd.admin2.yearly.u5
  }else if(gsub(paste0(sd.time.model, "_"), "", u5.filename) %in% 
           list.files("Direct/U5MR/")){
    u5.filename <- gsub(paste0(sd.time.model, "_"), "", u5.filename)
    message("Loading yearly Admin-2 U5MR results from \n", u5.filename, ".\n" )
    
    load(file = file.path("Direct", "U5MR", u5.filename))
    admin2.sd.yearly.u5 <- sd.admin2.yearly.u5
  }else{
    message("The yearly Admin 2 Smoothed Direct U5MR results specified don't exist.\n")
  }
  
  ## BB8 ####
  
  if(bench.model == ""){
    nmr.filename <- paste0(country, '_res_adm2_', time.model, 
                           "_", strata.model, "_nmr_allsurveys.rda")
  }else{
    nmr.filename <- paste0(country, '_res_adm2_', time.model, 
                           "_", strata.model, "_nmr_allsurveys_bench.rda")
  }
  
  if(strata.model == "strat"){
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
  }
  strata_str <- ifelse(strata.model == "unstrat", "unstratified", "stratified")
  bench_str <- ifelse(bench.model == "bench", "benchmarked", "unbenchmarked")
  
  if(nmr.filename %in% list.files("Betabinomial/NMR/")){
    message("Loading Admin-2 ", bench_str, " ",
            strata_str, " BB8 NMR results using all surveys ",
            "from \n", nmr.filename, ".\n" )
  }else if(gsub(paste0(time.model, "_"), "", nmr.filename) %in% 
           list.files("Betabinomial/NMR/")){
    nmr.filename <- gsub(paste0(time.model, "_"), "", nmr.filename)
    message("Loading Admin-2 ", bench_str, " ", strata_str, 
            " BB8 NMR results using all surveys ",
            "from \n", nmr.filename, ".\n" )
  }else if(gsub("_allsurveys", "", nmr.filename) %in% 
           list.files("Betabinomial/NMR/")){
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
    message("Loading Admin-2 ", bench_str, " ",
            strata_str, " BB8 NMR results using surveys ",
            "from a single frame from \n", nmr.filename, ".\n" )
  }else if(bench.model == "bench" & (paste0(country, '_res_adm2_',
                                            strata.model, "_nmr_bench.rda") %in% 
                                     list.files("Betabinomial/NMR/"))){
    
    nmr.filename <- gsub(paste0(time.model, "_"), "", nmr.filename)
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
    message("Loading Admin-2", bench_str, " ", strata_str, 
            " BB8 NMR results using surveys ",
            "from a single frame from \n", nmr.filename, ".\n" )
  }else if(bench.model == "" & (paste0(country, '_res_adm2_',
                                       strata.model, "_nmr.rda") %in% 
                                list.files("Betabinomial/NMR/"))){
    
    nmr.filename <- gsub(paste0(time.model, "_"), "", nmr.filename)
    nmr.filename <- gsub("_allsurveys", "", nmr.filename)
    message("Loading Admin-2", bench_str, " ", strata_str, 
            " BB8 NMR results using surveys ",
            "from a single frame from \n", nmr.filename, ".\n" )
  }else{
    message("The Admin-2 BB8 NMR results specified don't exist.\n")
  }
  
  if(bench.model == ""){
    u5.filename <- paste0(country, '_res_adm2_', time.model, 
                          "_", strata.model, "_u5_allsurveys.rda")
  }else{
    u5.filename <- paste0(country, '_res_adm2_', time.model, 
                          "_", strata.model, "_u5_allsurveys_bench.rda")
  }
  
  if(strata.model == "strat"){
    u5.filename <- gsub("_allsurveys", "", u5.filename)
  }
  strata_str <- ifelse(strata.model == "unstrat", "unstratified", "stratified")
  bench_str <- ifelse(bench.model == "bench", "benchmarked", "unbenchmarked")
  
  if(u5.filename %in% list.files("Betabinomial/U5MR/")){
    message("Loading Admin-2 ", bench_str, " ",
            strata_str, " BB8 U5MR results using all surveys ",
            "from \n", u5.filename, ".\n" )
  }else if(gsub(paste0(time.model, "_"), "", u5.filename) %in% 
           list.files("Betabinomial/U5MR/")){
    u5.filename <- gsub(paste0(time.model, "_"), "", u5.filename)
    message("Loading Admin-2 ", bench_str, " ", strata_str, 
            " BB8 U5MR results using all surveys ",
            "from \n", u5.filename, ".\n" )
  }else if(gsub("_allsurveys", "", u5.filename) %in% 
           list.files("Betabinomial/U5MR/")){
    u5.filename <- gsub("_allsurveys", "", u5.filename)
    message("Loading Admin-2 ", bench_str, " ",
            strata_str, " BB8 U5MR results using surveys ",
            "from a single frame from \n", u5.filename, ".\n" )
  }else if(bench.model == "bench" &
           (paste0(country, '_res_adm2_',
                   strata.model, "_u5_bench.rda") %in% 
            list.files("Betabinomial/U5MR/"))){
    
    u5.filename <- gsub(paste0(time.model, "_"), "", u5.filename)
    u5.filename <- gsub("_allsurveys", "", u5.filename)
    message("Loading Admin-2", bench_str, " ", strata_str, 
            " BB8 U5MR results using surveys ",
            "from a single frame from \n", u5.filename, ".\n" )
  }else if(bench.model == "" & (paste0(country, '_res_adm2_',
                                       strata.model, "_u5.rda") %in% 
                                list.files("Betabinomial/U5MR/"))){
    
    u5.filename <- gsub(paste0(time.model, "_"), "", u5.filename)
    u5.filename <- gsub("_allsurveys", "", u5.filename)
    message("Loading Admin-2", bench_str, " ", strata_str, 
            " BB8 U5MR results using surveys ",
            "from a single frame from \n", u5.filename, ".\n" )
  }else{
    message("The Admin-2 BB8 U5MR results specified don't exist.\n")
  }
  
  # Select crisis-adjusted U5MR only when enabled in the country Info JSON.
  u5.path.selected <- select_crisis_result_file(file.path(
    res.dir, "Betabinomial", "U5MR", u5.filename
  ))
  u5.filename <- basename(u5.path.selected)
  if(grepl("_crisis[.]rda$", u5.filename)){
    message("Loading crisis-adjusted estimates from above model")
  }
  
  if(strata.model == "unstrat"){
    load(file = file.path("Betabinomial", "NMR", nmr.filename))
    load(file = file.path("Betabinomial", "U5MR", u5.filename))
    
    ##Load benchmarks
    if(bench.model=='bench'){
      nmr.bench.file <- gsub(paste0(country, "_res_"), "", 
                             nmr.filename)
      nmr.bench.file <- gsub("_allsurveys", "", nmr.bench.file)
      nmr.bench.file <- gsub("_bench", "_benchmarks", nmr.bench.file)
      
      u5.bench.file <- gsub(paste0(country, "_res_"), "", 
                            u5.filename)
      u5.bench.file <- gsub("_crisis", "", u5.bench.file)
      u5.bench.file <- gsub("_allsurveys", "", u5.bench.file)
      u5.bench.file <- gsub("_bench", "_benchmarks", u5.bench.file)
      
      
      if(file.exists(file.path("Betabinomial", "NMR", nmr.bench.file))){
        load(file = file.path("Betabinomial", "NMR", nmr.bench.file))
      }else if(file.exists(file.path("Betabinomial", "NMR",
                                     gsub(paste0("_", time.model),
                                          "", nmr.bench.file)))){
        load(file = file.path("Betabinomial", "NMR",
                              gsub(paste0("_", time.model),
                                   "", nmr.bench.file)))
      }else{
        message("Benchmarks file does not exist.\n")
      }
      adm2.nmr.benchmarks <- bench.adj
      
      
      if(file.exists(file.path("Betabinomial", "U5MR", u5.bench.file))){
        load(file = file.path("Betabinomial", "U5MR", u5.bench.file))
      }else if(file.exists(file.path("Betabinomial", "U5MR",
                                     gsub(paste0("_", time.model),
                                          "", u5.bench.file)))){
        load(file = file.path("Betabinomial", "U5MR",
                              gsub(paste0("_", time.model),
                                   "", u5.bench.file)))
      }else{
        message("Benchmarks file does not exist.\n")
      }
      adm2.u5.benchmarks <- bench.adj
    }
    
    if(exists('bb.res.adm2.unstrat.nmr.allsurveys')){
      bb.res.adm2.unstrat.nmr <- bb.res.adm2.unstrat.nmr.allsurveys
    }
    if(exists('bb.res.adm2.unstrat.u5.allsurveys')){
      bb.res.adm2.unstrat.u5 <- bb.res.adm2.unstrat.u5.allsurveys
    }
    if(exists('bb.res.adm2.unstrat.nmr.allsurveys.bench')){
      bb.res.adm2.unstrat.nmr.bench <- bb.res.adm2.unstrat.nmr.allsurveys.bench
    }
    if(exists('bb.res.adm2.unstrat.u5.allsurveys.bench')){
      bb.res.adm2.unstrat.u5.bench <- bb.res.adm2.unstrat.u5.allsurveys.bench
    }
    
    if(bench.model == ""){
      admin2.unstrat.nmr.BB8 <- bb.res.adm2.unstrat.nmr$overall
      admin2.unstrat.u5.BB8 <- bb.res.adm2.unstrat.u5$overall
    }else{
      admin2.unstrat.nmr.BB8.bench <-  bb.res.adm2.unstrat.nmr.bench$overall
      if(grepl('crisis',u5.filename)){
        admin2.unstrat.u5.BB8.bench <- res_adm2_u5_crisis
      }else{
        admin2.unstrat.u5.BB8.bench <- bb.res.adm2.unstrat.u5.bench$overall
      }
    }
    
  }else{
    load(file = file.path("Betabinomial", "NMR", nmr.filename))
    load(file = file.path("Betabinomial", "U5MR", u5.filename))
    
    ##Load benchmarks
    if(bench.model=='bench'){
      nmr.bench.file <- gsub(paste0(country, "_res_"), "", 
                             nmr.filename)
      nmr.bench.file <- gsub("_allsurveys", "", nmr.bench.file)
      nmr.bench.file <- gsub("_bench", "_benchmarks", nmr.bench.file)
      
      u5.bench.file <- gsub(paste0(country, "_res_"), "", 
                            u5.filename)
      u5.bench.file <- gsub("_crisis", "", u5.bench.file)
      u5.bench.file <- gsub("_allsurveys", "", u5.bench.file)
      u5.bench.file <- gsub("_bench", "_benchmarks", u5.bench.file)
      
      if(file.exists(file.path("Betabinomial", "NMR", nmr.bench.file))){
        load(file = file.path("Betabinomial", "NMR", nmr.bench.file))
      }else if(file.exists(file.path("Betabinomial", "NMR",
                                     gsub(paste0("_", time.model),
                                          "", nmr.bench.file)))){
        load(file = file.path("Betabinomial", "NMR",
                              gsub(paste0("_", time.model),
                                   "", nmr.bench.file)))
      }else{
        message("Benchmarks file does not exist.\n")
      }
      
      adm2.nmr.benchmarks <- bench.adj
      
      if(file.exists(file.path("Betabinomial", "U5MR", u5.bench.file))){
        load(file = file.path("Betabinomial", "U5MR", u5.bench.file))
      }else if(file.exists(file.path("Betabinomial", "U5MR",
                                     gsub(paste0("_", time.model),
                                          "", u5.bench.file)))){
        load(file = file.path("Betabinomial", "U5MR",
                              gsub(paste0("_", time.model),
                                   "", u5.bench.file)))
      }else{
        message("Benchmarks file does not exist.\n")
      }
      adm2.u5.benchmarks <- bench.adj
    }
    
    if(bench.model == ""){
      admin2.strat.nmr.BB8 <- bb.res.adm2.strat.nmr$overall
      admin2.strat.u5.BB8 <- bb.res.adm2.strat.u5$overall
    }else{
      admin2.strat.nmr.BB8.bench <-  bb.res.adm2.strat.nmr.bench$overall
      if(grepl('crisis',u5.filename)){
        admin2.strat.u5.BB8.bench <- res_adm2_u5_crisis
      }else{
        admin2.strat.u5.BB8.bench <- bb.res.adm2.strat.u5.bench$overall
      }
    }
  }  
}

## IGME estimates ####
igme.frame <- 
  as.data.frame(cbind(igme.ests.nmr$LOWER_BOUND,
                      igme.ests.nmr$OBS_VALUE,igme.ests.nmr$UPPER_BOUND,
                      igme.ests.u5$LOWER_BOUND,
                      igme.ests.u5$OBS_VALUE,igme.ests.u5$UPPER_BOUND))
colnames(igme.frame) = c("lower_nmr", "median_nmr", "upper_nmr",
                         "lower_u5", "median_u5", "upper_u5")
igme.frame$method <- "igme"
igme.frame$years <- beg.year:max(igme.ests.nmr$year)

# National Plots ####
model_cols <- brewer.pal(n = 12, name = "Paired")
survey_cols <- rainbow(length(surveys))

## Spaghetti: 3 panel ####
use_path_base(res.dir)

### Specify Natl model ####

if(strata.model == "unstrat"){
  tmp_plot <- natl.bb.unstrat.frame
}else{
  tmp_plot <- natl.bb.strat.frame
}

for(outcome in c("nmr", "u5")){
  tmp.dir <- ifelse(outcome == "u5", "u5mr", outcome)
  file_name <- file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, "_natl_", strata.model,
         "_", time.model, "_", outcome,
         "_Spaghetti.pdf"))
  pdf(file_name,
      height = 2.67, width = 8)
  {
    tmp.area <- tmp_plot[,c("method", "years", 
                            paste0(c("lower", "upper", "median"),
                                   "_", outcome))]
    names(tmp.area)[3:5] <- c("lower", "upper", "median")
    tmp.area$width <- tmp.area$upper - tmp.area$lower
    tmp.area$cex2 <- median(tmp.area$width, na.rm = T)/tmp.area$width
    tmp.area$cex2[tmp.area$cex2 > 6] <- 6
    tmp.area$median <- tmp.area$median*1000
    tmp.area$upper <- tmp.area$upper*1000
    tmp.area$lower <- tmp.area$lower*1000
    tmp.area$years.num <- as.numeric(paste0(tmp.area$years))
    
    
    par(mfrow = c(1,3),lend=1)
    if(dim(tmp.area)[1] != 0 & 
       !(sum(is.na(tmp.area$median)) == nrow(tmp.area))){
      plot.max <- max(1000*natl.dir.frame[ , paste0("median_", outcome)] + 25,
                      na.rm = T)
    }else{
      plot.max <- 0.25*1000
    }
    
    if (nrow(tmp.area) >0 & sum(is.na(tmp.area[, "median"]))
        == nrow(tmp.area)) {
      plot(NA,
           xlab = "Year", ylab = toupper(tmp.dir),
           ylim = c(0, ceiling(plot.max)),
           xlim = range(plot_years),
           type = 'l', col = cols[1], lwd = 2,
           main = country)
      legend('topright', bty = 'n', col = c(survey_cols, 
                                            'grey80', 'black'),
             lwd = 2, lty = 1,
             
             legend = c(surveys, "IGME", "BB8"))
      
    } else {
      
      for(survey in surveys){
        tmp <- natl.dir.frame[natl.dir.frame$surveyYears == survey,
                              c("method", "years", "surveyYears",
                                paste0(c("lower", "median", "upper"),
                                       "_", outcome))]
        names(tmp)[4:6] <- c("lower", "median", "upper")
        tmp[ , c("lower", "median", "upper")] <- 
          1000*tmp[ , c("lower", "median", "upper")]
        svy.idx <- match(survey, surveys) 
        
        if(svy.idx== 1){
          if(dim(tmp)[1] != 0){
            plot(NA,
                 xlab = "Year", ylab = toupper(tmp.dir),
                 ylim = c(0, plot.max),
                 xlim = c(2000, end.proj.year),
                 type = 'l', col = survey_cols[svy.idx], lwd = 2,
                 main = country)
            
            lines(tmp$years, tmp$median, cex = tmp$cex2,
                  type = 'l', col = survey_cols[svy.idx],
                  main = surveys[svy.idx], lwd = 2)
            
            points(tmp$years, tmp$median, pch = 19,
                   col = alpha(survey_cols[svy.idx], 0.35),
                   cex = tmp$cex2)
            
          }else{
            plot(NA,
                 xlab = "Year", ylab = toupper(tmp.dir),
                 ylim = c(0, plot.max),
                 xlim = c(2000, end.year),
                 type = 'l', col = survey_cols[svy.idx], lwd = 2,
                 main =  country)
          }
        }else{
          if(dim(tmp)[1] != 0){
            lines(tmp$years, tmp$median, cex = tmp$cex2,
                  type = 'l', col = survey_cols[svy.idx],
                  lwd = 2)
            points(tmp$years, tmp$median, pch = 19,
                   col = alpha(survey_cols[svy.idx], 0.35),
                   cex = tmp$cex2)
          } 
        }
        
        
      }
      
      igme.years <- igme.frame$years
      lines(igme.frame$years, 1000*igme.frame[,paste0("median_", outcome)],
            lty = 1, lwd = 2, col = "grey80")
      
      
      lines(tmp.area$years.num,
            tmp.area$median,
            col = "black",
            lwd = 2, lty = 1)
      
      
      legend('topright', bty = 'n', 
             col = c(survey_cols, "grey88", 'black'),
             lwd = 2, lty = c(rep(1, length(survey_cols) + 2)),
             legend = c(surveys, "IGME", "BB8"),
             cex = 0.6)
      
      for(survey in surveys){
        tmp <- natl.dir.frame[natl.dir.frame$surveyYears == survey,
                              c("method", "years", "surveyYears",
                                paste0(c("lower", "median", "upper"),
                                       "_", outcome))]
        names(tmp)[4:6] <- c("lower", "median", "upper")
        
        tmp[ , c("lower", "median", "upper")] <- 
          1000*tmp[ , c("lower", "median", "upper")]
        svy.idx <- match(survey, surveys) 
        
        if(svy.idx == 1){
          if(dim(tmp)[1] != 0){
            plot(NA,
                 xlab = "Year", ylab = toupper(tmp.dir),
                 ylim = c(0, plot.max),
                 xlim = c(2000, end.proj.year),
                 type = 'l', col = survey_cols[svy.idx], lwd = 2,
                 main = country)
            
            poly.years <- tmp$years[!is.na(tmp$upper)]
            
            polygon(x = c(poly.years,
                          rev(poly.years)),
                    y = c(tmp$upper[!is.na(tmp$upper)],
                          rev(tmp$lower[!is.na(tmp$lower)])),
                    col = alpha(survey_cols[svy.idx], 0.25),
                    border = FALSE)
            
            
          }else{
            plot(NA,
                 xlab = "Year", ylab = toupper(tmp.dir),
                 ylim = c(0, plot.max),
                 xlim = c(2000, end.proj.year),
                 type = 'l', col = survey_cols[svy.idx], lwd = 2,
                 main = country_print)
            
            lines(tmp$years, tmp$median, cex = tmp$cex2,
                  type = 'l', col = survey_cols[svy.idx],
                  lwd = 2)
            points(tmp$years, tmp$median, pch = 19,
                   col = alpha(survey_cols[svy.idx], 0.35),
                   cex = tmp$cex2)
          }
        }else{
          poly.years <- tmp$years[!is.na(tmp$upper)]
          
          polygon(x = c(poly.years,
                        rev(poly.years)),
                  y = c(tmp$upper[!is.na(tmp$upper)],
                        rev(tmp$lower[!is.na(tmp$lower)])),
                  col = alpha(survey_cols[svy.idx], 0.25),
                  border = FALSE)
        }
        
      }  
      
      legend('topright', bty = 'n',
             fill = alpha(survey_cols, 0.25),
             border = survey_cols,
             legend = surveys,
             cex = 0.6)
      
      for(survey in surveys){
        tmp <- natl.dir.frame[natl.dir.frame$surveyYears == survey,
                              c("method", "years", "surveyYears",
                                paste0(c("lower", "median", "upper"),
                                       "_", outcome))]
        names(tmp)[4:6] <- c("lower", "median", "upper")
        
        tmp[ , c("lower", "median", "upper")] <- 
          1000*tmp[ , c("lower", "median", "upper")]
        svy.idx <- match(survey, surveys) 
        
        
        if(svy.idx == 1){
          if(dim(tmp)[1] != 0){
            plot(NA,
                 xlab = "Year", ylab = toupper(tmp.dir),
                 ylim = c(0, plot.max),
                 xlim = c(2000, end.proj.year),
                 type = 'l', col = survey_cols[svy.idx], lwd = 2,
                 main = country)
            
          }
        }  
      }
      
      igme.years <- igme.frame$years
      polygon(x = c(igme.years, rev(igme.years)),
              y = 1000*c(igme.frame[,paste0("upper_", outcome)],
                         rev(igme.frame[,paste0("lower_", outcome)])),
              col = alpha("grey80", 0.35),
              border = FALSE)
      
      polygon(x = c(tmp.area$years.num, rev(tmp.area$years.num)),
              y = c(tmp.area$upper, rev(tmp.area$lower)),
              col = alpha('black', 0.35),
              border = FALSE)
      lines(tmp.area$years.num,
            tmp.area$median,
            col = 'black',
            lwd = 2, lty = 1)
      legend('topright', bty = 'n',
             fill = alpha(c("grey80",'black'), .25),
             border = c("grey80",'black'),  cex = 0.65,
             legend = c( 'IGME', 'BB8'))
    }
    
    
  }
  dev.off()
}


# Admin-1 Plots ####
report_excluded_ids <- report_excluded_admin_ids(home.dir, country, 1L)
admin1.names <- filter_report_admin_rows(admin1.names, report_excluded_ids, "Internal")
if (length(report_excluded_ids)) {
  poly.adm1 <- poly.adm1[poly.adm1[[poly.label.adm1]] %in% admin1.names$Join, ]
}
## Specify Admin-1 Result Object ####

tmp_plot <- list()
if(strata.model == "unstrat"){
  if(bench.model == ""){
    tmp_plot$nmr <- admin1.unstrat.nmr.BB8
    tmp_plot$u5 <- admin1.unstrat.u5.BB8
  }else{
    tmp_plot$nmr <- admin1.unstrat.nmr.BB8.bench
    tmp_plot$u5 <- admin1.unstrat.u5.BB8.bench
  }
}else{
  if(bench.model == ""){
    tmp_plot$nmr <- admin1.strat.nmr.BB8
    tmp_plot$u5 <- admin1.strat.u5.BB8
  }else{
    tmp_plot$nmr <- admin1.strat.nmr.BB8.bench
    tmp_plot$u5 <- admin1.strat.u5.BB8.bench
  }
}


## Spaghetti: Medians ####


# change the region names from Internal to GeoRepo for legend labels

tmp_plot <- lapply(tmp_plot, function(res.admin1){
  res.admin1 <- filter_report_admin_rows(res.admin1, report_excluded_ids)
  res.admin1$region.orig <- res.admin1$region
  for (i in 1:nrow(admin1.names)) {
    res.admin1$region[as.character(res.admin1$region) == 
                        as.character(admin1.names$Internal[i])] <- 
      paste(as.character(admin1.names$Display[i]))
  }
  
  
  res.admin1
})

# Add a scalable overview against the final official national series. Individual
# Admin-1 labels remain available in the paginated coloured charts below.
for (outcome in c("nmr", "u5")) {
  tmp.dir <- ifelse(outcome == "u5", "u5mr", outcome)
  national_total_file <- file.path(
    res.dir,
    "Figures",
    "Summary",
    toupper(tmp.dir),
    admin1_national_total_filename(
      country = country,
      outcome = outcome,
      time_model = time.model,
      strata_model = strata.model,
      bench_model = bench.model
    )
  )
  national_total_plot <- build_admin1_national_total_plot(
    admin_data = tmp_plot[[outcome]],
    igme_frame = igme.frame,
    outcome = outcome,
    country_label = country_print
  )
  grDevices::pdf(national_total_file, width = 7, height = 5.5)
  print(national_total_plot)
  grDevices::dev.off()
}

# make the plot

numberAreasPerPage <- 21
numberAreasTotal <- nrow(admin1.names)
numberPages <- ceiling(numberAreasTotal/numberAreasPerPage)

# order data by median magnitude in 2024
tmp_plot$u5$years.num <- as.numeric(paste0(tmp_plot$u5$years))

if(country != "Pakistan"){
  areaOrder <- tmp_plot$u5 %>% 
    filter(years.num == end.proj.year) %>%
    arrange(median) %>% 
    dplyr::select(region.orig) %>% unlist()
}else{
  areaOrder <- tmp_plot$u5 %>% 
    filter(years.num == end.proj.year) %>%
    filter(!(region.orig %in% disputed_areas_internal)) %>% 
    arrange(median) %>% 
    dplyr::select(region.orig) %>% unlist()
}

# loop and make plots
for (i in 1:numberPages) {
  if (i != numberPages) {
    areas <- areaOrder[(((i-1)*numberAreasPerPage)+1):(i*numberAreasPerPage)]
  } else {
    areas <- areaOrder[(((i-1)*numberAreasPerPage)+1):numberAreasTotal]
  }
  
  for(outcome in c("nmr", "u5")){
    tmp <- tmp_plot[[outcome]]
    tmp <- tmp[tmp$region.orig %in% areas,]
    tmp.dir <- ifelse(outcome == "u5", "u5mr", outcome)
    bench_str <- ifelse(bench.model == "", bench.model,
                        paste0("_", bench.model))
    
    file_name <- file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, '_Admin1_', outcome, '_SpaghettiAll_',
                        time.model, '_', strata.model, bench_str, "_",
                        i,'.pdf'))
    
    pdf(file_name)
    par(lend=1)
    
    g <- ggplot(tmp, aes(x = years.num, 
                         y = median*1000,
                         col = region)) +
      geom_line() +
      geom_point() +
      scale_color_discrete(labels = scales::label_wrap(width = 24)) +
      theme_light() +
      xlab("Year") +
      ylab(paste0(toupper(tmp.dir),
                  ": deaths per 1000 live births")) +
      ggtitle(country_print) +
      theme(legend.position = "bottom",
            legend.text = element_text(size = 8)) +
      guides(col = guide_legend(title = NULL, ncol = 3)) +
      ylim(c(0, max(tmp$median)*1000))
    print(g)
    dev.off()
  }
}

## Spaghetti: 6 regions per page (plot by region) ####

bench_str <- ifelse(bench.model == "", bench.model,
                    paste0("_", bench.model))

for(outcome in c("nmr", "u5")){
  tmp.dir <- ifelse(outcome == "u5", "u5mr", outcome)
  
  pdf(file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, '_Admin1_', outcome, "_",
             time.model, "_", strata.model, bench_str,  "_",
             "Spaghetti_6per.pdf")),
      height = 9, width = 6)
  {
    par(mfrow = c(3,2), lend=1)
    
    area.idx <- 0
    for(area in admin1.names$Internal){
      area.idx <- area.idx + 1
      tmp.area <- tmp_plot[[outcome]][,c("region", "region.orig", "years.num", 
                                         "lower", "upper", "median")] %>% 
        filter(region.orig == area)
      tmp.area$width <- tmp.area$upper - tmp.area$lower
      tmp.area$cex2 <- median(tmp.area$width, na.rm = T)/tmp.area$width
      tmp.area$cex2[tmp.area$cex2 > 6] <- 6
      tmp.area[,c("median", "lower","upper")] <-
        tmp.area[,c("median", "lower","upper")]*1000
      
      
      if(dim(tmp.area)[1] != 0 &
         !(sum(is.na(tmp.area$median)) == nrow(tmp.area))){
        direct.values <- 1000 * report_direct_region_values(
          adm1.dir.frame,
          area,
          outcome
        )
        plot.max <- report_spaghetti_axis_max(
          model_median = tmp.area$median,
          model_upper = tmp.area$upper,
          direct_values = direct.values
        )
      }else{
        plot.max <- 25
      }
      
      if (nrow(tmp.area) > 0 & sum(is.na(tmp.area$median)) == nrow(tmp.area)){
        plot(NA,
             xlab = "Year", ylab = toupper(tmp.dir),
             ylim = c(0, plot.max),
             xlim = c(beg.year, end.year + 1),
             type = 'l', col = survey_cols[1], lwd = 2,
             main = admin1.names$Display[area.idx])
        legend('topright', bty = 'n', col = c(cols, "grey80", 'black'),
               lwd = 2, lty = 1, legend = c(surveys, "IGME", "Betabinomial"))
        
      } else {
        
        for(survey in surveys){
          tmp <- adm1.dir.frame[adm1.dir.frame$surveyYears == survey &
                                  adm1.dir.frame$region == 
                                  admin1.names$Internal[area.idx],]
          svy.idx <- match(survey, surveys) 
          
          
          if(svy.idx == 1){
            if(dim(tmp)[1] != 0){
              plot(NA,
                   xlab = "Year", ylab = toupper(tmp.dir),
                   ylim = c(0, plot.max),
                   xlim = c(beg.year, end.proj.year + 1),
                   type = 'l', col = survey_cols[svy.idx], lwd = 2,
                   main = admin1.names$Display[area.idx])
              
              lines(pane.years[1:nrow(tmp)],
                    1000*tmp[, paste0("median_", outcome)],
                    cex = tmp$cex2,
                    type = 'l', col = survey_cols[svy.idx],
                    lwd = 2)
              
              points(pane.years[1:nrow(tmp)],
                     1000*tmp[, paste0("median_", outcome)],
                     pch = 19,
                     col = alpha(survey_cols[svy.idx], 0.35),
                     cex = tmp$cex2)
              
            }else{
              plot(NA,
                   xlab = "Year", ylab = toupper(tmp.dir),
                   ylim = c(0, plot.max),
                   xlim = c(beg.year, end.proj.year + 1),
                   type = 'l', col = survey_cols[svy.idx], lwd = 2,
                   main =  paste0(admin1.names$Display[area.idx]))
            }
          }else{
            if(dim(tmp)[1] != 0){
              lines(pane.years[1:nrow(tmp)],
                    1000*tmp[,paste0("median_", outcome)],
                    cex = tmp$cex2,
                    type = 'l', col = survey_cols[svy.idx],
                    lwd = 2)
              points(pane.years[1:nrow(tmp)],
                     1000*tmp[, paste0("median_", outcome)],
                     pch = 19,
                     col = alpha(survey_cols[svy.idx], 0.35),
                     cex = tmp$cex2)
            } 
          }
          
        }
        
        lines(tmp.area$years.num,tmp.area$median, 
              col = 'black', lwd = 2, lty = 1)
        
        polygon(x = c(tmp.area$years.num, rev(tmp.area$years.num)),
                y = c(tmp.area$upper, rev(tmp.area$lower)),
                col = alpha('black', 0.25), 
                border = FALSE)
        
        legend('topright', bty = 'n', col = c(survey_cols, 'black'),
               lwd = 2, lty = c(rep(1, length(cols)+1)),
               legend = c(surveys, "BB8"),
               cex = 0.6)
        
      }
    }
    dev.off()
  }
}

## Maps ####
### Make map ####
years_vt <- plot.years
n_years <- length(years_vt)
bench_str <- ifelse(bench.model == "", "", "_bench")

country_code_dt <- data.table(Country = country,
                              code = iso0)

country_code_dt <- data.table(Country = country,
                              code = iso0)
admin_level_dt <- data.table(Admin = "admin1", level = 2)
admin_name_dt <- as.data.table(admin1.names)
selected_map_layout <- report_selected_map_layout()


for(outcome in c("nmr", "u5")){
  if(!is.null(dev.list())) dev.off() # close any open devices
  
  tmp.dir <- ifelse(outcome == "u5", "u5mr", outcome)
  available_years <- sort(unique(tmp_plot[[outcome]]$years.num[
    !is.na(tmp_plot[[outcome]]$median)]))
  years_vt_outcome <- intersect(years_vt, available_years)
  
  if(length(years_vt_outcome) == 0){
    message("No ", toupper(tmp.dir), " map years available; skipping maps.\n")
    next
  }
  
  
  data_plot_dt <- NULL
  
  for(year in years_vt_outcome){
    
    cond <- tmp_plot[[outcome]][tmp_plot[[outcome]]$years.num == year,]
    if(country == "Pakistan"){
      cond <- cond[!(cond$region.orig %in% disputed_areas_internal), ]
    }
    
    # create plotting area names (just admin 1 name if admin = 1,
    # or 'admin2,\n admin1' if admin = 2)
    # admin_name_dt$nameToPlot <- unique(eval(str2lang(poly.label.adm1)))
    # replace by 
    admin_name_dt$nameToPlot <- admin_name_dt$Display
    
    # create data to plot
    data_plot_dt_year <- 
      data.table(Year = year, 
                 Internal = cond$region.orig,
                 GeoRepo = admin_name_dt[match(admin_name_dt$Internal,
                                               cond$region.orig), Join],
                 nameToPlot = admin_name_dt[match(admin_name_dt$Internal,
                                                  cond$region.orig), nameToPlot],
                 U5MR_median = cond$median)
    
    data_plot_dt_year[, "NAME_1" := GeoRepo]
    
    data_plot_dt <- rbind(data_plot_dt, data_plot_dt_year)
  }
  
  # map of all the years
  rowcount <- ceiling(length(years_vt_outcome)/5)
  pdf(file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, "_adm1_", time.model, "_",
             strata.model, "_", outcome,bench_str, "_medianmap.pdf")),
      width = 10, height = 3.5*rowcount)
  {
    data_plot_dt_df <- as.data.frame(data_plot_dt)
    print(SUMMER::mapPlot(data = data_plot_dt_df, 
                          "Year", is.long = T,
                          values = "U5MR_median", direction = -1,
                          geo = poly.adm1, ncol = 5,
                          by.data = "GeoRepo",
                          legend.label = toupper(tmp.dir),
                          per1000 = TRUE,
                          by.geo = poly.label.adm1))
  }
  dev.off()
  
  # map of selected years: 
  selected_years <- unique(c(2000, 2005, 2010, 2015, 2020,
                             max(years_vt_outcome)))
  selected_years <- intersect(selected_years, years_vt_outcome)
  file_name <- file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, "_adm1_", time.model, "_",
             strata.model, "_", outcome, bench_str, "_medianmap_",
             min(selected_years), "_", max(selected_years), ".pdf"))
  pdf(file_name,
      width = selected_map_layout$width,
      height = selected_map_layout$height)
  {
    
    print(SUMMER::mapPlot(data = data_plot_dt[Year %in% selected_years],
                          is.long = T, 
                          variables = "Year", 
                          values = "U5MR_median",direction = -1,
                          geo = poly.adm1,
                          ncol = selected_map_layout$ncol,
                          legend.label = toupper(tmp.dir),
                          per1000 = TRUE,
                          by.data = "GeoRepo",
                          by.geo = poly.label.adm1))
  }
  dev.off()
  
  
  # PD
  pd_years <- c(min(years_vt_outcome), max(years_vt_outcome))
  data_plot_dt_w <- dcast(data_plot_dt[Year %in% pd_years],
                          ...~ Year, value.var = "U5MR_median")
  start_col <- as.character(pd_years[1])
  end_col <- as.character(pd_years[2])
  data_plot_dt_w[, `Percentage decline` := (get(end_col)/get(start_col)-1) * -100]
  gPD <- SUMMER::mapPlot(data = data_plot_dt_w,
                         variables = "Percentage decline", direction = -1,
                         geo = poly.adm1, ncol = 1,
                         legend.label = paste(toupper(tmp.dir)),
                         by.data = "GeoRepo",
                         by.geo = poly.label.adm1)
  
  file_name <- file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, "_adm1_", time.model, "_",
                      strata.model, "_", outcome, bench_str, "_PDmap.pdf"))
  ggsave(gPD, file = file_name, width = 6, height = 5)
}



if(bench.model == "bench"){
  y_lims <- 1 + c(-1,1)*max(abs(1- range(adm1.nmr.benchmarks$ratio,
                                         na.rm = TRUE)), na.rm = TRUE)
  
  pdf(file.path("Figures", "Summary", "NMR", paste0(country, "_Admin1_nmr_",
             time.model, "_", strata.model, "_benchmarks.pdf")))
  {
    plot(adm1.nmr.benchmarks$years,
         adm1.nmr.benchmarks$ratio,
         xlab = "Year", ylab = "(Unbenchmarked Median)/(IGME Median)",
         ylim = y_lims, main = "",
         type = "n")
    abline(h = 1)
    lines(adm1.nmr.benchmarks$years,
          adm1.nmr.benchmarks$ratio,
          lwd = 2, col = "firebrick")
  }
  dev.off()
  
  y_lims <- 1 + c(-1,1)*max(abs(1- range(adm1.u5.benchmarks$ratio,
                                         na.rm = TRUE)), na.rm = TRUE)
  
  pdf(file.path("Figures", "Summary", "U5MR", paste0(country, "_Admin1_u5_",
             time.model, "_", strata.model, "_benchmarks.pdf")))
  {
    plot(adm1.u5.benchmarks$years,
         adm1.u5.benchmarks$ratio,
         xlab = "Year", ylab = "(Unbenchmarked Median)/(IGME Median)",
         ylim = y_lims, main = "",
         type = "n")
    abline(h = 1)
    lines(adm1.u5.benchmarks$years,
          adm1.u5.benchmarks$ratio,
          lwd = 2, col = "firebrick")
  }
  dev.off()
}




# Admin-2 Plots ####

if(run_admin2_report){
  
  use_path_base(res.dir)
  
  ## Specify Admin-2 Result Object ####
  
  tmp_plot <- list()
  if(strata.model == "unstrat"){
    if(bench.model == ""){
      tmp_plot$nmr <- admin2.unstrat.nmr.BB8
      tmp_plot$u5 <- admin2.unstrat.u5.BB8
    }else{
      tmp_plot$nmr <- admin2.unstrat.nmr.BB8.bench
      tmp_plot$u5 <- admin2.unstrat.u5.BB8.bench
    }
  }else{
    if(bench.model == ""){
      tmp_plot$nmr <- admin2.strat.nmr.BB8
      tmp_plot$u5 <- admin2.strat.u5.BB8
    }else{
      tmp_plot$nmr <- admin2.strat.nmr.BB8.bench
      tmp_plot$u5 <- admin2.strat.u5.BB8.bench
    }
  }
  
  
  ## Spaghetti: Medians within Admin-2 ####
  
  
  # change the region names from Internal to GeoRepo for legend labels
  
  tmp_plot <- lapply(tmp_plot, function(res.admin2){
    
    # change the region names from Internal to GeoRepo for legend labels
    res.admin2$region1.georepo <- 
      res.admin2$region.georepo <- 
      res.admin2$region.orig <- 
      res.admin2$region
    
    # If this isn't working for you, you may need to edit 
    # the way adm1_on_adm2 is defined
    for (i in 1:nrow(admin2.names)) {
      res.admin2$region[as.character(res.admin2$region) == 
                          as.character(admin2.names$Internal[i])] <-
        paste(as.character(admin2.names$Display[i]),
              admin2.parent.display[i], sep =", ")
      res.admin2$region.georepo[as.character(res.admin2$region.orig) == 
                               as.character(admin2.names$Internal[i])] <-
        paste(as.character(admin2.names$Display[i]))
      res.admin2$region1.georepo[as.character(res.admin2$region.orig) == 
                                as.character(admin2.names$Internal[i])] <-
        paste(admin2.parent.display[i])
      
    }
    
    res.admin2
  })
  
  
  # make the plot
  
  numberAreasPerPage <- 21
  numberAreasTotal <- nrow(admin2.names)
  numberPages <- ceiling(numberAreasTotal/numberAreasPerPage)
  
  # order data by median magnitude in 2024
  tmp_plot$u5$years.num <- as.numeric(paste0(tmp_plot$u5$years))
  
  if(country != "Pakistan"){
    areaOrder <- tmp_plot$u5 %>% 
      filter(years.num == end.proj.year) %>%
      arrange(median) %>% 
      dplyr::select(region.orig) %>% unlist()
  }else{
    areaOrder <- tmp_plot$u5 %>% 
      filter(years.num == end.proj.year) %>%
      filter(!(region.orig %in% disputed_areas_internal)) %>% 
      arrange(median) %>% 
      dplyr::select(region.orig) %>% unlist()
  }
  # loop and make plots
  for (i in 1:numberPages) {
    if (i != numberPages) {
      areas <- areaOrder[(((i-1)*numberAreasPerPage)+1):(i*numberAreasPerPage)]
    } else {
      areas <- areaOrder[(((i-1)*numberAreasPerPage)+1):numberAreasTotal]
    }
    
    for(outcome in c("nmr", "u5")){
      tmp <- tmp_plot[[outcome]]
      tmp <- tmp[tmp$region.orig %in% areas,]
      
      tmp.dir <- ifelse(outcome == "u5", "u5mr", outcome)
      bench_str <- ifelse(bench.model == "", bench.model,
                          paste0("_", bench.model))
      pdf(file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, '_Admin2_', outcome, '_SpaghettiAll_',
                 time.model, '_', strata.model, bench_str, "_",
                 i,'.pdf')))
      par(lend=1)
      
      g <- ggplot(tmp, aes(x = years.num, 
                           y = median*1000,
                           col = region)) +
        geom_line() +
        geom_point() +
        scale_color_discrete(labels = scales::label_wrap(width = 24)) +
        theme_light() +
        xlab("Year") +
        ylab(paste0(toupper(tmp.dir),
                    ": deaths per 1000 live births")) +
        ggtitle(country_print) +
        theme(legend.position = "bottom",
              legend.text = element_text(size = 6)) +
        guides(col = guide_legend(title = "Admin-2", ncol = 3)) +
        ylim(c(0, max(tmp$median)*1000))
      print(g)
      dev.off()
    }
  }
  
  ## Spaghetti: 6 per page ####
  bench_str <- ifelse(bench.model == "", bench.model,
                      paste0("_", bench.model))
  
  for(outcome in c("nmr", "u5")){
    tmp.dir <- ifelse(outcome == "u5", "u5mr", outcome)
    
    pdf(file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, '_Admin2_', outcome, "_",
               time.model, "_", strata.model, bench_str, "_", 
               "Spaghetti_6per.pdf")),
        height = 9, width = 6)
    {
      par(mfrow = c(3,2), lend=1)
      
      area.idx <- 0
      for(area in admin2.names$Internal){
        area.idx <- area.idx + 1
        tmp.area <- tmp_plot[[outcome]][,c("region", "region.orig", "years.num", 
                                           "lower", "upper", "median")] %>% 
          filter(region.orig == area)
        tmp.area$width <- tmp.area$upper - tmp.area$lower
        tmp.area$cex2 <- median(tmp.area$width, na.rm = T)/tmp.area$width
        tmp.area$cex2[tmp.area$cex2 > 6] <- 6
        tmp.area[,c("median", "lower","upper")] <-
          tmp.area[,c("median", "lower","upper")]*1000
        tmp.area$years.num <- as.numeric(paste0(tmp.area$years))
        
        
        if(dim(tmp.area)[1] != 0 &
           !(sum(is.na(tmp.area$median)) == nrow(tmp.area))){
          direct.values <- 1000 * report_direct_region_values(
            adm2.dir.frame,
            area,
            outcome
          )
          plot.max <- report_spaghetti_axis_max(
            model_median = tmp.area$median,
            model_upper = tmp.area$upper,
            direct_values = direct.values
          )
        }else{
          plot.max <- 25
        }
        
        if (nrow(tmp.area) > 0 & sum(is.na(tmp.area$median)) == nrow(tmp.area)){
          plot(NA,
               xlab = "Year", ylab = toupper(tmp.dir),
               ylim = c(0, plot.max),
               xlim = c(beg.year, end.year + 1),
               type = 'l', col = survey_cols[1], lwd = 2,
               main = admin2.names$Display[area.idx])
          legend('topright', bty = 'n', col = c(cols, 'black'),
                 lwd = 2, lty = 1, legend = c(surveys, "Betabinomial"))
          
        } else {
          
          for(survey in surveys){
            tmp <- adm2.dir.frame[adm2.dir.frame$surveyYears == survey &
                                    adm2.dir.frame$region == 
                                    admin2.names$Internal[area.idx],]
            svy.idx <- match(survey, surveys) 
            
            
            if(svy.idx == 1){
              if(dim(tmp)[1] != 0){
                plot(NA,
                     xlab = "Year", ylab = toupper(tmp.dir),
                     ylim = c(0, plot.max),
                     xlim = c(beg.year, end.proj.year + 1),
                     type = 'l', col = survey_cols[svy.idx], lwd = 2,
                      main = admin2.names$Display[area.idx])
                
                lines(pane.years[1:nrow(tmp)],
                      1000*tmp[, paste0("median_", outcome)],
                      cex = tmp$cex2,
                      type = 'l', col = survey_cols[svy.idx],
                      lwd = 2)
                points(pane.years[1:nrow(tmp)],
                       1000*tmp[, paste0("median_", outcome)],
                       pch = 19,
                       col = alpha(survey_cols[svy.idx], 0.35),
                       cex = tmp$cex2)
                
              }else{
                plot(NA,
                     xlab = "Year", ylab = toupper(tmp.dir),
                     ylim = c(0, plot.max),
                     xlim = c(beg.year, end.proj.year + 1),
                     type = 'l', col = survey_cols[svy.idx], lwd = 2,
                      main =  paste0(admin2.names$Display[area.idx]))
              }
            }else{
              if(dim(tmp)[1] != 0){
                lines(pane.years[1:nrow(tmp)],
                      1000*tmp[,paste0("median_", outcome)],
                      cex = tmp$cex2,
                      type = 'l', col = survey_cols[svy.idx],
                      lwd = 2)
                points(pane.years[1:nrow(tmp)],
                       1000*tmp[, paste0("median_", outcome)],
                       pch = 19,
                       col = alpha(survey_cols[svy.idx], 0.35),
                       cex = tmp$cex2)
              } 
            }
            
          }
          
          lines(tmp.area$years.num, tmp.area$median, 
                col = 'black', lwd = 2, lty = 1)
          
          polygon(x = c(tmp.area$years.num, rev(tmp.area$years.num)),
                  y = c(tmp.area$upper, rev(tmp.area$lower)),
                  col = alpha('black', 0.25), 
                  border = FALSE)
          
          legend('topright', bty = 'n', col = c(survey_cols, 'black'),
                 lwd = 2, lty = c(rep(1, length(cols)+1)),
                 legend = c(surveys, "BB8"),
                 cex = 0.6)
          
        }
      }
      dev.off()
    }
  }
  
  
  
  
  
  ## Maps ####
  ### Make map ####
  years_vt <- plot.years
  n_years <- length(years_vt)
  bench_str <- ifelse(bench.model == "", "", "_bench")
  country_code_dt <- data.table(Country = country,
                                code = iso0)
  admin_level_dt <- data.table(Admin = "admin2", level = 2)
  admin_name_dt <- as.data.table(admin2.names)
  
  for(outcome in c("nmr", "u5")){
    
    tmp.dir <- ifelse(outcome == "u5", "u5mr", outcome)
    available_years <- sort(unique(tmp_plot[[outcome]]$years.num[
      !is.na(tmp_plot[[outcome]]$median)]))
    years_vt_outcome <- intersect(years_vt, available_years)
    
    if(length(years_vt_outcome) == 0){
      message("No Admin-2 ", toupper(tmp.dir), " map years available; skipping maps.\n")
      next
    }
    
    
    data_plot_dt <- NULL
    
    for(year in years_vt_outcome){
      cond <- tmp_plot[[outcome]][tmp_plot[[outcome]]$years.num == year,]
      
      if(country == "Pakistan"){
        cond <- cond[!(cond$region.orig %in% disputed_areas_internal), ]
      }
      
      # create plotting area names (just admin 1 name if admin = 1,
      # or 'admin2,\n admin1' if admin = 2)
      # if this part is not working, please revist how
      # adm1_on_adm2 is defined
      admin_name_dt$nameToPlot <- admin2.parent.display
      
      # create data to plot
      data_plot_dt_year <- 
        data.table(Year = year, 
                   Internal = cond$region.orig,
                   GeoRepo = admin_name_dt[match(admin_name_dt$Internal,
                                               cond$region.orig), Join],
                   nameToPlot = admin_name_dt[match(admin_name_dt$Internal,
                                                    cond$region.orig), nameToPlot],
                   U5MR_median = cond$median)
      
      data_plot_dt_year[, "NAME_2" := GeoRepo]
      
      data_plot_dt <- rbind(data_plot_dt, data_plot_dt_year)
    }
    
    
    rowcount <- ceiling(length(years_vt_outcome)/5)
    
    pdf(file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, "_adm2_", time.model, "_",
               strata.model, "_", outcome, bench_str, "_medianmap.pdf")),
        width = 10, height = 3.5*rowcount)
    {
      data_plot_dt_df <- as.data.frame(data_plot_dt)
      print(SUMMER::mapPlot(data = data_plot_dt_df, 
                            variables = "Year", is.long = T,
                            values = "U5MR_median", direction = -1,
                            geo = poly.adm2, ncol = 5,
                            by.data = "GeoRepo",
                            legend.label = toupper(tmp.dir),
                            per1000 = TRUE,
                            by.geo = poly.label.adm2))
    }
    dev.off()
    
    selected_years <- unique(c(2000, 2005, 2010, 2015, 2020,
                               max(years_vt_outcome)))
    selected_years <- intersect(selected_years, years_vt_outcome)
    
    pdf(file.path("Figures", "Summary", toupper(tmp.dir), paste0(country, "_adm2_", time.model, "_",
               strata.model, "_", outcome, bench_str, "_medianmap_",
               min(selected_years), "_", max(selected_years), ".pdf")),
        width = selected_map_layout$width,
        height = selected_map_layout$height)
    {
      
      data_plot_dt_df <- as.data.frame(data_plot_dt)
      print(SUMMER::mapPlot(data = data_plot_dt_df[data_plot_dt_df$Year %in% 
                                                     selected_years,],
                            is.long = T, 
                            variables = "Year", 
                            values = "U5MR_median",direction = -1,
                            geo = poly.adm2,
                            ncol = selected_map_layout$ncol,
                            legend.label = toupper(tmp.dir),
                            per1000 = TRUE,
                            by.data = "GeoRepo",
                            by.geo = poly.label.adm2))
    }
    dev.off()
    
}
  
  
  
  
  
  ## Benchmarks ####
  
  if(bench.model == "bench"){
    y_lims <- 1 + c(-1,1)*max(abs(1- range(adm2.nmr.benchmarks$ratio,
                                           na.rm = TRUE)), na.rm = TRUE)
    
    pdf(file.path("Figures", "Summary", "NMR", paste0(country, "_Admin2_nmr_",
               time.model, "_", strata.model, "_benchmarks.pdf")))
    {
      plot(adm2.nmr.benchmarks$years,
           adm2.nmr.benchmarks$ratio,
           xlab = "Year", ylab = "(Unbenchmarked Median)/(IGME Median)",
           ylim = y_lims, main = "",
           type = "n")
      abline(h = 1)
      lines(adm2.nmr.benchmarks$years,
            adm2.nmr.benchmarks$ratio,
            lwd = 2, col = "firebrick")
    }
    dev.off()
    
    
    y_lims <- 1 + c(-1,1)*max(abs(1- range(adm2.u5.benchmarks$ratio,
                                           na.rm = TRUE)), na.rm = TRUE)
    
    pdf(file.path("Figures", "Summary", "U5MR", paste0(country, "_Admin2_u5_",
               time.model, "_", strata.model, "_benchmarks.pdf")))
    {
      plot(adm2.u5.benchmarks$years,
           adm2.u5.benchmarks$ratio,
           xlab = "Year", ylab = "(Unbenchmarked Median)/(IGME Median)",
           ylim = y_lims, main = "",
           type = "n")
      abline(h = 1)
      lines(adm2.u5.benchmarks$years,
            adm2.u5.benchmarks$ratio,
            lwd = 2, col = "firebrick")
    }
    dev.off()
  }
  
  
} # admin2 plot 

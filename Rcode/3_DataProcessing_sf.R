USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}

load.country.info(country)

#' Data processing script for DHS and MICS data
#' 
#' ref: https://github.com/alanamcgovern/UN-Subnational-Estimates

# Country context is loaded by Rcode/1_Preperation.R.

# Load libraries and info ----------------------------------------------------------
options(gsubfn.engine = "R")
options(tibble.width = 400)
options(warn=0)

library(spdep)
library(SUMMER)
library(geosphere)
library(stringr)
library(tidyverse)
library(rdhs) #devtools::install_github("ropensci/rdhs")
library(sf)
library(haven)

source(file.path(project_home(), "Rcode/_supporting_scripts/dhs_download.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/dhs_admin1_recode.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/mics_admin_matching.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/mics_tmp_files.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/admin_boundary_merges.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/malawi_admin_repair.R"))
source(file.path(project_home(), "Rcode/_supporting_scripts/urban_frame_matching.R"))

# extract file location of this script
code.path <- file.path(project_home(), "Rcode/3_DataProcessing_sf.R")
code.path.splitted <- strsplit(code.path, "/")[[1]]

# retrieve directories
home.dir <- paste(code.path.splitted[1: (length(code.path.splitted)-2)], collapse = "/")
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
require_country_context()
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}

# set API to get DHS data -- you will need to change this to your information!
dhs_cache_path <- file.path(home.dir, "Data", "DHS", ".rdhs_cache")
dir.create(dhs_cache_path, recursive = TRUE, showWarnings = FALSE)
rdhs_password <- resolve_rdhs_password()
if (!nzchar(rdhs_password)) {
  stop(
    "DHS password is unavailable. Set RDHS_USER_PASS in the current R process ",
    "or in the Windows user environment.",
    call. = FALSE
  )
}
rdhs_config_path <- "rdhs.json"
if (!file.create(rdhs_config_path)) {
  stop("Could not create a temporary rdhs configuration file.", call. = FALSE)
}
tryCatch(
  set_rdhs_config(email = "lhug@unicef.org",
                  project = "UN Child mortality estimation",
                  cache_path = dhs_cache_path,
                  config_path = rdhs_config_path,
                  global = FALSE,
                  password_prompt = FALSE,
                  prompt = nzchar(rdhs_password)),
  finally = unlink(rdhs_config_path)
)
rm(rdhs_password)

# 
# update_rdhs_config(email = "lhug@unicef.org", password = TRUE,
#                    project = "UN Child mortality estimation")

capitalize_words <- function(s) {
  sapply(strsplit(s, " "), function(words) {
    paste(toupper(substring(words, 1, 1)), tolower(substring(words, 2)), sep = "", collapse = " ")
  }, USE.NAMES = FALSE)
}

get_survey_exclusions <- function() {
  if (!exists("survey_excluded", inherits = TRUE) ||
      is.null(survey_excluded) ||
      length(survey_excluded) == 0) {
    return(numeric(0))
  }
  as.numeric(survey_excluded)
}


use_path_base(data.dir)

# Load polygon files ----------------------------------------------------------

print(poly.path)
if (identical(country, "Madagascar")) {
  sf::sf_use_s2(FALSE)
}
# load the national shape file
poly.adm0 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm0, options = "ENCODING=UTF-8")

# use encoding to read special characters
# load the shape file of admin-1 regions
poly.adm1 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm1, options = "ENCODING=UTF-8")
poly.adm1[[poly.label.adm1]] <- repair_utf8_text(
  poly.adm1[[poly.label.adm1]]
)

if(exists('poly.layer.adm2')){
  # load the shape file of admin-2 regions
  poly.adm2 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm2, options = "ENCODING=UTF-8")
  poly.adm2[[poly.label.adm2]] <- repair_utf8_text(
    poly.adm2[[poly.label.adm2]]
  )
  if (poly.label.adm1 %in% names(poly.adm2)) {
    poly.adm2[[poly.label.adm1]] <- repair_utf8_text(
      poly.adm2[[poly.label.adm1]]
    )
  }
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

# Create Adjacency Matrix ----------------------------------------------------------

# Adjacency matrix is a symmetric matrix with each entry of 1's or 0's indicating if the two administrative regions are adjacent. 
# Each row or column represents an administrative region.
# The codes below generates spatial adjacency matrix based on the spatial polygon file.


if (exists("poly.adm1")) {
  # Create adjacency matrix using sf object
  admin1.nb <- spdep::poly2nb(st_geometry(poly.adm1))  # No need to extract @polygons
  admin1.mat <- nb2mat(admin1.nb, zero.policy = TRUE)
  # Set row/col names
  colnames(admin1.mat) <- rownames(admin1.mat) <- paste0("admin1_", 1:nrow(admin1.mat))
  
  # Create name mapping
  admin1.names <- data.frame(
    GeoRepo = poly.adm1[[poly.label.adm1]],
    Internal = rownames(admin1.mat)
  )
} else {
  message("There is no Admin1 polygon file.")
}

if(exists("poly.adm2")){  # create the adjacency matrix for admin2 regions.
  # Create adjacency list from geometry
  admin2.nb <- poly2nb(st_geometry(poly.adm2))
  
  # Convert to adjacency matrix
  admin2.mat <- nb2mat(admin2.nb, zero.policy = TRUE)
  
  # Set matrix row/column names
  colnames(admin2.mat) <- rownames(admin2.mat) <- paste0("admin2_", 1:nrow(admin2.mat))
  # Create mapping table between GeoRepo name and internal ID
  admin2.names <- data.frame(
    GeoRepo = poly.adm2[[poly.label.adm2]],  # e.g., poly.label.adm2 <- "NAME_2"
    Internal = rownames(admin2.mat)
  )
}else{
  message("There is no Admin2 polygon file.")
}

if(exists("poly.adm2")){
  save(admin1.mat, admin2.mat, file = file.path(poly.path, paste0(country, "_Amat.rda"))) # save the admin1 and admin2 adjacency matrix
  save(admin1.names, admin2.names, file = file.path(poly.path, paste0(country, "_Amat_Names.rda"))) # save the admin1 and admin2 names
}else{
  save(admin1.mat, file = file.path(poly.path, paste0(country, "_Amat.rda")))
  save(admin1.names, file = file.path(poly.path, paste0(country, "_Amat_Names.rda")))
}

# Polygon Plots ----------------------------------------------------------

if(!dir.exists(file.path(res.dir, "Figures", "ShapeCheck"))){
  dir.create(file.path(res.dir, "Figures", "ShapeCheck"), recursive = TRUE)
}

cent <- st_coordinates(st_centroid(poly.adm1))
cols <- rainbow(min(10,
                    dim(admin1.mat)[1]))

### Admin1 neighbors ####
admin1_neighb_file <- file.path(
  res.dir,
  "Figures",
  "ShapeCheck",
  paste0(country, "_adm1_neighb.pdf")
)
pdf(admin1_neighb_file,
    height = 4, width = 4)
{
  plot(st_geometry(poly.adm1), col = cols, border = NA, axes = FALSE)
  
  for(i in 1:dim(cent)[1]){
    neighbs <- which(admin1.mat[i,] != 0)
    if(length(neighbs) != 0){
      for(j in 1:length(neighbs)){
        ends <- cent[neighbs,]
        segments(x0 = cent[i, 1],
                 y0 = cent[i, 2],
                 x1 = cent[neighbs[j], 1],
                 y1 = cent[neighbs[j], 2],
                 col = 'black')
      }
    }
  }
}
dev.off()

### Admin2 neighbors ####
if(exists("admin2.mat")){
  
  cent <- st_coordinates(st_centroid(poly.adm2))
  cols <- rainbow(min(10,
                      dim(admin2.mat)[1]))
  
  admin2_neighb_file <- file.path(
    res.dir,
    "Figures",
    "ShapeCheck",
    paste0(country, "_adm2_neighb.pdf")
  )
  pdf(admin2_neighb_file,
      height = 4, width = 4)
  {
    plot(st_geometry(poly.adm2), col = cols, border = NA, axes = FALSE)
    for(i in 1:dim(cent)[1]){
      neighbs <- which(admin2.mat[i,] != 0)
      if(length(neighbs) != 0){
        for(j in 1:length(neighbs)){
          ends <- cent[neighbs,]
          segments(x0 = cent[i, 1],
                   y0 = cent[i, 2],
                   x1 = cent[neighbs[j], 1],
                   y1 = cent[neighbs[j], 2], 
                   col = 'black')
        }
      }
    }
  }
  dev.off()
}

# Find DHS surveys ----------------------------------------------------------
#get country ID
if (!exists("dhs_survey_year_start", inherits = TRUE)) {
  dhs_survey_year_start <- 2000
}

countryId <- rdhs::dhs_countries()[dhs_countries()$ISO3_CountryCode==toupper(iso0),]

potential_surveys <- data.frame()
if (nrow(countryId) > 0) {
  potential_surveys <- tryCatch({
    rdhs::dhs_datasets(countryIds = countryId$DHS_CountryCode,
                       surveyYearStart = dhs_survey_year_start) %>%
      dplyr::filter((FileType == 'Births Recode' & FileFormat=='SPSS dataset (.sav)') |
                      (FileType == 'Geographic Data' & FileFormat =='Flat ASCII data (.dat)'))
  }, error = function(err) {
    message("No DHS datasets found for ", country, ": ", conditionMessage(err))
    data.frame()
  })
}

if (nrow(potential_surveys) > 0) {
  dhs_recode_config <- if (exists("dhs_admin1_from_recode", inherits = TRUE)) {
    dhs_admin1_from_recode
  } else {
    NULL
  }
  surveys <- select_dhs_surveys_for_processing(
    potential_surveys,
    config = dhs_recode_config,
    survey_ids = if (exists("dhs_survey_ids", inherits = TRUE)) {
      dhs_survey_ids
    } else {
      NULL
    }
  ) %>%
    group_by(SurveyYear) %>%
    arrange(SurveyYear, DatasetType)
  dhs_survey_years <- as.numeric(unique(surveys$SurveyYear))
  excluded_surveys <- get_survey_exclusions()
  if (length(excluded_surveys) > 0) {
    excluded_dhs <- intersect(dhs_survey_years, excluded_surveys)
    if (length(excluded_dhs) > 0) {
      message("Excluding DHS survey year(s) for ", country, ": ",
              paste(excluded_dhs, collapse = ", "))
    }
    surveys <- surveys %>% dplyr::filter(!SurveyYear %in% excluded_surveys)
    dhs_survey_years <- setdiff(dhs_survey_years, excluded_surveys)
  }
  
  # CHECK THAT SURVEYS FOR CORRECT COUNTRY HAVE BEEN CHOSEN
  unique(surveys$CountryName)
} else {
  surveys <- data.frame()
  dhs_survey_years <- numeric(0)
  dhs_recode_config <- NULL
  message("No DHS surveys to process for ", country, "; continuing with MICS inputs.")
}

# Download DHS files from the DHS API into the project layout used below.
if (length(dhs_survey_years) > 0) {
  dir_DHS_data <- file.path(home.dir, "Data/DHS", unique(surveys$CountryName))
  for(survey_year in dhs_survey_years){
    survey_files <- surveys[surveys$SurveyYear == survey_year, ]$FileName
    ensure_dhs_survey_files(
      survey_files = survey_files,
      survey_year = survey_year,
      country_name = unique(surveys$CountryName),
      dhs_root = file.path(home.dir, "Data/DHS")
    )
  }
}

# Process data for each DHS survey year ----------------------------------------------------------

# The codes below first loads the raw DHS data, then it assigns the GPS
# coordinates to each sampling cluster and admin regions where the sampling is
# conducted and assigns the admin regions where the clusters are located.

# first check if all data exists
for(survey_year in dhs_survey_years){
  
  dhs.svy.ind <- which(dhs_survey_years==survey_year)
  surveys[surveys$SurveyYear==survey_year, ]
  filename_BR  <- surveys[surveys$SurveyYear==survey_year & surveys$FileType == "Births Recode",]$FileName
  filename_Geo <- surveys[surveys$SurveyYear==survey_year & surveys$FileType == "Geographic Data",]$FileName
  filename_BR <- toupper(gsub(".zip", "",  filename_BR, ignore.case = TRUE))
  filename_Geo <- toupper(gsub(".zip", "",  filename_Geo, ignore.case = TRUE))
  cname0 <- unique(surveys$CountryName)
  use_admin1_recode <- is_dhs_admin1_recode_survey(
    dhs_recode_config,
    survey_year
  ) && length(filename_Geo) == 0L
  
  message('Processing DHS data for ', country,' ', survey_year,'\n')
  
  # no longer work from API:
  # data.paths.tmp <- get_datasets(surveys[surveys$SurveyYear==survey_year,]$FileName, clear_cache = T)
  
  # we save the data in dir_DHS_data by year 
  dir_DHS_data <- file.path(home.dir, "Data/DHS", cname0)
  if (!use_admin1_recode) {
    stopifnot(length(filename_Geo) == 1L)
    stopifnot(dir.exists(file.path(dir_DHS_data, survey_year, filename_Geo)))
  }
  dir_DHS_BR <- list.files(file.path(dir_DHS_data, survey_year), pattern = ".SAV", ignore.case = TRUE, full.names = TRUE, recursive = TRUE)
  stopifnot(length(dir_DHS_BR) == 1)
  message("Use BR data: ", dir_DHS_BR)
  if (use_admin1_recode) {
    message("No DHS GPS file; assigning Admin-1 from the configured births-recode variable.")
  } else {
    message("Use Geo data in :", file.path(dir_DHS_data, survey_year, filename_Geo))
  }
}

for(survey_year in dhs_survey_years){
  
    dhs.svy.ind <- which(dhs_survey_years==survey_year)
    surveys[surveys$SurveyYear==survey_year, ]
    filename_BR  <- surveys[surveys$SurveyYear==survey_year & surveys$FileType == "Births Recode",]$FileName
    filename_Geo <- surveys[surveys$SurveyYear==survey_year & surveys$FileType == "Geographic Data",]$FileName
    filename_BR <- toupper(gsub(".zip", "",  filename_BR, ignore.case = TRUE))
    filename_Geo <- toupper(gsub(".zip", "",  filename_Geo, ignore.case = TRUE))
    cname0 <- unique(surveys$CountryName)
    use_admin1_recode <- is_dhs_admin1_recode_survey(
      dhs_recode_config,
      survey_year
    ) && length(filename_Geo) == 0L
    
    message('Processing DHS data for ', country,' ', survey_year,'\n')
    
    # no longer work from API:
    # data.paths.tmp <- get_datasets(surveys[surveys$SurveyYear==survey_year,]$FileName, clear_cache = T)
    
    # we save the data in dir_DHS_data by year 
    dir_DHS_data <- file.path(home.dir, "Data/DHS", cname0)
    if (!use_admin1_recode) {
      stopifnot(length(filename_Geo) == 1L)
      stopifnot(dir.exists(file.path(dir_DHS_data, survey_year, filename_Geo)))
    }
    
    dir_DHS_BR <- list.files(file.path(dir_DHS_data, survey_year), pattern = ".SAV", ignore.case = TRUE, full.names = TRUE, recursive = TRUE)
    stopifnot(length(dir_DHS_BR) == 1)
    message("Use BR data :", dir_DHS_BR)
    if (use_admin1_recode) {
      message("No DHS GPS file; assigning Admin-1 from the configured births-recode variable.")
    } else {
      message("Use Geo data in :", file.path(dir_DHS_data, survey_year, filename_Geo))
    }
    
    raw.dat.tmp <- haven::read_spss(dir_DHS_BR)
  
    names(raw.dat.tmp) <- tolower(names(raw.dat.tmp)) # convert all variable names to lower case
    
    # convert some variables to factors
    alive <- attr(raw.dat.tmp$b5, which = "labels")
    names(alive) <- tolower(names(alive))
    raw.dat.tmp$b5 <- ifelse(raw.dat.tmp$b5 == alive["yes"][[1]], "yes", "no")
    raw.dat.tmp$b5 <- factor(raw.dat.tmp$b5, levels = c("yes", "no"))
    
    strat <- attr(raw.dat.tmp$v025,which='labels')
    names(strat) <- tolower(names(strat))
    raw.dat.tmp$v025 <- ifelse(raw.dat.tmp$v025 == strat["urban"][[1]],'urban','rural')
    raw.dat.tmp$v025 <- factor(raw.dat.tmp$v025, levels = c('urban','rural'))
    if (use_admin1_recode) {
      urbanicity_fix <- harmonize_dhs_cluster_urbanicity(raw.dat.tmp)
      raw.dat.tmp <- urbanicity_fix$data
      if (nrow(urbanicity_fix$repairs) > 0L) {
        message(
          "Harmonized DHS cluster urbanicity by unique-respondent mode: ",
          paste(
            urbanicity_fix$repairs$cluster,
            urbanicity_fix$repairs$selected,
            sep = "=",
            collapse = ", "
          )
        )
      }
    }
    
    # Extract current labels
    lab_vec <- attributes(raw.dat.tmp$v024)$labels
    
    # The configured no-GPS path maps the published labels explicitly. GPS
    # surveys retain the historical presentation-only capitalization.
    if (!use_admin1_recode) {
      names(lab_vec) <- capitalize_words(names(lab_vec))
    }
    
    # Set the modified labels back
    attributes(raw.dat.tmp$v024)$labels <- lab_vec
    
    message("DHS survey ", survey_year, " regions are: ", paste(names(attributes(raw.dat.tmp$v024)$labels), collapse = ", "))
    if (use_admin1_recode) {
      admin1_variable <- tolower(as.character(dhs_recode_config$variable))
      raw.dat.tmp[[admin1_variable]] <- dhs_labelled_admin1_names(
        raw.dat.tmp[[admin1_variable]],
        admin1_variable
      )
    }
    if (use_admin1_recode) {
      cmc.adjust <- dhs_admin1_recode_cmc_adjust(
        dhs_recode_config,
        survey_year,
        default = 0
      )
    } else if(country=='Ethiopia'){
      cmc.adjust <- 92
    }else if(country=='Nepal'){
      cmc.adjust <- -681
    }else{cmc.adjust <- 0}
    
    if(country=='Pakistan' & survey_year==2017){
      raw.dat.tmp[raw.dat.tmp$v005==0,]$v005 <- raw.dat.tmp[raw.dat.tmp$v005==0,]$sv005
    }
    
    # dat.tmp get birth 
    dat.tmp <- getBirths(data = raw.dat.tmp, 
                     surveyyear = survey_year,
                     year.cut = seq(beg.year, survey_year + 1, 1),
                     cmc.adjust = cmc.adjust,compact = T)

    # retrieve the some columns of the full data
    dat.tmp <- dat.tmp[ ,c("v001", "v024", "time", "total",
                       "age", "v005", "v025", "strata", "died")]

    if (use_admin1_recode) {
      if (exists("poly.adm2")) {
        stop(
          "DHS Admin-1 assignment from a births recode supports Admin-1-only runs; ",
          "remove the Admin-2 layer or provide DHS geographic data.",
          call. = FALSE
        )
      }

      dat.tmp <- attach_dhs_admin1_from_recode(
        dat = dat.tmp,
        georepo_names = poly.adm1[[poly.label.adm1]],
        config = dhs_recode_config,
        survey_year = survey_year
      )
      dat.tmp <- dat.tmp %>%
        select(cluster = v001, age, years = time, total, Y = died, v005,
               urban = v025, LONGNUM, LATNUM, strata, admin1,
               admin1.char, admin1.name)
      message("Assigned DHS Admin-1 from the validated births-recode labels.")
    } else {

    # specify the name of DHS GPS file, which contains the GPS coordinates of the sampling cluster where the data is sampled
    # points <- readRDS(paste0(data.paths.tmp[1]))
    points <- sf::st_read(dsn = file.path(dir_DHS_data, survey_year, filename_Geo), options = "ENCODING=UTF-8")
    
    # detect points in the DHS GPS file with mis-specified coordinates and remove them if any
    wrong.points <- which(points$LATNUM == 0.0 & points$LONGNUM == 0.0)
    if (length(wrong.points) > 0) message("There are wrong GPS points: (Longitude, Latitude) = (0, 0)")
    if (length(wrong.points) > 0) {
      points <- points[-wrong.points, ]
    }

    
    # Assign coordinates to survey respondents
    dat.tmp <- dat.tmp %>%
      left_join(st_drop_geometry(points)[, c("DHSCLUST", "LATNUM", "LONGNUM")], by = c("v001" = "DHSCLUST")) 
    
    # Drop any (0,0) remaining rows
    dat.tmp <- dat.tmp[!(dat.tmp$LATNUM == 0 & dat.tmp$LONGNUM == 0), ]
    dat.tmp <- dat.tmp[!(is.na(dat.tmp$LATNUM)|is.na(dat.tmp$LONGNUM)), ]
    
    message("\n Assigned LAT & LONG")

    # Convert data frame to spatial object using sf
    dat.points <- st_as_sf(dat.tmp, coords = c("LONGNUM", "LATNUM"), crs = st_crs(poly.adm1))
    
    # Assign administrative units
    if (exists("poly.adm2")) {
      dat.points <- st_join(dat.points, poly.adm2, join = st_within, left = TRUE)
      colnames(dat.points) <- gsub("\\.x$", "", colnames(dat.points))  # remove ".x" suffix from column names
      # Handle missing assignments
      missing_adm2 <- which(is.na(dat.points[[poly.label.adm2]]))
      if (length(missing_adm2) > 0) {
        message("Some points not matched to Admin2. Using nearest polygon.")
        nearest_adm2 <- st_nearest_feature(dat.points[missing_adm2, ], poly.adm2)
        dat.points[missing_adm2, poly.label.adm2] <- poly.adm2[[poly.label.adm2]][nearest_adm2]
      }
      
      dat.points$admin2 <- st_nearest_feature(dat.points, poly.adm2)
      dat.points$admin2.char <- paste0("admin2_", dat.points$admin2)
      dat.points$admin2.name <- dat.points[[poly.label.adm2]]
    } else {
      dat.points$admin2 <- dat.points$admin2.name <- NA
      message("There is no Admin2 polygon to assign points to.")
    }
    
    if (exists("poly.adm1")) {
      colnames(dat.points)
      dat.points <- st_join(dat.points, poly.adm1, join = st_within, left = TRUE)
      colnames(dat.points) <- gsub("\\.x$", "", colnames(dat.points)) # YL remove ".x" suffix from column names
      
      missing_adm1 <- which(is.na(dat.points[[poly.label.adm1]]))
      if (length(missing_adm1) > 0) {
        message("Some points not matched to Admin1. Using nearest polygon.")
        nearest_adm1 <- st_nearest_feature(dat.points[missing_adm1, ], poly.adm1)
        dat.points[missing_adm1, poly.label.adm1] <- poly.adm1[[poly.label.adm1]][nearest_adm1]
      }
      
      dat.points$admin1 <- st_nearest_feature(dat.points, poly.adm1)
      dat.points$admin1.char <- paste0("admin1_", dat.points$admin1)
      dat.points$admin1.name <- dat.points[[poly.label.adm1]]
    } else {
      dat.points$admin1 <- dat.points$admin1.name <- NA
      message("There is no Admin1 polygon to assign points to.")
    }
    
    # Convert back to data.frame and keep only needed columns
    coords <- st_coordinates(dat.points)
    dat.points$LONGNUM <- coords[, "X"]
    dat.points$LATNUM  <- coords[, "Y"]
    dat.tmp <- st_drop_geometry(dat.points)
    # remove the extra joined columns, ".x" -> ""
    
    # Final formatting
    if (exists("poly.adm2")) {
      dat.tmp <- dat.tmp %>%
        select(cluster = v001, age, years = time, total, Y = died, v005, urban = v025,
               LONGNUM, LATNUM, strata,
               admin1, admin2, admin1.char, admin2.char, admin1.name, admin2.name)
    } else {
      dat.tmp <- dat.tmp %>%
        select(cluster = v001, age, years = time, total, Y = died, v005, urban = v025,
               LONGNUM, LATNUM, strata,
               admin1, admin1.char, admin1.name)
    }
    }
    
    # Survey metadata
    dat.tmp$survey <- raw.dat.tmp$survey_year <- survey_year
    dat.tmp$survey.type <- 'DHS'
    
    # Stack into full dataset
    if (survey_year == dhs_survey_years[1]) {
      mod.dat <- dat.tmp
      raw.dat <- raw.dat.tmp[, c("caseid", "b5", "b7", "survey_year")]
    } else {
      mod.dat <- bind_rows(mod.dat, dat.tmp)
      raw.dat <- bind_rows(raw.dat, raw.dat.tmp[, c("caseid", "b5", "b7", "survey_year")])
    }
  
}

if (exists("mod.dat")) {
  mod.dat.DHS <- mod.dat
  dim(mod.dat) 
} else {
  mod.dat <- NULL
  raw.dat <- NULL
  message("No DHS data processed for ", country, "; MICS will initialize mod.dat.")
}

# Process data for each MICS survey year ----------------------------------------------------------
# for preprocessing, please use MICS_DataProcessing.R

mics.dir <- file.path(home.dir, "Data/MICS", country)
dir.create(mics.dir, recursive = TRUE, showWarnings = FALSE)

admin1_wanted <- if (is.null(mod.dat)) {
  sort(unique(stats::na.omit(poly.adm1[[poly.label.adm1]])))
} else {
  sort(unique(stats::na.omit(mod.dat$admin1.name)))
}
saveRDS(admin1_wanted, file.path(mics.dir, "admin1.name.rds"))

if (!is.null(mod.dat) && "admin2.name" %in% names(mod.dat)) {
  admin2_wanted <- sort(unique(stats::na.omit(mod.dat$admin2.name)))
  saveRDS(admin2_wanted, file.path(mics.dir, "admin2.name.rds"))
}

if (dir.exists(mics.dir)) {

  mics_files <- select_mics_tmp_files(mics.dir)
  if (length(mics_files) == 0) {
    message("No MICS tmp files found for ", country, "; continuing with DHS only.")
  } else {
  
  #make admin key
  if (exists("poly.adm2")){
    mics.keys <- make_optional_mics_admin_keys(
      mod.dat = mod.dat,
      poly.adm1 = poly.adm1,
      poly.label.adm1 = poly.label.adm1
    )
    admin2.key <- mics.keys$admin2
    admin1.key <- mics.keys$admin1
    
    for(k in seq_along(mics_files)){
      
      mics_env <- new.env(parent = emptyenv())
      load(file = mics_files[k], envir = mics_env)
      if (!exists("dat.tmp", envir = mics_env, inherits = FALSE)) {
        stop("Expected dat.tmp in ", mics_files[k], call. = FALSE)
      }
      dat.tmp <- get("dat.tmp", envir = mics_env)
      
      #match admin area codes
      admin2_values <- if ("admin2.name" %in% names(dat.tmp)) {
        unique(as.character(dat.tmp$admin2.name[
          !is.na(dat.tmp$admin2.name) & nzchar(trimws(dat.tmp$admin2.name))
        ]))
      } else {
        character(0)
      }

      geospatial_admin2_columns <- c(
        "LONGNUM", "LATNUM", "admin1", "admin2", "admin1.char",
        "admin2.char", "admin1.name", "admin2.name"
      )
      has_geospatial_admin2 <- length(admin2_values) > 0 &&
        all(geospatial_admin2_columns %in% names(dat.tmp)) &&
        any(!is.na(dat.tmp$LONGNUM) & !is.na(dat.tmp$LATNUM))

      if (has_geospatial_admin2) {
        dat.tmp <- validate_mics_geospatial_admin2(
          dat.tmp,
          admin1_names = poly.adm1[[poly.label.adm1]],
          admin2_names = poly.adm2[[poly.label.adm2]],
          mics_file = mics_files[k]
        )
        mics_admin_level <- "admin2 (geospatial)"
      } else if (length(admin2_values) > 0 && !is.null(admin2.key) &&
          all(admin2_values %in% admin2.key$admin2.name)) {
        dat.tmp <- attach_mics_admin2_key(dat.tmp, admin2.key, mics_files[k])
        mics_admin_level <- "admin2"
      } else {
        if (length(admin2_values) > 0 && is.null(admin2.key)) {
          stop(
            "Non-geospatial MICS Admin-2 labels in ", mics_files[k],
            " cannot be matched because no DHS-derived Admin-2 key is available.",
            call. = FALSE
          )
        }
        if (!("admin1.name" %in% names(dat.tmp))) {
          if ("admin2.name" %in% names(dat.tmp)) {
            dat.tmp$admin1.name <- dat.tmp$admin2.name
          } else {
            stop("MICS data in ", mics_files[k],
                 " must include admin1.name or admin2.name.",
                 call. = FALSE)
          }
        }
        dat.tmp <- attach_mics_admin1_key(dat.tmp, admin1.key, mics_files[k])
        mics_admin_level <- "admin1"
      }
      
      #prepare to merge with DHS data
      dat.tmp <- dat.tmp[,c("cluster",'age','years','total','Y','v005','urban',"LONGNUM","LATNUM",'strata','admin1','admin2',
                            'admin1.char','admin2.char','admin1.name','admin2.name','survey','survey.type')]
      
      #add to prepared data
      mod.dat <- rbind(mod.dat,dat.tmp)
      message('Processing MICS data for ', mics_files[k],
              ' at ', mics_admin_level, ' level\n')
    }
  } else{
    
  admin.key <- if (is.null(mod.dat)) {
    data.frame(
      admin1 = seq_len(nrow(poly.adm1)),
      admin1.char = paste0("admin1_", seq_len(nrow(poly.adm1))),
      admin1.name = poly.adm1[[poly.label.adm1]]
    )
  } else {
    mod.dat %>%
      dplyr::select(admin1, admin1.char, admin1.name) %>%
      distinct()
  }
    
    for(k in seq_along(mics_files)){
      
      load(file = mics_files[k])
      
      #match admin area codes
      dat.tmp$admin1 <- dat.tmp$strata <- NA
      dat.tmp$admin1.char <-  ''
      
      stopifnot(all(dat.tmp$admin1.name %in% admin.key$admin1.name)) # match by admin1.name
      for(perm in 1:nrow(admin.key)){
        perm.ind <- dat.tmp$admin1.name==admin.key$admin1.name[perm]
        dat.tmp$admin1[perm.ind] <- admin.key$admin1[perm]
        dat.tmp$admin1.char[perm.ind] <- admin.key$admin1.char[perm]
        dat.tmp$strata[perm.ind] <- if ("strata" %in% names(admin.key)) {
          admin.key$strata[perm]
        } else {
          paste0(admin.key$admin1[perm], ":", dat.tmp$urban[perm.ind])
        }
      }
      
      #prepare to merge with DHS data
      dat.tmp <- ensure_mics_coordinate_columns(dat.tmp)
      dat.tmp$survey.type <- 'MICS'
      dat.tmp <- dat.tmp[,c("cluster",'age','years','total','Y','v005','urban',"LONGNUM","LATNUM",'strata','admin1',
                            'admin1.char','admin1.name','survey','survey.type')]
      
      #add to prepared data
      mod.dat <- rbind(mod.dat, dat.tmp)
      message('Processing MICS data for ', mics_files[k],'\n')
    }
  }
  }
}

mod.dat <- mod.dat %>% distinct()

excluded_surveys <- get_survey_exclusions()
if (length(excluded_surveys) > 0) {
  before_exclusion <- nrow(mod.dat)
  mod.dat <- mod.dat[!mod.dat$survey %in% excluded_surveys, ]
  if (!is.null(raw.dat) && "survey_year" %in% names(raw.dat)) {
    raw.dat <- raw.dat[!raw.dat$survey_year %in% excluded_surveys, ]
  }
  message("Survey exclusion removed ", before_exclusion - nrow(mod.dat),
          " rows for ", country, ".")
}


table(mod.dat$survey)
table(mod.dat$years)
dim(mod.dat) 


# Change cluster numbers to get rid of duplicates ----------------------------------------------------------
clusters <- unique(mod.dat[,c("cluster","survey")])
clusters$cluster.new <- 1:nrow(clusters)
mod.dat <- merge(mod.dat, clusters, by=c('cluster','survey'))
mod.dat$cluster <- mod.dat$cluster.new
mod.dat <- mod.dat[,!(names(mod.dat)=='cluster.new')]

survey_years <- sort(unique(mod.dat$survey))
mod.dat$survey.id<- unlist(sapply(1:nrow(mod.dat),function(x){which(mod.dat$survey[x] ==survey_years)}))

# Use raw data to calculate age band intercept priors for benchmarking ----------------------------------------------------------
if (!is.null(raw.dat) && is.factor(raw.dat$b5)) {
  raw.u5mr <- nrow(raw.dat[raw.dat$b7<60 & tolower(as.character(raw.dat$b5))=="no",])/nrow(raw.dat)
  int.priors.bench <- c(nrow(raw.dat[raw.dat$b7==0 & tolower(as.character(raw.dat$b5))=="no",])/nrow(raw.dat)*(1/raw.u5mr), #<1 month
                        nrow(raw.dat[(raw.dat$b7 %in% 1:11) & tolower(as.character(raw.dat$b5))=="no",])/nrow(raw.dat[raw.dat$b7>=1 | raw.dat$b5==1,])*(1/raw.u5mr), #1-11 months  
                        nrow(raw.dat[(raw.dat$b7 %in% 12:23) & tolower(as.character(raw.dat$b5))=="no",])/nrow(raw.dat[raw.dat$b7>=12 | raw.dat$b5==1,])*(1/raw.u5mr), #12-23 months  
                        nrow(raw.dat[(raw.dat$b7 %in% 24:35) & tolower(as.character(raw.dat$b5))=="no",])/nrow(raw.dat[raw.dat$b7>=24 | raw.dat$b5==1,])*(1/raw.u5mr), #24-35 months  
                        nrow(raw.dat[(raw.dat$b7 %in% 36:47) & tolower(as.character(raw.dat$b5))=="no",])/nrow(raw.dat[raw.dat$b7>=36 | raw.dat$b5==1,])*(1/raw.u5mr), #36-47 months  
                        nrow(raw.dat[(raw.dat$b7 %in% 48:59) & tolower(as.character(raw.dat$b5))=="no",])/nrow(raw.dat[raw.dat$b7>=48 | raw.dat$b5==1,])*(1/raw.u5mr)) #48-59 months
} else if (!is.null(raw.dat)) {
  raw.u5mr <- nrow(raw.dat[raw.dat$b7<60 & raw.dat$b5==0,])/nrow(raw.dat)
  int.priors.bench <- c(nrow(raw.dat[raw.dat$b7==0 & raw.dat$b5==0,])/nrow(raw.dat)*(1/raw.u5mr), #<1 month
                        nrow(raw.dat[(raw.dat$b7 %in% 1:11) & raw.dat$b5==0,])/nrow(raw.dat[raw.dat$b7>=1 | raw.dat$b5==1,])*(1/raw.u5mr), #1-11 months  
                        nrow(raw.dat[(raw.dat$b7 %in% 12:23) & raw.dat$b5==0,])/nrow(raw.dat[raw.dat$b7>=12 | raw.dat$b5==1,])*(1/raw.u5mr), #12-23 months  
                        nrow(raw.dat[(raw.dat$b7 %in% 24:35) & raw.dat$b5==0,])/nrow(raw.dat[raw.dat$b7>=24 | raw.dat$b5==1,])*(1/raw.u5mr), #24-35 months  
                        nrow(raw.dat[(raw.dat$b7 %in% 36:47) & raw.dat$b5==0,])/nrow(raw.dat[raw.dat$b7>=36 | raw.dat$b5==1,])*(1/raw.u5mr), #36-47 months  
                        nrow(raw.dat[(raw.dat$b7 %in% 48:59) & raw.dat$b5==0,])/nrow(raw.dat[raw.dat$b7>=48 | raw.dat$b5==1,])*(1/raw.u5mr)) #48-59 months
} else {
  int.priors.bench <- rep(NA_real_, 6)
  message("No DHS raw data available for ", country, "; saving NA age intercept benchmark priors.")
}
# Fix any special cases ----------------------------------------------------------
if(country=='Malawi'){
  mod.dat <- repair_malawi_kasungu_admin(mod.dat)
}
if(country=='Guinea'){
  mod.dat <- mod.dat[!(mod.dat$years==2018),]
}
if(country=='Ghana'){
  mod.dat <- mod.dat[!(mod.dat$years==2018),]
}

# Save processed data  ----------------------------------------------------------

save(mod.dat, file = paste0(country,'_cluster_dat.rda'))
save(int.priors.bench, file = paste0(country,'_age_int_priors_bench.rda'))


# below is moved from 7b


# take out surveys from different sampling frame
# if all surveys are from the same sampling frame, then no need to filter
use_path_base(data.dir)
load(paste0(country,'_cluster_dat.rda'))

survey_years <- if (exists("surveys_1frame") && !is.null(surveys_1frame)) {
  surveys_1frame
} else {
  sort(unique(mod.dat$survey))
}
mod.dat <- mod.dat[mod.dat$survey %in% survey_years,] #
table(mod.dat$survey)
save(mod.dat, file=paste0(country,'_cluster_dat_1frame.rda'))

message("Data processing completed successfully for ", country, ".")

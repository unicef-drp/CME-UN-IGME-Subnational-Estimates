USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
source(file.path(dir_subnational, "Rcode/_supporting_scripts/urban_frame_matching.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}

# Run UR_thresholding.R to obtain urban/rural sampling weights to be used in the
# Beta-binomial model. At the top of the script, make sure to specify (1) the
# country, (2) the frame year being used, and (3) the survey years that used
# this census frame (also available in the Country Info Sheet)

# UR_thresholding.R
# Country context is loaded by Rcode/1_Preperation.R.

if (!exists("frame_year", inherits = TRUE) || is.null(frame_year)) {
  stop("Set frame_year in Info/", country,
       "_general_info.json before running this step.",
       call. = FALSE)
}
frame_runs <- list(
  list(
    survey_years = if (exists("surveys_1frame", inherits = TRUE) &&
                       !is.null(surveys_1frame)) {
      surveys_1frame
    } else {
      stop("Set surveys_1frame in Info/", country,
           "_general_info.json before running this step.",
           call. = FALSE)
    },
    frame_year = frame_year[1],
    output_suffix = ""
  )
)

# Load libraries and info ----------------------------------------------------------

options(gsubfn.engine = "R")
library(sf)
library(terra)
# library(rgdal)
# library(rgeos)
library(raster)
library(sqldf)
library(geosphere)
library(Matrix)
library(openxlsx)

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
    code.path <- normalizePath("Rcode/7b_UR_thresholding_sf.R",
                               winslash = "/", mustWork = TRUE)
  }
}
code.path.splitted <- strsplit(code.path, "/")[[1]]

home.dir <- project_home()
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
population_dir <- population_raster_dir(country)
dir.create(population_dir, recursive = TRUE, showWarnings = FALSE)
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
require_country_context()
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}

use_path_base(res.dir)
required_ur_output_dirs <- c(
  file.path("UR", "Threshold"),
  file.path("UR", "U1_fraction"),
  file.path("UR", "U5_fraction")
)
for (output_dir in required_ur_output_dirs) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
}

# Load Polygons ----------------------------------------------------------

use_path_base(data.dir)

# load the national shape file
poly.adm0 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm0, options = "ENCODING=UTF-8")

# use encoding to read special characters
# load the shape file of admin-1 regions
poly.adm1 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm1, options = "ENCODING=UTF-8")
poly.adm1 <- repair_utf8_columns(poly.adm1)

if(exists('poly.layer.adm2')){
  # load the shape file of admin-2 regions
  poly.adm2 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm2, options = "ENCODING=UTF-8")
  poly.adm2 <- repair_utf8_columns(poly.adm2)
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
admin1.names <- repair_utf8_columns(admin1.names)
if (exists("admin2.names")) {
  admin2.names <- repair_utf8_columns(admin2.names)
}
admin1_name_col <- if ("GeoRepo" %in% names(admin1.names)) {
  "GeoRepo"
} else {
  "GADM"
}
if (exists("admin2.names")) {
  admin2_name_col <- if ("GeoRepo" %in% names(admin2.names)) {
    "GeoRepo"
  } else {
    "GADM"
  }
}

for (frame_run in frame_runs) {
  survey_years <- frame_run$survey_years
  frame_year <- frame_run$frame_year
  frame_output_suffix <- frame_run$output_suffix
  
  message("Processing ", country, " frame ", frame_year,
          " for surveys: ", paste(survey_years, collapse = ", "))
  
  ref_tab_file <- file.path(res.dir, "UR", paste0("urb_prop_", frame_year, ".rda"))
  if (!file.exists(ref_tab_file) && frame_output_suffix == "") {
    ref_tab_file <- file.path(res.dir, "UR", "urb_prop.rda")
  }
  if (!file.exists(ref_tab_file)) {
    stop("Missing urban proportion reference table for frame ", frame_year,
         ". Expected: ", ref_tab_file,
         ". Run Rcode/7a_UR_prop.R first.")
  }
  load(ref_tab_file) # load sampling frame urban proportion at admin1
  ref.tab <- repair_utf8_columns(ref.tab)
  
# Load cluster data  ----------------------------------------------------------

use_path_base(data.dir)
load(paste0(country,'_cluster_dat.rda'))
mod.dat <- repair_utf8_columns(mod.dat)

# take out surveys from different sampling frame
# if all surveys are from the same sampling frame, then no need to filter

mod.dat <- mod.dat[mod.dat$survey %in% survey_years,] 

save(mod.dat, file=paste0(country,'_cluster_dat_1frame',
                          frame_output_suffix, '.rda'))

cluster_list<-mod.dat[!duplicated(mod.dat[c('cluster','survey',
                                            'LONGNUM','LATNUM')]),]

survey_years <- unique(mod.dat$survey)



# Load worldpop  ----------------------------------------------------------

pop.year <- beg.year:2020
pop.abbrev <- tolower(iso0)

  worldpop_year <- frame_year
  if(frame_year == 2023){
    file <- paste0(pop.abbrev,'_ppp_',worldpop_year,'_1km_UNadj.tif')
    url <- paste0("https://data.worldpop.org/GIS/Population/Interim/",
                  "Global_2023_1km_UNadj/unconstrained/2023/",
                  toupper(pop.abbrev),"/",
                  pop.abbrev,'_ppp_',worldpop_year,'_1km_UNadj.tif')
  }else{
    file <- paste0(pop.abbrev,'_ppp_',worldpop_year,'_1km_Aggregated_UNadj.tif')
    url <- paste0("https://data.worldpop.org/GIS/Population/Global_2000_2020_1km_UNadj/", 
                  worldpop_year, "/", toupper(pop.abbrev),"/",      
                  pop.abbrev,'_ppp_',worldpop_year,'_1km_Aggregated_UNadj.tif')
  }
  
  if(!file.exists(file.path(population_dir, file)) &&
     frame_year > 2020 && frame_year != 2023){
    available_pop_files <- list.files(population_dir,
      pattern = paste0("^", pop.abbrev,
                       "_ppp_[0-9]{4}_1km_Aggregated_UNadj\\.tif$")
    )
    available_pop_years <- as.integer(sub(
      paste0("^", pop.abbrev, "_ppp_([0-9]{4})_1km_Aggregated_UNadj\\.tif$"),
      "\\1",
      available_pop_files
    ))
    available_pop_years <- available_pop_years[available_pop_years <= 2020]
    
    if(length(available_pop_years) > 0){
      worldpop_year <- max(available_pop_years)
      file <- paste0(pop.abbrev,'_ppp_',worldpop_year,
                     '_1km_Aggregated_UNadj.tif')
      url <- paste0("https://data.worldpop.org/GIS/Population/Global_2000_2020_1km_UNadj/",
                    worldpop_year, "/", toupper(pop.abbrev),"/",
                    pop.abbrev,'_ppp_',worldpop_year,'_1km_Aggregated_UNadj.tif')
      message("No ", frame_year, " WorldPop raster found. Using ",
              worldpop_year, " population raster with the ", frame_year,
              " urban fraction reference table.")
    } else {
      worldpop_year <- 2020
      file <- paste0(pop.abbrev,'_ppp_',worldpop_year,
                     '_1km_Aggregated_UNadj.tif')
      url <- paste0("https://data.worldpop.org/GIS/Population/Global_2000_2020_1km_UNadj/",
                    worldpop_year, "/", toupper(pop.abbrev),"/",
                    pop.abbrev,'_ppp_',worldpop_year,'_1km_Aggregated_UNadj.tif')
      message("No ", frame_year, " WorldPop raster found and no local ",
              "2000-2020 fallback exists. Downloading 2020 population ",
              "raster with the ", frame_year, " urban fraction reference table.")
    }
  }
  
  population_file <- file.path(population_dir, file)
  if(!file.exists(population_file)){
    download.file(url, population_file, method = "libcurl",mode="wb")
    }
  
    # UNadjusted population counts
    worldpop <- raster(population_file)


# Define function to correct urban clusters ----------------------------------------------------------
  
  ## The function below corrects urban clusters that are misclassified to be rural due to jittering. Jittered location is not the exact location 
  ## but a randomly shifted location for the purpose of confidentiality. This may results in some urban clusters to be jittered to some rural areas, 
  ## which is unexpected to our classification algorithm and therefore correcting the misclassified clusters is of interest. 
  
  constr_prior <- function(obs,jitter_r,prob_r,poly_admin,pop_ras){
    
    tryCatch({
      
    # for the cluster, find its coordinates and admin1 area
    if(exists("poly.adm2")){
      admin1_index<-obs$admin2
    }else{
      admin1_index<-obs$admin1
    }
    sp_xy<-SpatialPoints(as.data.frame(obs)[,c('LONGNUM','LATNUM')],
                         proj4string = CRS(proj4string(poly_admin)))
    #pt<-as.data.frame(obs)[,c('LONGNUM','LATNUM')]
    #colnames(pt)<-c('x','y')
    
    # generate gitter 
    #jitter_r<-2000
    cluster_buffer<-buffer(sp_xy, width=jitter_r)
    
    # extract pixels within the buffer
    temp_pop_cir<-raster::mask(crop(pop_ras,cluster_buffer),
                       cluster_buffer)
    
    # put admin area restriction
    admin1_poly<-poly_admin[admin1_index,]
    temp_pop_admin<-raster::mask(crop(temp_pop_cir,admin1_poly),
                         admin1_poly)
    
    
    # check whether need to adjust for constraint 
    cir_val<-values(temp_pop_cir)
    admin_val<-values(temp_pop_admin)
    
    admin_adj<-length(which(!is.na(cir_val)))!=length(which(!is.na(admin_val)))
    
    if(admin_adj){
      #normc<-admin1_normc(pt,jitter_r,admin1_poly,ntrial=1000)
      normc<-1
    }else{  normc<-1}
    
    ## prepare sample frame
    
    temp_val<-values(temp_pop_admin)
      pop_index<-which(!is.na(temp_val))
      
      temp_frame<-as.data.frame(coordinates(temp_pop_admin))
      pixel_candidate<-temp_frame[pop_index,]
      pixel_candidate$pop_den<-temp_val[pop_index]
      
      pixel_candidate$center_x<-obs$LONGNUM
      pixel_candidate$center_y<-obs$LATNUM
      pixel_candidate$dist<-diag(distm(pixel_candidate[,c('x','y')], 
                                       pixel_candidate[,c('center_x','center_y')]))
      
      pixel_candidate$unn_w<-pixel_candidate$pop_den*
        1/(2*pi * 2 * pixel_candidate$dist)*normc*prob_r 
      
      pixel_candidate$normc<-normc
    
    
    },error=function(e){ })
    
    if(!exists('pixel_candidate')){
      pixel_candidate <- data.frame(x=NA,y=NA,unn_w=NA,normc=1)
    }
    return(pixel_candidate[,c("x","y",'normc','unn_w')])
    #return(pixel_candidate)
    
  }
  
# Define function to compute urban population threshold ----------------------------------------------------------
  
  ## This function computes the urban population threshold for a given admin1 area.
  ## This is done by keep counting the urban locations until the urban population fraction in the reference table is reached.
  thresh_urb<-function(adm_grid,ref_tab){
    
    # sort grid population
    vals <- adm_grid$pop_den
    vals[is.na(vals)] <- 0
    sort.obj <- sort.int(vals, decreasing = TRUE, index.return = TRUE, method = 'shell')
    svals <- sort.obj$x
    svals.int <- sort.obj$ix
    
    # extract cutoff proportion based on admin1
    adm.idx <- adm_grid$admin1.char[1]
    cutoff <- ref_tab[ref_tab$Internal==adm.idx,]$urb_frac
    
    # determine population threshold and urban rural
    csvals <- cumsum(svals)/sum(svals)
    is.urb <- csvals <= cutoff
    org.isurb <- is.urb[invPerm(svals.int)]
    threshold <- min(vals[org.isurb == 1]) #cutoff
    
    # prepare return object (grid with urban/rural)
    adm_grid$threshold <- threshold
    adm_grid$urban <- as.numeric(org.isurb)
    #adm_grid[is.na(adm_grid$pop_den),]$urban<-NA
    
    return(adm_grid)
    
  }
  
# Define function to get urban fraction ----------------------------------------------------------
    
 # The get_subnatl_frac() function is used to calculate the urban population
 # fraction for each administrative area (typically admin1 or admin2) using a
 # gridded population raster and a corresponding binary urban classification
 # raster.
    
    get_subnatl_frac<-function(adm.names, adm.idx, wp, poly_file, wp_adm = NULL, urb_vec) {
      
      poly_file <- st_transform(poly_file, crs = crs(wp))
      
      if(is.null(wp_adm))
        wp_adm <- lapply(1:nrow(poly_file), function(x) {
          list(state_id = x, state_raster = raster::mask(crop(wp,poly_file[x,]), poly_file[x,]))
        })
      
      if (inherits(urb_vec, "Raster")) {
        pred_surf <- urb_vec
      } else {
        pred_surf <- wp
        values(pred_surf) <- urb_vec
      }
      if (!raster::compareRaster(pred_surf, wp, extent = TRUE, rowcol = TRUE,
                                 crs = TRUE, res = TRUE, orig = TRUE,
                                 stopiffalse = FALSE)) {
        pred_surf <- raster::resample(pred_surf, wp, method = "ngb")
      }
      
      urb_adm <- lapply(1:nrow(poly_file), function(x) {
        list(state_id = x, state_raster = raster::mask(crop(pred_surf,poly_file[x,]), poly_file[x,]))
      })
      
      frac_vec<-vector()
      
      for(j in 1:length(adm.names)){
        urb_j<-urb_adm[[j]]
        wp_j<-wp_adm[[j]]
        
        val_urb_j<-values(urb_j$state_raster)
        val_wp_j<-values(wp_j$state_raster)
        
        frac_vec[j]<-sum(val_urb_j*val_wp_j,na.rm=TRUE)/
          sum(val_wp_j,na.rm=TRUE)
      }
      
      subnatl_frac<-data.frame(adm_name=adm.names,adm_idx=adm.idx,urb_frac=frac_vec)
      return(subnatl_frac)
    }
    
    
# Correct urban clusters ----------------------------------------------------------

if('DHS' %in% mod.dat$survey.type){  
  # The codes below fulfills the process defined in the constr_prior function by assigning the possibly misclassified urban clusters to the nearest most densely populated areas.
  # It's generally true that the urban areas tend to have a higher population density so this process can alleviate the side effect
  # of jittering.
  
  cluster_list$x_adj <- cluster_list$y_adj <- NA
  # only correct urban clusters 
  # check if the strata are named 'urban' and 'rural'
  table(cluster_list$urban)
  urban_clus<-cluster_list[cluster_list$urban=='urban' & !(is.na(cluster_list$LATNUM)),]
  rural_clus<-cluster_list[cluster_list$urban=='rural' & !(is.na(cluster_list$LATNUM)),]

  urban_clus$x_adj<-NA
  urban_clus$y_adj<-NA
  rural_clus$x_adj<-rural_clus$LONGNUM
  rural_clus$y_adj<-rural_clus$LATNUM

  # points have to stay within the same admin2 region 
  #for( i in 1:dim(urban_clus)[1]){
  if(exists("poly.adm2")){
    poly.adm <- poly.adm2
  }else{
    poly.adm <- poly.adm1
  }
  
  for( i in 1:dim(urban_clus)[1]){
    print(i)
    temp_frame<-constr_prior(urban_clus[i,],2000,1,poly.adm,worldpop)
    p_mode = sqldf("SELECT * FROM temp_frame GROUP BY x,y ORDER BY SUM(unn_w) DESC LIMIT 1")
    urban_clus[i,]$x_adj<-p_mode$x
    urban_clus[i,]$y_adj<-p_mode$y
  }

  prep_dat<-rbind(urban_clus,rural_clus,cluster_list[is.na(cluster_list$LATNUM),])

}else{
  prep_dat <- cluster_list
  prep_dat$x_adj <- prep_dat$LONGNUM
  prep_dat$y_adj <- prep_dat$LATNUM
}  

# create directory to store cluster data
use_path_base(data.dir)

if(!dir.exists(paths = file.path("prepared_dat"))){
    dir.create(path = file.path("prepared_dat"))
}

save(prep_dat,file=file.path("prepared_dat",
                             paste0("prep_dat", frame_output_suffix, ".rda")))


# Add covariates ----------------------------------------------------------
  
  crc_dat<-prep_dat
  
  # set up corrected xy for clusters
  xy_crc <- as.matrix(crc_dat[c('x_adj','y_adj')])
  crc_dat$x<-crc_dat$x_adj # x_adj and y_adj: corrected coordinates
  crc_dat$y<-crc_dat$y_adj

  # extract covariates
  crc_dat$pop_den <- raster::extract(worldpop, xy_crc)

  # only retain part of the columns to reduce redundancy
  if(exists("poly.adm2")){
    col_select<-c('cluster','urban','admin1','admin2',
                 'admin1.name','admin2.name',
                 'admin1.char','admin2.char',
                 'survey','pop_den','x','y')
  }else{
    col_select<-c('cluster','urban','admin1',
                  'admin1.name',  'admin1.char',
                  'survey','pop_den','x','y') 
  }

  crc_dat_final<-crc_dat[,col_select]
  save(crc_dat_final,file=file.path("prepared_dat",
                                    paste0("crc_dat", frame_output_suffix, ".rda")))

# Prepare data w/o urban correction ----------------------------------------------------------
  
  uncrc_dat<-prep_dat

  # set up uncorrected xy for clusters
  xy_uncrc <- as.matrix(uncrc_dat[c('LONGNUM','LATNUM')])
  uncrc_dat$x<-uncrc_dat$LONGNUM # x_adj and y_adj: corrected coordinates
  uncrc_dat$y<-uncrc_dat$LATNUM


  # extract covariates
  uncrc_dat$pop_den <-raster::extract(worldpop, xy_uncrc)


  # keep columns
  if(exists("poly.adm2")){
    col_select<-c('cluster','urban','admin1','admin2',
                  'admin1.name','admin2.name',
                  'admin1.char','admin2.char',
                  'survey','pop_den','x','y')
  }else{
    col_select<-c('cluster','urban','admin1',
              'admin1.name',
              'admin1.char',
              'survey','pop_den','x','y')
  }

  uncrc_dat_final<-uncrc_dat[,col_select]
  save(uncrc_dat_final,file=file.path("prepared_dat",
                                      paste0("uncrc_dat", frame_output_suffix, ".rda")))


  
# Prepare national grid ----------------------------------------------------------
  
  ## set up grid
  urb_dat<-as.data.frame(coordinates(worldpop))
  colnames(urb_dat)<-c('x','y')
  
  ## add population density
  urb_dat$pop_den<-raster::extract(worldpop,urb_dat[c('x','y')])
  

  # poly.over.adm1 <- SpatialPolygons(poly.adm1@polygons)
  poly.sp.adm1 <- as(poly.adm1, "Spatial")  # becomes SpatialPolygonsDataFrame
  poly.over.adm1 <- as(poly.sp.adm1, "SpatialPolygons")
  
  ## add admin1 region for pixel
  points.frame <- SpatialPoints(urb_dat[, c("x", "y")],
                                proj4string = CRS(proj4string(poly.sp.adm1)))
  
  admin1.key <- over(points.frame, poly.over.adm1)
  table(admin1.key)
  
  # admin1.key looks like this: 
  # 1     2     3     4     5     6     7     8     9    10    11    12    13    14    15    16    17    18    19    20    21    22    23
  # 5547 40651  7915  5399 58427 11472 36917 85328 25064 19547  7288 23073  6176  9063  8699 21619  6228 28704 52697 23976 28385 42962 34181 
  # 24    25    26    27    28    29    30    31    32    33    34    35    36    37 
  # 41922  4445 31123 84325 18961 17120 10829 32378 32671 10029 38054 71200 54529 41303 
  
  urb_dat$admin1 <- admin1.key
  length(admin1.key) # 1665796
  
  urb_dat$admin1.char <- paste0("admin1_", admin1.key)
  dim(urb_dat)  #  1665796       5
  # 
  save(urb_dat, file = file.path("prepared_dat",
                                 paste0("natl_grid", frame_output_suffix, ".rda")))
  
  
# Admin1 threshold ----------------------------------------------------------
  
  # index the grid
  urb_dat$index <- c(1 : nrow(urb_dat))
  adm1_dat <- split( urb_dat , f = urb_dat$admin1 )
  
  # testing 
  urb1_test <- thresh_urb(adm_grid = adm1_dat[[1]], ref_tab = ref.tab)
  
  urb_list <- lapply(adm1_dat, FUN = thresh_urb, ref_tab = ref.tab)
  urb_class <- do.call("rbind", urb_list)
  hist(urb_class$threshold)
  dim(urb_class)
  
  urb_grid <- urb_dat
  urb_grid$urb_ind <-NA
  urb_grid[urb_class$index,]$urb_ind <- urb_class$urban
  
  
  urb_surf <- worldpop
  values(urb_surf) <- urb_grid$urb_ind
  
  
  ## save reference table along with calculated threshold 
  thresh_ref <- urb_class[!duplicated(urb_class[,c('admin1')]),]
  ref.tab$threshold <- thresh_ref$threshold # check whether the thresholds are sensible (shouldn't be NA or all 0)
  ref.tab$threshold
  write.xlsx(ref.tab, file=file.path("prepared_dat",
                                     paste0("reference_table", frame_output_suffix, ".xlsx")),
             rowNames = FALSE)
 
# Check classification accuracy based on clusters ----------------------------------------------------------

if('DHS' %in% mod.dat$survey.type){
  ### remove rows with missing covariates, could also build model with missing data
  crc_dat<-crc_dat_final[complete.cases(crc_dat_final), ]
  uncrc_dat<-uncrc_dat_final[complete.cases(uncrc_dat_final), ]
  
  
  xy_crc <- as.matrix(crc_dat[c('x','y')])
  xy_uncrc <- as.matrix(uncrc_dat[c('x','y')])
  
  # extract the urban/rural prediction
  crc_dat$urb_pred<-raster::extract(urb_surf,xy_crc)
  uncrc_dat$urb_pred<-raster::extract(urb_surf,xy_uncrc)
  urban_levels <- c("urban", "rural")
  pred_crc <- factor(
    ifelse(crc_dat$urb_pred == 1, "urban", "rural"),
    levels = urban_levels
  )
  pred_uncrc <- factor(
    ifelse(uncrc_dat$urb_pred == 1, "urban", "rural"),
    levels = urban_levels
  )
  reference_crc <- factor(crc_dat$urban, levels = urban_levels)
  reference_uncrc <- factor(uncrc_dat$urban, levels = urban_levels)
  
  ### set directory for results
  use_path_base(file.path(res.dir, "UR"))
  
  
  # compute the confusion to evaluate the accuracy
  confmatrix_crc <- caret::confusionMatrix(
    data = pred_crc,
    reference = reference_crc
  )
  
  confmatrix_crc
  save(confmatrix_crc,file=file.path("Threshold",
                                     paste0("confmatrix_crc", frame_output_suffix, ".rda")))
  
  confmatrix_uncrc <- caret::confusionMatrix(
    data = pred_uncrc,
    reference = reference_uncrc
  )
  
  confmatrix_uncrc
  save(confmatrix_uncrc,file=file.path("Threshold",
                                       paste0("confmatrix_uncrc", frame_output_suffix, ".rda")))
}  
  
# Save national U1 and U5 urban proportions ----------------------------------------------------------  
  years <- c(beg.year:end.proj.year)
  natl.u1.urb <- vector()
  natl.u5.urb <- vector()
  
  for ( t in 1:length(years)){
    
    print(t)
    year <- years[t]
    
    # load U1 population at year t
    u1_pop<-raster(file.path(population_dir,
                            paste0(country.abbrev,'_u1_',year,'_1km.tif')))
    
    # national urban fraction for U1 population at year t
    u1_natl <- sum(urb_grid$urb_ind * values(u1_pop),na.rm=TRUE)/
      sum(values(u1_pop),na.rm=TRUE)
    natl.u1.urb[t] <- u1_natl
    
    # load U5 population at year t
    u5_pop<-raster(file.path(population_dir,
                            paste0(country.abbrev,'_u5_',year,'_1km.tif')))
    
    # national urban fraction for U5 population at year t
    u5_natl <- sum(urb_grid$urb_ind*values(u5_pop),na.rm=TRUE)/
      sum(values(u5_pop),na.rm=TRUE)
    natl.u5.urb[t] <- u5_natl
    
  }
  
  natl.u1.urb.weights <- data.frame(years= years, urban=natl.u1.urb)
  natl.u5.urb.weights <- data.frame(years= years, urban=natl.u5.urb)
  
  if(end.proj.year > max(natl.u5.urb.weights$years)){
    natl.u5.urb.weights <- rbind(natl.u5.urb.weights,
                                   data.frame(years=(max(natl.u5.urb.weights$years) + 1):end.proj.year,
                                              urban=rep(natl.u5.urb.weights[natl.u5.urb.weights$years==max(natl.u5.urb.weights$years),]$urban,
                                                        (end.proj.year - max(natl.u5.urb.weights$years)))))
    natl.u1.urb.weights <- rbind(natl.u1.urb.weights,
                                 data.frame(years=(max(natl.u1.urb.weights$years) + 1):end.proj.year,
                                            urban=rep(natl.u1.urb.weights[natl.u1.urb.weights$years==max(natl.u1.urb.weights$years),]$urban,
                                                      (end.proj.year - max(natl.u1.urb.weights$years)))))
  }
  
  use_path_base(file.path(res.dir, "UR"))
  saveRDS(natl.u1.urb.weights,
          file.path("U1_fraction",
                    paste0("natl_u1_urban_weights", frame_output_suffix, ".rds")))
  saveRDS(natl.u5.urb.weights,
          file.path("U5_fraction",
                    paste0("natl_u5_urban_weights", frame_output_suffix, ".rds")))
 
# Save subnational U1 and U5 urban proportions ----------------------------------------------------------  

  adm1.u1.weight.frame <- data.frame()
  adm2.u1.weight.frame <- data.frame()
  adm1.u5.weight.frame <- data.frame()
  adm2.u5.weight.frame <- data.frame()
  
  for ( t in 1:length(years)){
    
    print(t)
    year <- years[t]
    
    # load populations at year t
    u1_pop<-raster(file.path(population_dir,
                            paste0(country.abbrev,'_u1_',year,'_1km.tif')))
    u5_pop<-raster(file.path(population_dir,
                            paste0(country.abbrev,'_u5_',year,'_1km.tif')))
    
    # admin1 urban fraction for populations at year t
    u1_urb_admin1 <- get_subnatl_frac(adm.names = admin1.names[[admin1_name_col]],
                                    adm.idx = admin1.names$Internal,
                                    wp = u1_pop,
                                    poly_file = poly.adm1,
                                    wp_adm = NULL,
                                    urb_vec = urb_surf)
    
    u5_urb_admin1 <- get_subnatl_frac(adm.names = admin1.names[[admin1_name_col]],
                                    adm.idx = admin1.names$Internal,
                                    wp=u5_pop,
                                    poly_file = poly.adm1,
                                    wp_adm = NULL,
                                    urb_vec = urb_surf)
    
    u1_urb_admin1$years <- u5_urb_admin1$years <- year
    adm1.u1.weight.frame <- rbind(adm1.u1.weight.frame,u1_urb_admin1)
    adm1.u5.weight.frame <- rbind(adm1.u5.weight.frame,u5_urb_admin1)
    
    if(exists('poly.adm2')){
    # admin2 urban fraction for U5 population at year t
    u1_urb_admin2<-get_subnatl_frac(adm.names = admin2.names[[admin2_name_col]],
                                    adm.idx = admin2.names$Internal,
                                    wp=u1_pop,
                                    poly_file = poly.adm2,
                                    wp_adm = NULL,
                                    urb_vec = urb_surf)
    
    u5_urb_admin2<-get_subnatl_frac(adm.names = admin2.names[[admin2_name_col]],
                                    adm.idx = admin2.names$Internal,
                                    wp=u5_pop,
                                    poly_file = poly.adm2,
                                    wp_adm = NULL,
                                    urb_vec = urb_surf)
    
    u1_urb_admin2$years <- u5_urb_admin2$years <- year
    adm2.u1.weight.frame <- rbind(adm2.u1.weight.frame,u1_urb_admin2)
    adm2.u5.weight.frame <- rbind(adm2.u5.weight.frame,u5_urb_admin2)
  
    }
    
    use_path_base(file.path(res.dir, "UR"))
    
    # save calculated urban fractions
    saveRDS(u1_urb_admin1,file=file.path("U1_fraction",
                                         paste0("admin1_u1_", year, "_urban_frac",
                                                frame_output_suffix, ".rds")))
    saveRDS(u5_urb_admin1,file=file.path("U5_fraction",
                                         paste0("admin1_u5_", year, "_urban_frac",
                                                frame_output_suffix, ".rds")))
    if(exists('poly.adm2')){
    saveRDS(u1_urb_admin2,file=file.path("U1_fraction",
                                         paste0("admin2_u1_", year, "_urban_frac",
                                                frame_output_suffix, ".rds")))
    saveRDS(u5_urb_admin2,file=file.path("U5_fraction",
                                         paste0("admin2_u5_", year, "_urban_frac",
                                                frame_output_suffix, ".rds")))
    }
    
  }
  
  
  extend_urban_weights <- function(weight_frame, final_year) {
    last_year <- max(weight_frame$years)
    if (final_year <= last_year) {
      return(weight_frame)
    }

    last_rows <- weight_frame[weight_frame$years == last_year, c("region", "urban")]
    future_rows <- do.call(rbind, lapply((last_year + 1):final_year, function(year) {
      data.frame(region = last_rows$region,
                 years = year,
                 urban = last_rows$urban)
    }))

    rbind(weight_frame, future_rows)
  }

  # process admin 1 urban rural weights data frame
  adm1.u1.weight.frame <- adm1.u1.weight.frame[,c('adm_idx','years','urb_frac')]
  colnames(adm1.u1.weight.frame) <- c('region','years','urban')
  adm1.u1.weight.frame <- extend_urban_weights(adm1.u1.weight.frame, end.proj.year)
  adm1.u1.weight.frame$rural <- 1 - adm1.u1.weight.frame$urban
  saveRDS(adm1.u1.weight.frame,
          file.path("U1_fraction",
                    paste0("admin1_u1_urban_weights", frame_output_suffix, ".rds")))
  
  adm1.u5.weight.frame <- adm1.u5.weight.frame[,c('adm_idx','years','urb_frac')]
  colnames(adm1.u5.weight.frame) <- c('region','years','urban')
  adm1.u5.weight.frame <- extend_urban_weights(adm1.u5.weight.frame, end.proj.year)
  adm1.u5.weight.frame$rural <- 1 - adm1.u5.weight.frame$urban
  saveRDS(adm1.u5.weight.frame,
          file.path("U5_fraction",
                    paste0("admin1_u5_urban_weights", frame_output_suffix, ".rds")))
  
  if(exists('poly.adm2')){
  # process admin 2 urban rural weights data frame
  adm2.u1.weight.frame <- adm2.u1.weight.frame[,c('adm_idx','years','urb_frac')]
  colnames(adm2.u1.weight.frame) <- c('region','years','urban')
  adm2.u1.weight.frame <- extend_urban_weights(adm2.u1.weight.frame, end.proj.year)
  adm2.u1.weight.frame$rural <- 1 - adm2.u1.weight.frame$urban
  saveRDS(adm2.u1.weight.frame,
          file.path("U1_fraction",
                    paste0("admin2_u1_urban_weights", frame_output_suffix, ".rds")))
  
  adm2.u5.weight.frame <- adm2.u5.weight.frame[,c('adm_idx','years','urb_frac')]
  colnames(adm2.u5.weight.frame) <- c('region','years','urban')
  adm2.u5.weight.frame <- extend_urban_weights(adm2.u5.weight.frame, end.proj.year)
  adm2.u5.weight.frame$rural <- 1 - adm2.u5.weight.frame$urban
  saveRDS(adm2.u5.weight.frame,
          file.path("U5_fraction",
                    paste0("admin2_u5_urban_weights", frame_output_suffix, ".rds")))
  }
}

USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
source(file.path(dir_subnational, "Rcode/_supporting_scripts/worldpop_population_inputs.R"))
source(file.path(dir_subnational, "Rcode/_supporting_scripts/population_weight_interpolation.R"))
source(file.path(dir_subnational, "Rcode/_supporting_scripts/population_raster_interpolation.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}


# Country context is loaded by Rcode/1_Preperation.R.


# Load libraries and info ----------------------------------------------------------

options(gsubfn.engine = "R")
library(sf)
library(terra)


home.dir <- project_home()
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
require_country_context()
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}

# Load Polygons ----------------------------------------------------------

use_path_base(data.dir)

# load the national shape file
poly.adm0 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm0, options = "ENCODING=UTF-8")

# use encoding to read special characters
# load the shape file of admin-1 regions
poly.adm1 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm1, options = "ENCODING=UTF-8")

if(exists('poly.layer.adm2')){
  # load the shape file of admin-2 regions
  poly.adm2 <- sf::st_read(dsn = poly.path, layer = poly.layer.adm2, options = "ENCODING=UTF-8")
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


# Load cluster data  ----------------------------------------------------------

use_path_base(paste0(data.dir))
load(paste0(country,'_cluster_dat.rda'),
     envir = .GlobalEnv)

cluster_list<-mod.dat[!duplicated(mod.dat[c('cluster','survey',
                                            'LONGNUM','LATNUM')]),]

survey_years <- unique(mod.dat$survey)



# function that calculates population in each admin area ----------------------------------------------------------
# pop_adm<-function(adm.shp, wp,admin_pop_dat){
#   
#   # make sure polygons have same crs as population raster
#   adm.shp <- spTransform(adm.shp, wp@crs)
#   
#   # admin level population
#   wp.adm.list <- lapply(1:nrow(adm.shp), function(x) {
#     list(state_id = x, state_raster = raster::mask(crop(wp,adm.shp[x,]),
#                                                    mask = adm.shp[x,]))
#   })
#   
#   # store total population at admin
#   pop.adm<-vector()
#   for ( j in 1:nrow(adm.shp)){
#     pop_j<-wp.adm.list[[j]]
#     pop.adm[j]<-sum(values(pop_j$state_raster),na.rm=TRUE)
#     
#   }
#   
#   # add admin population 
#   admin_pop_dat$admin_pop<-pop.adm
#   # not using matching because repeated admin2 names
#   # assume order in admin.link is the same as polygon
#   
#   return (admin_pop_dat)
# }


# Using terra 
.zone_raster_cache <- new.env(parent = emptyenv())

zone_cache_key <- function(adm.shp, wp, id_col) {
  paste(
    id_col,
    nrow(adm.shp),
    terra::nrow(wp),
    terra::ncol(wp),
    paste(terra::res(wp), collapse = "x"),
    paste(as.vector(terra::ext(wp)), collapse = ","),
    terra::crs(wp),
    sep = "|"
  )
}

pop_adm <- function(adm.shp, wp, admin_pop_dat, id_col = "Internal") {
  # Ensure adm.shp is in sf format and CRS matches
  if (inherits(adm.shp, "Spatial")) adm.shp <- st_as_sf(adm.shp)
  adm.vect <- vect(adm.shp)
  if (!terra::same.crs(wp, adm.vect)) {
    wp <- terra::project(wp, terra::crs(adm.vect))
  }

  cache.key <- zone_cache_key(adm.shp, wp, id_col)
  if (exists(cache.key, envir = .zone_raster_cache, inherits = FALSE)) {
    zones <- get(cache.key, envir = .zone_raster_cache)
  } else {
    adm.vect[[".admin_row"]] <- seq_len(nrow(adm.shp))
    zones <- terra::rasterize(adm.vect, wp[[1]], field = ".admin_row")
    assign(cache.key, zones, envir = .zone_raster_cache)
  }
  
  # Reusing zone rasters is much faster than repeated polygon extraction.
  zonal_sum <- terra::zonal(wp, zones, fun = "sum", na.rm = TRUE)
  admin_pop <- rep(0, nrow(adm.shp))
  zone_id <- zonal_sum[[1]]
  matched <- match(seq_len(nrow(adm.shp)), zone_id)
  has_match <- !is.na(matched)
  admin_pop[has_match] <- zonal_sum[[2]][matched[has_match]]
  admin_pop[!is.finite(admin_pop)] <- 0
  admin_pop_dat$admin_pop <- admin_pop
  
  return(admin_pop_dat)
}

# Prepare 1km population rasters --------------------------------------------------
#### Admin weights always use the aligned 1km WorldPop sources.
#### Set ADMIN_WEIGHTS_POP_YEARS=2020 for a short smoke test.

parse_population_years <- function(default_years) {
  override <- Sys.getenv("ADMIN_WEIGHTS_POP_YEARS", unset = "")
  if (!nzchar(override)) {
    return(default_years)
  }
  years <- as.integer(trimws(unlist(strsplit(override, ","))))
  if (any(is.na(years))) {
    stop("ADMIN_WEIGHTS_POP_YEARS must be a comma-separated list of years.")
  }
  years
}

pop.year <- parse_population_years(beg.year:end.proj.year)

population_dir <- population_raster_dir(country)
weight_output_dir <- file.path(data.dir, "worldpop")
force.population.rebuild <- identical(
  Sys.getenv("ADMIN_WEIGHTS_REBUILD_POPULATION", unset = "0"),
  "1"
)
dir.create(population_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(weight_output_dir, recursive = TRUE, showWarnings = FALSE)

raster_file_ok <- worldpop_raster_file_ok

worldpop.input.manifest <- ensure_worldpop_population_inputs(
  country = country,
  iso0 = iso0,
  years = pop.year
)

worldpop_age_sex_file <- function(year, sex, age) {
  worldpop_population_age_sex_file(
    year = year,
    sex = sex,
    age = age,
    country = country,
    iso0 = iso0
  )
}

ensure_age_sex_raster <- function(year, sex, age) {
  file <- worldpop_age_sex_file(year, sex, age)
  if (!raster_file_ok(file)) {
    stop(
      "Missing or unreadable ", worldpop_population_source_name(year),
      " population raster for ", country, " ", year, ": ", file,
      call. = FALSE
    )
  }
  file
}

population_group_file <- function(year, age_group) {
  file.path(population_dir, paste0(country.abbrev, "_", age_group, "_", year, "_1km.tif"))
}

prepare_population_rasters <- function(year) {
  u1_file <- population_group_file(year, "u1")
  u5_file <- population_group_file(year, "u5")
  if (!force.population.rebuild &&
      raster_file_ok(u1_file) && raster_file_ok(u5_file)) {
    return(invisible(c(u1 = u1_file, u5 = u5_file)))
  }

  message(
    "Preparing 1km U1/U5 population rasters for ", year,
    " from ", worldpop_population_source_name(year)
  )
  f_0 <- rast(ensure_age_sex_raster(year, "f", 0))
  f_1 <- rast(ensure_age_sex_raster(year, "f", 1))
  m_0 <- rast(ensure_age_sex_raster(year, "m", 0))
  m_1 <- rast(ensure_age_sex_raster(year, "m", 1))

  pop_u1 <- f_0 + m_0
  writeRaster(pop_u1, u1_file, overwrite = TRUE)

  # Keep the previous repository convention: U5 is WorldPop age bands 0 and 1.
  pop_u5 <- f_0 + f_1 + m_0 + m_1
  writeRaster(pop_u5, u5_file, overwrite = TRUE)
  invisible(c(u1 = u1_file, u5 = u5_file))
}

for (year in pop.year) {
  prepare_population_rasters(year)
}
complete_population_group_rasters(
  population_group_file = population_group_file,
  available_years = pop.year,
  target_years = beg.year:end.proj.year
)

weight.years <- beg.year:end.proj.year


# Calculate weights ----------------------------------------------------------

append_weight <- function(existing, new_rows) {
  if (is.null(existing)) {
    new_rows
  } else {
    rbind(existing, new_rows)
  }
}

population_proportions <- function(adm.shp, pop_raster, admin_names, year) {
  adm_pop <- pop_adm(adm.shp = adm.shp,
                     wp = pop_raster,
                     admin_pop_dat = admin_names)
  total_pop <- sum(adm_pop$admin_pop, na.rm = TRUE)
  if (!is.finite(total_pop) || total_pop <= 0) {
    stop("Population raster has zero or invalid total population for ", year)
  }
  adm_pop$proportion <- adm_pop$admin_pop / total_pop
  adm_pop <- adm_pop[, c("Internal", "proportion")]
  colnames(adm_pop) <- c("region", "proportion")
  adm_pop$years <- year
  adm_pop
}

extend_future_weights <- function(weight_table, admin_names) {
  expected_regions <- sort(unique(as.character(admin_names$Internal)))
  available_regions <- sort(unique(as.character(weight_table$region)))
  if (!identical(expected_regions, available_regions)) {
    stop("Population weights do not cover the expected administrative regions.",
         call. = FALSE)
  }
  complete_population_weights(weight_table, beg.year:end.proj.year)
}

calculate_population_weights <- function() {
  weights <- list(adm1.u1 = NULL, adm1.u5 = NULL)
  if (exists("poly.adm2")) {
    weights$adm2.u1 <- NULL
    weights$adm2.u5 <- NULL
  }

  for (year in weight.years) {
    message("Calculating 1km population weights for ", year)
    pop_u5 <- rast(population_group_file(year, "u5"))
    pop_u1 <- rast(population_group_file(year, "u1"))

    if (exists("poly.adm2")) {
      weights$adm2.u5 <- append_weight(
        weights$adm2.u5,
        population_proportions(poly.adm2, pop_u5, admin2.names, year)
      )
      weights$adm2.u1 <- append_weight(
        weights$adm2.u1,
        population_proportions(poly.adm2, pop_u1, admin2.names, year)
      )
    }

    weights$adm1.u5 <- append_weight(
      weights$adm1.u5,
      population_proportions(poly.adm1, pop_u5, admin1.names, year)
    )
    weights$adm1.u1 <- append_weight(
      weights$adm1.u1,
      population_proportions(poly.adm1, pop_u1, admin1.names, year)
    )
  }

  weights$adm1.u1 <- extend_future_weights(weights$adm1.u1, admin1.names)
  weights$adm1.u5 <- extend_future_weights(weights$adm1.u5, admin1.names)
  if (exists("poly.adm2")) {
    weights$adm2.u1 <- extend_future_weights(weights$adm2.u1, admin2.names)
    weights$adm2.u5 <- extend_future_weights(weights$adm2.u5, admin2.names)
  }
  weights
}

population.weights <- calculate_population_weights()

weight.adm1.u1 <- population.weights$adm1.u1
weight.adm1.u5 <- population.weights$adm1.u5

save(weight.adm1.u1, file = file.path(weight_output_dir, "adm1_weights_u1.rda"))
save(weight.adm1.u5, file = file.path(weight_output_dir, "adm1_weights_u5.rda"))

if (exists("poly.adm2")) {
  weight.adm2.u1 <- population.weights$adm2.u1
  weight.adm2.u5 <- population.weights$adm2.u5

  save(weight.adm2.u1, file = file.path(weight_output_dir, "adm2_weights_u1.rda"))
  save(weight.adm2.u5, file = file.path(weight_output_dir, "adm2_weights_u5.rda"))
}

# Get map plots of population weights ----------------------------------------------------------

load(file.path(weight_output_dir, "adm1_weights_u1.rda"))
load(file.path(weight_output_dir, "adm1_weights_u5.rda"))
if(exists('poly.adm2')){
  load(file.path(weight_output_dir, "adm2_weights_u1.rda"))
  load(file.path(weight_output_dir, "adm2_weights_u5.rda"))
}

poly.adm1$regionPlot <- admin1.names$Internal
if (exists("poly.adm2")) {
  poly.adm2$regionPlot <- admin2.names$Internal
}

pdf(file.path(weight_output_dir, "admin1_u1_weights.pdf"))
{
  weight.adm1.u1$regionPlot <- weight.adm1.u1$region
  print(SUMMER::mapPlot(data = weight.adm1.u1,
                        is.long = T, 
                        variables = "years", 
                        values = "proportion",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 5,
                        legend.label = "Population weight",
                        per1000 = FALSE,
                        by.data = "regionPlot",
                        by.geo = "regionPlot"))
}
dev.off()

pdf(file.path(weight_output_dir, "admin1_u5_weights.pdf"))
{
  weight.adm1.u5$regionPlot <- weight.adm1.u5$region
  print(SUMMER::mapPlot(data = weight.adm1.u5,
                        is.long = T, 
                        variables = "years", 
                        values = "proportion",
                        direction = -1,
                        geo = poly.adm1,
                        ncol = 5,
                        legend.label = "Population weight",
                        per1000 = FALSE,
                        by.data = "regionPlot",
                        by.geo = "regionPlot"))
}
dev.off()

if(exists('poly.adm2')){
  pdf(file.path(weight_output_dir, "admin2_u1_weights.pdf"))
  {
    weight.adm2.u1$regionPlot <- weight.adm2.u1$region
    print(SUMMER::mapPlot(data = weight.adm2.u1,
                          is.long = T, 
                          variables = "years", 
                          values = "proportion",
                          direction = -1,
                          geo = poly.adm2,
                          ncol = 5,
                          legend.label = "Population weight",
                          per1000 = FALSE,
                          by.data = "regionPlot",
                          by.geo = "regionPlot"))
  }
  dev.off()

  pdf(file.path(weight_output_dir, "admin2_u5_weights.pdf"))
  {
    weight.adm2.u5$regionPlot <- weight.adm2.u5$region
    print(SUMMER::mapPlot(data = weight.adm2.u5,
                          is.long = T, 
                          variables = "years", 
                          values = "proportion",
                          direction = -1,
                          geo = poly.adm2,
                          ncol = 5,
                          legend.label = "Population weight",
                          per1000 = FALSE,
                          by.data = "regionPlot",
                          by.geo = "regionPlot"))
  }
  dev.off()
}


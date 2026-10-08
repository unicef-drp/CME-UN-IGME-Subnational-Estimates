##################################################################
##################################################################
# This script is used to generate the info file for a given country
##################################################################
##################################################################
rm(list = ls())

################################################################
#########   set parameters
################################################################

# Files info (For those lines with ### xxx ### above, please fill in as commented)
country <- 'Niger'

### please fill in the country ISO3 code in all upper case ### (e.g. SEN)
iso0 <- "NER"
doHIVAdj <- F

### please fill in the path to country shape files ####
poly.path <- paste0("../shapeFiles/georepo_", iso0, "_shp")


##### explain how these may need to be changed
poly.layer.adm0 <- paste0("georepo_", iso0, "_0") # specify the name of the national shape file
poly.layer.adm1 <- paste0("georepo_", iso0, "_1") # specify the name of the admin1 shape file
poly.layer.adm2 <- paste0("georepo_", iso0, "_2") # specify the name of the admin2 shape file
poly.label.adm1 <- "NAME_1"
poly.label.adm2 <- "NAME_2"

##################################################################
##################################################################
##################################################################

## setting rest of parameters using info from above
country.abbrev <- tolower(iso0)           # lowercase ISO3 abbreviation
beg.year <- 2000 # the first year of the interest
end.proj.year <- 2025 # last year we would like to project to 

frame_year <- c(2001) # sampling frame year(s), if an urban/rural frame is used
surveys_1frame <- NULL
final_model <- list(
  time.model = "ar1",
  sd.time.model = "ar1",
  strata.model = "unstrat",
  bench.model = "bench"
)

info.name <- paste0(country, "_general_info.Rdata")

get_script_path <- function() {
  frames <- sys.frames()
  for (frame in rev(frames)) {
    if (!is.null(frame$ofile)) {
      return(normalizePath(frame$ofile, winslash = "/", mustWork = TRUE))
    }
  }

  file.arg <- "--file="
  script.args <- commandArgs(trailingOnly = FALSE)
  script.path <- sub(file.arg, "", script.args[grepl(paste0("^", file.arg), script.args)])
  if (length(script.path) > 0) {
    return(normalizePath(script.path[1], winslash = "/", mustWork = TRUE))
  }

  stop("Cannot determine script path. Run this script with Rscript or source().")
}

script.path <- get_script_path()
project.dir <- normalizePath(file.path(dirname(script.path), ".."), winslash = "/", mustWork = TRUE)

info.objects <- c(
  "country",
  "iso0",
  "doHIVAdj",
  "poly.path",
  "poly.layer.adm0",
  "poly.layer.adm1",
  "poly.label.adm1",
  "country.abbrev",
  "beg.year",
  "end.proj.year",
  "frame_year",
  "surveys_1frame",
  "final_model",
  "info.name"
)
if (exists("poly.layer.adm2")) {
  info.objects <- c(info.objects, "poly.layer.adm2")
}
if (exists("poly.label.adm2")) {
  info.objects <- c(info.objects, "poly.label.adm2")
}

base::save(list = info.objects, file = file.path(project.dir, "Info", info.name))

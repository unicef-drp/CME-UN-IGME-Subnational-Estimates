##################################################################
##################################################################
# This script is used to generate the info file for a given country
##################################################################
##################################################################


################################################################
#########   set parameters
################################################################

# Files info (For those lines with ### xxx ### above, please fill in as commented)
country <- 'Guinea'

### please fill in the country abbreviation in all upper case of georepo files ### (e.g. fill in SEN for georepo_SEN_3.shp)
iso0 <- "GIN"
doHIVAdj <- F

### please fill in the name of the folder containing the DHS data and the name of the DHS data file inside, separated by "/" ###
dhsStata.files<-"GNBR71DT/GNBR71FL.dta"

### please fill in the file name containing the DHS GPS data ###
dhsFlat.files<-'GNGE71FL'

### please fill in the following information ####
dhs_survey_years<-2018 # years of the DHS surveys
survey_years <- 2018
frame_year <- 2017

### please fill in the path to country shape files ####
poly.path <- paste0("shapeFiles/georepo_GIN_shp")

## save url for frame year census
#census.urls <- c('http://www.nsomalawi.mw/index.php?option=com_content&view=article&id=107%3A2008-population-and-housing-census-results&catid=8%3Areports&Itemid=1')

##### explain how these may need to be changed
poly.layer.adm0 <- paste('georepo', iso0,
                         '0', sep = "_") # specify the name of the national shape file
poly.layer.adm1 <- paste('georepo', iso0,
                         '1', sep = "_") # specify the name of the admin2 shape file
poly.layer.adm2 <- paste('georepo', iso0,
                         '2', sep = "_") # specify the name of the admin2 shape file


poly.label.adm1 <- "poly.adm1@data$NAME_1"
poly.label.adm2 <- "poly.adm2@data$NAME_2"

##################################################################
##################################################################
##################################################################

## setting rest of parameters using info from above
country.abbrev <- tolower(iso0)           # lower the country georepo abbreviation 
beg.year <- 2000 # the first year of the interest
end.proj.year <- 2020 # last year we would like to project to 

info.name <- paste0(country, "_general_info.Rdata")

# extract file location of this script
code.path <- rstudioapi::getActiveDocumentContext()$path
code.path.splitted <- strsplit(code.path, "/")[[1]]

save.image(file = paste0(paste(code.path.splitted[1: (length(code.path.splitted)-2)], collapse = "/"),'/Info/', info.name, sep=''))


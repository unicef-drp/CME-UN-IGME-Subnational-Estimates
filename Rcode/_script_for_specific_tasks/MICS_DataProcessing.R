USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))

#load libraries
library(haven)
library(tidyverse)
library(SUMMER)

get_current_script_path <- function() {
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

# extract file location of this script
code.path <- get_current_script_path()

# retrieve directories
home.dir <- normalizePath(file.path(dirname(code.path), "..", ".."),
                          winslash = "/", mustWork = TRUE)
use_path_base(home.dir)

capitalize_words <- function(s) {
  sapply(strsplit(s, " "), function(words) {
    paste(toupper(substring(words, 1, 1)), tolower(substring(words, 2)), sep = "", collapse = " ")
  }, USE.NAMES = FALSE)
}


# loading complete --------------------------------------------------------



# Malawi 2013-2014 ------------------------------------------------------------------------
#read data and get info
bh <- read_sav('Data/MICS/Malawi/mwi_2014_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% select(HH1,BH5,BH9C,BH4C,HH6,HH7,WDOI,wmweight,region) %>%
#put some variables in proper format for getBirths
      mutate(urban=ifelse(HH6==1,'urban',
                           ifelse(HH6==2,'rural',NA)),
             alive=ifelse(BH5==1,'yes',
                          ifelse(BH5==2,'no',NA)))

bh$admin2.name <- ''
for(i in 1:length(unique(bh$HH7))){
  bh$admin2.name[bh$HH7==attr(bh$HH7,'labels')[i]] <- names(attr(bh$HH7,'labels'))[i]
}
bh$admin2.name <- str_remove(bh$admin2.name,' city')
bh <- bh %>% mutate(admin2.name=ifelse(admin2.name %in% c('Mzuzu','Nkhatabay'),'Nkhata Bay',admin2.name))
            
dat.tmp <- getBirths(data=bh, surveyyear = 2014, variables = c('HH1','BH4C','BH9C','admin2.name','WDOI','alive','urban','wmweight'),
                     strata = c('admin2.name','urban'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 36,year.cut = seq(2000, 2014 + 1, 1),compact.by = c("HH1", 'wmweight', 'admin2.name','urban'),compact=T)

#put in correct order
mwi.2014.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin2.name')]

colnames(mwi.2014.tmp) <- c("cluster", "age", "years", "total",
                       "Y", "v005", 'urban', "admin2.name")

dat.tmp <- mwi.2014.tmp %>% select(c(cluster,age,years,total,Y,v005,urban,admin2.name))
dat.tmp$survey <- 2014

save(dat.tmp,file='Data/MICS/Malawi/mwi.2014.tmp.rda')

# Malawi 2019-2020 ------------------------------------------------------------------------
#read data and get info
bh <- read_sav('Data/MICS/Malawi/mwi_2020_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% select(HH1,BH5,BH4C,BH9C,HH6,WDOI,wmweight,stratum)%>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA)))
bh$strata <- ''
for(i in 1:length(names(attr(bh$stratum,'labels')))){
  bh$strata[bh$stratum==attr(bh$stratum,'labels')[i]] <- names(attr(bh$stratum,'labels'))[i]
}
bh$strata <- str_remove(bh$strata,' City')
bh$admin2.name <- ''
bh$admin2.name[bh$HH6==1] <- str_remove(bh$strata[bh$HH6==1],' Urban')
bh$admin2.name[bh$HH6==2] <- str_remove(bh$strata[bh$HH6==2],' Rural')
bh$admin2.name <- str_trim(bh$admin2.name)

bh <- bh %>% mutate(admin2.name=ifelse(admin2.name=='Mzuzu','Nkhata Bay',admin2.name))

dat.tmp <- getBirths(data=bh, surveyyear = 2020, variables = c('HH1','BH4C','BH9C','WDOI','alive','strata','wmweight','urban','admin2.name'),
                     strata = 'strata',dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 36,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin2.name'),compact=T)

mwi.2020.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin2.name')]
colnames(mwi.2020.tmp) <-  c("cluster", "age", "years", "total",
                             "Y", "v005",'urban', "admin2.name")

dat.tmp <- mwi.2020.tmp %>% select(c(cluster,age,years,total,Y,v005,urban,admin2.name))
dat.tmp$survey <- 2020

save(dat.tmp,file='Data/MICS/Malawi/mwi.2020.tmp.rda')

# Bangladesh 2019 ---------------------------------------
#read data and get info
bh <- read_sav('Data/MICS/Bangladesh/bgd_2019_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7A,WDOI,wmweight)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA)))
bh$admin2.name <- ''
for(i in 1:length(names(attr(bh$HH7A,'labels')))){
  bh$admin2.name[bh$HH7A==attr(bh$HH7A,'labels')[i]] <- names(attr(bh$HH7A,'labels'))[i]
}
#change admin areas to match DHS
bh <- bh %>% dplyr::mutate(admin2.name=if_else(admin2.name=='Barishal','Barisal',
                                        if_else(admin2.name=='Bogura','Bogra',
                                        if_else(admin2.name=="Brahmanbaria", "Brahamanbaria",
                                        if_else(admin2.name=="Chapai Nawabganj","Nawabganj",
                                        if_else(admin2.name=="Cox's Bazar", "Cox'S Bazar",
                                        if_else(admin2.name=="Chattogram", "Chittagong",
                                        if_else(admin2.name=="Cumilla", "Comilla",
                                        if_else(admin2.name=="Jashore", "Jessore",
                                        if_else(admin2.name=="Kishoregonj", "Kishoreganj",
                                        if_else(admin2.name=="Narayangonj", "Narayanganj",
                                        if_else(admin2.name=="Netrokona","Netrakona",admin2.name))))))))))))

dat.tmp <- getBirths(data=bh, surveyyear = 2019, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin2.name'),
                     strata = c('urban','admin2.name'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin2.name'),compact=T)

bgd.2019.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin2.name')]
colnames(bgd.2019.tmp)<-  c("cluster", "age", "years", "total",
                            "Y", "v005",'urban', "admin2.name")

dat.tmp <- bgd.2019.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin2.name))
dat.tmp$survey <- 2019

save(dat.tmp,file='Data/MICS/Bangladesh/bgd.2019.tmp.rda')

# Madagascar 2018 ---------------------------------------
#read data and get info
bh <- read_sav('Data/MICS/Madagascar/mdg_2018_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7,WDOI,wmweight)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA)))

bh$admin2.name <- ''
for(i in 1:length(names(attr(bh$HH7,'labels')))){
  bh$admin2.name[bh$HH7==attr(bh$HH7,'labels')[i]] <- names(attr(bh$HH7,'labels'))[i]
}
bh$admin2.name <- str_to_title(tolower(bh$admin2.name))

dat.tmp <- getBirths(data=bh, surveyyear = 2018, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin2.name'),
                     strata = c('urban','admin2.name'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2018 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin2.name'),compact=T)

mdg.2018.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin2.name')]
colnames(mdg.2018.tmp)<-  c("cluster", "age", "years", "total",
                            "Y", "v005",'urban', "admin2.name")

# note: Madagascar 2018 MICS HH7 is region, which matches the 2014-2021 SALB Admin-2 names.

dat.tmp <- mdg.2018.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin2.name))
dat.tmp$survey <- 2018

save(dat.tmp,file='Data/MICS/Madagascar/mdg.2018.tmp.rda')

# DR Congo 2018 --------------------------------------
bh <- read_sav('Data/MICS/DR_Congo/cod_2018_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7,WDOI,wmweight)) %>%
  filter(!is.na(BH4C)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA)))

bh$admin1.name <- ''
for(i in 1:length(names(attr(bh$HH7,'labels')))){
  bh$admin1.name[bh$HH7==attr(bh$HH7,'labels')[i]] <- names(attr(bh$HH7,'labels'))[i]
}

bh$admin1.name <- str_replace(bh$admin1.name,' ','-')

bh <- bh %>% dplyr::mutate(
  admin1.name = dplyr::recode(
    admin1.name,
    "Kasai-Central" = "Kasai Central",
    "Kasai-Oriental" = "Kasai Oriental",
    "Kongo-Central" = "Kongo Central",
    "Maindombe" = "Mai-Ndombe"
  )
)

dat.tmp <- getBirths(data=bh, surveyyear = 2018, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin1.name'),
                     strata = c('urban','admin1.name'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin1.name'),compact=T)

#put in correct order
dat.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin1.name')]

colnames(dat.tmp) <- c("cluster", "age", "years", "total",
                            "Y", "v005", 'urban', "admin1.name")

dat.tmp <- dat.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin1.name))
dat.tmp$survey <- 2018

save(dat.tmp,file='Data/MICS/DR_Congo/cod.2018.tmp.rda')

# Ghana 2011 --------------------------------------
bh <- read_sav('Data/MICS/Ghana/gha_2011_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7,WDOI,wmweight)) %>%
  filter(!is.na(BH4C)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA)))

bh$admin1.name <- ''
for(i in 1:length(names(attr(bh$HH7,'labels')))){
  bh$admin1.name[bh$HH7==attr(bh$HH7,'labels')[i]] <- names(attr(bh$HH7,'labels'))[i]
}
bh <- bh  %>% filter(admin1.name!="Brong Ahafo") %>% dplyr::mutate(admin1.name=if_else(admin1.name=="Asante", "Ashanti", admin1.name))

dat.tmp <- getBirths(data=bh, surveyyear = 2011, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin1.name'),
                     strata = c('urban','admin1.name'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin1.name'),compact=T)

#put in correct order
dat.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin1.name')]

colnames(dat.tmp) <- c("cluster", "age", "years", "total",
                       "Y", "v005", 'urban', "admin1.name")

dat.tmp <- dat.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin1.name))
dat.tmp$survey <- 2011

save(dat.tmp,file='Data/MICS/Ghana/gha.2011.tmp.rda')

# Ghana 2018 --------------------------------------
bh <- read_sav('Data/MICS/Ghana/gha_2018_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7,WDOI,wmweight)) %>%
  filter(!is.na(BH4C)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA)))

bh$admin1.name <- ''
for(i in 1:length(names(attr(bh$HH7,'labels')))){
  bh$admin1.name[bh$HH7==attr(bh$HH7,'labels')[i]] <- names(attr(bh$HH7,'labels'))[i]
}
bh$admin1.name <- str_to_title(tolower(bh$admin1.name))
bh <- bh  %>% filter(admin1.name!="Brong Ahafo")

dat.tmp <- getBirths(data=bh, surveyyear = 2018, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin1.name'),
                     strata = c('urban','admin1.name'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin1.name'),compact=T)

#put in correct order
dat.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin1.name')]

colnames(dat.tmp) <- c("cluster", "age", "years", "total",
                       "Y", "v005", 'urban', "admin1.name")

dat.tmp <- dat.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin1.name))
dat.tmp$survey <- 2018

save(dat.tmp,file='Data/MICS/Ghana/gha.2018.tmp.rda')

# Lesotho 2018 -------------------------------------
bh <- read_sav('Data/MICS/Lesotho/lso_2018_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7A,WDOI,wmweight)) %>%
  filter(!is.na(BH4C)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA)))

bh$admin1.name <- ''
for(i in 1:length(names(attr(bh$HH7A,'labels')))){
  bh$admin1.name[bh$HH7A==attr(bh$HH7A,'labels')[i]] <- names(attr(bh$HH7A,'labels'))[i]
}

bh$admin1.name <- str_to_title(tolower(bh$admin1.name))
bh <- bh %>% dplyr::mutate(admin1.name=if_else(admin1.name=="Botha-Bothe","Butha-Buthe",
                                        if_else(admin1.name=="Mohales Hoek","Mohale's Hoek",
                                        if_else(admin1.name=="Qachas Nek","Qacha's Nek", admin1.name))))

dat.tmp <- getBirths(data=bh, surveyyear = 2018, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin1.name'),
                     strata = c('urban','admin1.name'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin1.name'),compact=T)

#put in correct order
dat.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin1.name')]

colnames(dat.tmp) <- c("cluster", "age", "years", "total",
                       "Y", "v005", 'urban', "admin1.name")

dat.tmp <- dat.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin1.name))
dat.tmp$survey <- 2018

save(dat.tmp,file='Data/MICS/Lesotho/lso.2018.tmp.rda')

# Nigeria 2017 -------------------------------------
bh <- haven::read_sav('Data/MICS/Nigeria/2017/nga_2017_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7,WDOI,wmweight)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA))) %>%
  filter(!is.na(BH4C), !is.na(alive))

bh$admin1.name <- ''
for(i in 1:length(names(attr(bh$HH7,'labels')))){
  bh$admin1.name[bh$HH7==attr(bh$HH7,'labels')[i]] <- names(attr(bh$HH7,'labels'))[i]
}

bh <- bh %>% dplyr::mutate(admin1.name=if_else(admin1.name=="FCT Abuja","Federal Capital Territory",admin1.name))

dat.tmp <- getBirths(data=bh, surveyyear = 2017, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin1.name'),
                     strata = c('urban','admin1.name'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin1.name'),compact=T)

#put in correct order
dat.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin1.name')]

colnames(dat.tmp) <- c("cluster", "age", "years", "total",
                       "Y", "v005", 'urban', "admin1.name")

dat.tmp <- dat.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin1.name))
dat.tmp$survey <- 2017

save(dat.tmp,file='Data/MICS/Nigeria/nga.2017.tmp.rda')



# Nigeria 2021 -------------------------------------

# for checking 
# admin1_wanted <- unique(mod.dat$admin1.name)
# all(admin1_wanted %in% dat.tmp$admin1.name)
# saveRDS(admin1_wanted, "Data/MICS/Nigeria/admin1.name.rds")

admin1_wanted <- readRDS("Data/MICS/Nigeria/admin1.name.rds")

bh <- haven::read_sav('Data/MICS/Nigeria/2021/bh.sav')
sapply(bh, attr,  'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7,WDOI,wmweight)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA))) %>%
  filter(!is.na(BH4C), !is.na(alive))

bh$admin1.name <- ''
for(i in 1:length(names(attr(bh$HH7,'labels')))){
  bh$admin1.name[bh$HH7==attr(bh$HH7,'labels')[i]] <- names(attr(bh$HH7,'labels'))[i]
}

bh$admin1.name <- capitalize_words(tolower(bh$admin1.name))
admin1_wanted[!admin1_wanted %in% bh$admin1.name]
admin_name_recode <- c(
  "Fct Abuja" = "Federal Capital Territory",
  "Fct" = "Federal Capital Territory"
)
bh <- bh %>% dplyr::mutate(admin1.name = dplyr::recode(admin1.name, !!!admin_name_recode))
stopifnot(all(admin1_wanted %in% bh$admin1.name))
dat.tmp <- getBirths(data=bh, surveyyear = 2021, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin1.name'),
                     strata = c('urban', 'admin1.name'), dob = 'BH4C', alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin1.name'),compact=T)

#put in correct order
dat.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin1.name')]

colnames(dat.tmp) <- c("cluster", "age", "years", "total",
                       "Y", "v005", 'urban', "admin1.name")

dat.tmp <- dat.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin1.name))
dat.tmp$survey <- 2021

save(dat.tmp,file='Data/MICS/Nigeria/nga.2021.tmp.rda')



# Togo 2017 -------------------------------------
bh <- read_sav('Data/MICS/Togo/tgo_2017_bh.sav')
sapply(bh,attr,'label')

bh <- bh %>% dplyr::select(c(HH1,BH4C,BH5,BH9C,HH6,HH7,WDOI,wmweight)) %>%
  #put some variables in proper format for getBirths
  mutate(urban=ifelse(HH6==1,'urban',
                      ifelse(HH6==2,'rural',NA)),
         alive=ifelse(BH5==1,'yes',
                      ifelse(BH5==2,'no',NA))) %>%
  filter(!is.na(BH4C), !is.na(alive))

bh$admin1.name <- ''
for(i in 1:length(names(attr(bh$HH7,'labels')))){
  bh$admin1.name[bh$HH7==attr(bh$HH7,'labels')[i]] <- names(attr(bh$HH7,'labels'))[i]
}

bh[bh$admin1.name %in% c('LOME COMMUNE',"GOLFE URBAIN"),]$admin1.name <- 'MARITIME'
bh$admin1.name <- str_to_title(bh$admin1.name)

dat.tmp <- getBirths(data=bh, surveyyear = 2017, variables = c('HH1','BH4C','BH9C','WDOI','alive','wmweight','urban','admin1.name'),
                     strata = c('urban','admin1.name'),dob = 'BH4C',alive = 'alive',age = 'BH9C',date.interview = 'WDOI',
                     age.truncate = 24,year.cut = seq(2000, 2020 + 1, 1),compact.by = c("HH1", 'wmweight','urban','admin1.name'),compact=T)

#put in correct order
dat.tmp <- dat.tmp[,c('HH1','age','time','total','died','wmweight','urban','admin1.name')]

colnames(dat.tmp) <- c("cluster", "age", "years", "total",
                       "Y", "v005", 'urban', "admin1.name")

dat.tmp <- dat.tmp %>% dplyr::select(c(cluster,age,years,total,Y,v005,urban,admin1.name))
dat.tmp$survey <- 2017

save(dat.tmp,file='Data/MICS/Togo/tgo.2017.tmp.rda')

# Laos 2017 and 2023 -------------------------------------
# Laos 2023 is processed from Data/MICS/Laos/2023/bh.sav.

get_laos_admin_key <- function() {
  if (exists("poly.adm1")) {
    admin1.name <- poly.adm1$NAME_1
    admin1 <- seq_along(admin1.name)
    return(data.frame(
      admin1 = admin1,
      admin1.char = paste0("admin1_", admin1),
      admin1.name = admin1.name
    ))
  }

  georepo_path <- "Data/shapeFiles/georepo_LAO_shp"
  if (dir.exists(georepo_path)) {
    poly.adm1 <- sf::st_read(georepo_path, layer = "georepo_LAO_1", quiet = TRUE)
    admin1 <- seq_len(nrow(poly.adm1))
    return(data.frame(
      admin1 = admin1,
      admin1.char = paste0("admin1_", admin1),
      admin1.name = poly.adm1$NAME_1
    ))
  }

  laos_cluster_file <- "Data/MICS/Laos/Laos_cluster_dat.rda"
  if (!file.exists(laos_cluster_file)) {
    stop("Load Laos poly.adm1 or provide ", laos_cluster_file,
         " before processing Laos MICS.")
  }

  laos_env <- new.env(parent = emptyenv())
  load(laos_cluster_file, envir = laos_env)
  laos_env$mod.dat %>%
    dplyr::select(admin1, admin1.char, admin1.name) %>%
    dplyr::distinct() %>%
    dplyr::arrange(admin1)
}

add_laos_admin_names <- function(bh, laos_admin_key) {
  hh7_to_admin1 <- c(
    "1" = 15, "2" = 10, "3" = 7, "4" = 9, "5" = 2, "6" = 8,
    "7" = 5, "8" = 16, "9" = 18, "10" = 14, "11" = 3,
    "12" = 6, "13" = 12, "14" = 11, "15" = 13, "16" = 4,
    "17" = 1, "18" = 17
  )
  bh$admin1 <- unname(hh7_to_admin1[as.character(as.integer(bh$HH7))])
  bh$admin1.name <- laos_admin_key$admin1.name[
    match(bh$admin1, laos_admin_key$admin1)
  ]
  bh
}

prepare_laos_mics <- function(bh_path, survey_year, output_file, laos_admin_key) {
  bh <- haven::read_sav(bh_path)
  bh <- bh %>%
    dplyr::select(c(HH1, BH4C, BH5, BH9C, HH6, HH7, WDOI, wmweight)) %>%
    dplyr::mutate(
      urban = ifelse(HH6 == 1, "urban",
                     ifelse(HH6 %in% c(2, 3), "rural", NA)),
      alive = ifelse(BH5 == 1, "yes",
                     ifelse(BH5 == 2, "no", NA))
    ) %>%
    dplyr::filter(!is.na(BH4C), !is.na(alive))

  bh <- add_laos_admin_names(bh, laos_admin_key) %>%
    dplyr::filter(!is.na(admin1.name))

  dat.tmp <- getBirths(
    data = bh,
    surveyyear = survey_year,
    variables = c("HH1", "BH4C", "BH9C", "WDOI", "alive", "wmweight",
                  "urban", "admin1.name"),
    strata = c("urban", "admin1.name"),
    dob = "BH4C",
    alive = "alive",
    age = "BH9C",
    date.interview = "WDOI",
    age.truncate = 24,
    year.cut = seq(2000, survey_year + 1, 1),
    compact.by = c("HH1", "wmweight", "urban", "admin1.name"),
    compact = TRUE
  )

  dat.tmp <- dat.tmp[, c("HH1", "age", "time", "total", "died",
                         "wmweight", "urban", "admin1.name")]
  colnames(dat.tmp) <- c("cluster", "age", "years", "total", "Y",
                         "v005", "urban", "admin1.name")
  dat.tmp$survey <- survey_year

  save(dat.tmp, file = output_file)
  dat.tmp
}

combine_laos_mics <- function(mics_files, laos_admin_key, output_file) {
  mod.dat <- purrr::map_dfr(mics_files, function(mics_file) {
    mics_env <- new.env(parent = emptyenv())
    load(mics_file, envir = mics_env)
    dat.tmp <- mics_env$dat.tmp

    dat.tmp <- dat.tmp %>%
      dplyr::left_join(laos_admin_key, by = "admin1.name")
    stopifnot(!anyNA(dat.tmp$admin1), !anyNA(dat.tmp$admin1.char))

    dat.tmp$strata <- paste0(dat.tmp$admin1, ":", dat.tmp$urban)
    dat.tmp$LONGNUM <- dat.tmp$LATNUM <- NA
    dat.tmp$survey.type <- "MICS"
    dat.tmp[, c("cluster", "age", "years", "total", "Y", "v005", "urban",
                "admin1.name", "admin1.char", "admin1", "strata",
                "LONGNUM", "LATNUM", "survey.type", "survey")]
  })

  save(mod.dat, file = output_file)
  mod.dat
}

laos_admin_key <- get_laos_admin_key()
prepare_laos_mics(
  bh_path = "Data/MICS/Laos/lao_2017_bh.sav",
  survey_year = 2017,
  output_file = "Data/MICS/Laos/lao.2017.tmp.rda",
  laos_admin_key = laos_admin_key
)
prepare_laos_mics(
  bh_path = "Data/MICS/Laos/2023/bh.sav",
  survey_year = 2023,
  output_file = "Data/MICS/Laos/lao.2023.tmp.rda",
  laos_admin_key = laos_admin_key
)

mod.dat <- combine_laos_mics(
  mics_files = c("Data/MICS/Laos/lao.2017.tmp.rda",
                 "Data/MICS/Laos/lao.2023.tmp.rda"),
  laos_admin_key = laos_admin_key,
  output_file = "Data/MICS/Laos/Laos_cluster_dat.rda"
)

dir.create("Data/Countries/Laos", recursive = TRUE, showWarnings = FALSE)
save(mod.dat, file = "Data/Countries/Laos/Laos_cluster_dat.rda")
save(mod.dat, file = "Data/Countries/Laos/Laos_cluster_dat_1frame.rda")


# Afghanistan 2022-2023 -------------------------------------

get_afghanistan_admin_key <- function() {
  georepo_path <- "Data/shapeFiles/georepo_AFG_shp"
  if (!dir.exists(georepo_path)) {
    stop("Afghanistan GeoRepo shapefile is required at ", georepo_path,
         call. = FALSE)
  }
  poly.adm1 <- sf::st_read(georepo_path, layer = "georepo_AFG_1",
                           quiet = TRUE)
  data.frame(
    admin1 = seq_len(nrow(poly.adm1)),
    admin1.char = paste0("admin1_", seq_len(nrow(poly.adm1))),
    admin1.name = poly.adm1$NAME_1,
    stringsAsFactors = FALSE
  )
}

normalize_afghanistan_admin1 <- function(x) {
  x <- stringr::str_to_title(tolower(as.character(x)))
  x <- stringr::str_replace_all(x, "[[:space:]]+", " ")
  dplyr::recode(
    trimws(x),
    "Daikundi" = "Daykundi",
    "Helmand" = "Hilmand",
    "Herat" = "Hirat",
    "Jowzjan" = "Jawzjan",
    "Kunarha" = "Kunar",
    "Nooristan" = "Nuristan",
    "Paktia" = "Paktya",
    "Panjshir" = "Panjsher",
    "Sari Pul" = "Sar-e-Pul",
    "Urozgan" = "Uruzgan",
    .default = trimws(x)
  )
}

prepare_afghanistan_mics <- function(
    bh_path = "Data/MICS/Afghanistan/2022_2023/bh.sav",
    survey_year = 2023,
    output_file = "Data/MICS/Afghanistan/afg.2023.tmp.rda",
    afghanistan_admin_key = get_afghanistan_admin_key()) {

  bh <- haven::read_sav(bh_path)
  bh <- bh %>%
    dplyr::select(c(HH1, BH4C, BH5, BH9C, HH6, HH7, WDOI, wmweight)) %>%
    dplyr::mutate(
      urban = ifelse(HH6 == 1, "urban",
                     ifelse(HH6 == 2, "rural", NA)),
      alive = ifelse(BH5 == 1, "yes",
                     ifelse(BH5 == 2, "no", NA))
    ) %>%
    dplyr::filter(!is.na(BH4C), !is.na(alive))

  hh7_labels <- attr(bh$HH7, "labels")
  bh$admin1.name <- names(hh7_labels)[match(bh$HH7, hh7_labels)]
  bh$admin1.name <- normalize_afghanistan_admin1(bh$admin1.name)

  unmatched <- setdiff(unique(bh$admin1.name),
                       afghanistan_admin_key$admin1.name)
  if (length(unmatched) > 0) {
    stop("Afghanistan MICS HH7 admin names do not match GeoRepo: ",
         paste(unmatched, collapse = ", "), call. = FALSE)
  }

  dat.tmp <- getBirths(
    data = bh,
    surveyyear = survey_year,
    variables = c("HH1", "BH4C", "BH9C", "WDOI", "alive", "wmweight",
                  "urban", "admin1.name"),
    strata = c("urban", "admin1.name"),
    dob = "BH4C",
    alive = "alive",
    age = "BH9C",
    date.interview = "WDOI",
    age.truncate = 24,
    year.cut = seq(2000, survey_year + 1, 1),
    cmc.adjust = -945,
    compact.by = c("HH1", "wmweight", "urban", "admin1.name"),
    compact = TRUE
  )

  dat.tmp <- dat.tmp[, c("HH1", "age", "time", "total", "died",
                         "wmweight", "urban", "admin1.name")]
  colnames(dat.tmp) <- c("cluster", "age", "years", "total", "Y",
                         "v005", "urban", "admin1.name")
  dat.tmp$survey <- survey_year

  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  save(dat.tmp, file = output_file)
  dat.tmp
}

if (file.exists("Data/MICS/Afghanistan/2022_2023/bh.sav")) {
  prepare_afghanistan_mics()
}







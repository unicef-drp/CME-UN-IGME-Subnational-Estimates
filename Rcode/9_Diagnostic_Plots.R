USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}


# Country context is loaded by Rcode/1_Preperation.R.
# Please specify which model(s) to get diagnostic plots for. The diagnostics
# script is also used for countries where only an unstratified/all-survey BB8
# run is available, so filter this candidate list to files that actually exist.
model.candidates <- c(
  "natl_unstrat_nmr", "adm1_unstrat_nmr", "adm2_unstrat_nmr",
  "natl_strat_nmr", "adm1_strat_nmr", "adm2_strat_nmr",
  "natl_unstrat_nmr_allsurveys", "adm1_unstrat_nmr_allsurveys",
  "adm2_unstrat_nmr_allsurveys", "adm1_unstrat_nmr_allsurveys_bench",
  "adm2_unstrat_nmr_allsurveys_bench", "adm1_strat_nmr_bench",
  "adm2_strat_nmr_bench",
  "natl_unstrat_u5", "adm1_unstrat_u5", "adm2_unstrat_u5",
  "natl_strat_u5", "adm1_strat_u5", "adm2_strat_u5",
  "natl_unstrat_u5_allsurveys", "adm1_unstrat_u5_allsurveys",
  "adm2_unstrat_u5_allsurveys", "adm1_unstrat_u5_allsurveys_bench",
  "adm2_unstrat_u5_allsurveys_bench", "adm1_strat_u5_bench",
  "adm2_strat_u5_bench"
)
if (admin1_only_requested()) {
  model.candidates <- model.candidates[
    !grepl("^adm2_", model.candidates)
  ]
  message("BB8_ADMIN1_ONLY=1; excluding Admin-2 diagnostic models.")
}

#### Load libraries and info ----------------------------------------------------------

# Libraries
options(gsubfn.engine = "R")
library(tidyverse)
library(SUMMER)

# extract file location of this script
code.path <- file.path(project_home(), "Rcode/9_Diagnostic_Plots.R")
code.path.splitted <- strsplit(code.path, "/")[[1]]

# retrieve directories
home.dir <- paste(code.path.splitted[1: (length(code.path.splitted)-2)], collapse = "/")
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
require_country_context()
source(file.path(home.dir, "Rcode", "_supporting_scripts", "admin_benchmark_helpers.R"))
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}

use_path_base(res.dir)

model_result_file <- function(model) {
  outcome <- str_split(model, "_")[[1]][3]
  metric_dir <- if (outcome == "nmr") {
    "NMR"
  } else if (outcome == "u5") {
    "U5MR"
  } else {
    stop("Cannot infer outcome from model name: ", model)
  }
  file.path(res.dir, "Betabinomial", metric_dir,
            paste0(country, "_res_", model, ".rda"))
}

models <- model.candidates[vapply(model.candidates, function(model) {
  file.exists(model_result_file(model))
}, logical(1))]
missing.models <- setdiff(model.candidates, models)
if (length(missing.models) > 0) {
  message("Skipping missing diagnostic model files: ",
          paste(missing.models, collapse = ", "))
}
if (length(models) == 0) {
  stop("No BB8 result files found for diagnostic plots.")
}

if(!dir.exists(file.path(res.dir, "Figures", "Trends"))){
  dir.create(file.path(res.dir, "Figures", "Trends"))}
if(!dir.exists(file.path(res.dir, "Figures", "Trends", "NMR"))){
  dir.create(file.path(res.dir, "Figures", "Trends", "NMR"))}
if(!dir.exists(file.path(res.dir, "Figures", "Trends", "U5MR"))){
  dir.create(file.path(res.dir, "Figures", "Trends", "U5MR"))}

open_plot_pdf <- function(file) {
  tryCatch({
    pdf(file)
    invisible(file)
  }, error = function(err) {
    fallback <- file.path(
      dirname(file),
      paste0(tools::file_path_sans_ext(basename(file)), "_",
             format(Sys.time(), "%Y%m%d_%H%M%S"), ".pdf")
    )
    warning("Could not open existing plot file for writing: ", file,
            "\nWriting fallback file instead: ", fallback)
    pdf(fallback)
    invisible(fallback)
  })
}

#### Parameters ----------------------------------------------------------
beg.year <- 2000

n_years <- end.proj.year - beg.year + 1

# get info about each model
models.dat <- data.frame(label=models,
                         admin_level = sapply(1:length(models),function(i){str_split(models,'_')[[i]][1]}),
                         strat = sapply(1:length(models),function(i){str_split(models,'_')[[i]][2]}),
                         outcome = sapply(1:length(models),function(i){str_split(models,'_')[[i]][3]}))

#### Load admin names  ------------------------------------------------------
use_path_base(data.dir)

load(file.path(poly.path, paste0(country, "_Amat.rda")))
load(file.path(poly.path, paste0(country, "_Amat_Names.rda")))


#### Plot monthly hazards and urban/rural odds ratio over time (assuming AR1 main temporal trend) ----------------------------------------------------------
for(model.id in 1:length(models)){
  
  if(models.dat$outcome[model.id]=='nmr'){
    load(file.path(res.dir, "Betabinomial", "NMR", paste0(country, "_res_", models[model.id], ".rda")), envir = .GlobalEnv)
    if(models.dat$strat[model.id]=='unstrat'){
      ages <- c('0')
      ages.strata <- ages
    }else{
      ages <- c('0')
      ages.strata <- c(paste0(ages,':rural'),paste0(ages,':urban'))}
  }else if(models.dat$outcome[model.id]=='u5'){
    load(file.path(res.dir, "Betabinomial", "U5MR", paste0(country, "_res_", models[model.id], ".rda")), envir = .GlobalEnv)
    if(models.dat$strat[model.id]=='unstrat'){
      ages <- c('0','1-11','12-23','24-35','36-47','48-59')
      ages.strata <- ages
    }else{
      ages <- c('0','1-11','12-23','24-35','36-47','48-59')
      ages.strata <- c(paste0(ages,':rural'),paste0(ages,':urban'))
    }
  }else{
    stop(paste0(model, ' cannot be found.'))
  }
  
  diagnostic_result <- eval(str2lang(paste0('bb.res.', str_replace_all(models[model.id],'_','.'))))
  sampAll <- benchmark_diagnostic_draws(diagnostic_result)
  diagnostic_label <- paste0(models[model.id],
    if (!is.null(diagnostic_result$benchmark)) " (HIV-adjusted source fit)" else "")
  
  re <- grep("time.struct", rownames(sampAll[[1]]$latent)) # random effect
  
  if(models.dat$outcome[model.id]=='nmr' & models.dat$strat[model.id]=='unstrat'){
    fe.int <- grep("(Intercept)", rownames(sampAll[[1]]$latent))
  }else{
    fe.int <- grep("age", rownames(sampAll[[1]]$latent))} # fixed effect intercept
  
  fe.slope <-  grep("slope.group", rownames(sampAll[[1]]$latent)) # fixed effect slope
  
  struct.all <- matrix(0,n_years*length(ages.strata),length(sampAll))
  
  for(j in 1:length(sampAll)){
    for(age.strata in ages.strata){
      #assign ids
      age <- ages[sapply(ages,grepl,age.strata)]
      age.idx <- which(age==ages)
      
      # age.strata.idx <- grep(age.strata, rownames(sampAll[[1]]$latent)[fe.int])
      if (models.dat$outcome[model.id]=='nmr' & models.dat$strat[model.id]=='unstrat') {
        age.strata.idx <- 1
      } else {
        age.strata.idx <- grep(age.strata, rownames(sampAll[[1]]$latent)[fe.int])
      }
      
      if(age.strata.idx %in% c(1,2) ){
        age.strata.bin.idx <- age.strata.idx
      }else if(age.strata.idx %in% c(3,4,5,6)){
        age.strata.bin.idx <- 3
      }else if(age.strata.idx %in% c(7,8)){
        age.strata.bin.idx <- age.strata.idx-3
      }else if(age.strata.idx %in% c(9,10,11,12)){
        age.strata.bin.idx <- 6
      }
      
      where.row <- (age.strata.idx-1)*n_years +1
      
      struct.all[((where.row):(n_years*age.strata.idx)),j] <- rep(sampAll[[j]]$latent[fe.int][age.strata.idx],n_years) + #fixed intercept
        sampAll[[j]]$latent[fe.slope][age.strata.bin.idx]*(((1:n_years)-n_years/2)/(n_years-1)) + #fixed slope
        sampAll[[j]]$latent[re][(age.strata.bin.idx-1)*n_years+c(1:n_years)]
    }
  }
  
  lower <- (1 - 0.95) / 2
  upper <- 1 - lower
  
  quants <- data.frame(t(apply(struct.all, 1, stats::quantile, c(lower, 0.5, upper))))
  colnames(quants) <- c("lower", "median", "upper")
  quants$years <- rep(beg.year:end.proj.year,length(ages.strata))
  groups <- gsub('age.intercept','',rownames(sampAll[[1]]$latent)[fe.int])
  groups <- gsub(':1','',groups)
  quants$group <- c(sapply(groups,rep,n_years))
  
  age.strata.cols <- rainbow(length(ages.strata))
  
  #plot temporal trends
  if(models.dat$outcome[model.id]=='nmr'){
    open_plot_pdf(file.path(res.dir, "Figures", "Trends", "NMR", paste0(country, "_temporals_", models[model.id], ".pdf")))
  }else if(models.dat$outcome[model.id]=='u5'){
    open_plot_pdf(file.path(res.dir, "Figures", "Trends", "U5MR", paste0(country, "_temporals_", models[model.id], ".pdf")))}
  
  g1 <- ggplot(quants) + geom_line(aes(x=years,y=median,color=group)) + ylab("Monthly Hazard") + ggtitle(diagnostic_label)
  print(g1)
  
  dev.off()
  
  if(models.dat$strat[model.id]=='strat'){
    # calculate urban rural hazards / odds ratio
    urban.samp <- struct.all[grep("urban",quants$group),]
    rural.samp <- struct.all[grep("rural",quants$group),]
    
    hazard.urban.samp <- exp(urban.samp)
    hazard.rural.samp <- exp(rural.samp)
    odds.urban.samp <- expit(urban.samp)
    odds.rural.samp <- expit(rural.samp)
    hazard.r.samp <- exp(urban.samp)/exp(rural.samp)
    odds.r.samp <- expit(urban.samp)/expit(rural.samp)
    
    ### form frame
    hazard.urban.frame <- data.frame(t(apply(hazard.urban.samp, 1, stats::quantile, c(lower, 0.5, upper))))
    hazard.rural.frame <- data.frame(t(apply(hazard.rural.samp, 1, stats::quantile, c(lower, 0.5, upper))))
    odds.urban.frame <- data.frame(t(apply(odds.urban.samp, 1, stats::quantile, c(lower, 0.5, upper))))
    odds.rural.frame <- data.frame(t(apply(odds.rural.samp, 1, stats::quantile, c(lower, 0.5, upper))))
    hazard.r.frame <- data.frame(t(apply(hazard.r.samp, 1, stats::quantile, c(lower, 0.5, upper))))
    odds.r.frame <- data.frame(t(apply(odds.r.samp, 1, stats::quantile, c(lower, 0.5, upper))))
    
    ### assign column name
    colnames(hazard.urban.frame) <- c("lower", "median", "upper")
    colnames(hazard.rural.frame) <- c("lower", "median", "upper")
    colnames(odds.urban.frame) <- c("lower", "median", "upper")
    colnames(odds.rural.frame) <- c("lower", "median", "upper")
    colnames(hazard.r.frame) <- c("lower", "median", "upper")
    colnames(odds.r.frame) <- c("lower", "median", "upper")
    
    ### assign year
    hazard.urban.frame$years <- rep(beg.year:end.proj.year,length(ages.strata)/2)
    hazard.rural.frame$years <- rep(beg.year:end.proj.year,length(ages.strata)/2)
    odds.urban.frame$years <- rep(beg.year:end.proj.year,length(ages.strata)/2)
    odds.rural.frame$years <- rep(beg.year:end.proj.year,length(ages.strata)/2)
    hazard.r.frame$years <- rep(beg.year:end.proj.year,length(ages.strata)/2)
    odds.r.frame$years <- rep(beg.year:end.proj.year,length(ages.strata)/2)
    
    ### assign age group
    hazard.urban.frame$group <- c(sapply(ages.strata[grep('urban',ages.strata)],rep,n_years))
    hazard.rural.frame$group <- c(sapply(ages.strata[grep('rural',ages.strata)],rep,n_years))
    odds.urban.frame$group <- c(sapply(ages.strata[grep('urban',ages.strata)],rep,n_years))
    odds.rural.frame$group <- c(sapply(ages.strata[grep('rural',ages.strata)],rep,n_years))
    hazard.r.frame$group <- str_remove(c(sapply(ages.strata[grep('urban',ages.strata)],rep,n_years)),':urban')
    odds.r.frame$group <- str_remove(c(sapply(ages.strata[grep('urban',ages.strata)],rep,n_years)),':urban')
    
    ### assign label
    hazard.urban.frame$label <- 'Hazard: Urban'
    hazard.rural.frame$label <- 'Hazard: Rural'
    odds.urban.frame$label <- 'Odds: Urban'
    odds.rural.frame$label <- 'Odds: Rural'
    hazard.r.frame$label <- 'Hazard Ratio'
    odds.r.frame$label <- 'Odds Ratio'
    
    #plot hazard ratio
    if(models.dat$outcome[model.id]=='nmr'){
      open_plot_pdf(file.path(res.dir, "Figures", "Trends", "NMR", paste0(country, "_URhazards_", models[model.id], ".pdf")))
    }else if(models.dat$outcome[model.id]=='u5'){
      open_plot_pdf(file.path(res.dir, "Figures", "Trends", "U5MR", paste0(country, "_URhazards_", models[model.id], ".pdf")))}
    
    g2 <- ggplot(hazard.r.frame) + 
      geom_line(aes(years,median,color=group),lwd=0.75) +
      geom_line(aes(years,lower,color=group),lty=2) + 
      geom_line(aes(years,upper,color=group),lty=2) + 
      ylab('UR Hazard Ratio') + ggtitle(diagnostic_label)
    print(g2)
    
    dev.off()
    
    if(models.dat$outcome[model.id]=='nmr'){
      open_plot_pdf(file.path(res.dir, "Figures", "Trends", "NMR", paste0(country, "_URodds_", models[model.id], ".pdf")))
    }else if(models.dat$outcome[model.id]=='u5'){
      open_plot_pdf(file.path(res.dir, "Figures", "Trends", "U5MR", paste0(country, "_URodds_", models[model.id], ".pdf")))}
    
    g3 <- ggplot(odds.r.frame) + 
      geom_line(aes(years,median,color=group),lwd=0.75) +
      geom_line(aes(years,lower,color=group),lty=2) + 
      geom_line(aes(years,upper,color=group),lty=2) + 
      ylab('UR Odds Ratio') + ggtitle(diagnostic_label)
    print(g3)
    
    dev.off()
  }
}



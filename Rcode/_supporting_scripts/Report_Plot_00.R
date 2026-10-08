#' Report_Plot.R helper functions
#' 
#'

expit <- function(x){
  exp(x)/(1 + exp(x))
}

logit <- function(x){
  log(x/(1-x))
}

report_direct_region_values <- function(direct_frame, area, outcome) {
  value_column <- paste0("median_", outcome)
  if (!value_column %in% names(direct_frame)) {
    return(numeric())
  }

  region_columns <- intersect(c("region", "region.orig"), names(direct_frame))
  if (length(region_columns) == 0) {
    return(numeric())
  }

  area_match <- Reduce(
    `|`,
    lapply(region_columns, function(column) {
      !is.na(direct_frame[[column]]) &
        as.character(direct_frame[[column]]) == as.character(area)
    })
  )
  as.numeric(direct_frame[area_match, value_column, drop = TRUE])
}

report_spaghetti_axis_max <- function(model_median,
                                      model_upper = model_median,
                                      direct_values = numeric(),
                                      margin = 25) {
  values <- c(model_median, model_upper, direct_values)
  values <- values[is.finite(values)]
  if (length(values) == 0) {
    return(margin)
  }
  max(values) + margin
}

## function to organize posterior draws from BB8 

draw_1y_adm <- function(admin_draws, year_num,admin_vec, nsim=1000){
  
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

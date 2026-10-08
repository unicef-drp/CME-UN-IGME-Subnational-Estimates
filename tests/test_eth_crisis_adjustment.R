source('Data/Crisis_Adjustment/prepare_eth_tigray.R')
expect_error <- function(expr, pattern) {
  msg <- tryCatch({ force(expr); NA_character_ }, error = conditionMessage)
  stopifnot(!is.na(msg), grepl(pattern, msg, ignore.case = TRUE))
}
national <- data.frame(years=2021:2022, crisis_d0=c(100,200),
                       crisis_d1_4=c(300,600), pop_0=c(1000,1000), pop_1_4=c(4000,4000))
areas <- data.frame(years=rep(2021:2022,each=3), region=rep(c('a','b','c'),2),
  georepo=rep(c('A','B','C'),2), ucode=rep(c('1','2','3'),2),
  parent_admin1=rep(c('Tigray','Tigray','Other'),2),
  admin1_region=rep(c('t','t','o'),2), admin1_ucode=rep(c('T','T','O'),2),
  raw_pop_0=c(10,30,60,30,10,60), raw_pop_1_4=c(60,20,20,20,60,20))
a <- allocate_eth_crisis_deaths(national,areas)
z <- a[a$level=='admin2',]
stopifnot(isTRUE(all.equal(z$ed_0_1,c(25,75,0,150,50,0))),
          isTRUE(all.equal(z$ed_1_5,c(225,75,0,150,450,0))))
for(y in national$years) for(level in c('admin1','admin2')) {
  d <- a[a$years==y & a$level==level,]
  stopifnot(abs(sum(d$ed_0_1)-national$crisis_d0[national$years==y])<1e-10,
            abs(sum(d$ed_1_5)-national$crisis_d1_4[national$years==y])<1e-10,
            all(d$ed_0_1[d$parent_admin1!='Tigray']==0))
}
expect_error(allocate_eth_crisis_deaths(national,rbind(areas,areas[1,])), 'duplicate')
bad <- areas; bad$raw_pop_1_4[1] <- -1
expect_error(allocate_eth_crisis_deaths(national,bad), 'population')
bad <- areas; bad$parent_admin1 <- 'Other'
expect_error(allocate_eth_crisis_deaths(national,bad), 'Tigray')
expect_error(allocate_eth_crisis_deaths(national,areas[-1,]), 'complete')
source('Rcode/_supporting_scripts/refresh_country_crisis_adjustment.R')
stopifnot(country_crisis_adjustment_family('Ethiopia')=='ethiopia')
cfg <- jsonlite::read_json('Info/Ethiopia_general_info.json',simplifyVector=TRUE)
stopifnot(isTRUE(cfg$doCrisisAdj))
source('Data/Crisis_Adjustment/apply_eth_crisis_adjustment.R')
specs <- eth_crisis_application_specs(project_home())
stopifnot(length(specs)==2L,all(vapply(specs,function(s) grepl('_unstrat_u5_allsurveys_bench_crisis.rda$',s$output_path),TRUE)))
isolated <- new.env(parent=globalenv())
sys.source('Data/Crisis_Adjustment/apply_eth_crisis_adjustment.R',envir=isolated)
stopifnot(is.function(isolated$prepare_eth_crisis_adjustment),
          is.function(isolated$build_cod_crisis_qx),
          is.function(isolated$apply_eth_crisis_adjustment))
# Exercise real refresh dispatch with preparation/application calls intercepted.
# This validates environment lookup and ordering without overwriting outputs.
dispatch <- new.env(parent=globalenv())
sys.source('Rcode/_supporting_scripts/refresh_country_crisis_adjustment.R',envir=dispatch)
dispatch$country <- 'Ethiopia'; dispatch$project_dir <- project_home()
calls <- character()
dispatch$sys.source <- function(file,envir) {
  base::sys.source(file,envir=envir)
  stopifnot(is.function(envir$prepare_eth_crisis_adjustment),
            is.function(envir$apply_eth_crisis_adjustment))
  envir$prepare_eth_crisis_adjustment <- function(project_root,write_output,overwrite) {
    stopifnot(write_output,overwrite,identical(project_root,project_home()))
    calls <<- c(calls,'prepare')
  }
  envir$apply_eth_crisis_adjustment <- function(project_root,write_output,overwrite) {
    stopifnot(write_output,overwrite,identical(project_root,project_home()))
    calls <<- c(calls,'apply')
  }
}
dispatch$main()
stopifnot(identical(calls,c('prepare','apply')))
cat('Ethiopia allocation and refresh tests passed.\n')

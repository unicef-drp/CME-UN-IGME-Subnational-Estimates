source('Data/Crisis_Adjustment/prepare_sdn_darfur.R')
expect_error <- function(expr, pattern) {
  msg <- tryCatch({force(expr); NA_character_}, error=conditionMessage)
  stopifnot(!is.na(msg), grepl(pattern,msg,ignore.case=TRUE))
}
national <- data.frame(years=2004:2005,crisis_d0=c(100,200),
  crisis_d1_4=c(300,600),pop_0=c(1000,1000),pop_1_4=c(4000,4000))
areas <- data.frame(years=rep(2004:2005,each=6),region=rep(paste0('a',1:6),2),
  georepo=rep(c(sdn_darfur_states(),'Other'),2),ucode=rep(paste0('id',1:6),2),
  raw_pop_0=c(10,20,30,15,25,100,25,15,30,20,10,100),
  raw_pop_1_4=c(25,15,30,20,10,100,10,20,30,15,25,100))
a <- allocate_sdn_crisis_deaths(national,areas)
stopifnot(all(a$level=='admin1'),
  isTRUE(all.equal(a$ed_0_1,c(10,20,30,15,25,0,50,30,60,40,20,0))),
  isTRUE(all.equal(a$ed_1_5,c(75,45,90,60,30,0,60,120,180,90,150,0))))
for (yr in national$years) {
  d <- a[a$years==yr,]; n <- national[national$years==yr,]
  stopifnot(abs(sum(d$ed_0_1)-n$crisis_d0)<1e-10,
    abs(sum(d$ed_1_5)-n$crisis_d1_4)<1e-10,
    abs(sum(d$area_pop_0_1)-n$pop_0)<1e-10,
    abs(sum(d$area_pop_1_5)-n$pop_1_4)<1e-10)
}
expect_error(allocate_sdn_crisis_deaths(national,rbind(areas,areas[1,])),'duplicate')
expect_error(allocate_sdn_crisis_deaths(national,areas[-1,]),'incomplete')
bad <- areas;bad$raw_pop_0[1] <- -1
expect_error(allocate_sdn_crisis_deaths(national,bad),'population')
bad <- areas;bad$georepo[bad$georepo=='West Darfur'] <- 'Elsewhere'
expect_error(allocate_sdn_crisis_deaths(national,bad),'Darfur')
bad <- national;bad$years[1] <- 2025
expect_error(allocate_sdn_crisis_deaths(bad,areas),'2004')
source('Data/Crisis_Adjustment/apply_sdn_crisis_adjustment.R')
spec <- sdn_crisis_application_spec(project_home())
stopifnot(spec$level=='admin1',spec$object_name=='bb.res.adm1.strat.u5.bench',
  grepl('Sudan_res_adm1_strat_u5_bench_crisis.rda$',spec$output_path))
isolated <- new.env(parent=globalenv())
sys.source('Data/Crisis_Adjustment/apply_sdn_crisis_adjustment.R',envir=isolated)
stopifnot(is.function(isolated$prepare_sdn_crisis_adjustment),
  is.function(isolated$apply_sdn_crisis_adjustment),is.function(isolated$build_cod_crisis_qx))
dispatch <- new.env(parent=globalenv())
sys.source('Rcode/_supporting_scripts/refresh_country_crisis_adjustment.R',envir=dispatch)
stopifnot(dispatch$country_crisis_adjustment_family('Sudan')=='sudan')
dispatch$country <- 'Sudan';dispatch$project_dir <- project_home();calls <- character()
dispatch$sys.source <- function(file,envir) {
  base::sys.source(file,envir=envir)
  envir$prepare_sdn_crisis_adjustment <- function(project_root,write_output,overwrite) {
    stopifnot(write_output,overwrite);calls <<- c(calls,'prepare')
  }
  envir$apply_sdn_crisis_adjustment <- function(project_root,write_output,overwrite) {
    stopifnot(write_output,overwrite);calls <<- c(calls,'apply')
  }
}
dispatch$main()
stopifnot(identical(calls,c('prepare','apply')))
cat('Sudan allocation, selected model and refresh dispatch tests passed.\n')

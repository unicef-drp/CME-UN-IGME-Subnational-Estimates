source('Rcode/_supporting_scripts/refresh_country_crisis_adjustment.R')
stopifnot(identical(country_crisis_adjustment_family('Malawi'), 'malawi'))
source('Data/Crisis_Adjustment/apply_mwi_crisis_adjustment.R')
root <- normalizePath('.', winslash='/', mustWork=TRUE)
r <- apply_mwi_crisis_adjustment(root, write_output=FALSE, quiet=TRUE)
stopifnot(identical(names(r), c('adm1','adm2')))
for (adm in names(r)) {
  s <- mwi_crisis_application_specs(root)[[adm]]
  base <- load_required_rda_object(s$input_path,s$object_name)
  q <- r[[adm]]$crisis_qx
  stopifnot(all(q$years==2001L),abs(sum(q$ed_0_1)-22017)<1e-7,
    abs(sum(q$ed_1_5)-14780)<1e-7,nrow(q)==if(adm=='adm1') 3L else 32L)
  out <- r[[adm]]$model
  for (component in c('overall','stratified')) {
    old <- base[[component]]; new <- out[[component]]
    shift <- q$crisis_5q0[match(crisis_region_year_key(old$region,old$years),crisis_region_year_key(q$region,q$years))]
    shift[is.na(shift)] <- 0
    for (column in c('median','mean','lower','upper')) stopifnot(max(abs(new[[column]]-old[[column]]-shift))<1e-12)
    stopifnot(identical(old[old$years!=2001,],new[new$years!=2001,]))
  }
  for (component in c('draws.est.overall','draws.est')) for(i in seq_along(base[[component]])) {
    b <- base[[component]][[i]]; a <- out[[component]][[i]]
    shift <- q$crisis_5q0[match(crisis_region_year_key(b$region,b$years),crisis_region_year_key(q$region,q$years))]
    if(is.na(shift)) shift <- 0
    stopifnot(max(abs(a$draws-b$draws-shift))<1e-12)
  }
  for (component in setdiff(names(base),c('overall','stratified','draws.est.overall','draws.est'))) stopifnot(identical(base[[component]],out[[component]]))
  stopifnot(max(r[[adm]]$sensitivity$population_only_5q0)-min(r[[adm]]$sensitivity$population_only_5q0)<1e-12)
}
cat('Malawi application, death reconciliation, sensitivity, saved draw and non-target preservation checks passed.\n')

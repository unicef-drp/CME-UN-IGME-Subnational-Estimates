source("Rcode/_supporting_scripts/admin_benchmark_helpers.R")
ds<-list(list(region="A",years=2024,draws=c(.02,.04,.09)),list(region="B",years=2024,draws=c(.08,.06,.03)),list(region="A",years=2025,draws=c(.01,.02,.03)),list(region="B",years=2025,draws=c(.03,.04,.05)))
w<-data.frame(region=rep(c("B","A"),2),years=rep(2024:2025,each=2),proportion=rep(c(.7,.3),2))
r<-list(overall=data.frame(region=c("A","B","A","B"),years=c(2024,2024,2025,2025),median=c(.04,.06,.02,.04),mean=c(.05,.06,.02,.04),variance=1,lower=0,upper=1),draws.est.overall=ds,draws.est=ds,CI=.9,draws=list("latent"))
r$overall$strata_all <- 1
before<-serialize(r,NULL)
adj<-compute_admin_benchmark_adjustment("Test",2024:2025,ds,w,data.frame(year=2024:2025,OBS_VALUE=c(.07,.05)))
z<-benchmark_admin_result(r,adj)
stopifnot(identical(before,serialize(r,NULL)),identical(z$benchmark$method,"direct_pointmedian_v1"),is.null(z$draws))
for(y in 2024:2025){s<-z$overall[z$overall$years==y,];ww<-w[w$years==y,];stopifnot(abs(sum(s$median*ww$proportion[match(s$region,ww$region)])-adj$igme[adj$years==y])<1e-12)}
bad<-adj;bad$factor[1]<-100
stopifnot(inherits(try(benchmark_admin_result(r,bad),silent=TRUE),"try-error"))
stopifnot(inherits(try(compute_admin_benchmark_adjustment("Test",2024:2025,ds,w[-1,],data.frame(year=2024:2025,OBS_VALUE=c(.07,.05))),silent=TRUE),"try-error"))
for(p in c("Rcode/8_10_BB8.R","Rcode/8_10_BB8_unstrat_only.R","Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R","Rcode/_supporting_scripts/final_admin2_recovery.R")){
 t<-paste(readLines(p,warn=FALSE),collapse="\n")
 stopifnot(!grepl("ratio.bench",t,fixed=TRUE),grepl("benchmark_admin_result",t,fixed=TRUE))
}
cat("Separate benchmark forecast closure, input preservation and entrypoint tests passed.\n")

# Relative path base must also apply to unwrapped readLines/writeLines.
task_root <- tempfile("benchmark_diagnostics_")
dir.create(file.path(task_root,"Betabinomial","NMR"),recursive=TRUE)
runtime_path <- function(path) file.path(task_root,path)
for(component in c("temporals","hyperpar","fixed")){
 name<-paste0("bb.",component,".adm1.unstrat.nmr.allsurveys")
 assign(name,list(source="HIV-only"))
 save(list=name,file=file.path(task_root,"Betabinomial","NMR",paste0("Test_",component,"_adm1_unstrat_nmr_allsurveys.rda")))
}
writeLines("Source fit",file.path(task_root,"Betabinomial","NMR","Test_fit_adm1_unstrat_nmr_allsurveys.txt"))
save_benchmark_source_diagnostics("Test","NMR","adm1_unstrat_nmr_allsurveys","adm1_unstrat_nmr_allsurveys_bench")
stopifnot(file.exists(file.path(task_root,"Betabinomial","NMR","Test_fit_adm1_unstrat_nmr_allsurveys_bench.txt")))
rm(runtime_path)
unlink(task_root,recursive=TRUE)
cat("Benchmark diagnostics respect the shared runtime path base.\n")
# The default targets weighted marginal medians, not median(weighted draws).
noncomonotonic <- list(list(region="A",years=2025,draws=c(.01,.02,.09)),list(region="B",years=2025,draws=c(.04,.08,.03)))
b<-compute_admin_benchmark_adjustment("Test",2025,noncomonotonic,data.frame(region=c("A","B"),years=2025,proportion=.5),data.frame(year=2025,OBS_VALUE=.06))
stopifnot(abs(b$est-.03)<1e-12,abs(b$factor-2)<1e-12)
cat("Weighted marginal medians remain distinct from joint-aggregate medians.\n")

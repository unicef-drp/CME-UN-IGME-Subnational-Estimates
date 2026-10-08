source('Rcode/_supporting_scripts/benchmark_pilot_report.R')
stopifnot(is.null(load_benchmark_pilot(tempdir(),'NoPilotCountry')))
p <- load_benchmark_pilot(getwd(),'Namibia')
stopifnot(identical(p$country,'Namibia'),nrow(p$aggregate)==156L,nrow(p$regional)==2184L)
t <- benchmark_pilot_key_table(p)
stopifnot(nrow(t)==4L,all(abs(t$Custom-t$National)<1e-9),all(t$Custom>t$Existing),
          grepl('not propagated',paste(p$limitations,collapse=' '),fixed=TRUE))
rr <- readLines('Rcode/11_CountrySummary.Rmd',warn=FALSE)
qq <- readLines('Rcode/9_Comparison_Plot.qmd',warn=FALSE)
stopifnot(any(grepl('benchmark_pilot_pdf',rr,fixed=TRUE)),any(grepl('benchmark_pilot_dashboard',qq,fixed=TRUE)))
# Existing model data and pilot data have separate sources and labels.
stopifnot(any(grepl('pilot_bundle.rds',readLines('Rcode/_supporting_scripts/benchmark_pilot_report.R'),fixed=TRUE)))
cat('PASS: optional report bundle, matching source snapshots, national alignment, explicit uncertainty, both report consumers.\n')

mwi_crisis_report_notes <- function(home_dir) {
  notes <- c('Malawi crisis adjustment: national infant and ages 1-4 crisis deaths for 2001 are allocated separately using district food-aid beneficiary shares from FAO/WFP, Special Report: Malawi, 29 May 2002, Table 7. Historical districts are mapped to current areas; successor areas share their district allocation in proportion to the corresponding 2001 age-specific population. The regional allocation is Central 45.32 percent, Southern 47.94 percent and Northern 6.74 percent.',
    'The source projects food-aid need for June 2002-March 2003. Its application to 2001 is an assumed geographic allocation informed by food insecurity, not observed excess mortality. Zero beneficiary weights do not establish zero crisis deaths. A population-only allocation is retained as a sensitivity analysis.',
    'Deterministic increments are added to benchmarked U5MR summaries and estimated draws for 2001 only. NMR is unchanged. National infant and ages 1-4 death totals are preserved. The nonlinear conversion does not guarantee exact aggregation of local U5MR increments to the national increment. Uncertainty intervals do not incorporate additional uncertainty in crisis deaths or their geographic allocation.')
  nat <- function(file) {
    x <- read.csv(file.path(home_dir,'Data/IGME',file))
    v <- x[x$ISO.Code=='MWI' & tolower(x$Quantile)=='median','X2001.5']
    if(length(v)!=1L || !is.finite(v)) stop('Missing national MWI 2001 median.')
    v
  }
  curve <- nat('igme2026_u5.csv')-nat('igme2026_u5_nocrisis.csv')
  w <- readxl::read_xlsx(file.path(home_dir,'Data/Crisis_Adjustment/Crisis_Under5_deaths_2026.xlsx'))
  rate <- w[['Crisis rate 0-5']][w$ISO3Code=='MWI' & floor(w$Year)==2001]
  if(length(rate)!=1L || !is.finite(rate)) stop('Missing MWI crisis workbook rate.')
  if(abs(curve-rate)>0.1) notes <- c(notes,sprintf('National comparison caveat: the supplied national curve contains a 2001 crisis increment of %.2f per 1,000, while the finalized crisis workbook specifies %.2f. These subnational results use the finalized workbook deaths; comparison with the supplied national crisis-inclusive curve in 2001 is provisional.',curve,rate))
  notes
}

# Optional, explicitly labelled benchmark-review supplement. Does not select or
# replace any production model. A missing bundle leaves existing reports alone.
load_benchmark_pilot <- function(home_dir,country) {
  asset_dir <- file.path(home_dir,'Results',country,'BenchmarkPilot')
  path <- file.path(asset_dir,'pilot_bundle.rds')
  if(!file.exists(path)) return(NULL)
  p <- readRDS(path)
  stopifnot(identical(p$country,country),is.data.frame(p$aggregate),is.data.frame(p$regional))
  hashes <- vapply(p$input_hashes$path,function(f)digest::digest(file=f,algo='sha256'),character(1))
  if(!identical(unname(hashes),p$input_hashes$sha256)) {
    stop('Benchmark pilot inputs changed; refresh and validate the pilot before reporting it.')
  }
  custom <- p$aggregate[p$aggregate$method=='Custom calibration',]
  stopifnot(all(abs(custom$median-custom$national)<1e-9),!anyDuplicated(paste(custom$outcome,custom$year)))
  p$asset_dir <- normalizePath(asset_dir,winslash='/'); p
}

benchmark_pilot_key_table <- function(p) {
  a <- p$aggregate
  z <- a[a$method=='Custom calibration' & a$year %in% c(2024,2025),]
  current <- a[a$method=='Current offset refit',]
  idx <- match(paste(z$outcome,z$year),paste(current$outcome,current$year))
  data.frame(Outcome=ifelse(z$outcome=='u5','U5MR','NMR'),Year=z$year,
             Existing=current$median[idx],Custom=z$median,National=z$national,
             `Regional range`=sprintf('%.2f - %.2f',z$min_regional_median,z$max_regional_median),check.names=FALSE)
}

benchmark_pilot_pdf <- function(p) {
  if(is.null(p)) return(invisible(NULL))
  cat('\n\\clearpage\n\n# National benchmark review: Admin-1 pilot\n\n')
  cat('**Review date: ',p$date,'. Experimental results; configured final models remain unchanged.**\n\n',sep='')
  cat(paste(p$findings,collapse='\n\n'),'\n\n')
  cat('National target / median of population-weighted base draws = annual calibration factor. The factor is applied to every regional draw for that year.\n\n')
  cat('## Numerical comparison\n\nRates per 1,000 live births. Existing, custom, and national columns refer to medians of population-weighted draws or the national target.\n\n')
  cat(knitr::kable(benchmark_pilot_key_table(p),format='latex',booktabs=FALSE,digits=2,row.names=FALSE),'\n\n')
  cat('## Interpretation\n\n',paste(p$limitations,collapse='\n\n'),'\n\n',sep='')
  cat('The NMR factor is 1.695 in 2024, compared with 1.101 for U5MR, relative to the unbenchmarked base. Erongo NMR in 2024 is 20.84 with a conditional 90 percent interval of 9.73 to 46.44.\n\n')
  cat('SUMMER developer discussion: ',p$issue_url,'\n\n',sep='')
  for(o in c('u5','nmr')) {
    label <- if(o=='u5') 'U5MR' else 'NMR'
    cat('\n\\clearpage\n\n## ',label,': custom benchmark results\n\n',sep='')
    for(suffix in c('custom_regions','national_comparison')) {
      file <- file.path(p$asset_dir,paste0(o,'_',suffix,'.png'))
      stopifnot(file.exists(file))
      cat('\\begin{center}\n\\includegraphics[width=0.88\\linewidth]{',file,'}\n\\end{center}\n',sep='')
    }
  }
  cat('\n\\clearpage\n\n')
  invisible(NULL)
}

benchmark_pilot_dashboard <- function(p) {
  if(is.null(p)) return(NULL)
  tag <- htmltools::tags
  cols <- c('HIV-adjusted base'='#7B8794','Current offset refit'='#D55E00','Custom calibration'='#0072B2')
  aggregate_plot <- function(o) {
    a <- p$aggregate[p$aggregate$outcome==o,]
    g <- plotly::plot_ly()
    for(m in names(cols)) {
      z <- a[a$method==m,];z<-z[order(z$year),]
      g <- plotly::add_trace(g,x=z$year,y=z$median,type='scatter',mode='lines',name=m,
        line=list(color=cols[[m]],width=3),hovertemplate=paste(m,'<br>Year %{x}<br>Median %{y:.2f}<extra></extra>'))
    }
    z <- a[a$method=='Custom calibration',]
    g <- plotly::add_trace(g,x=z$year,y=z$national,type='scatter',mode='lines',name='National target',line=list(color='black',dash='dash',width=2))
    plotly::layout(g,title=paste(if(o=='u5') 'U5MR' else 'NMR','- national alignment'),
      xaxis=list(title='Year'),yaxis=list(title='Deaths per 1,000 live births'),
      margin=list(l=85,r=35,t=100,b=85),legend=list(orientation='h',y=1.1),height=780)
  }
  regional_plot <- function(o) {
    r <- p$regional[p$regional$outcome==o & p$regional$method=='Custom calibration',]
    n <- p$national[p$national$outcome==o,]
    g <- plotly::plot_ly(r,x=~year,y=~median,color=~region_name,type='scatter',mode='lines',
       customdata=~paste0(region_name,'<br>90% interval: ',round(lower,2),' - ',round(upper,2)),
       hovertemplate='%{customdata}<br>Year %{x}<br>Median %{y:.2f}<extra></extra>')
    g <- plotly::add_trace(g,x=n$year,y=n$target*1000,inherit=FALSE,type='scatter',mode='lines',name='National target',line=list(color='black',width=4))
    plotly::layout(g,title=paste(if(o=='u5') 'U5MR' else 'NMR','- custom-calibrated regional medians'),
      xaxis=list(title='Year'),yaxis=list(title='Deaths per 1,000 live births'),
      margin=list(l=85,r=35,t=150,b=85),legend=list(orientation='h',y=1.16),height=780)
  }
  table <- DT::datatable(benchmark_pilot_key_table(p),rownames=FALSE,options=list(dom='t',scrollX=TRUE))
  table <- DT::formatRound(table,columns=c('Existing','Custom','National'),digits=2)
  htmltools::tagList(
    tag$section(id='national-benchmark-pilot',
      tag$h1('National benchmark review: Admin-1 pilot'),
      tag$p(tag$strong(paste('Review date:',p$date,'|',p$status))),
      lapply(p$findings,tag$p),
      tag$p(tag$strong('Factor = national median / median of population-weighted base draws.')),
      tag$h2('Numerical comparison'),tag$p('Rates per 1,000 live births. Aggregates are medians of weighted draws.'),table,
      tag$h2('Interpretation and limits'),tag$ul(lapply(p$limitations,tag$li)),
      tag$p('In 2024 the factor is 1.101 for U5MR and 1.695 for NMR, relative to the unbenchmarked base. Erongo NMR is 20.84 with a conditional 90% interval of 9.73-46.44.'),
      tag$p(tag$a(href=p$issue_url,'SUMMER developer discussion: issue 40')),
      tag$h2('National alignment'),tag$p('The dashed national line overlaps the custom aggregate in every year.'),
      aggregate_plot('u5'),aggregate_plot('nmr'),
      tag$h2('Custom regional estimates'),tag$p('Hover over a region for its median and conditional 90% interval. Click legend entries to select regions. All following original model-comparison panels retain their existing model definitions.'),
      regional_plot('u5'),regional_plot('nmr')))
}

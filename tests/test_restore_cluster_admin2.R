suppressPackageStartupMessages(library(sf))
source('Rcode/_supporting_scripts/restore_cluster_admin2.R')
box <- function(x) st_polygon(list(matrix(c(x,0,x+1,0,x+1,1,x,1,x,0),ncol=2,byrow=TRUE)))
p <- st_sf(NAME_2=c('West','East'), geometry=st_sfc(box(0),box(1)), crs=4326)
map <- data.frame(GeoRepo=c('West','East'), Internal=c('admin2_1','admin2_2'))
d <- data.frame(cluster=c(2L,1L,2L),survey=2018,LONGNUM=c(1.5,.5,1.5),
 LATNUM=.5,Y=c(1L,0L,2L),total=c(10,11,12),strata='original',admin1.char='admin1_1')
r <- restore_cluster_admin2_from_gps(d,p,'NAME_2',map)
stopifnot(identical(r$data[names(d)],d),
 identical(r$data$admin2.char,c('admin2_2','admin2_1','admin2_2')),
 r$outside_clusters==0L)
outside <- d; outside$LONGNUM[outside$cluster==2L] <- 2.01
stopifnot(restore_cluster_admin2_from_gps(outside,p,'NAME_2',map)$outside_clusters==1L)
fails <- function(expr) inherits(tryCatch({force(expr);NULL},error=identity),'error')
bad <- d; bad$LATNUM[1] <- NA_real_
stopifnot(fails(restore_cluster_admin2_from_gps(bad,p,'NAME_2',map)))
bad <- d; bad$LONGNUM[1] <- 1.6
stopifnot(fails(restore_cluster_admin2_from_gps(bad,p,'NAME_2',map)))
stopifnot(fails(restore_cluster_admin2_from_gps(d,p,'NAME_2',map[2:1,])))
stopifnot(fails(restore_cluster_admin2_from_gps(r$data,p,'NAME_2',map)))
cat('PASS: Admin-2 restoration preserves input columns and rejects inconsistent inputs.\n')

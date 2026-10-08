source('Data/Crisis_Adjustment/prepare_sdn_darfur.R')
expect_error <- function(expr, pattern) {
  msg <- tryCatch({force(expr); NA_character_}, error=conditionMessage)
  stopifnot(!is.na(msg), grepl(pattern,msg,ignore.case=TRUE))
}
n <- data.frame(years=2025L,crisis_d0=6257,crisis_d1_4=9215,
  pop_0=1604170,pop_1_4=6114387)
states <- c('Aj Jazirah','Blue Nile','Central Darfur','East Darfur','Gedaref',
  'Kassala','Khartoum','North Darfur','North Kordofan','Northern','Red Sea',
  'River Nile','Sennar','South Darfur','South Kordofan','West Darfur',
  'West Kordofan','White Nile')
a <- data.frame(years=2025L,region=paste0('admin1_',1:18),georepo=states,
  ucode=paste0('id',1:18),raw_pop_0=1:18,raw_pop_1_4=18:1)
w <- data.frame(years=2025L,georepo=states,fatalities_2025=0:17)
d <- allocate_sdn_2025_deaths(n,a,w)
stopifnot(abs(sum(d$ed_0_1)-6257)<1e-9,abs(sum(d$ed_1_5)-9215)<1e-9,
  abs(sum(d$area_pop_0_1)-1604170)<1e-8,
  abs(sum(d$area_pop_1_5)-6114387)<1e-8,
  all(d$allocation_share_0_1==d$allocation_share_1_5),
  all(abs(d$ed_0_1/6257-d$fatalities_2025/sum(w$fatalities_2025))<1e-12),
  d$ed_0_1[d$georepo==states[1]]==0)
expect_error(allocate_sdn_2025_deaths(n,a,w[-1,]),'coverage')
expect_error(allocate_sdn_2025_deaths(n,a,rbind(w,w[1,])),'duplicate')
bad <- w;bad$fatalities_2025[1] <- -1
expect_error(allocate_sdn_2025_deaths(n,a,bad),'fatalit')
bad <- w;bad$fatalities_2025 <- 0
expect_error(allocate_sdn_2025_deaths(n,a,bad),'fatalit')
bad <- n;bad$years <- 2024L
expect_error(allocate_sdn_2025_deaths(bad,a,w),'2025')
bad <- a;bad$raw_pop_0[1] <- 0
expect_error(allocate_sdn_2025_deaths(n,bad,w),'population')
bad <- a;bad$ucode[1] <- bad$ucode[2]
expect_error(allocate_sdn_2025_deaths(n,bad,w),'duplicate')
source_weights <- read_sdn_2025_weights('Data/Crisis_Adjustment/sdn_2025_state_weights.csv')
stopifnot(nrow(source_weights)==18, sum(source_weights$fatalities_2025)==18663,
  all(rowSums(source_weights[paste0('q',1:4,'_2025')])==source_weights$fatalities_2025))
cat('Sudan 2025 age totals, geographic weights and input guards passed.\n')

USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))
source(file.path(dir_subnational, "Rcode/_supporting_scripts/urban_frame_matching.R"))
if (!exists("country", inherits = TRUE)) {
  stop("Run/source Rcode/1_Preperation.R first.", call. = FALSE)
}


# Country context is loaded by Rcode/1_Preperation.R.

# Load libraries and Info -----------------------------------------------

library(stringdist)
library(openxlsx)
library(readr)

# extract file location of this script
code.path <- file.path(project_home(), "Rcode/7a_UR_prop.R")
code.path.splitted <- strsplit(code.path, "/")[[1]]

home.dir <- paste(code.path.splitted[1: (length(code.path.splitted)-2)], collapse = "/")
data.dir <- country_data_dir(home.dir, country) # set the directory to store the data
res.dir <- file.path(home.dir, "Results", country) # set the directory to store the results (e.g. fitted R objects, figures, tables in .csv etc.)
require_country_context()
if (!exists("frame_year", inherits = TRUE) || is.null(frame_year)) {
  stop("Set frame_year in Info/", country,
       "_general_info.json before running this step.",
       call. = FALSE)
}
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}

use_path_base(data.dir)

load(file.path(poly.path, paste0(country, "_Amat.rda")))  # load the adjacency matrix
load(file.path(poly.path, paste0(country, "_Amat_Names.rda")))  # load names of admin1 and admin2 regions

# properly format urban proportion table for sample frame -----------------------------------------------
## BEFORE RUNNING THIS SECTION: follow vignette to create a txt file with urban population fraction at admin1 level

greedyAssign <- function(a,b,d){
  x <- numeric(length(a)) # assgn variable: 0 for unassigned but assignable, 
  # 1 for already assigned, -1 for unassigned and unassignable
  while(any(x==0)){
    min_d <- min(d[x==0]) # identify closest pair, arbitrarily selecting 1st if multiple pairs
    a_sel <- a[d==min_d & x==0][1] 
    b_sel <- b[d==min_d & a == a_sel & x==0][1] 
    x[a==a_sel & b == b_sel] <- 1
    x[x==0 & (a==a_sel|b==b_sel)] <- -1
  }
  cbind(a=a[x==1],b=b[x==1],d=d[x==1])
}

for (year in frame_year) {
  frame_file <- file.path(home.dir, 'Data/urban_frames',
                          paste0(country.abbrev, '_', year, '_frame_urb_prop.csv'))

  # read the csv file containing urban population fraction at admin1 level.
  frame <- readr::read_csv(frame_file)
  frame <- data.frame(frame)
  admin_name_col <- if ("GeoRepo" %in% names(admin1.names)) {
    "GeoRepo"
  } else {
    "GADM"
  }
  admin_labels <- normalize_urban_frame_admin_label(
    admin1.names[[admin_name_col]]
  )
  frame <- expand_urban_frame_to_current_admin(
    frame,
    admin1.names[[admin_name_col]],
    if (exists("urban_frame_admin1_parent_map", inherits = TRUE)) {
      urban_frame_admin1_parent_map
    } else {
      NULL
    }
  )

  ## check that that the admin1 names in your table and admin1.names (from the DHS data) are the same (differences in spacing or accents is fine)
  stopifnot(identical(sort(frame[[1]]), sort(admin_labels)))

  # greedy algorithm to match admin names
  adm1.ref <- expand.grid(frame[[1]],
                          admin_labels,
                          stringsAsFactors = FALSE) # Distance matrix in long form
  names(adm1.ref) <- c("frame_name","georepo_name")

  ### string distance,  jw=jaro winkler distance, try 'dl' if not working
  adm1.ref$dist <- stringdist(adm1.ref$frame_name,
                              adm1.ref$georepo_name, method = "jw")

  match_order <- data.frame(greedyAssign(adm1.ref$frame_name,
                                         adm1.ref$georepo_name,
                                         adm1.ref$dist))
  names(match_order) <- c("frame_name", "georepo_name", "dist")

  # create reference table
  ref.tab <- admin1.names
  ref_match <- match(admin_labels, match_order$georepo_name)
  if (any(is.na(ref_match))) {
    stop("Could not match urban-frame rows to GeoRepo admin1 names: ",
         paste(ref.tab[[admin_name_col]][is.na(ref_match)], collapse = ", "))
  }
  frame_match <- match(match_order$frame_name[ref_match], frame[[1]])
  if (any(is.na(frame_match))) {
    stop("Could not recover urban-frame rows after name matching: ",
         paste(match_order$frame_name[ref_match][is.na(frame_match)],
               collapse = ", "))
  }
  ref.tab$matched_name <- frame[[1]][frame_match] ### check that names match!!!
  ref.tab$urb_frac <- frame[[2]][frame_match]

  ## save reference table -----------------------------------------------
  if(!dir.exists(file.path(res.dir, 'UR'))) {
    dir.create(file.path(res.dir, 'UR'))
  }
  save(ref.tab, file = file.path(res.dir, 'UR', paste0('urb_prop_', year, '.rda')))
}

if (length(frame_year) == 1) {
  save(ref.tab, file = file.path(res.dir, 'UR/urb_prop.rda'))
}
message("Finished processing urban proportion data for ", country, " for frame year(s): ", paste(frame_year, collapse = ", "),
        " saved to ", file.path(res.dir, 'UR'))

        

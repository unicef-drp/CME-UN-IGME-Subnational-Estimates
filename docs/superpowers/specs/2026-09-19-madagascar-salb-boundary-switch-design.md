# Madagascar SALB Boundary Switch Design

## Objective

Replace Madagascar's GADM 4.1 boundaries with the validated UN SALB dataset whose temporal validity is 2014-09-27 through 2021-06-23, then regenerate every boundary-dependent Madagascar artifact.

## Source selection

Use the SALB ArcGIS item `9013b63ff3694106baa2ea8cd701223c` from <https://salb.un.org/en/data/mdg>. This is the boundary period that covers the 2018 MICS frame and retains the six-province and 22-region hierarchy used by the surveys. Do not use the later 23- or 24-region SALB revisions for this run.

## Storage and normalization

Store the downloaded source archive, extracted source shapefile, normalized pipeline layers, and provenance metadata directly in `Data/shapeFiles/_alt`. Create normalized layers named `salb_MDG_0`, `salb_MDG_1`, and `salb_MDG_2`. Retain source-native names in normalized `NAME_1` and `NAME_2` fields, and retain SALB administrative codes.

Admin-2 is the 22-feature SALB source layer. Admin-1 is dissolved from Admin-2 by `adm1nm` into six provinces. Admin-0 is dissolved from all Admin-2 features. All layers use the source CRS and valid polygonal geometry.

## Configuration and preprocessing

Point `Info/Madagascar_general_info.json` to `../shapeFiles/_alt` and the three SALB layers. Remove the GADM-specific Madagascar MICS name recodes so MICS labels use the source-native SALB spelling. Replace the GADM-specific configuration test with SALB source, layer, feature-count, hierarchy, and metadata assertions.

## Replacement and rerun

Remove `Data/Countries/Madagascar/shapeFiles/gadm41_MDG_shp` after the SALB layers pass validation. Inventory and back up current Madagascar boundary-dependent data and results, then rerun the production pipeline. The user explicitly authorized overwriting current Madagascar results as needed.

## Validation

Require 1 Admin-0 feature, 6 unique Admin-1 features, and 22 unique Admin-2 features. Require all Admin-2 parent names to exist in Admin-1, the ISO3 code to be `MDG`, nonempty names, readable geometries, and provenance metadata containing the SALB page, ArcGIS item, temporal validity, download time, and source archive checksum. Run the focused Madagascar tests plus the general information and boundary tests before the production rerun. Inspect the generated manifest and representative boundary-dependent plots and final PDF.

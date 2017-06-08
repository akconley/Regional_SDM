# File: 0_pathsAndSettings.r
# Purpose: to define a set of consistently used objects for a full modeling
#   run. The goal is to avoid redundancy and improve consistency among scripts.


# Set inputs ----
# These locations require data created not as part of these scripts

# The folder that has your species polygon data. 
loc_spPoly <- "W:\\Projects\\Lands&Forests\\2016_PROs\\2016_Polygons\\EDM_feature_polys"

# This is the full path and name of the information-tracking database
nm_db_file <- "C:\\Users\\Public\\Git_Repos\\PROs\\BackEnd.sqlite"

# This is the background random points shapefile, path then name (without the 'shp)
loc_bkgPts <- "C:\\Users\\Public\\2016_Pros\\BackgroundPoints"
nm_bkgPts <- "10k_backgroundPts_2_att"

# the folder containing all environmental variable raster (tiffs)
loc_envVars <- "D:\\Env_Var_Copy\\Env_Variables"

# the path where the next two shapefiles are stored
loc_otherSpatial <- "C:\\Users\\Public\\2016_Pros\\other_spatial"

# A shapefile showing state boundaries (or other reference boundaries)
# used in the map produced in the metadata
nm_refBoundaries <- "NY_bound_mod"

# A shapefile showing the extent of the study area over which the model 
# was created. This is also used in the metadata map.
nm_studyAreaExtent <- "NY_bound_mod"


# Set destination folders ----
# These locations are initially locations where outputs are written. 
# In many cases, they become input folders later in the process. 

# The folder for species point data
loc_spPts <- "C:\\Users\\Public\\2016_Pros\\inputs\\species\\points_data"

# output folder for RData files
loc_RDataOut <- "C:\\Users\\Public\\2016_Pros\\outputs"

# output folder for grids (raster predictions)
loc_outRas <- "C:\\Users\\Public\\2016_Pros\\outputs\\grids"

# output folder for metadata
loc_outMetadata <- "C:\\Users\\Public\\2016_Pros\\outputs\\metadata"

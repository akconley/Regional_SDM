# File: 1_pointsInPolys_cleanBkgPts.r
# Purpose: 
# 1. Sampling of EDM polygons to create random points within the polygons
#  these are the random presence points being created here, from polygon presence data.
# 2. Removing any points from the background points dataset that overlap or are near
#  the input presence polygon dataset.

library(RSQLite)
library(rgdal)
library(sp)
library(rgeos)

####
# Assumptions
# - the shapefile is named with the species code that is used in the lookup table
#   e.g. glypmuhl.shp
# - There is lookup data in the sqlite database to link to other element information (full name, common name, etc.)
# - the polygon shapefile has at least these fields EO_ID_ST, SNAME, SCOMNAME, RA

####
#### load input poly ----

###
## two lines need your attention. The one directly below (loc_scripts)
## and about line 38 where you choose which polygon file to use

loc_scripts <- "D:\\Git_Repos\\Regional_SDM"
source(paste(loc_scripts, "0_pathsAndSettings.R", sep = "/"))

setwd(loc_spPoly)

#get a list of what's in the directory
fileList <- dir( pattern = ".shp$")
fileList

#look at the output and choose which shapefile you want to run
#enter its location in the list (first = 1, second = 2, etc)
n <- 1

# load data, QC ----
fileName <- fileList[[n]]
shpName <- strsplit(fileName,"\\.")[[1]][[1]]
sppCode <- shpName

presPolys <- readOGR(fileName, layer = shpName) #Z-dimension discarded msg is OK
#check for proper column names. If no error from next code block, then good to go
shpColNms <- names(presPolys@data)
desiredCols <- c("EO_ID", "SCIEN_NAME", "COMMONNAME", "ERACCURACY")
if("FALSE" %in% c(desiredCols %in% shpColNms)) {
	  stop("at least one column is missing or incorrectly named")
  } else {
    print("Required columns are present")
  }

#pare down columns
presPolys@data <- presPolys@data[,desiredCols]

#get projection info for later
projInfo <- presPolys@proj4string

# explode multi-part polys ----
shp_expl <- disaggregate(presPolys)

#add some columns (explode id and area)
shp_expl@data <- cbind(shp_expl@data, 
	EXPL_ID = rownames(shp_expl@data), 
	AREAM2 = sapply(slot(shp_expl, "polygons"), slot, "area"))
		
# projection info doesn't stick, apply from what we grabbed earlier
shp_expl@proj4string <- projInfo
#write out the exploded polygon set
nm.PyFile <- paste(sppCode, "_expl", sep = "")
writeOGR(shp_expl, dsn = ".", layer = nm.PyFile, driver="ESRI Shapefile", overwrite_layer=TRUE)
  
#name of random points output shapefile; add path to (now input) polygon file
nm.RanPtFile <- paste(loc_spPts,"/", sppCode, "_RanPts", sep = "")
nm.PyFile <- paste(loc_spPoly,"/", sppCode, "_expl", sep = "")

####
####  Placing random points within each sample unit (polygon/EO) ----
####

#get the attribute table from above 
att.pt <- shp_expl@data

# just in case convert to lower
names(att.pt) <- tolower(names(att.pt))

#calculate Number of points for each poly, stick into new field
att.pt$PolySampNum <- round(400*((2/(1+exp(-(att.pt[,"aream2"]/900+1)*0.004)))-1))
#make a new field for the design, providing a stratum name
att.pt <- cbind(att.pt, "panelNum" = paste("poly_",att.pt$expl_id, sep=""))

# sample must be equal or larger than the RA sample size in the random forest model
att.pt$eraccuracy <- factor(tolower(as.character(att.pt$eraccuracy)))

EObyRA <- unique(att.pt[,c("expl_id", "eo_id","eraccuracy")])
EObyRA$minSamps[EObyRA$eraccuracy == "very high"] <- 5
EObyRA$minSamps[EObyRA$eraccuracy == "high"] <- 4
EObyRA$minSamps[EObyRA$eraccuracy == "medium"] <- 3
EObyRA$minSamps[EObyRA$eraccuracy == "low"] <- 2
EObyRA$minSamps[EObyRA$eraccuracy == "very low"] <- 1

att.pt.2 <- merge(x = att.pt, y = EObyRA[,c("expl_id","minSamps")], 
                  all.x = TRUE, by.x = "expl_id", by.y = "expl_id")

att.pt.2$finalSampNum <- ifelse(att.pt.2$PolySampNum < att.pt.2$minSamps, 
                                att.pt.2$minSamps, 
                                att.pt.2$PolySampNum)

# add two more cols for later (backwards compatibility with old GRTS routine)
att.pt.2$stratum <- att.pt.2$panelNum
att.pt.2$siteID <- paste(sppCode, att.pt.2$expl_id, sep = "-")
# get these data into the spatial poly df
shp_expl_dat <- merge(shp_expl, att.pt.2[,c("expl_id","finalSampNum","siteID","stratum")],
                      by.x = "EXPL_ID", by.y = "expl_id")

#initialize a list for saving the random points data
v.ranSPDF <- vector("list", nrow(shp_expl_dat))
names(v.ranSPDF) <- shp_expl_dat@data$EXPL_ID

# generate random points for each polygon by looping through all polys
for(i in 1:nrow(shp_expl_dat)){
  numSamps <- shp_expl_dat@data$finalSampNum[[i]]
  pts <- spsample(shp_expl_dat[i,], n= numSamps, 
                  type = "random", iter = 500)
  #rare edge cases where points can't get placed will result in null
  #seems to be due to holes in the poly most often
  # this might be fixed! Keeping in for safety for now. 
  if(!is.null(pts)){
    v.ranSPDF[[i]] <- SpatialPointsDataFrame(pts, data = shp_expl_dat@data[rep(i, nrow(pts@coords)),])
  }
}

#check for screw-ups
ptsCouldntBePlaced <- v.ranSPDF[sapply(v.ranSPDF, is.null)]
if(length(ptsCouldntBePlaced) > 0){
  if(length(ptsCouldntBePlaced) > 1){
    print(paste("You've got ", length(ptsCouldntBePlaced), " polys that didn't get any points placed in them.", sep = ""))
    print("These are:")         
    shp_expl_dat@data[as.numeric(names(ptsCouldntBePlaced)),]
  } else {
    print(paste("You've got one poly that didn't get any points placed in them.", sep = ""))
    print("This is:")         
    shp_expl_dat@data[as.numeric(names(ptsCouldntBePlaced)),]
  }
} else {
  print("All's well")
}
## if you got polys with no points, read the numbers reported and 
## view the poly with this command
# plot(shp_expl_dat[[putNumberReportedHere]])
# e.g. plot(shp_expl_dat[698,])

# you can choose to move on or fix in gis (remove holes?)

v.ranSPDF.clean <- v.ranSPDF[!sapply(v.ranSPDF, is.null)]
ranPts <- do.call('rbind',v.ranSPDF.clean)

#check for cases where sample smaller than requested
# how many points actually generated?
npts <- sapply(v.ranSPDF.clean, function(i) nrow(i@coords))
if(length(ptsCouldntBePlaced) > 0){
  tpts <- shp_expl_dat@data$finalSampNum[-as.numeric(names(ptsCouldntBePlaced))]
} else {
  tpts <- shp_expl_dat@data$finalSampNum
}
dif <- data.frame(targPts = tpts, resTps = npts)
dif$diff <- dif$targPts - dif$resTps
table(dif$diff)
# if you get all zeros in the above "table" command you are golden!
# TODO: handle cases that are off

# projection info doesn't stick, apply from what we grabbed earlier
ranPts@proj4string <- projInfo
names(ranPts@data) <- tolower(names(ranPts@data))
# remove extranneous fields, write it out
fullName <- paste(nm.RanPtFile,".shp",sep="")

colsToKeep <- c("siteid", "stratum", tolower(desiredCols))
ranPts <- ranPts[,colsToKeep]
writeOGR(ranPts, dsn = fullName, layer = nm.RanPtFile, 
			driver="ESRI Shapefile", overwrite_layer=TRUE)

# Write out various stats and data to the database ------
# prep the data
OutPut <- data.frame(SciName = paste(att.pt[1,"scien_name"]),
	CommName=paste(att.pt[1,"commonname"]),
	ElemCode=sppCode,
	RandomPtFile=nm.RanPtFile,
	date = paste(Sys.Date()),
	time = format(Sys.time(), "%X"),
	Loc_Use=""
	)

#Write the data to the SQLite database
db <- dbConnect(SQLite(),dbname=nm_db_file)
dbWriteTable(db,"tblPrepStats",OutPut,append=TRUE)
dbDisconnect(db)

###
### remove Coincident Background points ----
###

# get the background shapefile
backgShapef <- readOGR(dsn=loc_bkgPts, layer=nm_bkgPts)

#get projection info for later
projInfo <- backgShapef@proj4string

# find coincident points ----
#buffer the poly shapefile 30 m
polybuff <- gBuffer(presPolys, width = 30)

# find points that fall within the buffered polygons, subset the sp object
coincidentPts <- gContains(polybuff, backgShapef, byid = TRUE)
colnames(coincidentPts) <- "insideBuff"
backgShapef@data <- cbind(backgShapef@data, coincidentPts)
backgSubset <- backgShapef[backgShapef@data$insideBuff == FALSE,]

# projection info doesn't stick, apply from what we grabbed earlier
backgSubset@proj4string <- projInfo

# write it out ---
outFileName <- paste(nm_bkgPts, "_clean", sep="")
writeOGR(backgSubset, dsn = loc_bkgPts, layer = outFileName, 
         driver="ESRI Shapefile", overwrite_layer=TRUE)

## clean up ----
# remove all objects before moving on to the next script
rm(list=ls())

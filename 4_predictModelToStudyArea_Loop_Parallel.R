# File: 4_predictModelToStudyArea.r
# Purpose: create the distribution model prediction raster

## start with a fresh workspace with no objects loaded
library(raster)
library(rgdal)
library(randomForest)

####
## two lines need your attention. The one directly below (loc_scripts)
## and about line 26 where you choose which Rdata file to use,

loc_scripts <- "D:\\Git_Repos\\Regional_SDM"

# get paths, other settings
source(paste(loc_scripts,"0_pathsAndSettings.R", sep="/"))
# get the customized version of the predict function
source(paste(loc_scripts, "RasterPredictMod.R", sep = "/"))

# load data ----
# get the rdata file
setwd(loc_RDataOut)
fileList <- dir(pattern = ".Rdata$",full.names=FALSE)
fileList
pull_list<-readLines("D:\\Git_Repos\\PROs\\Files_coded_ready_for_points_6_6.csv")


fileList <- unique (grep(paste(pull_list,collapse="|"), 
                         fileList, value=TRUE))




len_fileList<-length(fileList)
# choose one to run, load it #### requires editing ####
predict_parallel<-function(rdata_file){
  library(raster)
  library(rgdal)
  library(randomForest)

load(rdata_file)
loc_scripts <- "D:\\Git_Repos\\Regional_SDM"
  
  # get paths, other settings
source(paste(loc_scripts,"0_pathsAndSettings.R", sep="/"))
  # get the customized version of the predict function
source(paste(loc_scripts, "RasterPredictMod.R", sep = "/"))
##Make the raster stack
stackOrder <- names(df.full)[indVarCols]
setwd(loc_envVars)
rasL <- paste(stackOrder,".grd", sep="")
fullL <- as.list(paste(loc_envVars, rasL, sep="/"))
names(fullL) <- stackOrder
envStack <- stack(fullL)

# run prediction ----
fileNm <- paste(loc_outRas, "/", ElementNames$Code, "_",Sys.Date(),".tif", sep = "")
outRas <- predictRF(envStack, rf.full, progress="text", index=2, na.rm=TRUE, type="prob", filename=fileNm, format = "GTiff", overwrite=TRUE)

#writeRaster(outRas, filename=paste(fileNm, "_2",sep=""), format = "GTiff", overwrite = TRUE)
setwd(loc_RDataOut)
rm(list=ls()[!ls() %in% 
               c("p_fileList","predictRF","fileList","loc_scripts","loc_outRas","loc_RDataOut","loc_bkgPts","loc_spPts","loc_envVars","nm_db_file","loc_otherSpatial","len_fileList")])

}

test_data<-fileList[1]

subsetlist<-fileList[2:19]
predict_parallel(test_data)

source(paste(loc_scripts, "bindToEnv2.R", sep = "/"))

mkWorker<-function(){
  bindToEnv(objNames = c('loc_scripts','predict_parallel'))
  function(rdata_File){
  
    print(rdata_File)
    predict_parallel(rdata_File)
  }
}

parallelCluster<-parallel::makeCluster(parallel::detectCores())
print(parallelCluster)

tryCatch(
  
  models<-parallel::parLapply(parallelCluster,subsetlist,mkWorker()),
  error=function(e) print(e)
)








## clean up ----
# remove all objects before moving on to the next script
rm(list=ls())
if(!is.null(parallelCluster)){
  parallel::stopCluster(parallelCluster)
  parallelCluster<-c()
}



#!/bin/bash

##############################################################
# BASH script to get Argos data files from the FTP server 
# and process them. When processing has been done, 
# plot_argos.csh is called to generate plots.
#
# This script can be run at any time to get the lastest
# argos data - it will not cause any problems if there are no
# data files to get. 
#
# USAGE: 
#
#  get_argos.sh
#
# USES: ftp
#       extract_argos.sh        - Generates decoded / cleaned files
#       make_tilt.sh            - Generates daily tilt files
#       update_daily_average.sh - Update daily averages
#       plot_agros.csh          - CShell script to draw data plots 
#
# Written by J Cole-Baker / GNS / 2011
##############################################################



### Define some file paths: ###
ArgosDataPath="/home/volcano/data/rcl_argos"
ArgosProgPath="/home/volcano/programs/rcl_argos"
#WebSitePath="/opt/local/apache/htdocs/volcanoes/ruapehu/ruapehu_argos"
TiltPath="/home/volcano/data/tilt"

RawDir="${ArgosDataPath}/raw"
CleanDir="${ArgosDataPath}/clean"

CleanFile120Day="${ArgosDataPath}/clean.csv"
AvgFile="${ArgosDataPath}/rcl_daily_avg.csv"
AvgBUFile="${ArgosDataPath}/rcl_daily_avg.old"
TempTiltFile="${ArgosDataPath}/tilt.csv"


################################################################
#  1: FTP Download:                                             
#  ================                                             
#                                                               
#  Run an FTP command sequence to retrieve the latest Argos files.
#  Files are deleted from FTP server after retrieval.          
#                                                              
################################################################
OldDir=$(pwd)
cd $RawDir
source_machine='ftp.gns.cri.nz'
ftp -inv $source_machine << endftp
  user anonymous t.hurst@gns.cri.nz
  cd incoming/Argos
  mget *.CSV
  mdel *.CSV
endftp
cd $OldDir




################################################################
#
#  The following script loops through the last 120 days. 
#  Steps 2-4 are applied to the most recent 6 days, while 
#  step 5 is applied to all 120 days. 
#
#  2: Generate 'Clean' Files:                                             
#  ==========================                                             
#                                                               
#  For the most recent 6 days, the script searches for and 
#  extracts data from the raw files, and generates new daily 
#  'clean' files. 
#
#  Data are extracted and coverted to floating point numbers
#  from 16-bit integers; Checksum is used to remove bad records. 
#
#  Actual decode / clean is done by calling "extract_argos.sh"
#  for each date. See extract_argos.sh for additional notes. 
#
#  3: Generate Tilt Data Files: 
#  ============================ 
#
#  For the most recent 6 days, the daily tilt file is updated 
#  by calling "make_tilt.sh" for the day. 
#  This script extracts the required tilt columns from the 
#  clean files, and converts the date format.
#
#  4: Daily Average Update: 
#  ========================
#
#  For the most recent 6 days, the daily average file is updated
#  by calling "update_daily_average.sh" for the day. 
#  This script uses awk to calculate daily averages. See
#  update_daily_average.sh for more details. 
#                                                              
#  5: Add data to 120 day clean file: 
#  ==================================
#
#  For days from 120 to 7 days ago, the script assumes that
#  clean data have already been extracted; data for these days 
#  are simply extracted from any existing daily 'clean' files in 
#  /home/volcano/data/rcl_argos/clean and appended to a new 
#  120-day clean file (clean.csv) which is used to generate 
#  the plots. This ensures the 120-day file is up-to-date.
#
################################################################

# Remove the old 'clean' data file, and create new one: #
rm -f $CleanFile120Day
echo "RecordDateUTC,Battery,PanelTemp,DepthKTE,LakeTemp,AtmPressure,EastTilt,NorthTilt,TiltBatt,DepthKTEMin,DepthKTEMax,DepthKTEStdDev,DepthRTO" > $CleanFile120Day


# Reprocess the last 120 days. 
#  -Add data to 'clean.csv'
#  -Extract the last 6 days to update any missing data. 
for i in {120..0}
do

  ThisDay=$(date -d -${i}days +%Y%m%d)
  Year="${ThisDay:0:4}"
  ShortYear="${ThisDay:2:2}"
  Month="${ThisDay:4:2}"
  Day="${ThisDay:6:2}"
  CleanFile="${CleanDir}/${ShortYear}-${Month}/${Year}${Month}${Day}_clean.csv" 

  if ((i < 7))
#  if ((i < 0))         # Inserted here temporarily when logger system changed
  then
    ### For Last 6 days: ###
    echo "Processing Argos data for ${Year}/${Month}/${Day}..."

    ## 2: Generate 'clean' file with 'extract argos' script:    ##
    ${ArgosProgPath}/extract_argos.sh $ThisDay

    ## 3: Generate Tilt data file:                              ##
    ## ${ArgosProgPath}/make_tilt.sh $ThisDay

    ## 4: Daily Average Update:                                 ##
    ${ArgosProgPath}/update_daily_average.sh $ThisDay

  fi

  ## 5: For all days in range: add the clean data to the new clean file: ##
  grep "" ${CleanFile} >> ${CleanFile120Day}

done



################################################################
#  6: Copy Daily Average File to Web Sever:                                             
################################################################
#cp $AvgFile $WebSitePath



################################################################
#  7: Draw Plots (also copies plots to web server):                                             
################################################################                         
#${ArgosProgPath}/plot_argos.csh



########
# Done!#
########




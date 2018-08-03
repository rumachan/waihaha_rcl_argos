#!/bin/bash

##############################################################
# BASH script to create a file of tilt data from a decoded
# data file from the Argos system
#
# Usage: make_tilt.sh YYYYMMDD
#
#     YYYYMMDD - Date to extract. Script will look for a 
#                file of clean argos data for this date.
#
# A file of tilt data in the appropriate format is generated
# and stored to the tilt data path (see below). Any existing 
# crater lake tilt file for the same day is overwritten.
#
# USES: awk
#
# Written by J Cole-Baker / GNS / 2011
##############################################################



### Define some file paths: ###
ArgosDataPath="/home/volcano/data/rcl_argos"
ArgosProgPath="/home/volcano/programs/rcl_argos"
CleanPath="${ArgosDataPath}/clean"
TiltPath="/home/volcano/data/tilt"


# Check whether a date was specified: 
if [[ ( ("$#" == 1) && ($1 =~ ^[0-9]{8}$) ) ]]
then 
  # The user specified a date:
  echo "Getting RCL tilt data for $1"
else
  echo "USAGE: make_tilt.sh YYYYMMDD"
  echo "         YYYYMMDD - Date to process."
  exit 1
fi

# Get the various parts of the supplied date: 
Year="${1:0:4}"
ShortYear="${1:2:2}"
Month="${1:4:2}"
Day="${1:6:2}"
JulDay=$(date -d $1 +%j)

# Build the path and file name of the clean file to use: 
ThisFile="${CleanPath}/${ShortYear}-${Month}/${Year}${Month}${Day}_clean.csv"
echo "Source File: ${ThisFile}" 

# Check to see if the tilt path exists, and create if it doesn't: #
if [ ! -d $TiltPath/$Year ] 
then
  mkdir $TiltPath/$Year
fi

# Construct the name of the tilt file to generate: #
TiltFile=${TiltPath}/${Year}/${Year}.${JulDay}.RCL.90-lan.tilt
rm -f $TiltFile

# Use AWK to extract only the columns of interest, and add to the tilt file: #
awk 'BEGIN {FS=","; OFS=","} { gsub(/ /,"T",$1); gsub(/\//,"-",$1); print $1,$7,$8,$9 }' $ThisFile > $TiltFile




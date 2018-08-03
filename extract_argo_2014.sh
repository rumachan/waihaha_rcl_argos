#!/bin/bash

##############################################################
# BASH script to extract clean Argos data files from one or
# more raw files. 
#
# Usage: 
#         extract_argos.sh YYYYMMDD
#
# YYYYMMDD - Date to process. 
#          
# Creates a clean argos CSV file in 
#   /home/volcano/data/rcl_argos/clean
#
# Any existing file will be overwritten.
#
# USES: grep 
#       perl
#       argos_cleanup.pl
#
# Written by J Cole-Baker / GNS / 2011
##############################################################



### Define some file paths: ###
ArgosDataPath="/home/volcano/data/rcl_argos"
ArgosProgPath="/home/volcano/programs/rcl_argos"

RawPath="${ArgosDataPath}/raw"
CleanPath="${ArgosDataPath}/clean"
TempFile="${ArgosDataPath}/temp_raw.csv"


# Check whether a date was specified: 
if [[ ( ("$#" == 1) && ($1 =~ ^[0-9]{8}$) ) ]]
then 
  # The user specified a date:
  echo "Proessing files in $RawPath for $1"
else
  echo "USAGE: extract_argos.sh YYYYMMDD"
  exit 1
fi

# Delete temporary file: 
rm -f $TempFile

# Get the various parts of the supplied date: 
Year="${1:0:4}"
ShortYear="${1:2:2}"
Month="${1:4:2}"
Day="${1:6:2}"

# Grep out records for the date from the raw data, and place in a temp file: 
# This operation includes a sort and removal of duplicates. 
SearchDate="${Year}/${Month}/${Day}"
echo "Extracting data for: $SearchDate"
grep ${SearchDate} ${RawPath}/*.CSV -h | sort -t ';' -k 8 -u > ${TempFile}

# Build the path and file name of the clean file we are going to generate: 
CleanDir="${CleanPath}/${ShortYear}-${Month}"
CleanFile="${CleanDir}/${Year}${Month}${Day}_clean.csv"
CompFile="${CleanDir}/${Year}${Month}${Day}_comp.csv"
TestFile="${CleanDir}/${Year}${Month}${Day}_test.csv"

echo "Output File: ${CleanFile}" 

# Check to see if the path for the clean file exists, and create if it doesn't:
if [ ! -d "$CleanDir" ]
then
  mkdir "$CleanDir"
fi

# Delete any existing version of the clean file: 
rm -f $CleanFile

# Decode and clean the temporary file of raw data, using the perl script argos_cleanup.pl, 
# and store a cleaned CSV file:
#perl "${ArgosProgPath}/argos_cleanup.pl" -f ${TempFile} > ${CleanFile}
#perl "${ArgosProgPath}/argos_cleanup_21022013.pl" -f ${TempFile} > ${CleanFile}
perl "${ArgosProgPath}/argos_cleanup_15032014.pl" -f ${TempFile} > ${CleanFile}
#perl "${ArgosProgPath}/argos_cleanup_05032016.pl" -f ${TempFile} > ${CleanFile}
#perl "${ArgosProgPath}/argos_test.pl" -f ${TempFile} > ${TestFile}









#!/bin/bash

##############################################################
# BASH script to add a daily average from a daily cleaned 
# argos data file to the daily average file 
# (rcl_daily_average.csv).
#
# The script removes any existing record(s) for the current 
# day, and sorts the file by date. 
#
# Usage: 
#       update_daily_average.sh YYYYMMDD
#
# YYYYMMDD - Date to process. 
#          
# During the daily average process, the backup file 
# (rcl_daily_avg.old) is overwritten. 
#
# USES: grep 
#       awk
#
# Written by J Cole-Baker / GNS / 2011
##############################################################



# Define an AWK command to calculate the average of a file (6 fields): 
# (Note line continuations!)
DaiyAvgProg=' BEGIN { FS=","; OFS=",";  }                                                                     \
              { for (i=2; i<=6; i++) totals[i] += $i; count++;  }                                             \
              END { if (count > 0) {  printf( substr($1,1,10) " 12:00:00,");                                  \
                                      for (i=2; i<=6; i++) { $i = totals[i]/count; printf( "%0.3f,", $i ); }  \
                                      printf( "%d\n", count );  }  }    '


### Define some file paths: ###
ArgosDataPath="/home/volcano/data/rcl_argos"
ArgosProgPath="/home/volcano/programs/rcl_argos"

CleanPath="${ArgosDataPath}/clean"

AvgFile="${ArgosDataPath}/rcl_daily_avg.csv"
AvgFileBU="${ArgosDataPath}/rcl_daily_avg.old"


# Check whether a date was specified: 
if [[ ( ("$#" == 1) && ($1 =~ ^[0-9]{8}$) ) ]]
then 
  # The user specified a date:
  echo "Update daily average for $1"
else
  echo "USAGE: update_daily_average.sh YYYYMMDD"
  exit 1
fi


# Get the various parts of the supplied date: 
Year="${1:0:4}"
ShortYear="${1:2:2}"
Month="${1:4:2}"
Day="${1:6:2}"
SearchDate="${Year}/${Month}/${Day}"

# Build the path and file name of the clean file we are going to average: 
CleanFile="${CleanPath}/${ShortYear}-${Month}/${Year}${Month}${Day}_clean.csv"

echo "Clean File: ${CleanFile}" 

# Check to see if there is a file of clean data for this date.
# If not, there's nothing to do:
if [[ -s ${CleanFile} ]]
then

  ##### Clean file found: #####

  # Delete the old daily average BACKUP file:
  rm -f $AvgFileBU

  # Use Grep to get the records from the current daily average file, 
  # minus any for the day we are processing, and copy to the backup:
  grep -v ${SearchDate} ${AvgFile} -h > ${AvgFileBU}

  # Use Awk program to calculate daily averages from the clean file, 
  # and add to the backup daily average file: 
  awk "$DaiyAvgProg" < $CleanFile >> ${AvgFileBU}

  # Use sort to sort the records and place the sorted data into a new
  # daily average file: 
  sort -t ',' -k 1,1 -u ${AvgFileBU} > $AvgFile

else
 
  ##### No data to process: #####
  echo "No Clean Data For Date $1."

fi

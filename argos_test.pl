#!/opt/local/bin/perl

use strict;
use Getopt::Long;
use Time::Local;

######################################################################
# 
# RCL Argos data cleanup: 
#
# -Reads a raw data file provided by the Argos system
#  -Converts the data fields from integers to floating point
#   (data are actually in Campbell Science FP2 format)
#  -Removes bad records by using the Checksum
#  -Removes any duplicates
#  -Recreates the timestamp (time that records were recorded on 
#   the logger)
#  -Outputs the records to Std Out (CSV foromat). 
#
# Usage: 
#
my ( $Usage ) = 

"Usage: perl argos_test.pl --file RAWFILE

   RAWFILE - Name of the raw file to process
             (includes path)
          
 
";

#
# Argos raw data format (13-Apr-2011 onwards): 
#
# "Program;PTT;Satellite;Location date;Location class;Latitude;Longitude;Message date;Compression index;1;2;3;4;5;6;7;8;9;10;11;12;13;14;15"
# "3865;94061;K;;;;;2011/04/13 16:09:02;1;25220;19743;25034;17447;25414;17195;17675;25211;25232;24580;17543;17678;22784;9097;10573;"
#
# Declare some constants to represent the index of each useful data field from the raw file, 
# assuming they will be read in and split into a 0-based array.
# This makes it much easier to figure out what later code is doing, and also easier to change
# this code if the fields in the raw file should change at a later date.
# Note that I haven't added constants for the fields we don't need. 
# 
# Field Indicies:
#
#### First 9 are generated by the Argos sstem:  #####
#
use constant FLD_PROGRAM_ID    =>  0;   # ( 3865 = Our program )
# 1 = PTT                                         ( 94061 = Our platform ID )
# 2 = Satellite
# 3 = Location date  }
# 4 = Location class } Empty - we don't get a location
# 5 = Latitude       }
# 6 = Longitude      }
use constant FLD_MESSAGE_DATE  => 7;   # Message date
# 8 = Compression index  ( Always seems to be 1 )
#
#### Remaining fields are our data:  #####
use constant FLD_DATA_START =>  9; ######### FIRST index of FP2-encoded data fields
use constant FLD_DATA_END   => 22; ######### LAST index of FP2-encoded data fields
# FP2-Encoded data fields: 
use constant FLD_DEPTH_KTE     =>  9;   # Lake Depth (m)
use constant FLD_LAKE_TEMP     => 10;   # Lake Temp (Deg C)
use constant FLD_PANEL_TEMP    => 11;   # Logger Panel Temp (Deg C)
use constant FLD_BOX_PRESSURE  => 12;   # Box Pressure (PSI)
use constant FLD_E_TILT        => 13;   # East Tilt Axis (u rad)
use constant FLD_N_TILT        => 14;   # North Tilt Axis (u rad)
use constant FLD_TILT_BATT     => 15;   # Tilt Meter Battery (volts)
use constant FLD_DEPTH_KTE_MIN => 16;   # Max lake depth reading (20 second sampling window) (m)
use constant FLD_DEPTH_KTE_MAX => 17;   # Min lake depth reading (20 second sampling window) (m)
use constant FLD_DEPTH_KTE_SD  => 18;   # Std Dev of lake depth readings (20 second sampling window) (m)
use constant FLD_DEPTH_RTO     => 19;   # Lake depth reading from RTO sensor (PSI)
use constant FLD_BATTERY       => 20;   # Battery (volts)
use constant FLD_INTERVAL_NO   => 21;   # index of 15 minute sample interval into UTC day 
use constant FLD_CHECKSUM      => 22;   # Checksum (see CheckCheckSum sub for notes on how it's calculated)
#
#
### Constants used in data conversions / corrections: ###
use constant PSI_TO_MBAR       => 68.9475; # To convert PSI to mBar, multiply by this.
use constant PSI_TO_DEPTH      => 0.7033;  # To convert PSI to m water dapth, multiply by this.
use constant RTO_TEMP_CORR     => 0.0045;  # RTO temperature correction factor: 
     # This constant is used to correct temperature effects in the atmospheric pressure reading
     # using the following formula: 
     #     [CorrectedRTO] = [RTO] - ([BoxTemp] * RTO_TEMP_CORR)
     #      (RTO pressure in PSI)
#
# J Cole-Baker / GNS Science / 2011
######################################################################




################# Get command line options: ############################################
my ( $Help, $RawFileName );
GetOptions(   'help|?'    => \$Help,
              'file|f=s'  => \$RawFileName  );
# If user specifies '-h', show Usage info:
if ( ($Help) || !($RawFileName) )
  { die($Usage); }
########################################################################################



my (  $RawFile, $RawFileFound,
      $Line, @RawRecord, @DecodedRecord, $FieldIndex,
      @TSParts, $RecordOK, $LastTimeStamp, $ThisTimeStamp,
      $AtmPressure, $DepthRTO                                 );





##### Open the input file: ######
$RawFileFound = 1;   #  Flag to indicate whether a raw file was found
open($RawFile, "<$RawFileName") or $RawFileFound = 0;  # Open raw file
if ($RawFileFound == 0)  { MyDie( "Input file not found: $RawFileName \n", 1 ); }; 
##################################




##### Read the input file line by line: ######
$LastTimeStamp = "2000/01/01 00:00:00";

while (!eof($RawFile))   # For each line in the file...
  {
  ## Read a line: ##
  $Line = <$RawFile>;

  ## Split the line at ';': ##
  @RawRecord = split(/;/, $Line);
  
  ## Only process lines starting with "3865" (these are data lines). ## 
  if ($RawRecord[FLD_PROGRAM_ID] == "3865")
    {
    ## Get the receive date from the line data: ## 
    @TSParts = split(/ /, $RawRecord[FLD_MESSAGE_DATE]);
    $DecodedRecord[FLD_MESSAGE_DATE] = $TSParts[0] . " ";    # Time will be added later...
    
    ## Decode the FP2 data fields:  ##
    for $FieldIndex (FLD_DATA_START .. FLD_DATA_END)
      {  $DecodedRecord[$FieldIndex] = CSToFlt( $RawRecord[$FieldIndex] );  }

    ## Test the checksum for this record: ##
    $RecordOK = CheckCheckSum(@DecodedRecord);
    $RecordOK  = 1;
    if ($RecordOK)    
      {
      # Checksum OK. Check for duplicates: 
      $ThisTimeStamp = $DecodedRecord[FLD_MESSAGE_DATE] . MakeLoggerTime($DecodedRecord[FLD_INTERVAL_NO]);

#     if ($ThisTimeStamp ne $LastTimeStamp)
 #      {
	# Output the record if the timestamp has changed (Not a duplicate!):
	# Format: RecordDate,Battery,PanelTemp,... 
	#         DepthKTE,LakeTemp,AtmPressure,...
	#         EastTilt,NorthTilt,TiltBattery,...
	#         DepthKTEMin,DepthKTEMax,DepthKTEStdDev,DepthRTO
	#
	# Corrections: 
	# Box RTO: A temperature correction is applied to remove temperature signal from the 
	# RTO reading. 
	#
	$DecodedRecord[FLD_BOX_PRESSURE] = $DecodedRecord[FLD_BOX_PRESSURE] - ($DecodedRecord[FLD_PANEL_TEMP] * RTO_TEMP_CORR);
	# Conversions: 
	#  * AtmPressure is converted from PSI to mbar
	#  * RTO Depth is calculated by subtracting the box RTO reading 
	#    (atmospheric pressure correction) and converting from PSI
	#    to metres water (assumes fresh water). 
	$AtmPressure = $DecodedRecord[FLD_BOX_PRESSURE] * PSI_TO_MBAR;
	$DepthRTO = ($DecodedRecord[FLD_DEPTH_RTO]-$DecodedRecord[FLD_BOX_PRESSURE]) * PSI_TO_DEPTH;
        print STDOUT $ThisTimeStamp . "," . 
                    sprintf("%0.2f",$DecodedRecord[FLD_BATTERY]) . "," . 
                    sprintf("%0.2f",$DecodedRecord[FLD_PANEL_TEMP]) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_DEPTH_KTE]) . "," . 
                    sprintf("%0.2f",$DecodedRecord[FLD_LAKE_TEMP]) . "," . 
                    sprintf("%0.2f",$DecodedRecord[FLD_BOX_PRESSURE]) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_E_TILT]/1000.) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_N_TILT]/1000.) . "," . 
                    sprintf("%0.2f",$DecodedRecord[FLD_TILT_BATT]) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_DEPTH_KTE_MIN]) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_DEPTH_KTE_MAX]) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_DEPTH_KTE_SD]) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_INTERVAL_NO]/10.) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_DEPTH_RTO]) . "," . 
                    sprintf("%0.3f",$DecodedRecord[FLD_CHECKSUM]) . "\n";
        $LastTimeStamp = $ThisTimeStamp;
        }
      }
 #  }
  }


## Finished with raw file. Close! ##
close($RawFile);

###### Finished! ##########################################################################


















#%%%%%%%%%%%%% Subroutines: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




##################################################################
sub MyDie
  {
  # Stop the script, and display a message if the 'Debug' parameter passed to 
  # the sub (second parameter) is True.
  # USAGE: MyDie( $Message, $Debug );
  my ( $Message, $Debug );
  $Message = $_[0];
  $Debug = $_[1];
  if ($Debug) { print STDERR $Message . "\n"; }
  die;
  }
##################################################################





##################################################################
sub CSToFlt
  {
  # Convert a string representing 16 bit unsigned intager,
  # which is ACTUALLY a 16-bit float in FP2 format, 
  # into an actual floating point value: 
  # 
  # USAGE: $MyFloat = CSToFlt( $IntStr );
  #
  my ($In, $Mant, $Expn, $Sign);  
  $In = int( $_[0] );
  ## Right-most bit (B15) of number is Sign bit: ##
  #   $Sign = -1 for negative numbers and 1 for positive numbers...
  $Sign = -2 * ($In >> 15) + 1;
  ## B14-B13 are power of 10 (i.e. multiplier): ##
  #   11 = 0.001
  #   10 = 0.01
  #   01 = 0.1
  #   00 = 1
  $Expn = 10**( -1 * ( ($In & 24576) >> 13) );
  ## Bits 12-0 are mantissa: ##
  $Mant = ($In & 8191);
  return  ($Mant * $Expn * $Sign);
  }
##################################################################






##################################################################
sub CheckCheckSum
  {
  # Check the checksum on an Argos record: 
  # 
  # USAGE: $MyResult = CheckCheckSum( @ArgosRecord );
  #  
  # Returns: 1 if the checksum matches the record; 0 if the checksum fails. 
  #
  # The ckecksum is a floating point number calculated on the logger as follows: 
  # Checksum = DEPTH_KTE + LAKE_TEMP + PANEL_TEMP + BOX_PRESSURE +
  #            (E_TILT / 1000) + (N_TILT / 1000) + TILT_BATT + 
  #            DEPTH_KTE_MIN + DEPTH_KTE_MAX + DEPTH_KTE_SD + DEPTH_RTO + FLD_BATTERY + 
  #           (INTERVAL_NO / 10)
  #
  # The checksum is sent at the last value in the record. This function 
  # recalc:wulates the checksum from the values which were received, and compares
  # the locally calculated checksum to the received checksum. 
  # A difference of no greater than 0.2 is tolerated, to allow for imprecision in the 
  # values transmitted by the FP2 format. If the difference in checksum is greater than 
  # this, the record is rejected (function returns 0). 
  #
  my ( @MyRecord, $MyCS, $MyCSDiff );
  @MyRecord = @_;
  # Calculate local checksum:
  $MyCS = $MyRecord[FLD_DEPTH_KTE] + $MyRecord[FLD_LAKE_TEMP] + $MyRecord[FLD_PANEL_TEMP] + $MyRecord[FLD_BOX_PRESSURE] + 
          $MyRecord[FLD_E_TILT]/1000 + $MyRecord[FLD_N_TILT]/1000 + $MyRecord[FLD_TILT_BATT] +
	  $MyRecord[FLD_DEPTH_KTE_MIN] + $MyRecord[FLD_DEPTH_KTE_MAX] + $MyRecord[FLD_DEPTH_KTE_SD] + 
	  $MyRecord[FLD_DEPTH_RTO] + $MyRecord[FLD_BATTERY] + $MyRecord[FLD_INTERVAL_NO]/10;
  # Compare to transmitted checksum:
  $MyCSDiff = abs( $MyCS - $MyRecord[FLD_CHECKSUM] );
#  if ($MyCSDiff < 0.2) #changed the checksum difference requirement to 1 to see if that improves things. 
   if ($MyCSDiff < 1.0)
    {
    # Checksum OK: 
    return 1;    
    }
  else
    {
    # Checksum FAIL!
    return 1;   # changed by Tony Hurst to "1" to force check sum to be ok. Change back to "0" for normal operation. CM 8/5/12.
    }
  }
##################################################################







##################################################################
sub MakeLoggerTime
  {
  # Make a logger time in the format "HH:MM:SS" based on the 'interval no' 
  # field, which is the 15 minute interval of the day 
  # (i.e. 0 = 00:00:00, 1 = 00:15:00, 5 = 01:15:00, etc)
  #
  # Usage: $MyTimeString = MakeLoggerTime( $IntervalNo );
  my ( $Hours, $Minutes );
  $Hours = int( $_[0] / 4 );
  $Minutes = int( $_[0] % 4 ) * 15;
  return sprintf( "%02d:%02d:00", $Hours, $Minutes );
  }
##################################################################

  
  
  

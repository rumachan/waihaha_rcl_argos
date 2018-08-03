#!/bin/csh -f

##############################################################
# CSH script to draw plots of data from ruapehu argos system
#
# USES: plot_rclargos.sh - BASH script to draw data plots 
#
# Written by J Cole-Baker / GNS / 2010
#
##############################################################

# Draw plots of data with python matplotlib: 

source /home/volcano/.cshrc

/home/volcano/programs/rcl_argos/plot_rclargos.py
/home/volcano/programs/rcl_argos/plot_rclargos.py /a


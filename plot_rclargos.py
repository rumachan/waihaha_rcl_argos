#! /opt/local/epd-7.3.1/bin/python
# -*- coding: utf-8 -*-

from RuapehuCraterLakePlot import RuapehuCraterLakePlot

import os
import sys
import datetime
from datetime import timedelta

'''
Creates a png file containing daily average plots of Ruapehu crater lake data,
and writes it to the file location configured in RuapehuCraterLakePlot.cfg
Usage: 
    python plot_rcl_argos.py     -> 90 day plot
    python plot_rcl_argos.py /a  -> Daily average plot
'''
rclPlot = RuapehuCraterLakePlot()
if len(sys.argv) > 1:
    plotPng = rclPlot.getDailyAveragePlots()
    outputFile = 'ruapehu_argos_daily_avg.png'
        
else:
    currentDate = datetime.datetime.today()
    plotPng = rclPlot.getPlots(currentDate-timedelta(days=90), currentDate)
    outputFile = 'ruapehu_argos.png'  
    
with open(os.path.join(rclPlot.outputDir, outputFile), 'wb') as f:
    f.write(plotPng)
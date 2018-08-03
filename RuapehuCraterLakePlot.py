'''
Created on 03/03/2014

@author: duncanw
'''

'''
RuapehyCraterLakePlot contains functions for creating data plots from
Ruapehu monitoring data. The raw binary data must be transformed into 
CSV data before being used by RuapehuCraterLakePlot.
'''

import matplotlib
matplotlib.use('Agg')  # this prevents the display
import matplotlib.pyplot as plt
from matplotlib.figure import Figure
from matplotlib.backends.backend_agg import FigureCanvasAgg as FigureCanvas
import pandas as pd
import numpy as np
import xlrd

import os
import re
import io
import datetime
from datetime import date, timedelta
import traceback

import ConfigParser

class RuapehuCraterLakePlot(object):
    
    '''
    Constructor loads the location of Ruapehu crater lake data from RuapehuCraterLakePlot.cfg
    if the dataDir parameter is not provided.
    '''
    def __init__(self, dataDir=None):
        self.config = RuapehuCraterLakePlot.loadConfig()
        if (dataDir == None):
            dataDir = self.config.get('Files', 'dataDir')            
        self.dataDir = dataDir
        self.dailyAvgFile = self.config.get('Files', 'dailyAvgFile')
        self.outputDir = self.config.get('Files', 'outputDir')
        self.chemistryFile = self.config.get('Files', 'chemistryFile')
        
        # regex to match YY-MM dir names
        self.yearMonthDirRegex = re.compile('\d{2}-\d{2}')
        # regex to match filenames like "20131001_clean.csv"
        self.dataFileRegex = re.compile('(\d{8})_clean.csv')
        # regex to match dates like 2013/10/01 03:00:00
        self.dateTimeRegex = re.compile('\d{4}/\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2}')
        
        
    @classmethod
    def loadConfig(cls):
        scriptDir = os.path.dirname(os.path.realpath(__file__))
        config = ConfigParser.ConfigParser()
        config.read(os.path.join(scriptDir, 'RuapehuCraterLakePlot.cfg'))
        return config      
    
    '''
    startDate: datetime specifying the first day in the range of data to be returned
    endDate: datetime specifying the last day in the range of data to be returned
    
    Returns a pandas DataFrame object containing Ruapehu crater lake data in the given range.
    '''
    def getData(self, startDate, endDate):
        
        dataframeList = []
        numberOfDays = (endDate - startDate).days + 1
        for day in range(0, numberOfDays):
            date = startDate + timedelta(days=day)
            dataFile = self.__getDataFilePath(date)
            if os.path.exists(dataFile) and os.stat(dataFile).st_size > 0:
                dataframe = self.__readData(dataFile)
                dataframeList.append(dataframe)
            else:
                dataframe = self.__getDummyDataframe(date)
            dataframeList.append(dataframe)       

        dataframe = pd.concat(dataframeList)
        return dataframe
    
    def getDailyAverageData(self):
        return self.__readData(self.dailyAvgFile)
    
    '''
    startDate: datetime specifying the first day in the range of data to be included.
    endDate: datetime specifying the last day in the range of data to be included.
    
    Reads manual temperature measurements from the Ruapehu crater lake chemistry
    measurements Excel spreadsheet, and returns them as a Pandas DataFrame object. 
    Returns None if no temperature data is found.  
    '''
    def getChemistryTempData(self, startDate, endDate):
        
        # Opens the workbook, reads it into memory then closes it.
        workbook = xlrd.open_workbook(self.chemistryFile)
        dateValueList = [startDate]
        tempValueList = [np.NAN]
        for year in range(startDate.year, endDate.year + 1):
            # worksheets are labelled by year
            sheetName = str(year)
            if sheetName in workbook.sheet_names():
                worksheet = workbook.sheet_by_name(str(year))
                dateColumn = -1
                tempColumn = -1
                headerRow = 0
                
                # Look for date and temperature columns in the worksheet
                for colIndex in range (0, worksheet.ncols):
                    colHeader = worksheet.cell_value(headerRow, colIndex)
                    if colHeader == 'Date':
                        dateColumn = colIndex
                    elif colHeader == 'Tm':
                        tempColumn = colIndex
                       
                if dateColumn >= 0 and tempColumn >= 0:
                    # worksheet contains date and temperature columns, try
                    # to extract data.
                    for rowIndex in range (1, worksheet.nrows):
                        dateValue = None
                        tempValue = None
                        if (worksheet.cell(rowIndex, dateColumn).ctype == xlrd.XL_CELL_DATE):
                            dateValue = datetime.datetime(*xlrd.xldate_as_tuple(worksheet.cell_value(rowIndex, dateColumn), workbook.datemode))  
                            # Estimate measurement collection time at 10am,
                            # then subtract 12 hours to approximate the UTC time                             
                            #dateValue = dateValue.replace(hour=10, minute=0, second=0) - timedelta(hours=12)
                            #dateValue = dateValue - timedelta(days=1)
                            if (startDate <= dateValue and dateValue <= endDate): 
                                tempColVal = worksheet.cell_value(rowIndex, tempColumn)                
                                try:                            
                                    tempValue = float(tempColVal)
                                except ValueError:
                                    pass  
                        
                        if (dateValue != None and tempValue != None):                                         
                            dateValueList.append(dateValue)
                            tempValueList.append(tempValue)
        
        dateValueList.append(endDate)
        tempValueList.append(np.NAN)
        dataFrame = None
        if len(tempValueList) > 2:
            dataFrame = pd.DataFrame(tempValueList, index=dateValueList)
            dataFrame = dataFrame.resample('D', fill_method=None)
        return dataFrame
       
    def __getDummyDataframe(self, date):
        names = self.__getColumns()
        index = pd.date_range(name=names[0], start=date.replace(hour=0, minute=0, second=0), end=date.replace(hour=23, minute=0, second=0), freq='H')
        return pd.DataFrame(index=index, columns=names[1:])  
    
    def __getColumns(self):
        return ['TimeUTC', 'Battery', 'BoxTemp', 'LakeLevel', 'LakeTemperature', 'AirPressure', 'LakeLevel2', 'LakeTemperature2']      
                                    
    
    def __getDataFilePath(self, date):
        yearMonth = date.strftime("%Y-%m")[2:] # remove the first two digits of year
        dateString = date.strftime("%Y%m%d")
        return os.path.join(self.dataDir, yearMonth, dateString + "_clean.csv")  
 
    '''
    startDate: datetime specifying the first day in the range of data to be included in the plots
    endDate: datetime specifying the last day in the range of data to be included in the plots
    
    Returns a byte string of a png file containing Ruapehu crater lake data plots.
    '''
    def getPlots(self, startDate, endDate):     
        chemTempDataFrame=None
        try:
            chemTempDataFrame = self.getChemistryTempData(startDate, endDate)
        except:
            traceback.print_exc()
        
        return self.getRclPlots(self.getData(startDate, endDate), chemTempDataFrame) 
    

    '''
    Reads the data from the daily average file and returns a byte string of a png file 
    containing plots of the data.
    '''
    def getDailyAveragePlots(self):
        rclDataFrame = self.getDailyAverageData()
        chemTempDataFrame=None
        try:        
            startDate = rclDataFrame.index[0]
            endDate = rclDataFrame.index[-1]
            chemTempDataFrame = self.getChemistryTempData(startDate, endDate)
        except:
            traceback.print_exc()
            
        return self.getRclPlots(rclDataFrame, chemTempDataFrame) 
        
    def getRclPlots(self, rclDataFrame, chemTempDataFrame=None):
                
        plt.ioff()                  
        figure = Figure(figsize=(12,10))
        FigureCanvas(figure)
        figureGridRows = 5
        figureGridCols = 1
        
        degC =  " (" + u'\N{DEGREE SIGN}' + "C)"
              
        axes = figure.add_subplot(figureGridRows,figureGridCols,1)
        rclDataFrame.AirPressure.plot(ax=axes)
        axes.set_ylabel("Air Pressure (mBar)")
        axes.set_xlabel("")
        axes.xaxis.tick_top()
        xlabels = axes.get_xticklabels() 
        for label in xlabels: 
            label.set_rotation(30) 
            label.set_horizontalalignment('left');
        axes.set_autoscaley_on(False)
        axes.set_ylim([680,760])  
        xticks = axes.get_xticks()
    
        axes = figure.add_subplot(figureGridRows,figureGridCols,2)
        rclDataFrame.LakeTemperature.plot(ax=axes, label = "data logger 1")
        # SS rclDataFrame.LakeTemperature.plot(ax=axes, label = "data logger 1", legend=True)
        #SS rclDataFrame.LakeTemperature2.plot(ax=axes, label = "data logger 2", legend=True)
        if (chemTempDataFrame is not None):
            chemTempDataFrame.plot(ax=axes, style='ro')
            handles, labels = axes.get_legend_handles_labels()
            labels[2] = 'manual measurements'
            axes.legend(handles, labels,loc=2,prop={'size':10}, numpoints=1)

        axes.set_ylabel("Lake Temp" + degC)
        axes.set_autoscaley_on(False)
        #SS axes.set_ylim([10,45]) 
        axes.set_ylim([10,48]) 
        axes.set_xticks(xticks)
        axes.set_xlabel("")
        axes.set_xticklabels([]) 
        
        axes = figure.add_subplot(figureGridRows,figureGridCols,3)
        # SS rclDataFrame.LakeLevel.plot(ax=axes, label = "data logger 1")
        # SS rclDataFrame.LakeLevel.plot(ax=axes, label = "data logger 1", legend=True)
        rclDataFrame.LakeLevel2.plot(ax=axes, label = "data logger 2")
        axes.set_ylabel("Lake Level (m)")
        axes.set_xlabel("")
        axes.set_xticklabels([]) 
        axes.set_autoscaley_on(False)
        axes.set_ylim([0,3])  
        axes.axhline(y=1, color='#444444') 
        
        axes = figure.add_subplot(figureGridRows,figureGridCols,4)
        rclDataFrame.BoxTemp.plot(ax=axes)
        axes.set_ylabel("Box Temp" + degC)
        axes.set_xlabel("")
        axes.set_xticklabels([]) 
        axes.set_autoscaley_on(False)
        axes.set_ylim([-10,30])         
        
        axes = figure.add_subplot(figureGridRows,figureGridCols,5)
        rclDataFrame.Battery.plot(ax=axes)
        axes.set_ylabel("Battery (V)")
        axes.set_xlabel("Timestamp UTC")  
        axes.set_autoscaley_on(False)
        axes.set_ylim([12,13.5])                 
        
        # create a time plot drawn label
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        figure.text(0.001, 0.001, 'Plot drawn: ' + str(timestamp))
        
        figure.tight_layout(None, pad=0.5, h_pad=0.1, w_pad=0) 
        
        imageBuffer = io.BytesIO()
        figure.savefig(imageBuffer, format='png')
        return imageBuffer.getvalue()    
        
    '''
    startDate: datetime specifying the first day in the range of data to be returned
    endDate: datetime specifying the last day in the range of data to be returned
    
    Returns a byte string of Ruapehu crater lake csv data.
    '''    
    def getCsvData(self, startDate, endDate):   
        rclDataFrame = self.getData(startDate, endDate)   
        csvBuffer = io.BytesIO()
        rclDataFrame.to_csv(csvBuffer, encoding='us-ascii')
        return csvBuffer.getvalue() 
    
    '''
    Returns the first and last day of the currently available Ruapehu crater lake data.
    
    Values are returned as two datetimes. 
    '''
    def getDateRange(self):
        yearMonthList = []
        for name in os.listdir(self.dataDir):
            if os.path.isdir(os.path.join(self.dataDir, name)):
                if self.yearMonthDirRegex.match(name):
                    yearMonthList.append(name)
        yearMonthList.sort()
        
        firstDay = self.__getDayOfMonth(yearMonthList[0], 0)
        lastDay = self.__getDayOfMonth(yearMonthList[-1], -1)

        return firstDay, lastDay
 
    '''
    Checks the data directory to find the first or last day data is available for in the
    given month.
    
    yearMonth: e.g "13-05" for May 2013
    dayPosition: 0 to get the first day in the month, -1 to get the last day in the month.
    
    Returns the first or last day, as a datetime.
    '''  
    def __getDayOfMonth(self, yearMonth, dayPosition):
        dayFileList = []
        for name in os.listdir(os.path.join(self.dataDir, yearMonth)):
            if not os.path.isdir(os.path.join(self.dataDir, name)) and self.dataFileRegex.match(name):
                dayFileList.append(name)
        dayFileList.sort()
        day = self.dataFileRegex.match(dayFileList[dayPosition]).group(1)  
           
        return datetime.datetime.strptime(day, '%Y%m%d');  
    
    def __datetimeConverter(self, date):
        if (self.dateTimeRegex.match(date)):
            try:
                return datetime.datetime.strptime(date, "%Y/%m/%d %H:%M:%S")
            except ValueError:
                pass
            
        return self.__getDummyDate()
    
    def __getDummyDate(self):
        return datetime.datetime.strptime('1970/01/01 00:00:00', "%Y/%m/%d %H:%M:%S")
    
    def __readData(self, fileName):

        # The data files are of variable quality, the occasional row has
        # extra or missing columns. For this reason files have to be read 
        # line by line and munged, rather than using the standard pandas.read_table approach        
        names=self.__getColumns()
        data = pd.DataFrame(columns = names)
        data.set_index(names[0], inplace=True)

        with open(fileName, 'r') as f:
            for line in f:
                elements = line.strip().split(',')
                # Pad rows missing columns with NaN
                while len(elements) < len(names):
                    elements.append(np.nan)
                # Truncate rows with extra columns
                del elements[len(names):]   
            
                # Convert strings to floats
                numericVals = elements[1:]
                for i in  range(len(numericVals)):
                    try:
                        numericVals[i] = float(numericVals[i])
                    except Exception:
                        numericVals[i] = np.nan

                elements =  [self.__datetimeConverter(elements[0])] + numericVals
                newData = pd.DataFrame([tuple(elements)],columns = names)
                newData.set_index(names[0], inplace=True)
                data = pd.concat( [data, newData])
          
    
        data = data[data.index != self.__getDummyDate()]
        return data   
  


        
        
        

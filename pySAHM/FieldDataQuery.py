'''
Created on Dec 29, 2010

This module was created to 

@author: talbertc
'''

import sys, os
import math
import csv

from osgeo import gdalconst
from osgeo import gdal
from osgeo import osr
from math import floor

from optparse import OptionParser

def main(argv):
    usageStmt = "usage:  options: -t --template   -f --fieldData -a --aggPixel -y --aggYears -o --output"
    desc = "Aggregates sample points by pixel and/or year."

    parser = OptionParser(usage=usageStmt, description=desc)
    parser.add_option("-t", "--template", 
                      dest="template", 
                      help="The template grid in Tif, ESRI grid, or ASC format")
    parser.add_option("-f", "--fieldData", 
                      dest="csv", 
                      help="The CSV of field data")
    parser.add_option("-o", "--output", 
                      dest="output", 
                      help="The output CSV file with appended frequency and numPresence")
    parser.add_option("-p", "--aggregate", 
                      dest="bAgg", 
                      default=True, 
                      action="store_true", 
                      help="Flag to aggregate by pixel in the template")
    parser.add_option("-y", "--aggregateYears", 
                      dest="bAggYears", 
                      default=False, 
                      action="store_true", 
                      help="Flag to aggregate by years in the template")
    parser.add_option("-v", "--verbose", 
                      dest="verbose", 
                      default=False, 
                      action="store_true",
                      help="the verbose flag causes diagnostic output to print")

    (options, args) = parser.parse_args(argv)

    ourFDQ = FieldDataQuery()
    ourFDQ.template = options.template
    ourFDQ.csv = options.csv
    ourFDQ.output = options.output
    ourFDQ.AggByPixel = options.bAgg
    ourFDQ.AggByYear = options.bAggYears
    ourFDQ.verbose = options.verbose
    ourFDQ.processCSV()
    
class FieldDataQuery:

    def __init__(self):
        #instance level variables
        self.csv = None
        self.template = None
        self.output = None
        self.templateParams = {}
        self.AggByYear = False
        self.AggByPixel = True
        self.verbose = False

    def validateArgs(self):
        """
        Make sure the user sent us some stuff we can work with
        """

        # Validate template image.
        if self.template is None:
            raise Exception, "template raster not provided (-t command line argument missing)"
        
        if not os.path.exists(self.template):
            raise Exception, "Template file, " + self.template + ", does not exist on file system"

        self.templateParams = self.getRasterParams(self.template)
        if len(self.templateParams["Error"]) <> 0:
            print ("There was a problem with the provided template: \n    " + 
                                    "    " + "\n    ".join(self.templateParams["Error"]))
            raise Exception, ("There was a problem with the provided template: \n    " + 
                                    "    " + "\n    ".join(self.templateParams["Error"]))
        
        # Ensure the template has square pixels.
        if abs(abs(self.templateParams["xScale"]) - abs(self.templateParams["yScale"])) > 1e-6:
            print "The template raster must have square pixels."
            print "x pixel scale = " + str(xScale)
            print "y pixel scale = " + str(yScale)
            raise Exception, "template image must have square pixels."
        
        #Validate the CSV
        if self.csv is None:
            raise Exception, "No csv provided"
    
        if not os.path.exists(self.csv):
            raise Exception, "CSV file, " + self.csv + ", does not exist on file system"
        
    def getRasterParams(self, rasterFile):
        """
        Extracts a series of bits of information from a passed raster
        All values are stored in a dictionary which is returned.
        If errors are encountered along the way the error messages will
        be returned as a list in the Error element.
        """
        try:
            #initialize our params dictionary to have None for all parma
            params = {}
            allRasterParams = ["Error", "xScale", "yScale", "width", "height",
                            "ulx", "uly", "lrx", "lry", "Wkt", 
                            "tUlx", "tUly", "tLrx", "tLry", 
                            "srs", "gt", "prj", "NoData", "PixelType"]
            
            for param in allRasterParams:
                params[param] = None
            params["Error"] = []
            
            # Get the PARC parameters from the rasterFile.
            dataset = gdal.Open(rasterFile, gdalconst.GA_ReadOnly)
            if dataset is None:
                params["Error"].append("Unable to open file")
                #print "Unable to open " + rasterFile
                #raise Exception, "Unable to open specifed file " + rasterFile
                
            
            xform  = dataset.GetGeoTransform()
            params["xScale"] = xform[1]
            params["yScale"] = xform[5]
    
            params["width"]  = dataset.RasterXSize
            params["height"] = dataset.RasterYSize
    
            params["ulx"] = xform[0]
            params["uly"] = xform[3]
            params["lrx"] = params["ulx"] + params["width"]  * params["xScale"]
            params["lry"] = params["uly"] + params["height"] * params["yScale"]
                
            
        except:
            #print "We ran into problems extracting raster parameters from " + rasterFile
            params["Error"].append("Some untrapped error was encountered")
        finally:
            del dataset
            return params
    
    def processCSV(self):
        if self.verbose:
            print "Starting on Field Data Query for " + os.path.split(self.csv)[1]
            print "  using template " + os.path.split(self.template)[1]
         
        self.validateArgs()  
            
        csvfile = open(self.csv, "r")
        #dialect = csv.Sniffer().sniff(csvfile.read(1024))
        reader = csv.reader(csvfile)
        usedPixels = {}
        reader.next()
        header = ["x", "y", "ResponseBinary"]
        
        #Commented this out because it is causing an error
        #to be thrown by the java, uncomment out when the 
        #java has been replaced
        header.append("frequency")
        header.append("numPresence")
        header.append("pixelColumn")
        header.append("pixelRow")
    
        #loop through each row (observation) and 
        #if that particular pixel hasn't been encountered before
        #add it to a dictionary containing a key of the pixel X,Y
        #and values of each row encountered for that pixel
        #if pixel
        lineCount = linesInFile(self.csv)
        extraPoints = []
        pointCount = 0
        pcntDone = 0
        for row in reader:
            if self.pointInTemplate(row[0], row[1]):
                pixelColumn = int(floor((float(row[0]) - self.templateParams["ulx"]) 
                                        / self.templateParams["xScale"]))
                pixelRow = int(floor((float(row[1]) - self.templateParams["uly"]) 
                                     / self.templateParams["yScale"]))
                pixel = "".join(["X:",str(pixelColumn),":Y:",str(pixelRow)])
                #if verbose == True:
                if not pixel in usedPixels:
                    usedPixels[pixel] = [row]
                    #usedPixels[pixel] = usedPixels[pixel].append(row)
                else:
                    curVal = usedPixels[pixel]
                    curVal.append(row)
                    usedPixels[pixel] = curVal
            else:
                extraPoints.append([row[0], row[1], row[2]])
            pointCount += 1
            if self.verbose:
                if float(pointCount)/lineCount > float(pcntDone)/100:
                    pcntDone += 10
                    if self.verbose:
                        print str(pcntDone) + "...",
    
        #Open up and write to an output file
        oFile = open(self.output, 'wb')
        fOut = csv.writer(oFile, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
        fOut.writerow(header)
    
        #Add each used pixel to the output file
        for k in usedPixels:
            v = usedPixels[k]
            outputLine = v[0]
    
            pixelColumn = int(k.rsplit(':')[1])
            pixelRow = int(k.rsplit(':')[3])
            outPixelX = (self.templateParams["ulx"] + (self.templateParams["xScale"] * pixelColumn) + 
                                    self.templateParams["xScale"]/2)
            outPixelY = (self.templateParams["uly"] + (self.templateParams["yScale"] * pixelRow) + 
                                    self.templateParams["yScale"]/2)
            frequency = len(v)
    
            numPresence = 0
            for i in range (frequency):
                if int(float(v[i][2])) == 1:
                    numPresence += 1
            
            outputLine[0] = outPixelX
            outputLine[1] = outPixelY
            
            if numPresence == 0:
                outputLine[2] = 0
            else:
                outputLine[2] = 1
                
            outputLine.append(frequency)
            outputLine.append(numPresence)
            outputLine.append(pixelColumn)
            outputLine.append(pixelRow)
            
    
            fOut.writerow(outputLine)
        oFile.close
        if self.verbose:
            print "Done\nFinished creating field data query output.\n"
            if len(extraPoints) > 0:
                print ("  WARNING: " + str(len(extraPoints)) + " points" +
                    " out of " + str(pointCount) + " total points in the " +
                    "original CSV were outside the template extent and WERE NOT " +
                    "INCLUDED IN THE FDQ OUTPUT.")
            else:
                pass

    def pointInTemplate(self, x, y):
        if (float(x) >= self.templateParams["ulx"] and
            float(x) <= self.templateParams["lrx"] and
            float(y) >= self.templateParams["lry"] and
            float(y) <= self.templateParams["uly"]):
            return True
        else:
            return False

def linesInFile(filename):
    f = open(filename)                  
    lines = 0
    buf_size = 1024 * 1024
    read_f = f.read # loop optimization

    buf = read_f(buf_size)
    while buf:
        lines += buf.count('\n')
        buf = read_f(buf_size)

    return lines
#def getTemplateParams(template, verbose):
#    # Get the PARC parameters from the template.
#    dataset = gdal.Open(template, gdalconst.GA_ReadOnly)
#    
#    if dataset is None:
#        print "Unable to open " + template
#        raise RuntimeError
#    xform = dataset.GetGeoTransform()
#    xScale = xform[1]
#    yScale = xform[5]
#    # Ensure the template has square pixels.
#    if abs(math.fabs(xScale) - math.fabs(yScale)) > 1e-6:
#        print "The template image must have square pixels."
#        print "x pixel scale = " + str(math.fabs(xScale))
#        print "y pixel scale = " + str(math.fabs(yScale))
#        raise RuntimeError
#    width = dataset.RasterXSize
#    height = dataset.RasterYSize
#    ulx = xform[0]
#    uly = xform[3]
#    lrx = ulx + width * xScale
#    lry = uly + height * yScale
#    if verbose == True:
#        print "upper left = (" + str(ulx) + ", " + str(uly) + ")"
#        print "lower right = (" + str(lrx) + ", " + str(lry) + ")"
#    # Store the extent in geographic coordinates.
#    tEPSG = getEPSG(dataset)
#    if int(tEPSG) == 4326:
#        tGeoUlX = ulx
#        tGeoUlY = uly
#        tGeoLrX = lrx
#        tGeoLrY = lry
#    else:
#        tGeoUlX, tGeoUlY, tGeoLrX, tGeoLrY = getExtentInGeog(ulx, uly, lrx, lry, tEPSG)
#    return ulx, uly, lrx, lry, getEPSG(dataset), xScale, yScale
#
#def getEPSG(dataset):
#    #Returns code for the projection/datum used in the layer
#    wkt = dataset.GetProjection()
#    s_srs = osr.SpatialReference(wkt)
#    s_srs.AutoIdentifyEPSG()
#    epsg = s_srs.GetAuthorityCode("PROJCS")
#    if epsg == None:
#        epsg = s_srs.GetAuthorityCode("GEOGCS")
#    if epsg == None:
#        print "Unable to extract the EPSG code from the image."
#        raise RuntimeError
#    return epsg
#
#def getExtentInGeog(ulx, uly, lrx, lry, EPSG):
#        
#        s_srs = osr.SpatialReference()
#        s_srs.ImportFromEPSG(int(EPSG))
#
#        t_srs = osr.SpatialReference()
#        t_srs.ImportFromEPSG(4326)
#
#        coordXform = osr.CoordinateTransformation(s_srs, t_srs)
#
#        result = coordXform.TransformPoint(ulx, uly)
#        gulx = result[0]
#        guly = result[1]
#
#        result = coordXform.TransformPoint(lrx, lry)
#        glrx = result[0]
#        glry = result[1]
#
#        return gulx, guly, glrx, glry

if __name__ == '__main__':
    main(sys.argv)
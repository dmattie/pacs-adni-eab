#!/usr/bin/env python3
 
import sys,os,subprocess
import re
import argparse
import json
from csv import reader


def process(**kwargs):#segment,counterpart,method):
        measurements=kwargs['measurements']  
        segmentmap=kwargs['segmentmap']
       
        if not os.path.isfile(measurements):
            print(f"Measurements file not found: {measurements}")
            sys.exit(1)
        if not os.path.isfile(segmentmap):
            print(f"Segment map file not found: {segmentmap}")
            sys.exit(1)            
        
        
        try:

            smap={}
            with open(segmentmap,'r') as sfile:
                csv_reader=reader(sfile)
                for row in csv_reader:
                    #ParcellationId,Label,Asymmetry Counterpart,White Grey Counterpart,Left or Right,White or Grey,Common Name
                    roistart=row[0]
                    roistartLable=row[1]
                    asym=row[2]
                    wgcounterpart=row[3]
                    lr=row[4]
                    wg=row[5]
                    cn=row[6]

                    if roistart[:1]!="#":
                        smap[roistart]={}
            max_count=0
            for k in smap:
                for kpair in smap:
                    if k!=kpair:
                        smap[k][kpair]={
                            "roi":{},
                            "roi_end":{}
                        }
                        for method in smap[k][kpair]:
                            smap[k][kpair][method]={
                                "NumTracts":False,
                                "TractsToRender":False,
                                "LinesToRender":False,
                                "MeanTractLen":False,
                                "MeanTractLen_StdDev":False,
                                "VoxelSizeX":False,
                                "VoxelSizeY":False,
                                "VoxelSizeZ":False,
                                "meanFA":False,
                                "stddevFA":False,
                                "meanADC":False,
                                "stddevADC":False,
                                "voxelvolume":False
                            }
                            max_count=max_count+len(smap[k][kpair][method])
            
            
            found_count=0
            with open(measurements,'r') as mfile:
                
                csv_reader=reader(mfile)
                for row in csv_reader:
                    #levman,A00000300,20110101,0049,0008,roi,NumTracts,22793613
                    smap[row[3]][row[4]][row[5]][row[6]]=True                    
                    #max_count=max_count+1
            
            for r1 in smap:                
                for r2 in smap[r1]:                    
                    for method in smap[r1][r2]:
                        for measure in smap[r1][r2][method]:   
                            #print(f"{r1}/{r2}/{method}/{measure}")                         
                            if smap[r1][r2][method][measure]==True:
                                found_count=found_count+1
            
            pct_complete=found_count/max_count*100
            print(f"Expected {max_count}, found {found_count}, pct {pct_complete}")



        except Exception as e:

            print(f"{e}")

def main():

    args=None

    parser = argparse.ArgumentParser(
        description="CRUSH client command line utility. Audit completion of consolidated extracted measurements.")
    parser.add_argument('-measurements',action='store', required=True, help="Path to measurement file to audit")    
    parser.add_argument('-segmentmap',action='store',required=True, help='Path to file containing atlas segment metadata') 
    
    
    args = parser.parse_args()

    process(measurements=args.measurements,segmentmap=args.segmentmap)

if __name__ == '__main__':
    main()
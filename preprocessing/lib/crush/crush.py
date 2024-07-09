#!/usr/bin/env python3
 
import sys,os,subprocess
import re
import argparse
import json
import inspect
import csv
from multiprocessing import Pool,cpu_count


def process(**kwargs):#segment,counterpart,method):
    datasetdir=kwargs['datasetdir']
    subject=kwargs['subject']
    session=kwargs['session'] 
    pipeline=kwargs['pipeline']
    maxcores=kwargs['maxcores']

    if session==None or session=="":
        session_path=""
    else:
        session_path=f"ses-{session}"
    
    target=f"{datasetdir}/derivatives/{pipeline}/sub-{subject}/{session_path}"

    if "overlay" in kwargs:
        overlay=kwargs['overlay']
        if overlay and overlay!="":
            crush_dir=overlay
            print("Apptainer overlay detected, files will be stored there instead.")
        else:
            crush_dir=f"{target}/crush"
    else:
        crush_dir=f"{target}/crush"

    if not os.path.isdir(datasetdir):
        print(f"datasetdir not found: {datasetdir}")
        sys.exit(1)

    segmentMap=f"{os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))}/../../../assets/segmentMap.csv"
    Segments=[]
    with open(segmentMap) as fin:
        reader=csv.reader(fin, skipinitialspace=True, quotechar="'")
        p = re.compile('^ *#')   # if not commented          
        for row in reader:            
            if(not p.match(row[0])): 
                Segments.append({'roi':row[0],'roiname':row[1],'asymmetry':row[2]})

        
    
    tasks = []
    
    for roi_tuple in Segments:
        roi1=roi_tuple['roi']
        for roi_tuple2 in Segments:
            roi2=roi_tuple2['roi']
            if roi1!=roi2:
                if os.path.isfile(f"{target}/crush_qball.trk"):
                    crushtract=f"{target}/crush_qball.trk"
                else:
                    crushtract=f"{target}/crush_dti.trk"
                for method in ['roi','roi_end']:
                    if not os.path.isfile(f"{crush_dir}/{roi1}/calcs-{roi1}-{roi2}-roi.json"):
                        t = [roi1,roi2,method,target,pipeline,crushtract,crush_dir]
                        tasks.append(t)
    if maxcores:
        no_of_procs=maxcores
    else:
        no_of_procs = cpu_count()     
        
   # pool = Pool(int(no_of_procs))    
    print("Multiprocessing %s tasks across %s async procs" %(len(tasks),no_of_procs))

    with Pool(int(no_of_procs)) as p:
        p.map(getmeasurements,tasks)
    # for t in tasks:
    #     print(t)
    #     pool.apply_async(getmeasurements,(t,))    
    # pool.close()
    # pool.join()
        
def getmeasurements(parms):
    roi1=parms[0]
    roi2=parms[1]
    method=parms[2]
    target=parms[3]
    pipeline=parms[4]
    tract=parms[5]
    crush_dir=parms[6] #For a singularity file overlay

    if not os.path.isdir(f"{crush_dir}/{roi1}"):
        os.makedirs(f"{crush_dir}/{roi1}",exist_ok=True)
    scripthome=f"{os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))}"

    trackvis=[f"{scripthome}/get_tract_measurements.py",
    "-roi_start",roi1,
    "-roi_end",roi2,
    "-method",method,
    "-tract",tract,
    "-pipeline",pipeline,
    "-crush_dir",crush_dir]
    print(".",end='')

    with open(f"{crush_dir}/{roi1}/{roi1}-{roi2}-{method}.log", "w") as track_vis_out:
        proc = subprocess.Popen(trackvis, stdout=track_vis_out)
        proc.communicate() 

    pass
def main():

    args=None

    parser = argparse.ArgumentParser(
        description="CRUSH client command line utility. Extract measurements.")
    parser.add_argument('-datasetdir',action='store', required=True, help="Path to dataset directory (just above ../[source|rawdata|derivatives]/..)")
    parser.add_argument('-subject',action='store', required=True, help="Specify Subject ID")
    parser.add_argument('-session',action='store', help="Specify Session ID")    
    parser.add_argument('-pipeline',action='store', required=True, help="The name of the pipeline being processed to tag the data as it is stored")    
    parser.add_argument('-maxcores',action='store',help='Specify the maximum number of tasks to run concurrently')
    parser.add_argument('-overlay',action='store',help='Specify the location of the working directory')
   
    args = parser.parse_args()

    process(datasetdir=args.datasetdir,subject=args.subject,session=args.session,pipeline=args.pipeline,maxcores=args.maxcores,overlay=args.overlay)

if __name__ == '__main__':
    main()
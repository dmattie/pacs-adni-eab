#!/usr/bin/env python3
 
import sys,os,subprocess
import re
import argparse
import json


def process(**kwargs):#segment,counterpart,method):
        # datasetdir=kwargs['datasetdir']
        subject=kwargs['subject']
        session=kwargs['session']
        pipeline=kwargs['pipeline']
        tidy=kwargs['tidy']
        clean=kwargs['clean']
        out=kwargs['out']
        crushpath=kwargs['crushpath']
        if not os.path.isdir(crushpath):
            print(f"datasetdir not found: {crushpath}")
            sys.exit(1)


        pattern = re.compile("(.*)\/(\d+)-(\d+)-(\w+)-(\w+)")
        target = open(out,"a")

        for dir in os.walk(crushpath):
           for f in dir[2]:
             if os.path.splitext(f"{dir[0]}/{f}")[1] == ".json":
                try:
                   with open(f"{dir[0]}/{f}",'r') as jq:
                      data=json.load(jq)
                      for k in data:
                         keyparts=pattern.split(k)
                         target.write(f"{pipeline},{subject},{session},{keyparts[2]},{keyparts[3]},{keyparts[4]},{keyparts[5]},{data[k]}\n")
                except Exception as e:
                   print(f"ERROR processing {dir[0]}/{f}\n{e}")
                   sys.exit(1)
        

def main():

    args=None

    parser = argparse.ArgumentParser(
        description="CRUSH client command line utility. Consolidate extracted measurements.  Clean up temp files.")
    parser.add_argument('-crushpath',action='store', required=True, help="Path to crush directory containing directories of rois that store json files")
    parser.add_argument('-subject',action='store', required=True, help="Specify Subject ID")
    parser.add_argument('-session',action='store', help="Specify Session ID")    
    parser.add_argument('-pipeline',action='store', required=True, help="The name of the pipeline being processed to tag the data as it is stored")    
    parser.add_argument('-tidy',action='store_true', help="If specified, tar temp files into a single file" )
    parser.add_argument('-clean',action='store_true', help="If specified, remove intermediate files (.nii, .txt, .json)" )
    parser.add_argument('-out',action='store',required=True,help='Filename for consolidated output.  Existing file will be appended')
    
    args = parser.parse_args()

    if os.path.isfile(args.out):
        os.unlink(args.out)

    process(crushpath=args.crushpath,subject=args.subject,session=args.session,pipeline=args.pipeline,tidy=args.tidy,clean=args.clean,out=args.out)

if __name__ == '__main__':
    main()
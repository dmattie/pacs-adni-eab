#!/usr/bin/env python3
import argparse
import pandas as pd
import os,sys


parser = argparse.ArgumentParser(
    description="CRUSH utility, converts bvecs to gradient matrix")
parser.add_argument('-bvec',action='store',required=True,
    help="Path to bvec file")
parser.add_argument('-out',action='store',required=True,
    help="Output filename for gradient matrix file")
parser.add_argument('-imaging_model',action='store',required=True,
    help="Specify the imaging model to use {dti, hardi}")

args=parser.parse_args()

if not os.path.isfile(args.bvec):
    print(f"bvec file not found ({args.bvec})")
    sys.exit(1)

csv = pd.read_csv(args.bvec, header=None,skiprows=0,sep='\s+')
df_csv = pd.DataFrame(data=csv)

transposed_csv = df_csv.T  
if args.imaging_model=='qball':
    #According to Ruopeng Wang, the gradient table should have b0 rows removed when performing hardi/q-ball reconstruction
    print("Removing b0 rows from gradient table.")
    
    transposed_csv[
        (transposed_csv.iloc[:,0]!=0) |  # Col 0 > 0
        (transposed_csv.iloc[:,1]!=0) | # Col 1 > 0
        (transposed_csv.iloc[:,2]!=0)    # Col 2 > 0
    ].to_csv(args.out,header=False,index=False)

else:
    print(args.imaging_model)
    transposed_csv.to_csv(args.out,header=False,index=False)
print("Creating number of measurement points datafile")
f = open(f"{args.out}.directions", "w")
f.write(f"{transposed_csv.shape[0]}")
f.close()
print(f"{transposed_csv.shape[0]} measurement points")
        
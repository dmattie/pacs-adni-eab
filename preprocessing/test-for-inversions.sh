#!/bin/bash
set -x
IMAGE_PATH=$1
if [[ ! -d $IMAGE_PATH ]];then
echo "Path to image not set or does not exist ($IMAGE_PATH)"
exit 1
fi
PREFIX=$2
if [[ $PREFIX == "" ]];then
  echo "Usage: this.sh PATH_TO_IMAGES PREFIX"
  exit 2
fi
mkdir -p $IMAGE_PATH/tracts

SPACE="."
INVERT="$SPACE ix iy iz"
SWAPS="$SPACE sxy syz szx"

for inv in $INVERT
do

  for swap in $SWAPS
  do
    if [[ $inv == "." ]];then
       invstring=""
    else 
       invstring="-$inv"
    fi

    if [[ $swap == "." ]];then
       swapstring=""
    else 
       swapstring="-$swap"
    fi
        
    
    dti_tracker "$IMAGE_PATH/$PREFIX" "$IMAGE_PATH/tracts/$PREFIX${invstring}_${swapstring}.trk" -at 35 $invstring $swapstring -m "$IMAGE_PATH/${PREFIX}_dwi.nii"  -m2 "$IMAGE_PATH/${PREFIX}_fa.nii" -it nii
  done

done

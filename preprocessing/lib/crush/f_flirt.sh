#!/bin/bash


############################################################
# flirt  - affine image registration
############################################################

function f_flirt()
{
    if [[ -f $TARGET/RegTransform4D ]];then
        echo "Existing RegTransform4D detected and overwrite not specified.  Skipping (re-)creation of this file."
        return 0
    fi
    echo "Calculating RegTransform4D"

    if [[ -f $TARGET/reg2brain.data.nii ]];then
        reg2brain=$TARGET/reg2brain.data.nii
    else
        if [[ ! -f $TARGET/reg2brain.data.nii.gz ]];then
            echo "flirt:unable to find input file[$TARGET/reg2brain.data.nii.gz]."     
            return 1   
        fi
        reg2brain=$TARGET/reg2brain.data.nii.gz
    fi

    if [[ ! -f $FREESURFER/mri/brainmask.nii ]];then
        echo "flirt:unable to find reference brainmask.nii[$FREESURFER/mri/brainmask.nii]."     
        return 1   
    fi
    #/usr/bin/time -v flirt -in $TARGET/reg2brain.data.nii.gz -ref $FREESURFER/mri/brainmask.nii -omat $TARGET/RegTransform4D
    flirt -in $reg2brain -ref $FREESURFER/mri/brainmask.nii -omat $TARGET/RegTransform4D
    ret=$?
    if [[ $ret -ne 0 ]];then
        >&2 echo "ERROR: flirt failed with error. see above."
        return $ret
    fi
    return 0
}

export f_flirt
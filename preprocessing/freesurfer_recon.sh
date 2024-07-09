#!/bin/bash

#set -e #Exit when a command fails
#set -x #echo each command before it runs

SCRIPT=$( realpath $0 )
SCRIPTPATH=$( dirname $SCRIPT )
source "${SCRIPTPATH}/lib/helper.sh"
############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Reconstruct structural T1 image using Freesurfer recon_all"
   echo
   echo "Usage: recon [OPTIONS...]"
   echo "options:"
   echo "--help                                 Print this Help."
   echo "--datasetdir  DIR                      Path to dataset directory (just above ../[source|rawdata|derivatives]/..)"
   echo "--subject SUBJECT                      Specify subject ID to clone.  If session not"
   echo "                                       specified, then clone the entire subject"
   echo "--session SESSION                      Specify session ID to clone"  
   echo "--pipeline PIPELINE_ID                 Specify derivatives directory to store output.  If unspecified, store in rawdata." 
   echo "--reprocess                            If recon-all has been previously run, remove it and recon-all again"
   echo "--verbose                              Print out all commands executed"
   echo
}


############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options


TEMP=`getopt -o h: --long help,datasetdir:,subject:,session:,pipeline:,reprocess,verbose, \
             -n 'recon' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

DATASETDIR=""
SUBJECT=""
SESSION=""
PIPELINE=""
REPROCESS="N"
VERBOSE="N"

while true; do
  case "$1" in
    -h | --help ) Help;exit 1;;
    --datasetdir ) DATASETDIR="$2";shift 2;;     
    --subject ) SUBJECT="$2";shift 2;;
    --session ) SESSION="$2";shift 2;;
    --pipeline ) PIPELINE="$2";shift 2;;
    --reprocess ) REPROCESS="Y";shift;break;;
    --verbose ) VERBOSE="Y";shift;;     
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [[ $VERBOSE == "Y" ]];then
    set -x
fi

if [[ $DATASETDIR == "" ]];then
    >&2 echo "ERROR: --datasetdir not specified"
    exit 1
fi
if [[ ! -d $DATASETDIR ]];then
    >&2 echo "ERROR: dataset directory specified not found ($DATASETDIR)"
    exit 1
fi
if [[ $SUBJECT == "" ]];then
    >&2 echo "ERROR: subject not specified"
    exit 1
fi
if [[ $SESSION == "" ]];then
    SOURCE=$DATASETDIR/rawdata/sub-$SUBJECT
    if [[ $PIPELINE == "" ]];then
        TARGET=$DATASETDIR/rawdata/freesurfer/sub-$SUBJECT
    else
        TARGET=$DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT
    fi
else
    SOURCE=$DATASETDIR/rawdata/sub-$SUBJECT/ses-$SESSION
    if [[ $PIPELINE == "" ]];then
        TARGET=$DATASETDIR/derivatives/freesurfer/sub-$SUBJECT/ses-$SESSION
    else
        TARGET=$DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/ses-$SESSION
        
    fi
    
fi

if [[ ! -d $SOURCE ]];then
    >&2 echo "ERROR: Specified source directory doesn't exist: ($SOURCE)"
    exit 1
fi

cd $SOURCE
if [[ ! -d "anat" ]];then
    >&2 echo "T1 Structural directory not found in $SOURCE/anat"
    exit 1
fi

rm -r --force $TARGET/freesurfer

if [[ $REPROCESS == "N" ]];then
    echo "Checking existence of $TARGET/mri/wmparc.mgz"
    if [[ -f $TARGET/mri/wmparc.mgz ]];then
        echo "This exam as already been reconstructed.  Target exists ($TARGET)"
        exit 0
    else 
        echo "File not found, proceeding with reconstruction"
    fi
else
    #Check for empty directory in $TARGET
    if [ ! -z "$(ls -A $TARGET)" ]; then
        echo "Reconstruction output exisets.  This will be deleted before continuing"
        rm -r $TARGET/*
    fi


fi

shopt -s globstar  

for eachnii in $SOURCE/anat/sub-*T1w.nii*;do
    infile=$eachnii
    break;
done

#######################  DO THE WORK   #########################################
# Do Reconstruction here

mkdir -p $TARGET

SUBJECTS_DIR=$TARGET
echo "Performing cortical reconstruction from $infile"
echo "Output will be written to working directory: $TARGET"
recon-all -s freesurfer -i $infile -all 
if [[ $? -eq 0 && -f $TARGET/freesurfer/mri/wmparc.mgz ]];then
    mv $TARGET/freesurfer/* $TARGET
    rmdir $TARGET/freesurfer

    shopt -s globstar  
    for eachmgz in $TARGET/*.mgz;do
        if [[ -f $eachmgz ]];then        
            mgz_to_nifti $eachmgz
        fi
    done  

    # Convert mgz 2 nifti files

    echo "recon-all complete"
fi

# mkdir -p $TARGET/mri
# touch $TARGET/mri/wmparc.mgz 
# ecode=$?

#######################  VALIDATE   ############################################
# Validate the work
if [ ! -f "$TARGET/mri/wmparc.mgz" ];then 
    >&2 echo "ERROR: recon_all failed.  No changes committed"; 
    exit 1; 
fi


exit




#!/bin/bash

SCRIPT=$( realpath $0 )
SCRIPTPATH=$( dirname $SCRIPT )
source "${SCRIPTPATH}/lib/helper.sh"

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Perform image segmentation of reconstructed T1"
   echo
   echo "Usage: recon [OPTIONS...]"
   echo "options:"
   echo "--help                                 Print this Help."
   echo "--datasetdir  DIR                      Path to dataset directory (just above ../[source|rawdata|derivatives]/..)"
   echo "--subject SUBJECT                      Specify subject ID to clone.  If session not"
   echo "                                       specified, then clone the entire subject"
   echo "--session SESSION                      Specify session ID to clone"  
   echo "--pipeline PIPELINE                    Pipeline ID used to place parcellated segments in derivatives directory" 
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options

TEMP=`getopt -o h: --long help,datasetdir:,subject:,session:,pipeline:, \
             -n 'parcellate' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

DATASETDIR=""
SUBJECT=""
SESSION=""
PIPELINE=""

while true; do
  case "$1" in
    -h | --help ) Help;exit 1;;
    --datasetdir ) DATASETDIR="$2";shift 2;;     
    --subject ) SUBJECT="$2";shift 2;;
    --session ) SESSION="$2";shift 2;;
    --pipeline ) PIPELINE="$2";shift 2;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done


if [[ $DATASETDIR == "" ]];then
    >&2 echo "ERROR: --datasetdir not specified"
    exit 1
fi
if [[ ! -d $DATASETDIR ]];then
    >&2 echo "ERROR: dataset directory specified not found ($datasetdir)"
    exit 1
fi
if [[ $SUBJECT == "" ]];then
    >&2 echo "ERROR: subject not specified"
    exit 1
fi
if [[ $PIPELINE == "" ]];then
    >&2 echo "ERROR: pipeline not specified"
    exit 1
fi
if [[ $SESSION == "" ]];then
    SOURCE=$DATASETDIR/derivatives/freesurfer/sub-$SUBJECT
    TARGET=$DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT
else
    SOURCE=$DATASETDIR/derivatives/freesurfer/sub-$SUBJECT/ses-$SESSION
    TARGET=$DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/ses-$SESSION
fi

if [[ ! -d $SOURCE ]];then
    >&2 echo "ERROR: Specified source directory doesn't exist: ($SOURCE)"
    exit 1
fi

mkdir -p $TARGET/parcellations
if [[ ! -f $SOURCE/mri/wmparc.nii && -f $SOURCE/mri/wmparc.mgz ]];then
    #MGZ2Nifti not called yet.  lets convert inline
    mri_convert -rt nearest -nc -ns 1 $SOURCE/mri/wmparc.mgz $SOURCE/mri/wmparc.nii
fi
if [[ ! -f $SOURCE/mri/wmparc.nii ]];then
    >&2 echo "ERROR: $SOURCE/mri/wmparc.nii not found.  If an .mgz file was found I would have attempted conversion first."
    exit 1
# else
#     cp $SOURCE/mri/wmparc.nii $TARGET/parcellations
fi

cd $TARGET/parcellations
rm --force wmparc*.nii
if [[ -f wmparc-parcellated.tar ]];then
    rm wmparc-parcellated.tar
fi
#Iterate segment map, get a list of ROIs and split wmparc into individual components, one per ROI
cat "${SCRIPTPATH}/../assets/segmentMap.csv"|grep -v "#"|cut -d, -f1 | while read -r line; do
    mri_extract_label $SOURCE/mri/wmparc.nii $line wmparc$line.nii;tar -rf wmparc-parcellated.tar wmparc$line.nii --remove-files
done

parcels=$(cat "${SCRIPTPATH}/../assets/segmentMap.csv"|grep -v "#"|cut -d, -f1|wc -l)
echo "$parcels rois expected to be produced"

rendered=$(ls $TARGET/parcellations|wc -l) 
echo "$rendered rendered"

if [ "$rendered" -lt "$parcels" ];then
    >&2 echo "WARNING: Not all parcellations were created. Expected $parcels, found $rendered wmparc files."
fi
echo "Parcellation completed, $rendered files created in $TARGET/parcellations"
exit 0


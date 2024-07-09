#!/bin/bash


#set -e #Exit when a command fails
set +x #echo each command before it runs
echo "Reconstructing and Tracking..."
SCRIPT=$( realpath $0 )
SCRIPTPATH=$( dirname $SCRIPT )
source "${SCRIPTPATH}/lib/helper.sh"
source "${SCRIPTPATH}/lib/crush/crush_import.sh"

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Reconstruct images to tensors and perform fiber tracking"
   echo
   echo "Usage: tracking [OPTIONS...]"
   echo "options:"
   echo "--help                                 Print this Help."
   echo "--datasetdir  DIR                      Path to dataset directory (just above ../[source|rawdata|derivatives]/..)"
   echo "--subject SUBJECT                      Specify subject ID to clone.  If session not"
   echo "                                       specified, then clone the entire subject"
   echo "--session SESSION                      Specify session ID to clone"  
   echo "--pipeline PIPELINE_ID                 Specify derivatives directory to store output.  If unspecified, store in crush." 
   echo "--gradientmatrix GRADIENTMATRIX        If a gradient matrix file has been provided, specifiy its location here"
   echo "--maxcores MAX                         Specify a hard limit on the number of cores used"
   echo "--overwrite                            Overwrite any existing derivative files with a conflicting name"
   echo "--invert_x                             [dti|odf]_tracker switch to invert x vector"
   echo "--invert_y                             [dti|odf]_tracker switch to invert y vector"
   echo "--invert_z                             [dti|odf]_tracker switch to invert x,y, or z component(s) of vector"
   echo "--swap_sxy                             [dti|odf]_tracker switch to swap x and y vectors while tracking"
   echo "--swap_syz                             [dti|odf]_tracker switch to swap y and z vectors while tracking"
   echo "--swap_szx                             [dti|odf]_tracker switch to swap x and z vectors while tracking"
   echo "--verbose                              Print out all commands executed"
   
   echo
}


############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options

TEMP=`getopt -o h: --long help,datasetdir:,subject:,session:,pipeline:,maxcores:,gradientmatrix:,bmax:,b0:,overwrite,invert_x,invert_y,invert_z,swap_sxy,swap_syz,swap_szx,verbose\
             -n 'tracking' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

DATASETDIR=""
SUBJECT=""
SESSION=""
PIPELINE=""
GRADIENTMATRIX=""
MAXCORES=""
BMAX=""
BNOT=""
OVERWRITE=0
INVERT_X=""
INVERT_Y=""
INVERT_Z=""
SWAP_SXY=""
SWAP_SYZ=""
SWAP_SZX=""
VERBOSE="N"

while true; do
  case "$1" in
    -h | --help ) Help;exit 1;;
    --datasetdir ) DATASETDIR="$2";shift 2;;     
    --subject ) SUBJECT="$2";shift 2;;
    --session ) SESSION="$2";shift 2;;
    --pipeline ) PIPELINE="$2";shift 2;;
    --gradientmatrix ) GRADIENTMATRIX="$2";shift 2;;
    --bmax ) BMAX="$2";shift 2;;
    --BNOT ) BNOT="$2";shift 2;;   
    --maxcores ) MAXCORES="$2";shift 2;;
    --overwrite ) OVERWRITE=1;shift;;     
    --invert_x ) INVERT_X=" -ix";shift;;     
    --invert_y ) INVERT_Y=" -iy";shift;;     
    --invert_z ) INVERT_Z=" -iz";shift;;             
    --swap_sxy ) SWAP_SXY=" -sxy";shift;;         
    --swap_syz ) SWAP_SYZ=" -syz";shift;;         
    --swap_szx ) SWAP_SZX=" -szx";shift;; 
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

if [[ $PIPELINE == "" ]];then
    >&2 echo "ERROR: pipeline not specified"
    exit 1
fi
if [[ $SESSION == "" ]];then
    >&2 echo "WARNING: session not specified"  
    SESSIONpath=""
else
    SESSIONpath="ses-$SESSION"  
fi

if [[ $GRADIENTMATRIX != "" && ! -f $GRADIENTMATRIX ]];then
    >&2 echo "ERROR: A gradient matrix has been specified but cannot be found ($GRADIENTMATRIX)"
    exit 1    
fi  


SOURCE=$DATASETDIR/rawdata/sub-$SUBJECT/$SESSIONpath
TARGET=$DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath
FREESURFER=$DATASETDIR/derivatives/freesurfer/sub-$SUBJECT/$SESSIONpath
  
if [[ ! -d $SOURCE ]];then
    >&2 echo "ERROR: Specified source directory doesn't exist: ($SOURCE)"
    exit 1
fi

echo "Cleaning house..."
if [[ $OVERWRITE -eq 1 ]];then
    rm --force $TARGET/hardi_mat*.dat #Clear hardi_mat output    
    rm --force $TARGET/recon_out*  # clear odf_recon output    
    rm --force $TARGET/dti_recon_out* # clear dti_recon output        
    rm --force $TARGET/odf_tracker.log  
    rm --force $TARGET/dti_tracker.log 
    rm --force $TARGET/RegTransform4D  #clear flirt output
    rm --force $TARGET/crush.trk  #Clear track_transform output
    rm --force $TARGET/crush_qball.trk  #Clear track_transform output
    rm --force $TARGET/crush_dti.trk #Clear track_transform output
    rm --force $TARGET/gradientmatrix*.txt  #Clean up old gradient matrix files    
    rm --force $TARGET/core.* #Remove old core dumps

    echo "Any previous output have been removed"
fi

mkdir -p $TARGET

if [[ $GRADIENTMATRIX != "" ]];then
    cp $GRADIENTMATRIX $TARGET/gradientmatrix_dti.txt
    cp $GRADIENTMATRIX $TARGET/gradientmatrix_qball.txt
else

    if [[ -f $TARGET/gradientmatrix_dti.txt ]];then
        echo "Existing gradientmatrix for dti imaging model detected.  Skipping (re-)creation."    
    else 
        echo "Calculating reconstruction matrix from gradient table::dti"
        f_creategradientmatrix $TARGET/gradientmatrix_dti.txt dti
    fi


    if [[ -f $TARGET/gradientmatrix_qball.txt ]];then
        echo "Existing gradientmatrix for qball imaging model detected.  Skipping (re-)creation."    
    else 
        echo "Calculating reconstruction matrix from gradient table::qball"
        f_creategradientmatrix $TARGET/gradientmatrix_qball.txt qball
    fi

fi
echo "Gradients..."

res=$?
if [[ $res -ne 0 ]];then
    >&2 echo "ERROR: Unable to establish a gradient matrix.  Unable to continue."
fi
echo "Hardi..."
###########################
# HARDI_MAT               #
###########################

if [[ $GRADIENTMATRIX == "" ]];then
    GRADIENTMATRIX=$TARGET/gradientmatrix_dti.txt     
fi

if [[ -f $TARGET/reg2brain.data.nii ]];then
   gz=""
else
   gz=".gz"
fi

f_hardi_mat $TARGET/gradientmatrix_dti.txt "dti" "$TARGET/reg2brain.data.nii$gz"
res=$?

if [[ $res != 0 ]];then
    >&2 echo "ERROR: Unable to perform hardi_mat.  Unable to continue."
    exit 1
fi

if [[ -f "$TARGET/reg2brain_hardi.data.nii$gz" ]];then
    f_hardi_mat $TARGET/gradientmatrix_qball.txt "qball" "$TARGET/reg2brain_hardi.data.nii$gz"
    
    res=$?

    if [[ $res != 0 ]];then
        >&2 echo "ERROR: Unable to perform hardi_mat (for hardi/q-ball reconstruction).  Unable to continue."
        exit 1
    fi
else
    echo "$TARGET/reg2brain_hardi.data.nii$gz not found. HARDI reconstruction will not be possible.  Skipping."
fi

###########################
# RECON                   #
###########################
echo "Recon..."
diffusion_result=$( f_diffusion_recon $INVERT_X $INVERT_Y $INVERT_Z $SWAP_SXY $SWAP_SYZ $SWAP_SZX )
res=$?


if [[ ! $res -eq 0 ]];then
    >&2 echo $diffusion_result
    if [[ ! $res -eq 2 ]];then   #2 means files already exist and overwrite not specified  
        >&2 echo "ERROR: Unable to perform Cortical Reconstruction.  Unable to continue."
        exit 1
    fi
fi
#We don't always know the correct settings for tracking, so lets do them all for review later
echo "Tracking alternative tract settings for visual inspection"
${SCRIPTPATH}/test-for-inversion.sh $TARGET "dti"

###############################
# flirt / affine registration #
###############################
echo "flirt..."
flirt_result=$( f_flirt )
res=$?

if [[ $res != 0 ]];then
    >&2 echo "ERROR: Unable to perform flirt/affine registration.  Unable to continue."
    >&2 echo $flirt_result
    exit 1
fi
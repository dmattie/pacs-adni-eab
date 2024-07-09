#!/bin/bash


#set -e #Exit when a command fails
#set -x #echo each command before it runs
echo "Crushing..."
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
   echo "Cartesian product of Region to Region tract measurement extraction"
   echo
   echo "Usage: crush [OPTIONS...]"
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
   echo "--overlay                              Path to optional singularity overlay file"
   echo "--verbose                              Print out all commands executed"
   
   echo
}


############################################################
# Process the input options. Add options as needed.        #
############################################################
# # Get the options

# TEMP=`getopt -o h: --long help,datasetdir:,subject:,session:,pipeline:,maxcores:,gradientmatrix:,overwrite,verbose,overlay:\
#              -n 'crush' -- "$@"`

# if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# # Note the quotes around `$TEMP': they are essential!
# echo "xxxxxxxx $TEMP   xxxxxxxxx"
# #eval set -- "$TEMP"
# echo "yyyyyyyy $TEMP   yyyyyyyyy"

DATASETDIR=""
SUBJECT=""
SESSION=""
PIPELINE=""
GRADIENTMATRIX=""
MAXCORES=$SLURM_CPUS_PER_TASK
OVERWRITE=0
VERBOSE="N"
OVERLAY=""

if [[ $MAXCORES == "" ]];then
  >&2 echo "ERROR: this job appears to be set to run on one CPU (variable SLURM_CPUS_PER_TASK unset).  This will probably fail.  Set sbatch --cpus-per-task" 
  exit 1
fi
# while true; do
#   case "$1" in
#     -h | --help ) Help;exit 1;;
#     --datasetdir ) DATASETDIR="$2";shift 2;;     
#     --subject ) SUBJECT="$2";shift 2;;
#     --session ) SESSION="$2";shift 2;;
#     --pipeline ) PIPELINE="$2";shift 2;;
#     --gradientmatrix ) GRADIENTMATRIX="$2";shift 2;;
#     --maxcores ) MAXCORES="$2";shift 2;;
#     --overwrite ) OVERWRITE=1;shift;; 
#     --overlay ) OVERLAY="$2";shift 2;;    
#     --verbose ) VERBOSE="Y";shift;;                
#     -- ) shift; break ;;
#     * ) break ;;
#   esac
# done
args=( )
#replace long parms
for arg; do
    case "$arg" in
        --help)             args+=( -h ) ;;
        --datasetdir)       args+=( -d ) ;;
        --subject)          args+=( -S ) ;;
        --session)          args+=( -s ) ;;
        --pipeline)         args+=( -p ) ;;
        --gradientmatrix)   args+=( -g ) ;;
        --overwrite)        args+=( -o ) ;;
        --overlay)          args+=( -O ) ;;
        --verbose)          args+=( -v ) ;;
        --maxcores)         args+=( -m ) ;;
        *)                  args+=( "$arg" ) ;;
    esac
done

printf 'args before update : '; printf '%q ' "$@"; echo
set -- "${args[@]}"
printf 'args after update  : '; printf '%q ' "$@"; echo

while getopts "hd:S:s:p:g:oO:v" OPTION; do
    : "$OPTION" "$OPTARG"
    echo "optarg : $OPTARG"
    case $OPTION in
    h) Help;exit 0;;
    d) DATASETDIR="$OPTARG";;
    S) SUBJECT="$OPTARG";;
    s) SESSION="$OPTARG";;
    p) PIPELINE="$OPTARG";;
    g) GRADIENTMATRIX="$OPTARG";;
    o) OVERWRITE=1;;
    O) OVERLAY="$OPTARG";;
    v) VERBOSE="Y";;
    m) MAXCORES="$OPTARG";;
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
    >&2 echo "ERROR: dataset directory specified not found \(${DATASETDIR}\)"
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
    >&2 echo "ERROR: A gradient matrix has been specified but cannot be found \($GRADIENTMATRIX\)"
    exit 1    
fi  


SOURCE=$DATASETDIR/rawdata/sub-$SUBJECT/$SESSIONpath
TARGET=$DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath
FREESURFER=$DATASETDIR/derivatives/freesurfer/sub-$SUBJECT/$SESSIONpath
  
# if [[ ! -d $SOURCE ]];then
#     >&2 echo "ERROR: Specified source directory doesn\'t exist: \($SOURCE\)"
#     exit 1
# fi


if [[ $OVERWRITE -eq 1 ]];then
    echo "Cleaning house..."
    rm -r --force $TARGET/crush  #Clean up old crush derived results
    rm --force $TARGET/core.* #Remove old core dumps

    echo "Any previous output have been removed"
fi

mkdir -p $TARGET

if [[ $GRADIENTMATRIX != "" ]];then
    cp $GRADIENTMATRIX $TARGET/gradientmatrix_dti.txt
    cp $GRADIENTMATRIX $TARGET/gradientmatrix_qball.txt
fi


#####################################
#  ROI x ROI measurement extraction #
#####################################

if [[ -f $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath/parcellations/wmparc-parcellated.tar ]];then
   cd $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath/parcellations
   #If the tar file isn't already expanded, then do so
   no_of_niis=`ls *.nii|wc -l`   
   if [[ $no_of_niis -eq 0 ]];then
       tar -xf wmparc-parcellated.tar
   fi
   
fi
#echo -n "Checking overlay...${APPTAINER_NAME}"
#if [[ ! -z "${APPTAINER_NAME}" ]]; then
  if [[ $OVERWRITE -eq 1 ]];then
    rm -r --force /crush
  fi
  mkdir -p /crush
  if [[ $? -eq 0 ]];then
    OVERLAY_PATH="/crush" 
    CRUSHPATH="/crush"
    echo "You appear to have an overlay file. Crush will work in $OVERLAY_PATH"
  else    
    OVERLAY_PATH=""
    CRUSHPATH="$DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath/crush"
    echo "No overlay file detected.  It is strongly encouraged to use an overlay file to improve performance and avoid disk quotas.  See APPTAINER overlays."
    exit 1
  fi  
# else
#   OVERLAY_PATH=""
#   CRUSHPATH="$DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath/crush"
#   echo "No overlay file detected.  It is strongly encouraged to use an overlay file to improve performance and avoid disk quotas.  See APPTAINER overlays."
#   exit 1
# fi
#############################################################################
echo "Crushing across $MAXCORES processes"
#############################################################################
allSegments=("")
methods=("roi" "roi_end")
segmentMap="${SCRIPTPATH}/../assets/segmentMap.csv"
while read p; do
  comment="^#"
  if [[ ! $p =~ $comment ]];then
    segment=$( echo $p|cut -d, -f1 )
    allSegments+=( $segment )    
  fi
done <$segmentMap
rm -f $TARGET/crush_iterator.csv
echo "Writing to $TARGET/crush_iterator.csv"

for roi_start in "${allSegments[@]}"
do
  if [[ $roi_start != "" ]] && [[ -f $TARGET/parcellations/wmparc$roi_start.nii ]];then
    for roi_end in "${allSegments[@]}"    
    do
      # If not empty and end is greater than start and file exists
      # Note single brackets avoid evaluating as octal
      if [[ $roi_end != "" ]] && [ $roi_end -ne $roi_start ] && [[ -f $TARGET/parcellations/wmparc$roi_end.nii ]];then
        for method in "${methods[@]}"
        do
          if [[ $roi_start != $roi_end ]];then
            echo "${roi_start},${roi_end},$method" >> $TARGET/crush_iterator.csv
          fi
        done
      fi
    done
  fi
done
iterator_len=`wc -l $TARGET/crush_iterator.csv`
if [[ $? -eq 0 ]];then
 echo "Found $iterator_len ROIs to iterate"
else
  echo "FAILED, iterator appears incomplete ($TARGET/crush_iterator.csv).  Was parcellation task performed?"
  return 1
fi
if [[ -f $TARGET/crush_qball.trk ]];then
    TRACT=$TARGET/crush_qball.trk
else
    TRACT=$TARGET/crush_dti.trk
fi
cat $TARGET/crush_iterator.csv |xargs -P $MAXCORES -I@ ${SCRIPTPATH}/lib/crush/get_tract_measurements2.py -roi @ -tract ${TRACT} -pipeline ${PIPELINE} -crush_dir ${CRUSHPATH}

if [[ ! $? -eq 0 ]];then
  echo "FAILED, previous messages should elucidate the issue"
  return 1
fi
# cat $TARGET/crush_iterator.csv |xargs -I@ bash -c 'roi_start=`echo @|cut -d, -f1`;roi_end=`echo @|cut -d, -f2`;method=`echo @|cut -d, -f3`;echo python '${SCRIPTPATH}'/lib/crush/get_tract_measurements.py -roi_start '${roi_start}' -roi_end '$roi_end' -method '$method' -tract '${TRACT}' -pipeline '${PIPELINE}' -crush_dir '${CRUSHPATH}
#exit
##########################################################################
# if [[ $MAXCORES == "" ]];then
#     python3 ${SCRIPTPATH}/lib/crush/crush.py -datasetdir $DATASETDIR \
#     -subject $SUBJECT \
#     -session "$SESSION" \
#     -pipeline $PIPELINE \
#     -overlay "$OVERLAY_PATH"
# else
#     python3 ${SCRIPTPATH}/lib/crush/crush.py -datasetdir $DATASETDIR \
#     -subject $SUBJECT \
#     -session "$SESSION" \
#     -pipeline $PIPELINE \
#     -maxcores $MAXCORES \
#     -overlay "$OVERLAY_PATH"
# fi
##########################################################################
if [[ -f $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath/parcellations/wmparc-parcellated.tar ]];then
   cd $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath/parcellations
   rm *.nii
fi

echo "Consolidating"

python3 ${SCRIPTPATH}/lib/crush/consolidate-measurements.py \
-crushpath $CRUSHPATH \
-subject $SUBJECT \
-session $SESSION \
-pipeline $PIPELINE \
-out $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath/crush.txt

if [[ $? -eq 0  ]];then
    echo "MEASUREMENT COMPLETE"
    python3 ${SCRIPTPATH}/lib/crush/consolidate-audit.py \
    -measurements $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath/crush.txt \
    -segmentmap $segmentMap

    cd  $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/$SESSIONpath
    if [[ -d crush ]];then
        tar -rf crush.tar crush --remove-files 
    fi
else
    echo "Consolidation failed"
fi


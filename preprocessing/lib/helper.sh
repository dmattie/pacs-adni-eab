#!/bin/bash

function case_aa_test {  ## ABIDE  
  if [[ -d $DATASETDIR/source/$SUBJECT 
  && -d $DATASETDIR/source/$SUBJECT/session_$SESSION
  && -d $DATASETDIR/source/$SUBJECT/session_$SESSION/anat_1 
  && -f $DATASETDIR/source/$SUBJECT/session_$SESSION/anat_1/anat.nii.gz ]];then
    echo 0
  fi
  echo 1
}

function get_setting {
    setting=$1
    default=$2
    if [[ -f ~/.airneuro.conf ]];then
        RES=$(cat .airneuro.conf|grep ${setting}|cut -d= -f2)
    else
        RES=$default
    fi
    echo $RES
}
function get_subject {    
    absolute_path=$( readlink -f $1 )    
    anticipated_subject=$( echo $absolute_path |rev|cut -d'/' -f2|rev )
    anticipated_session=$( echo $absolute_path |rev|cut -d'/' -f1|rev )
    #If the session doesn't start with ses- then assume the last dir in path 
    #is the subject instead of second last.    
    if [[ ${#anticipated_session} -ge 4 ]];then
        prefix=${anticipated_session:0:4}                    
        if [[ ! $prefix == "ses-" ]];then
            #last dir doesn't start with session. assume this dir is SUBJECT
            #This can happen if pulling from non-bids compliant dir like 
            #original source
            echo $anticipated_session
            exit
        fi
    fi
    #If last dir started with ses-, then second last probably starts with sub-
    #just return second last dir
    echo $anticipated_subject
    
}
function get_session {
    absolute_path=$( readlink -f $1 )
    #echo ${absolute_path}|rev|cut -d'/' -f1|rev 
    anticipated_subject=$( echo $absolute_path |rev|cut -d'/' -f2|rev )
    anticipated_session=$( echo $absolute_path |rev|cut -d'/' -f1|rev )
    #If the session doesn't start with ses- then assume the last dir in path 
    #is the subject instead of second last.    
    if [[ ${#anticipated_session} -ge 4 ]];then
        prefix=${anticipated_session:0:4}                    
        if [[ ! $prefix == "ses-" ]];then
            #last dir doesn't start with session. assume this dir is SUBJECT
            #This can happen if pulling from non-bids compliant dir like 
            #original source.  For now, just return 1 as session
            echo "1"
            exit
        fi
    fi
    #If last dir started with ses-, just return last dir
    echo $anticipated_session
    
}
function strip_prefix {
    input=$1
    if [[ ${#input} -ge 4 ]];then        
        prefix=${input:0:4}          
        if [[ $prefix == "sub-" || $prefix == "ses-" ]];then              
            echo ${input:4:50}
            exit            
        fi
    fi
    echo $input
}
function get_derivatives {
    absolute_path=$( readlink -f $1/../../../derivatives )
    echo ${absolute_path}
}

function begin_transaction {
    source=$1
    UUID=$(cat /proc/sys/kernel/random/uuid)
    stagingdir=$AIRCRUSH_SCRATCH/$UUID

    if [[ -z "${AIRCRUSH_SCRATCH}" ]];then
        echo "ERRPR: Environment variable AIRCRUSH_SCRATCH not set. It must be set to continue"
        exit 1
    fi 
    if [[ ! -d $source ]];then
        echo "ERROR: Source directory does not exist ($source)"
        exit 1
    fi  
    mkdir -p $AIRCRUSH_SCRATCH
    if [[ ! -d ${AIRCRUSH_SCRATCH} ]];then
        echo "ERROR: Scratch directory does not exist (${AIRCRUSH_SCRATCH})"
        exit 1
    fi    

    mkdir -p $stagingdir
    if [[ ! $? -eq 0 ]];then
        echo "ERROR: Unable to create temporary working directory ($stagingdir)"
        exit 1
    fi

    rsync -r $source/ $stagingdir
    if [[ ! $? -eq 0 ]];then
        echo "ERROR: Unable to create snapshot of source for atomic transaction"
        exit 1
    fi

    echo $stagingdir

}
function end_transaction {
    transactiondir=$1
    target=$2


    if [ ! -d $transactiondir ];then echo "ERROR: Source transaction directory ($transactiondir) does not exist"  ; exit 2; fi
    
    mkdir -p $target
    if [ ! $? == 0 ];then echo "ERROR: Failed to create target directory ($target)";exit 2; fi
    
    rsync -r $transactiondir/ $target
    if [ ! $? == 0 ];then echo "ERROR: Failed to sync transaction ($transactiondir) to target directory ($target)";exit 2; fi

    if [[ ! -z "${AIRCRUSH_SCRATCH_KEEP_FOR_DEBUG}" ]];then        
        if [[ "${AIRCRUSH_SCRATCH_KEEP_FOR_DEBUG}" == "Y" ]];then
            echo "INFO: Transaction directory ($transactiondir) has not been purged due to AIRCRUSH_SCRATCH_KEEP_FOR_DEBUG environment variable set to Y"
            exit 0
        fi
    fi

    rm -r $transactiondir
    if [ ! $? == 0 ];then echo "ERROR: Failed to cleanup temporary transaction directory ($transactiondir)"; exit 2; fi

}
function mgz_to_nifti {
    filepath=$( dirname -- $1 )
    filename=$( basename -- $1 )
    extension="${filename##*.}"
    filename="${filename%.*}"

    if [[ -d $filepath ]];then
        cd $filepath
        mri_convert -rt nearest -nc -ns 1 $1 ${filename}.nii               
    fi

}

function spin {
   local -a marks=( '/' '-' '\' '|' )
   while [[ 1 ]]; do
     printf '%s\r' "${marks[i++ % ${#marks[@]}]}"
     sleep 1
   done
 }

export get_subject
export get_session
export get_derivatives
export strip_prefix
export begin_transaction
export end_transaction
export mgz_to_nifti
export spin

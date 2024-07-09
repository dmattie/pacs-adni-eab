
#!/bin/bash

############################################################
# hardi_mat                                                     #
############################################################
f_hardi_mat()
{

    matrix=$1
    imaging_model=$2
    ref=$3

    #######  Determine the diffusion file for reference
    # shopt -s globstar  
    # for eachnii in $SOURCE/dwi/sub-*.nii*;do
    #     ref=$eachnii
    #     break;
    # done
    if [[ ! -f $ref ]];then
        echo "FALSE"
        >&2 echo "ERROR: Diffusion file not found matching search pattern : ($ref)"
        exit 1
    fi
    
    ######## Create a reconstruction matrix for dti and for qball 
    if [[ -f $TARGET/hardi_mat_dti.dat && -f $TARGET/hardi_mat_qball.dat  ]];then
        echo "Existing hardi_mat output detected and overwrite not specified.  Skipping (re-)creation for $imaging_model."
        return 0
    fi
    echo "Calculating reconstruction matrix from gradient table"

    if [[ ! -f $matrix ]];then
        >&2 echo "hardi_mat:gradient matrix file missing[$matrix]."     
        return 1   
    fi
    if [[ $imaging_model != "dti" && $imaging_model != "qball" ]];then
        >&2 echo "ERROR: hardi_mat produces a matrix file that may need to vary by image reconstruction model.  Specify dti or qball.  Unable to continue."
        return 1
    fi

    
    hardi_mat $matrix $TARGET/hardi_mat_${imaging_model}.dat -ref $ref -oc
    # hardi_mat $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/ses-$SESSION/gradientmatrix.txt \
    #     $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/ses-$SESSION/hardi_mat.dat \
    #     -ref $DATASETDIR/derivatives/$PIPELINE/sub-$SUBJECT/ses-$SESSION/reg2brain.data.nii.gz \
    #     -oc
    ret=$?
    if [[ $ret -ne 0 ]];then
        >&2 echo "ERROR: hardi_mat failed with error. see above."
        exit $ret
    fi

}
export f_hardi_mat

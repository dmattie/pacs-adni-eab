#!/bin/bash

############################################################
# creategradientmatrix                                     #
############################################################
f_creategradientmatrix()
{
    matrix=$1
    imaging_model=$2

    if [[ $GRADIENTMATRIX != "" && -f $GRADIENTMATRIX ]];then
        cp $GRADIENTMATRIX $matrix
        if [[ ! -f $matrix ]];then
            >&2 echo "Unable to copy specified gradient matrix to $matrix"                        
            return 1
        fi
    else
        #Todo support for a "bvecs" filename is non compliant and needs to be deprecated.
        bvecs=$DATASETDIR/rawdata/sub-$SUBJECT/$SESSIONpath/dwi/bvecs
        
        if [[ ! -f $bvecs ]];then
            #Lets find a bids compliant bvecs filename supporting multiple runs (we'll take the first one we find)
            shopt -s globstar
            for eachbvec in $DATASETDIR/rawdata/sub-$SUBJECT/$SESSIONpath/dwi/sub-${SUBJECT}_$SESSIONpath*_dwi.bvec; do
                bvecs=$eachbvec
                break;
            done
        fi
        
        if [[ ! -f $bvecs ]];then
            >&2 echo "Gradient table not specified and convertable bvecs not found ($bvecs).  Unable to proceed."
            
            return 1
        fi   

        ${SCRIPTPATH}/lib/crush/create_gradient_matrix.py -bvec $bvecs -out $matrix -imaging_model $imaging_model

        if [[ ! -f $matrix || ! $? -eq 0 ]];then
            >&2 echo "Gradient table ($matrix) could not be created from ($bvecs).  Unable to proceed."
            return 1
        fi

    fi
    return 0

}
export f_creategradientmatrix
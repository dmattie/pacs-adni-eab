#!/bin/bash

SCRIPT=$( realpath $0 )
SCRIPTPATH=$( dirname $SCRIPT )
#source "${SCRIPTPATH}/lib/crush/dti_recon.sh"
#source "${SCRIPTPATH}/lib/crush/odf_recon.sh"


############################################################
# diffusion exists
############################################################

function f_diffusion_exists()
{
    diffusion_type=$1
    if [[ $1 == 'hardi' ]];then
      diffusion_type='_hardi'
    else
      diffusion_type=''
    fi

    shopt -s globstar  
    # for eachnii in $SOURCE/dwi/sub-*.nii*;do
    #     dwifile=$eachnii
    #     break;
    # done
    dwifile=$TARGET/reg2brain$diffusion_type.data.nii.gz
    dwifile_unzipped=$TARGET/reg2brain$diffusion_type.data.nii
    #     dwifile=$eachnii
    #     break;
    # done
    if [ ! -f $dwifile ] && [ ! -f $dwifile_unzipped ];then      
        echo "FALSE"
        >&2 echo "ERROR: Diffusion file not found matching search pattern : ($dwifile) or unzipped equiv"
        exit 1
    fi
   
    if [ -f $dwifile ];then
      rm --force $dwifile_unzipped
      gunzip $dwifile
    fi

    cd $TARGET
    
    if [[ -f $dwifile_unzipped ]];then
      echo $dwifile_unzipped
    else
      echo $dwifile
    fi

}


############################################################
# dti_recon                                                #
############################################################
function f_dti_recon()
{
 
    #Params:
    #  1: path to 3D diffusion weighted image
    #  2: path to gradientmatrix file
    #  3: high b value (e.g. 1000)
    #  4: number of b0 rows in gradient matrix
  dwi=$1
  matrix=$2
  highb=$3
  b0=$4  #NOT USED SEE BELOW!!!!!!!!!!!!!!!!!!!
  shift;shift;shift;shift;
  #echo "f_dti_recon extras:{$@}"
  >&2 echo "DTI RECON---\nDWI:$dwi\nmatrix:$matrix\nhighb:$highb\nb0:$b0"
  cd $TARGET

  if [[ -f $TARGET/dti_recon_out_fa.nii 
     && -f $TARGET/dti_recon_out_adc.nii
     && -f $TARGET/dti_recon_out_dwi.nii ]];then   
     echo "Previous dti_recon output detected.  Skipping dti_recon" 
     if [[ ! -f $TARGET/crush_dti.trk ]];then 
       >&2 echo "No tract file detected.  Tracking $TARGET/crush_dti.trk"
          dti_tracker "dti_recon_out" "crush_dti.trk" -m dti_recon_out_dwi.nii -it "nii" "$@"   
          return $?
     fi
    return 2
  fi
  b0=`cat $matrix | grep "0,0,0"|wc -l`
  dti_recon $dwi "dti_recon_out" -gm $matrix -b $highb -b0 $b0 -p 3 -sn 1 -ot nii
  res=$?   
  if [[ $res != 0 ]];then
    >&2 echo "ERROR: Unable to complete dti_recon"
    return 1
  fi
  if [[ ! -f "crush_dti.trk" ]];then
    dti_tracker "dti_recon_out" "crush_dti.trk" -m dti_recon_out_dwi.nii -it "nii" "$@"      
  fi
  return $?

}


############################################################
# odf_recon                                                #
############################################################
function f_odf_recon()
{
    #Params:
    #  1: path to 3D diffusion weighted image
    #  2: high b value (e.g. 1000)
    #  3: number of b0 rows in gradient matrix

  dwi=$1
  bmax=$2
  highb=$3
  b0=$4  
  

  shift;shift;shift;shift;
  >&2 echo "f_odf_recon extras:{$@}"

  >&2 echo "ODF RECON----"
  >&2 echo "DWI:$dwi"
  >&2 echo "bmax:$bmax"
  >&2 echo "highb:$highb"
  >&2 echo "b0:$b0"

  cd $TARGET
  if [[ ! -f $TARGET/hardi_mat_qball.dat ]];then
    >&2 echo "WARNING: hardi_mat_qball.dat was not present.  Unable to perform ODF RECON, skipping and falling back to DTI"
    return 0
  fi

  if [[ -f $TARGET/recon_out_odf.nii && -f $TARGET/recon_out_max.nii && -f $TARGET/recon_out_b0.nii && -f $TARGET/recon_out_dwi.nii ]];then
    >&2 echo "Previous odf_recon output detected. Skipping odf_recon"
    if [[ ! -f $TARGET/crush_qball.trk ]];then
        >&2 echo "No tract file detected.  Tracking $TARGET/crush_qball.trk"
        echo odf_tracker "recon_out" "crush_qball.trk" -m recon_out_dwi.nii -it "nii" "$@"        
        odf_tracker "recon_out" "crush_qball.trk" -m recon_out_dwi.nii -at 35 -it "nii" "$@"        
        return $?
    fi    
    return 2
  fi

  nframes=`mri_info $dwi|grep nframes:|cut -d':' -f2|xargs`
  if [[ ! $((nframes)) -gt 0 ]];then
    >&2 echo "ERROR: Unable to determine the number of frames in dwi file [$dwi]. Unable to proceed, number of directions must be known before performing odf_recon"    
    return 1
  fi

  #measurementpoints=`cat $TARGET/gradientmatrix_qball.txt|wc -l`
  measurementpoints=`cat $TARGET/gradientmatrix_qball.txt.directions`

  #NUMBER_OF_DIRECTIONS=$((nframes+0))
  NUMBER_OF_DIRECTIONS=$((measurementpoints+1-$b0))
  NUMBER_OF_OUTPUT_DIRS=181  
  echo odf_recon $dwi $NUMBER_OF_DIRECTIONS $NUMBER_OF_OUTPUT_DIRS "recon_out" -mat $TARGET/hardi_mat_qball.dat -b0 $b0 -ot nii -p 3 -sn 1
  odf_recon $dwi $NUMBER_OF_DIRECTIONS $NUMBER_OF_OUTPUT_DIRS "recon_out" -mat $TARGET/hardi_mat_qball.dat -b0 $b0 -ot nii -p 3 -sn 1

  res=$?
  if [[ $res != 0 ]];then
    >&2 echo "ERROR: Unable to complete odf_recon"    
    return 1
  fi
  if [[ ! -f "crush_qball.trk" ]];then
    echo odf_tracker "recon_out" "crush_qball.trk" -m recon_out_dwi.nii -it "nii" "$@"
    odf_tracker "recon_out" "crush_qball.trk" -m recon_out_dwi.nii -at 35 -it "nii" "$@"  
  fi
  return $?


}

############################################################
# recon                                                    #
############################################################
function f_diffusion_recon()
{    
    dwifile_dti=$( f_diffusion_exists "dti" )
    dwifile_hardi=$( f_diffusion_exists "hardi" )
   # gradientmatrix=$TARGET/gradientmatrix.txt


    if [[ $dwifile_dti == "FALSE" ]];then
        >&2 echo "ERROR: Diffusion file not found matching search pattern : ($dwifile)."        
        return 1
    fi
    #How many B values do we have.  If only one, we can use ODF recon, otherwise use DTI
    #Todo support for a "bvecs" filename is non compliant and needs to be deprecated.
    BVALS=$SOURCE/dwi/bvals

    if [[ ! -f $BVALS ]];then
        #Lets find a bids compliant bvals filename supporting multiple runs (we'll take the first one we find)
        shopt -s globstar
        for eachbval in $SOURCE/dwi/sub-${SUBJECT}_*_dwi.bval; do
            BVALS=$eachbval
            break;
        done
    fi

    if [[ ! -f $BVALS ]];then    
        >&2 echo "ERROR: $SOURCE/dwi/bvals not found.  Unable to continue, I need to know how many high b values I am working with"        
        return 1
    fi

    #Find highest b val

    if [[ $BMAX == "" ]];then
        #Look at bvals file and find largest integer
        BMAX_VAL=`cat $BVALS|tr '\t' '\n'|tr ' ' '\n'|sort -u|grep -v '^0'|grep -v -e '^$'|sort -nr|head -1`
        BMAX="-b $BMAX_VAL"
        >&2 echo "Using high b value of $BMAX_VAL as per dwi/bvals file"
    else
        #Use passed value 
        BMAX_VAL=$BMAX
        BMAX="-b $BMAX"
        
    fi   

    num_high_b_vals=`cat $BVALS|tr '\t' '\n'|tr ' ' '\n'|sort -u|grep -v '^0'|grep -v -e '^$'|wc -l`
    b0=`cat $BVALS|tr '\t' '\n'|tr ' ' '\n'|grep '^0'|wc -l`
    cat $BVALS
    >&2 echo "Detected b0 volumes: $b0"
    if [[ $num_high_b_vals == '1' ]];then
        # ODF Recon can be used     
        echo "Performing ODF Reconstruction"      
        if [[ -f $dwifile_hardi ]];then
          echo "f_odf_recon $dwifile_hardi $BMAX_VAL $num_high_b_vals $b0 $@"
          res=$( f_odf_recon $dwifile_hardi $BMAX_VAL $num_high_b_vals $b0 "$@")        
          res_code=$?
          if [[ $res_code != 0 ]];then
              echo $res
              if [[ $res_code == 2 ]];then
                  return 0
              fi        
              >&2 echo "ERROR: odf_recon failed. Previous messages may contain a clue. Unable to proceed."            
              return 1
          fi
        else
          echo "$dwifile_hardi not found.  Unable to process Q-Ball/HARDI.  Falling back to DTI."
        fi
    else
      >&2 echo "More than one shell detected, unable to process Q-Ball/HARDI.  Falling back to DTI"
    fi             
    #Lets also use DTI_RECON, we need the FA maps anyway
    echo "Performing DTI Recononstruction"
    echo "f_dti_recon $dwifile_dti $TARGET/gradientmatrix_dti.txt $BMAX_VAL $num_high_b_vals $@"
    res=$( f_dti_recon $dwifile_dti $TARGET/gradientmatrix_dti.txt $BMAX_VAL $num_high_b_vals "$@" ) 
    res_code=$?
    if [[ $res_code != 0 ]];then        
        if [[ $res_code == 2 ]];then            
            return 0
        fi        
        >&2 echo "ERROR: dti_recon failed. Previous messages may contain a clue. Unable to proceed."
        return 1
    fi
               
    return 0

}

export f_diffusion_recon



# dwifiles=os.listdir(args.diffusionpath)
#     for f in dwifiles:
#         if f.endswith('bvec'):
#             bvec_fname=f"{args.diffusionpath}/{f}"
#             break  #Get the first one I can find, we are only processing the first scan of this session
#         if f=='bvecs':
#             bvec_fname=f"{args.diffusionpath}/{f}"
#             break

#  dti_recon $TARGET/reg2brain.data.nii.gz $TARGET/DTI_Reg2Brain -gm $TARGET.gradientmatrix.txt $BMAX $BNOT -p 3 -sn 1 -ot nii


# python $CRUSH_PATH/crush.py -samples $SUBJECTS_DIR -patient sub-$patientID -recrush -fixmissing #-gradienttable ~/projects/def-dmattie/crush/plugins/levman/hcp_gradient_table_from_data_dictionary_3T.csv
# pwd

# if [ -f "$SUBJECTS_DIR/sub-$patientID/ses-$sessionID/Tractography/crush/tracts.txt" ]; then
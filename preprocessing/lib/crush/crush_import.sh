#!/bin/bash
source "${SCRIPTPATH}/lib/crush/hardi_mat.sh"
source "${SCRIPTPATH}/lib/crush/creategradientmatrix.sh"
source "${SCRIPTPATH}/lib/crush/diffusion_recon.sh"
source "${SCRIPTPATH}/lib/crush/f_flirt.sh"

export f_hardi_mat
export f_creategradientmatrix
export f_dti_recon
export f_diffusion_recon
export f_flirt
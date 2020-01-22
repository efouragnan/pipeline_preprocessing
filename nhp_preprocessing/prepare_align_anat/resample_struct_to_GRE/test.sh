set -e # stop on error 

struct=/Users/rushworth/seqodr_data/mri_data/pugsley/02_12_2015/align_anatomy/R.nii
gre=/Users/rushworth/seqodr_data/mri_data/pugsley/02_12_2015/align_anatomy/G.nii

aligndir=/Users/rushworth/seqodr_data/

funcdir=/Users/rushworth/dropbox/Work/seqodr/preprocessing/mri_recon/resample_struct_to_GRE

matlab -nodisplay - r addpath('$funcdir') "prepare_resample_struct('$struct','$gre','$aligndir'); exit"

#matlab -nodisplay -n -r "prepare_resample_struct('$struct','$gre','$aligndir'); exit"

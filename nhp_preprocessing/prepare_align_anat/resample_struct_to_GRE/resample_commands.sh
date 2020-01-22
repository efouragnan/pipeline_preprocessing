set -e # stop on error 

struct=/Users/rushworth/seqodr_data/mri_data/pugsley/02_12_2015/align_anatomy/R
gre=/Users/rushworth/seqodr_data/mri_data/pugsley/02_12_2015/align_anatomy/G

aligndir=/Users/rushworth/dropbox/Work/seqodr/preprocessing/mri_recon/resample_struct_to_GRE

funcdir=/Users/rushworth/dropbox/Work/seqodr/preprocessing/mri_recon/resample_struct_to_GRE

matlab -nodisplay -r "addpath('$funcdir'); prepare_resample_struct('$struct.nii','$gre.nii','$aligndir'); exit"

export JIP_HOME=/usr/local/share/jip-source 

$JIP_HOME/bin/jip resample.com $struct.nii $struct_gre_space.nii


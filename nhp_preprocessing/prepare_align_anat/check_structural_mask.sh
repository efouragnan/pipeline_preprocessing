set -e # stop on error 

# ///////////////////////////////////////////////////////////////////////////////////////////////////////
# -------------------------------------------------------------------------------------------------------

# path to main study/data directory 
study_dir=/Users/rushworth/seqodr_data/mri_data

# subject
subj="animal"

# session folder IDs (separated by spaces)
sessions_to_do="MI01001 MI01002"

# Hauke's toolbox works with uncompressed nifti images only
FSLOUTPUTTYPE=NIFTI

# -------------------------------------------------------------------------------------------------------
# LOOP OVER SESSIONS

for session in $sessions_to_do ; do

    # set align_anatomy directory
    anat_path="$study_dir/$subj/$session/align_anatomy/"

    echo; echo "...RUNNING SESSION: $session"

    fslview "$anat_path/struct_gre_space" "$align_anat/ref_brain_mask" -l Yellow -t 0.3

done

echo; echo "~~~DONE!" ; echo


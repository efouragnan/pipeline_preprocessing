set -e # stop on error 

# ///////////////////////////////////////////////////////////////////////////////////////////////////////

<<COMMENT 
 --------------------- SUBJECT AND SESSION SPECIFIC SETUP: CHANGE SETTINGS ACCORDINGLY
COMMENT

# subject (only 1 per run)
subj="animal"

# session folder IDs (separated by spaces)
sessions_to_do="MI01001 MI01002 MI01003"

# path to main study/data directory 
study_dir=/Users/rushworth/seqodr_data/mri_data

# Hauke's toolbox works with uncompressed nifti images only
FSLOUTPUTTYPE=NIFTI

# -------------------------------------------------------------------------------------------------------

# loop over session
for session in $sessions_to_do; do

    # SESSION-SPECIFIC SETUP
    echo; echo "...INSPECTING TARGET VOLUME AND BRAIN MASK FOR SESSION: $session"
    echo; echo ">> close FSLview to continue to next session"
    # set EPI paths
    target_volume=$study_dir/$subj/$session/f_t.nii
    brain_mask=$study_dir/$subj/$session/f_t_brain_mask.nii
    epi_dir=$(find $study_dir/$subj/$session/* -maxdepth 0 -d -name ep2d*)
    epi="$epi_dir/f.nii"

    fslview $epi $target_volume $brain_mask 

done


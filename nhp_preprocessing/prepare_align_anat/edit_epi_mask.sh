set -e # stop on error 

# ///////////////////////////////////////////////////////////////////////////////////////////////////////
# -------------------------------------------------------------------------------------------------------

# path to main study/data directory 
study_dir=/Users/rushworth/seqodr_data/mri_data

# subject
subj="animal"

# session folder IDs (separated by spaces)
sessions_to_do="MI01001 MIO1002 MI01003"

# Hauke's toolbox works with uncompressed nifti images only
FSLOUTPUTTYPE=NIFTI

# -------------------------------------------------------------------------------------------------------
# LOOP OVER SESSIONS

for session in $sessions_to_do ; do

    # set EPI directory 
    epi_dir=$(find $study_dir/$subj/$session/* -maxdepth 0 -d -name ep2d*)
    epi_mask_dir=$epi_dir/brain_mask

    echo; echo "...RUNNING SESSION: $session"

    fslview $epi_mask_dir/fm_whole $epi_mask_dir/fm_brain_mask -l Green -t 0.3

    echo; echo "...Mask mean EPI using brain mask? >> Y - yes and continue / N - no and continue / Q - exit script"

    while [ "$resp" != "y" ] && [ "$resp" != "n" ] && [ "$resp" != "q" ] ; do read -n1 resp; done

    if [ "$resp" == "y" ]; then
        # mask fm_whole using fm_brain_mask
        echo; echo "...Masking fm_whole (fm.nii)"
        fslmaths $epi_mask_dir/fm_whole -mas $epi_mask_dir/fm_brain_mask $epi_dir/fm
    elif [ "$resp" == "n" ]; then
        echo; echo "...NOT masking fm_whole - moving to next session..."
    elif [ "$resp" == "q" ]; then
        echo; echo "...Exiting script!"
        exit
    fi

    # clear resp variable
    unset resp
       
done

echo; echo "~~~DONE!" ; echo

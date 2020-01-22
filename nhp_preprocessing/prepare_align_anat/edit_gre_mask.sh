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

# retrieve directory of this script
script_dir="$(cd "$( dirname ${BASH_SOURCE[0]} )" && pwd)"

# directory of create_overlay MATLAB script
create_overlay_dir="$script_dir/create_overlay"

# -------------------------------------------------------------------------------------------------------
# LOOP OVER SESSIONS

for session in $sessions_to_do ; do

    # set GRE directory 
    gre_dir=$(find $study_dir/$subj/$session/* -maxdepth 0 -d -name gre*)
    gre_mask_dir=$gre_dir

    # set align_anatomy directory
    anat_path="$study_dir/$subj/$session/align_anatomy/"

    echo; echo "...RUNNING SESSION: $session"

    fslview "$gre_mask_dir/fg" "$gre_mask_dir/fg_brain_mask" -l Green -t 0.3

    echo; echo "...Create GRE mask overlay? >> Y - yes and continue / N - no and continue / Q - exit script"

    while [ "$resp" != "y" ] && [ "$resp" != "n" ] && [ "$resp" != "q" ] ; do read -n1 resp; done

    if [ "$resp" == "y" ]; then

        echo; echo "...Creating GRE mask overlay based on fg_brain_mask"

        nii_input="$gre_dir/fg_brain_mask.nii"
        ovl_output="$anat_path/overlay_gre.ovl"

        # run MATLAB script
        matlab -nodisplay -r "addpath('$create_overlay_dir'); create_overlay('$nii_input','$ovl_output'); exit"

    elif [ "$resp" == "n" ]; then
        echo; echo "...NOT creating GRE mask overlay - moving to next session..."
    elif [ "$resp" == "q" ]; then
        echo; echo "...Exiting script!"
        exit
    fi

    # clear resp variable
    unset resp

done

echo; echo "~~~DONE!" ; echo


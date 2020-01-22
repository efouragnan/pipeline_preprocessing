set -e # stop on error 

# ///////////////////////////////////////////////////////////////////////////////////////////////////////

<<COMMENT 
 --------------------- SUBJECT AND SESSION SPECIFIC SETUP: CHANGE SETTINGS ACCORDINGLY
COMMENT

# subject (only 1 per run)
subj="animal"

# session folder IDs (separated by spaces)
sessions_to_do="MI01001 MI01002"

# volume number, separated by spaces, one volume per session (use FSL indexing -- starts at 0, not 1)
target_volumes="541"

# MRCAT directory 
mrcat_dir=/Users/rushworth/dropbox/Work/seqodr/preprocessing/MrCat-dev

# path to main study/data directory 
study_dir=/Users/rushworth/seqodr_data/mri_data

# ///////////////////////////////////////////////////////////////////////////////////////////////////////
# -------------------------------------------------------------------------------------------------------
# GENERAL SETUP

# Hauke's toolbox works with uncompressed nifti images only
FSLOUTPUTTYPE=NIFTI

# retrieve directory of this script
script_dir="$(cd "$( dirname ${BASH_SOURCE[0]} )" && pwd)"

# directory of create_overlay MATLAB script
create_overlay_dir="$script_dir/create_overlay"

# convert to arrays
target_volumes=($target_volumes)
sessions_to_do=($sessions_to_do)

# check if sessions target volumes match
if [ ${#sessions_to_do[@]} != ${#target_volumes[@]} ] ; then
    echo; echo ">> Number of sessions (${#sessions_to_do[@]}) does not match number of target volumes (${#target_volumes[@]})! Exiting..."
    exit
fi

# set counter for target volumes
j=0

# -------------------------------------------------------------------------------------------------------

# loop over session
for session in $sessions_to_do; do

    # SESSION-SPECIFIC SETUP
    echo; echo "...RUNNING SESSION: $session"

    # set EPI paths
    epi_dir=$(find $study_dir/$subj/$session/* -maxdepth 0 -d -name ep2d*)
    epi="$epi_dir/f.nii"

    # output directory for target volume
    out_dir=$study_dir/$subj/$session

# -------------------------------------------------------------------------------------------------------
<<COMMENT

GET TARGET EPI VOLUME

- calculates mean of EPI
- subtracts mean EPI from each volume to obtain deviation
- squares deviation to get variance
- calculates mean variance for each volume
- creates var.txt with variance of each volume and a volume index number
- sorts list of volumes by variance from low->high and outputs index of lowest variance volume (target volume)
- creates target target volume as f_t.nii

COMMENT

    volume=${target_volumes[j]}
    echo; echo "...Using volume fsl ($volume) for session ($session)"

    filename="MANUAL_TARGETVOLUME_fsl_$(($volume+0))_jip_$(($volume+1))"
    echo; echo "...Target volume index written to file: $filename"
    echo > $out_dir/$filename 

    # create target volume file
    echo; echo "...Creating target volume"
    fslroi $epi_dir/f.nii $out_dir/f_t.nii $volume 1;

# -------------------------------------------------------------------------------------------------------
<<COMMENT

CREATE BRAIN MASK

- if previous brain mask exists, makes a backup copy: f_t_brain_mask-backup-#.nii
- uses bet_macaque.sh to brain extract the target volume (f_t) to create f_t_brain and f_t_brain_mask
- dilates f_t_brain_mask by 7 voxels to fully encompass entire brain

COMMENT

    # check if brain mask exists; if yes, back it up
    if [ -f "$out_dir/f_t_brain_mask.nii" ] ; then 
        i=0
        # if backup already exists, increment backup number and save another backup
        while [ -f "$out_dir/f_t_brain_mask-backup-$i.nii" ] ; do
            i=$(($i+1))
        done

        echo; echo "...Brain mask exists: making a backup copy named f_t_brain_mask-backup-$i.nii"
        cp $out_dir/f_t_brain_mask.nii $out_dir/f_t_brain_mask-backup-$i.nii
    fi

    echo; echo "...Making brain mask"; echo;
    sh $mrcat_dir/in_vivo/bet_macaque.sh $out_dir/f_t.nii $out_dir/f_t -t T2star -d -s "bet"
    fslmaths $out_dir/f_t_brain_mask -kernel box 7 -dilM $out_dir/f_t_brain_mask

# -------------------------------------------------------------------------------------------------------
<<COMMENT
CREATE OVERLAY - runs MATLAB function to create an overlay based on f_t_brain_mask
COMMENT

    echo; echo "...Making overlay based on f_t_brain_mask"

    nii_input="$out_dir/f_t_brain_mask.nii"
    ovl_output="$out_dir/overlay.dat"

    # run MATLAB script
    matlab -nodisplay -r "addpath('$create_overlay_dir'); create_overlay('$nii_input','$ovl_output'); exit"

    echo; echo "...DONE!" ; echo

# increment counter
j=$(($j+1))

done


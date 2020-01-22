set -e # stop on error 

# ///////////////////////////////////////////////////////////////////////////////////////////////////////
# -------------------------------------------------------------------------------------------------------
# SUBJECT / SESSION SETUP

# path to main study/data directory 
study_dir=/Users/rushworth/seqodr_data/mri_data

# subject (only 1 per run)
subj="animal"

# session folder IDs (separated by spaces)
sessions_to_do="MI01001 MI01002 MI01003"

# IMPORTANT: flip orientations and correct labels? should only be done * ONCE * for a given session
flip_orient=1

# MRCAT directory 
mrcat_dir=/Users/rushworth/dropbox/Work/seqodr/preprocessing/MrCat-dev

# ///////////////////////////////////////////////////////////////////////////////////////////////////////
# -------------------------------------------------------------------------------------------------------
# MISC SETUP

# Hauke's toolbox works with uncompressed nifti images only
FSLOUTPUTTYPE=NIFTI

# retrieve directory of this script
script_dir="$(cd "$( dirname ${BASH_SOURCE[0]} )" && pwd)"

# directory of create_overlay MATLAB script
create_overlay_dir="$script_dir/create_overlay"

# -------------------------------------------------------------------------------------------------------
# LOOP OVER SESSIONS
for session in $sessions_to_do ; do

    # SESSION-SPECIFIC SETUP
    echo; echo "RUNNING SESSION: $session"

    # set EPI paths
    epi_dir=$(find $study_dir/$subj/$session/* -maxdepth 0 -d -name ep2d*)
    epi="$epi_dir/f.nii"

    # output directory for variance calculations
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

    echo; echo "   ...Creating target volume image"

    echo; echo "   ...Calculating variance for each volume"
    fslmaths $epi -Tmean $epi_dir/mean_f
    fslmaths $epi -sub $epi_dir/mean_f $epi_dir/temp
    fslmaths $epi_dir/temp -mul $epi_dir/temp $epi_dir/temp

    echo; echo "   ...Finding volume with least variance"
    # calculating mean variance for each volume
    fslmeants -i $epi_dir/temp -o $epi_dir/var.txt

    # add column indexing the volumes
    awk -F, '{$(NF+1)=++i-1;}1' $epi_dir/var.txt > $epi_dir/var2.txt && mv $epi_dir/var2.txt $epi_dir/var.txt

    # sort columns based variance from low->high, output index of lowest variance volume
    volume=$(sort -n -k 1,1 $epi_dir/var.txt | sed -n '1p' | cut -d' ' -f2-)
    filename="TARGETVOLUME_fsl_$(($volume+0))_jip_$(($volume+1))"
    echo "" > $out_dir/$filename 
    echo; echo "   ...Target volume index written to file: $filename"

    # create target volume file
    echo; echo "   ...Creating target volume"
    fslroi $epi_dir/f.nii $out_dir/f_t.nii $volume 1;

    # clean up files
    rm $epi_dir/temp.nii
    rm $epi_dir/mean_f.nii

# -------------------------------------------------------------------------------------------------------
<<COMMENT

CORRECT ORIENTATION

- images are oriented and labelled incorrectly from Hauke's toolboxes - this corrects them.
- corrects all .nii files in the session folder 
- SHOULD ONLY BE DONE ONCE OR ELSE IT WILL BE ORIENTED/LABELLED INCORRECTLY AGAIN!

COMMENT

    if [ "$flip_orient" == 1 ]; then
        echo; echo "   ...Correcting orientation for all images in the whole session (except BACKUPS)"
        find $out_dir -maxdepth 2 -type f \( ! -name "*-backup-*.nii" -a -name "*.nii" \) | while read input; do
            fslorient -deleteorient $input
            fslswapdim $input x -y z $input
            fslorient -setqformcode 1 $input
            echo "${input} corrected"
        done
    else
        echo; echo "   ...NOT correcting orientation for any image"
    fi

# -------------------------------------------------------------------------------------------------------
<<COMMENT

CREATE BRAIN MASK

- if previous brain mask exists, makes a backup copy: f_t_brain_mask-backup-#.nii
- uses bet_macaque.sh to brain extract the target volume (f_t) to create f_t_brain and f_t_brain_mask
- dilates f_t_brain_mask by 7 voxels to fully encompass entire brain

COMMENT

    # check if brain mask exists
    if [ -f "$out_dir/f_t_brain_mask.nii" ] ; then 
        i=0
        while [ -f "$out_dir/f_t_brain_mask-backup-$i.nii" ] ; do
            i=$(($i+1))
        done
    
        echo; echo "   ...Brain mask exists: making a backup copy named f_t_brain_mask-backup-$i.nii"
        cp $out_dir/f_t_brain_mask.nii $out_dir/f_t_brain_mask-backup-$i.nii
    fi

    echo; echo "   ...Making brain mask"
    sh $mrcat_dir/in_vivo/bet_macaque.sh $out_dir/f_t.nii $out_dir/f_t -t T2star -s "bet"
    fslmaths $out_dir/f_t_brain_mask -kernel box 7 -dilM $out_dir/f_t_brain_mask

# -------------------------------------------------------------------------------------------------------
<<COMMENT
CREATE OVERLAY - runs MATLAB function to create an overlay based on f_t_brain_mask
COMMENT

    echo; echo "   ...Making overlay based on f_t_brain_mask"

    nii_input="$out_dir/f_t_brain_mask.nii"
    ovl_output="$out_dir/overlay.dat"

    # run MATLAB script
    matlab -nodisplay -r "addpath('$create_overlay_dir'); create_overlay('$nii_input','$ovl_output'); exit"

    
done

echo; echo "   ...DONE!" ; echo

set -e # stop on error 

# -------------------------------------------------------------------------------------------------------

# STEPS TO RUN:

    create_epi_mask=1 # run EPI mask steps at all?
    borrow_epi_mask=1 # 1 = yes (for all sessions), 0 = no (make a new mask for all sessions) 

    create_gre_mask=1 # run GRE mask steps at all?
    borrow_gre_mask=1 # 1 = yes (for all sessions), 0 = no (make a new mask for all sessions) 
    create_gre_overlay=1 # 1 = yes, 0 = no

    create_structural_mask=1 # 1 = yes, 0 = no
    create_structural_overlay=1 # 1 = yes, 0 = no

# SETTINGS:

    # path to main study/data directory 
    study_dir="/Users/rushworth/seqodr_data/mri_data"

    # subject
    subj="animal"

    # session folder IDs (separated by spaces)
    sessions_to_do="MI01002 MI01003"

    # paths to structural (excluding .nii extension!)
    anat_full="$study_dir/$subj/structural/structural_restore"
    anat_crop="$study_dir/$subj/structural/structural_restore_brain"

    # MRCAT directory 
    mrcat_dir="/Users/rushworth/dropbox/Work/seqodr/preprocessing/MrCat-dev"

    # JIP directory
    jip_dir="/usr/local/share/jip-source"

    # degrees of freedom for FLIRT (default is 6) if borrowing GRE mask
    borrow_gre_dof=6

    # degrees of freedom for FLIRT (default is 6) if borrowing EPI mask
    borrow_epi_dof=6

    # session name from which to borrow GRE/GRE mask 
    borrow_gre_session="MI01001"

    # session name from which to borrow EPI mask
    borrow_epi_session="MI01001"

    # if session(s) listed in sessions_to_do is missing a GRE, mark it here (the entire GRE will be borrowed in addition to the mask)
    missing_gre_session=""

# -------------------------------------------------------------------------------------------------------
# GENERAL SETUP

    # Hauke's toolbox works with uncompressed nifti images only
    FSLOUTPUTTYPE=NIFTI

    # retrieve directory of this script
    script_dir="$(cd "$( dirname ${BASH_SOURCE[0]} )" && pwd)"

    # export JIP dir
    export JIP_HOME=$jip_dir

    # directory of create_overlay MATLAB script
    create_overlay_dir="$script_dir/create_overlay"

    # tracks if current session is listed in missing GRE list
    is_missing_gre=0

# -------------------------------------------------------------------------------------------------------
# LOOP OVER SESSIONS

for session in $sessions_to_do ; do

    echo; echo "RUNNING SESSION: $session"

    # path to structural dir 
    struct_dir=$(find $study_dir/$subj/* -maxdepth 0 -d -name structural)

    # path to GRE dir
    gre_dir=$(find $study_dir/$subj/$session/* -maxdepth 0 -d -name "gre*")
    
    # set EPI directory 
    epi_dir=$(find $study_dir/$subj/$session/* -maxdepth 0 -d -name "ep2d*")

    # create align_anatomy folder for further processing and Hauke's scripts
    anat_path="$study_dir/$subj/$session/align_anatomy/"
    [[ ! -d "$anat_path" ]] && mkdir $anat_path

    # copy over full hi-res structural into anat folder as brain.nii for Hauke's toolbox
    cp $anat_full.nii $anat_path/brain.nii

    # check if degrees of freedom is set (for borrowed mask registration); if not, default to 6
    borrow_gre_dof="${borrow_gre_dof:-"6"}"
    borrow_epi_dof="${borrow_epi_dof:-"6"}"

# -------------------------------------------------------------------------------------------------------

<<COMMENT

CREATE MEAN EPI MASK:

Borrows EPI mask from previous session
(OR: runs bet_macaque.sh from MRCAT on mean EPI image)

Output: 

EPI_DIR/brain_mask/fm_whole.nii
EPI_DIR/brain_mask/fm_brain_mask.nii

COMMENT

    if [ "$create_epi_mask" == "1" ] ; then

        echo; echo "CREATING EPI MASK"

        # check/create directory to store EPI mask files
        epi_mask_dir=$epi_dir/brain_mask

        if [ ! -d "$epi_mask_dir" ] ; then
            mkdir $epi_mask_dir 
            echo; echo "   ...Creating folder 'brain_mask' in session EPI directory"
        fi

        # check if brain mask exists
        if [ -f "$epi_mask_dir/fm_brain_mask.nii" ] ; then 
            i=0
            while [ -f "$epi_mask_dir/fm_brain_mask-backup-$i.nii" ] ; do
                i=$(($i+1))
            done
        
            echo; echo "   ...Mean EPI brain mask exists: making a backup copy named fm_brain_mask-backup-$i.nii"
            cp $epi_mask_dir/fm_brain_mask.nii $epi_mask_dir/fm_brain_mask-backup-$i.nii
        fi

        # make copy of fm.nii as fm_whole.nii (fm.nii will be masked later)
        echo; echo "   ...Creating copy of mean EPI (fm_whole.nii)"
        cp $epi_dir/fm.nii $epi_mask_dir/fm_whole.nii

        if [ "$borrow_epi_mask" == "1" ] ; then

            # borrow EPI mask 
            echo; echo "   ...Borrowing EPI mask from session $borrow_epi_session (fm_brain_mask.nii)"

            # full path to borrowed EPI 
            borrow_epi_dir=$(find $study_dir/$subj/$borrow_epi_session/* -maxdepth 0 -d -name "ep*")

            # use FLIRT to register borrowed mean EPI to current mean EPI to get transformation matrix
            echo; echo "   ...Registering borrowed EPI to current EPI"
            flirt -in $borrow_epi_dir/brain_mask/fm_whole -ref $epi_mask_dir/fm_whole -omat $epi_mask_dir/epi_xfm.mat -dof $borrow_epi_dof

            # apply transformation matrix to borrowed EPI mask to create EPI mask for current session
            echo; echo "   ...Applying transformation to borrowed EPI mask"
            flirt -in $borrow_epi_dir/brain_mask/fm_brain_mask -ref $epi_mask_dir/fm_whole -applyxfm -init $epi_mask_dir/epi_xfm.mat -out $epi_mask_dir/fm_brain_mask

            # crop mask around
            fslmaths $epi_mask_dir/fm_brain_mask -thr 0.5 -bin $epi_mask_dir/fm_brain_mask

        else
           # run BET macaque on mean EPI
            echo; echo "   ...Running bet_macaque on mean EPI to create mask (fm_brain_mask.nii)"
            echo;
            sh $mrcat_dir/in_vivo/bet_macaque.sh $epi_mask_dir/fm_whole $epi_mask_dir/fm -t T2star -m
        fi

    fi
# -------------------------------------------------------------------------------------------------------

<<COMMENT

CREATE/BORROW GRE MASK OR BORROW ENTIRE GRE IMAGE FROM PREVIOUS SESSION:

- Checks if current session is listed in missing_gre_session
- If yes: borrows entire GRE and GRE mask from borrow_gre_session
- If no: creates new GRE mask or borrows mask from borrow_gre_session

COMMENT

    # check if missing any GRE; if no, default to "none" and skip
    missing_gre_session="${missing_gre_session:-"none"}"
    
    if [ "$create_gre_mask" == "1" ]; then

        echo; echo "CREATING GRE MASK"

        # check if brain mask exists
        if [ -f "$gre_dir/fg_brain_mask.nii" ] ; then 
            i=0
            while [ -f "$gre_dir/fg_brain_mask-backup-$i.nii" ] ; do
                i=$(($i+1))
            done
        
            echo; echo "   ...GRE brain mask exists: making a backup copy named fg_brain_mask-backup-$i.nii"
            cp $gre_dir/fg_brain_mask.nii $gre_dir/fg_brain_mask-backup-$i.nii
        fi

        # check if current session is listed as missing a GRE
        for i in $missing_gre_session ; do
            if [ "$session" == "$i" ]; then
                is_missing_gre=1
                break
            fi
        done

        if [ "$is_missing_gre" == "0" ] ; then

            if [ "$borrow_gre_mask" == "1" ] ; then

                echo; echo "   ...BORROWING GRE MASK FROM PREVIOUS SESSION $borrow_gre_session"

                # use FLIRT to register borrowed mean EPI to current mean EPI to get transformation matrix
                echo; echo "   ...Registering borrowed EPI to current EPI"
                
                borrow_gre_epi_dir=$(find $study_dir/$subj/$borrow_gre_session/* -maxdepth 0 -d -name "ep*")
                
                # check if mean EPI vol for current session exists
                [[ ! -f "$epi_dir/brain_mask/fm_whole.nii" ]] && echo && echo "...fm_whole doesn't exist! Exiting..." && exit;

                flirt -in $borrow_gre_epi_dir/brain_mask/fm_whole -ref $epi_dir/brain_mask/fm_whole -omat $gre_dir/gre_xfm.mat -dof $borrow_gre_dof
                borrow_gre_dir=$(find $study_dir/$subj/$borrow_gre_session/* -maxdepth 0 -d -name "gre*")
                
                # apply transformation matrix to borrowed GRE mask to create GRE mask for current session
                echo; echo "   ...Applying transformation to borrowed GRE mask"
                flirt -in $borrow_gre_dir/fg_brain_mask -ref $borrow_gre_dir/'fg' -applyxfm -init $gre_dir/gre_xfm.mat -out $gre_dir/fg_brain_mask

                # crop mask around
                fslmaths $gre_dir/fg_brain_mask -thr 0.5 -bin $gre_dir/fg_brain_mask

                echo; echo "   *** Make sure to check registration quality of borrowed GRE mask *** "

            else
                echo; echo "CREATING NEW GRE MASK (~20 min)"
                sh preproc_fieldmap.sh --sessiondir=$study_dir/$subj/$session --fieldmapdir=$gre_dir --structdir=$struct_dir --mrcatdir=$mrcat_dir
            fi

        else

            # reset tracker
            is_missing_gre=0

            echo; echo " ...BORROWING ENTIRE GRE (and GRE mask) FROM PREVIOUS SESSION $borrow_gre_session"

            # create GRE folder in current session
            echo; echo "   ...Creating GRE folder in current session (gre_99999)"

            gre_dir=$study_dir/$subj/$session/gre_99999
            [[ ! -d "$gre_dir" ]] && mkdir $gre_dir

            # use FLIRT to register borrowed mean EPI to current mean EPI to get transformation matrix
            echo; echo "   ...Registering borrowed EPI to current EPI"

            borrow_epi_dir=$(find $study_dir/$subj/$borrow_gre_session/* -maxdepth 0 -d -name "ep*")

            # check if mean EPI vol for current session exists
            [[ ! -f "$epi_dir/brain_mask/fm_whole.nii" ]] && echo && echo "...fm_whole doesn't exist! Exiting..." && exit;

            flirt -in $borrow_epi_dir/brain_mask/fm_whole -ref $epi_dir/brain_mask/fm_whole -omat $gre_dir/gre_xfm.mat -dof $borrow_gre_dof

            # apply transformation matrix to borrowed GRE to create GRE for current session
            echo; echo "   ...Applying transformation to borrowed GRE"
            borrow_gre_dir=$(find $study_dir/$subj/$borrow_gre_session/* -maxdepth 0 -d -name "gre*")
            
            flirt -in $borrow_gre_dir/'fg' -ref $borrow_gre_dir/'fg' -applyxfm -init $gre_dir/gre_xfm.mat -out $gre_dir/'fg'

            # apply transformation matrix to borrowed GRE mask to create GRE mask for current session
            echo; echo "   ...Applying transformation to borrowed GRE mask"
            flirt -in $borrow_gre_dir/fg_brain_mask -ref $borrow_gre_dir/'fg' -applyxfm -init $gre_dir/gre_xfm.mat -out $gre_dir/fg_brain_mask

            # crop mask around
            fslmaths $gre_dir/fg_brain_mask -thr 0.5 -bin $gre_dir/fg_brain_mask

            echo; echo "   *** Make sure to check registration quality of borrowed GRE and GRE mask *** "

        fi
    fi

# -------------------------------------------------------------------------------------------------------

<<COMMENT

CREATE STRUCTURAL MASK (IN GRE SPACE):

(1) runs MATLAB script (adapted from Hauke's toolbox) to determine appropriate dimensions for 
resampling high-res structural to GRE space. This creates resample_params.com file with 
correct dimensions to use (adapted from Hauke's toolbox).

(2) runs JIP to do the resampling, using the resample_params.com file created, 
outputs struct_gre_space.nii file in align_anatomy dir

(3) creates structural mask in GRE space by (a) registering hi-res structural to low-res resampled image, 
(b) creating high-res structural mask using high-res brain image, (c) applying transformation matrix to high-res mask
to create low-res structural mask in GRE space 

COMMENT
    
    if [ "$create_structural_mask" == "1" ]; then

        echo; echo "CREATING STRUCTURAL BRAIN MASK IN GRE SPACE (ref_brain_mask.nii)"

        # dir where you want resample_params.com to be saved (defult: align_anatomy dir)
        resample_dir=$anat_path

        # GRE image
        gre=$gre_dir/'fg'

        # dir where the resampling matlab scripts are located
        resample_script_dir=$script_dir/resample_struct_to_GRE

        # parameter file (to be created using Matlab function call)
        resample_params=$resample_script_dir/resample_params.com

        # name of resampled output image
        resample_output='struct_gre_space'

        # run MATLAB script
        echo; echo "   ...Running MATLAB script to get resample parameters"
        matlab -nodisplay -r "addpath('$resample_script_dir'); prepare_resample_struct('$anat_full.nii','$gre.nii','$resample_script_dir'); exit"

        # check if resampled struct exists
        if [ -f "$anat_path/$resample_output.nii" ] ; then 
            i=0
            while [ -f "$anat_path/$resample_output-backup-$i.nii" ] ; do
                i=$(($i+1))
            done
        
            echo; echo "   ...Resampled structural exists: making a backup copy named $resample_output-backup-$i.nii"
            cp $anat_path/$resample_output.nii $anat_path/$resample_output-backup-$i.nii
            rm $anat_path/$resample_output.nii
        fi

        # run JIP using resample.com script which takes as input: (1) parameter file (created above) (2) full high-res structural (3) path/name of output image
        # running JIP in background or else it will exit the shell script entirely...
        
        echo; echo "   ...Running JIP to do resampling"
        $JIP_HOME/bin/jip $resample_script_dir/resample.com $resample_params $anat_full.nii $anat_path/$resample_output.nii &
        
        # wait until JIP finishes running in background and outputs nifti file
        while [ ! -f $anat_path/$resample_output.nii ] ; do sleep 2; done
        sleep 2;

        echo; echo ""; echo "   ...Making the mask"
        # registers hi-res structural to resampled structural
        flirt -in $anat_full -ref $anat_path/$resample_output -omat $anat_path/ref_brain_mat.mat -out $anat_path/ref_brain_full -dof 6

        # binarise hi-res brain to create mask
        fslmaths $anat_crop -bin $anat_path/ref_brain_mask

        # apply transformation matrix to mask to create low-res mask in GRE-space 
        flirt -in $anat_path/ref_brain_mask -ref $anat_path/$resample_output -applyxfm -init $anat_path/ref_brain_mat.mat -out $anat_path/ref_brain_mask
        fslmaths $anat_path/ref_brain_mask -thr 0.3 -bin $anat_path/ref_brain_mask
        rm $anat_path/ref_brain_full.nii
    fi

# -------------------------------------------------------------------------------------------------------

<<COMMENT
CREATE STRUCTURAL OVERLAY - runs MATLAB function to create an overlay based on structural mask
COMMENT

    if [ "$create_structural_overlay" == "1" ]; then

        echo; echo "MAKING OVERLAY BASED ON ref_brain_mask.nii"

        nii_input="$anat_path/ref_brain_mask.nii"
        ovl_output="$anat_path/overlay_ref.ovl"

        # run MATLAB script
        matlab -nodisplay -r "addpath('$create_overlay_dir'); create_overlay('$nii_input','$ovl_output'); exit"

    fi

# -------------------------------------------------------------------------------------------------------

<<COMMENT
CREATE GRE OVERLAY - runs MATLAB function to create an overlay based on structural mask
COMMENT

    if [ "$create_gre_overlay" == "1" ]; then

        echo; echo "MAKING OVERLAY BASED ON fg_brain_mask"

        nii_input="$gre_dir/fg_brain_mask.nii"
        ovl_output="$anat_path/overlay_gre.ovl"

        # run MATLAB script
        matlab -nodisplay -r "addpath('$create_overlay_dir'); create_overlay('$nii_input','$ovl_output'); exit"

    fi

    echo; echo "~~~DONE!" ; echo

done

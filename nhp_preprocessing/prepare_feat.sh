set -e # stop on error 

# ///////////////////////////////////////////////////////////////////////////////////////////////////////
# -------------------------------------------------------------------------------------------------------

# path to main study/data directory 
study_dir=/Users/rushworth/seqodr_data/mri_data

# subject
subj="pringle"

# session folder IDs (separated by spaces)
#sessions_to_do="2015_11_25 2015_11_26 2015_11_27 2015_11_30 2015_12_02 2015_12_03 2015_12_04 2015_12_07 2015_12_08 2015_12_09 2015_12_10 2015_12_15"
sessions_to_do="2015_11_26 2015_11_27 2015_11_30 2015_12_01 2015_12_02 2015_12_04 2015_12_07 2015_12_08 2015_12_10 2015_12_11 2015_12_14 2015_12_15"

# Hauke's toolbox works with uncompressed nifti images only
FSLOUTPUTTYPE=NIFTI

anat="$study_dir/$subj/structural/structural_restore_brain.nii"

for session in $sessions_to_do ; do

	echo; echo "RUNNING SESSION: $session"

	proc_dir=$study_dir/$subj/$session/proc
	
	[[ ! -d  $proc_dir ]] && mkdir $proc_dir

	 # set EPI directory 
    epi_dir=$(find $study_dir/$subj/$session/* -maxdepth 0 -d -name "ep2d*")

	# brain mask for structural in gre space 
	ref_brain_mask=$study_dir/$subj/$session/align_anatomy/ref_brain_mask.nii

	# structural in gre space
	struct_gre_space=$study_dir/$subj/$session/align_anatomy/struct_gre_space.nii

	# aligned and registered EPI
	far=$epi_dir/far.nii
	
	# dilate brain mask
	echo; echo "...creating dilated low-res structural brain mask"
	fslmaths $ref_brain_mask -s 5 -thr 0.1 -bin $proc_dir/ref_brain_mask_loose

	# mask far.nii
	echo; echo "...masking far.nii"
	fslmaths $far -mul $proc_dir/ref_brain_mask_loose $proc_dir/far.nii

	# mask structural in gre space to create alternative reference image 
	echo; echo "...masking low-res structural"
	fslmaths $struct_gre_space -mul $ref_brain_mask $proc_dir/alt_ref.nii

	# copy high-res structural
	cp $anat $proc_dir

	# delete last 2 volumes 
	echo; echo "...cropping last 2 volumes"
	nvols=$(fslnvols $proc_dir/far)

	fslroi $proc_dir/far $proc_dir/far 0 $(($nvols-2))

	# change TR in header
	echo; echo "...updating header TR to 2.28"
	fslhd -x $proc_dir/far > $proc_dir/temphdr.txt
   	sed "s/dt =.*/dt = \'2.28\'/" $proc_dir/temphdr.txt > $proc_dir/temphdr2.txt
   	fslcreatehd $proc_dir/temphdr2.txt $proc_dir/far
   	rm $proc_dir/temphdr.txt $proc_dir/temphdr2.txt

	# gzip everything 
	gzip $proc_dir/*.nii

	
done
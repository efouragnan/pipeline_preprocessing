#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# please note that this script relies on the MrCat toolbox

# ensure code root exists
[[ -z $OXNEURODIR ]] && export OXNEURODIR=~/code/oxneuranalysis

# specify data
studyDir=$OXNEURODIR/nhp_preprocessing/play
[[ -d $studyDir ]] || studyDir=$(cd ..; pwd)
fieldmapDir=$studyDir/fieldmap
structDir=$studyDir/struct
transDir=$studyDir/transform
fieldmapImg="fg"


# bias correct and brain extract the gradient echo field map magnitude image
# --------------------------------------------------------
# create a "brain" mask that covers the whole image
rm -rf $fieldmapDir/brainmask
mkdir -p $fieldmapDir/brainmask
fslmaths $fieldmapDir/$fieldmapImg -mul 0 -add 1 $fieldmapDir/brainmask/${fieldmapImg}_all_mask

# smoothness definitions
sigma=3
FWHM=$(echo "2.3548 * $sigma" | bc)

# run RobustBiasCorr
rm -rf $fieldmapDir/biascorr
sh $MRCATDIR/HCP_scripts/RobustBiasCorr.sh \
  --in=$fieldmapDir/$fieldmapImg \
  --workingdir=$fieldmapDir/biascorr \
  --brainmask=$fieldmapDir/brainmask/${fieldmapImg}_all_mask \
  --basename=$fieldmapImg \
  --FWHM=$FWHM \
  --type=1 \
  --forcestrictbrainmask="FALSE" --ignorecsf="FALSE"

# rough brain mask based on bias corrected image
rm -rf $fieldmapDir/brainmask
mkdir -p $fieldmapDir/brainmask
imcp $fieldmapDir/biascorr/${fieldmapImg}_restore $fieldmapDir/brainmask/${fieldmapImg}_restore
sh $MRCATDIR/in_vivo/bet_macaque.sh $fieldmapDir/brainmask/${fieldmapImg}_restore -t T1 -f 0.3 -fFP 1 -fTP 0.5 -s 70


# refine based on rough brain mask
# --------------------------------
# run RobustBiasCorr with the rough brain mask
rm -rf $fieldmapDir/biascorr
sh $MRCATDIR/HCP_scripts/RobustBiasCorr.sh \
  --in=$fieldmapDir/$fieldmapImg \
  --workingdir=$fieldmapDir/biascorr \
  --brainmask=$fieldmapDir/brainmask/${fieldmapImg}_restore_brain_mask \
  --basename=$fieldmapImg \
  --FWHM=$FWHM \
  --type=1 \
  --forcestrictbrainmask="FALSE" --ignorecsf="FALSE"

# refine brain mask based on properly bias corrected image
rm -rf $fieldmapDir/brainmask
mkdir -p $fieldmapDir/brainmask
imcp $fieldmapDir/biascorr/${fieldmapImg}_restore $fieldmapDir/brainmask/${fieldmapImg}_restore
sh $MRCATDIR/in_vivo/bet_macaque.sh $fieldmapDir/brainmask/${fieldmapImg}_restore -f 0.45 -fFP 1 -fTP 0.5 -s 70

# run RobustBiasCorr with the refined brain mask
rm -rf $fieldmapDir/biascorr
sh $MRCATDIR/HCP_scripts/RobustBiasCorr.sh \
  --in=$fieldmapDir/$fieldmapImg \
  --workingdir=$fieldmapDir/biascorr \
  --brainmask=$fieldmapDir/brainmask/${fieldmapImg}_restore_brain_mask \
  --basename=$fieldmapImg \
  --FWHM=$FWHM \
  --type=1 \
  --forcestrictbrainmask="FALSE" --ignorecsf="FALSE"

# copy and rename refined brain mask and bias corrected image
imcp $fieldmapDir/brainmask/${fieldmapImg}_restore_brain_mask $fieldmapDir/${fieldmapImg}_brain_mask
imcp $fieldmapDir/biascorr/${fieldmapImg}_restore $fieldmapDir/${fieldmapImg}_restore

# remove intermediate working directories
rm -rf $fieldmapDir/biascorr
rm -rf $fieldmapDir/brainmask


# register with hi-res T1w structural
# -----------------------------------
# specify images and masks
structBase=structural
structImg=$structDir/${structBase}_restore
structMask=$structDir/${structBase}_brain_mask
structMaskStrict=${structBase}_brain_mask_strict
fieldmapBase=$fieldmapImg
fieldmapImg=$fieldmapDir/${fieldmapBase}_restore
fieldmapMask=$fieldmapDir/${fieldmapBase}_brain_mask

# make a transformation directory
mkdir -p $transDir

# switch what type of registration will be done, rigid, linear or non-linear
flgReg="non-linear" # rigid, linear, non-linear
case $flgReg in
  rigid)
    # rigid body registration to the structural
    echo "  rigid-body registration"
    flirt -dof 6 -ref $structImg -refweight $structMask -in $fieldmapImg -inweight $fieldmapMask -omat $transDir/${fieldmapBase}_to_${structBase}.mat
    ;;
  linear)
    # strangely enough, the rigid body doesn't seem to give a perfect fit,
    # with the structural brian mask being a bit too tight for the fieldmap
    # so I'm going to dilate the structural brain mask and use 12 dof registration
    echo "  12 dof linear registration"
    # dilate the structural brain mask
    fslmaths $structMask -s 0.5 -thr 0.1 -bin ${structMask}_dil
    # 12 degrees-of-freedom registration to the structural
    flirt -dof 12 -ref $structImg -refweight ${structMask}_dil -in $fieldmapImg -inweight $fieldmapMask -omat $transDir/${fieldmapBase}_to_${structBase}.mat
    ;;
  *)
    # 12 degrees-of-freedom registration to the structural
    echo "  12 dof linear registration"
    flirt -dof 12 -ref $structImg -refweight $structMask -in $fieldmapImg -inweight $fieldmapMask -omat $transDir/${fieldmapBase}_to_${structBase}.mat
    ;;
esac

# invert linear transformation
convert_xfm -omat $transDir/${structBase}_to_${fieldmapBase}.mat -inverse $transDir/${fieldmapBase}_to_${structBase}.mat

# transform the structural brain mask to the fieldmap space
applywarp --rel --interp=nn -i $structMask -r $fieldmapImg --premat=$transDir/${structBase}_to_${fieldmapBase}.mat -o $fieldmapDir/${structBase}_brain_mask_lin
# and bring the actualy structural image along, mostly for inspection purposes
#applywarp --rel --interp=spline -i $structImg -r $fieldmapImg --premat=$transDir/${structBase}_to_${fieldmapBase}.mat -o $fieldmapDir/"$(basename $structImg)"_lin

# non-linear registration
echo "  non-linear registration"
config=$MRCATDIR/HCP_scripts/fnirt_1mm.cnf
fnirt --ref=$structImg --refmask=$structMask --in=$fieldmapImg --aff=$transDir/${fieldmapBase}_to_${structBase}.mat --cout=$transDir/${fieldmapBase}_to_${structBase}_warpcoef --config=$config

# invert the warp field
invwarp -w $transDir/${fieldmapBase}_to_${structBase}_warpcoef -o $transDir/${structBase}_to_${fieldmapBase}_warpfield -r $fieldmapImg
applywarp --rel --interp=nn -i $structMask -r $fieldmapImg -w $transDir/${structBase}_to_${fieldmapBase}_warpfield -o $fieldmapDir/${structBase}_brain_mask
# and bring the actualy structural image along, mostly for inspection purposes
#applywarp --rel --interp=spline -i $structImg -r $fieldmapImg -w $transDir/${structBase}_to_${fieldmapBase}_warpfield -o $fieldmapDir/"$(basename $structImg)"

# remove the log
rm -f ${fieldmapImg}_to_"$(basename $structImg)".log

exit

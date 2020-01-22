#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files

# this is just a snippet of code to play with

# change .nii files to .nii.gz
for img in *.nii ; do
  [[ ! -r $img ]] && break
  fslchfiletype NIFTI_GZ $img
done

sh $MRCATDIR/in_vivo/register_EPI_T1.sh \
  --all \
  --epi=func/fm \
  --t1=structural/structural #\
  #--fmap=gre_phase \
  #--fmapmag=gre_mag \
  #--echospacing=0.000404998 \
  #--pedir=-y

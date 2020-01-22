Oxford Neuroimaging Analysis Scripts
There are 3 main directories of scripts so far:

nhp_preprocessing
nhp_fmri_analysis
human_fmri_analysis

Feel free to propose changes or add more. Also feel free to update this README with a brief reference
to scripts you've added (full descriptions should be in the script or in the script directory).
This README file uses Markdown to format the text.
See here: https://daringfireball.net/projects/markdown/syntax

NHP Preprocessing
MrCat-dev (dir)
A set of scripts from the MrCat toolbox (bias correction, brain extraction, registration etc.)
- includes struct_macaque, bet_macaque, robustfov_macaque among others
organise_raw_data.sh
A sample script that can be used to set up folder structure for preprocessing with Hauke's toolboxes.
prepare_align_epi (dir)
A set of scripts (Shell and Matlab) to prepare everything needed to run Hauke's Align_EPI toolbox.
Offline_SENSE.mlappinstall
Hauke's toolbox for SENSE reconstruction
Align_EPI.mlappinstall
Hauke's toolbox for aligning EPI slices/volumes
Align_Anatomy.mlappinstall
Haukes's toolbox for registering structural, GRE, and EPI images to each other.

NHP fMRI Analysis

Human fMRI Analysis

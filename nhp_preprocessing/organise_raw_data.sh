set -e # stop on error 

# ///////////////////////////////////////////////////////////////////////////////////////////////////////

<<COMMENT 
 --------------------- SUBJECT AND SESSION SPECIFIC SETUP: CHANGE SETTINGS ACCORDINGLY
COMMENT

# subject (only 1 per run)
subj="puzzle"

# session folder IDs (separated by spaces)
sessions_to_do="MI01097 MI01098 MI01103 MI01106 MI01113 MI01115 MI01118 MI01119 MI01121 MI01123 MI01125 MI01127"
sessions_rename="2016_01_22 2016_01_25 2016_01_28 2016_01_29 2016_02_03 2016_02_04 2016_02_05 2016_02_08 2016_02_09 2016_02_10 2016_02_12 2016_02_15"

# pringle
#sessions_to_do="MI01039 MI01043 MI01046 MI01048 MI01051 MI01056 MI01059 MI01062 MI01068 MI01070 MI01072 MI01076"
#sessions_rename="2015_11_26 2015_11_27 2015_11_30 2015_12_01 2015_12_02 2015_12_04 2015_12_07 2015_12_08 2015_12_10 2015_12_11 2015_12_14 2015_12_15"

sessions_rename=($sessions_rename)

# path to main study/data directory 
study_dir=/Users/rushworth/seqodr_data/mri_data

# -------------------------------------------------------------------------------------------------------
i=0

# loop over session
for session in $sessions_to_do; do

	rawdir=$study_dir/$subj/$session/raw

	mkdir $rawdir

	mv $rawdir/../*ep2d* $rawdir
	mv $rawdir/../*gre* $rawdir

	mv $study_dir/$subj/$session $study_dir/$subj/${sessions_rename[i]}

	i=$(($i+1))
done


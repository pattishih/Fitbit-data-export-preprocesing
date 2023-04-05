#!/bin/bash -l
#
# This script extracts fitbit export data and does a small amount of parsing 
# to prepare it for import into python for further processing.
#
# Dependencies:
#	jq command line JSON processor (https://stedolan.gi/Users/pshih/Downloads/MyFitbitData/Lily/fitbit_data_extraction.ipynbthub.io/jq)
#		-- you might have this already if you use conda, I think
#
# Instructions:
#	1) Create a folder named `data` in the same folder as the cleanup scripts 
#	   and copy/move all your fitbit export folders into `data`.
#	2) Open the jupityr notebook and run the code (fitbit_data_extraction.ipynb) 
#		* Two new folders will be created (data_concat and data_readme)
#		* data_concat contains preprocessed .csv files of the fitbit data
#		* data_readme contains related readme texts included by fitbit
#
# The project folder should look something like this:
# 	data/
# 	  ../Application/
#	  ../Biometrics/
#	  ../Fitbit Care/
#		...
#	  ../Stress/
#	data_concat/
#   data_readme/
#	avg.awk
#	fitbit_data_extraction.ipynb
#	fitbit_data_setup.sh
#	sum.awk
# 
# Resulting files in data_concat:
#	breath_rate.csv - Breathing rate (during sleep); 1 or more measurements/day
#	breath_rate_daily.csv - Breathing rate (during sleep); 1/day
#	calories_burned_daily.csv
#	distance_from_steps_daily.csv - units: cm
#	glucose.csv
#	hrv_daily.csv - Heart rate variability (during sleep)
#	hrv_histo_daily.csv - HRV histogram (during sleep)
#	lightly_active_minutes_daily.csv
#	moderately_active_minutes_daily.csv
#	very_active_minutes_daily.csv
#	sedentary_minutes_daily.csv
#	sleep_details_daily.csv
#	sleep_profile.csv
#	sleep_score.csv - daily sleep score metric computed by fitbit
#	sp02_daily.csv - SpO2 estimate (during sleep)
#	steps_daily.csv
#	stress_score.csv - daily stress metric computed by fitbit
#	weight_daily.csv
#	wrist_temperature.csv - wrist skin temperature (during sleep) - 1 or more measurements/day
#

FITBIT_EXPORT_DATA_DIR=data
NEW_DIR=data_concat
README_DIR=data_readme

#--------------------------------------------------

CSV_CONCAT=(
"Sleep:hrv_daily:Daily Heart Rate Variability Summary -"
"Sleep:hrv_histo_daily:Heart Rate Variability Histogram -"
"Sleep:wrist_temperature:Computed Temperature -"
"Sleep:sp02_daily:Daily SpO2 -"
"Sleep:breath_rate:Respiratory Rate Summary -"
"Sleep:breath_rate_daily:Daily Respiratory Rate Summary -"
"Biometrics:glucose:Glucose 2"
)

ALL_SINGLECSV=(
"Sleep/Sleep Profile.csv"
"Sleep/sleep_score.csv"
"Stress/Stress Score.csv"
)

# in-folder:out-filename:in-file-prefix:key1,key2,keyN
JSON_CONCAT=(
"Physical Activity:sedentary_minutes_daily:sedentary_minutes-:dateTime:value"
"Physical Activity:very_active_minutes_daily:very_active_minutes-:dateTime:value"
"Physical Activity:moderately_active_minutes_daily:moderately_active_minutes-:dateTime:value"
"Physical Activity:lightly_active_minutes_daily:lightly_active_minutes-:dateTime:value"
)

#"Physical Activity:resting_heart_rate:resting_heart_rate-:value.date:value.value"
#	(note: resting heart rate extracted from json seems to be miss-dated because they are
#	1 day behind the RHR in sleep_score.csv. So for a sleep log on 1/30/2023, the equiv
#	RHR can be found for the date 1/29/2023 in resting_heart_rate-*.json)


JSON_AGG_SUM_CONCAT=(
"Physical Activity:steps_daily:steps-:dateTime:value"
"Physical Activity:distance_from_steps_daily:distance-:dateTime:value"
"Physical Activity:calories_burned_daily:calories-:dateTime:value"
)

JSON_AGG_AVG_CONCAT=(
"Personal & Account:weight_daily:weight-:date:time:weight"
)

JSON_IFTRUE_CONCAT=(
"Sleep:sleep_details_daily:sleep-:mainSleep,type:dateOfSleep:startTime:endTime:minutesToFallAsleep:minutesAsleep:minutesAwake:timeInBed:levels.summary.light.minutes:levels.summary.deep.minutes:levels.summary.rem.minutes"
)

README_LOCATION=("Sleep" "Stress")

#===================================================
cd $FITBIT_EXPORT_DATA_DIR
NEW_DIR=../$NEW_DIR
README_DIR=../$README_DIR
avgawkpath=../avg.awk
sumawkpath=../sum.awk

mkdir -p $NEW_DIR 
mkdir -p $README_DIR

start_time=$(date +%s.%N)
#--------------------------------------------------
#++ Extract data from separate csv and combine them into one file

function extract_csv {
	local first=1

	# in-folder:out-filename:in-file-prefix:key1:key2:keyN
	local read_dir="$(echo $1 | cut -f1 -d:)"
	local out_title="$(echo $1 | cut -f2 -d:)"
	local in_title="$(echo $1 | cut -f3 -d:)"
	
	echo "Extracting ${in_title}* and saving to ${out_title}.csv"
	
	for csvfile in "$read_dir/${in_title}"*.csv; do
		#echo "$csvfile"
		if [ "$first" = 1 ]; then
			head -n 1 "$csvfile" > "$NEW_DIR/${out_title}.csv"
			first=0
		fi
		
		sed -n '2,$p' "$csvfile" >> "$NEW_DIR/${out_title}.csv"
	done
	wc -l < "$NEW_DIR/${out_title}.csv"; echo

}

for csv in "${CSV_CONCAT[@]}"; do
	extract_csv "$csv"
done

#--------------------------------------------------
#++ Copy over single csv files that don't need to be combined

for csvfile in "${ALL_SINGLECSV[@]}"; do
	filen="$(echo $csvfile | cut -f2 -d/ | tr '[:upper:] ' '[:lower:]_')"
	cp "$csvfile" "$NEW_DIR/$filen"
done

#--------------------------------------------------
#++ Grab all the readme texts

for read_dir in "${README_LOCATION[@]}"; do
	cd "$read_dir"
	for readme in *"README.txt"; do
		cp "$readme" ../"$README_DIR/$readme"
	done
	cd ..
done

#--------------------------------------------------

function extract_json {
	# in-folder:out-filename:in-file-prefix:key1:key2:keyN
	local read_dir="$(echo $1 | cut -f1 -d:)"
	local out_title="$(echo $1 | cut -f2 -d:)"
	local in_title="$(echo $1 | cut -f3 -d:)"
	local keys=($(echo "$1" | cut -f4- -d: | tr ':' '\n'))
	
	echo "Extracting ${in_title}* and saving to ${out_title}.csv"
	
    # Loop through all JSON files in the directory and extract the specified values
    if [ ${keys[0]} = 'date' ] && [ ${keys[1]} = 'time' ]; then	
		echo "dateTime,${keys[*]:2}" | tr ' ' ',' > "$NEW_DIR/${out_title}.csv"
		for jsonfile in "$read_dir/${in_title}"*.json; do
			# Use jq to extract the specified values
			jq -r ".[] | \"\(.date) \(.time),$(printf '\\(.%s)\n' "${keys[@]:2}" | paste -sd',' -)\"" "$jsonfile"\
				>> "$NEW_DIR/${out_title}.csv"
		done
	else
		echo ${keys[*]} | tr ' ' ',' > "$NEW_DIR/${out_title}.csv"
		for jsonfile in "$read_dir/${in_title}"*.json; do
			# Use jq to extract the specified values
			jq -r ".[] | \"$(printf '\\(.%s)\n' "${keys[@]}" | paste -sd',' -)\"" "$jsonfile"\
				>> "$NEW_DIR/${out_title}.csv"
		done
	fi
	wc -l < "$NEW_DIR/${out_title}.csv"; echo
}
#--------------------------------------------------
function aggregate_sum_extract_json {
	# in-folder:out-filename:in-file-prefix:key1,key2,keyN
	local read_dir="$(echo $1 | cut -f1 -d:)"
	local out_title="$(echo $1 | cut -f2 -d:)"
	local in_title="$(echo $1 | cut -f3 -d:)"
	local keys=( $(echo $1 | cut -f4- -d: | tr ':' '\n') )
	
	echo "Extracting ${in_title}* and saving to ${out_title}.csv"   
	echo ${keys[*]} | tr ' ' ',' > "$NEW_DIR/${out_title}.csv"
	
	local everything=$(
		# Loop through all JSON files in the directory and extract the specified values
		for jsonfile in "$read_dir/${in_title}"*.json; do
			# Use jq to extract the specified values
			jq -r ".[] | \"$(printf '\\(.%s)\n' "${keys[@]}" | paste -sd',' -)\"" "$jsonfile"
		done
	)
	
	awk -F',' -f "$sumawkpath" <<< "$everything" | sort -n -t":" -k1.7 -k1.1,3.2 -k1.4,3.5\
	>> "$NEW_DIR/${out_title}.csv"
	
	wc -l < "$NEW_DIR/${out_title}.csv"; echo
}
#--------------------------------------------------
function aggregate_avg_extract_json {
	# in-folder:out-filename:in-file-prefix:key1,key2,keyN
	local read_dir="$(echo $1 | cut -f1 -d:)"
	local out_title="$(echo $1 | cut -f2 -d:)"
	local in_title="$(echo $1 | cut -f3 -d:)"
	local keys=( $(echo $1 | cut -f4- -d: | tr ':' '\n') )
	
	echo "Extracting ${in_title}* and saving to ${out_title}.csv"
	echo ${keys[*]} | tr ' ' ',' > "$NEW_DIR/${out_title}.csv"

    local everything=$(
		# Loop through all JSON files in the directory and extract the specified values
		if [ ${keys[0]} = 'date' ] && [ ${keys[1]} = 'time' ]; then	
			echo "dateTime,${keys[*]:2}" | tr ' ' ',' > "$NEW_DIR/${out_title}.csv"
			for jsonfile in "$read_dir/${in_title}"*.json; do
				# Use jq to extract the specified values
				jq -r ".[] | \"\(.date) \(.time),$(printf '\\(.%s)\n' "${keys[@]:2}" | paste -sd',' -)\"" "$jsonfile"
			done
		else
			echo ${keys[*]} | tr ' ' ',' > "$NEW_DIR/${out_title}.csv"
			for jsonfile in "$read_dir/${in_title}"*.json; do
				# Use jq to extract the specified values
				jq -r ".[] | \"$(printf '\\(.%s)\n' "${keys[@]}" | paste -sd',' -)\"" "$jsonfile"
			done
		fi
	)
	
	awk -F',' -f "$avgawkpath" <<< "$everything" | sort -n -t":" -k1.7 -k1.1,3.2 -k1.4,3.5\
	>> "$NEW_DIR/${out_title}.csv"
	
	wc -l < "$NEW_DIR/${out_title}.csv"; echo
}
#--------------------------------------------------

function extract_iftrue_json {
	# in-folder:out-filename:in-file-prefix:key1,key2,keyN
	local read_dir="$(echo $1 | cut -f1 -d:)"
	local out_title="$(echo $1 | cut -f2 -d:)"
	local in_title="$(echo $1 | cut -f3 -d:)"
	local iftrue=( $(echo $1 | cut -f4 -d: | tr ',' '\n') )
	local keys=( $(echo $1 | cut -f5- -d: | tr ':' '\n') )
	
	echo "Extracting ${in_title}* and saving to ${out_title}.csv"   
	echo ${keys[*]} | tr ' ' ',' > "$NEW_DIR/${out_title}.csv"
	
	# Loop through all JSON files in the directory and extract the specified values
	for jsonfile in "$read_dir/${in_title}"*.json; do
		# Use jq to extract the specified values
		jq -r ".[] | select(.${iftrue[0]} == true $(printf 'and .%s == \"stages\"\n' ${iftrue[@]:1} | paste -sd',' -)) | \"$(printf '\\(.%s)\n' ${keys[@]} | paste -sd',' -)\"" "$jsonfile"\
		>> "$NEW_DIR/${out_title}.csv"
	done	
	
	wc -l < "$NEW_DIR/${out_title}.csv"; echo
}
#--------------------------------------------------
for json in "${JSON_CONCAT[@]}"; do
	extract_json "$json"
done

for json in "${JSON_AGG_SUM_CONCAT[@]}"; do
	aggregate_sum_extract_json "$json"
done

for json in "${JSON_AGG_AVG_CONCAT[@]}"; do
	aggregate_avg_extract_json "$json"
done

for json in "${JSON_IFTRUE_CONCAT[@]}"; do
	extract_iftrue_json "$json"
done

#--------------------------------------------------
end_time=$(date +%s.%N)
elapsed_time=$(echo "$end_time - $start_time" | bc)
echo "Elapsed time: $elapsed_time seconds"


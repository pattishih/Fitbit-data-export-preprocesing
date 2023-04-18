#!/bin/bash -l
#
# This script extracts fitbit export data and does a small amount of parsing 
# to prepare it for import into python or whatever for further processing.
#
# Requirements:
#  bash shell
#  jq command line JSON processor (https://stedolan.github.io/jq)
#    -- you might have this already if you use conda, I think
#
# Instructions:
#  1) Create a folder named `data` in the same folder as the cleanup scripts 
#     and copy/move all your fitbit export folders into `data`.
#  2) Open your command line environment and run:
#      bash fitbit_data_setup.sh
#
#  * Two new folders will be created (data_concat and data_readme)
#  * data_concat contains preprocessed .csv files of the fitbit data
#  * data_readme contains related readme texts included by fitbit
#
#  The project folder should look something like this:
#
#  data/
#    ../Application/
#    ../Biometrics/
#    ../Fitbit Care/
#       ...
#    ../Stress/
#  data_concat/
#  data_hr/
#  data_readme/
#  avg.awk
#  fitbit_data_extraction.ipynb
#  fitbit_data_setup.sh
#  sum.awk
# 
# Resulting files in data_concat/:
#
#  calories_burned_daily.csv
#  distance_from_steps_daily.csv - units in centimeters
#  steps_daily.csv
#  altitude_daily.csv - not sure what units... cm?
#  all_movement_metrics_daily.csv - the above 4 metrics inner joined in 1 csv
#
#  active_zone_minutes.csv
#  lightly_active_minutes_daily.csv
#  moderately_active_minutes_daily.csv
#  very_active_minutes_daily.csv
#  sedentary_minutes_daily.csv
#  all_sed_active_minutes_daily.csv - the above 4 inner joined in one csv
#
#  Sleep-related measurements/metrics:
#    breath_rate_daily.csv - Breathing rate (during sleep); 1/day
#    breath_rate.csv - Breathing rate (during sleep); 1 or more measurements/day
#    daily_readiness_score.csv - only available for certain fitbit models
#    hrv_daily.csv - Heart rate variability (during sleep)
#    hrv_histograms.csv - HRV histogram (during sleep)
#    sleep_details_daily.csv
#    sleep_profile.csv
#    sleep_score.csv - daily sleep score metric computed by fitbit
#    sp02_daily.csv - SpO2 estimate (during sleep)
#    stress_score.csv - daily stress metric computed by fitbit
#    wrist_temperature.csv - (during sleep) - 1 or more measurements/day
#
#  glucose.csv - if you have it sync'd
#  weight_daily.csv - units are whatever you specified in Fitbit app
#
# **Files suffixed with `_daily` have 1 value per day, but may or may not 
# include a row for every day if there was no measurement that day
#
################################################################################
#++ Begin Customization Blocks
################################################################################

#===============================================================================
#++ Directory names
#-------------------------------------------------------------------------------
FITBIT_DATA_DIR=data
NEW_CONCAT_DIR=data_concat
NEW_README_DIR=data_readme
NEW_HEART_RATE_DIR=data_hr

#===============================================================================
#
#++ Uncomment data to extract / Comment out data that you do not want processed
#
#===============================================================================
#-- Copy over single-file CSVs that don't need anything done to them
#-------------------------------------------------------------------------------
ALL_SINGLECSV=(
"Stress/Stress Score.csv"
"Sleep/sleep_score.csv"
#"Sleep/Sleep Profile.csv"
)

#===============================================================================
#-- Concatenate CSVs
#-------------------------------------------------------------------------------
CSV_CONCAT=(
"Sleep:hrv_histograms:Heart Rate Variability Histogram -"
"Sleep:hrv_daily:Daily Heart Rate Variability Summary -"
"Sleep:breath_rate_daily:Daily Respiratory Rate Summary -"
#"Sleep:breath_rate:Respiratory Rate Summary -"
"Sleep:wrist_temperature:Computed Temperature -"
"Sleep:sp02_daily:Daily SpO2 -"
#"Physical Activity:active_zone_minutes:Active Zone Minutes -"
#"Physical Activity:daily_readiness_score:Daily Readiness Score -"
#"Biometrics:glucose:Glucose 2"
)

#===============================================================================
#-- Extract the JSON data and convert it to csv format
#-------------------------------------------------------------------------------
#   No concatenation or aggregation... Maybe good for extracting fine-grained
#   minute-to-minute data like heart rate time series.
#
#   Format:
#      IN-folder:IN-file-prefix:dateTime:valuekey

JSON_EXTRACT_ONLY=(
"Physical Activity:heart_rate-:dateTime:value.bpm"
)

#===============================================================================
#-- Simple concatenation of daily summary measures from JSONs into one csv
#-------------------------------------------------------------------------------
#   Also creates a single CSV (all_sed_active_minutes_daily.csv) of all four
#   combined, but only if all four are uncommented below
#
#   Format:
#     IN-folder:OUT-filename:IN-file-prefix:dateTime:key2:keyN
JSON_CONCAT=(
"Physical Activity:sedentary_minutes_daily:sedentary_minutes-:dateTime:value"
"Physical Activity:very_active_minutes_daily:very_active_minutes-:dateTime:value"
"Physical Activity:moderately_active_minutes_daily:moderately_active_minutes-:dateTime:value"
"Physical Activity:lightly_active_minutes_daily:lightly_active_minutes-:dateTime:value"
)

# !!! __Data below is not recommended:__
#"Physical Activity:resting_heart_rate:resting_heart_rate-:dateTime:value.value"
#  (*note*: resting heart rate extracted from these jsons seem to be miss-dated 
#  because they are 1 day behind the RHR in sleep_score.csv. So for a sleep log 
#  on 1/30/2023, the equiv RHR can be found for the date 1/29/2023 in 
#  resting_heart_rate-*.json)

#===============================================================================
#-- Concatenates and computes the daily cummulative sum
#-------------------------------------------------------------------------------
JSON_AGG_SUM_CONCAT=(
"Physical Activity:calories_burned_daily:calories-:dateTime:value"
"Physical Activity:steps_daily:steps-:dateTime:value"
"Physical Activity:distance_from_steps_daily:distance-:dateTime:value"
"Physical Activity:altitude_daily:altitude-:dateTime:value"
)

#===============================================================================
#-- Concatenates and computes the daily average
#-------------------------------------------------------------------------------
JSON_AGG_AVG_CONCAT=(
"Personal & Account:weight_daily:weight-:date:time:weight"
)

#===============================================================================
#-- Sleep stages JSON data extraction
#-------------------------------------------------------------------------------
#   TODO (when there's time... haha, yeah right):
#   This is a more complicated JSON extraction that I had intended to make 
#   generalizable, but it currently works only on the sleep data.
# 
#   More specifically—it only extracts the data if Fitbit classified it as
#   "mainSleep" (as opposed to a nap or whatever) and if Fitbit had detected
#   different stages of sleep.

JSON_IFTRUE_CONCAT=(
"Sleep:sleep_details_daily:sleep-:mainSleep,type:dateOfSleep:startTime:endTime:minutesToFallAsleep:minutesAsleep:minutesAwake:timeInBed:levels.summary.light.minutes:levels.summary.deep.minutes:levels.summary.rem.minutes"
)

#===============================================================================
#-- Copy over some readme files provided by Fitbit
#-------------------------------------------------------------------------------
README_LOCATION=("Physical Activity" "Sleep" "Stress")

################################################################################
#++ End of customization
################################################################################

#++ Redefine some paths so they are absolute, not relative
starting_dir="$(pwd)"
FITBIT_DATA_DIR="$starting_dir/$FITBIT_DATA_DIR"
NEW_CONCAT_DIR="$starting_dir/$NEW_CONCAT_DIR"
NEW_README_DIR="$starting_dir/$NEW_README_DIR"
NEW_HEART_RATE_DIR="$starting_dir/$NEW_HEART_RATE_DIR"
avgawkpath="$starting_dir/avg.awk"
sumawkpath="$starting_dir/sum.awk"

mkdir -p $NEW_CONCAT_DIR 
mkdir -p $NEW_README_DIR

start_time=$(date +%s)

#----------------------------------------------------------
#++ Some concatenation and extraction functions
#----------------------------------------------------------
#-- Extract data from separate csv and combine them into one file
function extract_csv() {
  cd "$FITBIT_DATA_DIR"

  # in-folder:out-filename:in-file-prefix:key1:key2:keyN
  local read_dir="$(echo $1 | cut -f1 -d:)"
  local out_title="$(echo $1 | cut -f2 -d:)"
  local in_title="$(echo $1 | cut -f3 -d:)"
  local first=1
  
  echo "Extracting ${in_title}* and saving to ${out_title}.csv"
  
  for csvfile in "$read_dir/${in_title}"*.csv; do
    #echo "$csvfile"
    if [ "$first" = 1 ]; then
      head -n 1 "$csvfile" > "$NEW_CONCAT_DIR/${out_title}.csv"
      first=0
    fi
    
    sed -n '2,$p' "$csvfile" >> "$NEW_CONCAT_DIR/${out_title}.csv"
  done

  wc -l < "$NEW_CONCAT_DIR/${out_title}.csv"; echo
}

#-- Extracts the values of specified keys: 1 csv per 1 json
function extract_json_only() {
  cd "$FITBIT_DATA_DIR"
  
  local read_dir="$(echo $1 | cut -f1 -d:)"
  local in_title="$(echo $1 | cut -f2 -d:)"
  local keys=($(echo "$1" | cut -f3- -d: | tr ':' '\n'))
  
  mkdir -p "$NEW_HEART_RATE_DIR"
  echo "Extracting ${in_title}* and saving to ${NEW_HEART_RATE_DIR}"
  
  # Change dir so that it will be easier to use $jsonfile to name csv file
  cd "$read_dir"
  
  # Loop through all JSON files in the directory and extract the specified values
  for jsonfile in "${in_title}"*.json; do
    out_title=$(echo "$jsonfile" | cut -f1 -d.)

    # Create new csv, output header
    echo ${keys[*]} | tr ' ' ',' > "$NEW_HEART_RATE_DIR/${out_title}.csv"

    # Use jq to extract the specified values
    jq -r ".[] | \"$(printf '\\(.%s)\n' "${keys[@]}" | paste -sd',' -)\"" "$jsonfile"\
      >> "$NEW_HEART_RATE_DIR/${out_title}.csv"
  done
  cd ..
  echo
}

#-- Just extracting and concatenating JSONs
function extract_concat_json() {
  cd "$FITBIT_DATA_DIR"

  # in-folder:out-filename:in-file-prefix:key1:key2:keyN
  local read_dir="$(echo $1 | cut -f1 -d:)"
  local out_title="$(echo $1 | cut -f2 -d:)"
  local in_title="$(echo $1 | cut -f3 -d:)"
  local keys=($(echo "$1" | cut -f4- -d: | tr ':' '\n'))
  
  echo "Extracting ${in_title}* and saving to ${out_title}.csv"
  
  # Loop through all JSON files in the directory and extract the specified values
  echo ${keys[*]} | tr ' ' ',' > "$NEW_CONCAT_DIR/${out_title}.csv"
  for jsonfile in "$read_dir/${in_title}"*.json; do
    # Use jq to extract the specified values
    jq -r ".[] | \"$(printf '\\(.%s)\n' "${keys[@]}" | paste -sd',' -)\"" "$jsonfile"\
      >> "$NEW_CONCAT_DIR/${out_title}.csv"
  done

  wc -l < "$NEW_CONCAT_DIR/${out_title}.csv"; echo
}

#-- Get a cumulative value for the day
function aggregate_sum_extract_json() {
  cd "$FITBIT_DATA_DIR"
  
  # in-folder:out-filename:in-file-prefix:key1,key2,keyN
  local read_dir="$(echo $1 | cut -f1 -d:)"
  local out_title="$(echo $1 | cut -f2 -d:)"
  local in_title="$(echo $1 | cut -f3 -d:)"
  local keys=( $(echo $1 | cut -f4- -d: | tr ':' '\n') )
  
  echo "Extracting ${in_title}* and saving to ${out_title}.csv"   
  echo ${keys[*]} | tr ' ' ',' > "$NEW_CONCAT_DIR/${out_title}.csv"
  
  local everything=$(
    # Loop through all JSON files in the directory and extract the specified values
    for jsonfile in "$read_dir/${in_title}"*.json; do
      # Use jq to extract the specified values
      jq -r ".[] | \"$(printf '\\(.%s)\n' "${keys[@]}" | paste -sd',' -)\"" "$jsonfile"
    done
  )
  
  awk -F',' -f "$sumawkpath" <<< "$everything" | sort -n -t' ' -k1 >> "$NEW_CONCAT_DIR/${out_title}.csv"
  
  wc -l < "$NEW_CONCAT_DIR/${out_title}.csv"; echo
}

#-- Mainly for averaging multiple measurements of weight... and anything else?
function aggregate_avg_extract_json() {
  cd "$FITBIT_DATA_DIR"
  
  # in-folder:out-filename:in-file-prefix:key1,key2,keyN
  local read_dir="$(echo $1 | cut -f1 -d:)"
  local out_title="$(echo $1 | cut -f2 -d:)"
  local in_title="$(echo $1 | cut -f3 -d:)"
  local keys=( $(echo $1 | cut -f4- -d: | tr ':' '\n') )
  
  echo "Extracting ${in_title}* and saving to ${out_title}.csv"
  echo ${keys[*]} | tr ' ' ',' > "$NEW_CONCAT_DIR/${out_title}.csv"

  local everything=$(
    # Loop through all JSON files in the directory and extract the specified values
    if [ ${keys[0]} = 'date' ] && [ ${keys[1]} = 'time' ]; then  
      echo "dateTime,${keys[*]:2}" | tr ' ' ',' > "$NEW_CONCAT_DIR/${out_title}.csv"
      for jsonfile in "$read_dir/${in_title}"*.json; do
        # Use jq to extract the specified values
        jq -r ".[] | \"\(.date) \(.time),$(printf '\\(.%s)\n' "${keys[@]:2}" | paste -sd',' -)\"" "$jsonfile"
      done
    else
      echo ${keys[*]} | tr ' ' ',' > "$NEW_CONCAT_DIR/${out_title}.csv"
      for jsonfile in "$read_dir/${in_title}"*.json; do
        # Use jq to extract the specified values
        jq -r ".[] | \"$(printf '\\(.%s)\n' "${keys[@]}" | paste -sd',' -)\"" "$jsonfile"
      done
    fi
  )
  
  awk -F',' -f "$avgawkpath" <<< "$everything" | sort -n -t' ' -k1 >> "$NEW_CONCAT_DIR/${out_title}.csv"
  
  wc -l < "$NEW_CONCAT_DIR/${out_title}.csv"; echo
}

#-- For getting the individual sleep data
function extract_iftrue_json() {
  cd "$FITBIT_DATA_DIR"
  
  # in-folder:out-filename:in-file-prefix:key1,key2,keyN
  local read_dir="$(echo $1 | cut -f1 -d:)"
  local out_title="$(echo $1 | cut -f2 -d:)"
  local in_title="$(echo $1 | cut -f3 -d:)"
  local iftrue=( $(echo $1 | cut -f4 -d: | tr ',' '\n') )
  local keys=( $(echo $1 | cut -f5- -d: | tr ':' '\n') )
  
  echo "Extracting ${in_title}* and saving to ${out_title}.csv"   
  echo ${keys[*]} | tr ' ' ',' > "$NEW_CONCAT_DIR/${out_title}.csv"
  
  # Loop through all JSON files in the directory and extract the specified values
  for jsonfile in "$read_dir/${in_title}"*.json; do
    # Use jq to extract the specified values
    jq -r ".[] | select(.${iftrue[0]} == true $(printf 'and .%s == \"stages\"\n' ${iftrue[@]:1} | paste -sd',' -)) | \"$(printf '\\(.%s)\n' ${keys[@]} | paste -sd',' -)\"" "$jsonfile"\
    >> "$NEW_CONCAT_DIR/${out_title}.csv"
  done  
  
  wc -l < "$NEW_CONCAT_DIR/${out_title}.csv"; echo
}

#----------------------------------------------------------
#++ Do stuff on Fitbit's CSV files
#----------------------------------------------------------
#-- Concatenate data that are split into separate CSV files
for csv in "${CSV_CONCAT[@]}"; do
  extract_csv "$csv"
done

#-- Copy over single csv files that don't need to be combined
cd "$FITBIT_DATA_DIR"
for csvfile in "${ALL_SINGLECSV[@]}"; do
  filen="$(echo $csvfile | cut -f2 -d/ | tr '[:upper:] ' '[:lower:]_')"
  cp "$csvfile" "$NEW_CONCAT_DIR/$filen"
  echo "Copying over $csvfile as $filen"
  wc -l < "$csvfile"; echo
done

#-- Grab all the readme texts
cd "$FITBIT_DATA_DIR"
for read_dir in "${README_LOCATION[@]}"; do
  cd "$read_dir"
  for readme in *{README,Readme}.txt; do
    cp "$readme" "$NEW_README_DIR/$readme" 2> /dev/null
  done
  cd ..
done
echo

#----------------------------------------------------------
#++ Loop thru the arrays and do JSON extraction stuff
#----------------------------------------------------------
#-- Extract JSON data and save as individual CSVs
for json in "${JSON_EXTRACT_ONLY[@]}"; do
  extract_json_only "$json"
done

#-- Loop thru sedentary & active minutes CSVs to concat them into one for each
activity_minutes=()
for json in "${JSON_CONCAT[@]}"; do
  activity_minutes+=("$(echo $json | cut -f2 -d:)")
  extract_concat_json "$json"
done

# Then join the sedentary & active minutes CSVs into one table
# TODO: This combining step makes a lot of assumptions about the data...
if [ ${#activity_minutes[@]} = 4 ]; then
  cd $NEW_CONCAT_DIR
  echo "Combining above to make all_sed_active_minutes_daily.csv"
  echo "date ${activity_minutes[*]}" | tr ' ' ',' > "all_sed_active_minutes_daily.csv"
  join -t',' <(tail -n+2 "${activity_minutes[0]}.csv") <(tail -n+2 "${activity_minutes[1]}.csv")\
    | join -t',' - <(tail -n+2 "${activity_minutes[2]}.csv")\
    | join -t',' - <(tail -n+2 "${activity_minutes[3]}.csv")\
    >> "all_sed_active_minutes_daily.csv"
  wc -l < "all_sed_active_minutes_daily.csv"; echo
  cd ..
  # the following line reformats the date to YYYY-MM-DD, but has been left out
  # for speed reasons. Note: it uses string manipulation rather than strftime
  # for awk version compatibility
  #| awk -F, '{OFS=","; split($1, dt, " "); split(dt[1], d, "/"); $1 = "20"d[3]"-"d[1]"-"d[2]; print}'\
fi

#-- Get daily cummulative sums for certain measurements then inner join them
#   (calories, steps, distance, altitude)
out_csv="all_movement_metrics_daily.csv"
metrics=()
for json in "${JSON_AGG_SUM_CONCAT[@]}"; do
  metrics+=("$(echo $json | cut -f2 -d:)")
  aggregate_sum_extract_json "$json"
done

cd $NEW_CONCAT_DIR
echo "Combining above to make $out_csv"
tail -n+2 "${metrics[0]}.csv" > "$out_csv"
  
for metric in "${metrics[@]:1}"; do
  tempdata=$(cat "$out_csv")
  join -t',' <(echo "$tempdata") <(tail -n+2 "$metric.csv") > "$out_csv"
done
echo "date ${metrics[*]}" | tr ' ' ',' | cat - "$out_csv" > temp.csv && mv temp.csv "$out_csv"
wc -l < "$out_csv"; echo
cd ..

#-- Get the average daily weight
for json in "${JSON_AGG_AVG_CONCAT[@]}"; do
  aggregate_avg_extract_json "$json"
done

#-- Sleep stages JSON data extraction
for json in "${JSON_IFTRUE_CONCAT[@]}"; do
  extract_iftrue_json "$json"
done

#----------------------------------------------------------
end_time=$(date +%s)
elapsed_time=$(echo "$end_time - $start_time" | bc)
echo "Elapsed time: $elapsed_time seconds"


# Fitbit data export preprocesing
 Performs various quick & dirty data wrangling steps in bash shell (extracting, transforming, combining, aggregating, etc...) to prepare the data for analysis elsewhere

## Instructions:
  1) Create a folder named `data` in the same folder as the cleanup scripts 
     and copy/move all your fitbit export folders into `data`.
  2) Open `fitbit_data_setup.sh` in your preferred code editor and adjust the commenting within the denoted customization block to process/skip whatever you want... the default should be fine for most people. 
  3) Open your command line environment and run:
      ```
      bash fitbit_data_setup.sh
      ```
I'll also include my Jupyter notebook python code that loads and sets the data up with pandas when I get around to cleaning it up.

## Requirements:
  * `bash` shell
  * `jq` command line JSON processor (https://stedolan.github.io/jq)
    -- you might have this already if you use conda, I think

## What does `fitbit_data_setup.sh` do?
 The script extracts fitbit export data and does a small amount of parsing 
 to prepare it for import into python or whatever for further processing.
 
  * Two new folders will be created (`data_concat` and `data_readme`)
  * `data_concat` contains preprocessed .csv files of the fitbit data
  * `data_readme` contains related readme texts included by fitbit

The project folder should look something like this:
```
  data/
    ../Application/
    ../Biometrics/
    ../Fitbit Care/
       ...
    ../Stress/
  data_concat/
  data_hr/
  data_readme/
  avg.awk
  fitbit_data_extraction.ipynb
  fitbit_data_setup.sh
  sum.awk
```

Resulting files in `data_concat/`:
```
  calories_burned_daily.csv
  distance_from_steps_daily.csv - units in centimeters
  steps_daily.csv
  altitude_daily.csv - not sure what units... cm?
  all_movement_metrics_daily.csv - the above 4 metrics inner joined in 1 csv

  active_zone_minutes.csv
  lightly_active_minutes_daily.csv
  moderately_active_minutes_daily.csv
  very_active_minutes_daily.csv
  sedentary_minutes_daily.csv
  all_sed_active_minutes_daily.csv - the above 4 inner joined in one csv

  Sleep-related measurements/metrics:
    breath_rate_daily.csv - Breathing rate (during sleep); 1/day
    breath_rate.csv - Breathing rate (during sleep); 1 or more measurements/day
    daily_readiness_score.csv - only available for certain fitbit models
    hrv_daily.csv - Heart rate variability (during sleep)
    hrv_histograms.csv - HRV histogram (during sleep)
    sleep_details_daily.csv
    sleep_profile.csv
    sleep_score.csv - daily sleep score metric computed by fitbit
    sp02_daily.csv - SpO2 estimate (during sleep)
    stress_score.csv - daily stress metric computed by fitbit
    wrist_temperature.csv - (during sleep) - 1 or more measurements/day

  glucose.csv - if you have it sync'd
  weight_daily.csv - units are whatever you specified in Fitbit app
```

 ** Files suffixed with `_daily` have 1 value per day, but may or may not 
 include a row for every day if there was no measurement that day

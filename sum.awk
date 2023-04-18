BEGIN {
  OFS=","
} {
  # Split the datetime field into date and time fields using " " delimiter
  split($1, datetime, " ")

  # reformat the date so that it is YYYY-MM-DD so that it matches the other
  # data exports, but also, easier to sort this way
  split(datetime[1], datesplit, "/")  
  date = "20"datesplit[3]"-"datesplit[1]"-"datesplit[2]

  # Add the value to the sum to compute cumulative for the current date
  sum[date] += $2
} END {
  # Print the total for each date
  for (date in sum) {
    printf("%s,%i\n", date, sum[date])
  }
}

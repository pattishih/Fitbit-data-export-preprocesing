BEGIN {
	FS=","
	OFS=","
}
{
	# Split the datetime field into date and time fields using " " delimiter
	split($1, datetime, " ")
	date = datetime[1]
	#time = datetime[2]

	# Add the distance to the sum for the current date
	sum[date] += $2
}
END {
	# Print the total for each date
	for (date in sum) {
		printf("%s,%i\n", date, sum[date])
	}
}

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
	count[date] += 1
}
END {
	# Compute and print the average for each date
	for (date in sum) {
		avg = sum[date]/count[date]
		printf("%s,%.2f\n", date, avg)
	}
}

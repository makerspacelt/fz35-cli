#!/bin/bash


: "${PSU_NR:=1}"


mq_get() {
	nr=$1
	tag=$2
	count=${3:-5}
	offset=$((1+(count/10)))
	timeout 1000 mosquitto_sub -h mqtt.lan -t "tmp/device/i2c-psu${nr}/psu/${tag}" -C $((count+offset+offset)) \
		| sort -n \
		| tail -n$((count+offset)) \
		| head -n$((count)) \
		| awk '{s+=$1;c++} END {printf "%.3f", s/c}'
}

getAmps() {
	nr=$PSU_NR
	count=$1
	raw=$(mq_get $nr out_amps $count)
	line=$( (echo $raw; cat psu-hp-hstns-pl14.cal) | sort -n | grep -n "^${raw}$" | cut -d: -f1 )

	read set1 cal1 < <(sed -n "$((line-1))p" psu-hp-hstns-pl14.cal 2>/dev/null | cut -d' ' -f1,$((nr+1)))
	read set2 cal2 < <(sed -n "$((line))p" psu-hp-hstns-pl14.cal 2>/dev/null | cut -d' ' -f1,$((nr+1)))
	cal1=${cal1:-$cal2}
	cal2=${cal2:-$cal1}
	if [ "$cal1" == "$cal2" ]; then
		echo "scale=3; $raw*$cal1" | bc -l
	else
		echo "scale=3; $raw * ($cal1 + ($cal2 - $cal1) * ($raw - $set1) / ($set2 - $set1))" | bc -l

	fi
}
getVolts() {
	count=$1
	mq_get $PSU_NR out_volts $count
}
getRpm() {
	count=$1
	mq_get $PSU_NR fan_rpm $count
}

setRpm() {
	nr=$PSU_NR
	val=$1
	mosquitto_pub -h mqtt.lan -t "tmp/device/i2c-psu${nr}/psu/set_fan_rpm" -m "$val"
}


default() {
	cat <<-EOF
	Did you mean:
		$0 getAmps
		$0 getVolts
		$0 getRpm
		$0 setRpm <num>
	EOF
}


###########################


if [ -z "$1" ]
then
	default
else
	"$@"
fi



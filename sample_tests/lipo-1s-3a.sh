#!/bin/bash

charge_volts=4.200
charge_amps_max=1.000
charge_amps_min=0.050

load_amps=3.000
load_volts=3.200

delta_volts=0.005

# ========================

load() { HOST=192.168.0.9 ./load-kunkin-kp184.sh "$@" ;}
psu()  { HOST=192.168.0.6 ./psu-rd-dps8005.sh "$@" ;}

# =======================

start_timestamp=$(date +%s)

function getCsvRow() {
	fields="timestamp volts in_amps out_amps out_ah out_wh"

	if [ "$1" == "header" ]
	then
		echo "Charge:,"
		echo "charge_volts,$charge_volts,V"
		echo "charge_amps_max,$charge_amps_max,A"
		echo "charge_amps_min,$charge_amps_min,A"
		echo "Discharge:,"
		echo "load_amps,$load_amps,A"
		echo "load_volts,$load_volts,V"
		echo "Recovery:,"
		echo "delta_volts,$delta_volts,V"
		echo ","
		echo "$fields note" | tr ' ' ','
	else
		timestamp=$(($(date +%s) - start_timestamp))
		load_status="$(load getVolts getAmps getAH getWH | tr "\n" ' ')"
		volts=$(   echo "$load_status" | cut -d' ' -f1)
		out_amps=$(echo "$load_status" | cut -d' ' -f2)
		out_ah=$(  echo "$load_status" | cut -d' ' -f3)
		out_wh=$(  echo "$load_status" | cut -d' ' -f4)
		in_amps=$(psu getAmps)
		for f in $fields ; do
			echo -n "${!f},"
		done
		echo "$1"
	fi
}


echo "Setting up load ..." >&2
load off slp setFunc:none slp setFunc:bat clearAH setBatVolts:${load_volts} ${load_amps}A
echo "Setting up psu ..." >&2
psu off slp ${charge_volts}V ${charge_amps_max}A

getCsvRow header



echo "Charging ..." >&2
getCsvRow "Charging"
psu on

avg=100
while (( $(echo "$avg > $charge_amps_min" | bc -l) ))
do
	avg=0
	for i in {1..4}
	do
		amps=$(psu getAmps)
		avg=$(echo "$avg + $amps" | bc -l)
		getCsvRow
	done
	avg=$(echo "$avg / $i" | bc -l)
	getCsvRow "avg=$avg"
done

psu off
sleep 10



echo "Discharging ..." >&2
getCsvRow "Discharging"
load on

while [ "$(load isOn)" != 'false' ]
do
	getCsvRow
done


echo "Recovering ..." >&2
getCsvRow "Recovering"

delta=100
while (( $(echo "$delta > $delta_volts" | bc -l) ))
do
	min=1000
	max=0
	for i in {1..10}
	do
		volts=$(load getVolts)
		if (( $(echo "$volts < $min" | bc -l) ))
		then
			min=$volts
		fi
		if (( $(echo "$volts > $max" | bc -l) ))
		then
			max=$volts
		fi
		delta=$(echo "$max - $min" | bc -l)
		getCsvRow
	done
	getCsvRow "delta=$delta"
done



echo "Done" >&2
getCsvRow "Done"

psu off
load off



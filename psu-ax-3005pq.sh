#!/bin/bash
#set -x

: "${HOST:=psu30.lan}"
DEV=""


read_line() {
	local data=""
	local i=0
	until echo "$data" | grep -q "$1"
	do
		IFS= read -r -t 0.5 -s holder && data="$holder"
		((i++))
		if [ $i -gt 5 ]
		then
			return 1
		fi
	done < <(nc -q1 -w1 $HOST 23)
	echo $data
	if [ -z "$data" ]
	then
		return 1
	fi
}

send() {
	echo -n $1'\n' | nc -q1 -w1 $HOST 23
	if [ "$1" == "read" ]
	then
		return
	fi
}


# write

f_slp()   { sleep 1; }
f_on()    { send 'OUTPUT1'; sleep 0.5; }
f_off()   { send 'OUTPUT0'; sleep 0.5; }

f_setVolts() {
	volts=$(echo "$1" | sed 's/^\([0-9.]*\)[vV]$/\1/')
	LAST_SET_VOLTS=$(printf %05.2f $volts)
	send "VSET1:${LAST_SET_VOLTS}"
	sleep 0.5
}
f_setAmps() {
	amps=$(echo "$1" | sed 's/^\([0-9.]*\)[aA]$/\1/')
	LAST_SET_AMPS=$(printf %.3f $amps)
	send "ISET1:${LAST_SET_AMPS}"
	sleep 0.5
}


# read

f_idn()   {
	send '*IDN?'
	read_line '.'
}
f_status()   {
	send 'STATUS?'
	data="$(read_line '.')"
	test "${data:0:1}" == "1" && echo -n 'CV,'  || echo -n 'CC,'
	test "${data:1:1}" == "1" && echo -n 'ON,'  || echo -n 'OFF,'
	test "${data:2:1}" == "1" && echo -n 'OCP,' || echo -n 'NONE,'
	echo
}
f_getCVCC() {       f_status | cut -d, -f1; }
f_isOn() {          f_status | cut -d, -f2; }
f_getProtection() { f_status | cut -d, -f3; }



f_getVolts() {
	send 'VOUT1?'
	cache_read_volts=$(read_line '[0-3][0-9].[0-9][0-9]')
	echo $cache_read_volts
}
f_getAmps() {
	send 'IOUT1?'
	cache_read_amps=$(read_line '[0-5].[0-9][0-9][0-9]')
	echo $cache_read_amps
}
f_getWatts() {
	V=$(f_getVolts)
	A=$(f_getAmps)
	W=$(bc -l <<< "$V*$A")
	printf "%.2F\n" $W
}
f_getLimitVolts() {
	send 'VSET1?'
	read_line '[0-3][0-9].[0-9][0-9]'
}
f_getLimitAmps() {
	send 'ISET1?'
	read_line '[0-5].[0-9][0-9][0-9]'

}


for f in "$@"
do
	if echo "$f" | grep -q '^[0-9.]*[Vv]$'
	then
		f_setVolts "$f"
		continue
	fi

	if echo "$f" | grep -q '^[0-9.]*[Aa]$'
	then
		f_setAmps "$f"
		continue
	fi

	if echo "$f" | grep -q '...:.'
	then
		val=$(echo $f | cut -d: -f2)
		f=$(echo $f | cut -d: -f1)
	fi
	"f_$f" $val
done


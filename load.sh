#!/bin/bash
#set -x

LOAD_HOST="load.lan"
LOAD_DEV=""

LAST_AMPS=0.00
LAST_VOLTS=00.00

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
	done < <(nc -q1 -w1 $LOAD_HOST 23)
	echo $data
	if [ -z "$data" ]
	then
		return 1
	fi
}

send() {
	echo -n $1 | nc -q1 -w1 $LOAD_HOST 23
	if [ "$1" == "read" ]
	then
		return
	fi
	if read_line 'success' | fgrep -vq success
	then
		echo "send $1 failed" >&2
	fi
}

f_slp()   { sleep 1; }
f_on()    { send on; }
f_off()   { send off; }
f_start() { send start; }
f_stop()  { send stop; }
f_read()  { send read; }

f_lvp() { send $(printf "LVP:%2.1F\n" $1); }
f_ovp() { send $(printf "OVP:%2.1F\n" $1); }
f_ocp() { send $(printf "OCP:%1.2F\n" $1); }
f_opp() { send $(printf "OPP:%2.2F\n" $1); }
f_oah() { send $(printf "OAH:%1.3F\n" $1); }
f_ohp() { send $(printf "OHP:%s\n" $1); }

f_setup() {
	f_ovp 25.2
	f_ocp 5.1
	f_opp 35.5
	f_lvp 1.5
	f_oah 0.000
	f_ohp 00:00
	f_start
}


f_line() {
	read_line '.'
}
f_data() {
	read_line "^[0-9][0-9]\.[0-9][0-9]V" \
	|| echo "00.00V,0.00A,0.000Ah,00:00"
}

f_settings() {
	f_read
	read_line "^OVP:...."
}

getData() {
	f_data | tr -s AVh, ' ' 
}
f_getVolts()    { getData 1 | sed 's/^0\([0-9.]*\)$/\1/'; }
f_getAmps()     { getData 2; }
f_getAmpHours() { getData 3; }
f_getTime()     { getData 4; }
f_getWatts() {
	d=$( read_line . | tr -s AVh, ' ' | cut -d' ' -f1,2 )
	V=$(echo $d | cut -d' ' -f1)
	A=$(echo $d | cut -d' ' -f2)
	W=$(bc -l <<< "$V*$A")
	printf "%.2F\n" $W
}

f_setAmps() {
	amps=$(echo "$1" | sed 's/^\([0-9.]*\)A$/\1/')
	LAST_AMPS=$(printf %.2f $amps)
	send "${LAST_AMPS}A"
	sleep 1
}

f_getCsvVoltsAmps() {
	read_line . | tr -s AVh, ';' | cut -d';' -f1,2
}
f_getCsvRow() {
	d=$( getData | cut -d' ' -f1,2 )
	V=$(echo $d | cut -d' ' -f1)
	A=$(echo $d | cut -d' ' -f2)
	W=$(bc -l <<< "$V*$A")
	printf "%.2F,%.2F,%.2F,%.2F\n" "$LAST_AMPS" "$A" "$V" "$W"
}



for f in "$@"
do
	if echo "$f" | grep -q '^[0-5].*A'
	then
		f_setAmps "$f"
	else
		if echo "$f" | grep -q '...:.'
		then
			val=$(echo $f | cut -d: -f2)
			f=$(echo $f | cut -d: -f1)
		fi

		"f_$f" $val
	fi
done


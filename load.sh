#!/bin/bash
#set -x

send() {
	echo -n $1 | nc -q1 -w1 load.lan 23
}

f_slp()   { sleep 2; }
f_on()    { send on; }
f_off()   { send off; }
f_start() { send start; }
f_stop()  { send stop; }
f_read()  { send read; }

read_line() {
	local data
	local i=0;
	until echo "$data" | grep -q "$1"
	do
		IFS= read -r -t 0.5 -s holder && data="$holder"
		((i++))
		if [ $i -gt 5 ]
		then
			return 1
		fi
	done < <(nc -q1 -w1 load.lan 23)
	echo $data
}
f_data() {
	read_line "^[0-9][0-9]\.[0-9][0-9]V"
}

f_settings() {
	f_read
	read_line "^OVP"
}

getData() {
	read_line . | tr -s AVh, ' ' | awk "{print \$$1}"
}
f_getVolts()    { getData 1 | sed 's/^0\([0-9.]*\)$/\1/'; }
f_getAmps()     { getData 2; }
f_getAmpHours() { getData 3; }
f_getTime()     { getData 4; }
f_setAmps() {
	amps=$(echo "$1" | sed 's/^\([0-9.]*\)A$/\1/')
	amps=$(printf %.2f $amps)
	send "${amps}A"
	sleep 1
}

f_getCsvVoltsAmps() {
	read_line . | tr -s AVh, ';' | cut -d';' -f1,2
}
f_getCsvRow() {
	d=$( read_line . | tr -s AVh, ' ' | cut -d' ' -f1,2 )
	V=$(echo $d | cut -d' ' -f1)
	A=$(echo $d | cut -d' ' -f2)
	W=$(bc -l <<< "$V*$A")
	printf "%.2F,%.2F,%.2F\n" $A $V $W
}



for f in "$@"
do
	if echo "$f" | grep -q '^[0-5].*A'
	then
		f_setAmps "$f"
	else
		"f_$f"
	fi
done


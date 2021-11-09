#!/bin/bash
#set -x

: "${HOST:=192.168.0.65}"
DEV=""

status_data=""
status_timestamp=""

read_line() {
	data=$(nc $HOST 23 \
		| od -v -j0 -N30 -w2 -t u2 --endian=big \
		| grep -o ' [0-9]*$' \
		| tr -d "\n" \
		| grep '^ 16973 28 ' \
		| sed 's/^ 16973 28 //' \
	)
	echo $data
	if [ -z "$data" ]
	then
		return 1
	fi
}

f_status()   {
	item=$1

	if [ $(($status_timestamp+1)) -lt $(date +%s) ]
	then
		data="$(read_line)"
		status_data="$(
			echo -n "PM1.0:"; echo "$data" | cut -d' ' -f1
			echo -n "PM2.5:"; echo "$data" | cut -d' ' -f2
			echo -n "PM10:";  echo "$data" | cut -d' ' -f3

			echo -n "PM1.0_atm:"; echo "$data" | cut -d' ' -f4
			echo -n "PM2.5_atm:"; echo "$data" | cut -d' ' -f5
			echo -n "PM10_atm:";  echo "$data" | cut -d' ' -f6

			echo -n "PM0.3_num:"; echo "$data" | cut -d' ' -f7
			echo -n "PM0.5_num:"; echo "$data" | cut -d' ' -f8
			echo -n "PM1.0_num:"; echo "$data" | cut -d' ' -f9
			echo -n "PM2.5_num:"; echo "$data" | cut -d' ' -f10
			echo -n "PM5.0_num:"; echo "$data" | cut -d' ' -f11
			echo -n "PM10_num:";  echo "$data" | cut -d' ' -f12

		)"
		status_timestamp=$(date +%s)
	fi

	if [ -z "$item" ]
        then
		echo $status_data | tr ' ' "\n"
	else
		echo $status_data | tr ' ' "\n" | fgrep "$item:" | cut -d: -f2
	fi
}


for f in "$@"
do
	if echo "$f" | grep -q '^PM[0-9]'
	then
		f_status "$f"
		continue
	fi

	if echo "$f" | grep -q '...:.'
	then
		val=$(echo $f | cut -d: -f2)
		f=$(echo $f | cut -d: -f1)
	fi
	"f_$f" $val
done


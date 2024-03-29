#!/bin/bash
#set -x
#
# This script is for controlling KUNKIN KP182 and KP184 electronic loads
# Tested on KP184 via esp-link on esp-01s
#

: "${HOST:=load1.lan}"
DEV=""

loadStatusFile='/dev/shm/status'
rm -f $loadStatusFile

crc_reverse="false"

crc16() {
	table="
	   0X0000, 0XC0C1, 0XC181, 0X0140, 0XC301, 0X03C0, 0X0280, 0XC241,
	   0XC601, 0X06C0, 0X0780, 0XC741, 0X0500, 0XC5C1, 0XC481, 0X0440,
	   0XCC01, 0X0CC0, 0X0D80, 0XCD41, 0X0F00, 0XCFC1, 0XCE81, 0X0E40,
	   0X0A00, 0XCAC1, 0XCB81, 0X0B40, 0XC901, 0X09C0, 0X0880, 0XC841,
	   0XD801, 0X18C0, 0X1980, 0XD941, 0X1B00, 0XDBC1, 0XDA81, 0X1A40,
	   0X1E00, 0XDEC1, 0XDF81, 0X1F40, 0XDD01, 0X1DC0, 0X1C80, 0XDC41,
	   0X1400, 0XD4C1, 0XD581, 0X1540, 0XD701, 0X17C0, 0X1680, 0XD641,
	   0XD201, 0X12C0, 0X1380, 0XD341, 0X1100, 0XD1C1, 0XD081, 0X1040,
	   0XF001, 0X30C0, 0X3180, 0XF141, 0X3300, 0XF3C1, 0XF281, 0X3240,
	   0X3600, 0XF6C1, 0XF781, 0X3740, 0XF501, 0X35C0, 0X3480, 0XF441,
	   0X3C00, 0XFCC1, 0XFD81, 0X3D40, 0XFF01, 0X3FC0, 0X3E80, 0XFE41,
	   0XFA01, 0X3AC0, 0X3B80, 0XFB41, 0X3900, 0XF9C1, 0XF881, 0X3840,
	   0X2800, 0XE8C1, 0XE981, 0X2940, 0XEB01, 0X2BC0, 0X2A80, 0XEA41,
	   0XEE01, 0X2EC0, 0X2F80, 0XEF41, 0X2D00, 0XEDC1, 0XEC81, 0X2C40,
	   0XE401, 0X24C0, 0X2580, 0XE541, 0X2700, 0XE7C1, 0XE681, 0X2640,
	   0X2200, 0XE2C1, 0XE381, 0X2340, 0XE101, 0X21C0, 0X2080, 0XE041,
	   0XA001, 0X60C0, 0X6180, 0XA141, 0X6300, 0XA3C1, 0XA281, 0X6240,
	   0X6600, 0XA6C1, 0XA781, 0X6740, 0XA501, 0X65C0, 0X6480, 0XA441,
	   0X6C00, 0XACC1, 0XAD81, 0X6D40, 0XAF01, 0X6FC0, 0X6E80, 0XAE41,
	   0XAA01, 0X6AC0, 0X6B80, 0XAB41, 0X6900, 0XA9C1, 0XA881, 0X6840,
	   0X7800, 0XB8C1, 0XB981, 0X7940, 0XBB01, 0X7BC0, 0X7A80, 0XBA41,
	   0XBE01, 0X7EC0, 0X7F80, 0XBF41, 0X7D00, 0XBDC1, 0XBC81, 0X7C40,
	   0XB401, 0X74C0, 0X7580, 0XB541, 0X7700, 0XB7C1, 0XB681, 0X7640,
	   0X7200, 0XB2C1, 0XB381, 0X7340, 0XB101, 0X71C0, 0X7080, 0XB041,
	   0X5000, 0X90C1, 0X9181, 0X5140, 0X9301, 0X53C0, 0X5280, 0X9241,
	   0X9601, 0X56C0, 0X5780, 0X9741, 0X5500, 0X95C1, 0X9481, 0X5440,
	   0X9C01, 0X5CC0, 0X5D80, 0X9D41, 0X5F00, 0X9FC1, 0X9E81, 0X5E40,
	   0X5A00, 0X9AC1, 0X9B81, 0X5B40, 0X9901, 0X59C0, 0X5880, 0X9841,
	   0X8801, 0X48C0, 0X4980, 0X8941, 0X4B00, 0X8BC1, 0X8A81, 0X4A40,
	   0X4E00, 0X8EC1, 0X8F81, 0X4F40, 0X8D01, 0X4DC0, 0X4C80, 0X8C41,
	   0X4400, 0X84C1, 0X8581, 0X4540, 0X8701, 0X47C0, 0X4680, 0X8641,
	   0X8201, 0X42C0, 0X4380, 0X8341, 0X4100, 0X81C1, 0X8081, 0X4040
	"
	crc=0xFFFF;

	while true
	do
		byte=$( dd bs=1 count=1 <&0 2>/dev/null | od -w1 -t u1 | head -n 1 | awk '{print $2}')
		if [ -z "$byte" ]
		then
			break
		fi
		index=$(( ( ( byte ^ crc ) + 1 ) & 0x00FF  ))
		test $index -eq 0 && index=256
		table_val="$(echo $table | tr -d "\n\r\t " | cut -d, -f$index)"
		crc=$(( (crc >> 8) ^ table_val ));
	done

	if [ "$crc_reverse" == "true" ]
	then
		printf "\\\x%02x\\\x%02x\n" $(( crc & 0x00FF )) $(( crc >> 8 ))
	else
		printf "\\\x%02x\\\x%02x\n" $(( crc >> 8 )) $(( crc & 0x00FF ))
	fi
}





mb_send() {
	msg="\x01$1"
	crc=$(echo -ne "$msg" | crc16)
	msg="$msg$crc"
	echo -ne $msg | nc -q$2 -w1 $HOST 23 2>/dev/null
	sleep 0.01
}

mb_read_raw() {
	address="$1"
	count="$2"

	address=$( printf "\\\x%02x\\\x%02x" $(( address >> 8 )) $(( address & 0x00FF )) )
	count=$( printf "\\\x%02x\\\x%02x" $(( count >> 8 )) $(( count & 0x00FF )) )

	msg="\x03$address$count"
	mb_send "$msg" -1
}

mb_read() {
	address="$1"
	count="$2"
	bytes_to_read=$(( count * 2 ))

	mb_read_raw $address $count	\
		| od -v -j3 -N$bytes_to_read -w4 -t u4 --endian=big \
		| awk '{print $2}' \
		| head -n1 | tr "\n\r" ' '
}

mb_read_one() {
	mb_read $1 1
}

mb_write_one() {
	address="$1"
	value="$2"

	address=$( printf "\\\x%02x\\\x%02x" \
		$(( address >> 8 )) \
		$(( address & 0x00FF )) \
	)
	value=$( printf "\\\x%02x\\\x%02x\\\x%02x\\\x%02x" \
		$(( (value >> 24) & 0x00FF )) \
		$(( (value >> 16) & 0x00FF )) \
		$(( (value >> 8) & 0x00FF )) \
		$(( value & 0x00FF )) \
	)

	msg="\x06$address\x00\x01\x04$value"
	mb_send "$msg" 1 >/dev/null
}


## ==== write


f_on() {
	mb_write_one 0x010e 1
}
f_off() {
	mb_write_one 0x010e 0
}


f_setMode() {
	case $1 in
		CC) mode=1 ;;
		CV) mode=0 ;;
		CW) mode=3 ;;
		CR) mode=2 ;;
	esac
	mb_write_one 0x110 $mode
}

f_setFunc() {
	param=$(echo $1 | tr '[:lower:]' '[:upper:]')
	case $param in
		DYN) dyn=1 ;;
		BAT) bat=1 ;;
		COP) cop=1 ;;
		OCT) oct=1 ;;
	esac
	mb_write_one 0x0132 ${dyn:0}
	mb_write_one 0x0144 ${bat:0}
	mb_write_one 0x0180 ${cop:0}
	mb_write_one 0x0190 ${oct:0}
}
f_clearAH() {
	mb_write_one 0x0148 0
}
f_clearWH() {
	f_clearAH
}


f_setVolts() {
	f_setMode CV
	val=$(echo $1 | tr -d 'CVv')
	val=$(bc -l <<< "$val * 1000" | cut -d. -f1)
	mb_write_one 0x0112 $val # normal volts for CV
	mb_write_one 0x0146 $val # bat cut off voltage
}
f_setAmps() {
	f_setMode CC
	val=$(echo $1 | tr -d 'CAa')
	val=$(bc -l <<< "$val * 1000" | cut -d. -f1)
	mb_write_one 0x0116 $val
}
f_setWatts() {
	f_setMode CW
	val=$(echo $1 | tr -d 'CWw')
	val=$(bc -l <<< "$val * 100" | cut -d. -f1)
	mb_write_one 0x011E $val
}
f_setOhms() {
	f_setMode CR
	val=$(echo $1 | tr -d 'CRr')
	val=$(bc -l <<< "$val * 10" | cut -d. -f1)
	mb_write_one 0x011A $val
}
f_setBatVolts() {
	f_setFunc BAT
	val=$(echo $1 | tr -d 'Vv')
	val=$(bc -l <<< "$val * 1000" | cut -d. -f1)
	mb_write_one 0x0146 $val # bat cut off voltage
}


## ==== read


f_getVersion() {
	value=$(mb_read 0x0001 4)
	printf "%s\n" $value
}

f_getSetVolts() {
	value=$(mb_read 0x0112 4)
	value=$(bc -l <<< "$value / 1000")
	printf "%.3f\n" $value
}
f_getSetAmps() {
	value=$(mb_read 0x0116 4)
	value=$(bc -l <<< "$value / 1000")
	printf "%.3f\n" $value
}
f_getSetWatts() {
	value=$(mb_read 0x011E 4)
	value=$(bc -l <<< "$value / 100")
	printf "%.2f\n" $value
}
f_getSetOhms() {
	value=$(mb_read 0x011A 4)
	value=$(bc -l <<< "$value / 10")
	printf "%.1f\n" $value
}
f_getSetBatVolts() {
	value=$(mb_read 0x0146 4)
	value=$(bc -l <<< "$value / 1000")
	printf "%.3f\n" $value
}

#
#f_getVolts() {
#	value=$(mb_read 0x0122 4)
#	value=$(bc -l <<< "$value / 1000")
#	printf "%.3f\n" $value
#}
#f_getAmps() {
#	value=$(mb_read 0x0126 4)
#	value=$(bc -l <<< "$value / 1000")
#	printf "%.3f\n" $value
#}

## ==== status

getStatus() {
	if [ ! -f "$loadStatusFile" ]
	then
		mb_read_raw 0x0301 0 \
		| od -v -j3 -w1 -t u1 \
		| awk '{print $2" "}' \
		| tr -d '\r\n' \
		> $loadStatusFile
	fi
	if [ $(cat $loadStatusFile | wc -c) -lt 50 ]
	then
		rm "$loadStatusFile"
		getStatus
	else
		cat $loadStatusFile
	fi
}
f_getStatus() {	getStatus; }

f_isOn() {
	value=$(getStatus | cut -d' ' -f1)
	test $((value & 1)) -eq 1 && echo true || echo false
}
f_getMode() {
	value=$(getStatus | cut -d' ' -f1)
	echo -n C
	echo $(( (value >> 1) + 1 )) | tr '6587' 'CVWR'
}
f_getFunc() {
	value=$(getStatus | cut -d' ' -f2)

	test $((value&255)) -eq '0' && echo none
	test $((value&4)) -ne '0' && echo bat
	test $((value&8)) -ne '0' && echo dyn
	test $((value&32)) -ne '0' && echo cop
	test $((value&64)) -ne '0' && echo oct
}

f_getVolts() {
	b1=$(getStatus | cut -d' ' -f3)
	b2=$(getStatus | cut -d' ' -f4)
	b3=$(getStatus | cut -d' ' -f5)
	value=$(echo "($b1*256*256 + $b2*256 + $b3) /1000" | bc -l)
	printf "%.3f\n" "$value"
}
f_getAmps() {
	b1=$(getStatus | cut -d' ' -f6)
	b2=$(getStatus | cut -d' ' -f7)
	b3=$(getStatus | cut -d' ' -f8)
	value=$(echo "($b1*256*256 + $b2*256 + $b3) /1000" | bc -l)
	printf "%.3f\n" "$value"
}
f_getWatts() {
	volts=$(f_getVolts)
	amps=$(f_getAmps)
	value=$(echo "$volts*$amps" | bc -l)
	printf "%.3f\n" "$value"
}
f_getAH() {
	b1=$(getStatus | cut -d' ' -f25)
	b2=$(getStatus | cut -d' ' -f26)
	b3=$(getStatus | cut -d' ' -f27)
	b4=$(getStatus | cut -d' ' -f28)
	value=$(echo "($b1*256*256*256 + $b2*256*256 + $b3*256 + $b4) /60/60/1000" | bc -l)
	printf "%.6f\n" "$value"
}
f_getWH() {
	b1=$(getStatus | cut -d' ' -f29)
	b2=$(getStatus | cut -d' ' -f30)
	b3=$(getStatus | cut -d' ' -f31)
	b4=$(getStatus | cut -d' ' -f32)
	value=$(echo "($b1*256*256*256 + $b2*256*256 + $b3*256 + $b4) /60/60/1000" | bc -l)
	printf "%.6f\n" "$value"
}
f_getLimit() {
	b1=$(getStatus | cut -d' ' -f9)
	b2=$(getStatus | cut -d' ' -f10)
	b3=$(getStatus | cut -d' ' -f11)
	case $(f_getMode) in
	CC)
		printf "%.3f\n" $(echo "($b1*256*256 + $b2*256 + $b3) /1000" | bc -l)
		;;
	CV)
		printf "%.3f\n" $(echo "($b1*256*256 + $b2*256 + $b3) /1000" | bc -l)
		;;
	CW)
		printf "%.2f\n" $(echo "($b1*256*256 + $b2*256 + $b3) /100" | bc -l)
		;;
	CR)
		printf "%.1f\n" $(echo "($b1*256*256 + $b2*256 + $b3) /10" | bc -l)
		;;
	esac
}

## ==== high level stuff

f_slp() {
	rm -f $loadStatusFile
	sleep 1
}

setup() {
	if f_getVersion 2>/dev/null | fgrep -vq 1840
	then
		crc_reverse="true"
	fi
}

setup

for f in "$@"
do
	if echo "$f" | grep -q '^[0-9.]*[Vv]'
	then
		f_setVolts "$f"
		continue
	fi

	if echo "$f" | grep -q '^[0-9.]*[Aa]'
	then
		f_setAmps "$f"
		continue
	fi

	if echo "$f" | grep -q '^[0-9.]*[Ww]'
	then
		f_setWatts "$f"
		continue
	fi

	if echo "$f" | grep -q '^[0-9.]*[Rr]'
	then
		f_setOhms "$f"
		continue
	fi

	if echo "$f" | grep -q '...:.'
	then
		val=$(echo $f | cut -d: -f2)
		f=$(echo $f | cut -d: -f1)
	fi

	"f_$f" $val
done





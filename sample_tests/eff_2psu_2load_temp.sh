#!/bin/bash



async() {
	file=$(mktemp -p /dev/shm)
	( "$@" > $file ; test "$(cat "$file")" == "" && echo -n "-1" > "$file" ) >/dev/null &
	echo "$file"
}

await() {
	if grep -q "^/dev/shm/tmp." <<<"$1" ; then
		until [ -s "$1" ]; do
			sleep 0.1
		done
		cat "$1"
	else
		echo "$1"
		echo "WATNING: calling await on non-async value" >&2
	fi
}
test_async() {
	a=$(async amps 1)
	b=$(async amps 1 5)
	c=$(async amps 2)
	d=$(async amps 2 5)

	echo $a $b $c $d

	echo $(await $a) $(await $b) $(await $c) $(await $d)
	a=$(await $a)
	echo $a $b $c $d

	a=$(await $a)
	b=$(await $b)
	echo $a $b $c $d

}



getTemp() {
	nr=$1
	count=${3:-3}
	timeout 1000 mosquitto_sub -h mqtt.lan -t "tmp/device/temp-i2c8-pro/lab-temp/tl${nr}/get" -C $((count)) \
		| awk '{s+=$1;c++} END {printf "%.3f", s/c}'
}


load_send() {
	./load $@
}
load1() {
	HOST=load1.lan load_send $@
}
load2() {
	HOST=load2.lan load_send $@
}
load() {
	load1 $@
	load2 $@
}
psu1() {
	PSU_NR=1 psu-hp-hstns-pl14.sh $@
}
psu2() {
	PSU_NR=2 psu-hp-hstns-pl14.sh $@
}


default() {
	comment="$1"
	from=14.0
	to=2.0
	step=-0.2
	voutnom=$(load1 getVolts)
	v1=$(psu1 getVolts)
	v2=$(psu2 getVolts)
	vinnom=$(bc -l <<< "scale=1; $v1+$v2")
	outFile=$(date +data/%Y-%m-%d_%H-%M-%S)
	touch ${outFile}.png

	echo "load A, in V   , in A   , in    W, out  V, out  A, out W , eff %  , loss W  , t1 C, t2 C, t3 C, t4 C" > ${outFile}.csv 

	load off 0a on
	for i in $( seq $from $step $to ); do
		ah=$(bc -l <<< "scale=3; $i/2")
		load1 ${ah}A
		load2 ${ah}A
		sleep 1

		t1=$(async getTemp 48)
		t2=$(async getTemp 49)
		t3=$(async getTemp 4a)
		t4=$(async getTemp 4b)

		a1=$(async psu1 getAmps)
		a2=$(async psu2 getAmps)
		vin=$(./psu-rd-dps8005.sh getVolts getVolts getVolts | sort -n | head -n2 | tail -n1)

		# load1 has remote sens so get most accurate readings
		read -r ao1 vo1 wo1 <<<"$(load1 getAmps getVolts getWatts | tr '\n' ' ')"
		vo=$vo1
		ao=$(bc -l <<< "scale=3; $ao1*2")
		wo=$(bc -l <<< "scale=3; ${vo1}*${ao1}*2")


		a1=$(await $a1)
		a2=$(await $a2)
		ain=$(bc -l <<< "scale=3; ($a1+$a2)/2")
		win=$(bc -l <<< "scale=3; $vin*$ain")


		eff=$(bc -l <<< "scale=3; $wo/$win*100")
		loss=$(bc -l <<< "scale=3; $win-$wo")

		t1=$(await $t1)
		t2=$(await $t2)
		t3=$(await $t3)
		t4=$(await $t4)

		echo "${i}  , ${vin}V, ${ain}A, ${win}W, ${vo}V, ${ao}A, ${wo}W, ${eff}%, ${loss}W, $t1  , $t2 , $t3  , $t4" \
			| tee -a ${outFile}.csv
		./sample_plots/eff_loss.gnuplot \
			"${outFile}.csv" \
			"Efficiency/Loss vs Output Load" \
			"V_{in}=${vinnom}V; V_{out}=${voutnom}V; I_{out}=${from}A\~${to}A" \
			"${comment}" \
			> ${outFile}.png
	done
	load off off
}


trap 'rm -f /dev/shm/tmp.*' EXIT

###########################


if [ -z "$1" ]
then
	default
else
	"$@"
fi



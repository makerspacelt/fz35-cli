#!/bin/bash


function set() {
	sigrok-cli --driver=rdtech-dps:conn=/dev/ttyUSB0 --config $1 --set
}
function get() {
	sigrok-cli --driver=rdtech-dps:conn=/dev/ttyUSB0 --config $1 --get
}
function sample() {
	sigrok-cli --driver=rdtech-dps:conn=/dev/ttyUSB0 --samples ${1:-1}
}
function show() {
	sigrok-cli --driver=rdtech-dps:conn=/dev/ttyUSB0 --show
}

function on() {
	set enabled=on
}
function off() {
	set enabled=off
}


if [ -z $1 ]; then
		set voltage_target=3.35
		on
	   	sample
	   	set voltage_target=5.01
	    sample
		off
	    sample
else
	$1 $2
fi


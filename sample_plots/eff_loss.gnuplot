#!/usr/bin/gnuplot -c

set terminal pngcairo font ",72" fontscale 0.19 size 800, 600
# set output 'test.png'

set datafile separator ","

set xlabel ARG2."\n".ARG3."\n".ARG4
set format x '%.1fA'

set ylabel "Efficiency (%)"
set format y '%.1f'

set y2label "Power Loss (W)"
set format y2 '%.1f'
set y2tics

#set nomxtics

set grid layerdefault   lt 0 linecolor black linewidth 2

#set tmargin 1
#set rmargin 3
#set bmargin 5
#set lmargin 5


set xrange [ * : * ] noreverse writeback
set x2range [ * : * ] noreverse writeback
set yrange [ * : * ] noreverse writeback
set y2range [ * : * ] noreverse writeback
set zrange [ * : * ] noreverse writeback
set cbrange [ * : * ] noreverse writeback
set rrange [ * : * ] noreverse writeback

set key bottom right

plot \
ARG1 using 1:8 with lines linecolor black linewidth 2 dashtype 1 title '%', \
ARG1 using 1:9 with lines linecolor black linewidth 2 dashtype "-" axis x1y2 title 'W' \



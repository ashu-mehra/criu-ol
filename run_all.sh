#!/bin/bash

./pingperf_test.sh 5 8 &> pingperf.out
./acmeair_test.sh 5 8 &> acmeair.out
./daytrader7_test.sh 5 8 &> daytrader7.out

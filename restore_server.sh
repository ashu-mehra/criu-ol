#!/bin/bash

date +"%s.%3N" > starttime.out
numactl --physcpubind="0,1,32,33" --membind="0" ./criu-ns restore --tcp-established --images-dir=${SNAPSHOT_DIR} -j -d -v4 -o ${SNAPSHOT_DIR}/restore.log

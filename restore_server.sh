#!/bin/bash

date +"%s.%3N" > starttime.out
./criu-ns restore --tcp-established --images-dir=${SNAPSHOT_DIR} -j -d -v4 -o ${SNAPSHOT_DIR}/restore.log

# If you want to bind the server to cpus, then use the following command and comment out previous command.
# numactl --physcpubind="0-1" --membind="0" ./criu-ns restore --tcp-established --images-dir=${SNAPSHOT_DIR} -j -d -v4 -o ${SNAPSHOT_DIR}/restore.log

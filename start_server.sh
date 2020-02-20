#!/bin/bash

date +"%s.%3N" > starttime.out
numactl --physcpubind="0,1,32,33" --membind="0" ${SERVER_INSTALL_DIR}/wlp/bin/server start ${SERVER_NAME}
#numactl --physcpubind="0,1,32,33" --membind="0" perf stat ${SERVER_INSTALL_DIR}/wlp/bin/server start ${SERVER_NAME}

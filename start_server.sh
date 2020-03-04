#!/bin/bash

date +"%s.%3N" > starttime.out
${SERVER_INSTALL_DIR}/wlp/bin/server start ${SERVER_NAME}

# If you want to bind the server to cpus, then use the following command and comment out previous command.
#numactl --physcpubind="0-3" --membind="0" ${SERVER_INSTALL_DIR}/wlp/bin/server start ${SERVER_NAME}

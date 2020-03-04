#!/bin/bash

export SERVER_INSTALL_DIR="/opt/app/acmeair"

export SERVER_NAME=defaultServer

export LOG_MESSAGE="The defaultServer server is ready to run a smarter planet"

export LOG_LOCATION="${SERVER_INSTALL_DIR}/wlp/usr/servers/${SERVER_NAME}/logs/messages.log"

export FIRST_REQUEST_URL="localhost:9090/acmeair-webapp/flights.html"

export SNAPSHOT_DIR="${SERVER_INSTALL_DIR}/wlp/usr/servers/${SERVER_NAME}_checkpoint"

export SCC_LOCATION="${SERVER_INSTALL_DIR}/usr/servers/.classCache"

./compare.sh "$@"

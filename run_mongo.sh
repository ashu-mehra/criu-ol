#!/bin/bash

docker run --rm -d --net=host --name mongodb mongo-acmeair:latest --nojournal
sleep 2
docker exec mongodb mongorestore --drop /AcmeAirDBBackup 

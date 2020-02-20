#!/bin/bash

while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' ${FIRST_REQUEST_URL})" != "200" ]]; do
	sleep .00001;
done
date +"%s.%3N" > endtime.out

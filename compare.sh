#!/bin/bash

check_server_started() {
	waitPeriod=30
	waited=0
	while [ ${waited} -lt ${waitPeriod} ];
	do
		grep "${LOG_MESSAGE}" "${LOG_LOCATION}" &> /dev/null
                local app_started=$?
                if [ ${app_started} -eq 0 ]; then
                        break
                else
                        sleep 1s
			waited=$(( waited + 1 ))
                fi
        done
	if [ ${waited} -eq ${waitPeriod} ];
	then
		echo "Looks like something went wrong in starting the server!"
		exit 1
	fi
}

pre_test_cleanup() {
	rm -f starttime.out
	if [ ! -z "${LOG_LOCATION}" ]; then
		rm -f ${LOG_LOCATION}
	fi	
	rm -f endtime.out
}

pre_test_cleanup_criu() {
	rm -f starttime.out
	rm -f endtime.out
}

test_server_su() {
	isColdRun=$1
	echo "Starting ${SERVER_NAME} using original image for startup measurement"
	pre_test_cleanup
	
	./start_server.sh &
	check_server_started
	if [ $? -eq 0 ]; then
		startupMsg=`grep "${LOG_MESSAGE}" "${LOG_LOCATION}"`
		end_time=`perl getLibertyStartTime.pl "$startupMsg"`
	fi
	start_time=`cat starttime.out`
	diff=`echo "$end_time-$start_time" | bc`
	echo "Start time: ${start_time}"
	echo "End time: ${end_time}"
	echo "Response time: ${diff} seconds"
	if [ ${isColdRun} -eq 0 ]; then
		server_su+=(${diff})
	else
		echo "Ignoring this as cold run"
	fi
	echo -n "Stopping the server ... "
	${SERVER_INSTALL_DIR}/wlp/bin/server stop ${SERVER_NAME}
	echo "Done"
}

test_server_fr() {
	isColdRun=$1
	echo "Starting ${SERVER_NAME} using original image"
	pre_test_cleanup

	./hiturlloop.sh &
	./start_server.sh &
	while [ ! -f endtime.out ]; do
		sleep 1s
	done
	start_time=`cat starttime.out`
	end_time=`cat endtime.out`
	diff=`echo "$end_time-$start_time" | bc`
	echo "Start time: ${start_time}"
	echo "End time: ${end_time}"
	echo "Response time: ${diff} seconds"
	if [ ${isColdRun} -eq 0 ]; then
		server_fr+=(${diff})
	else
		echo "Ignoring this as cold run"
	fi
	echo -n "Stopping the server ... "
	${SERVER_INSTALL_DIR}/wlp/bin/server stop ${SERVER_NAME}
	echo "Done"
}

test_server_fr_criu() {
	isColdRun=$1
	echo "Starting ${SERVER_NAME} using checkpoint"
	pre_test_cleanup_criu

	./hiturlloop.sh &
	./restore_server.sh &
	while [ ! -f endtime.out ]; do
		sleep 1s
	done
	start_time=`cat starttime.out`
	end_time=`cat endtime.out`
	diff=`echo "$end_time-$start_time" | bc`
	echo "Start time: ${start_time}"
	echo "End time: ${end_time}"
	echo "Response time: ${diff} seconds"
	if [ ${isColdRun} -eq 0 ]; then
		server_fr_criu+=(${diff})
	else
		echo "Ignoring this as cold run"
	fi

        #restore_time=`crit show ${SNAPSHOT_DIR}/stats-restore | grep restore_time | cut -d ':' -f 2 | cut -d ',' -f 1`
        #echo "time to restore: " $((${restore_time}/1000))

	echo -n "Stopping the server ... "
	pid=`ps -ef | grep "java" | grep -v grep | awk '{ print $2 }'`
	kill -9 $pid
	echo "Done"
}

create_checkpoint() {
	echo "Creating checkpoint for server ${SERVER_NAME}"
	if [ -d ${SCC_LOCATION} ]; then
		rm -fr ${SCC_LOCATION}
	fi
	if [ -d ${SNAPSHOT_DIR} ]; then
		rm -fr ${SNAPSHOT_DIR}
	fi
	pre_test_cleanup
	mkdir -p ${SNAPSHOT_DIR}
	./start_server.sh &
	echo "Waiting for server to be started ..."
	check_server_started
	if [ $? -eq 0 ]; then
		numJava=`ps -ef | grep "java" | grep -v grep | wc -l`
		if [ "$numJava" -ne "1" ]; then
			echo "More than one java process found"
			exit 1
		fi
		pid=`ps -ef | grep "java" | grep -v grep | awk '{ print $2 }'`
		if [ -z "${pid}" ]; then
			echo "Failed to find pid of the process to be checkpointed"
			exit 1;
		fi
		echo "Pid to be checkpointed: ${pid}"
		date +"%s.%3N" > cpstart.out
		cmd="./criu-ns dump -t ${pid} --tcp-established --images-dir=${SNAPSHOT_DIR} -j -v4 -o ${SNAPSHOT_DIR}/dump.log"
		echo "CMD: ${cmd}"
		${cmd}
		date +"%s.%3N" > cpend.out
		start_time=`cat cpstart.out`
		end_time=`cat cpend.out`
		diff=`echo "$end_time-$start_time" | bc`
		echo "Time taken to checkpoint: ${diff} secs"
	fi
	grep "Dumping finished successfully" ${SNAPSHOT_DIR}/dump.log
	if [ $? -ne 0 ]; then
		echo "Checkpoint failed"
		cleanup
		exit 1
	fi
	echo "Checkpoint created"
}

cleanup() {
	if [[ "${FIRST_REQUEST_URL}" == *"acmeair"* ]]; then
		docker stop mongodb
		docker container prune -f &> /dev/null &
	fi
}

get_average() {
	arr=("$@")
	# echo "values: ${arr[@]}"
	sum=0
	for val in ${arr[@]}
	do
		sum=`echo "${sum}+${val}" | bc`
	done
	echo "scale=3; $sum/${#arr[@]}" | bc
}

get_averages() {
	for server in ${headers[@]}
	do
		value_list=(${values[$server]})
		#echo "value_list: ${value_list[@]}"
		#get_average ${value_list[@]}
		averages[$server]=$(get_average ${value_list[@]})
	done
}

print_summary() {
	echo "########## Summary ##########"
	printf "\t"
	for server in ${headers[@]}
	do
		printf "%-15s" "${server}"
	done
	echo
	index=0
	for batch in `seq 1 ${batches}`;
	do
		for itr in `seq 1 ${iterations}`;
		do
			printf "${batch}.${itr}\t"
			for server in ${headers[@]};
			do
				value_list=(${values[$server]})
				printf "%-15s" "${value_list[${index}]}"
			done
			echo
			index=$(( $index + 1 ))
		done
	done
	printf "Avg\t"
	for server in ${headers[@]}
	do
		printf "%-15s" "${averages[$server]}"
	done
	echo
}

if [ -z ${JAVA_HOME} ]; then
	echo "JAVA_HOME is not set"
	exit 1
fi

echo "Using JAVA_HOME: ${JAVA_HOME}"
export PATH="$JAVA_HOME/bin:$JAVA_HOME/jre/bin:$PATH"

declare -a headers=("server_su" "server_fr" "server_fr_criu")

declare -A values
declare -A averages
for server in ${headers[@]}
do
	averages[$server]=0
done

declare -a server_su server_fr server_fr_criu

if [ $# -lt 2 ]; then
	echo "Invalid number of arguments; please pass number of batches and iterations"
	exit -1	
fi

if [[ "${FIRST_REQUEST_URL}" == *"acmeair"* ]]; then
	./run_mongo.sh
fi

batches=$1
iterations=$2

for batch in `seq 1 ${batches}`;
do
	for server in ${headers[@]}
	do
		# before running criu tests, create a checkpoint
		if [ "${server}" = "server_fr_criu" ]; then
			create_checkpoint
		fi
		
		echo "Cold run for batch ${batch}"
		test_${server} 1
		for itr in `seq 1 ${iterations}`;
		do
			echo "###"
			echo "Iteration ${batch}.${itr} for ${server}"
			test_${server} 0
		done
	done
done

cleanup

values["server_su"]=${server_su[@]}
values["server_fr"]=${server_fr[@]}
values["server_fr_criu"]=${server_fr_criu[@]}

get_averages
print_summary

#!/bin/bash

# Usage:
#
# ./utils.sh -c create-master -n mesos-master-1,mesos-master-2,\
#									mesos-master-3
#
# ./utils.sh -c create-slave -n mesos-slave-1,mesos-slave-2,\
#									mesos-slave-3,mesos-slave-4
#
# ./utils.sh -c delete-vms -n mesos-master-1,mesos-master-2,\
#									mesos-master-3
#
# ./utils.sh -c delete-vms -n mesos-slave-1,mesos-slave-2,\
#									mesos-slave-3,mesos-slave-4

function exec_cmd
{	
  echo ""
  echo "Command: $ARG_CMD"
	echo "script to execute:   $EXEC_SCRIPT"
	if [ "$ARG_DRY_RUN" = 0 ]; then
		bash -c "$EXEC_SCRIPT";
	fi
}

function clear_workspace_folder
{
	EXEC_SCRIPT="rm -Rf ./tmp-ws"
	bash -c "$EXEC_SCRIPT";
}

function create_master
{
	for element in "${array[@]}"
	do
    EXEC_SCRIPT="$BASE_CREATE instances create \"$element\""
    EXEC_SCRIPT="$EXEC_SCRIPT $BASE_SCRIPT"
    EXEC_SCRIPT="$EXEC_SCRIPT --image \"$BASE_IMAGE\""
    EXEC_SCRIPT="$EXEC_SCRIPT --boot-disk-size \"40\""
    EXEC_SCRIPT="$EXEC_SCRIPT --boot-disk-type \"pd-standard\""
    EXEC_SCRIPT="$EXEC_SCRIPT --boot-disk-device-name \"disk-$element\""
    EXEC_SCRIPT="$EXEC_SCRIPT --metadata-from-file startup-"
    EXEC_SCRIPT="${EXEC_SCRIPT}-script=./init-vm-instance.sh &"

		exec_cmd
	done
}

function create_slave
{
	for element in "${array[@]}"
	do
    EXEC_SCRIPT="gcloud compute --project \"$ARG_PROJECT_ID\" instances create \"$element\""
    EXEC_SCRIPT="$EXEC_SCRIPT --zone \"asia-east1-b\" --machine-type \"n1-standard-2\""
    EXEC_SCRIPT="$EXEC_SCRIPT --network \"default\" --maintenance-policy \"MIGRATE\""
    EXEC_SCRIPT="$EXEC_SCRIPT --scopes \"https://www.googleapis.com/auth/cloud-platform\""
    EXEC_SCRIPT="$EXEC_SCRIPT --image \"https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1404-trusty-v20151113\""
    EXEC_SCRIPT="$EXEC_SCRIPT --boot-disk-size \"200\" --boot-disk-type \"pd-standard\" --boot-disk-device-name \"disk-$element\""
    EXEC_SCRIPT="$EXEC_SCRIPT --metadata-from-file startup-script=./init-vm-instance.sh &"

		exec_cmd
	done
}


function delete_vms
{
	DELETE_VMS=""
	
	for element in "${array[@]}"
	do
		DELETE_VMS="$DELETE_VMS $element"
	done

	EXEC_SCRIPT="gcloud compute instances delete $DELETE_VMS -q &"
	exec_cmd
}

function create_replica_set
{
	rs_set="${array[0]}"
	mg_a="${array[1]}"
	mg_b="${array[2]}"
	mg_c="${array[3]}"
	
	# prepare pods magnifest file
	sed "s/{tagname}/$mg_a/g" ./templates/pod-member-{tagname}.json | sed "s/--replSet {replica-name}/--replSet $rs_set/g" | sed "s/\"mg-role\": \"rs-x\"/\"mg-role\": \"rs-a\"/g" > ./tmp-ws/pod-$mg_a.json
	sed "s/{tagname}/$mg_b/g" ./templates/pod-member-{tagname}.json | sed "s/--replSet {replica-name}/--replSet $rs_set/g" | sed "s/\"mg-role\": \"rs-x\"/\"mg-role\": \"rs-b\"/g" > ./tmp-ws/pod-$mg_b.json
	sed "s/{tagname}/$mg_c/g" ./templates/pod-member-{tagname}.json | sed "s/--replSet {replica-name}/--replSet $rs_set/g" | sed "s/\"mg-role\": \"rs-x\"/\"mg-role\": \"rs-c\"/g" > ./tmp-ws/pod-$mg_c.json
	
	# prepare service magnifest file
	sed "s/{tagname}/$mg_a/g" ./templates/svc-member-{tagname}.json > ./tmp-ws/svc-$mg_a.json
	sed "s/{tagname}/$mg_b/g" ./templates/svc-member-{tagname}.json > ./tmp-ws/svc-$mg_b.json
	sed "s/{tagname}/$mg_c/g" ./templates/svc-member-{tagname}.json > ./tmp-ws/svc-$mg_c.json
	
	EXEC_SCRIPT="kubectl create -f ./tmp-ws/pod-$mg_a.json"
	exec_cmd
	EXEC_SCRIPT="kubectl create -f ./tmp-ws/pod-$mg_b.json"
	exec_cmd
	EXEC_SCRIPT="kubectl create -f ./tmp-ws/pod-$mg_c.json"
	exec_cmd
	EXEC_SCRIPT="kubectl create -f ./tmp-ws/svc-$mg_a.json"
	exec_cmd
	EXEC_SCRIPT="kubectl create -f ./tmp-ws/svc-$mg_b.json"
	exec_cmd
	EXEC_SCRIPT="kubectl create -f ./tmp-ws/svc-$mg_c.json"
	exec_cmd
}


function delete_container
{
	for element in "${array[@]}"
	do
		EXEC_SCRIPT="kubectl delete services $element"
		exec_cmd
		
		sleep 1
		
		EXEC_SCRIPT="kubectl delete pods $element"
		exec_cmd
	done
}


function create_config_server
{
	for element in "${array[@]}"
	do
		# prepare pods magnifest file
		sed "s/{tagname}/$element/g" ./templates/pod-config-{tagname}.json > ./tmp-ws/pod-$element.json
	
		# prepare service magnifest file
		sed "s/{tagname}/$element/g" ./templates/svc-config-{tagname}.json > ./tmp-ws/svc-$element.json
	
		EXEC_SCRIPT="kubectl create -f ./tmp-ws/pod-$element.json"
		exec_cmd
		EXEC_SCRIPT="kubectl create -f ./tmp-ws/svc-$element.json"
		exec_cmd
	done
}

function create_router
{
	mg_name="${array[0]}"
	conf_servers="${array[1]},${array[2]},${array[3]}"
	
	# prepare magnifest file
	sed "s/{tagname}/$mg_name/g" ./templates/pod-router-{tagname}.json | sed "s/{config-servers}/$conf_servers/g" > ./tmp-ws/pod-$mg_name.json
	sed "s/{tagname}/$mg_name/g" ./templates/svc-router-{tagname}.json > ./tmp-ws/svc-$mg_name.json
	
	EXEC_SCRIPT="kubectl create -f ./tmp-ws/pod-$mg_name.json"
	exec_cmd
	EXEC_SCRIPT="kubectl create -f ./tmp-ws/svc-$mg_name.json"
	exec_cmd
}

function clean
{
	echo "todo todo..."
}

function print_usage
{
	echo "Shell utility for creating vms in Google Compute Engine, usage:"
  echo "-c : command create-master|create-slave|delete"
  echo "-n : names of vm, commas separated, example: name-1,name-2"
  echo "-d : dry run flag. Only print the command to execute, DO NOT execute. for debugging."
}


### main ###########

ARG_CMD=
ARG_NAMES=
ARG_PROJECT_ID=lab-larry
ARG_DRY_RUN=0
ARG_KEEP_WORKSPACE=0
EXEC_SCRIPT=
MYSCOPE="https://www.googleapis.com/auth/cloud-platform"
BASE_CREATE="gcloud compute --project \"$ARG_PROJECT_ID\""
BASE_SCRIPT="--zone \"asia-east1-b\" --network \"default\""
BASE_SCRIPT="$BASE_SCRIPT --machine-type \"n1-standard-1\""
BASE_SCRIPT="$BASE_SCRIPT --maintenance-policy \"MIGRATE\""
BASE_SCRIPT="$BASE_SCRIPT --scopes \"$MYSCOPE\""
BASE_IMAGE="https://www.googleapis.com/compute/v1/projects"
BASE_IMAGE="${BASE_IMAGE}/ubuntu-os-cloud/global/images"
BASE_IMAGE="${BASE_IMAGE}/ubuntu-1404-trusty-v20151113"


VAR_OPTARG_FAIL=0

#Bad arguments
if [ "$#" = 0 ]; then
  VAR_OPTARG_FAIL=1
fi

while getopts  "c:dn:p:" flag
do
  # echo "$flag" $OPTIND $OPTARG
  case "$flag" in
    c) ARG_CMD=$OPTARG; continue; ;;
    n) ARG_NAMES=$OPTARG; continue; ;;
    p) ARG_PROJECT_ID=$OPTARG; continue; ;;
    d) ARG_DRY_RUN=1; continue; ;;
    *) echo "Unknown argument: $flag !"; VAR_OPTARG_FAIL=1; break; ;;
  esac
done

echo "Running parameters: "
echo "ARG_CMD: $ARG_CMD";
echo "ARG_NAMES: $ARG_NAMES";
echo "ARG_PROJECT_ID: $ARG_PROJECT_ID";
echo "ARG_DRY_RUN: $ARG_DRY_RUN";

if [ "$VAR_OPTARG_FAIL" = 1 ]; then
	print_usage
  exit -1
fi

IFS=',' read -a array <<< "$ARG_NAMES"

clear_workspace_folder

mkdir -p ./tmp-ws

if [ "$ARG_CMD" = "create-master" ]; then
	create_master
elif [ "$ARG_CMD" = "create-slave" ]; then
  create_slave
elif [ "$ARG_CMD" = "delete-vms" ]; then
  delete_vms
# elif [ "$ARG_CMD" = "create_router" ]; then
#   create_router
# elif [ "$ARG_CMD" = "delete_disk" ]; then
#   delete_disk
# elif [ "$ARG_CMD" = "delete_service" ]; then
#   create_replica_set
# elif [ "$ARG_CMD" = "delete_container" ]; then
#   delete_container
elif [ "$ARG_CMD" = "clean" ]; then
	clean
else
	echo "unknown command: $ARG_CMD"
  print_usage
fi

if [ "$ARG_KEEP_WORKSPACE" = 0 ]; then
	clear_workspace_folder
fi

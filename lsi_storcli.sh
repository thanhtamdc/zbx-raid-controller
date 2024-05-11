#!/bin/bash
CLI='/opt/MegaRAID/storcli/storcli64'
PATH_CTRL_COUNT='/tmp/ctrl_count'

action=$1
part=$2


if [ ! -f ${CLI} ]; then
    echo "Could not find path: ${CLI}"
    exit
fi

GetCtrlCount() {
    ctrl_count=1
    echo ${ctrl_count} > ${PATH_CTRL_COUNT}
    echo ${ctrl_count}
}


CheckCtrlCount() {
    if [ -f ${PATH_CTRL_COUNT} ]; then
        ctrl_count=$(cat ${PATH_CTRL_COUNT})
        if [ -z ${ctrl_count} ]; then
            ctrl_count=$(GetCtrlCount)
        fi
    else
        ctrl_count=$(GetCtrlCount)
    fi
    echo ${ctrl_count}
}


LLDControllers() {
    ctrl_json=""
    ctrl_id=$(echo 0 | tr -dc '[:print:]')
    ctrl_model=$($CLI /c0 show | grep "Product Name" | cut -f2 -d"=" | sed -e 's/^\s*//')
    ctrl_sn=$($CLI /c0 show | grep "Serial Number" | cut -f2 -d"=" | sed -e 's/^\s*//')
    ctrl_json=${ctrl_json}"{\"{#CTRL.ID}\":\"${ctrl_id}\",\"{#CTRL.MODEL}\":\"${ctrl_model}\",\"{#CTRL.SN}\":\"${ctrl_sn}\"},"
    echo "{\"data\":[$(echo ${ctrl_json} | sed -e 's/,$//')]}"
}

LLDPhysicalDrives() {
    ctrl_id=0
    pd_json=""
    pdn=$($CLI /c0 show all | grep "Physical Drives" | cut -f2 -d"=" | sed -e 's/^\s*//')
    ed_id=252
    for pd_id in $(seq 0 $((${pdn} - 1))); do
        pd_sn=$($CLI /call/vall show all | grep "${ed_id}:${pd_id}" | awk '{print $13}')
        pd_json=${pd_json}"{\"{#CTRL.ID}\":\"${ctrl_id}\",\"{#ED.ID}\":\"${ed_id}\",\"{#PD.ID}\":\"${pd_id}\",\"{#PD.SN}\":\"${pd_sn}\"},"
    done
    echo "{\"data\":[$(echo ${pd_json} | sed -e 's/,$//')]}"
}

LLDLogicalDrives() {
    ctrl_count=1
    ld_json=""
    ldn=$($CLI /c0 show all | grep "Virtual Drives" | cut -f2 -d"=" | sed -e 's/^\s*//')

    for ctrl_id in $(seq 0 $((${ctrl_count} - 1))); do
        for ld_id in $(seq 0 $((${ldn} - 1))); do
            ld_name="$ld_id/$ld_id"
            ld_raid=$($CLI /call/vall show all | grep "$ld_name" | awk '{print $2}')
            ld_json=${ld_json}"{\"{#CTRL.ID}\":\"${ctrl_id}\",\"{#LD.ID}\":\"${ld_id}\",\"{#LD.NAME}\":\"${ld_name}\",\"{#LD.RAID}\":\"${ld_raid}\"},"
        done
    done

    echo "{\"data\":[$(echo ${ld_json} | sed -e 's/,$//')]}"
}


GetControllerStatus() {
    ctrl_id=$1
    ctrl_part=$2
    value=""
    case ${ctrl_part} in
        "main")
            value=$($CLI /c0 show all | grep "Controller Status" | cut -f2 -d"=" | sed -e 's/^\s*//')
        ;;
        "temperature")
            value=$($CLI /c0 show all | grep "ROC temperature(Degree Celsius)" | cut -f2 -d"=" | sed -e 's/^\s*//')
        ;;
        "battery")
            value=$($CLI /c0 show all | grep "BatteryFRU" | cut -f2 -d"=" | sed -e 's/^\s*//')
        ;;
    esac
    echo ${value}
}

GetPhysicalDriveStatus() {
    ctrl_id=$1
    pd_id=$2
    ed_id=$3
    response=$($CLI /call/vall show all | grep "${ed_id}:${pd_id}" | awk '{print $3}')

    if [ -n ${response} ]; then
#       if [ "${response}" == "Onln" ]; then
                echo ${response}
#       fi
    else
        echo "Data not found"
    fi
}

GetLogicalDriveStatus() {
    ctrl_id=$1
    ld_id=$2
    response=$($CLI /call/vall show all | grep "${ld_id}/${ld_id}" | awk '{print $3}')

    if [ -n ${response} ]; then
#       if [ "${response}" == "Optl" ]; then
                echo ${response}
#       fi
    else
        echo "Data not found"
    fi
}

GetPhysicalDriveTemp() {
    ctrl_id=$1
    pd_id=$2
    ed_id=$3
        sl="/c0/e252/s$pd_id"
    response=$($CLI /call/eall/sall show all | grep -A 5 "Drive $sl State" | grep "Drive Temperature" | cut -f2 -d"=" | cut -c3-4 | sed -e 's/^\s*//')

    if [ -n ${response} ]; then
        echo ${response}
    else
        echo "Data not found"
    fi
}

case ${action} in
    "lld")
        case ${part} in
            "ad")
                LLDControllers
            ;;
            "bt")
                LLDBattery
            ;;
            "pd")
                LLDPhysicalDrives
            ;;
            "ld")
                LLDLogicalDrives
            ;;
        esac
    ;;
    "health")
        case ${part} in
            "ad")
                GetControllerStatus $3 $4
            ;;
            "pd")
                GetPhysicalDriveStatus $3 $4 $5
            ;;
            "ld")
                GetLogicalDriveStatus $3 $4
            ;;
            "tmp")
                GetPhysicalDriveTemp $3 $4 $5
            ;;
        esac
    ;;
esac

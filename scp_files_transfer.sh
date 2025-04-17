#!/bin/bash

# Declare variables
declare SERVER_IP
SOURCE_PATH="/home/kouvakis/workspace/latest_robot/robot/"
DESTINATION_PATH="/data/atxuser/robot/"

# Delcare files to be tranfered
declare -a SCP_FILES
#SCP_FILES=(
#"ATS/MOSWA/COMMON/COMMON_PROTOCOLS_2/CFM/NFR_SLM_DMM/NFR_CFM_SLM.robot"
#"ATS/MOSWA/COMMON/COMMON_PROTOCOLS_2/CFM/NFR_SLM_DMM/__init__.robot"
#"ATS/MOSWA/COMMON/COMMON_PROTOCOLS_2/NFR/STATIC_MAC_NFR.robot"
#"ATS/MOSWA/COMMON/COMMON_PROTOCOLS_2/NFR/static_mac_nfr_keywords.resource"
#"ATS/MOSWA/COMMON/COMMON_SERVICES/09__IPFIX/IPFIX_IMPROVEMENTS.robot"
#"ATS/MOSWA/COMMON/COMMON_SERVICES/09__IPFIX/IPFIX_KEYWORDS.resource"
#"ATS/MOSWA/COMMON/COMMON_SERVICES/09__IPFIX/IPFIX_NFR.robot"
#"ATS/MOSWA/COMMON/COMMON_SERVICES/09__IPFIX/IPFIX_TLS.robot"
#"ATS/MOSWA/COMMON/COMMON_SERVICES/09__IPFIX/__init__.robot"
#"ATS/MOSWA/COPPER/HARDENING/ROBUSTNESS/TESTS/IPFIX/__init__.robot"
#"ATS/MOSWA/FIBER/A2A/INTRA_SHELF/08_A2A_TRANSPORT/03__typeB_IPFIX.robot"
#"ATS/MOSWA/OAM/COMMON/OAM_MACRO_VERIFICATION/IPFIX_OAM.robot"
#"BATCH/hostbatch.json"
#"ULKS/MOSWA/NCY_USER_KW/ipfix-collector.sh"
#"ULKS/MOSWA/NCY_USER_KW/ipfix_guide_keywords.resource"
#"ULKS/MOSWA/NCY_USER_KW/ipfix_keywords.resource"
#)

SCP_FILES=("file1" "file2")

usage() {
cat << EOF

Description:
    Transfers files from local server working directory to remote server working direactory.
    Edit script's variables:
        SOURCE_PATH      : Local's server source path.
        e.g:
        SOURCE_PATH="/home/<username>/workspace/robot/"

        DESTINATION_PATH : Remote's server destination path.
        e.g:
        DESTINATION_PATH="/data/<username>/robot/"

        SCP_FILES        :
        e.g:
        SCP_FILES=(
        "ATS/MOSWA/COMMON/COMMON_SERVICES/<file1>"
        "ATS/MOSWA/COMMON/COMMON_SERVICES/<file2>"
        ...
        "ATS/MOSWA/COMMON/COMMON_SERVICES/<fileN>"
        )

Arguments:
    -h | --help     : Show usage of file.
    -s | --server   : Remote server IP address.
    -u | --username : Username in the remote server

Usage:
    ./scp_file_tranfer --server 10.10.10.10 --username <username>

Script will ask remote's server password, for the provided username.

Dependecies:
    sshpass should be installed to local server.

EOF
}

## MAIN ##
parameters=$@

while (( "$#" ))
do
    option=$1

    case ${option} in
    --help|-h)
        usage
        exit 100
        ;;
    --server|-s)
        SERVER_IP=$2
        shift
        ;;
    --username|-u)
        USERNAME=$2
        shift
        ;;
    *)
        echo -e ""
        echo "  [ERROR] Unknown parameter ${option}"
        echo -e ""
        usage
        exit 110
        ;;
    esac
    shift
done

# Check if username argument is provided.
if [[ -z ${USERNAME} ]]; then
    echo "No username provided..."
    usage
    exit 120
fi


# Check if server argument is provided.
if [[ -z ${SERVER_IP} ]]; then
    echo "No server argument provided..."
    usage
    exit 130
else
    # Check server's connectivity
    ping_resp=`ping -c 1 -W 1 "${SERVER_IP}" | grep -o "100% packet loss"`
    if [[ -n "${ping_resp}" ]]; then
        echo "No connectivity with server ${SERVER_IP}"
        exit 140
    fi
fi

# Get password
echo -n "password: "
stty -echo
read PASSWORD
stty echo
echo ""

# Check if password is empty
if [[ -z ${PASSWORD} ]]; then
    echo "No password provided..."
    exit 150
fi


# Check username & password for server.
sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${SERVER_IP} echo
if [[ "$?" -ne 0 ]]; then
    echo "username or password faillure."
    exit 140
fi

# Start transfering files.
for index in ${!SCP_FILES[@]}; do

    filename="${SCP_FILES[${index}]}"
    source="${SOURCE_PATH}${filename}"
    destination="${DESTINATION_PATH}${filename}"

    #echo "source = ${source}"
    #echo "destination = ${destination}"
    if [[ ! -f ${source} ]]; then
        echo "${source} not found..."
        continue
    fi

    sshpass -p ${PASSWORD} scp ${source} ${USERNAME}@${SERVER_IP}:${destination}

    [[ "$?" -eq 0 ]] && echo -e "$((index+=1)) -${filename} --- SUCCESS\n" || echo -e "$((index+=1)) - ${filename} --- FAILED\n"
done

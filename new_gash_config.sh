#!/bin/bash

# Define Arrays
declare -a RELEASES
declare -a BUILDS
declare -a POSITIONAL
declare -A MGMT_CPMS_IPS

# Define Variables
declare release
declare build

# Directories
link_dir=/usr/global/bin/link_dir
image_dir=/usr/global/images/7750mg

# Executable files
powercycle_vms_only=${HOME}/ws/gash/bin/powercycleVMs.py
powercycle_hw_only=${HOME}/ws/gash/bin/powercycle.tcl
copy_cmg_images=${HOME}/ws/gash/tools/cmg/copycmgimages.sh
run_gash_file=/usr/global/tools/lte/bin/rungash

# "rvars.sh" is created when "restore_gash.sh" is executed, so it should be there!
rvars_file=${HOME}/rvars.sh

# Check if secure TB
if [ -e "/opt/securebed" ]
then
    restore_gash_file=/usr/global/bin/secure_restore_gash.sh
else
    restore_gash_file=/usr/global/bin/restore_gash
fi

# Default parameters for 'restore_gash.sh'
phys_topo=lteDefault
sub_topo=vfp
power_cycle=true
mgplus=false

# Default Parameters
restore_gash=true
run_gash_arg=false
testbed=`id -nu`

debug=true

## Function Definitions 
get_git_release_tag()
{
    local dir=$1
    git_tag_file=${dir}/cvs_branch

    if [ ! -f "${git_tag_file}" ]
    then
        echo "File ${git_tag_file} does not exist"
        exit 200
    else
        git_release_tag=`cat ${git_tag_file}`
    fi
}

get_git_build_tag()
{
    local dir=$1
    git_build_file=${dir}/cvs_tag

    if [ ! -f "${git_build_file}" ]
    then
        echo "File ${git_build_file} does not exist"
        exit 201
    else
        git_build_tag=`cat ${git_build_file}`
    fi
}

copy_images()
{
    ${link_dir} ${build} 7750mg/${release}
    ${copy_cmg_images}

    local ret=$?
    if [ "${ret}" != "0" ]
    then
        echo "$(tput setaf 1)Failed to copy image files.$(tput sgr 0)"
        exit ${ret}
    fi
}

get_all_releases_from_image_dir() {
    local dir=$1
    RELEASES=(`ls ${dir} | sort -n | tr '\n' ' '`)
}

get_all_builds_from_release_dir() {
    local dir=$1
    BUILDS=(`ls ${dir} | sort -n | tr '\n' ' '`)
}

exec_restore_gash_cmd() {

    local restore_gash_cmd="${restore_gash_file} -git_tag ${git_release_tag} -physTopology ${phys_topo} -subTopology ${sub_topo} -powercycle ${power_cycle} ${POSITIONAL[@]}"
    eval ${restore_gash_cmd}
#    ${restore_gash_file} -git_tag ${git_release_tag} -physTopology ${phys_topo} -subTopology ${sub_topo} -powercycle ${power_cycle} ${POSITIONAL[@]}

    local ret=$?
    if [ "${ret}" != "0" ]
    then
        echo "$(tput setaf 1)Failed to do restore_gash.$(tput sgr 0)"
        exit $ret
    fi
}

debugOn_check_parameters() {

    if [ "${restore_gash}" = "true" ]
    then
        # Take the command, as it is from function "exec_restore_gash_cmd".
        local restore_gash_cmd="${restore_gash_file} -git_tag ${git_release_tag} -physTopology ${phys_topo} -subTopology ${sub_topo} -powercycle ${power_cycle} ${POSITIONAL[@]}"
    else
        restore_gash_cmd="${restore_gash}"
    fi

    echo ""
    echo "PARAMETERS                  : ${parameters[@]}"
    echo "RELEASE                     : ${release}"
    echo "BUILD                       : ${build}"
    echo "GIT_RELEASE_TAG             : ${git_release_tag}"
    echo "GIT_BUILD_TAG               : ${git_build_tag}"
    echo "MGPLUS_TOPO                 : ${mgplus}"
    echo "POWERCYCLE                  : ${power_cycle}"
    echo "PHYSTOPOLOGY                : ${phys_topo}"
    echo "SUBTOPOLOGY                 : ${sub_topo}"
    echo "RUN_GASH                    : ${run_gash_arg}"
    echo "RESTORE_GASH                : ${restore_gash_cmd}"
    echo "EXTRA_ARGs_FOR_RESTORE_GASH : ${POSITIONAL[@]}"
    echo ""

    sleep 2
}

exec_rungash_cmd() {

    if [ "${run_gash_arg}" = "true" ]
    then
        local rungash_cmd="${run_gash_file}"
    else
        local rungash_cmd="${run_gash_file} ${run_gash_arg}"
    fi
    echo -e "Running gash........\n${rungash_cmd}"
    eval ${rungash_cmd}
}

get_dutc_cpm_ip() {

    # NOTE: In case of real HW env, 1st IP is the console IP, 2nd IP is the management IP
    # so get the management IP to PING!!
    local ip_addr=`egrep -o "ESR.C.CPM.A\s+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" ${rvars_file} | awk '{print $2}' | tail -1`
    echo "${ip_addr}"
}

get_mgmt_cpm_ips() {
    # Local array declaration
    declare -a arrayMgmtCpmIps
    declare -a arrayMgmtCpmNames
    local mgmt_cpm_ips=`egrep -o "ESR\.[A-Z]\.CPM.A\s+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" ${rvars_file} | sort | awk '{print $2}' | tr "\n" " "`
    local mgmt_cpm_names=`egrep -o "ESR\.[A-Z]\.CPM.A\s+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" ${rvars_file} | sort | awk '{print $1}' | tr "\n" " "`
    IFS=' ' read -r -a arrayMgmtCpmIps <<< "${mgmt_cpm_ips}"
    IFS=' ' read -r -a arrayMgmtCpmNames <<< "${mgmt_cpm_names}"
    if [ ${#arrayMgmtCpmIps[@]} -ne ${#arrayMgmtCpmNames[@]} ]
    then
        echo "$(tput setaf 1)Error while getting management CPM IPs.$(tput sgr 0)"
    else
        # Create associative array, by combining arrays "arrayMgmtCpmNames" & "arrayMgmtCpmIps"
        # MGMT_CPMS_IPS=( ${arrayMgmtCpmNames[@]} ${arrayMgmtCpmIps[@]} ) -- not working...
        for i in ${!arrayMgmtCpmIps[@]}
        do
            MGMT_CPMS_IPS[${arrayMgmtCpmNames[i]}]=${arrayMgmtCpmIps[i]}
        done
    fi
}

wait_for_cpm_to_boot() {

    local count=0
    local MAX_TIMEOUT=40

    echo -ne "\nWaiting ${MAX_TIMEOUT} sec for CPM blades to boot "
    while [ "${count}" -lt "${MAX_TIMEOUT}" ]
    do
        ((count++))
        if [ $(( count % 5 )) = 0 ]
        then
            echo -n "${count}"
        else
            echo -n "."
        fi
        sleep 1
    done
    echo ""
}

wait_for_dut_to_boot() {

    local ping_resp
    local count=0
    local MAX_TIMEOUT=1500

    echo -ne "Waiting for DUTs to boot "

    while [ "${count}" -lt "${MAX_TIMEOUT}" ]
    do
        ((count++))
        if [ $(( count % 5 )) = 0 ]
        then
            echo -n "${count}"
        else
            echo -n "."
        fi

        ping_resp=`ping -c 1 -W 1 "$1" | grep -o "100% packet loss"`
        [ -z "${ping_resp}" ] && break
    done

    if [ "${count}" -eq "${MAX_TIMEOUT}" ]
    then
        echo -e "\nMAX_TIMEOUT exceeded..."
    else
        echo -e "\nDUTs are up after ${count} sec"
    fi
}

wait_for_all_duts_to_boot() {
    local ping_resp
    local count=0
    local MAX_TIMEOUT=2000

    echo "Waiting for all DUTs to boot "
    for dut_cpm in ${!MGMT_CPMS_IPS[@]}
    do
        dut_name=`echo ${dut_cpm} | awk -F "." '{print $2}'`
        echo -ne "\nTrying CPM.A IP: ${MGMT_CPMS_IPS[${dut_cpm}]} -- Dut-${dut_name}: "
        while [ "${count}" -lt "${MAX_TIMEOUT}" ]
        do
            ((count++))
            if [ $(( count % 5 )) = 0 ]
            then
                echo -n "${count}"
            else
                echo -n "."
            fi
            ping_resp=`ping -c 1 -W 1 "${MGMT_CPMS_IPS[$dut_cpm]}" | grep -o "100% packet loss"`
            [ -z "${ping_resp}" ] && break
        done

        if [ "${count}" -eq "${MAX_TIMEOUT}" ]
        then
            echo -e "\nMAX_TIMEOUT exceeded for Dut-${dut_name} "
        else
            echo -e "\nDut-${dut_name} is up after ${count} seconds "
        fi
    done
}

usage() {
cat << EOF

Usage:
    Wrapper script for "link_dir", "copycmgimages.sh", "restore_gash.sh" and "rungash".
    - Gets the appropriate "git_tag", according to "release" and "build".
    - Uses "link_dir" to create the soft links, according to "release" and "build".
    - Uses "copycmgimages.sh" to copy the image files.
    - Uses "restore_gash.sh" to configure GASH.
    - Uses "rungash" to load GASH.

Flags:
    Mandatory:
        -release        : Release number (e.g. 11.0).

    Optional:
        -build          : Build number. If not provided, will take "latest" build for release "0.0" and "latest_s" fol all other releases.
        -mgplus         : Default value "false". If "true", adds "-network_top mgplus.top" to "restore_gash.sh" (e.g. for DoCoMo test-suites).
        -powercycle     : Default value "true". Set to "false", NOT to powercycle the VMs.
        -physTopology   : Default value "lteDefault".
        -subTopology    : Default value "vfp".
        -restoreGash    : Default value "true". Set to "false", NOT to execute "restore_gash.sh" (e.g. change only build in our environment).
        -runGash        : Default value "false". Set to "true", to load GASH in a clean state.
                          NOTE: runGash accepts the arguments from "rungash" python script, but arguments need to be enclosed in double-quotes.
                          e.g: new_gash_config -release 11.0 -runGash "-S <suiteName> -R ' -params_dir /tmp'"

    All other possible flags or values are evaluated by "restore_gash.sh".

Hints:
    - Easy access to all releases:
        new_gash_config.sh -release X

    - Easy access to all builds from release:
        new_gash_config.sh -release 11.0 -build X

Examples:
    new_gash_config -release 11.0 -build S623
    new_gash_config -release 11.0 -mgplus true -powercycle false
    new_gash_config -release 11.0 -physTopology cupsThreeDut -subTopology dbNK
    new_gash_config -release 12.0 -restoreGash false -runGash true
    new_gash_config -release 12.0 -build latest_p -runGash "-S <suiteName> -R ' -runRegressInclude beta -runLevel extreme -skipPrePost true'"

EOF
}

## MAIN ##

parameters=$@

while (( "$#" ))
do
    key=$1

    case $key in
        -h|--help)
            usage
            exit 100
         ;;
        -release)
            if [[ "$2" =~ ^-.* ]] || [[ -z "$2" ]]
            then
                release=""
                shift
            else
                release=$2
                shift 2
            fi
            ;;
        -build)
            if [[ "$2" =~ ^-.* ]] || [[ -z "$2" ]]
            then
                build=""
                shift
            else
                build="$2"
                shift 2
            fi
            ;;
        -physTopology)
            if [[ "$2" =~ ^-.* ]] || [[ -z "$2" ]]
            then
                shift
            else
                phys_topo="$2"
                shift 2
            fi
            ;;
        -subTopology)
            if [[ "$2" =~ ^-.* ]] || [[ -z "$2" ]]
            then
                shift
            else
                sub_topo="$2"
                shift 2
            fi
            ;;
        -mgplus)
            if [[ "$2" =~ ^-.* ]] || [[ -z "$2" ]]
            then
                shift
            else
                mgplus="$2"
                if [ "${mgplus}" = "true" ]
                then
                    POSITIONAL+=("-network_top mgplus.top")
                fi
            fi
            shift 2
            ;;
        -powercycle)
            if [[ "$2" =~ ^-.* ]] || [[ -z "$2" ]]
            then
                shift
            else
                power_cycle="$2"
                shift 2
            fi
            ;;
        -restoreGash)
            if [[ "$2" =~ ^-.* ]] || [[ -z "$2" ]]
            then
                shift
            else
                restore_gash="$2"
                shift 2
            fi
            ;;
        -runGash)
            if [[ "$2" =~ ^-.* ]] || [[ -n "$2" ]]
            then
                run_gash_arg=$2
                shift 2
            elif [[ -z "$2" ]]
            then
                run_gash_arg=false
                shift
            fi
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Check if exec files exist
if [ ! -f "${copy_cmg_images}" ] || [ ! -f "${restore_gash_file}" ]
then
    echo -e "One of the following exec files does not exist: \n${copy_cmg_images} \n${restore_gash_file}"
    exit 101
fi

# Check image directory
if [ ! -d "${image_dir}" ]
then
    echo "Image directory ${image_dir} does not exist."
    exit 102
fi

# Get RELEASE array
get_all_releases_from_image_dir "${image_dir}"

# Check RELEASES array 
if [ -z "${RELEASES}" ]
then
    echo "No releases found under directory ${image_dir}."
    exit 103
fi

# Select "latest" or "latest_s", if "-build" flag is not specified
if [ -z "${release}" ]
then
    usage
    exit 104
elif [ "${release}" = "0.0" ] && [ -z "${build}" ]
then
    build="latest"
elif [ -z "${build}" ]
then
    build="latest_s"
fi

# Create release and build directories
release_dir="${image_dir}/${release}"
build_dir="${release_dir}/${build}"

# Check release directory
if [ ! -d "${release_dir}" ]
then
    echo -e "Release directory ${release_dir} not found. Please select one of the following:\n"
    echo "${RELEASES[@]}"
    exit 105
fi

get_all_builds_from_release_dir "${release_dir}"

# Check build directory
if [ ! -d "${build_dir}" ]
then
    echo -e "build directory ${build_dir} not found. Please select one of the following:\n"
    echo "${BUILDS[@]}"
    exit 106
fi

get_git_release_tag "${build_dir}"
get_git_build_tag "${build_dir}"
copy_images

if [ "${debug}" = "true" ]
then
    debugOn_check_parameters
fi

# Execute "restore_gash"
if [ "${restore_gash}" = "true" ]
then
    exec_restore_gash_cmd
elif [ "${power_cycle}" = "true" ]
then
    # Check for HYP IP address
    hypervisor_ip=`egrep "HYP.[0-9]\s+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" ${rvars_file}`
    if [ -z "${hypervisor_ip}" ]
    then
        # Powercycle for real HW env
        echo "No Hypervisor found... powercycle real HW env!"
        powercycle_cmd="${powercycle_hw_only} ${testbed} reset"
    else
        # Powercyvle for env with VMs
        powercycle_cmd="${powercycle_vms_only} ${testbed}" 
    fi
    eval ${powercycle_cmd}
    rc=$?
    if [ "${rc}" != "0" ]
    then
        echo "$(tput setaf 1)Failed to reboot the DUTs.$(tput sgr 0)"
        exit ${rc}
    fi
fi

# Execute "rungash"
if [ "${run_gash_arg}" != "false" ]
then
    sleep 5
    dutc_cpm_ip=$(get_dutc_cpm_ip)
    if [[ "${phys_topo}" == "cupsFiveDut" ]] || [[ "${phys_topo}" == "cupsSevenDut" ]]
    then
        get_mgmt_cpm_ips
        # Error case
        if [ ${#MGMT_CPMS_IPS[@]} -eq 0 ]
        then
            wait_for_dut_to_boot "${dutc_cpm_ip}"
        # normal case
        else
            wait_for_all_duts_to_boot
        fi
    else
        wait_for_dut_to_boot "${dutc_cpm_ip}"
    fi
    wait_for_cpm_to_boot
    exec_rungash_cmd
fi

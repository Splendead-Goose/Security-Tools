#!/usr/bin/bash

##########################
### NMAP Report Script ###
###  Created by Goose  ###
##########################

### Variables ###
nopts='-F'
exopts=""
logs=0
hosterr="ERROR: Please Specify Server Or File List"
filelogerr="ERROR: Using File List Requires Logging Directory"

### Functions ###
usage () {
	cat << EOF
$0 runs nmap report for servers

Options:
    -h			Shows this message
    -s [server_name]	Specify server to run report for
    -f [file_list]	Specify file list of hosts to scan
    -p [port_number]	Specify port(s) or a range
    -c			Runs nmap on 100 common ports
    -n			Runs nmap on 1000 normal ports
    -e			Add extra script output for nmap
    -l [log_dir]	Specify logging directory for output

Requirements:
    Flag '-s [server_name]' or -f '[file_list]' is required
    Flag '-l [log_dir]' is required when using '-f [file_list]'
    nmap installed and in PATH

Defaults:
    Runs nmap in fast mode '-c' to cover most common 100 ports

Examples:
    $0 -s foo.example.bar -p 80,443 -e
    $0 -s somehostname -n
    $0 -f /tmp/list.txt -l /tmp/ -c
EOF
}

testflags () {
	echo $nopts
	echo $exopts
	echo $filelist
	echo $logs
}

createlog () {
	logname="$1-$(date '+%Y%m%d-%H%M')-nmap.txt"
	logfile="$logdir/$logname"
}

runreport () {
	echo "Generating NMAP Report for $1"
	echo ""
	nmapreport $1
}

nmapreport () {
	echo "NMAP Results:"
	nmap -sT -sV -Pn $exopts $nopts $1 | grep -v -e "Service detection" -e "service unrecognized" -e "TCP:" -e "SF:"
	echo ""
}

### Pre-Flight ###

# Get Flags
while getopts "s:p:f:l:hcne" opt; do
	case ${opt} in
		h ) usage
		    exit ;;
		s ) host=${OPTARG} ;;
		p ) nopts="-p ${OPTARG}" ;;
		f ) filelist=${OPTARG} ;;
		c ) nopts='-F' ;;
		n ) nopts="" ;;
		e ) exopts='-A' ;;
		l ) logs=1
		    logdir=${OPTARG} ;;
		\?) exit 1 ;; #Invalid Option
		: ) exit 1 ;; #Missing Argument
	esac
done

# Check for Nothing
if [[ -z "${1}" ]]; then
	usage
	exit
fi

# Check for Hosts
if [[ -z "${host}" ]] && [[ -z "${filelist}" ]]; then
	echo "$hosterr"
	exit 1
fi

# Check File List and Logs
if [[ -n "${filelist}" ]] && [[ $logs = 0 ]]; then
	echo "$filelogerr"
	exit 1
fi

### Do Work ###

# Run Report
if [[ -n "${filelist}" ]]; then
	for server in $(cat ${filelist}); do
		createlog $server
		echo "Output: $logfile"
		runreport $server > $logfile 2>&1
	done
elif [[ $logs = 1 ]]; then
	createlog $host
	echo "Output: $logfile"
	runreport $host > $logfile 2>&1
else
	runreport $host
fi

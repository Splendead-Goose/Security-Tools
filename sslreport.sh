#!/usr/bin/bash

#########################
### SSL Report Script ###
### Created by: Goose ###
#########################

### Variables ###
port=443
sshport=22
opensslscan=0
nmapscan=0
ctext=""
weakscan=0
wtext=""
logs=0
sshovr="SSH Port Detected - Running nmap Only"
hosterr="ERROR: Please Specify Server Or File List"
filelogerr="ERROR: Using File List Requires Logging Directory"
scanerr="ERROR: Please Choose A Scan Type"

### Functions ###
usage () {
	cat << EOF
$0 runs SSL reports using nmap and sslscan

Options:
    -h			Shows this message
    -s [server_name]	Specify server to run report for
    -f [file_list]	Specify file list of hosts to scan
    -p [port_number]	Specify port - Default is 443
    -o			Run openssl report
    -n			Run nmap report
    -c			Add SSL Cipher output for nmap
    -w			Run sslscan report
    -l [log_dir]	Specify logging directory for output

Requirements:
    Flag '-s [server_name]' or -f '[file_list]' is required
    Flag '-l [log_dir]' is required when using '-f [file_list]'
    openssl, nmap and sslscan installed

Defaults:
    Port is '443' by default - Override with '-p [port_number]'
    Running a sslscan report with logging will turn off colors
    Will only run a nmap report when using SSH port $sshport

Examples:
    $0 -s foo.example.bar -oncw
    $0 -s rabbitmq.ssl -p 15671 -o
    $0 -f /tmp/list.txt -l /tmp/ -oncw
EOF
}

testflags () {
	echo $host
	echo $port
	echo $filelist
	echo $opensslscan
	echo $nmapscan
	echo $ctext
	echo $weakscan
	echo $wtext
	echo $logs
}

createlog () {
	logname="$1-$(date '+%Y%m%d-%H%M')-ssl.txt"
	logfile="$logdir/$logname"
}

runreport () {
	echo "Generating SSL Report for $1"
	echo ""
	if [[ $opensslscan = 1 ]]; then
		opensslreport $1
	fi
	if [[ $nmapscan = 1 ]]; then
		nmapreport $1
	fi
	if [[ $weakscan = 1 ]]; then
		weakreport $1
	fi
}

opensslreport () {
	echo "SSL Certificate:"
        echo | openssl s_client -showcerts -servername $1 -connect $1:$port 2>/dev/null | openssl x509 -inform pem -noout -text | grep -e "DNS" -e "Issuer:" -e "Validity" -e "Not Before" -e "Not After" -e "Alternative" -e "Subject:"
	echo ""
}

nmapreport () {
	echo "NMAP Results:"
	nmap -sT -sV -Pn $ctext -p $port $1 | grep -v -e "Service detection" -e "service unrecognized" -e "TCP:" -e "SF:"
	echo ""
}

weakreport () {
	echo "SSL Scan Report:"
	sslscan $wtext $1:$port
	echo ""
}

### Pre-Flight ###

# Get Flags
while getopts "s:p:f:l:honcw" opt; do
	case ${opt} in
		h ) usage
		    exit ;;
		s ) host=${OPTARG} ;;
		p ) port=${OPTARG} ;;
		f ) filelist=${OPTARG} ;;
		o ) opensslscan=1 ;;
		n ) nmapscan=1 ;;
		c ) ctext='--script ssl-enum-ciphers' ;;
		w ) weakscan=1 ;;
		l ) logs=1
		    logdir=${OPTARG}
		    wtext='--no-colour' ;;
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

# Check for a Scan Type
if [[ $opensslscan = 0 ]] && [[ $nmapscan = 0 ]] && [[ $weakscan = 0 ]]; then
	echo "$scanerr"
	exit 1
fi

# NMAP Only if SSH Port
if [[ $port = $sshport ]]; then
	echo "$sshovr"
	echo ""
	opensslscan=0
	nmapscan=1
	ctext='--script ssh2-enum-algos'
	weakscan=0
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

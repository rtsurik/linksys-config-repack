#!/bin/bash 

# linksys-config-repack 2017-05-16
# This tool repacks/modifies a Linksys backup file
# and allows to change some config settings not available via GUI
# 
# Usage example:
# ./linksys-config-repack.sh -f ./backup.cfg -o ./backup_new.cfg -s "s:rip_interface_wan=1:rip_interface_wan=0:"
#
# (C) 2017 Rustam Tsurik

mk_tmp_dirs() {
	TMP_DIR=$(mktemp -d ${TMPDIR:-/var/tmp}/linksys-config-repack-XXXXXXXXXX)
	trap "rm -rf $CHROOT_DIR" EXIT TERM INT
}

backup_unpack() {
	printf >&2 'Unpacking the backup... '

	# skip the header and unpack	
	dd if="${BACKUP_FILENAME}" skip=12 bs=1 2>/dev/null | tar -xz -C "${TMP_DIR}"	
	[ -f "${TMP_DIR}/tmp/syscfg.tmp" ] || exit 1; # need a proper error reporting here?

	printf >&2 '\t [done]\n'
}

backup_repack() {	
	printf >&2 'Repacking... '

	REPACKED_PAYLOAD="${TMP_DIR}/payload.tar.gz"
	REPACKED_FILE="${TMP_DIR}/repacked_backup.data"

	# create a payload, the just a regular tar.gz archive
	tar -c -C "${TMP_DIR}/" tmp var | gzip --best > "${REPACKED_PAYLOAD}"
	PAYLOAD_SIZE=$(wc -c "${REPACKED_PAYLOAD}" | awk '{print $1}')
	
	# header + payload
	printf "0x0002\x0a" > "${REPACKED_FILE}"
	printf "${PAYLOAD_SIZE}\x0a" >> "${REPACKED_FILE}"
	cat "${REPACKED_PAYLOAD}" >> "${REPACKED_FILE}"

	if [ -z $OUTPUT_FILENAME ] ; then
		cat "$REPACKED_FILE"
	else
		mv "$REPACKED_FILE" "$OUTPUT_FILENAME"
	fi

	printf >&2 '\t\t\t [done]\n'
}

backup_not_found() {
	printf >&2 "%s: backup file not found\n" "$0"
	exit 1;
}

edit_configs() {
	printf >&2 "Updating tmp/syscfg.tmp"
	sed -i "$TMP_DIR/tmp/syscfg.tmp" -e "$SED_RULE"
	printf >&2 "\t\t [done]\n"
}

usage() {
	printf >&2 '%s: [-f filename] [-o output filename] [-s sed rule]\n' "$0"
	exit 1;
}

# initialize variables
BACKUP_FILENAME=""
OUTPUT_FILENAME=""
SED_RULE=""

while getopts "hf:o:s:" opt; do
	case $opt in
		f)
			BACKUP_FILENAME=$OPTARG
			;;
		o)	OUTPUT_FILENAME=$OPTARG
			;;
		s)	SED_RULE=$OPTARG
			;;
		*)
			usage
			;;
	esac
done

[ -z $BACKUP_FILENAME ] && usage
[ -z $OUTPUT_FILENAME ] && usage
[ -f $BACKUP_FILENAME ] || backup_not_found

mk_tmp_dirs
backup_unpack
[ -z $SED_RULE ] || edit_configs
backup_repack

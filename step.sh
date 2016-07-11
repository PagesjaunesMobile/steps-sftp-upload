#!/bin/bash

#
# NOTE:
#  the raw-ssh-key parameter is a multiline input -> will be directly retrieved from the environment
#


THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#echo $(ruby -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION')
#curl -O https://raw.githubusercontent.com/net-ssh/net-ssh/master/net-ssh-public_cert.pem
#gem cert --add net-ssh-public_cert.pem
##gem install net-sftp  #-P HighSecurity

formatted_output_file_path=''
if [ -n "${BITRISE_STEP_FORMATTED_OUTPUT_FILE_PATH}" ] ; then
	formatted_output_file_path="${BITRISE_STEP_FORMATTED_OUTPUT_FILE_PATH}"
fi

ruby "${THIS_SCRIPT_DIR}/sftp_upload.rb" \
	--source-dir="${upload_source_path}" \
	--dest-dir="${upload_target_path}" \

exit $?

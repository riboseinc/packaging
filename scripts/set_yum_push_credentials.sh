#!/bin/bash

NETRC_PATH=~/.netrc
GIT_HTTPS_USERNAME=$1
GIT_HTTPS_PASSWORD=$2

echo "machine github.com
  login ${GIT_HTTPS_USERNAME}
  password ${GIT_HTTPS_PASSWORD}
" > ${NETRC_PATH}


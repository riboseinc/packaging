#!/bin/bash

yum install -y git createrepo

base=$(cd "$(dirname "$0")"; pwd)
root=$(cd "${base}/../"; pwd)

${root}/set_yum_push_credentials.sh ${REPO_USERNAME} ${REPO_PASSWORD}
${root}/import_packaging_key.sh ${PACKAGER_KEY_PATH}

#!/bin/bash

package_name=mydumper

base=$(cd "$(dirname "$0")"; pwd)
root=$(cd "${base}/../"; pwd)
echo "base is ${base}"
echo "root is ${root}"

${base}/_common.sh

repo_name=rpm-specs
repo_path=/usr/local/${repo_name}
if [ ! -d ${repo_path} ] && [ ! -d ${repo_path}/.git ]; then
  git clone --depth 1 https://github.com/riboseinc/${repo_name} ${repo_path}
fi

#pushd ${repo_path}/${package_name}

# TODO: change rpm-specs repo to use a consistent name in prepare.sh
package_path=/usr/local/${package_name}
mkdir -p ${package_path}
cp -ra ${repo_path}/${package_name}/* ${package_path}/
pushd ${package_path}

./prepare.sh

${root}/publish_rpmbuild_to_yum.sh


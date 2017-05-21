#!/bin/bash

yum install -y git createrepo

base=$(cd "$(dirname "$0")"; pwd)
root=$(cd "${base}/../"; pwd)
echo "base is ${base}"
echo "root is ${root}"

${root}/import_packaging_key.sh ${root}/ribose-packager.key

package_name=rnp
package_path=/usr/local/${package_name}
if [ ! -d ${package_path} ] && [ ! -d ${package_path}/.git ]; then
  git clone --depth 1 https://github.com/riboseinc/${package_name} ${package_path}
fi
pushd ${package_path}

packaging/redhat/extra/prepare_build.sh

${root}/import_packaging_key.sh ${root}/ribose-packager.key

./remove_artifacts.sh
packaging/redhat/extra/build_rpm.sh

${root}/publish_rpmbuild_to_yum.sh

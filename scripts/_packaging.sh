#!/bin/bash

readonly __progname=$(basename $0)

base=$(cd "$(dirname "$0")"; pwd)
scripts=$(cd "${base}/../scripts"; pwd)

errx() {
	echo -e "$__progname: $@" >&2
	exit 1
}

install_basic_packages() {
  yum install -y epel-release

  yum install -y git createrepo automake autoconf libtool make gcc-c++ \
    rpmdevtools wget epel-rpm-macros rpm-sign expect
}

set_creds_and_key() {
  ${scripts}/set_yum_push_credentials.sh "${REPO_USERNAME}" "${REPO_PASSWORD}"
  ${scripts}/import_packaging_key.sh ${PACKAGER_KEY_PATH}
}

fetch_spec_from_ribose_specs() {
  readonly local p_name=$1
  [ -z "${p_name}" ] && errx "no p_name provided to $0"

  # TODO: change rpm-specs repo to use a consistent name in prepare.sh
  readonly local p_path=/usr/local/${p_name}
  echo "${p_path}"

  readonly local repo_name=rpm-specs
  readonly local repo_path=/usr/local/${repo_name}
  if [ ! -d ${repo_path} ] && [ ! -d ${repo_path}/.git ]; then
    git clone --quiet --depth 1 https://github.com/riboseinc/${repo_name} ${repo_path} || errx "git clone"
  else
    pushd ${repo_path}
    git stash --quiet || errx "git stash"
    git pull --quiet || errx "git pull"
  fi

  mkdir -p ${p_path} || errx "mkdir"
  cp -ra ${repo_path}/${p_name}/* ${p_path}/

  return 0
}

the_works() {
  readonly local package_name=$1
  [ -z "${package_name}" ] && errx "no package_name provided"

  install_basic_packages
  set_creds_and_key
  readonly local package_path="$(fetch_spec_from_ribose_specs ${package_name})"
  [[ $? -ne 0 ]] && errx "failed to fetch spec"

  echo "PACKAGE PATH IS ${package_path}"
  pushd ${package_path} || errx "failed to enter package path"
  ./prepare.sh || errx "failed to prepare"

  ${scripts}/publish_rpmbuild_to_yum.sh
}

export RPMBUILD_FLAGS="-v -ba"


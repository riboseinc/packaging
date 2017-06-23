#!/bin/bash -x

errx() {
  readonly __progname=$(basename ${BASH_SOURCE})
	echo -e "${__progname}: $@" >&2
	exit 1
}

setup_env() {
  # We mark our packages for el7 not el7.centos
  sed -i 's/el7.centos/el7/' /etc/rpm/macros.dist
  export RPMBUILD_FLAGS="-v -ba"

  install_basic_packages
  set_creds_and_key
}

update_repo() {
  dest_path=$1

  createrepo --update --delta ${dest_path}
  rm -f ${dest_path}/repodata/repomd.xml.asc
  gpg --detach-sign --armor ${dest_path}/repodata/repomd.xml
}

install_basic_packages() {
  yum install -y epel-release

  yum install -y git createrepo automake autoconf libtool make gcc-c++ \
    rpmdevtools wget epel-rpm-macros rpm-sign expect
}

set_creds_and_key() {
  scripts=$(dirname $(readlink -f ${BASH_SOURCE}))
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
    popd
  fi

  mkdir -p ${p_path} || errx "mkdir"
  cp -ra ${repo_path}/${p_name}/* ${p_path}/

  return 0
}

the_works() {
  readonly local package_name=$1
  [ -z "${package_name}" ] && errx "no package_name provided"

  setup_env

  readonly local package_path="$(fetch_spec_from_ribose_specs ${package_name})"
  [[ $? -ne 0 ]] && errx "failed to fetch spec"

  echo "PACKAGE PATH IS ${package_path}"
  pushd ${package_path} || errx "failed to enter package path"
  ./prepare.sh || errx "failed to prepare"
  popd

  pull_yum
  update_yum_srpm
  update_yum_rpm
  commit_repo
}

readonly yumpath=/usr/local/yum

pull_yum() {
  if [ ! -d ${yumpath} ] || [ ! -d ${yumpath}/.git ]; then

    mkdir -p ${yumpath}
    ls -al ${yumpath}
    echo "Cloning into ${yumpath}..." >&2
    pushd ${yumpath}
    git clone --depth 1 https://github.com/riboseinc/yum .
    popd

  else

    echo "Updating ${yumpath}..." >&2
    pushd ${yumpath}
    git stash
    git checkout master
    git reset --hard origin/master
    git pull
    popd

  fi
}

# TODO: make this script understand whether to push SRPMS or not. Erlang SRPM
# fails due to file size over 100MB.

readonly max_file_size=100000000
readonly rpmbuild_path=/root/rpmbuild

copy_to_repo_and_update() {
  source_path=$1
  dest_path=$2

  mkdir -p ${dest_path}
  for f in ${source_path}/*.rpm; do
    local size=$( wc -c "${f}" | awk '{print $1}' )
    # If SRPM filesize exceeds max size, skip this step.
    if [ ${size} -gt ${max_file_size} ]; then
      echo "Skipping ${f} file since it is too large" >&2
      continue
    fi

    cp ${f} ${dest_path}

  done

  update_repo ${dest_path}
}

sign_packages() {
  scripts=$(dirname $(readlink -f ${BASH_SOURCE}))
  for f in ${1}/*.rpm; do
    ${scripts}/rpmsign.exp ${f}
  done
}

update_yum_srpm() {
  # Update SRPM repo
  sign_packages ${rpmbuild_path}/SRPMS
  copy_to_repo_and_update ${rpmbuild_path}/SRPMS ${yumpath}/SRPMS/
}

# Update RPMS repos
update_yum_rpm() {
  rpmpath="${rpmbuild_path}/RPMS"
  arches=$(ls ${yumpath}/RPMS)

  for arch in ${arches}; do
    dest=${yumpath}/RPMS/${arch}
    src=${rpmpath}/${arch}
    sign_packages ${src}

    if [ -d ${src} ]; then
      continue
    fi

    if [ "${arch}" != "noarch" ] && [ -d ${rpmpath}/noarch ]; then
      copy_to_repo_and_update ${rpmpath}/noarch ${dest}
    fi

    copy_to_repo_and_update ${src} ${dest}
  done
}

# run this in the git repo itself
commit_repo() {
  cd ${yumpath}
  # Only commit if any RPMs have changed
  rpms_changed="$(git status | grep rpm)"

  if [ "${rpms_changed}" == "" ]; then
    echo "No packages have changed, exit now."
    exit 0;
  fi

  # Do the git commit
  git config --global user.name "Ribose Packaging"
  git config --global user.email packages@ribose.com

  git add -A

  git commit -m "Updated RPMs and repodata"
  git push
}


#!/bin/bash -xe

# shellcheck disable=SC2155
# shellcheck disable=SC2164

errx() {
  readonly __progname=$(basename "${BASH_SOURCE}")
  echo -e "${__progname}: $*" >&2
  # return 1
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
  local dest_path=$1

  echo "[update_repo] Updating yum repo at ${1}" >&2
  createrepo --update --delta "${dest_path}" || \
    errx "Cannot createrepo at ${dest_path}.  Aborting."
  echo "[update_repo] Signing repo at ${1}" >&2
  rm -f "${dest_path}/repodata/repomd.xml.asc"
  gpg --detach-sign --armor "${dest_path}/repodata/repomd.xml" || \
    errx "Cannot sign.  Aborting."
}

install_basic_packages() {
  yum install -y epel-release

  yum install -y git createrepo automake autoconf libtool make gcc-c++ \
    rpmdevtools wget epel-rpm-macros rpm-sign expect
}

set_creds_and_key() {
  local scripts=$(dirname "$(readlink -f "${BASH_SOURCE}")")
  "${scripts}"/set_yum_push_credentials.sh "${REPO_USERNAME}" "${REPO_PASSWORD}"
  "${scripts}"/import_packaging_key.sh "${PACKAGER_KEY_PATH}"
}

readonly rpmspec_repo_prefix=rpm-spec-
readonly rpmspec_path=/usr/local/rpm-specs/package
readonly rpmspecs_path=/usr/local/rpm-specs

fetch_spec_from_ribose_specs() {
  readonly local p_name=$1
  readonly local p_path=$2
  [ -z "${p_name}" ] && errx "no p_name provided to $0"
  [ -z "${p_path}" ] && errx "no p_path provided to $0"

  local rpmspec_package_name=${rpmspec_repo_prefix}${p_name}

  # We fully clone so we can compare the commits to previous ones
  # It's not a lot anyway
  if [ ! -d ${rpmspec_path} ] && [ ! -d ${rpmspec_path}/.git ]; then
    git clone --quiet \
            https://github.com/riboseinc/"${rpmspec_package_name}" \
            "${rpmspec_path}" || errx "git clone"
  else
    pushd "${rpmspec_path}" && \
            git clean -qdffx && \
            git fetch && \
            git checkout master && \
            git --hard origin/master && \
            popd
  fi

  cd "${rpmspec_path}"
  git submodule update --init >/dev/null
  cp -ra "${rpmspec_path}/common"/* "${rpmspecs_path}/" || return 1

  local package_spec_commit="$(git log -1 --format=format:%H)"
  echo "$package_spec_commit"
  cp -ra "${rpmspec_path}"/* "${p_path}/" || return 1
}

the_works() {
  readonly local package_name=$1
  [[ -z "${package_name}" ]] && errx "no package_name provided"

  setup_env

  # TODO: change rpm-specs repo to use a consistent name in prepare.sh
  local package_path=/usr/local/${package_name}
  mkdir -p "${package_path}" || errx "mkdir package_path"
  echo "PACKAGE_PATH=${package_path}"

  local package_spec_commit
  package_spec_commit="$(fetch_spec_from_ribose_specs "${package_name}" "${package_path}")"

  [[ $? -ne 0 ]] && errx "failed to fetch spec"

  echo "RPMSPEC_COMMIT=${package_spec_commit}"
  echo "PACKAGE_PATH LS:"
  ls "${package_path}"

  pushd "${package_path}" || errx "failed to enter package path"
  "${package_path}"/prepare.sh || errx "failed to prepare"
  popd

  pull_yum

  # Compare commits only if we already have a package
  if [[ -f "${yumpath}/commits/${package_name}" ]]; then
    local yum_commit=$(cat "${yumpath}/commits/${package_name}")
    check_if_newer_than_published "${package_spec_commit}" "${yum_commit}"
    local rv=$?
    case $rv in
      1)
        errx "Package build rejected ${package_name}: Commit (${package_spec_commit}) not newer than one in yum repo (${yum_commit})!"
        ;;
      128)
        echo "Package ${package_name}: Commit in rpm-spec-${package_name} (${package_spec_commit}) cannot compare to the one in Yum (${yum_commit}).  Probably transitioning to different rpm-spec-* repos?  Continuing."
        ;;
    esac
  fi

  update_yum_srpm
  update_yum_rpm
  commit_repo "${package_name}" "${package_spec_commit}"
}

readonly yumpath=/usr/local/yum

pull_yum() {
  echo "[pull_yum] Going to update local yum repo" >&2

  if [ ! -d ${yumpath} ] || [ ! -d ${yumpath}/.git ]; then

    echo "[pull_yum] Cloning into ${yumpath}..." >&2
    mkdir -p ${yumpath}
    ls -al ${yumpath}
    rm -rf "${yumpath:?}"/*
    pushd "${yumpath}"
    git clone --depth 1 https://github.com/riboseinc/yum .
    popd

  else

    echo "[pull_yum] Updating ${yumpath}..." >&2
    pushd "${yumpath}"
    git clean -qdffx
    git fetch
    git checkout master
    git reset --hard origin/master
    popd

  fi
}

check_if_newer_than_published() {
  local rpm_spec_commit=$1
  local yum_repo_commit=$2
  [ -z "${rpm_spec_commit}" ] && errx "no rpm_spec_commit provided"
  [ -z "${yum_repo_commit}" ] && errx "no yum_repo_commit provided"

  pushd ${rpmspec_path}
  # Commits are same, no need to re-build
  if [ "${yum_repo_commit}" == "${rpm_spec_commit}" ]; then
    popd
    return 1
  fi

  # Check if commit is an ancestor
  git merge-base --is-ancestor "${yum_repo_commit}" "${rpm_spec_commit}"
  local rv=$?
  popd

  return $rv
}

# TODO: make this script understand whether to push SRPMS or not. Erlang SRPM
# fails due to file size over 100MB.

readonly max_file_size=100000000
readonly rpmbuild_path=/root/rpmbuild

copy_to_repo_and_update() {
  local source_path=$1
  local dest_path=$2

  echo "[copy_to_repo_and_update] source: ${source_path} dest: ${dest_path}" >&2

  if [ -d "${source_path}" ]; then

    mkdir -p "${dest_path}"

    pushd "${source_path}"
    while IFS= read -r -d '' f; do
      local size=$( wc -c "${f}" | awk '{print $1}' )
      # If SRPM filesize exceeds max size, skip this step.
      if [[ "${size}" -gt "${max_file_size}" ]]; then
        echo "[copy_to_repo_and_update] Skipping ${f} file since it is too large" >&2
        continue
      fi

      echo "[copy_to_repo_and_update] Copying ${f} to ${dest_path}" >&2
      cp "${f}" "${dest_path}" || \
        errx "Cannot copy ${f} to ${dest_path}.  Aborting."

    done < <(find . -iname '*.rpm')
    popd

    update_repo "${dest_path}"
  fi
}

sign_packages() {
  local scripts=$(dirname "$(readlink -f "${BASH_SOURCE}")")
  local rpmpath=$1

  if [ -d "${rpmpath}" ]; then
    pushd "${rpmpath}"
    while IFS= read -r -d '' f; do
      echo "[sign_packages] ${f}" >&2
      "${scripts}/rpmsign.exp" "${f}" || \
        errx "Cannot sign ${f}.  Aborting."
    done < <(find . -iname '*.rpm')
    popd
  fi
}

# SRPM directory always exist
update_yum_srpm() {
  # Update SRPM repo
  sign_packages ${rpmbuild_path}/SRPMS
  copy_to_repo_and_update ${rpmbuild_path}/SRPMS ${yumpath}/SRPMS/
}

# Update RPMS repos
update_yum_rpm() {
  local rpmpath="${rpmbuild_path}/RPMS"
  local arches=$(ls ${yumpath}/RPMS)

  echo "[update_yum_rpm]" >&2

  for arch in ${arches}; do
    local src=${rpmpath}/${arch}
    local dest=${yumpath}/RPMS/${arch}

    echo "[update_yum_rpm] src:${src} dest:${dest}" >&2

    if [[ -d ${src} ]]; then
      sign_packages "${src}"
      copy_to_repo_and_update "${src}" "${dest}"
    fi

    if [ "${arch}" != "noarch" ] && [ -d "${rpmpath}/noarch" ]; then
      copy_to_repo_and_update ${rpmpath}/noarch "${dest}"
    fi
  done
}

# run this in the git repo itself
commit_repo() {
  set -e
  local package_name="${1?}"
  local package_spec_commit="${2?}"

  cd ${yumpath}
  # Only commit if any RPMs have changed
  local rpms_changed="$(git status | grep rpm)"

  if [ "${rpms_changed}" == "" ]; then
    echo "No packages have changed, exit now." >&2
    exit 0
  fi

  # Do the git commit
  git config --global user.name "Ribose Packaging"
  git config --global user.email packages@ribose.com

  echo "${package_spec_commit}" > "${yumpath}/commits/${package_name}"

  git add -A
  git commit -m "${package_name}: Update RPMs and repodata"

  if [ "$DRYRUN" != "1" ]; then
    git push
  else
    echo "DRYRUN set to 1, NOT PUSHING CHANGES." >&2
  fi
  set +e
}

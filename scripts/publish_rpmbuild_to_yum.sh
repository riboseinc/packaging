#!/bin/bash -x

readonly __progname=$(basename $0)

base=$(cd "$(dirname "$0")"; pwd)
scripts=$(cd "${base}/../scripts"; pwd)

# TODO: make this script understand whether to push SRPMS or not. Erlang SRPM
# fails due to file size over 100MB.

max_file_size=100000000

yumpath=/usr/local/yum
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

pushd ${yumpath}

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

  createrepo --update --delta ${dest_path}
  rm -f ${dest_path}/repodata/repomd.xml.asc
  gpg --detach-sign --armor ${dest_path}/repodata/repomd.xml
}

sign_packages() {
  for f in ${1}/*.rpm; do
    ${scripts}/rpmsign.exp ${f}
  done
}

rpmbuild_path=/root/rpmbuild

# Update SRPM repo
sign_packages ${rpmbuild_path}/SRPMS
copy_to_repo_and_update ${rpmbuild_path}/SRPMS ${yumpath}/SRPMS/

# Update RPMS repos
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
exec bash

git commit -m "Updated RPMs and repodata"
git push


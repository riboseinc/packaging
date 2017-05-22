#!/bin/bash -e

yumpath=/usr/local/yum
if [ ! -d ${yumpath} ] && [ ! -d ${yumpath}/.git ]; then
  git clone --depth 1 https://github.com/riboseinc/yum ${yumpath}
fi
pushd ${yumpath}

rpmbuild_path=/root/rpmbuild
repopath="${rpmbuild_path}/SRPMS"
mkdir -p ${yumpath}/SRPMS/
cp ${repopath}/*.rpm ${yumpath}/SRPMS/
createrepo --update --delta ${repopath}
rm -f ${repopath}/repodata/repomd.xml.asc
gpg --detach-sign --armor ${repopath}/repodata/repomd.xml

rpmpath="${rpmbuild_path}/RPMS"
arches=$(ls ${rpmpath})
for arch in ${arches}; do
  repopath=${yumpath}/RPMS/${arch}
  mkdir -p ${repopath}
  cp ${rpmpath}/${arch}/*.rpm ${repopath}/
  createrepo --update --delta ${repopath}
  rm -f ${repopath}/repodata/repomd.xml.asc
  gpg --detach-sign --armor ${repopath}/repodata/repomd.xml
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
git commit -m "Updated RPMs and repodata"
git push


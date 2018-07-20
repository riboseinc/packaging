set -xe

RIBOSE_PACKAGER_KEY_PATH=${1:-ribose-packager.key}

gpg --import ${RIBOSE_PACKAGER_KEY_PATH}

# Edit your identities.
PACKAGER="${PACKAGER:-Ribose Packaging <packages@ribose.com>}"
GPG_NAME="${GPG_NAME:-${PACKAGER}}"

cat <<MACROS >~/.rpmmacros
%_signature gpg
%_gpg_path $HOME/.gnupg
%_gpg_name ${GPG_NAME}
%_gpgbin /usr/bin/gpg
%packager ${PACKAGER}
%_topdir $HOME/rpmbuild
MACROS


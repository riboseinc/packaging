#!/bin/bash -x

readonly __progname=$(basename $0)

errx() {
	echo -e "$__progname: $@" >&2
	exit 1
}

usage() {
	echo "usage: $__progname -k <packager-key-path> -u <repo-username> -p <repo-password> [ package-name ]"
  echo "  Arguments can also be set via environment variables: "
  echo "  - REPO_USERNAME"
  echo "  - REPO_PASSWORD"
  echo "  - PACKAGER_KEY_PATH"
	exit 1
}

main() {

	while getopts ":u:p:k:" o; do
		case "${o}" in
		k)
			readonly local PACKAGER_KEY_PATH=${OPTARG}
			;;
		u)
			readonly local REPO_USERNAME=${OPTARG}
			;;
		p)
			readonly local REPO_PASSWORD=${OPTARG}
			;;
		*)
			usage
			;;
		esac
	done

  shift $(($OPTIND - 1))

  PACKAGE_NAME=$1
	if [ "x$PACKAGE_NAME" != "x" ]; then
    DOCKER_BASH_EXTRA="-c /usr/local/ribose-packaging/packages/"${1}".sh"
  fi

	[[ ! "$PACKAGER_KEY_PATH" ]] && \
		usage

	[[ ! "$REPO_USERNAME" ]] && \
		usage

	[[ ! "$REPO_PASSWORD" ]] && \
		usage

  volume_name=ribose-yum
  docker volume create ${volume_name}

  container_key_path=/tmp/packager.key
  docker run -it \
    -v $(pwd):/usr/local/ribose-packaging \
    -v ${PACKAGER_KEY_PATH}:${container_key_path}:ro \
    -v ${volume_name}:/usr/local/yum \
    -e PACKAGER_KEY_PATH=${container_key_path} \
    -e REPO_USERNAME="${REPO_USERNAME}" \
    -e REPO_PASSWORD="${REPO_PASSWORD}" \
    centos:7 bash -l ${DOCKER_BASH_EXTRA}

}

main "$@"

exit 0

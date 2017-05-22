#!/bin/bash

readonly __progname=$(basename $0)

errx() {
	echo -e "$__progname: $@" >&2
	exit 1
}

usage() {
	echo "usage: $__progname -k <packager-key-path> -u <repo-username> -p <repo-password>"
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

	[[ ! "$PACKAGER_KEY_PATH" ]] && \
		usage

	[[ ! "$REPO_USERNAME" ]] && \
		usage

	[[ ! "$REPO_PASSWORD" ]] && \
		usage


  container_key_path=/tmp/packager.key
  docker run -it \
    -v $(pwd):/usr/local/ribose-packaging \
    -v ${PACKAGER_KEY_PATH}:${container_key_path} \
    -e PACKAGER_KEY_PATH=/tmp/packager.key \
    -e REPO_USERNAME=${REPO_USERNAME} \
    -e REPO_PASSWORD=${REPO_PASSWORD} \
    centos:7 bash -l

}

main "$@"

exit 0

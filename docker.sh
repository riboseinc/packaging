#!/bin/bash

readonly __progname=$(basename "$0")

errx() {
  echo -e "$__progname: $*" >&2
  exit 1
}

usage() {
  echo "usage: $__progname -k <packager-key-path> -u <repo-username> -p <repo-password> -d [ package-name ]"
  echo ""
  echo "  Options:"
  echo "  -d for dry run, not pushing to yum repo."
  echo "  -k for the path to the packager key."
  echo "  -u for git repo's username (via https)."
  echo "  -p for git repo's password / app-token."
  echo "  -h to display this message"
  echo ""
  echo "  Arguments can also be set via environment variables: "
  echo "  - REPO_USERNAME"
  echo "  - REPO_PASSWORD"
  echo "  - PACKAGER_KEY_PATH"
  exit 1
}

main() {

  while getopts ":u:p:k:dh" o; do
    case "${o}" in
    d)
      readonly local DRYRUN=1
      ;;
    k)
      readonly local PACKAGER_KEY_PATH=${OPTARG}
      ;;
    u)
      readonly local REPO_USERNAME=${OPTARG}
      ;;
    p)
      readonly local REPO_PASSWORD=${OPTARG}
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
    esac
  done

  shift $(($OPTIND - 1))

  PACKAGE_NAME=$1
  if [ "x$PACKAGE_NAME" != "x" ]; then
    DOCKER_BASH_COMMAND=". /usr/local/packaging/scripts/_common.sh; the_works ${1}"

    if [ "${DRYRUN}" = "1" ]; then
      DOCKER_BASH_COMMAND=". /usr/local/packaging/scripts/_common.sh; export DRYRUN=1; the_works ${1}; bash"
    fi
  fi

  [[ ! "$PACKAGER_KEY_PATH" ]] && \
    usage

  [[ ! "$REPO_USERNAME" ]] && \
    usage

  [[ ! "$REPO_PASSWORD" ]] && \
    usage

  DOCKER_BASH_FLAGS=-l

  volume_name=ribose-yum
  docker volume create ${volume_name}

  container_key_path=/tmp/packager.key

  # TODO: clean this up...
  if [ "$DOCKER_BASH_COMMAND" != "" ]; then
    DOCKER_BASH_EXTRA="${DOCKER_BASH_COMMAND}"
    DOCKER_BASH_FLAGS="${DOCKER_BASH_FLAGS} -c"
  fi

  docker run -it \
          -v "$(pwd)":/usr/local/packaging \
          -v "${PACKAGER_KEY_PATH}":"${container_key_path}":ro \
          -v ${volume_name}:/usr/local/yum \
          -e PACKAGER_KEY_PATH=${container_key_path} \
          -e REPO_USERNAME="${REPO_USERNAME}" \
          -e REPO_PASSWORD="${REPO_PASSWORD}" \
          centos:7 bash ${DOCKER_BASH_FLAGS} "${DOCKER_BASH_EXTRA}"

}

main "$@"

exit 0

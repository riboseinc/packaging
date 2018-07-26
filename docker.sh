#!/bin/bash

#
# Environment variables can be passed to the prepare.sh script by
# specifying the env var keys with a comma-separated list, like 
# so:
#
#   ENVS=key1,key2,...
#
# Current values of the env vars will be propagated as per Docker-run's 
# documentation.  So, if you have the following:
#
#   export key1=hello
#   export key2=bye
#   ENVS=key1,key2 ./docker.sh my_package_name
#
# ... then the ./docker.sh will have key1=hello and key2=bye.
#

set -e

readonly __progname=$(basename "$0")

errx() {
  echo -e "$__progname: $*" >&2
  exit 1
}

usage() {
  echo "usage: $__progname -k <packager-key-path> -u <repo-username> -p <repo-password> -d [ package-name ]"
  echo ""
  echo "  Options:"
  echo "  -v for additional volume for the docker script (same syntax as the docker-run -v option)"
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

  while getopts ":v:u:p:k:dh" o; do
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
    v)
      local DOCKER_RUN_PACKAGE_SPEC_VOLUME="-v ${OPTARG}"
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

  [[ ! -z "$DOCKER_RUN_PACKAGE_SPEC_VOLUME" ]] || \
    DOCKER_RUN_PACKAGE_SPEC_VOLUME=""

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

  DOCKER_RUN_IT_FLAGS='-i'

  if [[ -t 1 ]]; then
    DOCKER_RUN_IT_FLAGS="${DOCKER_RUN_IT_FLAGS} -t"
  fi

  # DOCKER_RUN_PACKAGE_SPEC_VOLUME="-v "$(pwd)/..":/usr/local/rpm-specs/package"

  # Parse out env var names intended for passing into container:
  envs=()
  if [[ ! -z "${ENVS:-}" ]]; then
    IFS=, read -r -a envs <<< "${ENVS}"
  fi

  # Compose envs strings for `docker run`:
  docker_env_opts=''
  for env_key in "${envs[@]}"; do
    docker_env_opts="${docker_env_opts} -e ${env_key}"
  done

  docker run ${DOCKER_RUN_IT_FLAGS} \
    -v "$(pwd)":/usr/local/packaging \
    ${DOCKER_RUN_PACKAGE_SPEC_VOLUME} \
    -v "${PACKAGER_KEY_PATH}":"${container_key_path}":ro \
    -v ${volume_name}:/usr/local/yum \
    ${docker_env_opts} \
    -e PACKAGER_KEY_PATH=${container_key_path} \
    -e REPO_USERNAME="${REPO_USERNAME}" \
    -e REPO_PASSWORD="${REPO_PASSWORD}" \
    centos:7 bash ${DOCKER_BASH_FLAGS} "${DOCKER_BASH_EXTRA}"

}

main "$@"

exit 0

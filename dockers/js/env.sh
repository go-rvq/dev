#!/bin/bash
sourced=0

DOT_DIR=`pwd`

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
  DIR=$(dirname "$0")
else
  DIR=$(dirname "${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}")
  sourced=1
fi

function abspath() {
  python3 - "$1" < <(
    cat <<doc
import sys
from os import getcwd, path

p = path.normpath(sys.argv[1])
if p[0] != '/':
  p = path.normpath(path.join(getcwd(), p))
print(path.abspath(p))
doc
)
  return $?
}

function @freeport() {
    if [ $# -lt 1 ]; then
      echo "usage: @freeport START_FROM" >&2
      return 1
    fi

    local _check="-"
    local port=$1

    while true; do
        _check=$(ss -tulpn | grep ":${port}" || true)
        [[ -z "${_check}" ]] && break
        ((port++))
    done

    echo $port
}

DIR=$(cd "$DIR" && pwd)

set -e

node_version=$(grep FROM "$DIR/Dockerfile" | perl -pe 's/^FROM node:(\d+)-.+$/\1/')
export DOCKER_IMAGE_NAME="rvq_js:${node_version}-latest"

function @image_build() {
  ( cd "$DIR" && \
    docker build --tag $DOCKER_IMAGE_NAME .
  )
  return $?
}

function @image_rm() {
  docker image rm $DOCKER_IMAGE_NAME
  return $?
}

function @image_check() {
  echo INFO: checking build image >&2
  docker inspect --type image $DOCKER_IMAGE_NAME 2>/dev/null >&2 || \
    @image_build >&2
  return $?
}

@image_check

function @image_rebuild() {
  @image_rm && @image_build
}

function @check() {
  if [ ! -e ./package.json ] || [ ! -e ./pnpm-lock.yaml ] || [ ! -e ./Makefile ]; then
    echo ERROR: ./ is not a valid project >&2
    return 1
  fi
}

function @exec() {
  local opt="-it"

  case $1 in
  "-")
    # pass stdin as bash command
    # example: echo 'date;ls' | @exec -
    opt="-i"
    ;;
  "--")
    # pass stdin to normal command
    # example: echo hello | @exec -- cat
    opt="-i"
    shift
    ;;
  esac

  local docker_args=( run \
    "$opt" \
    --rm \
    --user root \
    -e AS_USER=$(id -u):$(id -g) \
    -e HOME=/home/node \
    -v .:/home/node/src \
    -v "$DIR/volumes/pnpm-cache:/home/node/.cache/pnpm" \
    -v "$DIR/volumes/pnpm-store:/home/node/src/.pnpm-store" \
    -v $HOME/.gitconfig:/home/node/.gitconfig
    -w /home/node/src \
  )

  local args=()

  local args_cmd=$("$DIR/split_args.py" args docker_args -- "$@")
  eval "$args_cmd"
  echo ">> ARGS: ${args[@]}" >&2
  echo ">> DOCKER ARGS: ${docker_args[@]}" >&2

  let j=1
  local container_name=''
  for (( j=1; j<=${#docker_args[@]}; j++ )); do
    if [ "${docker_args[i]}" = '--name' ]; then
      ((j++))
      container_name="${docker_args[j]}"
      break
    fi
  done

  if [ "$container_name" = '' ]; then
    container_name="${rvq_js_container_name:-rvq_js}"
    docker_args+=( "--name" "${container_name}" )
  fi

  echo "[CONTAINER_NAME]: $container_name" >&2

  docker_args+=( "$DOCKER_IMAGE_NAME" "${args[@]}" )

  echo ">> DOCKER EXEC ARGS:" >&2
  for item in "${docker_args[@]}"; do
    echo "  $item" >&2
  done

  set -ex
  docker "${docker_args[@]}"
  return $?
}

function @build_cmd() {
  @check || return $?

  [ -e ./dist ] && rm -vrf ./dist

  @exec - "$@"
  return $?
}

function @build() {
  echo 'set -ex
  pnpm install
  if  [ -e "./scripts/fix-node_modules.sh" ]; then
    exe_path=./scripts/fix-node_modules.sh
    __path=$exe_path "$exe_path"
  fi
  pnpm run build
  ' | @build_cmd "$@"
  return $?
}

function @dist() {
  @check || return $?

  [ -e ./dist ] && rm -vrf ./dist

  echo 'pnpm install && pnpm format && pnpm run build' | @exec -
  return $?
}

function pnpm() {
  @exec pnpm "$@"
  return $?
}

function @dev() {
  @check || return $?

  local port=$(@freeport 3000)
  rm -rf ./node_modules/.vite
  echo 'set -ex
  pnpm install
  if  [ -e "./scripts/fix-node_modules.sh" ]; then
    ./scripts/fix-node_modules.sh
  fi
  pnpm run dev -- --force
  ' | @exec - \
    docker_args.start \
      -p ":$port:$port" \
      -e VITE_PORT=$port \
      -e VITE_HOST=true \
      -e VITE_ALLOWED_HOST=true \
    docker_args.end "$@"
  return $?
}

function @install() {
  @exec "$@" pnpm install
  return $?
}

"$@"
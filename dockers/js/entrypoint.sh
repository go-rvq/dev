#!/usr/bin/env bash

set -Eeo pipefail

_check_perms() {
  [ -e "/home/node/.cache/pnpm" ] && chmod 777 /home/node/.cache/pnpm
  [ -e "/home/node/src/.pnpm-store" ] && chmod 777 /home/node/src/.pnpm-store
}


if [ $(id -u) -eq 0 ]; then
  _check_perms

  if [ "$AS_USER" != '' ]; then
    u=$AS_USER
    unset $AS_USER
    su-exec  $AS_USER "$0" "$@"
    exit $?
  fi
fi

case "$1" in
"-")
  commands_from_stdin=$(cat)
  eval "$commands_from_stdin"
  exit $?
  ;;
esac

exec "$@"
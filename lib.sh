#!/bin/bash
does_not_exists_or_is_different() {
  if [ ! -e "$1" ]; then   # Check if first file does not exist
    return 0   # Return true
  elif ! cmp -s "$1" "$2"; then # Check if files are different
    return 0   # Return true
  fi
  return 1
}

package_installed() {
  if dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"; then
    return 0   # Return true if package is installed
  else
    return 1   # Return false if package is not installed
  fi
}

# retry <n> <cmd...>: run cmd up to n times with a growing pause between tries.
retry() {
  local n=$1 i=1
  shift
  until "$@"; do
    if [ "$i" -ge "$n" ]; then
      echo "retry: giving up after $n attempts: $*" >&2
      return 1
    fi
    echo "retry: attempt $i/$n failed, retrying: $*" >&2
    sleep $((i * 2))
    i=$((i + 1))
  done
}

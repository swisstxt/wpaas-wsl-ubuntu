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

# os_codename: "resolute"
os_codename() {
  # shellcheck disable=SC1091
  (. /etc/os-release && echo "$VERSION_CODENAME")
}

# apt_get <args...>: non-interactive apt-get with download retries.
# Uses `sudo env VAR=..` because sudo-rs rejects VAR=.. arguments under env_reset.
apt_get() {
  sudo env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 "$@"
}

apt_install() { apt_get install -y "$@"; }

apt_update() { retry 3 apt_get update; }

# install_file <src> <dst> [mode]: copy as root only when missing or different.
install_file() {
  local src=$1 dst=$2 mode=${3:-0644}
  if does_not_exists_or_is_different "$dst" "$src"; then
    echo "installing $dst"
    sudo install -D -m "$mode" "$src" "$dst"
  else
    echo "$dst is up to date"
  fi
}

# fetch_keyring <url> <dst>: download an ASCII-armored key once, store dearmored.
fetch_keyring() {
  local url=$1 dst=$2 tmp
  if [ -s "$dst" ]; then
    echo "keyring $dst present"
    return 0
  fi
  tmp=$(mktemp)
  retry 3 curl -fsSL "$url" -o "$tmp.asc"
  gpg --dearmor < "$tmp.asc" > "$tmp"
  sudo install -D -m 0644 "$tmp" "$dst"
  rm -f "$tmp" "$tmp.asc"
}

# write_apt_list <name> <line>: /etc/apt/sources.list.d/<name>.list is overwritten, never appended.
write_apt_list() {
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$2" > "$tmp"
  install_file "$tmp" "/etc/apt/sources.list.d/$1.list"
  rm -f "$tmp"
}

# write_apt_pin <name> <package> <version-glob>: /etc/apt/preferences.d/<name>
write_apt_pin() {
  local tmp
  tmp=$(mktemp)
  printf 'Package: %s\nPin: version %s\nPin-Priority: 1000\n' "$2" "$3" > "$tmp"
  install_file "$tmp" "/etc/apt/preferences.d/$1"
  rm -f "$tmp"
}

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
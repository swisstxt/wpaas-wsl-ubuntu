#!/bin/bash
# Exercises the kubectl_complete-* scripts in bin/ against a stub kubectl and a
# stub krew directory, so no cluster or network is needed.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fails=0
assert_eq() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3' got '$2'"; fails=$((fails+1)); fi; }

# stub kubectl: records its arguments, answers a namespace listing
mkdir -p "$TMP/bin"
cat > "$TMP/bin/kubectl" <<S
#!/bin/bash
echo "\$*" >> "$TMP/kubectl.calls"
printf 'default\nkube-system\nmyapp\n'
S
chmod +x "$TMP/bin/kubectl"
export PATH="$TMP/bin:$PATH"

# stub krew root: index with three plugins, two of them installed
export KREW_ROOT="$TMP/krew"
mkdir -p "$KREW_ROOT/index/default/plugins" "$KREW_ROOT/receipts"
touch "$KREW_ROOT/index/default/plugins/"{ns,ctx,neat}.yaml "$KREW_ROOT/receipts/"{krew,ns}.yaml

NS="$REPO_ROOT/bin/kubectl_complete-ns"
KREW="$REPO_ROOT/bin/kubectl_complete-krew"

assert_eq "ns: namespaces of the current context plus -" "$("$NS" "")"      "$(printf -- '-\ndefault\nkube-system\nmyapp\n:4')"
assert_eq "ns: partial word is left to the shell"        "$("$NS" "ku")"    "$(printf -- '-\ndefault\nkube-system\nmyapp\n:4')"
assert_eq "ns: only the first argument completes"        "$("$NS" "myapp" "")" ":4"
assert_eq "ns: kubectl is asked for names only"          "$(head -1 "$TMP/kubectl.calls")" "get namespaces -o jsonpath={range .items[*]}{.metadata.name}{\"\\n\"}{end}"

assert_eq "krew: subcommands at the first position" "$("$KREW" "")" "$(printf 'help\nindex\ninfo\ninstall\nlist\nsearch\nuninstall\nupdate\nupgrade\nversion\n:4')"
assert_eq "krew: install offers index plugins"      "$("$KREW" install "")"   "$(printf 'ctx\nneat\nns\n:4')"
assert_eq "krew: info offers index plugins"         "$("$KREW" info "n")"     "$(printf 'ctx\nneat\nns\n:4')"
assert_eq "krew: uninstall offers installed ones"   "$("$KREW" uninstall "")" "$(printf 'krew\nns\n:4')"
assert_eq "krew: upgrade offers installed ones"     "$("$KREW" upgrade "")"   "$(printf 'krew\nns\n:4')"
assert_eq "krew: other subcommands complete nothing" "$("$KREW" list "")" ":4"
rm -rf "$KREW_ROOT/index"
assert_eq "krew: missing index completes nothing"   "$("$KREW" install "")"  ":4"

[ "$fails" -eq 0 ] && echo "kubectl-complete test OK" || { echo "$fails failure(s)"; exit 1; }

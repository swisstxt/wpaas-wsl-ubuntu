#!/bin/bash
# Exercises lib/runner.sh through install.sh using dummy steps in a temp dir.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export WPAAS_DIR="$TMP/wpaas"
export STEPS_DIR="$TMP/steps"
export WPAAS_ASSUME_SYSTEMD=0
export WPAAS_NO_SUDO=1
export WPAAS_GIT_NAME="Test User"
export WPAAS_GIT_EMAIL="test@example.com"
export WPAAS_INSTALL_KUBECONTEXTS=n
export WPAAS_INSTALL_JETBRAINS=n
mkdir -p "$STEPS_DIR"

fails=0
assert_eq()      { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3' got '$2'"; fails=$((fails+1)); fi; }
assert_match()   { if grep -qE -- "$3" <<<"$2"; then echo "ok   $1"; else echo "FAIL $1: /$3/ not found"; fails=$((fails+1)); fi; }
assert_nomatch() { if grep -qE -- "$3" <<<"$2"; then echo "FAIL $1: /$3/ unexpectedly found"; fails=$((fails+1)); else echo "ok   $1"; fi; }
assert_file()    { if [ -e "$2" ]; then echo "ok   $1"; else echo "FAIL $1: $2 missing"; fails=$((fails+1)); fi; }
assert_nofile()  { if [ -e "$2" ]; then echo "FAIL $1: $2 exists"; fails=$((fails+1)); else echo "ok   $1"; fi; }

cat > "$STEPS_DIR/10-alpha.sh" <<'S'
#!/bin/bash
# step: alpha
echo "alpha ran as $WPAAS_GIT_NAME in $PWD"
S
cat > "$STEPS_DIR/20-beta.sh" <<'S'
#!/bin/bash
# step: beta
echo "beta fails"
exit 3
S
cat > "$STEPS_DIR/30-gamma.sh" <<'S'
#!/bin/bash
# step: gamma
# needs_systemd: 1
echo "gamma ran"
S
cat > "$STEPS_DIR/40-delta.sh" <<'S'
#!/bin/bash
# step: delta
echo "delta ran"
S

run() { bash "$REPO_ROOT/install.sh" "$@" 2>&1; }

echo "--- run 1: fresh"
out=$(run --non-interactive); rc=$?
assert_eq    "exit 1 when a step failed" "$rc" 1
assert_match "answers exported to steps" "$out" "alpha ran as Test User in $REPO_ROOT"
assert_match "alpha OK" "$out" "^ +alpha +OK"
assert_match "beta FAILED with log path" "$out" "^ +beta +FAILED +$WPAAS_DIR/logs/beta.log"
assert_match "gamma DEFERRED" "$out" "^ +gamma +DEFERRED \(systemd\)"
assert_match "delta OK" "$out" "^ +delta +OK"
assert_file   "alpha.done" "$WPAAS_DIR/state/alpha.done"
assert_nofile "beta.done absent" "$WPAAS_DIR/state/beta.done"
assert_nofile "gamma.done absent" "$WPAAS_DIR/state/gamma.done"
assert_file   "beta log" "$WPAAS_DIR/logs/beta.log"
assert_match  "beta log content" "$(cat "$WPAAS_DIR/logs/beta.log")" "beta fails"
assert_file   "answers.env" "$WPAAS_DIR/answers.env"
assert_eq     "answers.env mode" "$(stat -c %a "$WPAAS_DIR/answers.env")" 600
assert_match  "answers.env content" "$(cat "$WPAAS_DIR/answers.env")" "^git_name=Test User$"

echo "--- run 2: rerun with systemd"
out=$(WPAAS_ASSUME_SYSTEMD=1 run --non-interactive); rc=$?
assert_match "alpha skipped (done)" "$out" "^ +alpha +SKIPPED \(done\)"
assert_match "beta fails again" "$out" "^ +beta +FAILED"
assert_match "gamma OK now" "$out" "^ +gamma +OK"
assert_match "delta skipped (done)" "$out" "^ +delta +SKIPPED \(done\)"

echo "--- run 3: answers persisted"
out=$(env -u WPAAS_GIT_NAME -u WPAAS_GIT_EMAIL -u WPAAS_INSTALL_KUBECONTEXTS -u WPAAS_INSTALL_JETBRAINS bash "$REPO_ROOT/install.sh" --non-interactive --only alpha --force 2>&1); rc=$?
assert_eq    "exit 0 with persisted answers" "$rc" 0
assert_match "alpha reran from file answers" "$out" "alpha ran as Test User"

echo "--- run 4: --only and --force"
out=$(run --non-interactive --only alpha --force); rc=$?
assert_eq    "exit 0" "$rc" 0
assert_match "alpha OK" "$out" "^ +alpha +OK"
assert_match "beta skipped (flag)" "$out" "^ +beta +SKIPPED \(flag\)"
assert_match "delta skipped (flag)" "$out" "^ +delta +SKIPPED \(flag\)"

echo "--- run 5: --skip"
out=$(run --non-interactive --skip beta); rc=$?
assert_eq    "exit 0 when failing step skipped" "$rc" 0
assert_match "beta skipped (flag)" "$out" "^ +beta +SKIPPED \(flag\)"

echo "--- run 6: --list"
out=$(run --list)
assert_match "list shows alpha" "$out" "^alpha +required=0 needs_systemd=0"
assert_match "list shows gamma" "$out" "^gamma +required=0 needs_systemd=1"

echo "--- run 7: required step aborts"
cat > "$STEPS_DIR/50-epsilon.sh" <<'S'
#!/bin/bash
# step: epsilon
# required: 1
echo "epsilon fails"
exit 1
S
cat > "$STEPS_DIR/60-zeta.sh" <<'S'
#!/bin/bash
# step: zeta
echo "zeta ran"
S
out=$(run --non-interactive --force --skip beta); rc=$?
assert_eq      "exit 1 on required failure" "$rc" 1
assert_match   "epsilon FAILED" "$out" "^ +epsilon +FAILED"
assert_nomatch "zeta not run after required failure" "$out" "zeta"

echo "--- run 8: --reset and missing answer"
out=$(run --reset)
assert_nofile "state dir removed" "$WPAAS_DIR/state"
out=$(env -u WPAAS_GIT_NAME bash "$REPO_ROOT/install.sh" --non-interactive 2>&1); rc=$?
assert_eq    "exit 2 on missing answer" "$rc" 2
assert_match "names the missing answer" "$out" "missing answer git_name \(set WPAAS_GIT_NAME\)"

echo "--- run 9: steps do not consume the step list from stdin"
export STEPS_DIR="$TMP/steps9"
mkdir -p "$STEPS_DIR"
cat > "$STEPS_DIR/10-reader.sh" <<'S'
#!/bin/bash
# step: reader
read -r line || true
echo "read got: '${line:-}'"
S
cat > "$STEPS_DIR/20-after.sh" <<'S'
#!/bin/bash
# step: after
echo "after ran"
S
out=$(run --non-interactive </dev/null); rc=$?
assert_eq      "exit 0" "$rc" 0
assert_match   "later step still ran" "$out" "^ +after +OK"
assert_nomatch "reader did not get a step filename" "$(grep 'read got' <<<"$out")" "\.sh"

echo "--- run 10: --only without argument"
out=$(run --only); rc=$?
assert_eq    "exit 2 on missing option argument" "$rc" 2
assert_match "clear message" "$out" "option --only needs an argument"

echo "--- run 11: numeric step ordering"
ORDER_DIR="$TMP/order-steps"
mkdir -p "$ORDER_DIR"
for n in 10-first 15-second 100-third; do
  printf '#!/bin/bash\n# step: %s\necho %s\n' "${n#*-}" "${n#*-}" > "$ORDER_DIR/$n.sh"
done
out=$(STEPS_DIR="$ORDER_DIR" WPAAS_DIR="$TMP/order-wpaas" run --non-interactive </dev/null)
assert_eq "steps run in numeric order" "$(grep -o '==> [a-z]*' <<<"$out" | tr '\n' ' ')" "==> first ==> second ==> third "

echo "--- run 12: --only with unknown step"
out=$(run --only nope 2>&1); rc=$?
assert_eq    "exit 2 on unknown step" "$rc" 2
assert_match "unknown step message" "$out" "unknown step: nope \\(see --list\\)"

echo
if [ "$fails" -eq 0 ]; then echo "ALL OK"; else echo "$fails FAILED"; exit 1; fi

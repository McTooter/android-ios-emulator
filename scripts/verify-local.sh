#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="${VERIFY_REPORT_DIR:-${ROOT_DIR}/build/local-verify}"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/report.txt"
: > "$REPORT"

pass() { printf 'PASS  %s\n' "$1" | tee -a "$REPORT"; }
skip_check() { printf 'SKIP  %s\n' "$1" | tee -a "$REPORT"; }
fail_check() { printf 'FAIL  %s\n' "$1" | tee -a "$REPORT"; exit 1; }
run_check() {
  local label="$1"; shift
  if "$@" >>"$REPORT_DIR/${label// /_}.log" 2>&1; then
    pass "$label"
  else
    cat "$REPORT_DIR/${label// /_}.log" >&2
    fail_check "$label"
  fi
}

cd "$ROOT_DIR"
printf 'Local verification report\n' | tee -a "$REPORT"
printf 'Repository: %s\n' "$ROOT_DIR" | tee -a "$REPORT"
printf 'UTC: %s\n\n' "$(date -u +%FT%H:%M:%SZ)" | tee -a "$REPORT"

command -v python3 >/dev/null || fail_check 'python3 is required'
run_check 'Guest manifest JSON' python3 -m json.tool Config/guest-manifest.example.json
run_check 'Python tool compilation' python3 -m py_compile tools/inspect_apk.py tools/qemu_args.py tools/test_guest_apk.py tools/test_qemu_args.py tools/validate_guest.py
rm -rf tools/__pycache__
run_check 'QEMU generator unit tests' python3 -m unittest discover -s tools -p 'test_*.py'

if command -v cmake >/dev/null; then
  run_check 'Native core configure' cmake -S Core -B Core/build -DCMAKE_BUILD_TYPE=Release
  run_check 'Native core build' cmake --build Core/build --parallel
  run_check 'Native core smoke test' Core/build/AndroidRuntimeCoreSmokeTest
else
  fail_check 'cmake is required for the native core checks'
fi

GRADLE_BIN="${GRADLE_BIN:-}"
if [ -z "$GRADLE_BIN" ] && command -v gradle >/dev/null 2>&1; then
  GRADLE_BIN="$(command -v gradle)"
fi
if [ -z "$GRADLE_BIN" ]; then
  for candidate in "$ROOT_DIR/gradle-8.7/bin/gradle" "$HOME/android-sdk-local/gradle-8.7/bin/gradle"; do
    if [ -x "$candidate" ]; then
      GRADLE_BIN="$candidate"
      break
    fi
  done
fi

if [ -n "$GRADLE_BIN" ] && [ -f test-apk/settings.gradle.kts ]; then
  if [ -n "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}" ]; then
    run_check 'Original test APK build' bash -c 'cd test-apk && "$1" --no-daemon :app:assembleDebug' _ "$GRADLE_BIN"
    apk="$ROOT_DIR/test-apk/app/build/outputs/apk/debug/app-debug.apk"
    if [ -f "$apk" ]; then
      run_check 'Original test APK inspection' python3 tools/inspect_apk.py "$apk"
      pass "Original test APK artifact: $apk"
    else
      fail_check 'Original test APK artifact missing after build'
    fi
  else
    skip_check 'Original test APK build (set ANDROID_HOME or ANDROID_SDK_ROOT)'
  fi
else
  skip_check 'Original test APK build (Gradle unavailable)'
fi

if [ -n "${ANDROID_GUEST_MANIFEST:-}" ]; then
  [ -f "$ANDROID_GUEST_MANIFEST" ] || fail_check "guest manifest not found: $ANDROID_GUEST_MANIFEST"
  run_check 'Guest manifest validation' python3 tools/validate_guest.py "$ANDROID_GUEST_MANIFEST"
  run_check 'QEMU argument generation' python3 tools/qemu_args.py "$ANDROID_GUEST_MANIFEST" --format shell
else
  skip_check 'Guest validation and QEMU argument generation (set ANDROID_GUEST_MANIFEST)'
fi

if [ -n "${ANDROID_TEST_APK:-}" ] && [ -n "${ANDROID_TEST_PACKAGE:-}" ]; then
  [ -f "$ANDROID_TEST_APK" ] || fail_check "test APK not found: $ANDROID_TEST_APK"
  run_check 'ADB install and launch harness' python3 tools/test_guest_apk.py "$ANDROID_TEST_APK" --package "$ANDROID_TEST_PACKAGE" --serial "${ADB_SERIAL:-127.0.0.1:5555}" --timeout "${ADB_TIMEOUT:-120}"
else
  skip_check 'ADB install and launch harness (set ANDROID_TEST_APK and ANDROID_TEST_PACKAGE)'
fi

pass "Local verification complete; report: $REPORT"

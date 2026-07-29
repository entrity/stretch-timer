# Center Zenity on the Primary Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Center the stretch timer's Zenity prompt on the primary X11 monitor without affecting other windows or changing the prompt's output and exit behavior.

**Architecture:** Add small, independently testable geometry helpers to the Linux platform adapter. Run Zenity and a best-effort positioning helper concurrently, wait for Zenity to finish, and return its status unchanged; missing tools or malformed desktop data only disable centering.

**Tech Stack:** Bash, Zenity 4, `xrandr`, `xdotool`, Git

---

## File Structure

- Modify `platform-linux.sh`: parse primary-monitor and window geometry, calculate centered coordinates, move Zenity, and preserve prompt behavior.
- Create `tests/platform-linux-test.sh`: dependency-free Bash assertions for coordinate calculation, parsing, fallback behavior, and the prompt contract.

### Task 1: Test Linux centering behavior

**Files:**
- Create: `tests/platform-linux-test.sh`
- Test: `tests/platform-linux-test.sh`

- [ ] **Step 1: Write the failing coordinate and parsing tests**

Create an executable test script that sources `platform-linux.sh`, records
failures, and checks geometry helpers with controlled command output:

```bash
#!/bin/bash

set -uo pipefail

THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$THIS_DIR/../platform-linux.sh" >/dev/null

FAILURES=0

assert_eq () {
  local expected=$1
  local actual=$2
  local description=$3
  if [[ $actual != "$expected" ]]; then
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' \
      "$description" "$expected" "$actual" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

test_center_coordinates_at_origin () {
  assert_eq "810 450" "$(_center_coordinates 0 0 1920 1080 300 180)" \
    "centers a window on a monitor at the origin"
}

test_center_coordinates_with_monitor_offset () {
  assert_eq "4010 660" "$(_center_coordinates 3440 240 1920 1200 780 360)" \
    "includes the primary monitor offset"
}

test_center_coordinates_round_down () {
  assert_eq "2 3" "$(_center_coordinates 0 0 6 8 1 1)" \
    "uses Bash integer division for odd differences"
}

test_primary_monitor_geometry () {
  xrandr () {
    printf '%s\n' \
      "Monitors: 2" \
      " 0: +HDMI-1-0 3440/800x1440/335+0+0 HDMI-1-0" \
      " 1: +*eDP-1 1920/344x1200/215+3440+240 eDP-1"
  }
  assert_eq "+3440 +240 1920 1200" "$(_get_primary_monitor_geometry)" \
    "parses the primary monitor and its nonzero origin"
  unset -f xrandr
}

test_window_size () {
  xdotool () {
    printf '%s\n' \
      "WINDOW=42" \
      "X=100" \
      "Y=200" \
      "WIDTH=640" \
      "HEIGHT=240" \
      "SCREEN=0"
  }
  assert_eq "640 240" "$(_get_window_size 42)" \
    "parses xdotool shell geometry"
  unset -f xdotool
}

test_center_coordinates_at_origin
test_center_coordinates_with_monitor_offset
test_center_coordinates_round_down
test_primary_monitor_geometry
test_window_size

if ((FAILURES)); then
  exit 1
fi
printf 'All platform-linux tests passed\n'
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
bash tests/platform-linux-test.sh
```

Expected: failures containing `command not found` for `_center_coordinates`,
`_get_primary_monitor_geometry`, and `_get_window_size`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/platform-linux-test.sh
git -c commit.gpgsign=false commit -m "test: cover Linux dialog positioning"
```

### Task 2: Implement geometry and best-effort positioning

**Files:**
- Modify: `platform-linux.sh`
- Test: `tests/platform-linux-test.sh`

- [ ] **Step 1: Add the geometry helpers**

Add these functions above `prompt` in `platform-linux.sh`:

```bash
_center_coordinates () {
  local monitor_x=$1
  local monitor_y=$2
  local monitor_width=$3
  local monitor_height=$4
  local window_width=$5
  local window_height=$6
  printf '%s %s\n' \
    "$((monitor_x + (monitor_width - window_width) / 2))" \
    "$((monitor_y + (monitor_height - window_height) / 2))"
}

_get_primary_monitor_geometry () {
  xrandr --listmonitors 2>/dev/null |
    awk '$2 ~ /\*/ { print $3; exit }' |
    sed -E \
      's#^([0-9]+)/[0-9]+x([0-9]+)/[0-9]+([+-][0-9]+)([+-][0-9]+)$#\3 \4 \1 \2#' |
    grep -E '^[+-][0-9]+ [+-][0-9]+ [0-9]+ [0-9]+$'
}

_get_window_size () {
  xdotool getwindowgeometry --shell "$1" 2>/dev/null |
    awk -F= '
      $1 == "WIDTH" { width = $2 }
      $1 == "HEIGHT" { height = $2 }
      END {
        if (width ~ /^[0-9]+$/ && height ~ /^[0-9]+$/) {
          print width, height
        } else {
          exit 1
        }
      }
    '
}

_center_zenity_window () {
  local zenity_pid=$1
  local monitor_geometry
  local window_id=
  local window_size
  local coordinates
  local monitor_x monitor_y monitor_width monitor_height
  local window_width window_height
  local coordinate_x coordinate_y
  local attempts=0

  command -v xrandr >/dev/null || return 0
  command -v xdotool >/dev/null || return 0
  monitor_geometry=$(_get_primary_monitor_geometry) || return 0
  while kill -0 "$zenity_pid" 2>/dev/null && ((attempts < 200)); do
    window_id=$(xdotool search --onlyvisible --pid "$zenity_pid" \
      2>/dev/null | head -n 1) || window_id=
    [[ $window_id =~ ^[0-9]+$ ]] && break
    attempts=$((attempts + 1))
    sleep 0.05
  done
  [[ $window_id =~ ^[0-9]+$ ]] || return 0
  window_size=$(_get_window_size "$window_id") || return 0
  read -r monitor_x monitor_y monitor_width monitor_height \
    <<<"$monitor_geometry" || return 0
  read -r window_width window_height <<<"$window_size" || return 0
  coordinates=$(_center_coordinates \
    "$monitor_x" "$monitor_y" "$monitor_width" "$monitor_height" \
    "$window_width" "$window_height") || return 0
  read -r coordinate_x coordinate_y <<<"$coordinates" || return 0
  xdotool windowmove "$window_id" "$coordinate_x" "$coordinate_y" \
    >/dev/null 2>&1 || true
}
```

- [ ] **Step 2: Run the geometry tests**

Run:

```bash
bash tests/platform-linux-test.sh
```

Expected: `All platform-linux tests passed`.

- [ ] **Step 3: Add prompt contract and fallback tests**

Insert these tests before the test invocations in
`tests/platform-linux-test.sh`:

```bash
test_prompt_preserves_output_and_status () {
  local center_marker
  center_marker=$(mktemp)
  zenity () {
    printf '20:00\n'
    return 7
  }
  _center_zenity_window () {
    printf 'called\n' >"$center_marker"
    return 0
  }

  local output
  local status
  output=$(prompt "Pomodoro WORK" "Enter time" "20")
  status=$?

  assert_eq "20:00" "$output" "preserves Zenity standard output"
  assert_eq "7" "$status" "preserves Zenity exit status"
  assert_eq "called" "$(<"$center_marker")" "runs the centering helper"
  rm "$center_marker"
  unset -f zenity
  unset -f _center_zenity_window
}

test_centering_failure_does_not_change_prompt () {
  local center_marker
  center_marker=$(mktemp)
  zenity () {
    printf '30\n'
    return 0
  }
  _center_zenity_window () {
    printf 'called\n' >"$center_marker"
    return 1
  }

  local output
  local status
  output=$(prompt "Pomodoro BREAK" "Enter time" "20")
  status=$?

  assert_eq "30" "$output" "keeps output when centering fails"
  assert_eq "0" "$status" "keeps status when centering fails"
  assert_eq "called" "$(<"$center_marker")" \
    "attempts centering without making it fatal"
  rm "$center_marker"
  unset -f zenity
  unset -f _center_zenity_window
}
```

Add the invocations after the geometry test invocations:

```bash
test_prompt_preserves_output_and_status
test_centering_failure_does_not_change_prompt
```

- [ ] **Step 4: Run the prompt tests to verify they fail**

Run:

```bash
bash tests/platform-linux-test.sh
```

Expected: prompt-contract failures stating that the centering helper was not
called because the existing foreground `prompt` does not invoke it.

- [ ] **Step 5: Update the prompt implementation**

Replace `prompt` in `platform-linux.sh` with:

```bash
prompt () {
  zenity --entry --title="$1" --text="$2" --entry-text="$3" &
  local zenity_pid=$!
  _center_zenity_window "$zenity_pid" &
  local centering_pid=$!
  local zenity_status

  wait "$zenity_pid"
  zenity_status=$?
  wait "$centering_pid" 2>/dev/null || true
  return "$zenity_status"
}
```

- [ ] **Step 6: Run static and automated verification**

Run:

```bash
bash -n platform-linux.sh tests/platform-linux-test.sh
bash tests/platform-linux-test.sh
git diff --check
```

Expected: no syntax or whitespace errors and
`All platform-linux tests passed`.

- [ ] **Step 7: Commit the implementation**

```bash
git add platform-linux.sh tests/platform-linux-test.sh
git -c commit.gpgsign=false commit -m "fix: center Zenity on the primary monitor"
```

### Task 3: Verify the real dialog and prepare review

**Files:**
- Modify only if verification exposes a defect: `platform-linux.sh`
- Test only if verification exposes a defect: `tests/platform-linux-test.sh`

- [ ] **Step 1: Open a real prompt**

Run:

```bash
bash -c '. ./platform-linux.sh >/dev/null; prompt "Stretch Timer Test" "Confirm this is centered" "20:00"'
```

Expected: the Zenity entry appears centered on the primary monitor. Entering
text prints it; Cancel returns Zenity's nonzero status.

- [ ] **Step 2: Run the complete verification again**

Run:

```bash
bash -n platform-linux.sh stretch-timer-daemon.sh tests/platform-linux-test.sh
bash tests/platform-linux-test.sh
git diff --check
git status --short
```

Expected: all tests pass, no whitespace errors, and no unrelated files are
modified.

- [ ] **Step 3: Push and open a merge request**

```bash
git push -u origin center-zenity-primary-monitor
```

Open a merge request titled
`fix: center Zenity on the primary monitor`, containing only the design,
implementation plan, tests, and Linux positioning implementation.

# Center Zenity on the Primary Monitor

## Goal

Center only the stretch timer's Zenity entry dialog on the primary monitor in
the current GNOME/X11 environment. Do not change GNOME's global window
placement behavior.

## Approach

Keep the behavior in the Linux platform adapter. The `prompt` function will
launch Zenity in the background, identify the resulting X11 window by the
Zenity process ID, and wait until that window is mapped. A focused helper will
then:

1. Read the primary monitor's position and dimensions from `xrandr`.
2. Read the Zenity window's dimensions with `xdotool`.
3. Calculate the top-left coordinates that center the window within the
   primary monitor, including monitors whose origin is not `(0,0)`.
4. Move the window to those coordinates with `xdotool`.

The prompt will still emit Zenity's entered text on standard output and return
Zenity's original exit status so callers retain their current behavior.

## Components

- `platform-linux.sh`: owns X11 window discovery, coordinate calculation, and
  best-effort positioning because these are Linux desktop concerns.
- A shell test file: exercises coordinate calculation and failure behavior
  without opening a real dialog.

Coordinate calculation will be isolated from desktop commands so it can be
tested deterministically.

## Failure Behavior

Centering is best effort. If `xrandr` or `xdotool` is unavailable, the primary
monitor cannot be identified, the Zenity window cannot be found, or movement
fails, Zenity remains open at GNOME's chosen location. Positioning failures
must not alter the dialog's output or exit status.

## Scope

This change supports the current GNOME/X11 environment. Native Wayland window
positioning is explicitly out of scope because Wayland clients cannot choose
their own global screen coordinates.

## Verification

Automated shell tests will verify:

- Centering on a primary monitor at origin `(0,0)`.
- Centering on a primary monitor with a nonzero origin.
- Correct integer rounding for odd size differences.
- Graceful fallback when positioning dependencies or monitor/window data are
  unavailable.
- Preservation of Zenity output and exit status.

A manual check will confirm that the real Zenity prompt appears centered on
the primary monitor.

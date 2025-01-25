# Configuration Files

Amethyst will pick up a config file located at `~/.amethyst.yml` or `~/.config/amethyst/amethyst.yml` in this order. A sample can be found at [/.amethyst.sample.yml](../.amethyst.sample.yml)

## Configuration Keys

| Key | Description |
| -- | -- |
| `layouts` | Ordered list of layouts to use by layout key (default tall, wide, fullscreen, and column). |
| `mod1` | First mod (default option + shift). |
| `mod2` | Second mod (default option + shift + control). |
| `mod3` | Third mod (not used by default). |
| `mod4` | Fourth mod (not used by default). |
| `window-max-count` | The max number of windows that may be visible on a screen at one time before additional windows are minimized. A value of 0 disables the feature. |
| `window-margins` | Boolean flag for whether or not to add margins between and around windows (default `false`). |
| `smart-window-margins` | Boolean flag for whether or not to set window margins if there is only one window on the screen, assuming window margins are enabled (default `false`). |
| `window-margin-size` | The size of the margins between and around windows (in px, default `0`). |
| `window-minimum-height` | The smallest height that a window can be sized to regardless of its layout frame (in px, default `0`). |
| `window-minimum-width` | The smallest width that a window can be sized to regardless of its layout frame (in px, default `0`) |
| `floating` | List of bundle identifiers for applications to either be automatically floating or automatically tiled based on `floating-is-blacklist` (default `[]`). |
| `floating-is-blacklist` | Boolean flag determining behavior of the `floating` list. `true` if the applications should be floating and all others tiled. `false` if the applications should be tiled and all others floating (default `true`). |
| `ignore-menu-bar` | `true` if screen frames should exclude the status bar. `false` if the screen frames should include the status bar (default `false`). |
| `float-small-windows` | `true` if windows smaller than a 500px square should be floating by default (default `true`) |
| `mouse-follows-focus` | `true` if the mouse should move position to the center of a window when it becomes focused (default `false`). Note that this is largely incompatible with `focus-follows-mouse`. |
| `focus-follows-mouse` | `true` if the windows underneath the mouse should become focused as the mouse moves (default `false`). Note that this is largely incompatible with `mouse-follows-focus` |
| `mouse-swaps-windows` | `true` if dragging and dropping windows on to each other should swap their positions (default `false`). |
| `mouse-resizes-windows` | `true` if changing the frame of a window with the mouse should update the layout to accommodate the change (default `false`). Note that not all layouts will be able to respond to the change. |
| `enables-layout-hud` | `true` to display the name of the layout when a new layout is selected (default `true`). |
| `enables-layout-hud-on-space-change` | `true` to display the name of the layout when moving to a new space (default `true`). |
| `use-canary-build` | `true` to get updates to beta versions of the software (default `false`). |
| `new-windows-to-main` | `true` to insert new windows into the first position and `false` to insert new windows into the last position (default `false`). |
| `follow-space-thrown-windows` | `true` to automatically move to a space when throwing a window to it (default `true`). | 
| `window-resize-step` | The integer percentage of the screen dimension to increment and decrement main pane ratios by (default `5`). |
| `screen-padding-left` | Padding to apply between windows and the left edge of the screen (in px, default `0`). |
| `screen-padding-right` | Padding to apply between windows and the right edge of the screen (in px, default `0`). |
| `screen-padding-top` | Padding to apply between windows and the top edge of the screen (in px, default `0`). |
| `screen-padding-bottom` | Padding to apply between windows and the bottom edge of the screen (in px, default `0`).
| `restore-layouts-on-launch` | `true` to maintain layout state across application executions (default `true`). |
| `debug-layout-info` | `true` to display some optional debug information in the layout HUD (default `false`). |
| `disable-padding-on-builtin-display` |  `true` to disable screen padding on in-built display (default `false`). |
| `hide-menu-bar-icon` | `true` to hide the menu bar icon (default `false`). |

## Commands

Commands are defined at the root of the config file, as either an object with `mod` and `key` values to customize the command or is `false` to entirely disable it.

| Key | Description |
| --- | ----------- |
| `mod` | The modifier to use, either `mod1`, `mod2`, `mod3` or `mod4`. |
| `key` | The key on the keyboard to use. |

### Mods

A mod is a list of keyboard modifiers. Namely, `option`, `control`, `shift`, and `command`.

### Command Keys

| Command | Description |
| ------- | ------------|
| `cycle-layout` | Move to the next layout in the list. |
| `cycle-layout-backward` | Move to the previous layout in the list. |
| `shrink-main` | Shrink the main pane by a percentage of the screen dimension as defined by `window-resize-step`. Note that not all layouts respond to this command. |
| `expand-main` | Expand the main pane by a percentage of the screen dimension as defined by `window-resize-step`. Note that not all layouts respond to this command. |
| `increase-main` | Increase the number of windows in the main pane. Note that not all layouts respond to this command. |
| `decrease-main` | Decrease the number of windows in the main pane. Note that not all layouts respond to this command. |
| `command1` | General purpose command for custom layouts. Functionality is layout-dependent. |
| `command2` | General purpose command for custom layouts. Functionality is layout-dependent. |
| `command3` | General purpose command for custom layouts. Functionality is layout-dependent. |
| `command4` | General purpose command for custom layouts. Functionality is layout-dependent. |
| `focus-ccw` | Focus the next window in the list going counter-clockwise. |
| `focus-cw` | Focus the next window in the list going clockwise. |
| `focus-main` | Focus the main window in the list. |
| `focus-screen-ccw` | Focus the next screen in the list going counter-clockwise. |
| `focus-screen-cw` | Focus the next screen in the list going clockwise. |
| `swap-screen-ccw` | Move the currently focused window onto the next screen in the list going counter-clockwise. |
| `swap-screen-cw` | Move the currently focused window onto the next screen in the list going clockwise. |
| `swap-ccw` | Swap the position of the currently focused window with the next window in the list going counter-clockwise. |
| `swap-cw` | Swap the position of the currently focused window with the next window in the list going clockwise. |
| `swap-main` | Swap the position of the currently focused window with the main window in the list. |
| `focus-screen-n` | Move focus to the n-th screen in the list; e.g., `focus-screen-3` will move mouse focus to the 3rd screen. Note that the main window in the given screen will be focused. |
| `throw-screen-n` | Move the currently focused window to the n-th screen; e.g., `throw-screen-3` will move the window to the 3rd screen. |
| `throw-space-n` | Move the currently focused window to the n-th space; e.g., `throw-space-3` will move the window to the 3rd space. |
| `throw-space-left` | Move the currently focused window to the space to the left. |
| `throw-space-right` | Move currently the focused window to the space to the right. |
| `toggle-float` | Toggle the floating state of the currently focused window; i.e., if it was floating make it tiled and if it was tiled make it floating. |
| `display-current-layout` | Display the layout HUD with the current layout on each screen. |
| `toggle-tiling` | Turn on or off tiling entirely. |
| `reevaluate-windows` | Rerun the current layout's algorithm. |
| `toggle-focus-follows-mouse` | Turn on or off `focus-follows-mouse`. |
| `relaunch-amethyst` | Automatically quit and reopen Amethyst. |

### Layout Selection

Amethyst supports defining shortcuts for selecting specific layouts directly. They take the form of `select-${layout_key}-layout`. For example, defining the command `select-tall-layout` will define a shortcut that when used will switch directly to the Tall layout. Note, this works for custom layouts as well.

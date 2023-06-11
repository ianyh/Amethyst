# Window Limit 

## How To Enable

In the General tab of Amethyst's preferences, there is a Maximum Window Count field. Setting this field to a value greater than 0 will enable the feature.

## Behavior

* Windows set to float using the keyboard shortcut will not be minimized.
* Main windows will not be minimized. Enable ‘Send new windows to main pane’ to have the oldest window cycle out. Disable the setting to exclude main panes, which will act as a persistent workspace alongside other windows.
* The window limit applies on a per-screen basis.
* Disabling Amethyst will disable window limits. Use the Floating layout to apply window limits without any window tiling.

## Recommendations

It is recommended to enable macOS's setting under System Preferences's Dock pane to minimize windows into their dock icon. This will avoid Dock clutter building up while using the feature.

To create an iPad-like experience:
* Set window limit to 2, and have just fullscreen & 1 "paned layout" enabled. Cycle between layouts to toggle between fullscreen & split view.
* Enable "Swap windows using mouse" & "Resize windows using mouse".
* Float windows to put them in slide-over mode.

##　Limitations

* The window limit may not be enforced when windows are moved between screens. Creating a new window will correct the issue.  

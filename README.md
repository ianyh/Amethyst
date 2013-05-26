Amethyst
========

Tiling window manager for OS X similar to xmonad. Was originally written as an
alternative to [fjolnir's](https://github.com/fjolnir) awesome
[xnomad](https://github.com/fjolnir/xnomad) but written in pure
Objective-C. It's expanded to include some more features like Spaces support not
reliant on fragile private APIs.

![Screenshot](https://raw.github.com/ianyh/Amethyst/gh-pages/images/screenshot-small.png)

Credits
-------

Credit goes to [fjolnir](https://github.com/fjolnir) for the bulk of the initial
logic and structure.

Using Amethyst
==============

The `Enable access for assistive devices` option on the Accessibility
preferences pane must be enabled for Amethyst to function.

![Enable access for assistive devices](https://raw.github.com/ianyh/Amethyst/gh-pages/images/accessibility-window.png)

Keyboard Shortcuts
------------------

Amethyst uses three modifier combinations.

* `mod1` - `option + shift`
* `mod2` - `ctrl + option + shift`
* `mod3` - `ctrl + option`

And defines the following commands.

* `mod1 + space` — change layout
* `mod1 + [n]` - focus the nth screen
* `mod2 + [n]` - move focused window to nth screen
* `mod3 + [n]` - move focused window to nth space
* `mod1 + h` - shrink the main pane
* `mod1 + l` - expand the main pane
* `mod1 + ,` - increase the number of windows in the main pane
* `mod1 + .` - decrease the number of windows in the main pane
* `mod1 + j` - focus the next window counterclockwise
* `mod1 + k` - focus the next window clockwise
* `mod2 + j` - move the focused window one space counterclockwise
* `mod2 + k` - move the focused window one space clockwise
* `mod1 + return` - swap the focused window with the main window

Setting Up Spaces Support
-------------------------

Spaces are, unfortunately, not supported right out of the box. To enable it you
must activate Mission Control's keyboard shortcuts for switching to specific
Desktops, as Mac OS X calls them. This option is in the Keyboard Shortcuts tab
of the Keyboard preferences pane. The shortcuts will be of the form `ctrl +
[n]`. Amethyst is only able to send a window to the `n`th space if the shortcut
`ctrl + n` is enabled.

![Mission Control keyboard shortcuts](https://raw.github.com/ianyh/Amethyst/gh-pages/images/missioncontrol-shortcuts.png)

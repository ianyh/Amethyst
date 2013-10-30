Amethyst
========

[![Build Status](https://travis-ci.org/ianyh/Amethyst.png?branch=master)](https://travis-ci.org/ianyh/Amethyst)

Tiling window manager for OS X similar to xmonad. Was originally written as an
alternative to [fjolnir's](https://github.com/fjolnir) awesome
[xnomad](https://github.com/fjolnir/xnomad) but written in pure
Objective-C. It's expanded to include some more features like Spaces support not
reliant on fragile private APIs.

![Screenshot](http://ianyh.com/amethyst/images/screenshot-small.png)

Credits
-------

Credit goes to [fjolnir](https://github.com/fjolnir) for the bulk of the initial
logic and structure.

Getting Amethyst
================

Amethyst is available for direct download [here](http://ianyh.com/amethyst/versions/Amethyst-0.8.3.zip) or using [homebrew cask](https://github.com/phinze/homebrew-cask).

```
brew cask install amethyst
```

Note: that Amethyst now is only supported on OS X 10.9. The last version that supports 10.8 can be found [here](http://ianyh.com/amethyst/versions/Amethyst-0.8.2.zip).

Building
--------

0. Install the latest version of XCode
1. Clone the project, then `cd` to the Amethyst directory.
2. Install xctool
    - `brew update && brew install xctool` 
    - you may need to accept all XCode licenses, e.g. `sudo xcodebuild -license`
3. Install cocoapods
    - `gem install cocoapods`
    - you may need to `exec zsh` or similar for this command to be found, if using rbenv.
7. `rake install`
8. `cp Amethyst/default.amethyst ~/.amethyst`

Using Amethyst
==============

The `Enable access for assistive devices` option on the Accessibility
preferences pane must be enabled for Amethyst to function.

![Enable access for assistive devices](http://ianyh.com/amethyst/images/accessibility-window.png)

Keyboard Shortcuts
------------------

Amethyst uses two modifier combinations.

* `mod1` - `option + shift`
* `mod2` - `ctrl + option + shift`

And defines the following commands, mostly a mapping to xmonad key combinations.

* `mod1 + space` — change layout
* `mod1 + w` - focus 1st screen
* `mod1 + e` - focus 2nd screen
* `mod1 + r` - focus 3rd screen
* `mod2 + w` - move focused window to 1st screen
* `mod2 + e` - move focused window to 2nd screen
* `mod2 + r` - move focused window to 3rd screen
* `mod2 + [n]` - move focused window to nth space
* `mod1 + h` - shrink the main pane
* `mod1 + l` - expand the main pane
* `mod1 + ,` - increase the number of windows in the main pane
* `mod1 + .` - decrease the number of windows in the main pane
* `mod1 + j` - focus the next window counterclockwise
* `mod1 + k` - focus the next window clockwise
* `mod2 + j` - move the focused window one space counterclockwise
* `mod2 + k` - move the focused window one space clockwise
* `mod1 + return` - swap the focused window with the main window
* `mod1 + t` - toggle whether or not the focused window is floating

Setting Up Spaces Support
-------------------------

Spaces are, unfortunately, not supported right out of the box. To enable it you
must activate Mission Control's keyboard shortcuts for switching to specific
Desktops, as Mac OS X calls them. This option is in the Keyboard Shortcuts tab
of the Keyboard preferences pane. The shortcuts will be of the form `ctrl +
[n]`. Amethyst is only able to send a window to the `n`th space if the shortcut
`ctrl + n` is enabled.

![Mission Control keyboard shortcuts](http://ianyh.com/amethyst/images/missioncontrol-shortcuts.png)

Customization
-------------

Amethyst can be customized by creating a json file called `.amethyst` in your home directory. The structure and valid keys and whatnot are all defined in [default.amethyst](Amethyst/default.amethyst).

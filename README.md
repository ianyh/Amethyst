Amethyst
========

[![Build Status](https://travis-ci.org/ianyh/Amethyst.png?branch=master)](https://travis-ci.org/ianyh/Amethyst)

Tiling window manager for OS X similar to xmonad. Was originally written as an
alternative to [fjolnir's](https://github.com/fjolnir) awesome
[xnomad](https://github.com/fjolnir/xnomad) but written in pure
Objective-C. It's expanded to include some more features like Spaces support not
reliant on fragile private APIs.

![Screenshot](http://ianyh.com/amethyst/images/screenshot-small.png)

A quick screencast of basic functionality can be found [here](http://youtu.be/9ayUdV1sfjA). (It's rough, and I'd love to see a better one if someone has the skills and inclination to make one.)

Credits
-------

Credit goes to [fjolnir](https://github.com/fjolnir) for the bulk of the initial
logic and structure.

Getting Amethyst
================

Amethyst is available for direct download [here](http://ianyh.com/amethyst/versions/Amethyst-0.8.5.1.zip) or using [homebrew cask](https://github.com/phinze/homebrew-cask).

```
brew cask install amethyst
```

Note: that Amethyst now is only supported on OS X 10.9. The last version that supports 10.8 can be found [here](http://ianyh.com/amethyst/versions/Amethyst-0.8.2.zip).

Building
--------

0. Install the latest version of Xcode
1. Clone the project, then `cd` to the Amethyst directory.
2. Install xctool
    - `brew update && brew install xctool`
    - you may need to accept all XCode licenses, e.g. `sudo xcodebuild -license`
3. Install cocoapods
    - `gem install cocoapods`
    - you may need to `exec zsh` or similar for this command to be found, if using rbenv.
7. `rake install`
8. `cp Amethyst/default.amethyst ~/.amethyst`

Contributing
============

If you'd like to contribute please branch off of the `development` branch. Otherwise just try to stick to the general style of the code.

Contact
=======

If you have questions or feedback you can [email me](mailto:ianynda@gmail.com) or [drop by #amethyst on Freenode](http://webchat.freenode.net/?channels=amethyst).

Using Amethyst
==============

Amethyst must be given permissions to use the accessibility APIs under the Privacy tab of the Security & Privacy preferences pane as shown below.

![Accessibility permissions](http://ianyh.com/amethyst/images/accessibility-window.png)

Keyboard Shortcuts
------------------

Amethyst uses two modifier combinations.

* `mod1` - `option + shift`
* `mod2` - `ctrl + option + shift`

And defines the following commands, mostly a mapping to xmonad key combinations.

* `mod1 + space` — cycle to next layout
* `mod2 + space` - cycle to previous layout
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
* `mod1 + i` - display the current layout for each screen

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

### Layouts

You can set the layouts you want to use by supplying a list of layout names under the "layouts" key. For example,

```js
"layouts": [
    "tall",
    "fullscreen",
],
```
will restrict your layouts to the tall and fullscreen layouts. The available layouts are as follows:

* **Tall** ("tall"): Defines a main area on the left and a secondary area on the right.
* **Wide** ("wide"): Defines a main area on the top and a secondary column on the right.
* **Fullscreen** ("fullscreen"): All windows are sized to fill the screen.
* **Column** ("column"): All windows are distributed in evenly sized in columns from left to right.
* **Row** ("row"): All windows are distributed in evenly sized rows from top to bottom.
* **Floating** ("floating"): All windows are floating. (Useful if you want a space dedicated to floating windows.)
* **Widescreen Tall** ("widescreen-tall"): Like Tall, but the main area uses columns and the secondary area uses rows.

### Mouse Follows Focus

This setting can be enabled by changing the following line

```js
"mouse-follows-focus": false,
```

to

```js
"mouse-follows-focus": true,
```

in your `.amethyst` file.


### Always float an app

You can set specific application to float by default, this can still be toggled by `mod1-t`

```js
"floating": [
    "com.apple.systempreferences"
],
```

Get the required string for the app `osascript -e 'id of app "Finder"'`. Just replace `Finder` with the name of your app

### Layout HUD

By default Amethyst pops up a HUD telling you the layout whenever the layout changes. You can disable it in your `.amethyst` file using the `enables-layout-hud` key. i.e.,

```js
"enables-layout-hud": false
```

By default the HUD will show when changing to a different space. You can disable the HUD during space changes, while still having it enabled when cycling or selecting a different layout, by using the `enables-layout-hud-on-space-change` key. i.e.,

```js
"enables-layout-hud-on-space-change": false
```

### Window Padding

By default Amethyst has no padding between windows inside layouts.  To turn on padding for all layouts, use the `window-padding` key in your `.amethyst` file. i.e.,

```js
"window-padding": 10
```

Amethyst
========

[![Join the chat at https://gitter.im/ianyh/Amethyst](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ianyh/Amethyst?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](https://api.travis-ci.org/ianyh/Amethyst.svg?branch=development)](https://travis-ci.org/ianyh/Amethyst)
[![Open Source Helpers](https://www.codetriage.com/ianyh/amethyst/badges/users.svg)](https://www.codetriage.com/ianyh/amethyst)
[![Reviewed by Hound](https://img.shields.io/badge/Reviewed_by-Hound-8E64B0.svg)](https://houndci.com)

Tiling window manager for macOS along the lines of [xmonad](http://xmonad.org/).

![Windows](http://ianyh.com/amethyst/images/windows.png)

A quick screencast of basic functionality can be found [here](https://youtu.be/boPilhScpkY). (It's rough, and I'd love to see a better one if someone has the skills and inclination to make one.)

Getting Amethyst
================

Amethyst is available for direct download on the [releases page](https://github.com/ianyh/Amethyst/releases) or using [homebrew cask](https://github.com/caskroom/homebrew-cask).

```
brew cask install amethyst
```

Note: that Amethyst now is only supported on OS X 10.12+.

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
* `mod2 + left` - move focused window left one space
* `mod2 + right` - move focused window right one space
* `mod1 + h` - shrink the main pane
* `mod1 + l` - expand the main pane
* `mod1 + ,` - increase the number of windows in the main pane
* `mod1 + .` - decrease the number of windows in the main pane
* `mod1 + j` - focus the next window counterclockwise
* `mod1 + k` - focus the next window clockwise
* `mod2 + j` - move the focused window one space counterclockwise
* `mod2 + k` - move the focused window one space clockwise
* `mod2 + h` - move the focused window one window counterclockwise
* `mod2 + l` - move the focused window one window clockwise
* `mod1 + return` - swap the focused window with the main window
* `mod1 + t` - toggle whether or not the focused window is floating
* `mod2 + t` - toggle globally whether or not Amethyst tiles windows
* `mod1 + i` - display the current layout for each screen
* `mod1 + z` - force windows to be reevalulated

Available Layouts
-----------------

Amethyst allows you to cycle among several different window layouts.
Layouts can also be enabled/disabled to control whether they appear in the cycle sequence at all.

* *Tall*
> The default layout. This gives you one "main pane" on the left, and one other
> pane on the right. By default, one window is placed in the main pane
> (extending the full height of the screen), and all remaining windows are
> placed in the other pane. If either pane has more than one window, that pane
> will be evenly split into rows, to show them all.
> You can use the keyboard shortcuts above to control which window(s), and
> how many, are in the main pane, as well as the horizontal size of the main
> pane vs. the other pane.
* *Tall-Right*
> Exactly the same as *Tall*, but the main pane is on the right, with the other
> pane on the left.
* *Wide*
> The rotated version of *Tall*, where the main pane is on the _top_ (extending
> the full width of the screen), and the other pane is on the bottom.
> If either pane has more than one window, that pane will split into columns
> instead of rows.
* *3Column-Middle*
> A three-column layout, with one main pane in the center (extending the full
> height of the screen) and two other panes, one on each side of the main pane.
> Like *Tall*, if any pane has more than one window, that pane will be split
> into rows.
> You can control how many windows are in the main pane as usual; other windows
> will be assigned as evenly as possible between the left and the right pane.
> (In previous versions of Amethyst, this layout was known as *Middle-Wide*.)
* *Widescreen-Tall*
> This mode is like *Tall*, but if there are multiple windows in the main pane,
> the main pane splits into columns rather than rows.
> The other pane still splits windows into rows, like *Tall*.
> This layout gets its name because it probably makes the most sense on very
> wide screens, with a large main pane consisting of several columns, and all
> remaining windows stacked into the final column.
> Other layouts that work well on very wide screens include any that allow for
> more than two columns (to take advantage of the screen width), such as
> *3Column-Middle* or *Column*.
* *Fullscreen*
> In this layout, the currently focused window takes up the entire screen, and
> the other windows are not visible at all.
> You can rotate between each of the windows using the "focus the next window"
> shortcut, as usual.
* *Column*
> This layout has one column per window, with each window extending the full
> height of the screen.
> The farthest-left window is considered the "main" window in the sense that
> you can change its size with the "shrink/expand the main pane" shortcuts;
> the other windows split the remaining space evenly.
* *Row*
> The rotated version of *Column*, where each window takes up an entire row,
> extending the full width of the screen.
* *Floating*
> This mode makes all windows "floating", allowing you to move and resize them
> as if Amethyst were temporarily deactivated.
> Unlike the other modes, this will mean that windows can be placed "on top of"
> each other, obscuring your view of some windows.
* *Binary Space Partitioning (BSP)*
> This layout does not have a main pane in the way that other layouts do.
> When adding windows, any given pane can be split evenly into two panes along
> whatever axis is longer. This is recursive such that pane A can be split in
> the middle into pane A on the left and pane B on the right; pane B can then
> be split into pane B on top and pane C on bottom; pane C can then be split
> into pane C on the left and pane D on the right; and so on.

Setting Up Spaces Support
-------------------------

Spaces are, unfortunately, not supported right out of the box. To enable it you
must activate Mission Control's keyboard shortcuts for switching to specific
Desktops, as Mac OS X calls them. This option is in the Keyboard Shortcuts tab
of the Keyboard preferences pane. The shortcuts will be of the form `ctrl +
[n]`. Amethyst is only able to send a window to the `n`th space if the shortcut
`ctrl + n` is enabled.

![Mission Control keyboard shortcuts](http://ianyh.com/amethyst/images/missioncontrol-shortcuts.png)

Amethyst currently supports sending windows to up to 10 spaces, despite macOS' limit of 16 spaces per display.

_Important note_: You will probably want to disable `Automatically rearrange Spaces based on most recent use` (found under Mission Control in System Preferences). This setting is enabled by default, and will cause your Spaces to swap places based on use. This makes keyboard navigation between Spaces unpredictable.

Contributing
============

If you would like to see features or particular bugs fixed check out the Trello board [here](https://trello.com/b/cCg3xhlb/amethyst) and vote on things. It'll give me a better sense of what people want so I can prioritize.

If you'd like to contribute please branch off of the `development` branch and open pull requests against it rather than `master`. Otherwise just try to stick to the general style of the code. There is a setup script to guide you through the process of installing necessary tools and getting dependencies built. To get started run

```bash
$ ./bin/setup.sh
```

Contact
=======

If you have questions or feedback you have a plethora of options. You can [email me](mailto:ianynda@gmail.com), [tweet at me](https://twitter.com/ianyh), or get on [gitter](https://gitter.im/ianyh/Amethyst).

Donating
========

Amethyst is free and always will be. That said, a couple of people have expressed their desire to donate money in appreciation. Given the current political climate I would recommend donating to one of these organizations instead:

* [American Civil Liberties Union](https://www.aclu.org/)
* [Planned Parenthood](https://www.plannedparenthood.org/)
* [Southern Poverty Law Center](https://www.splcenter.org/)
* [National Resources Defense Council](https://www.nrdc.org/)
* [International Refugee Assistance Project](https://refugeerights.org/)
* [NAACP Legal Defense Fund](http://www.naacpldf.org/)
* [The Trevor Project](http://www.thetrevorproject.org/)
* [Mexican American Legal Defense Fund](http://maldef.org/)
* [ProPublica](https://www.propublica.org/)

And a bunch of technology-oriented ones:

* [National Center for Women & Information Technology](https://www.ncwit.org/donate)
* [girls who code](http://girlswhocode.com/get-involved/)
* [MotherCoders](https://www.indiegogo.com/projects/mothercoders-a-giant-hack-for-moms-who-want-in)
* [Trans*H4CK](http://www.transhack.org/donate/)
* [Black Girls CODE](http://www.blackgirlscode.com/)

Alternatively, I have a Patreon page set up [here](https://www.patreon.com/ianyh). Any proceeds will be donated to one of the above organizations. 

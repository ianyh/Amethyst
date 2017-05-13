Amethyst
========

[![Join the chat at https://gitter.im/ianyh/Amethyst](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ianyh/Amethyst?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](https://api.travis-ci.org/ianyh/Amethyst.svg?branch=development)](https://travis-ci.org/ianyh/Amethyst)

Tiling window manager for macOS along the lines of [xmonad](http://xmonad.org/).

![Windows](http://ianyh.com/amethyst/images/windows.png)

A quick screencast of basic functionality can be found [here](https://youtu.be/boPilhScpkY). (It's rough, and I'd love to see a better one if someone has the skills and inclination to make one.)

Getting Amethyst
================

Amethyst is available for direct download [here](http://ianyh.com/amethyst/versions/Amethyst-latest.zip) or using [homebrew cask](https://github.com/caskroom/homebrew-cask).

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

Amethyst is free and always will be. That said, a couple of people have expressed their desire to donate money in appreciation. If you are so inclined I've set up two options:

* You can find a Patreon page [here](http://www.patreon.com/ianyh) if you would like to pledge money regularly for releases.
* If you would like to do a one-time donation there's a PayPal button below. If there's some other method of donating that you would prefer open an issue and I'll try to add it!

[![PayPal Donate](https://img.shields.io/badge/paypal-donate-blue.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=ianynda%40gmail%2ecom&lc=US&item_name=Ian%20Ynda%2dHummel&item_number=Amethyst&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_LG%2egif%3aNonHosted)

If you are considering donating to me, you are more than welcome to. Given the political climate in the US, though, you should also consider donating that money to a good cause in addition to or instead. Here's a very incomplete list of things that you might want to throw money at:

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

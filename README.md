Amethyst
========

[![Join the chat at https://gitter.im/ianyh/Amethyst](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ianyh/Amethyst?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](https://api.travis-ci.org/ianyh/Amethyst.svg?branch=master)](https://travis-ci.org/ianyh/Amethyst)

Tiling window manager for OS X along the lines of [xmonad](http://xmonad.org/) and [i3](https://i3wm.org/).

![Example 1](http://ianyh.com/amethyst/images/example-1.gif)

A quick screencast of basic functionality can be found [here](https://youtu.be/boPilhScpkY). (It's rough, and I'd love to see a better one if someone has the skills and inclination to make one.)

Getting Amethyst
================

Amethyst is available for direct download [here](http://ianyh.com/amethyst/versions/Amethyst-latest.zip) or using [homebrew cask](https://github.com/caskroom/homebrew-cask).

```
brew cask install amethyst
```

Note: that Amethyst now is only supported on OS X 10.9+. The last version that supports 10.8 can be found [here](http://ianyh.com/amethyst/versions/Amethyst-0.8.2.zip).

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
* `mod2 + t` - toggle globally whether or not Amethyst tiles windows
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

Contributing
============

If you would like to see features or particular bugs fixed check out the Trello board [here](https://trello.com/b/cCg3xhlb/amethyst) and vote on things. It'll give me a better sense of what people want so I can prioritize.

I love pull requests. If you'd like to contribute please branch off of the `development` branch and open pull requests against it rather than master. Otherwise just try to stick to the general style of the code.

In order to build Amethyst locally, you'll need to also perform the following steps after cloning the repo:

- Run `rake setup`, which installs dependencies from Carthage and CocoaPods.

Contact
=======

If you have questions or feedback you have a plethora of options. You can [email me](mailto:ianynda@gmail.com), [tweet at me](https://twitter.com/ianyh), or get on [gitter](https://gitter.im/ianyh/Amethyst). That last one is new and kind of experimental. You can [drop by #amethyst on Freenode](http://webchat.freenode.net/?channels=amethyst), as well, but I am on there fairly infrequently.

Donating
========

Amethyst is free and always will be. That said, a couple of people have expressed their desire to donate money in appreciation. If you are so inclined I've set up two options:

* You can find a Patreon page [here](http://www.patreon.com/ianyh) if you would like to pledge money regularly for releases.
* If you would like to do a one-time donation there's a PayPal button below. If there's some other method of donating that you would prefer open an issue and I'll try to add it!

[![PayPal Donate](https://img.shields.io/badge/paypal-donate-blue.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=ianynda%40gmail%2ecom&lc=US&item_name=Ian%20Ynda%2dHummel&item_number=Amethyst&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_LG%2egif%3aNonHosted)

If you are considering donating to me, you are more than welcome to. You should also consider donating that money to a charity in addition to or instead. Here's a very incomplete list of things that you might want to throw money at:

* [Freedom to Marry](https://secure.freedomtomarry.org/pages/donatetowin?source=BSDAds_GoogleGrant_EOY2013_Freedom%20to%20Marry-GG_Freedom%20to%20Marry_freedomtomarry&gclid=Cj0KEQjwq52iBRDEvrC12Jnz6coBEiQA2otXAsmb9ggRZp1ukDdxwvn7Y-1AN7mhTPZxcpC3dNokzY8aAmcl8P8HAQ)
* [Doctors Without Borders](https://donate.doctorswithoutborders.org/monthly.cfm?source=AZD140001D51&utm_source=google&utm_medium=ppc&gclid=Cj0KEQjwq52iBRDEvrC12Jnz6coBEiQA2otXAt-jLIelzmFWTo9t3xnrXGnyjffRnHQ_Ug2o6C1PdvkaAqQt8P8HAQ)
* [American Civil Liberties Union](https://www.aclu.org/secure/our-civil-liberties-are-under-attack-3?s_src=UNW140001SEM&ms=gad_SEM_Google_Search-Evergreen-ACLU%20Brand_ACLU%20Name%20Terms_DD_B2_aclu_e_53001180982)
* [Heifer International](http://www.heifer.org/what-you-can-do/index.html)

And a bunch of technology-oriented ones:

* [Ada Initiative](https://adainitiative.org/donate/)
* [National Center for Women & Information Technology](https://www.ncwit.org/donate)
* [girls who code](http://girlswhocode.com/get-involved/)
* [MotherCoders](https://www.indiegogo.com/projects/mothercoders-a-giant-hack-for-moms-who-want-in)
* [Trans*H4CK](http://www.transhack.org/support/)
* [Black Girls CODE](http://www.blackgirlscode.com/)

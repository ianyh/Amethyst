# Amethyst

[![Join the chat at https://gitter.im/ianyh/Amethyst](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ianyh/Amethyst?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](https://travis-ci.com/ianyh/Amethyst.svg?branch=development)](https://travis-ci.com/ianyh/Amethyst)
[![Open Source Helpers](https://www.codetriage.com/ianyh/amethyst/badges/users.svg)](https://www.codetriage.com/ianyh/amethyst)
[![Reviewed by Hound](https://img.shields.io/badge/Reviewed_by-Hound-8E64B0.svg)](https://houndci.com)
[![Twitter Follow](https://img.shields.io/twitter/follow/amethystwm?style=social)](https://twitter.com/amethystwm)

Tiling window manager for macOS along the lines of [xmonad](https://xmonad.org/).

![Windows](https://ianyh.com/amethyst/images/windows.png)

A quick screencast of basic functionality can be found [here](https://youtu.be/boPilhScpkY). (It's rough, and I'd love to see a better one if someone has the skills and inclination to make one.)

## Getting Amethyst

Amethyst is available for direct download on the [releases page](https://github.com/ianyh/Amethyst/releases) or using [homebrew cask](https://github.com/Homebrew/homebrew-cask).

```
brew install --cask amethyst
```

Note: that Amethyst now is only supported on macOS 10.12+.

## System Settings

Amethyst must be given permissions to use the accessibility APIs under the Privacy tab of the Security & Privacy preferences pane as shown below.

![Accessibility permissions](https://ianyh.com/amethyst/images/accessibility-window.png

## Keyboard Shortcuts

Make sure you read the [Terminologies](docs/Terminologies.md) before proceeding further.

Amethyst uses two modifier combinations.

| Default Shortcut | Description |
|---|---|
| `mod1` | `option + shift` |
| `mod2` | `ctrl + option + shift` |

And defines the following commands, mostly a mapping to xmonad key combinations.

| Default Shortcut | Description |
|---|---|
| `mod1 + space` | Cycle layout forward |
| `mod2 + space` | Cycle layout backwards |
| `mod1 + h` | Shrink the main pane |
| `mod1 + l` | Expand the main pane |
| `mod1 + ,` | Increase main pane count |
| `mod1 + .` | Decrease main pane count |
| `mod1 + j` | Move focus counter clockwise |
| `mod1 + k` | Move focus clockwise |
| `mod1 + p` | Move focus to counter clockwise screen |
| `mod1 + n` | Move focus to clockwise screen |
| `mod2 + h` | Swap focused window to counter clockwise screen |
| `mod2 + l` | Swap focused window to clockwise screen |
| `mod2 + j` | Swap focused window counter clockwise |
| `mod2 + k` | Swap focused window clockwise |
| `mod1 + enter` | Swap focused window with main window |
| `mod1 + z` | Force windows to be reevalulated |
| `mod2 + z` | Relaunch Amethyst |
| `mod2 + left` | Throw focused window to space left |
| `mod2 + right` | Throw focused window to space right |
| `mod2 + 1` | Throw focused window to space 1 |
| `mod2 + 2` | Throw focused window to space 2 |
| `mod2 + 3` | Throw focused window to space 3 |
| `mod2 + 4` | Throw focused window to space 4 |
| `mod2 + 5` | Throw focused window to space 5 |
| `mod2 + 6` | Throw focused window to space 6 |
| `mod2 + 7` | Throw focused window to space 7 |
| `mod2 + 8` | Throw focused window to space 8 |
| `mod2 + 9` | Throw focused window to space 9 |
| `mod2 + 0` | Throw focused window to space 10 |
| `mod1 + w` | Focus Screen 1 |
| `mod2 + w` | Throw focused window to screen 1 |
| `mod1 + e` | Focus Screen 2 |
| `mod2 + e` | Throw focused window to screen 2 |
| `mod1 + r` | Focus Screen 3 |
| `mod2 + r` | Throw focused window to screen 3 |
| `mod1 + q` | Focus Screen 4 |
| `mod2 + q` | Throw focused window to screen 4 |
| `mod1 + t` | Toggle float for focused window |
| `mod1 + i` | Display current layout |
| `mod2 + t` | Toggle global tiling |
| `mod1 + a` | Select tall layout |
| `none` | Select tall-right layout |
| `mod1 + s` | Select wide layout |
| `none` | Select middle-wide layout |
| `mod1 + d` | Select fullscreen layout |
| `mod1 + f` | Select column layout |
| `none` | Select row layout |
| `none` | Select floating layout |
| `none` | Select widescreen-tall layout |
| `none` | Select bsp layout |

## Contributing

If you'd like to contribute please branch off of the `development` branch and open pull requests against it rather than `master`. Otherwise just try to stick to the general style of the code. There is a setup script to guide you through the process of installing necessary tools and getting dependencies built. To get started run

```bash
$ ./bin/setup.sh
```

## Contact

If you have questions or feedback your best options are to [tweet](https://twitter.com/amethystwm) or to get on [gitter](https://gitter.im/ianyh/Amethyst).

## Donating

Amethyst is free and always will be. That said, a couple of people have expressed their desire to donate money in appreciation. Given the current political climate I would recommend donating to one of these organizations instead:

* [American Civil Liberties Union](https://www.aclu.org/)
* [Planned Parenthood](https://www.plannedparenthood.org/)
* [Southern Poverty Law Center](https://www.splcenter.org/)
* [National Resources Defense Council](https://www.nrdc.org/)
* [International Refugee Assistance Project](https://refugeerights.org/)
* [NAACP Legal Defense Fund](https://www.naacpldf.org/)
* [The Trevor Project](https://www.thetrevorproject.org/)
* [Mexican American Legal Defense Fund](https://www.maldef.org/)
* [ProPublica](https://www.propublica.org/)

And a bunch of technology-oriented ones:

* [National Center for Women & Information Technology](https://www.ncwit.org/donate)
* [girls who code](https://girlswhocode.com/get-involved/)
* [MotherCoders](https://www.indiegogo.com/projects/mothercoders-a-giant-hack-for-moms-who-want-in)
* [Trans*H4CK](https://www.transhack.org/donate/)
* [Black Girls CODE](https://www.blackgirlscode.com/)

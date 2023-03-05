
# Terminologies

## Layouts

The rules Amethyst uses to arrange panes(windows).

## Pane

Panes are areas on-screen managed by a layout to display windows.

## Main Pane

The area on-screen displays the main window (and other windows if `main pane count > 1`). It is usually the biggest in the _layout_.

The only way to change panes' size in the layout is by changing the main pane's size:

- Shrink the main pane.
- Expand the main pane.
- Increase main pane count.
- Decrease main pane count.

_Some layout may not support main pane._

## Main Pane Count

The _main pane_ count is a number that indicates the number of windows displayed in the main area. Min is 1.

## Main Window

More than one window can display in the _main pane_, but you only have exactly one _main window_ in the layout. It is the only window with a warranty to stay in the _main pane_ when you "Decrease main pane count."

Knowing which one is the _main window_ will help you not confuse when you "Swap focused window with the main window."

## Available Layouts

Amethyst allows you to cycle among several different window layouts. Layouts can also be enabled/disabled to control whether they appear in the cycle sequence at all.

### Tall

The default layout. This gives you one "main pane" on the left, and one other pane on the right. By default, one window is placed in the main pane (extending the full height of the screen), and all remaining windows are placed in the other pane. If either pane has more than one window, that pane will be evenly split into rows, to show them all. You can use the keyboard shortcuts above to control which window(s), and how many, are in the main pane, as well as the horizontal size of the main pane vs. the other pane.

### Tall-Right

Exactly the same as _Tall_, but the main pane is on the right, with the other pane on the left.

### Wide

The rotated version of _Tall_, where the main pane is on the _top_ (extending the full width of the screen), and the other pane is on the bottom. If either pane has more than one window, that pane will split into columns instead of rows.

### 3Column-Left

A three-column version of _Tall_, with one main pane on the left (extending the full height of the screen) and two other panes, one in the middle and one on the right. Like _Tall_, if any pane has more than one window, that pane will be split into rows. You can control how many windows are in the main pane as usual; other windows will be assigned as evenly as possible between the other two panes.

### 3Column-Middle

Exactly like _3Column-Left_, but the main pane is in the middle, with the other panes on either side. (In previous versions of Amethyst, this layout was known as _Middle-Wide_.)

### 3Column-Right

Exactly like _3Column-Left_, but the main pane is on the right, with the other panes in the middle and on the left.

### Widescreen-Tall

This mode is like _Tall_, but if there are multiple windows in the main pane, the main pane splits into columns rather than rows. The other pane still splits windows into rows, like _Tall_. This layout gets its name because it probably makes the most sense on very wide screens, with a large main pane consisting of several columns, and all remaining windows stacked into the final column. Other layouts that work well on very wide screens include any that allow for more than two columns (to take advantage of the screen width), such as any of the _3Column-*_ layouts, or _Column_.

### Fullscreen

In this layout, the currently focused window takes up the entire screen, and the other windows are not visible at all. You can rotate between each of the windows using the "focus the next window" shortcut, as usual.

### Column

This layout has one column per window, with each window extending the full height of the screen. The farthest-left window is considered the "main" window in the sense that you can change its size with the "shrink/expand the main pane" shortcuts; the other windows split the remaining space evenly.

### Row

The rotated version of _Column_, where each window takes up an entire row, extending the full width of the screen.

### Floating

This mode makes all windows "floating", allowing you to move and resize them as if Amethyst were temporarily deactivated. Unlike the other modes, this will mean that windows can be placed "on top of" each other, obscuring your view of some windows.

### Binary Space Partitioning (BSP)

This layout does not have a main pane in the way that other layouts do. When adding windows, any given pane can be split evenly into two panes along whatever axis is longer. This is recursive such that pane A can be split in the middle into pane A on the left and pane B on the right; pane B can then be split into pane B on top and pane C on bottom; pane C can then be split into pane C on the left and pane D on the right; and so on.

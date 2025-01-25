# Custom Layouts (beta)

Amethyst supports implementing custom layouts via JavaScript.

## Installing

Layouts are located in `~/Library/Application Support/Amethyst/Layouts/`. This directory is automatically created when Amethyst is first launched. JavaScript files in this directory will automatically be picked up and keyed by the name of the file; e.g., `my-cool-layout.js` will be available as a layout with the key `my-cool-layout`.

At the moment, files must be manually moved to this directory. There is no way to import them through the app.

## Defining a Layout

At the root of the file you must define a function named `layout`. This function should return an object with the following properties.

### Layout Properties

#### `name`

A string defining the name of the layout. If no name is specified it will default to the layout key.

#### `initialState`

An object defining any initial state to be tracked by the layout.

#### `commands`

An object defining the commands the layout responds to. There are four available custom commands keyed as `command1`, `command2`, `command3`, and `command4`, in addition to paned layout commands keyed as `expandMain`, `shrinkMain`, `increaseMain`, and `decreaseMain`. Commands are objects with a `description` string to describe what the command does and an `updateState` function.

The `updateState` function takes two arguments—`state` and `focusedWindowID`—and must return a new state object.

* `state`: the current layout state
* `focusedWindowID`: the currently focused window

#### `extends`

The key for a layout that the custom layout extends. Each call to `getFrameAssignments` will include the frames determined by the extended layout for reference. There are some limitations to this extension—you cannot affect the state of the extended layout, for example—but this is useful for small modifications to existing native layout algorithms.

#### `getFrameAssignments`

A function that takes four arguments—`windows`, `screenFrame`, `state`, and `extendedFrames`—and returns a mapping of window ids to window frames.

* `windows`: the list of active windows on the screen
* `screenFrame`: the frame of the screen containing the layout
* `state`: the current layout state
* `extendedFrames`: the frames that are inherited from the extended layout if any is defined

The return should be an object with _new_ frames keyed by the window id.

#### `updateWithChange`

A function that takes two arguments—`change` and `state`—and must return a new layout state based on the provided change.

* `change`: the particular change the layout needs to respond to.

### Common Structures

#### Windows

A window is an object with three properties.

* `id`: an opaque identifier for referencing the window both within `getFrameAssignments` and across the layout state
* `frame`: the current frame of the window in the screen space
* `isFocused`: boolean for whether or not the window is currently focused

#### Frames

A frame is an object with four properties.

* `x`: x-coordinate in the screen space
* `y`: y-coordinate in the screen space
* `width`: pixel width
* `height`: pixel height

Note that frames are in a global space, not relative to a given screen.

#### Changes

A change represents the outcome of an event in the system. It is an object with up to two properties.

* `change`: the string key of the type of event (see below)
* `windowID`: the window id for relevant changes
* `otherWindowID`: the second window id for relevant changes

Current changes are:

* `"add"`: a window has been added to tracking
    * Has a `windowID` for the new window
* `"remove"`: a window has been removed from tracking
    * Has a `windowID` for the removed window
* `"focus_changed"`: the currently focused window has changed
    * Has a `windowID` for the newly focused window
* `"window_swap"`: two windows have been swapped in position
    * Has a `windowID` for the first window and an `otherWindowID` for the second window
* `"application_activate"`: an application has been activated
    * No parameters
* `"application_deactivate"`: an application has been deactivated
    * No parameters
* `"space_change"`: the current space on a screen has changed
    * No parameters
* `"layout_change"`: the layout of a screen changed
    * No parameters
* `"unknown"`: an unknown event
    * No parameters

## Examples

There are several layouts defined for automated tests that can serve as examples. They are in [AmethystTests/Model/CustomLayouts/](../AmethystTests/Model/CustomLayouts/).

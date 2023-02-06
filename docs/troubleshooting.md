# Troubleshooting

## Nothing is working!

Here are some common problems and their solutions.

### "Always float"

Amethyst has the option to float everything by default until the user manually intervenes. When this mode is unintentionally enabled it can appear that nothing is working. The option is located in settings in the Floating tab and configured with the `floating-is-blacklist` key in a configuration file.

If you have not intentionally enabled this make sure that the option in the Floating tab says "Automatically float applications listed" as in this screenshot.

<img src="./images/floating-preferences.png" width="50%">

## One application isn't working!

### "Assign To All Desktops"

macOS has the option to assign an application specifically to no Desktops, one Desktop, or all Desktops. Amethyst does not handle the last option very well.

To change this setting you can right click (or control click or whatever gesture you may have associated with right click) on the application icon in the Dock. Under Options there is an Assign To section. See the screenshot below for reference.

<img src="./images/desktop-assignment.png" width="50%">

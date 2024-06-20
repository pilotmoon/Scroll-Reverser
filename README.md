# Scroll Reverser

Reverses the direction of scrolling on macOS, with independent settings for trackpads and mice.

## Download

For download links and more information, visit the **[Scroll Reverser home page](https://pilotmoon.com/scrollreverser/)**.

Downloads are also available in the GitHub releases tab.

## Notes

### Building

After cloning this repo, you'll need to `git submodule update --init` to check out the BuildScripts submodule.

If you try to build fresh out of the box you will get a build error because you don't have my code signing certificate. For best results, replace my certificate with your own Developer ID certificate in the Signing & Capabilities tab of the Scroll Reverser target settings in Xcode.

Debug builds produce an app with no app icon, named "Scroll Reverser (Dev)" and version "99999". This is the expected behaviour and the build is otherwise fully functional.

### How it works

The guts of the code is in MouseTap.m. Everything else is just user interface rigging.

Scroll Reverser installs an event tap, which gives it access to event stream, including scrolling events and gesture events. The main documentation about event taps is [Quartz Event Services Reference](https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/).

To distinguish between trackpad and mouse, Scroll Reverser examines gesture events to determine whether there are two or more fingers on the trackpad. If so, it assumes scrolling is coming from the trackpad. Otherwise, mouse. (There's a little more to it than that, but that is the general idea.)

### Runtime debug log

Scroll Reverser's main event tap does not output debug info with NSLog because it would slow down event processing too much. Instead, it has some custom debug code which is more efficient to write to.

To display the debug window, Option(⌥)-click the Scroll Reverser menu bar icon.

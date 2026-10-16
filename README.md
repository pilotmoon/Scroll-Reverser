# Scroll Reverser

Reverses the direction of scrolling on macOS, with separate settings for each source of scrolling: each trackpad, mouse, Universal Control device or app.

## Download

For download links and more information, visit the **[Scroll Reverser home page](https://pilotmoon.com/scrollreverser/)**.

Downloads are also available in the GitHub releases tab.

## Notes

### How it works

Scroll Reverser installs an event tap, which gives it access to the stream of scroll events. The main documentation about event taps is [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services?language=objc). The tap needs Accessibility permission.

Each scroll event is attributed to the most specific source the event itself identifies:

- **A device**, from the sender ID of the HID event inside the scroll event (a private API, `IOHIDEventGetSenderID`). The sender is looked up in the IORegistry, or in the HID event system for the virtual devices that Universal Control creates.
- **An app**, from the process ID, for scroll events posted by other software, such as mouse utilities.
- **An unidentified source**, when neither is available.

Continuous scrolling (trackpads, the Magic Mouse) and non-continuous scrolling (scroll wheels) from the same source are separate sources. Each source gets a row of settings, saved in user defaults: the scrolling direction, whether horizontal scrolling follows vertical, and a step size for scroll wheels.

How the direction is decided depends on what the event tells us:

- **Device sources** (any event with a HID event inside, even if the device can't be identified) offer Natural, Classic or Unchanged. For these events, `-[NSEvent isDirectionInvertedFromDevice]` says whether macOS has already applied natural scrolling. Scroll Reverser reverses the event only when that doesn't match the row's setting: a Natural row reverses events that arrive classic, and a Classic row reverses events that arrive natural. So the result doesn't depend on the natural scrolling setting in System Settings.
- **App sources** (events with no HID event inside, including the unidentified ones) offer only Reversed or Unchanged. Scrolling posted by an app never has natural scrolling applied by macOS (the app chose the direction itself), so there is nothing to compare against, and a Reversed row simply reverses every event.

### Code layout

- `MouseTap` — the event tap and its callback, which identifies, records and reverses each event.
- `ScrollSource` — identifies the source of an event and builds the stable key for its row.
- `SourceTable` — the saved rows of settings, the reversing rule, and the record of each source's use.
- `SourcesTableController`, `SourceInfoViewController`, `SourceRow+Display` — the sources table in the settings window, its info popover, and the localized names and descriptions.
- `PrefsWindowController` — the settings window. `PermissionsManager` — the Accessibility permission.
- `AppDelegate` — app setup, the master switch, the status item and updates (Sparkle).
- `Tests/` — unit tests for key building and the reversing rule.
- `resources/` — localizations. `script/` — translation helpers.

### Building

After cloning this repo, you'll need to `git submodule update --init` to check out the BuildScripts submodule.

If you try to build fresh out of the box you will get a build error because you don't have my code signing certificate. For best results, replace my certificate with your own Developer ID certificate in the Signing & Capabilities tab of the Scroll Reverser target settings in Xcode.

Debug builds produce an app with no app icon, named "Scroll Reverser (Dev)" and version "99999". This is the expected behaviour and the build is otherwise fully functional.

To run the unit tests, use Product › Test in Xcode, or:

```
xcodebuild -project ScrollReverser.xcodeproj -scheme "Scroll Reverser" test
```

### Translations

`script/gens` regenerates the English strings from the source code and adds new strings to every language, marked `TODO:TRANSLATE`. `script/apple_term.py` looks up Apple's own wording for a term in a given language, and `script/check_placeholders.py` checks translations for mismatched format placeholders.

### Runtime debug log

Scroll Reverser's event tap does not output debug info with NSLog because it would slow down event processing too much. Instead, it has some custom debug code which is more efficient to write to.

To display the debug window, Option(⌥)-click the Scroll Reverser menu bar icon.

# Scroll Reverser

Reverses the direction of scrolling on macOS, with separate settings for each source of scrolling: each trackpad, mouse, Universal Control device or app.

## Download

For download links and more information, visit the **[Scroll Reverser home page](https://pilotmoon.com/scrollreverser/)**.

Downloads are also available in the GitHub releases tab.

## Notes

### How it works

Scroll Reverser installs an event tap, which gives it access to the stream of scroll events. The main documentation about event taps is [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services?language=objc). The tap needs Accessibility permission.

Each scroll event is attributed to a source based on the available information:

- **A device**, from the sender ID of the HID event inside the scroll event.
- **An app**, from the process ID, for scroll events posted by other software.
- **An unidentified source**, when neither is available.

Additionally, scrolling sources are differentiated by whether they are **continuous** (typically trackpads and the Magic Mouse) or **discrete** (typically mice with scroll wheels).

Each source gets its own row in a table in Settings, with the scrolling direction preference and step size saved to user defaults.

Scrolling direction options are as follows:

- For **devices**, the system-defined scrolling direction is obtained using `[NSEvent isDirectionInvertedFromDevice]`, and the the direction options are **Natural** or **Classic**, with reversing applied as needed to give the desired outcome. A third option, **Unchanged**, acts as a passthrough.
- For **apps** and **unidentified** sources, which do not indicate the underlying scrolling direction, the options are **Reversed** and **Unchanged**.
- **Horizontal scrolling** has its own column in the sources table. It can be set to match vertical scrolling, or to Reversed or Unchanged regardless of vertical.

Default settings for newly detected scrolling sources:

- **Scrolling:** Natural for trackpads, Classic for other devices (mice, in practice), and Unchanged for apps and unidentified sources. A device counts as a trackpad if its `HIDScrollAccelerationType` property is `HIDTrackpadScrollAcceleration`, or if it's driven by Apple's multitouch trackpad driver.
- **Horizontal scrolling:** Match vertical.
- **Step size:** defaults to on, at 3 lines.

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

# Scroll Reverser 2.0: per-source scrolling (specification)

Status (15 Oct 2026): **the design is settled**, after a day of prototyping with Nick on branch
`v2-per-source` (prototype complete at f552302). This document is the specification for the
production implementation. The prototype is a working reference, not code to ship as it is. See
"Production pass" at the end for what to keep, what to rewrite, and what's still untested.

The evidence for the approach is in `hid-sender-findings.md` (in the side-session notes, not in
the repo).

## Principle

No gesture recognition and no assumptions about device models. Each scroll event is attributed
to the **most specific source the event itself identifies**. Every source gets a row of
settings, and the user decides per row. The UI shows what the system actually tells us.

## Sources

| The event carries | Source | Split by continuity? |
|---|---|---|
| HID event whose sender is found in the IORegistry | Device | No |
| HID event whose sender is a virtual service found via `IOHIDEventSystemClient` (Universal Control) | Universal Control device | No |
| HID event, but sender 0 or still unresolved after retries | Unidentified device | Yes |
| No HID event, pid ≠ 0 | App | Yes |
| No HID event, pid 0 (Sidecar, in practice) | Unidentified source | Yes |

- **Split by continuity:** the source gets separate rows for continuous and non-continuous
  scrolling, each created only when that kind is first seen. For example, Screen Sharing
  forwards a remote trackpad (continuous) and a remote wheel mouse (non-continuous).
- **Category,** for display and defaults:
  - **Trackpad:** a device whose `HIDScrollAccelerationType` is
    `HIDTrackpadScrollAcceleration`, or which is driven by `AppleMultitouchTrackpadHIDEventDriver`
    (checked on the service and its parent). This applies to local and Universal Control devices.
  - **Mouse:** any other identified device, i.e. "not a trackpad". That includes Magic Mice,
    wheel mice, tablets and keyboards with scroll wheels.
  - **Other:** app rows and the unidentified buckets.

### Identification

- Per event: `CGEventCopyIOHIDEvent` → `IOHIDEventGetSenderID` (private SPI). Otherwise use the
  pid from `kCGEventSourceUnixProcessID`.
- **Senders:**
  - Look a sender up the first time it's seen, and cache the result. Registry entry IDs aren't
    reused within a boot.
  - The lookup tries the IORegistry first (`IORegistryEntryIDMatching`). If that fails, it tries
    `IOHIDEventSystemClientCopyServices`, matching on `IOHIDServiceClientGetRegistryID`.
  - **Retry unresolved senders** at most every 250ms. New virtual services can send events
    before the event system lists them.
  - **Identity properties** are read from the sending service. Multitouch senders are the
    `AppleMultitouchDevice` child, which carries Product/VID/PID and the scroll acceleration type.
- **Pids:**
  - Resolve a pid the first time it's seen, while the process still exists: `proc_pidpath`, then
    the enclosing `.app` bundle (`<bundle>/Contents/MacOS/<exe>`). Cache the result.
  - Drop the cached entry when the process exits (`DISPATCH_SOURCE_TYPE_PROC`), because pids are
    reused.
  - If the process has already gone, use the unknown-app bucket.
- **Continuity** comes from `kCGScrollWheelEventIsContinuous`. Note that macOS makes the Mighty
  Mouse's ball continuous, while an MX Master stays non-continuous in both wheel modes.
- **The hot path:** all lookups happen only on a cache miss. Everything after that is a cache hit.
- **Degradation:** if the private SPI stops working in a future macOS, events fall into the
  unidentified buckets, which still have settings.

## Row keys

A key identifies a row, so it must stay the same for a source over time and never change because
of anything the user can rename or replug.

- **Devices:** Transport + VendorID + ProductID, plus `sn:` and the SerialNumber when the device
  reports one.
  - **Never the sender (registry) ID.** It changes on every reconnect and every Universal Control
    session.
  - **Product (the name) only as a last resort.** It's used only when there's no serial and VID
    and PID are both 0, as for the built-in trackpad, whose name is fixed. A Bluetooth device's
    Product is the user's name for it in Bluetooth settings.
  - **Never LocationID.** On USB it encodes the port; on Bluetooth it repeats part of the address
    the serial already has.
  - **Identical devices without serials share a row.** That includes the same device seen
    through Universal Control from two Macs.
- **Apps:** bundle ID, or the executable path if there's no bundle. Never the pid.

| Source | Key |
|---|---|
| Device with a serial | `device\|Transport\|VID\|PID\|sn:Serial` |
| Device without a serial | `device\|Transport\|VID\|PID` |
| Device with no serial and VID/PID 0 | `device\|Transport\|0\|0\|Product` |
| Universal Control device | `remote\|…`, same rules |
| App | `app\|BundleID#continuous` or `#discrete`, or `app\|/executable/path#…` |
| Unidentified device | `unidentified-device#continuous` or `#discrete` |
| Process gone before lookup | `unknown-app#…` |
| No HID event, pid 0 | `unidentified#…` |

- The first field names the kind.
- `%`, `|` and `#` inside a field are escaped as `%25`, `%7C` and `%23`, so a key can be read only
  one way.
- The same physical device on a different connection gets a different key, and so a different
  row. Examples: a Magic Trackpad over USB vs Bluetooth, or an MX Master on a receiver vs
  Bluetooth vs Options+. That's accepted, because they really are different paths. An unbundled
  executable that moves also gets a new row.

## Behaviour

### Settings per row

- **Scrolling,** the main setting:
  - **Device rows** (devices, Universal Control devices, unidentified devices): Natural, Classic
    or Unchanged.
  - **App rows and unidentified sources:** Reversed or Unchanged. An app that posts scroll events
    chooses the direction itself, and macOS never applies natural scrolling to posted events, so
    Natural and Classic would mean nothing there.
- **Horizontal scrolling:** Unchanged or Match vertical. Match vertical gives horizontal the same
  reversal as vertical. macOS applies natural scrolling to both axes, so a Classic wheel mouse
  needs this to scroll classic both ways.
- **Step size** (enabled + 1…30 lines): applies only to non-continuous scrolling, and is shown
  only for rows that have seen it.
- **Custom name:** optional.

### The reversing rule

For each event:

- **`natural`** = `-[NSEvent isDirectionInvertedFromDevice]`. It's YES when macOS has applied
  natural scrolling to this event.
- **Reverse vertical when:**
  - the row is Reversed, or
  - the row is Natural and `natural` is NO, or
  - the row is Classic and `natural` is YES.
  
  Unchanged never reverses.
- **Reverse horizontal when:** vertical is reversed and the row is Match vertical.
- **Step size:** for non-continuous events, a ±1 line delta on an axis becomes ±step size (1.x's
  logic, including setting the point deltas second).
- This needs no reading of the system preference, and stays correct if the user changes System
  Settings while the app runs.

### Defaults for a new row

A row's defaults are set from the event that creates it, and then belong to the row. There's
nothing for the user to configure.

- **Scrolling:** Natural for trackpads, Classic for other devices, Unchanged for app rows and
  unidentified sources.
- **Horizontal:** Match vertical only when the row isn't a trackpad and its first event is
  non-continuous (wheel mice). Trackpads and the Magic Mouse use horizontal swipes for gestures.
- **Step size:** on, at 3.

### Master switch

The 1.x "Enable Scroll Reverser" switch and the status item's right-click toggle stay, with the
same key (`InvertScrollingOn`). Off means no tap at all.

### Recorded per row

- First seen and last seen.
- Total distance scrolled, in points on both axes.
- Whether continuous and non-continuous scrolling have been seen.
- Whether events arrived with natural scrolling applied, without it, or both.
- Kind, category, reported name and path. The reported name is refreshed whenever the source is
  looked up again, e.g. on reconnect.

### Storage

- Rows are kept in the `Sources` user default, a dictionary from row key to a row dictionary.
- The tap records sightings in memory only. There are no defaults writes per event.
- New rows, settings changes and removals are saved within 1s. Sightings alone are saved at most
  once a minute. Everything is saved on quit.
- Stale rows are kept until the user removes them. Nothing is pruned automatically.

## Settings UI (Scrolling pane)

The pane has the "Enable Scroll Reverser" checkbox, the sources table below it, and a "−"
(remove) button under the table. The table and button are hidden while permissions are missing,
when the permissions box shows instead. The App pane is unchanged from 1.x.

### Table columns

| Column | Content |
|---|---|
| Icon | An app's own icon at 18×18. Devices use SF Symbols drawn at 13pt (not scaled to fit): `rectangle.and.hand.point.up.left` for trackpads, `magicmouse` for a mouse that has only scrolled continuously, `computermouse` otherwise. `app` for an app that can't be found, and `questionmark.circle` for unidentified sources. |
| Source | The name, truncated, with the full name as its tooltip. Not editable here. |
| Scrolling | A pop-up: Natural / Classic / Unchanged, or Reversed / Unchanged. |
| Step size | Checkbox, number field and stepper (1…30), or "Continuous" in secondary text when the row hasn't seen non-continuous scrolling. |
| Last used | "Just now" within the last minute, then a relative time ("5 min ago"). |
| ⓘ | Opens the row's info popover. |

### Names

The custom name if set, or else the default name:

- Devices and apps use the reported name.
- Universal Control devices drop the "V-" prefix that Universal Control adds, then add
  " (Universal Control)".
- With no reported name, the default is "Unnamed device", "Unidentified device", "Unknown app" or
  "Unidentified source".
- Names never mention continuity. A source with both a continuous and a non-continuous row shows
  the same name twice. That's rare, and accepted.

### Order

- Most recently used first.
- Kept up to date while the window is open: a source that scrolls moves to the top, with rows
  moved by animation, not reloaded, so the selection follows its row.

### Highlight

A row is tinted with the accent colour (25% alpha) while its source is scrolling, meaning it
scrolled within the last 0.25s. "Which one is this?" answers itself, and discovery is otherwise
silent.

### Removing a row

"−" removes the selected row. The source gets a new row, with defaults, if it scrolls again.

### Info popover (ⓘ)

1. **Name:** a text field, empty by default, with the default name as its placeholder. Clearing
   it returns to the default name.
2. **Horizontal scrolling:** a pop-up, Unchanged / Match vertical.
3. **Details:**
   - **Kind:** Mouse, Trackpad, Mouse (Universal Control), Trackpad (Universal Control),
     Unidentified device, App, or Unidentified source.
   - **Reported name.**
   - **Identifier:** the row key.
   - **Path:** apps only.
   - **Scrolling type:** Continuous, Discrete, or Both continuous and discrete.
   - **System direction:** Natural, Classic, Both natural and classic, or "Unknown" for app rows
     and unidentified sources.
   - **First seen.**
   - **Points scrolled:** the distance, as a plain number, so it needs no plural forms.

## Permissions

- Accessibility only, for the one active scroll tap.
- Input Monitoring was needed only for 1.x's passive gesture tap, and 2.0 doesn't ask for it.
  Checked on 16 Oct 2026 with Scroll Reverser absent from the Input Monitoring list: the active tap
  and the `IOHIDEventSystemClient` lookups work, and a Universal Control trackpad resolved to its
  own row. `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)` reports "granted" in that state, so
  macOS evidently counts Accessibility as covering listen access too.

## Upgrade from 1.x

- Only the master switch carries over.
- The 1.x per-type settings (ReverseX/Y, ReverseTrackpad/Mouse, the step-size keys,
  ShowDiscreteScrollOptions, ReverseOnlyRawInput) are ignored. New rows take the defaults above.
  Those defaults match what most 1.x users had: trackpads natural, mice classic.
- The release notes and the first-run window should explain the new per-source table.

## Production pass

### Keep, and tidy

- **`ScrollSource.h/.m`:** source identification and key building. It's small, designed up front,
  and checked on real devices: the built-in trackpad, Magic Mice, an MX Master over BLE and
  through Options+, a USB mouse, and a Universal Control trackpad.
- **`SourceTable.h/.m`:** the saved model.
  - Move the user-facing default names (`defaultName`) out of the model and localize them.
  - Replace the `@public` ivar shortcut with something cleaner, or document why it's there.
- **`MouseTap`:** the callback is small and follows the rule above. Keep the logging.

### Rewrite from this spec

- **`SourcesTableController`:** it grew by accretion while prototyping.
  - One 10Hz timer does re-sorting, highlighting and the Last used text.
  - The popover is built inline.
  - About 30 strings aren't localized.
  - It contains workarounds, e.g. setting cell text in place so reloading doesn't end editing.

### Do

- Localize every new string for all 27 languages.
- Remove the Input Monitoring code.
- Add unit tests for key building and escaping, and for the reversing rule.
- Check a Release build.
- Write the release notes and the first-run text.

### Untested

- **The #130 state after wake:** never reproduced. Confirm that senders are present then.
- **Other re-posting apps:** SteerMouse, USB Overdrive, BetterTouchTool, Mac Mouse Fix. They're
  expected to appear as app rows.
- **Sidecar:** what else produces "no HID event, pid 0"? Seen only with Sidecar so far.
- **Pid reuse:** the exit-source approach is untested under fast pid reuse.

## Decisions and alternatives rejected

All from 15 Oct 2026, with Nick, in order.

- **Category defaults with a "Defaults…" sheet and 1.x migration:** built, then dropped. New
  sources simply take defaults.
- **"Reverse vertical/horizontal" checkboxes:** replaced by Natural/Classic/Unchanged, because
  "reverse" depends on the System Settings direction.
- **Natural/Classic for app rows:** replaced by Reversed/Unchanged after seeing that Options+'s
  events never carry the natural flag.
- **The device name in the key:** dropped, because renaming a Bluetooth device would split its
  row. **LocationID in the key:** dropped.
- **"(continuous)"/"(non-continuous)" in names:** dropped as confusing.
- **Inline name editing in the table:** dropped in favour of the popover's Name field.
- **Ordering by total scrolling, sorting only when the window opens, or re-sorting from the
  header:** replaced by live most-recently-used order.
- **A caption above the table:** dropped. **A labelled Remove push button:** tried, then reverted
  to "−".
- **Naming the pid-0 bucket "Sidecar":** rejected. It stays "Unidentified source", since the
  bucket is defined by what's observed.

From 16 Oct 2026, with Nick:

- **Discovery while the master switch is off:** not done. Sources are added only while the tap
  runs. (The reason given at the time, that a listen-only tap would need Input Monitoring, turned
  out to be wrong: Accessibility covers it. Worth revisiting if discovery while off is wanted.)
- **Hint text for known re-posters** (e.g. "Logitech devices handled by Options+"): left out of
  2.0.

# Scroll Reverser

Reverses the direction of macOS scrolling, with independent settings for trackpads and mice.

Web home page: [https://pilotmoon.com/scrollreverser/](https://pilotmoon.com/scrollreverser/) (Please note the home page contains additional content about the app, FAQ, changelog etc.)

## Requirements

The latest build of Scroll Reverser requires macOS 10.12.6 and above and is a universal binary for both Intel and Apple Silicon (M1) Macs. Older versions are available for older OS versions, down to OS X 10.4. See the web home page for the downloads or the respective labeled branches for the code.

## Install and run

Download the [latest release](https://github.com/pilotmoon/Scroll-Reverser/releases/latest), unzip, and place `Scroll Reverser.app` in your `/Applications` folder. Double-click to run.

To uninstall, simply quit the app and drag `Scroll Reverser.app` to trash.

## Translations

Translation contributions in your language are welcome. Please submit transmations using the [CrowdIn](https://crowdin.com/project/pilotmoon-apps) platform. 
** When improving an existing translation, please add a comment and mark it as "Issue" so that it flags it up to me to approve. Otherwise I might not see it.**
If you would like to open a new language, just send me an email.

## License

Published under [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Please note, the name "Scroll Reverser" and the application icon are trademarks and may not be used by derivatve works (except as required to describe the origin of the work).

## Building

After cloning this repo, you'll need to `git submodule update --init` to check out the BuildScripts submodule.

You will get errors in the build script phase. That is because you need to replace out the part of the script which specifies my code signing key with the name of your own key. (If you don't have a code signing key, you'll need to Google that...)

## Viewing debug log

To display the debug window, Option(⌥)-click the Scroll Reverser menu bar icon. (Scroll Reverser does not output debug info with NSLog. This is because doing so slows down the event lap. Instead, it has some custom debug code which is more efficient to write to.)

## Notes on the code

The master branch targets 10.12 and higher.

Older code targeting 10.4+ is in the 'tiger' branch and 10.7+ is in the 'lion' branch.

The real guts of the code is in MouseTap.m. Everything else is just user interface rigging.

Scroll Reverser installs an event tap, which gives access to event stream, including scrolling events and gesture events. The main documentation is [Quartz Event Services Reference](https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/).

To distinguish between trackpad and mouse, Scroll Reverser essentially looks at the gesture events to determine whether there are 2 or more fingers on the trackpad. If so, it assumes it is the trackpad. If not, mouse. It's a little more complicated than that as you will see, but that is the general idea.

## Alternatives

<ul>
  <li><a href="https://github.com/linearmouse/linearmouse">LinearMouse</a></li>
  <li><a href="https://mousefix.org/">Mac Mouse Fix</a></li>
  <li><a href="https://mos.caldis.me">MOS</a></li>
  <li><a href="https://github.com/ther0n/UnnaturalScrollWheels">UnnaturalScrollWheels</a></li>
</ul>  

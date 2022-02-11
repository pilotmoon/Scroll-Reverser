# Scroll Reverser

Reverses the direction of macOS scrolling, with independent settings for trackpads and mice.

Web home page: [https://pilotmoon.com/scrollreverser/](https://pilotmoon.com/scrollreverser/) (Please note the home page contains additional content about the app, FAQ, changelog etc.)

## Known Issue: Safari Scrolling Broken in macOS Monterey 12.2

**Summary: Bad news. Scroll Reverser isn't working in Safari and there is no fix.**

On macOS Monterey 12.2, Scroll Reverser is not working in Safari when using smooth scrolling devices — that is, trackpads and the Magic Mouse. The effect is a kind of "snap back" where the scrolling direction flips, as if it fighting you. The problem does not occur with scroll wheel devices.

I have not been able to  find any way to modify Scroll Reverser to overcome this problem. (It seems Safari is ignoring the direction of the scrolling event input during the momentum phase of the scroll, and instead it is deriving it from some other source. That means whatever Scroll Reverser does, it can't reverse the momentum part of the scroll, which is giving the "snap back" effect. Speculatively, this is something to do with recent work done to to improve Safari scrolling on ProMotion displays.)

For now we wait and see if the changes in 12.2 were an unintentional bug, or if this is the way it is now. If anyone has any technical info on all this, or solutions, please let me know. I do not plan do do any more work on Scroll Reverser unless this situation is resolved.

*A note on alternative apps: [MOS](https://mos.caldis.me/) and [UnnaturalScrollWheels](https://github.com/ther0n/UnnaturalScrollWheels) are excellent alternatives to Scroll Reverser that reverse **wheel mouse** scrolling independently of the trackpad. However, neither of them can distinguish the **Magic Mouse** from the trackpad  — that has always been Scroll Reverser's speciality. It's specifically trackpad/Magic Mouse reversing that is now not working.*

Updated 11 Feb 2022. -Nick
## Requirements

The latest build of Scroll Reverser requires macOS 10.12.6 and above, and is a univeral binary for both Intel and Apple Silicon (M1) Macs. Older versions are available for older OS  versions down to OS X 10.4. See the web home page for the downloads, or the respective labelled branches for the code.

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

## Notes on the code

The master branch targets 10.12 and higher.

Older code targeting 10.4+ is in the 'tiger' branch and 10.7+ is in the 'lion' branch.

The real guts of the code is in MouseTap.m. Everything else is just user interface rigging.

Scroll Reverser installs an event tap, which gives access to event stream, including scrolling events and gesture events. The main documentation is [Quartz Event Services Reference](https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/).

To distinguish between trackpad and mouse, Scroll Reverser essentially looks at the gesture events to determine whether there are 2 or more fingers on the trackpad. If so, it assumes it is the trackpad. If not, mouse. It's a little more complicated than that as you will see, but that is the general idea.

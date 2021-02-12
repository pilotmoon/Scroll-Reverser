# Scroll Reverser

Reverses the direction of macOS scrolling, with independent settings for trackpads and mice.

Web home page: [https://pilotmoon.com/scrollreverser/](https://pilotmoon.com/scrollreverser/)

*Announcement: In a future update, Scroll Reverser will become a paid app. It will remain open source. You can read more about my decision [here](https://pilotmoon.com/blog/2020/12/09/scroll-reverser-1-8).*

## Translations

Translation updates in your language are appreciated either by pull request or using [CrowdIn](https://crowdin.com/project/pilotmoon-apps) platform.

## License

Licensed under [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Please note, the name "Scroll Reverser" and the application icons are trademarks and may not be used by derivatve works.

## Building

After cloning this repo, you'll need to `git submodule update --init` to check out the BuildScripts submodule.

## Notes on the code

The master branch targets 10.12 and higher.

Older code targeting 10.4+ is in the 'tiger' branch and 10.7+ is in the 'lion' branch.

The real guts of the code is in MouseTap.m. Everything else is just user interface rigging.

Scroll Reverser installs an event tap, which gives access to event stream, including scrolling events and gesture events. The main documentation is [Quartz Event Services Reference](https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/).

To distinguish between trackpad and mouse, Scroll Reverser essentially looks at the gesture events to determine whether there are 2 or more fingers on the trackpad. If so, it assumes it is the trackpad. If not, mouse. It's a little more complicated than that as you will see, but that is the general idea.

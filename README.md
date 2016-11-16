Scroll Reverser
===============

**Please fill in the [Scroll Reverser survey](https://goo.gl/forms/RjEd4HNbZV6qxJVs1)!**

Reverse the direction of scrolling on macOS. 

The 'master' branch build targets  10.7 and higher.

Older code targeting 10.4+ is in the 'tiger' branch.

Home page: http://pilotmoon.com/scrollreverser/

Licensed under [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Notes on the code
-----------------

The real guts of the code is in MouseTap.m. Everything else is just user interface rigging.

Scroll Reverser installs an event tap, which gives access to event stream, including scrolling events and gesture events. The main documentation is [Quartz Event Services Reference](https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/).

To distinguish between trackpad and mouse, Scroll Reverser essentially looks at the gesture events to determine whether there are 2 or more fingers on the trackpad. If so, it assumes it is the trackpad. If not, mouse. It's a little more complicated than that as you will see, but that is the general idea.

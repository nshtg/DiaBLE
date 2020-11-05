FIXME
-----

* iOS 14: when getting focus to enter the Nightscout credentials the URL textfields scroll up offscreen
* Apple Watch app:
  - the Libre 2 disconnects when trying to reuse the current sensor uid and unlock count but not the original patchInfo
  - the Monitor counter doesn't update on rescan
  - readings aren't received in background but Bluetooth connections aren't closed until shutdown, even when the app is removed from the Dock
* when the sensor is not detected the last reading time is updated anyway
* the log ScrollView doesn't remember the position when switching tabs, nor allows scrolling to the top when reversed

TODO
----

* clean the code base by restarting from a fresh Xcode 12 project template and make use of Combine and of the new Widgets, @Scene/AppStorage, ScrollViewReaders, lazy grids...
* selection of glucose units
* manage Nightscout JavaScript alerts synchronously
* Apple Watch app: snapshots, workout and extended runtime background sessions, complications
* log: limit to a number of readings, prepend time, add a search field, Share menu, record to a file
* more modern Swift idioms: property wrappers, @dynamicCallable/MemberLookup, ViewModifiers/Builders


PLANS / WISHES
---------------

* a predictive meal log using Machine Learning (see [WoofWoof](https://github.com/gshaviv/ninety-two))
* LoopKit integrations

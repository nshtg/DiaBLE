FIXME
-----

* Bubble: the Apple Watch app doesn't connect to it
* Apple Watch app:
  - the Monitor counter doesn't update on rescan
  - readings aren't received in background but Bluetooth connections aren't closed until shutdown, even when the app is removed from the Dock
* Mac Catalyst: AVAudioSession error: "Cannot activate session when app is in background" in MainDelegate init
* running the CBCentralManager delegate and log() in the main queue makes the tabs irresponsive when scanning for a device and the Mac is continuosly detected
* when the sensor is not detected the last reading time is updated anyway
* the log ScrollView doesn't remember the position when switching tabs, nor allows scrolling to the top when reversed

TODO
----

* clean the code base by restarting from a fresh Xcode 12 project template and make use of the new Widgets, @Scene/AppStorages, ScrollViewReaders, lazy grids...
* selection of glucose units
* manage Nightscout JavaScript alerts synchronously
* Apple Watch app: snapshots, workout and extended runtime background sessions, complications, context menus, edit calibration parameters
* BLE: Libre 2 beacons, update RSSI continuously
* log: limit to a number of readings, prepend time, add a search field, Share menu, record to a file
* let the users input their BG and manage different calibrations
* more modern Swift idioms: Combine, property wrappers, @dynamicCallable/MemberLookup, ViewModifiers


PLANS / WISHES
---------------

* a predictive meal log using Machine Learning (see [WoofWoof](https://github.com/gshaviv/ninety-two))
* LoopKit integrations

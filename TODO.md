FIXME
-----

* Bubble: the Apple Watch app doesn't connect to it and Mac Catalyst stops receiving data from the read characteristic
* Apple Watch app:
  - the Monitor counter doesn't update on relaunch
  - readings aren't received in background but Bluetooth connections aren't closed until shutdown, even when the app is removed from the Dock
* Mac Catalyst: AVAudioSession error: "Cannot activate session when app is in background" in MainDelegate init
* running the CBCentralManager delegate and log() in the main queue makes the tabs irresponsive when scanning for a device and the Mac is continuosly detected
* when the sensor is not detected the last reading time is updated anyway
* the log ScrollView doesn't remember the position when switching tabs, nor allows scrolling to the top when reversed

TODO
----

* get the Libre 2 patchInfo via NFC and XOR-decrypt its FRAM
* manage Nightscout JavaScript alerts synchronously
* Apple Watch app: snapshots, WKExtendedRuntimeSession, complications, Nightscout uploads, context menus
* BLE: update RSSI and 1805 2A2B characteristic (current time)
* Watlaa iBeacon
* selection of glucose units
* log: limit to a number of readings; add the time when prepending "\t"; add a search field; record to a file
* let the user input their BG and manage slope/offset parameters independent from the temperatures
* more modern Swift idioms: Combine, property wrappers, @dynamicCallable/MemberLookup, ViewModifiers


PLANS / WISHES
---------------

* a predictive meal log using Machine Learning (see [WoofWoof](https://github.com/gshaviv/ninety-two))
* LoopKit integrations

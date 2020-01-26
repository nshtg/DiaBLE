FIXME
-----

* Mac Catalyst:
   - stops receiving data from the Bubble read characteristic
   - AVAudioSession error: "Cannot activate session when app is in background" in MainDelegate init
* when the sensor is not detected the last reading time is updated anyway
*  the log ScrollView doesn't remember the position when switching tabs, nor allows scrolling to the top when reversed


TODO
----

* UNUserNotificationCenterDelegate methods
* save measurements by using HealthKit
* upload to Nightscout
* log: limit to a number of readings; add the time when prepending "\t"; add a search field; record to a file
* landcape mode
* changing the calibration parameters with a slider updates interactively the third purple curve
* a single slider for setting the target glucose range and the alarms
* more modern Swift idioms: Combine, property wrappers, @dynamicCallable/MemberLookup


PLANS / WISHES
---------------

* an independent Apple Watch app connecting directly via Bluetooth
* a predictive meal log (see [WoofWoof](https://github.com/gshaviv/ninety-two))

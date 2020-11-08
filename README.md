<p align ="center"><img src="./DiaBLE/Assets.xcassets/AppIcon.appiconset/Icon.png" width="25%" /></p>

Since the FreeStyle Libre 2 glucose sensor is a Bluetooth Low Energy BLE device and my purchase experience with the transmitters available for the previous generation has been quite frustrating, I am trying to leverage its capabilities to implement something new compared to the traditional apps:

* a universal **SwiftUI** application for iPhone, iPad and Mac Catalyst;
* an **independent Apple Watch app** connecting directly via Bluetooth;
* scanning the Libre directly via **NFC**;
* using both online servers and offline methods for calibrating just like **Abbott’s algorithm**;
* varying the **reading interval** instead of the usual 5-minute one;
* a detailed **log** to check the traffic from/to the BLE devices and remote servers.

Still too early to decide the final design (but I really like already the evil logo 😈), here there are some recent screenshots I tweeted:

<br><br>
<p align ="center"><img src="https://pbs.twimg.com/media/EfM5Q6sXYAYazK0?format=jpg&name=4096x4096" width="25%" /></p>
<h4 align ="center">Libre 2 decrypted thanks to @ivalkou</h4>
<p align ="center"><br><img src="https://pbs.twimg.com/media/EmTCHz2XcAEf5RE?format=png&name=small" align="top" width="25%" /></p>
<h4 align ="center">Phones and transmitters: who needs them?</h4><br><br>
<br><br>

The project started as a single script for the iPad Swift Playgrounds and was quickly converted to an app by using a standard Xcode template: it should compile finely without external dependencies just after changing the _Bundle Identifier_ in the _General_ panel and the _Team_ in the _Signing and Capabilities_ tab of Xcode -- Spike users know already very well what that means... ;)

Please refer to the [TODOs list](https://github.com/gui-dos/DiaBLE/blob/master/TODO.md) for the up-to-date status of all the current limitations and known bugs of this prototype.

---
Credits: [@bubbledevteam](https://github.com/bubbledevteam?tab=repositories), [@captainbeeheart](https://github.com/captainbeeheart?tab=repositories), [@cryptax](https://github.com/cryptax?tab=repositories), [@dabear](https://github.com/dabear?tab=repositories), [@ivalkou](https://github.com/ivalkou?tab=repositories), [LibreMonitor](https://github.com/UPetersen/LibreMonitor/tree/Swift4), [Loop](https://github.com/LoopKit/Loop), [Nightguard]( https://github.com/nightscout/nightguard), [@travisgoodspeed](https://github.com/travisgoodspeed?tab=repositories), [WoofWoof](https://github.com/gshaviv/ninety-two), [xDrip+](https://github.com/NightscoutFoundation/xDrip), [xDrip4iOS](https://github.com/JohanDegraeve/xdripswift).

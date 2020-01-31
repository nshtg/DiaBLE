<p align ="center"><img src="./DiaBLE//Assets.xcassets/AppIcon.appiconset/Icon.png" width="25%" /></p>

Experimenting with the Bluetooth BLE devices I bought for the Abbott FreeStyle Libre sensor (mainly  the Bubble and MiaoMiao transmitters, the M5Stack and the Watlaa watch) and trying something new compared to the traditional apps:

* a universal **SwiftUI** application for iPhone, iPad and Mac Catalyst;
* scanning the Libre directly via **NFC**;
* using online servers for calibrating just like **Abbott’s algorithm**;
* varying the **reading interval** (the Bubble firmware allows to set it from 1 to 15 minutes while the MiaoMiao one to reduce it to 1 or 3 minutes);
* a detailed **log** to check the traffic from/to the BLE devices and remote servers.

Still too early to decide the final design (but I really like already the evil logo 😈), here there are the first rough screenshots:


<p align ="center"><img src="https://drive.google.com/uc?export=view&id=1qYQa7PXcXI34FuCf7lF9MFnGvXU8hSsH" width="25%" />&nbsp;&nbsp;<img src="https://drive.google.com/uc?export=view&id=1APov1uxAI2P8m3UwPb47dkgi1Cus9wxU" width="25%" />&nbsp;&nbsp;<img src="https://drive.google.com/uc?export=view&id=1KXNkd-rQqqXKASTmfbciyKOElN3W5ft6" width="25%" /></p>

The project started as a single script for the iPad Swift Playgrounds and was quickly converted to an app by using a standard Xcode template (the Core Data layer and the Watch Extension are not actually implemented): it should compile finely without dependencies just after changing the _Bundle Identifier_ in the _General_ panel and the _Team_ in the _Signing and Capabilities_ tab of Xcode (Spike users know already very well what that means... ;) ).

Please refer to the [TODOs list](https://github.com/gui-dos/DiaBLE/blob/master/TODO.md) for the up-to-date status of all the current limitations and known bugs of this prototype.

---
Credits: [bubbledevteam](https://github.com/bubbledevteam?tab=repositories), [dabear](https://github.com/dabear?tab=repositories), [LibreMonitor](https://github.com/UPetersen/LibreMonitor/tree/Swift4), [Nightguard]( https://github.com/nightscout/nightguard), [WoofWoof](https://github.com/gshaviv/ninety-two), [xDrip for iOS](https://github.com/JohanDegraeve/xdripswift).

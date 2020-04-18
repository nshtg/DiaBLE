<p align ="center"><img src="./DiaBLE//Assets.xcassets/AppIcon.appiconset/Icon.png" width="25%" /></p>

Experimenting with the Bluetooth BLE devices I bought for the Abbott FreeStyle Libre sensor (mainly the **Bubble** and **MiaoMiao** transmitters, M5Stack and the Mi Band and Watlaa watches) and trying something new compared to the traditional apps:

* a universal **SwiftUI** application for iPhone, iPad and Mac Catalyst;
* an **independent Apple Watch app** connecting directly via Bluetooth;
* scanning the Libre directly via **NFC**;
* using online servers for calibrating just like **Abbott’s algorithm**;
* varying the **reading interval** (the Bubble firmware allows to set it from 1 to 15 minutes while the MiaoMiao one to reduce it to 1 or 3 minutes);
* a detailed **log** to check the traffic from/to the BLE devices and remote servers.

Still too early to decide the final design (but I really like already the evil logo 😈), here there are the first rough screenshots:


<p align ="center"><img src="https://pbs.twimg.com/media/EVeneWZXQAMmDz5?format=png&name=4096x4096" width="25%" />&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVeoUsRWoAUBuzr?format=png&name=4096x4096" width="25%" />&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVepOTUXgAARH2r?format=png&name=4096x4096" width="25%" /></p>
<p align ="center"><img src="https://pbs.twimg.com/media/EVeqRPYWkAAyuCW?format=png&name=4096x4096" width="25%" />&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVerNLGWkAAvm2F?format=png&name=4096x4096" width="25%" >/&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVerlxLXYAApZXz?format=png&name=4096x4096" width="25%" /></p>
<p align ="center"><img src="https://pbs.twimg.com/media/EVsyTgvWkAA3coH?format=png&name=4096x4096" width="25%" />&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVeuqaqWkAIuNNd?format=png&name=4096x4096" width="25%" /></p>
<p align ="center"><img src="https://pbs.twimg.com/media/EVeu_Z-XQAA7LZ6?format=png&name=large" width="50%" /></p>
<p align ="center"><img src="https://pbs.twimg.com/media/EVexQzZXsAEisB4?format=png&name=small" align="top" width="25%" />&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVextP9XkAAh3HN?format=png&name=small" align="top" width="25%" /></p>
<p align ="center"><img src="https://pbs.twimg.com/media/EVxo7ZbX0AEt21z?format=png&name=small" align="top" width="25%" />&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVxpaLtXsAA_u2O?format=png&name=small" align="top" width="25%" /></p>
<p align ="center"><img src="https://pbs.twimg.com/media/EVttZ0PXQAAj5gp?format=png&name=small" align="top" width="25%" />&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVxp2QLXQAEKeXM?format=png&name=small" align="top" width="25%" /></p>
<p align ="center">Libre 2: YEP  -  Bubble: NOPE<br><img src="https://pbs.twimg.com/media/EV37sVXWAAAKUxG?format=png&name=small" align="top" width="25%" />&nbsp;&nbsp;<img src="https://pbs.twimg.com/media/EVyjqaTX0AAwsoH?format=png&name=small" align="top" width="25%" /></p>



The project started as a single script for the iPad Swift Playgrounds and was quickly converted to an app by using a standard Xcode template: it should compile finely without external dependencies just after changing the _Bundle Identifier_ in the _General_ panel and the _Team_ in the _Signing and Capabilities_ tab of Xcode -- Spike users know already very well what that means... ;)

Please refer to the [TODOs list](https://github.com/gui-dos/DiaBLE/blob/master/TODO.md) for the up-to-date status of all the current limitations and known bugs of this prototype.

---
Credits: [bubbledevteam](https://github.com/bubbledevteam?tab=repositories), [dabear](https://github.com/dabear?tab=repositories), [LibreMonitor](https://github.com/UPetersen/LibreMonitor/tree/Swift4), [Loop](https://github.com/LoopKit/Loop), [Marek Macner](https://github.com/MarekM60?tab=repositories), [Nightguard]( https://github.com/nightscout/nightguard), [RileyLink iOS](https://github.com/ps2/rileylink_ios), [WoofWoof](https://github.com/gshaviv/ninety-two), [xDrip for iOS](https://github.com/JohanDegraeve/xdripswift).

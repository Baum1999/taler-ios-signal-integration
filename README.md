# GNU Taler Wallet iOS Code Repository

This git repository contains the source code for the GNU Taler Wallet iOS app.
The official location is: 
    https://git.taler.net/taler-ios.git


## Compatibility

The minimum version of iOS supported is 15.0.
This app runs on all iPhone models at least as new as the iPhone 6S. For NFC, you need an iPhone running iOS 17.7 or later, which must be registered in the European Economic Area.


## Building

Before building the iOS wallet, you must first checkout the quickjs-tart repo:
```
https://git.taler.net/quickjs-tart.git
```  
and the wallet-core repo:
```
https://git.taler.net/taler-typescript-core.git
```  

Have all 3 local repos (wallet-core, quickjs-tart, and this one) adjacent at the same level (e.g. in a "GNU_Taler" folder)
- `Taler16.xcworkspace` expects the QuickJS framework sub-project to be at  
```
../quickjs-tart/QuickJS-rt16.xcodeproj
``` 
 
Build wallet-core first:  
```
cd ~/Developer/GNU_Taler/wallet-core
```  
```
date; time make embedded; open packages/taler-wallet-embedded/dist  
```  
then drag or move its product `taler-wallet-core-qjs.mjs`
into your quickjs-tart folder right at the top level.

Open `Taler16.xcworkspace`, and set scheme / target to `Taler_Wallet`.  
Build & run...

Don't open QuickJS-rt16.xcodeproj or TalerWallet16.xcodeproj and build anything
there - all needed libraries and frameworks will be built automatically from `Taler16.xcworkspace`.


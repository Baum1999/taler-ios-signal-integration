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
Rename the latter to `wallet-core`.  

Have all 3 local repos (wallet-core, quickjs-tart, and this taler-ios) adjacent at the same level (e.g. in a "GNU_Taler" folder).  
 
Build wallet-core first:  
```
cd ~/Developer/GNU_Taler/wallet-core
```  
at the very first run, you need to  
```  
./bootstrap
```  
```  
./configure
```  
then call  
```
date; time make embedded; open packages/taler-wallet-embedded/dist  
```  
you should see its product `taler-wallet-core-qjs.mjs`.

Once you have that, switch over to quickjs-tart:  
```
cd ~/Developer/GNU_Taler/quickjs-tart
```  
and call  
```
date; time ./cross/package-ios.sh; open build-ios  
```  
This builds the framework `FTalerWalletcore.xcframework` (which includes wallet-core) in the build-ios folder.  
Drag'nDrop that into the XCFrameworks folder in taler-ios. That's all for the preparations.

Open `TalerWalletXC.xcodeproj`, and set scheme / target to `Taler_Wallet`.  
Build & run...


# taler-ios with Signal integration

This repository is a fork of [taler-ios](https://git.taler.net/taler-ios.git)
that adds a link interface for Signal with GNU Taler payments
(https://github.com/Baum1999/signal-ios-taler-payments). It is a development
fork and is not affiliated with the GNU Taler team or Signal Messenger LLC.
The original upstream README follows further down.

Signal never moves money. When a user sends, requests, accepts, refunds or
aborts a payment from a Signal chat, Signal opens a `talerlink://` link in this
app. The user confirms the action here, and the app jumps back to Signal with
`sgnl://taler-return`. There is no IPC and no server of our own.

## Branches and targets

| Branch | Content |
|---|---|
| `master` | Upstream taler-ios plus the Signal integration, regularly rebased onto upstream `master` |

All integration code is inside `#if TALER_SIGNAL` (decision E12). The flag is
set for the `GNU_Taler` target, whose Info.plist also registers `talerlink`
and queries `sgnl`. `Taler_Wallet` and `Taler_Nightly` build unchanged.

## What the fork adds

- **`talerlink://` scheme and router.** Handles `compose-send`,
  `compose-refund`, `compose-abort` and action links
  `talerlink://pay-push/…` / `talerlink://pay-pull/…`. The custom scheme exists
  because upstream GNU Taler also registers `taler://`, and iOS does not
  guarantee which app opens it.
- **Compose send/request.** A screen that shows the recipient name from
  Signal, switches between send and request, and splits group payments into
  per-member amounts. The purpose field is optional, with a fallback text.
- **Refund.** Resolves the received transaction from `originalUri` and warns
  if it was already refunded.
- **Bulk abort** of the user's own open payments ("Delete for everyone" in
  Signal), with one confirmation and one result per URI.
- **Own URIs.** Payments created here are remembered as SHA-256 keys. An
  action link for an own payment opens the transaction instead of accepting
  the payment back to oneself.
- **Return to Signal.** Validates the target (scheme
  `ReturnURLBuilder.returnScheme`, host `taler-return`), always rebuilds the
  query and sends exactly one return per operation. Closing a sheet by swiping
  counts as `cancelled` / `declined`.
- **Backend gate.** On a cold start through a link, the app waits until
  wallet-core is ready.

## Where the code is

| Path | Content |
|---|---|
| `TalerWallet1/Controllers/SignalLink/` | All integration code: `SignalLinkRouter`, `SignalLinkRequest` (parser), `ReturnURLBuilder`, compose views, `OwnUriStore`, `SentRefundStore`, `AmountSplit`, … |
| `TalerWallet1/Controllers/Controller.swift` | Hook into URL handling (`#if TALER_SIGNAL`) |
| `TalerWallet1/Views/Main/MainView.swift`, `…/P2P_Sheets/P2pAcceptDone.swift` | Sheet presentation and return after accepting |
| `TalerWallet1/Resources/GNU_Taler Info.plist` | URL schemes `taler`, `talerlink`; query scheme `sgnl` |

`SignalLinkSelfCheck.swift` contains parser checks. There are no automated
tests in this repo yet. Interface contracts between the apps (links,
parameters, data model, decision log):
[`docs/taler-signal/`](docs/taler-signal/README.md).

## Building

Build wallet-core and quickjs-tart exactly as described in the upstream README
below, then build the `GNU_Taler` scheme.

## Known limitations

- **No sender check.** iOS cannot verify which app sent a link or registered
  the return scheme. Safety comes from the user confirming every money
  movement in this app, and from Signal treating returns as untrusted
  (decisions E8/E9).
- **Payment without a message.** On send and refund, the payment is committed
  *before* the return to Signal. If the return gets lost, Signal sends no
  message for it.
- The contract documents are mostly in German.

## Related repositories

- Signal-iOS with GNU Taler payments: https://github.com/Baum1999/signal-ios-taler-payments
- Signal Android with GNU Taler payments: https://github.com/Baum1999/signal-taler-payments
- GNU Taler wallet with Signal integration, Android: https://github.com/Baum1999/taler-signal-integration

---

_Original upstream README:_

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


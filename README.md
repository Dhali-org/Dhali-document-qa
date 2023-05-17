# xrpl-text-to-speech

An application for consuming the Dhali text-2-speech asset directly from the Dhali marketplace.

## Pre-requisites

* Install [Flutter](https://docs.flutter.dev/get-started/install)
```bash
$ flutter --version
Flutter 3.9.0-1.0.pre.161 • channel master • https://github.com/flutter/flutter.git
Framework • revision f9ad42a32d (9 days ago) • 2023-03-11 03:32:04 +0000
Engine • revision e9ca7b2c45
Tools • Dart 3.0.0 (build 3.0.0-313.0.dev) • DevTools 2.22.2
```

## Running

* Start the app:
```
flutter run
```
* Activate your wallet using a BIP-39 compatible collection of words (see, [here](https://iancoleman.io/bip39/))
    - All subsequent re-activications will add more test XRP to the same account.
    - You can view your account on the XRPL testnet [here](https://testnet.xrpl.org/)
* Once the application is running, you can input text that you would like to be converted to audio.

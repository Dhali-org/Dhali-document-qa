import 'package:flutter/material.dart';
import 'dart:html';
import 'package:node_interop/util.dart';
import 'package:logger/logger.dart';

import 'package:xrpl/xrpl.dart';

class PaymentChannelDescriptor {
  String channelId;
  int amount;

  PaymentChannelDescriptor(this.channelId, this.amount);
}

class ImplementationErrorException implements Exception {
  String message;
  ImplementationErrorException(this.message);
}

class UnexpectedResponseException implements Exception {
  String message;
  UnexpectedResponseException(this.message);
}

class InvalidPaymentChannelException implements Exception {
  String message;
  InvalidPaymentChannelException(this.message);
}

class XRPLWallet {
  static String uninitialisedUrl = 'NOT INITIALISED!';
  // Choose from https://xrpl.org/public-servers.html
  static String testNetUrl = 'wss://s.altnet.rippletest.net/';
  // TODO: change once prod-ready:
  static String mainnetUrl = 'NOT IMPLEMENTED YET';

  String _netUrl = uninitialisedUrl;

  Wallet? _wallet;
  String? mnemonic;

  ValueNotifier<String?> balance = ValueNotifier(null);

  XRPLWallet(String seed, {bool testMode = false, fundingAmount = "40"}) {
    _netUrl = testMode ? testNetUrl : mainnetUrl;
    mnemonic = seed;

    var walletFromMneomicOptions = WalletFromMnemonicOptions(
      mnemonicEncoding: "bip39",
    );

    _wallet = Wallet.fromMnemonic(seed, walletFromMneomicOptions);

    Client client = Client(_netUrl);
    var logger = Logger();

    if (_wallet == null) {
      return;
    }

    try {
      promiseToFuture(client.connect()).then((erg) async {
        // TODO: Remove this in the future
        final options = FundWalletOptions(amount: fundingAmount);
        // TODO: Consider improving the error handling
        // This weird error handling appears to be the only way this could  be
        // forced to work. The problem:
        // TypeError: Failed to fetch: https://unpkg.com/xrpl@2.6.0/build/xrpl-latest-min.js 2:622721  _onFinish
        // https://unpkg.com/xrpl@2.6.0/build/xrpl-latest-min.js 2:621692  <fn>
        // https://unpkg.com/xrpl@2.6.0/build/xrpl-latest-min.js 2:362232  emit
        // https://unpkg.com/xrpl@2.6.0/build/xrpl-latest-min.js 2:514810  L
        // https://unpkg.com/xrpl@2.6.0/build/xrpl-latest-min.js 2:513706  M
        // https://unpkg.com/xrpl@2.6.0/build/xrpl-latest-min.js 2:487193  run
        // https://unpkg.com/xrpl@2.6.0/build/xrpl-latest-min.js 2:486687  h
        bool fundingSuccessful = false;
        bool currentlyWaiting = false;
        while (fundingSuccessful == false) {
          if (currentlyWaiting == false) {
            currentlyWaiting = true;
            promiseToFuture(client.fundWallet(_wallet, options)).then((e) {
              String address = _wallet!.address;
              fundingSuccessful = true;
              promiseToFuture(client.getXrpBalance(address))
                  .then((balanceString) {
                balance.value = balanceString.toString();
              }).whenComplete(() {
                client.disconnect();
              });
            }).onError((error, stackTrace) {
              print(error.toString() + ": " + stackTrace.toString());
            }).whenComplete(() {
              currentlyWaiting = false;
            });
          }
          await Future.delayed(Duration(seconds: 5));
        }
      }).onError((error, stackTrace) {
        print(error.toString() + ": " + stackTrace.toString());
      });
    } catch (e, stacktrace) {
      logger.e('Exception caught: ${e.toString()}');
      logger.e(stacktrace);
    }

    print("ended");
  }

  String publicKey() {
    return _wallet!.publicKey;
  }

  String get address {
    return _wallet!.address;
  }

  String sendDrops(String amount, String channelId) {
    return authorizeChannel(_wallet!, channelId, amount);
  }

  Future<bool> acceptOffer(String offerIndex) async {
    Client client = Client(_netUrl);

    var logger = Logger();
    try {
      var nftOfferAccept = NFTOfferAccept(
          Account: this._wallet!.address,
          NFTokenSellOffer: offerIndex,
          TransactionType: "NFTokenAcceptOffer");
      var signTransactionOptions = SignTransactionOptions(
        autofill: true,
        failHard: true,
        wallet: _wallet!,
      );

      return promiseToFuture(client.connect()).then((_) {
        return promiseToFuture(
                client.submitAndWait(nftOfferAccept, signTransactionOptions))
            .then((response) {
          dynamic dartResponse = dartify(response);
          dynamic result = dartResponse["result"];

          return Future<bool>.value(true);
        }).catchError((e, stacktrace) {
          logger.e("Exception caught from future: $e");
          logger.e("Stack trace: $stacktrace");
          return Future<bool>.error(e);
        });
      }).catchError((e, stacktrace) {
        logger.e("Exception caught from future: $e");
        logger.e("Stack trace: $stacktrace");
        return Future<bool>.error(e);
      });
    } catch (e, stacktrace) {
      logger.e('Exception caught: $e');
      logger.e(stacktrace);
      return Future<bool>.error(e);
    } finally {
      // TODO: This looks a potential source of race conditions with the asyncronous function calls above - maybe an RAII-style wrapped class would be appropriate to use instead of doing this.
      client.disconnect();
    }
    return Future.error(ImplementationErrorException(
        "This code should never be reached, and indicates an implementation error."));
  }

  Future<List<PaymentChannelDescriptor>> getOpenPaymentChannels(
      {String? destination_address}) async {
    Client client = Client(_netUrl);

    var logger = Logger();
    try {
      var accountChannelsRequest = AccountChannelsRequest(
        account: _wallet!.address,
        command: "account_channels",
        destination_account: destination_address,
      );

      return promiseToFuture(client.connect()).then((_) {
        return promiseToFuture(client.request(accountChannelsRequest))
            .then((response) {
          dynamic dartResponse = dartify(response);
          dynamic returnedChannelDescriptors =
              dartResponse["result"]["channels"];

          var channelDescriptors = <PaymentChannelDescriptor>[];
          returnedChannelDescriptors.forEach((returnedDescriptor) {
            dynamic dartDescriptor = returnedDescriptor;
            channelDescriptors.add(PaymentChannelDescriptor(
                returnedDescriptor["channel_id"],
                int.parse(returnedDescriptor["amount"])));
          });
          return Future<List<PaymentChannelDescriptor>>.value(
              channelDescriptors);
        }).catchError((e, stacktrace) {
          logger.e("Exception caught from future: $e");
          logger.e("Stack trace: $stacktrace");
          return Future<List<PaymentChannelDescriptor>>.error(e);
        });
      });
    } catch (e, stacktrace) {
      logger.e('Exception caught: $e');
      logger.e(stacktrace);
      return Future<List<PaymentChannelDescriptor>>.error(e);
    } finally {
      // TODO: This looks like a potential source of race conditions with the asyncronous function calls above - maybe an RAII-style wrapped class would be appropriate to use instead of doing this.
      client.disconnect();
    }
    return Future.error(ImplementationErrorException(
        "This code should never be reached, and indicates an implementation error."));
  }

  Future<PaymentChannelDescriptor> openPaymentChannel(
      String destinationAddress, String amount) async {
    Client client = Client(_netUrl);
    var logger = Logger();

    try {
      const int settleDelay = 15768000; // 6 months
      return promiseToFuture(client.connect()).then((erg) {
        var paymentChannelCreateTransaction = PaymentChannelCreate(
          Account: _wallet!.address,
          TransactionType: "PaymentChannelCreate",
          Amount: amount,
          Destination: destinationAddress,
          SettleDelay: settleDelay,
          PublicKey: _wallet!.publicKey,
        );
        var signTransactionOptions = SignTransactionOptions(
          autofill: true,
          failHard: true,
          wallet: _wallet!,
        );

        return promiseToFuture(client.submitAndWait(
                paymentChannelCreateTransaction, signTransactionOptions))
            .then((response) {
          dynamic dartResponse = dartify(response);

          dynamic channel = dartResponse['result'];
          bool sourceAccountIsCorrect = channel["Account"] == _wallet!.address;
          bool destinationAccountIsCorrect =
              channel["Destination"] == destinationAddress;
          bool amountIsCorrect = channel["Amount"] == amount;
          bool delayIsCorrect = channel["SettleDelay"] == settleDelay;

          dynamic channelMeta = channel["meta"];
          bool transactionWasSuccessful =
              channelMeta["TransactionResult"] == "tesSUCCESS";
          bool channelIsValidated = channel["validated"] == true;

          bool channelIsValidSoFar = sourceAccountIsCorrect &&
              destinationAccountIsCorrect &&
              amountIsCorrect &&
              delayIsCorrect &&
              transactionWasSuccessful &&
              channelIsValidated;
          if (!channelIsValidSoFar) {
            var errorMessage = '''
Attempted to create invalid channel.
Valid source account: $sourceAccountIsCorrect
Destination account: $destinationAccountIsCorrect
Amount: $amountIsCorrect
Settlement delay is correct: $delayIsCorrect
Transaction was successful: $transactionWasSuccessful
Channel was validated: $channelIsValidated
                ''';
            return Future<PaymentChannelDescriptor>.error(
                InvalidPaymentChannelException(errorMessage));
          }

          dynamic affectedNodes = channelMeta["AffectedNodes"];

          const String invalidChannelId = "INVALID_CHANNEL_ID";
          String channelId = invalidChannelId;

          affectedNodes.forEach((jsAffectedNode) {
            dynamic affectedNode = jsAffectedNode;

            const String createdNodeKey = "CreatedNode";
            if (!affectedNode.containsKey(createdNodeKey)) {
              return;
            }

            dynamic createdNode = affectedNode[createdNodeKey];
            var ledgerEntryType = createdNode["LedgerEntryType"];
            if (ledgerEntryType != "PayChannel") {
              return;
            }
            channelId = createdNode["LedgerIndex"];
          });

          if (channelId == invalidChannelId) {
            return Future<PaymentChannelDescriptor>.error(
                UnexpectedResponseException(
                    "Got unexpected response: $dartResponse. It has not been handled correctly, and so needs to be investigated."));
          }
          return Future<PaymentChannelDescriptor>.value(
              PaymentChannelDescriptor(channelId, int.parse(amount)));
        }).catchError((e, stacktrace) {
          logger.e("Exception caught: $e");
          logger.e("$stacktrace");
          return Future<PaymentChannelDescriptor>.error(e);
        });
      }).catchError((e, stacktrace) {
        logger.e("Exception caught: $e");
        logger.e("$stacktrace");
        return Future<PaymentChannelDescriptor>.error(e);
      });
    } catch (e, stacktrace) {
      logger.e('Exception caught: $e');
      logger.e(stacktrace);
    } finally {
      // TODO: This looks like a potential source of race conditions with the asyncronous function calls above - maybe an RAII-style wrapped class would be appropriate to use instead of doing this.
      client.disconnect();
    }

    return Future.error(ImplementationErrorException(
        "This code should never be reached, and indicates an implementation error."));
  }
}

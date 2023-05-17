import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xrpl/xrpl.dart';
import 'package:flutter/material.dart';

import 'package:consumer_application/wallet.dart';
import 'package:bip39/bip39.dart' as bip39;

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen(
      {super.key,
      required this.title,
      required this.getWallet,
      required this.setWallet});

  final String title;
  final XRPLWallet? Function() getWallet;
  final Function(XRPLWallet) setWallet;

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

// TODO: Metamask-style phrase creation and verification
class _WalletHomeScreenState extends State<WalletHomeScreen> {
  // TODO: pull the fields below from wallet
  String _publicKey = "";
  String? _mnemonicState;

  final _mnemonicFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    if (widget.getWallet() == null) {
      return Scaffold(
        body: Center(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60.0),
                  child: Form(
                    key: _mnemonicFormKey,
                    child: Column(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 25),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                children: <Widget>[
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.blue,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.all(.0),
                                      textStyle: const TextStyle(
                                          fontSize: 20, color: Colors.black),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _mnemonicState =
                                            bip39.generateMnemonic();
                                        var wallet = XRPLWallet(_mnemonicState!,
                                            testMode: true);
                                        widget.setWallet(wallet);
                                        _publicKey =
                                            widget.getWallet()!.publicKey();
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 50.0, vertical: 25),
                                      child: Text(
                                        'Generate new wallet',
                                        style: TextStyle(
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '\n\nor\n\n',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 25),
                              ),
                            ],
                          ),
                        ),
                        TextFormField(
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: const InputDecoration(
                              hintText: "Input your memorable words here.",
                            ),
                            validator: (value) {
                              const String errorMessage =
                                  'You must have at least 12 memorable words for your wallet.';
                              if (value == null || value.isEmpty) {
                                return errorMessage;
                              }

                              final whitespaceRegex = RegExp(r"\s+");
                              final leadingWhitespaceRegex = RegExp(r"^\s");
                              final trailingWhitespaceRegex = RegExp(r"\s$");

                              String cleanupWhitespace(String input) => value
                                  .replaceAll(whitespaceRegex, " ")
                                  .replaceAll(leadingWhitespaceRegex, "")
                                  .replaceAll(trailingWhitespaceRegex, "");

                              if (cleanupWhitespace(value).split(' ').length <
                                  12) {
                                return errorMessage;
                              }
                              return null;
                            },
                            onChanged: (String mnemonic) {
                              if (_mnemonicFormKey.currentState!.validate()) {
                                setState(() {
                                  _mnemonicState = mnemonic;
                                });
                              } else {
                                setState(() {
                                  _mnemonicState = null;
                                });
                              }
                            }),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 25),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                children: <Widget>[
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.blue,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.all(.0),
                                      textStyle: const TextStyle(fontSize: 20),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (_mnemonicState != null) {
                                          // TODO: 'testMode' to 'false' for release
                                          var wallet = XRPLWallet(
                                              _mnemonicState!,
                                              testMode: true);
                                          widget.setWallet(wallet);
                                          _publicKey =
                                              widget.getWallet()!.publicKey();
                                        }
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 50.0, vertical: 25),
                                      child: Text(
                                        'Retrieve your wallet',
                                        style: TextStyle(
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        body: Center(
          child: getGeneratedWidget(widget.getWallet()!, hideMnemonic: false),
        ),
      );
    }
  }
}

Widget getGeneratedWidget(XRPLWallet wallet, {bool hideMnemonic = true}) {
  return ListView(
    shrinkWrap: true,
    children: <Widget>[
      !hideMnemonic
          ? RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text:
                        'To regenerate your wallet later, remember your keywords:\n',
                    style: TextStyle(color: Colors.white, fontSize: 25),
                  ),
                ],
              ),
            )
          : SizedBox.shrink(),
      !hideMnemonic
          ? SelectableText(
              wallet.mnemonic!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold),
            )
          : SizedBox.shrink(),
      //const Center(
      //  child: const Padding(
      //padding: EdgeInsets.symmetric(horizontal: 200.0,
      //                        vertical: 100.0),
      //    child: BalanceChart(),
      //  )
      //),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 25.0),
          child: ValueListenableBuilder<String?>(
              valueListenable: wallet.balance,
              builder: (BuildContext context, String? balance, Widget? _) {
                if (balance == null) {
                  return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Loading balance: ",
                            style: TextStyle(fontSize: 25)),
                        CircularProgressIndicator()
                      ]);
                }
                return SelectableText('Your balance: $balance',
                    style: const TextStyle(fontSize: 25));
              }),
        ),
      ),
      Center(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 25.0),
            child: SelectableText(
              'Your classic address: ${wallet.address}',
              style: const TextStyle(fontSize: 25),
            )),
      )
    ],
  );
}

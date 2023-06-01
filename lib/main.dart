import 'dart:async';
import 'dart:html' as html;
import 'dart:io';
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:web_audio';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:consumer_application/accents_dropdown.dart';
import 'package:consumer_application/download_file_widget.dart';
import 'package:consumer_application/sentence_list_widget.dart';
import 'package:dhali_wallet/dhali_wallet_widget.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import 'dart:convert';
import 'package:dhali_wallet/dhali_wallet.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/src/media_type.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:xrpl/xrpl.dart';

import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:image/image.dart' as imglib;
import 'package:bip39/bip39.dart' as bip39;

enum DrawerIndex {
  Wallet,
  Product,
}

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TextInputScreen(
        getFirestore: () => FirebaseFirestore.instance,
      ),
    ),
  );
}

enum SnackBarTypes { error, success, inProgress }

const Map<String, int> accents = {
  "American woman 1": 7000,
  "American woman 2": 7391,
  "American woman 3": 6801,
  "American woman 4": 7900,
  "American man 1": 2100,
  "American man 2": 6100,
  "American man 3": 1300,
  "American man 4": 5000,
  "American man 5": 4000
};

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({Key? key, required this.getFirestore})
      : super(key: key);

  final FirebaseFirestore Function() getFirestore;
  @override
  TextInputScreenState createState() => TextInputScreenState();
}

class TextInputScreenState extends State<TextInputScreen> {
  List<Pair<String, bool>> sentences = [
    Pair("Who is the supplier?", true),
    Pair("What is the invoice number?", true),
    Pair("What is the total cost?", true),
    Pair("When is the payment due?", true)
  ];
  static const String uuid = 'd14a01e78-cced-470d-915a-64d194c1c830';
  String dhaliDebit = "0";
  double progress = 0;
  String answer = "";
  String confidence = "";
  String outputCsv = "";
  bool complete = true;
  bool errored = false;
  Widget? screenView;
  DrawerIndex? drawerIndex;
  double? _costPerRun;

  List<PlatformFile> images = [];
  DhaliWallet? _wallet;
  bool hideMnemonic = true;
  final String _endPoint =
      "https://dhali-prod-run-dauenf0n.uc.gateway.dev/${uuid}/run";
  Client client = Client('wss://s.altnet.rippletest.net:51233');
  ValueNotifier<String?> balance = ValueNotifier(null);
  bool _showContinueButton = false;

  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(),
              child: Container(
                height: 100, // Or any other height that suits your design
                child: SvgPicture.asset(
                    'assets/images/blue-company-logo-clean.svg',
                    semanticsLabel: 'Acme Logo'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.wallet),
              title: const Text('Wallet'),
              onTap: () {
                setState(() {
                  drawerIndex = DrawerIndex.Wallet;
                  screenView = getScreenView(drawerIndex);
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.token),
              title: const Text('AuditBot'),
              onTap: () {
                setState(() {
                  drawerIndex = DrawerIndex.Product;
                  screenView = getScreenView(drawerIndex);
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
                leading: const Icon(Icons.cookie),
                title: const Text('Cookie Consent Preferences'),
                onTap: () {
                  js.context.callMethod('displayPreferenceModal');
                }),
          ],
        ),
      ),
      body: screenView == null
          ? getWalletScaffoldBody()
          : getScreenView(drawerIndex),
      floatingActionButton: screenView == null
          ? getWalletFloatingActionButton("Activate wallet")
          : null,
      floatingActionButtonLocation:
          screenView == null ? FloatingActionButtonLocation.centerFloat : null,
    );
  }

  Widget getAnimatedText(String text) {
    return AnimatedTextKit(
      animatedTexts: [
        TypewriterAnimatedText(
          text,
          textStyle: const TextStyle(
            fontSize: 32.0,
            fontWeight: FontWeight.bold,
          ),
          speed: const Duration(milliseconds: 50),
        ),
      ],
      repeatForever: true,
      pause: const Duration(milliseconds: 50),
      displayFullTextOnTap: true,
      stopPauseOnTap: true,
    );
  }

  Widget getInferenceScaffoldBody() {
    return ListView(children: [
      SizedBox(height: 10),
      getHeader(),
      Container(
        height: MediaQuery.of(context).size.height / 10,
      ),
      Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width / 10,
          ),
          const Text(
            "1. Upload your invoice images",
            textAlign: TextAlign.left,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
        ],
      ),
      SizedBox(height: 50),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Spacer(flex: 3),
          ElevatedButton(
            style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all<Color>(Colors.tealAccent),
                fixedSize: MaterialStateProperty.all(Size(200,
                    48)), // Set the desired width and heightshape: MaterialStateProperty.all<RoundedRectangleBorder>(
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      25), // Adjust the radius value as needed
                ))),
            onPressed: () async {
              var picked = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ["png"],
                  allowMultiple: true);
              if (picked != null) {
                images = [];
                answer = "";
                confidence = "";
                setState(() {
                  images = picked.files;
                });
                // TODO : Consider allowing PDFs to be uploaded
                // final doc = await PdfDocument.openData(
                //     picked.files.first.bytes!);
                // final pages = doc.pageCount;

                // // get images from all the pages
                // for (int i = 1; i <= pages; i++) {
                //   var page = await doc.getPage(i);
                //   var imgPDF = await page.render();
                //   var img = await imgPDF.createImageDetached();
                //   var bytes = await img.toByteData(
                //       format: ImageByteFormat.png);
                //   images.add(bytes!);
                // }
              }
            },
            child: Text(
              'Select images',
              style: TextStyle(color: Colors.black),
            ),
          ),
          Spacer(flex: 3)
        ],
      ),
      images.length > 0
          ? Center(
              child: Text(
                "\n\n${images.length} images selected",
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            )
          : SizedBox.shrink(),
      SizedBox(height: 50),
      Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width / 10,
          ),
          const Text(
            "2. Choose your questions",
            textAlign: TextAlign.left,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
        ],
      ),
      SizedBox(height: 50),
      Row(
        children: [
          const Spacer(
            flex: 1,
          ),
          SentenceListWidget(
            getSentences: () => sentences,
            setSentences: (updatedSentences) {
              setState(() {
                updatedSentences = sentences;
              });
            },
          ),
          const Spacer(
            flex: 1,
          )
        ],
      ),
      SizedBox(height: 50),
      Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width / 10,
          ),
          !complete
              ? const Text(
                  "3. Running  ",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                )
              : const Text(
                  "3. Run",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                ),
          !complete ? CircularProgressIndicator() : SizedBox.shrink()
        ],
      ),
      SizedBox(height: 20),
      Row(children: [
        const Spacer(
          flex: 1,
        ),
        Center(
            child: Table(
          defaultColumnWidth: IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                TableCell(
                  child: Container(
                    margin: EdgeInsets.all(8),
                    child: Text('Expected cost per request:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                TableCell(
                    child: FutureBuilder(
                        future: widget
                            .getFirestore()
                            .collection("public_minted_nfts")
                            .doc(uuid)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          } else if (snapshot.hasData &&
                              snapshot.data!.data() != null) {
                            // TODO: https://github.com/orgs/Dhali-org/projects/1/views/1?pane=issue&itemId=29307943
                            _costPerRun =
                                snapshot.data!.data()!["cost_per_ms"] as double;
                            return Center(
                                child: Text(
                                    "${(_costPerRun! / 1000000).toStringAsFixed(3)} XRP",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)));
                          }
                          return const Text("unknown");
                        })),
                TableCell(
                    child: IconButton(
                        icon: Icon(Icons.info),
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Information'),
                                  content: const Text(
                                      'The number of requests is equal to the '
                                      'number of images multiplied by the number '
                                      'of questions.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text("OK"),
                                    ),
                                  ],
                                );
                              });
                        }))
              ],
            ),
            TableRow(
              children: [
                TableCell(
                  child: Container(
                    margin: EdgeInsets.all(8),
                    child: Text('Expected total:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                TableCell(
                    child: FutureBuilder(
                        future: widget
                            .getFirestore()
                            .collection("public_minted_nfts")
                            .doc(uuid)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          } else if (snapshot.hasData &&
                              snapshot.data!.data() != null) {
                            // TODO: https://github.com/orgs/Dhali-org/projects/1/views/1?pane=issue&itemId=29307943
                            _costPerRun =
                                snapshot.data!.data()!["cost_per_ms"] as double;
                            return Center(
                                child: Text(
                                    (images.length *
                                                sentences.length *
                                                _costPerRun! /
                                                1000000)
                                            .toStringAsFixed(3) +
                                        " XRP",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)));
                          }
                          return const Text("unknown");
                        })),
                TableCell(child: SizedBox.shrink())
              ],
            )
          ],
        )),
        const Spacer(
          flex: 6,
        ),
      ]),
      SizedBox(height: 50),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Spacer(flex: 2),
          getDownloadFloatingActionButton(),
          Spacer(flex: 2),
          getInferenceFloatingActionButton(),
          Spacer(flex: 2)
        ],
      ),
      SizedBox(height: 20),
      images.length * sentences.length != 0 && progress != 0
          ? Row(children: [
              Spacer(flex: 2),
              Expanded(
                  flex: 8,
                  child: LinearProgressIndicator(
                      color: Colors.green,
                      value: progress / (images.length * sentences.length))),
              Spacer(flex: 2),
            ])
          : const SizedBox.shrink(),
      Container(
        height: MediaQuery.of(context).size.height / 20,
      ),
      SizedBox(height: 50),
      RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'GitHub repo: ',
              style: TextStyle(color: Colors.white),
            ),
            TextSpan(
              text: 'https://github.com/Dhali-org/Dhali-document-qa',
              style: TextStyle(color: Colors.blue),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  launchUrl(Uri.parse(
                      'https://github.com/Dhali-org/Dhali-document-qa'));
                },
            ),
            TextSpan(
              text:
                  "\nNote: costs are calculated based on input size.  This app uses the XRPL testnet.",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    ]);
    // floatingActionButton: Container(
    //   constraints: BoxConstraints.tightFor(height: 100),
    //   child: ,
    //   color: Colors.black,
    // )
  }

  Widget getDownloadFloatingActionButton() {
    return FloatingActionButton(
      foregroundColor: !complete ? Colors.grey : null,
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      heroTag: "download",
      tooltip: "Export results",
      onPressed: !complete
          ? null
          : () {
              if (this.outputCsv == "") {
                updateSnackBar(
                    message: "Please click run!",
                    snackBarType: SnackBarTypes.error);
                return;
              }
              String encodedCsv = Uri.encodeComponent(outputCsv);
              final dataUri = 'data:text/plain;charset=utf-8,$encodedCsv';
              html.document.createElement('a') as html.AnchorElement
                ..href = dataUri
                ..download = 'results.csv'
                ..dispatchEvent(html.Event.eventType('MouseEvent', 'click'));
            },
      child: const Icon(
        Icons.download,
        size: 40,
        fill: 1,
      ),
    );
  }

  Widget getInferenceFloatingActionButton() {
    return FloatingActionButton(
      foregroundColor: images.length == 0 ? Colors.grey : null,
      heroTag: "run",
      tooltip: "Run inference",
      onPressed: () async {
        errored = false;
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        if (_wallet == null) {
          updateSnackBar(
              message: "Please activate your wallet",
              snackBarType: SnackBarTypes.error);
          return;
        }
        if (_wallet!.balance.value == null || _costPerRun == null) {
          updateSnackBar(
              message:
                  "Your wallet's balance is updating. Please wait a moment",
              snackBarType: SnackBarTypes.error);
          return;
        }
        if (images.length == 0) {
          updateSnackBar(
              message: "Please select your images",
              snackBarType: SnackBarTypes.error);
          return;
        }

        outputCsv = "";

        outputCsv += "filename, ";

        for (var question in sentences) {
          outputCsv += question.string + ", confidence, ";
        }

        outputCsv += "\n";

        var logger = Logger();
        try {
          String dest = "rstbSTpPcyxMsiXwkBxS9tFTrg2JsDNxWk"; // Dhali's address
          var openChannels =
              await _wallet!.getOpenPaymentChannels(destination_address: dest);

          double to_claim = 0;
          if (openChannels.isNotEmpty) {
            var doc_id =
                Uuid().v5(Uuid.NAMESPACE_URL, openChannels[0].channelId);

            var to_claim_doc = await widget
                .getFirestore()
                .collection("public_claim_info")
                .doc(doc_id)
                .get();

            to_claim = to_claim_doc.exists
                ? to_claim_doc.data()!["to_claim"] as double
                : 0;
          }

          double totalAmountRequired = to_claim +
              (_costPerRun! * images.length * sentences.length * 1.4);

          double amountNeeded = (totalAmountRequired / 1000000 -
              double.parse(_wallet!.balance.value!));

          bool? willFundDhaliBalance;
          if (mounted &&
              double.parse(_wallet!.balance.value!) < totalAmountRequired) {
            willFundDhaliBalance = await showDialog<bool?>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(
                        'Fund my Dhali balance with ${(totalAmountRequired / 1000000).toStringAsFixed(3)} XRP'),
                    content: Text(
                        'To run this, you must have at least ${(totalAmountRequired / 1000000).toStringAsFixed(3)} XRP in '
                        'your Dhali balance. \n\nYou must add '
                        '${amountNeeded.toStringAsFixed(3)}'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        child: const Text("Yes"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: const Text("No"),
                      ),
                    ],
                  );
                });
            if (willFundDhaliBalance != true) {
              return;
            }
            updateSnackBar(
                message: "Processing your request",
                snackBarType: SnackBarTypes.inProgress);
            if (openChannels.length == 0) {
              openChannels = [
                await _wallet!.openPaymentChannel(
                    dest, totalAmountRequired.ceil().toString())
              ];
            } else {
              _wallet!.fundPaymentChannel(
                  openChannels[0], '${amountNeeded.ceil().toString()}');
            }
          } else if (double.parse(_wallet!.balance.value!) >=
              totalAmountRequired) {
          } else {
            updateSnackBar(
                message: "An error occured when funding your Dhali balance",
                snackBarType: SnackBarTypes.error);
            return;
          }

          if (openChannels.isNotEmpty) {
          } else {
            updateSnackBar(
                message: "Please select your images",
                snackBarType: SnackBarTypes.error);
          }

          bool? willFundDhaliRequest;
          Map<String, String> paymentClaim;
          if (mounted) {
            willFundDhaliRequest = await showDialog<bool?>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Continue?'),
                    content: Text(
                        'This request will cost upto ${(totalAmountRequired / 1000000).toStringAsFixed(3)} XRP'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        child: const Text("Yes"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: const Text("No"),
                      ),
                    ],
                  );
                });
            if (willFundDhaliRequest != true) {
              return;
            }
            paymentClaim = await _wallet!.preparePayment(
                destinationAddress: dest,
                authAmount: totalAmountRequired.ceil().toString(),
                channelDescriptor: openChannels[0]);
          } else {
            updateSnackBar(
                message: "An error occured", snackBarType: SnackBarTypes.error);
            return;
          }
          setState(() {
            complete = false;
            progress = 0.1;
          });
          Map<String, String> header = {
            "Payment-Claim": const JsonEncoder().convert(paymentClaim)
          };
          for (var image in images) {
            outputCsv += "${image.name}, ";
            for (var question in sentences) {
              if (question.string == "" || question.flag == false) {
                continue;
              }

              String entryPointUrlRoot = _endPoint;

              var request =
                  http.MultipartRequest("PUT", Uri.parse(entryPointUrlRoot));
              request.headers.addAll(header);

              var input =
                  '{"image": "${base64Encode(image.bytes!)}", "question": "${question.string}"}';
              request.files.add(http.MultipartFile(
                  contentType: MediaType('multipart', 'form-data'),
                  "input",
                  Stream.value(input.codeUnits),
                  input.codeUnits.length,
                  filename: "input"));

              var finalResponse = await request.send();

              if (finalResponse.headers
                      .containsKey("dhali-total-requests-charge") &&
                  finalResponse.headers["dhali-total-requests-charge"] !=
                      null) {
                dhaliDebit =
                    finalResponse.headers["dhali-total-requests-charge"]!;
              }

              logger.d("Status: ${finalResponse.statusCode}");
              var response =
                  json.decode(await finalResponse.stream.bytesToString());
              if (finalResponse.statusCode == 200) {
                String answer = (response["results"][0]["answer"] as String);
                double confidence = (response["results"][0]["score"] as double);

                logger.d("Answer", answer);
                logger.d("Confidence", confidence);

                outputCsv += ("\"$answer\", ");
                outputCsv += ("\"$confidence\", ");
              } else {
                errored = true;
                logger.d("Response code", finalResponse.statusCode);
                updateSnackBar(
                    message: response.toString(),
                    snackBarType: SnackBarTypes.error);
                if (finalResponse.statusCode == 402) {
                  outputCsv += ("ERROR: insufficient funds, 0, ");
                  throw const HttpException("Insufficient funds");
                } else {
                  outputCsv += ("ERROR, 0, ");
                  throw HttpException(
                      "An ${finalResponse.statusCode} error occured");
                }
              }
              setState(() {
                progress += 1;
              });
            }
            outputCsv += "\n";
          }
        } catch (e) {
          errored = true;
          logger.d("Error", e.toString());
          updateSnackBar(
              message: e.toString(), snackBarType: SnackBarTypes.error);
        }

        setState(() {
          complete = true;
        });
        if (errored == false) {
          updateSnackBar(snackBarType: SnackBarTypes.success);
        }
      },
      child: const Icon(
        Icons.play_arrow,
        size: 40,
        fill: 1,
      ),
    );
  }

  Widget getWalletFloatingActionButton(String text) {
    return FloatingActionButton.extended(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      heroTag: "getWallet",
      tooltip: "Activate or top-up my wallet",
      onPressed: () async {
        updateSnackBar(
            message: "This app currently uses the test XRP leger.",
            snackBarType: SnackBarTypes.error);

        getScreenView(DrawerIndex.Wallet);
      },
      label: Text(
        text,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget getHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        const Spacer(flex: 1),
        const SizedBox(
          width: 10,
        ),
        badges.Badge(
            position: badges.BadgePosition.topEnd(top: -5, end: -45),
            showBadge: true,
            ignorePointer: false,
            onTap: () {},
            badgeContent: const Text(
              'Preview',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 10,
                color: Color.fromARGB(255, 186, 151, 255),
                fontWeight: FontWeight.bold,
              ),
            ),
            badgeStyle: badges.BadgeStyle(
              shape: badges.BadgeShape.square,
              badgeColor: Color.fromARGB(0, 0, 0, 0),
              padding: const EdgeInsets.all(5),
              borderRadius: BorderRadius.circular(4),
              elevation: 0,
            ),
            child: Text(
              'AuditBot',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            )),
        const Spacer(flex: 3),
        badges.Badge(
            position: badges.BadgePosition.topEnd(top: -2, end: -30),
            showBadge: true,
            ignorePointer: false,
            onTap: () {},
            badgeContent:
                const Icon(Icons.check, color: Colors.white, size: 10),
            badgeAnimation: const badges.BadgeAnimation.rotation(
              animationDuration: Duration(seconds: 1),
              colorChangeAnimationDuration: Duration(seconds: 1),
              loopAnimation: false,
              curve: Curves.fastOutSlowIn,
              colorChangeAnimationCurve: Curves.easeInCubic,
            ),
            badgeStyle: badges.BadgeStyle(
              shape: badges.BadgeShape.square,
              badgeColor: Colors.green,
              padding: const EdgeInsets.all(5),
              borderRadius: BorderRadius.circular(4),
              elevation: 0,
            ),
            child: RichText(
                text: TextSpan(
              style: const TextStyle(fontSize: 18),
              children: <TextSpan>[
                TextSpan(
                    text: 'Powered by Dhali',
                    style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launcher.launchUrl(Uri.parse(
                            "https://dhali-app.web.app/#/assets/d14a01e78-cced-470d-915a-64d194c1c830"));
                      }),
              ],
            ))),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget getWalletScaffoldBody() {
    return Column(children: [
      const Spacer(flex: 1),
      Expanded(child: getHeader(), flex: 3),
      const Spacer(flex: 10),
      Expanded(child: getAnimatedText('Please activate your wallet'), flex: 10),
    ]);
  }

  void updateSnackBar({String? message, SnackBarTypes? snackBarType}) {
    SnackBar snackbar;
    if (snackBarType == SnackBarTypes.error) {
      snackbar = SnackBar(
        backgroundColor: Colors.red,
        content: Text(message == null
            ? 'An unknown error occured. Please wait 30 seconds and try again.'
            : message),
        duration: const Duration(seconds: 3),
      );
    } else if (snackBarType == SnackBarTypes.inProgress) {
      snackbar = SnackBar(
        backgroundColor: Colors.blue,
        content: Text(message != null
            ? message
            : 'Inference in progress. Please wait...'),
        duration: Duration(seconds: 3),
      );
    } else if (snackBarType == SnackBarTypes.success) {
      snackbar = const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Success'),
        duration: Duration(seconds: 3),
      );
    } else {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(snackbar);
  }

  void activateWallet() {
    setState(() {
      _showContinueButton = true;
    });
  }

  void switchToProductView() {
    setState(() {
      this.drawerIndex = DrawerIndex.Product;
      if (_wallet != null) {
        screenView = getInferenceScaffoldBody();
      } else {
        screenView = null;
      }
      _showContinueButton = false;
    });
  }

  Widget? getScreenView(drawerIndex) {
    Future(() => ScaffoldMessenger.of(context).hideCurrentSnackBar());

    switch (drawerIndex) {
      case DrawerIndex.Wallet:
        setState(() {
          this.drawerIndex = drawerIndex;
          SnackBar snackbar;
          snackbar = const SnackBar(
            backgroundColor: Colors.red,
            content:
                Text("Dhali is currently in alpha and uses test XRP only!"),
            duration: Duration(days: 1),
          );

          Future(() => ScaffoldMessenger.of(context).showSnackBar(snackbar));

          screenView = Scaffold(
            body: Stack(
              children: [
                WalletHomeScreen(
                  title: "wallet",
                  buttonsColor: Colors.blue,
                  bodyTextColor: Colors.white,
                  getWallet: () {
                    return _wallet;
                  },
                  setWallet: (DhaliWallet? wallet) {
                    _wallet = wallet;
                  },
                  onActivation: activateWallet,
                ),
                if (_showContinueButton)
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton.extended(
                        label: Text('Continue'),
                        onPressed: switchToProductView,
                      ),
                    ),
                  ),
              ],
            ),
          );
        });
        break;
      case DrawerIndex.Product:
        switchToProductView();
        break;
      default:
        break;
    }
    return screenView;
  }
}

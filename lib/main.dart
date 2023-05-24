import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:web_audio';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:badges/badges.dart' as badges;
import 'package:consumer_application/accents_dropdown.dart';
import 'package:consumer_application/download_file_widget.dart';
import 'package:consumer_application/sentence_list_widget.dart';
import 'package:dhali_wallet/dhali_wallet_widget.dart';
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
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TextInputScreen(),
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
  @override
  TextInputScreenState createState() => TextInputScreenState();
}

class TextInputScreenState extends State<TextInputScreen> {
  List<Pair<String, bool>> sentences = [
    Pair("What is the title?", true),
    Pair("What is the total cost?", true),
    Pair("What is the reference number?", true)
  ];
  String dhaliDebit = "0";
  double progress = 0;
  String answer = "";
  String confidence = "";
  String outputCsv = "";
  bool complete = false;
  Widget? screenView;
  DrawerIndex? drawerIndex;

  List<PlatformFile> images = [];
  DhaliWallet? _wallet;
  bool hideMnemonic = true;
  String _endPoint =
      "https://dhali-prod-run-dauenf0n.uc.gateway.dev/d14a01e78-cced-470d-915a-64d194c1c830/run";
  Client client = Client('wss://s.altnet.rippletest.net:51233');
  ValueNotifier<String?> balance = ValueNotifier(null);
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
          const Text(
            "3. Run",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
        ],
      ),
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
              final dataUri = 'data:text/plain;charset=utf-8,$outputCsv';
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
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        if (_wallet == null) {
          updateSnackBar(
              message: "Please activate your wallet",
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
        setState(() {
          complete = false;
          progress = 0.1;
        });
        for (var image in images) {
          outputCsv += "${image.name}, ";
          for (var question in sentences) {
            try {
              if (question.string == "" || question.flag == false) {
                continue;
              }
              String dest =
                  "rstbSTpPcyxMsiXwkBxS9tFTrg2JsDNxWk"; // Dhali's address
              var openChannels = await _wallet!
                  .getOpenPaymentChannels(destination_address: dest);
              String amount;
              String authAmount; // The amount to authorise for the claim
              if (openChannels.isNotEmpty) {
                amount = openChannels.first.amount.toString();
              } else {
                amount = (double.parse(_wallet!.balance.value!) * 1000000 ~/ 2)
                    .toString(); // The total amount escrowed in the channel
                openChannels = [
                  await _wallet!.openPaymentChannel(dest, amount)
                ];
              }
              authAmount = amount;
              Map<String, String> paymentClaim = _wallet!.preparePayment(
                  destinationAddress: dest,
                  authAmount: authAmount,
                  channelId: openChannels[0].channelId);

              Map<String, String> header = {
                "Payment-Claim": const JsonEncoder().convert(paymentClaim)
              };
              String entryPointUrlRoot = _endPoint;

              var request =
                  http.MultipartRequest("PUT", Uri.parse(entryPointUrlRoot));
              request.headers.addAll(header);

              var logger = Logger();
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
                print(response["results"]);
                outputCsv += (response["results"][0]["answer"] + ", ");
                outputCsv +=
                    ((response["results"][0]["score"] as double).toString() +
                        ", ");
              } else {
                updateSnackBar(
                    message: response.toString(),
                    snackBarType: SnackBarTypes.error);
                outputCsv += ("ERROR, 0, ");
              }
            } catch (e) {
              outputCsv += ("ERROR, 0, ");
            }
            setState(() {
              progress += 1;
            });
          }
          outputCsv += "\n";
        }

        setState(() {
          complete = true;
        });

        updateSnackBar(snackBarType: SnackBarTypes.success);
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
      snackbar = const SnackBar(
        backgroundColor: Colors.blue,
        content: Text('Inference in progress. Please wait...'),
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
          screenView = WalletHomeScreen(
            title: "wallet",
            buttonsColor: Colors.blue,
            bodyTextColor: Colors.white,
            getWallet: () {
              return _wallet;
            },
            setWallet: (DhaliWallet wallet) {
              _wallet = wallet;
            },
          );
        });
        break;
      case DrawerIndex.Product:
        setState(() {
          this.drawerIndex = drawerIndex;
          if (_wallet != null) {
            screenView = getInferenceScaffoldBody();
          } else {
            screenView = null;
          }
        });
        break;
      default:
        break;
    }
    return screenView;
  }
}

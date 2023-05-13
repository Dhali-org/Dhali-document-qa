import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'dart:html' as html;

class DownloadFileWidget extends StatefulWidget {
  const DownloadFileWidget(
      {super.key, required this.bytes, required this.filename});
  final List<int> bytes;
  final String filename;

  @override
  State<DownloadFileWidget> createState() => _DownloadFileWidgetState();
}

class _DownloadFileWidgetState extends State<DownloadFileWidget> {
  List<int>? bytes;
  @override
  Widget build(BuildContext context) {
    return Container(
        child: Center(
      child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              backgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4))),
          onPressed: () async {
            final dataUri =
                'data:text/plain;base64,${base64.encode(this.bytes!)}';
            html.document.createElement('a') as html.AnchorElement
              ..href = dataUri
              ..download = 'output.txt'
              ..dispatchEvent(html.Event.eventType('MouseEvent', 'click'));
          },
          icon: const Icon(
            Icons.download,
            size: 32,
          ),
          label: Text(
            "Download",
            style: TextStyle(fontSize: 30),
          )),
    ));
  }
}

Uint8List getWavBytes(Float32List data, int sampleRate) {
  var channels = 1;

  final intArray =
      data.map((value) => (value * 32767.0).toInt().toSigned(16)).toList();
  final byteData =
      Uint8List.fromList(Int16List.fromList(intArray).buffer.asUint8List());

  int byteRate = ((16 * sampleRate * channels) / 8).round();

  int size = data.lengthInBytes;

  int fileSize = size + 36;

  Uint8List wav = Uint8List.fromList([
    // "RIFF"
    82, 73, 70, 70,
    fileSize & 0xff,
    (fileSize >> 8) & 0xff,
    (fileSize >> 16) & 0xff,
    (fileSize >> 24) & 0xff,
    // WAVE
    87, 65, 86, 69,
    // fmt
    102, 109, 116, 32,
    // fmt chunk size 16
    16, 0, 0, 0,
    // Type of format
    1, 0,
    // One channel
    channels, 0,
    // Sample rate
    sampleRate & 0xff,
    (sampleRate >> 8) & 0xff,
    (sampleRate >> 16) & 0xff,
    (sampleRate >> 24) & 0xff,
    // Byte rate
    byteRate & 0xff,
    (byteRate >> 8) & 0xff,
    (byteRate >> 16) & 0xff,
    (byteRate >> 24) & 0xff,
    // Uhm
    ((16 * channels) / 8).round(), 0,
    // bitsize
    16, 0,
    // "data"
    100, 97, 116, 97,
    size & 0xff,
    (size >> 8) & 0xff,
    (size >> 16) & 0xff,
    (size >> 24) & 0xff,
    ...byteData
  ]);

  return wav;
}

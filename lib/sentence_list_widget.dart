import 'package:flutter/material.dart';

class Pair<T1, T2> {
  T1 string;
  T2 flag;

  Pair(this.string, this.flag);
}

class SentenceListWidget extends StatefulWidget {
  const SentenceListWidget(
      {required this.setSentences, required this.getSentences});

  final void Function(List<Pair<String, bool>>) setSentences;
  final List<Pair<String, bool>> Function() getSentences;

  @override
  _SentenceListWidgetState createState() => _SentenceListWidgetState();
}

class _SentenceListWidgetState extends State<SentenceListWidget> {
  TextEditingController textController = TextEditingController();
  final ScrollController _firstController = ScrollController();

  @override
  Widget build(BuildContext context) {
    List<Pair<String, bool>> sentences = widget.getSentences();
    return Container(
        height: MediaQuery.of(context).size.height / 4,
        width: 4 * MediaQuery.of(context).size.width / 5,
        child: Column(
          children: <Widget>[
            Expanded(
              child: Scrollbar(
                  controller: _firstController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _firstController,
                    itemCount: sentences.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                          title: Text(sentences[index].string),
                          leading: Checkbox(
                            value: sentences[index].flag,
                            onChanged: (value) {
                              setState(() {
                                sentences[index].flag = value!;
                              });
                            },
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                sentences.removeAt(index);
                                widget.setSentences(sentences);
                              });
                            },
                          ));
                    },
                  )),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: textController,
                    decoration: InputDecoration(
                      labelText: 'Add a new question',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.check),
                  onPressed: () {
                    if (textController.text.isNotEmpty) {
                      setState(() {
                        Pair<String, bool> sentence =
                            Pair(textController.text, true);
                        sentences.add(sentence);
                        widget.setSentences(sentences);
                        textController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ));
  }
}

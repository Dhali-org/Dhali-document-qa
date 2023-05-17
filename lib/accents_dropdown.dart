import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class DropdownAccentButton extends StatefulWidget {
  const DropdownAccentButton(
      {super.key, required this.setValue, required this.options});

  final void Function(String) setValue;
  final Map<String, int> options;

  @override
  State<DropdownAccentButton> createState() => _DropdownAccentButtonState();
}

class _DropdownAccentButtonState extends State<DropdownAccentButton> {
  _DropdownAccentButtonState();
  String? dropdownValue;

  @override
  void initState() {
    super.initState();
    dropdownValue = widget.options.entries.first.key;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      isExpanded: true,
      value: dropdownValue,
      icon: const Icon(Icons.arrow_downward),
      elevation: 16,
      style: const TextStyle(color: Colors.white),
      // underline: Container(
      //   height: 2,
      //   color: Colors.white,
      // ),
      onChanged: (String? value) {
        // This is called when the user selects an item.
        setState(() {
          dropdownValue = value!;
        });
        widget.setValue(dropdownValue!);
      },
      items: widget.options.keys.map<DropdownMenuItem<String>>((String key) {
        return DropdownMenuItem<String>(
          value: key,
          child: Text(key),
        );
      }).toList(),
    );
  }
}

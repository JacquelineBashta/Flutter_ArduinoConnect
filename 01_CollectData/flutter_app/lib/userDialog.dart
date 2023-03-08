import 'package:flutter/material.dart';
import 'package:flow_draw/utils.dart';

class DisplayUserDialog extends StatefulWidget {

  @override
  _DisplayUserDialogState createState() => _DisplayUserDialogState();

  // The callback function with data you want to return -------|
  final Function(bool confirmed) onConfirm;
  String valueText;
  String infoText;

  DisplayUserDialog({
    Key? key,
    required this.valueText,
    required this.infoText,
    required this.onConfirm,
  }) : super(key: key);
}

class _DisplayUserDialogState extends State<DisplayUserDialog> {
  TextEditingController _textFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textFieldController = TextEditingController(text: widget.valueText);

  }

  @override
  Widget build(BuildContext context) {
    return
      AlertDialog(
        title: const Text('Enter CSV name'),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  value = widget.valueText; // Text field will overwrite user input
                });
              },
              controller: _textFieldController,
            ),

            const SizedBox(height: 10),

            Text(widget.infoText),
          ],
        ),

        actions: <Widget>[
          ElevatedButton(
            child: const Text('cancel'),
            onPressed: () {
                widget.onConfirm(false);
                Navigator.pop(context);
            },
          ),
          ElevatedButton(
            child: const Text('confirm'),
            onPressed: () {
              // Call the function here to pass back the value
              widget.onConfirm(true);
              Navigator.pop(context);
              },
          ),

        ],
      );
  }
}


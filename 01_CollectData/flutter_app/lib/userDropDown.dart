import 'package:flutter/material.dart';
import 'package:flow_draw/utils.dart';

class DisplayUserDropDown extends StatefulWidget {
  @override
  _DisplayUserDropDownState createState() => _DisplayUserDropDownState();

  final Function(String csvName) onChanged;

  const DisplayUserDropDown({
    Key? key,
    required this.onChanged,
  }) : super(key: key);
}

class _DisplayUserDropDownState extends State<DisplayUserDropDown> {
  late List<String> recordsNameList;
  late String selectedDropDown;


  void updateState(){
    recordsNameList = [];
    selectedDropDown = "";

    getRecordLists("").then((List<String> result) {
      setState(() {
        recordsNameList = result;
        selectedDropDown = recordsNameList.first;
        widget.onChanged(selectedDropDown);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    updateState();
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedDropDown,
      items: recordsNameList.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          selectedDropDown = newValue!;
          widget.onChanged(newValue);
        });
      },
    );
  }
}

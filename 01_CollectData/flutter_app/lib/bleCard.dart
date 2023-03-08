import 'package:flutter/material.dart';
import 'package:path/path.dart';

class BleCard extends StatefulWidget {

  BleCard({
    Key? key,
    required this.onConnect,
    required this.onDisconnect,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.icon,
    required this.color
  }) : super(key: key);

  Text title;
  Text subtitle;
  Text note;
  Icon icon;
  Color color;

  @override
  State<BleCard> createState() => _BleCardState();

  final Function(String deviceID) onConnect;
  final Function(String deviceID) onDisconnect;


}

class _BleCardState extends State<BleCard> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Card(
              color: widget.color,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: widget.icon,
                    title: widget.title,
                    subtitle: constraints.maxWidth >= 700 ? widget.subtitle : null,
                    trailing: constraints.maxWidth >= 700 ? widget.note : null,

                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        child: const Text('Connect'),
                        onPressed: () {
                          widget.onConnect(widget.subtitle.data.toString());
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        child: const Text('Disconnect'),
                        onPressed: () {
                          widget.onDisconnect(widget.subtitle.data.toString());
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
}

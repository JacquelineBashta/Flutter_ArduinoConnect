import 'package:flutter/material.dart';

class IconCard extends StatelessWidget {
  IconCard(
      {super.key, required this.title, required this.subtitle, required this.icon, required this.color});

  Text title;
  Text subtitle;
  Icon icon;
  Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: icon,
              title: title,
              subtitle: subtitle,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  child: Text('Connect'),
                  onPressed: () {/* ... */},
                ),
                const SizedBox(width: 8),
                TextButton(
                  child: Text('Disconnect'),
                  onPressed: () {/* ... */},
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),

      ),
    );
  }
}

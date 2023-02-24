import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flow_draw/ble.dart';

void main() {
  runApp(MaterialApp(
    title: 'Flow Draw',
    theme: ThemeData(
      useMaterial3: true,
    ),
    home: MyHomePage(),
  ),
  );
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var current = WordPair.random();
  var favorites = <WordPair>[];
  var selectedIndex = 0;

  void getNext() {
    setState(() {
      current = WordPair.random();
    });
  }

  void toggleFavorite() {
    setState(() {
      if (favorites.contains(current)) {
        favorites.remove(current);
      } else {
        favorites.add(current);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = BluetoothPage();
        break;
      case 1:
        page = GeneratorPage(appState: this);
        break;
      case 2:
        page = FavoritesPage(appState: this);
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: Text("Flow Draw"),
            centerTitle: true,
            backgroundColor: Colors.orangeAccent[100],
          ),
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 1200,
                  backgroundColor: Colors.orangeAccent[100],
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.bluetooth),
                      label: Text('Bluetooth'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.smart_toy),
                      label: Text('Words'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text('Favorites'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  child: page,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class GeneratorPage extends StatelessWidget {
  final _MyHomePageState appState;
  GeneratorPage({required this.appState });

  @override
  Widget build(BuildContext context) {
    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Expanded(
                flex: 1,
                child: Image(
                  image: NetworkImage("https://cdn-icons-png.flaticon.com/512/1006/1006771.png"),
                  height: 100,
                  width: 100,
                ),
              ),
              Expanded(
                flex: 1,
                child: Image(
                  image: AssetImage("assets/img1.png"),
                  height: 100,
                  width: 100,
                ),
              ),
            ],
          ),
          BigCard(pair: pair),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: const Text('Like'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  final _MyHomePageState appState;
  FavoritesPage({required this.appState });

  @override
  Widget build(BuildContext context) {
    if (appState.favorites.isEmpty) {
      return const Center(
        child: Text('No favorites yet.'),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have '
              '${appState.favorites.length} favorites:'),
        ),
        for (var pair in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(pair.asLowerCase),
          ),
      ],
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
      fontFamily: 'IndieFlower'
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: pair.asPascalCase,
        ),
      ),
    );
  }
}
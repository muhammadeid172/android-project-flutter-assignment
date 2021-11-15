import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart'; // Add this line.
import 'package:provider/provider.dart';
import 'package:hello_me/app_user.dart';




void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
                body: Center(
                    child: Text(snapshot.error.toString(),
                        textDirection: TextDirection.ltr)));
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return MyApp();
          }
          return Center(child: CircularProgressIndicator());
        },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppUser(),
      child: Consumer<AppUser>(
        builder: (context, appUser, _) => MaterialApp(
        title: 'Startup Name Generator',
        initialRoute: '/',
        routes: {
          '/': (context) => const RandomWords(),
          '/login': (context) => const LoginRoute(),
        },
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          primaryColor: Colors.deepPurple,
        ),
      ),
      ),
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _saved = <WordPair>[];
  final _biggerFont = const TextStyle(fontSize: 18);
  var user;

  @override
  Widget build(BuildContext context) {
    user = Provider.of<AppUser>(context);
    var authIcon = user.status == Status.authenticated ? const Icon(Icons.exit_to_app) : const Icon(Icons.login);
    var authIconFunction = user.status == Status.authenticated ?
          (() async {
            await user.signOut();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully logged out')));
          })
        :
          (() => Navigator.pushNamed(context, '/login'));
    var tooltip = user.status == Status.authenticated ? 'Logout' : 'Login';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(icon: const Icon(Icons.star), onPressed: _pushSaved, tooltip: 'Saved Suggestions'),
          IconButton(icon: authIcon, onPressed: authIconFunction, tooltip: tooltip),
        ],
      ),
      body: _buildSuggestions(),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext _context, int i) {
          if (i.isOdd) {
            return const Divider();
          }

          final int index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        });
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = user.starred.contains(pair);
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: IconButton(
          icon: Icon(
            alreadySaved ? Icons.star : Icons.star_border,
            color: alreadySaved ? Colors.deepPurple : null,
            semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
          ),
          onPressed: () async {
            if (alreadySaved) {
              await user.removePair(pair.first, pair.second);
            } else {
              await user.addPair(pair.first, pair.second);
            }
          },
      ),
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          var favorites = _saved;//idk
          favorites = user.starred;
          final tiles = favorites.map(
            (pair) {
              return ListTile(
                title: Text(
                  pair.asPascalCase,
                  style: _biggerFont,
                ),
              );
            },
          );
          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
                  context: context,
                  tiles: tiles,
                ).toList()
              : <Widget>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView.builder(
              itemCount: divided.length,
              itemBuilder: (context, index) {
                var pair = user.starred.toList()[index];
                return Dismissible(
                  key: UniqueKey(),
                  child: divided[index],
                  onDismissed: (dir) async {
                      await user.removePair(pair.first, pair.second);
                  },
                  confirmDismiss: (dir) async {
                    // var decision = false;
                    // // show the dialog
                    // showDialog(
                    //   context: context,
                    //   builder: (BuildContext context) {
                    //     return AlertDialog(
                    //       title: Text("Delete Suggesion"),
                    //       content: Text("Are you sure you want to delete $name from your saved suggestions?"),
                    //       actions: [
                    //         TextButton(child: const Text("Yes"), onPressed: () { decision = true; Navigator.of(context).pop();},),
                    //         TextButton(child: const Text("No"), onPressed: () { decision = false; Navigator.of(context).pop();},)
                    //       ],
                    //     );
                    //   },
                    // );
                    return await getDecision(pair);
                  },
                  background: Container(
                    child: Row(
                      children: const [
                        Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                        Text(
                          'Delete Suggestion',
                          style: TextStyle(color: Colors.white, fontSize: 17),
                        )
                      ],
                    ),
                    color: Colors.deepPurple,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<bool> getDecision (WordPair name) async {
    bool decision = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Suggestion"),
          content: Text("Are you sure you want to delete ${name.asPascalCase} from your saved suggestions?"),
          actions: [
            TextButton(child: const Text("Yes"), onPressed: () { decision = true; Navigator.of(context).pop();}, style: TextButton.styleFrom(primary: Colors.white, backgroundColor: Colors.deepPurple),),
            TextButton(child: const Text("No"), onPressed: () { decision = false; Navigator.of(context).pop();}, style: TextButton.styleFrom(primary: Colors.white, backgroundColor: Colors.deepPurple),)
          ],
        );
      },
    );
    return decision;
  }
}

class LoginRoute extends StatefulWidget {
  const LoginRoute({Key? key}) : super(key: key);

  @override
  _LoginRouteState createState() => _LoginRouteState();
}

class _LoginRouteState extends State<LoginRoute> {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser>(context);
    TextEditingController _email = TextEditingController(text: "");
    TextEditingController _password = TextEditingController(text: "");

    var logInButton = user.status == Status.authenticating ? const Center(child: CircularProgressIndicator())
      : MaterialButton(
          onPressed: () async {
            if(!await user.signIn(_email.text, _password.text)){
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('There was an error logging into the app')));
            }else {
              Navigator.pop(context);
            }
          },
          color: Colors.deepPurple,
          elevation: 5.0,
          child: const Text('Log in', style: TextStyle(fontSize: 20, color: Colors.white)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Column(children: <Widget>[
        const Padding(
            padding: EdgeInsets.all(25.0),
            child: (Text(
              'Welcome to Startup Names Generator, please log in below',
              style: TextStyle(
                fontSize: 17,
              ),
            ))),
        const SizedBox(height: 40),
        TextField(
          controller: _email,
          obscureText: false,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Email',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Password',
          ),
        ),
        const SizedBox(height: 40),
        logInButton,
      ]),
    );
  }
}


import 'dart:ui' as ui;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart'; // Add this line.
import 'package:provider/provider.dart';
import 'package:hello_me/app_user.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

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
      create: (_) => AppUser.instance(),
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
  var canDrag = true;
  SnappingSheetController sheetController = SnappingSheetController();
  final _biggerFont = const TextStyle(fontSize: 18);
  var user;

  @override
  Widget build(BuildContext context) {
    user = Provider.of<AppUser>(context);
    var authIcon = user.status == Status.authenticated
        ? const Icon(Icons.exit_to_app)
        : const Icon(Icons.login);
    var authIconFunction = user.status == Status.authenticated
        ? (() async {
            sheetController.snapToPosition(
                const SnappingPosition.factor(positionFactor: 0.083));
            canDrag = false;
            await user.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Successfully logged out')));
          })
        : (() => Navigator.pushNamed(context, '/login'));
    var tooltip = user.status == Status.authenticated ? 'Logout' : 'Login';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
              icon: const Icon(Icons.star),
              onPressed: _pushSaved,
              tooltip: 'Saved Suggestions'),
          IconButton(
              icon: authIcon, onPressed: authIconFunction, tooltip: tooltip),
        ],
      ),
      body: GestureDetector(
          child: SnappingSheet(
            controller: sheetController,
            snappingPositions: const [
              SnappingPosition.pixels(
                  positionPixels: 190,
                  snappingCurve: Curves.bounceOut,
                  snappingDuration: Duration(milliseconds: 350)),
              SnappingPosition.factor(
                  positionFactor: 1.0,
                  snappingCurve: Curves.easeInBack,
                  snappingDuration: Duration(milliseconds: 1)),
            ],
            lockOverflowDrag: true,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildSuggestions(),
                BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 5,
                    sigmaY: 5,
                  ),
                  child: canDrag && user.status == Status.authenticated ? Container(
                    color: Colors.transparent,
                  ) : null,
                )
              ],
            ),
            sheetBelow: user.status == Status.authenticated
                ? SnappingSheetContent(
                    draggable: canDrag,
                    child: Container(
                      color: Colors.white,
                      child: ListView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            Column(children: [
                              Row(children: <Widget>[
                                Expanded(
                                  child: Container(
                                    color: Colors.black12,
                                    height: 60,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Flexible(
                                            flex: 3,
                                            child: Center(
                                              child: Text(
                                                  "Welcome back, " +
                                                      user.getUserEmail(),
                                                  style: const TextStyle(
                                                      fontSize: 16.0)),
                                            )),
                                        const IconButton(
                                          icon: Icon(Icons.keyboard_arrow_up),
                                          onPressed: null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                              const Padding(padding: EdgeInsets.all(8)),
                              Row(children: <Widget>[
                                const Padding(padding: EdgeInsets.all(8)),
                                FutureBuilder(
                                  future: user.getImageUrl(),
                                  builder: (BuildContext context,
                                      AsyncSnapshot<String> snapshot) {
                                    return CircleAvatar(
                                      radius: 50.0,
                                      backgroundImage: snapshot.data != null
                                          ? NetworkImage(snapshot.data ??
                                              "") //muask might be null
                                          : null,
                                    );
                                  },
                                ),
                                const Padding(padding: EdgeInsets.all(10)),
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(user.getUserEmail(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.normal,
                                              fontSize: 20)),
                                      const Padding(padding: EdgeInsets.all(3)),
                                      MaterialButton(//Change avatar button
                                        onPressed: () async {
                                          FilePickerResult? result =
                                              await FilePicker.platform
                                                  .pickFiles(
                                            type: FileType.custom,
                                            allowedExtensions: [
                                              'png',
                                              'jpg',
                                              'gif',
                                              'bmp',
                                              'jpeg',
                                              'webp'
                                            ],
                                          );
                                          File file;
                                          if (result != null) {
                                            file = File(
                                                result.files.single.path ?? "");
                                            user.uploadNewImage(file);
                                          } else {
                                            // User canceled the picker
                                          }
                                        },
                                        textColor: Colors.white,
                                        padding: const EdgeInsets.only(
                                            left: 5.0,
                                            top: 3.0,
                                            bottom: 5.0,
                                            right: 8.0),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: <Color>[
                                                Colors.deepPurple,
                                                Colors.blueAccent,
                                              ],
                                            ),
                                          ),
                                          padding: const EdgeInsets.fromLTRB(15, 7, 15, 7),
                                          child: const Text('Change Avatar',
                                              style: TextStyle(fontSize: 15)),
                                        ),
                                      ),
                                    ])
                              ]),
                            ]),
                          ]),
                    ),
                    //heightBehavior: SnappingSheetHeight.fit(),
                  )
                : null,
          ),
          onTap: () => {
                setState(() {
                  if (canDrag == false) {
                    canDrag = true;
                    sheetController
                        .snapToPosition(const SnappingPosition.factor(
                      positionFactor: 0.265,
                    ));
                  } else {
                    canDrag = false;
                    sheetController.snapToPosition(
                        const SnappingPosition.factor(
                            positionFactor: 0.083,
                            snappingCurve: Curves.easeInBack,
                            snappingDuration: Duration(milliseconds: 1)));
                  }
                })
              }),
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
          var favorites = _saved; //idk
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

  Future<bool> getDecision(WordPair name) async {
    bool decision = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Suggestion"),
          content: Text(
              "Are you sure you want to delete ${name.asPascalCase} from your saved suggestions?"),
          actions: [
            TextButton(
              child: const Text("Yes"),
              onPressed: () {
                decision = true;
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                  primary: Colors.white, backgroundColor: Colors.deepPurple),
            ),
            TextButton(
              child: const Text("No"),
              onPressed: () {
                decision = false;
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                  primary: Colors.white, backgroundColor: Colors.deepPurple),
            )
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
    var _validate = true;
    TextEditingController _email = TextEditingController(text: "");
    TextEditingController _password = TextEditingController(text: "");
    TextEditingController _confirm = TextEditingController(text: "");

    var logInButton = user.status == Status.authenticating
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(8.0),
            child: ButtonTheme(
              minWidth: 300.0,
              height: 35.0,
              child: RaisedButton(
                color: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                    side: BorderSide(color: Colors.deepPurple)),
                onPressed: () async {
                  if (!await user.signIn(_email.text, _password.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('There was an error logging into the app')));
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text('Log in',
                    style: TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ),
          );

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ButtonTheme(
            minWidth: 300.0,
            height: 35.0,
            child: RaisedButton(
              color: Colors.blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0),
                  side: BorderSide(color: Colors.blue)),
              onPressed: () async {
                //
                // contexts = context;
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return AnimatedPadding(
                      padding: MediaQuery.of(context).viewInsets,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.decelerate,
                      child: Container(
                        height: 200,
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text('Please confirm your password below:'),
                              const SizedBox(height: 20),
                              Container(
                                width: 350,
                                child: TextField(
                                  controller: _confirm,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Password',
                                    errorText: _validate
                                        ? null
                                        : 'Passwords must match',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ButtonTheme(
                                minWidth: 350.0,
                                height: 50,
                                child: MaterialButton(
                                    color: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18.0),
                                        side: BorderSide(color: Colors.blue)),
                                    child: Text(
                                      'Confirm',
                                      style: TextStyle(
                                          fontSize: 17, color: Colors.white),
                                    ),
                                    onPressed: () async {
                                      if (_confirm.text == _password.text) {
                                        //do that
                                        // await user.signOut();
                                        user.signUp(
                                            _email.text, _password.text);
                                        //await user.signIn(_email.text, _password.text);
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                      } else {
                                        setState(() {
                                          _validate = false;
                                          FocusScope.of(context)
                                              .requestFocus(FocusNode());
                                        });
                                      }
                                    }),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
                //
                //Navigator.pop(context);
              },
              child: Text('New user? Click to sign up',
                  style: TextStyle(fontSize: 20, color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}

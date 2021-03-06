import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

enum Status { authenticated, authenticating, unauthenticated }

class AppUser with ChangeNotifier{
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth;// = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  Status status = Status.unauthenticated;
  List<WordPair> starred = [];


  AppUser.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(authChangeListenerReaction);
  }
  Future<void> authChangeListenerReaction(User? firebaseUser) async {           //Is this needed? muask
    if (firebaseUser == null) {
      status = Status.unauthenticated;
      starred = [];
      notifyListeners();
    } else {
      starred = await getStarredWordsFromCloud();
      status = Status.authenticated;
      notifyListeners();
    }
  }


  Future<bool> signIn(String email, String password) async{
    try{
      status = Status.authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await uploadLocallyStarredSavings();//note that these starred are just locally starred SO FAR.
      starred = await getStarredWordsFromCloud();
      status = Status.authenticated;
      notifyListeners();
      return true;
    }catch(e){
      status = Status.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async{
    await _auth.signOut();
    status = Status.unauthenticated;
    starred = [];
    notifyListeners();
  }

  /*
  * - If there is a signed-in user, returns a Future of a List that contains his
  * backup words from the cloud.
  * - If no user is signed in, returns a Future of an empty List
  * */
  Future<List<WordPair>> getStarredWordsFromCloud() async {
    final res = <WordPair>[];
    try {
      var receivedFromCloud = await _db.collection("Users").doc("StarredWords").get();
      await receivedFromCloud[_auth.currentUser?.uid ?? ""].forEach((element) async { //muask not sure if should be awaited
        String firstWord = await  element["first"];
        String secondWord = await element["second"];
        res.add(WordPair(firstWord, secondWord));
      });
    }catch(e){
      //In case this user does not have any starred words in the cloud.
      //or if the user didn't sign-in.
      return Future<List<WordPair>>.value([]);
    }
    return Future<List<WordPair>>.value(res);
  }

  Future<void> uploadLocallyStarredSavings() async {
    if (status == Status.authenticated || status == Status.authenticating) {
      var mappedList = starred.map((e) => {"first": e.first, "second": e.second}).toList();
      await _db.collection("Users").doc("StarredWords").update(
          {(_auth.currentUser?.uid ?? ""): FieldValue.arrayUnion(mappedList)});
    }
  }

  Future<void> addPair(String first, String second) async {
    starred.add(WordPair(first, second));
    notifyListeners();
/*    if((status == Status.authenticated && _auth.currentUser == null) || (status == Status.unauthenticated && _auth.currentUser != null)){
      //This if is for debugging
      print("THERE IS A PROBLEM");
    }*/
    if (status == Status.authenticated) {
      await _db.collection("Users").doc("StarredWords").update(
          {(_auth.currentUser?.uid ?? ""): FieldValue.arrayUnion([{"first": first, "second": second}])});
    }
  }

  Future<void> removePair(String first, String second) async {
    starred.remove(WordPair(first, second));
    notifyListeners();
/*    if((status == Status.authenticated && _auth.currentUser == null) || (status == Status.unauthenticated && _auth.currentUser != null)){
      //This if is for debugging
      print("THERE IS A PROBLEM");
    }*/
    if (status == Status.authenticated) {
      await _db.collection("Users").doc("StarredWords").update(
          {(_auth.currentUser?.uid ?? ""): FieldValue.arrayRemove([{"first": first, "second": second}])});
    }
  }

  String getUserEmail() {
    return _auth.currentUser?.email ?? "unknown@unknowndomain.com";
  }

  Future<UserCredential?> signUp(String email, String password) async {//muask might return null, but we assume it will succeed
    try {
      status = Status.authenticating;
      notifyListeners();
      var res =  await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await uploadLocallyStarredSavings();//note that these starred are just locally starred SO FAR.
      starred = await getStarredWordsFromCloud();
      var defaultProfilePicture = "https://firebasestorage.googleapis.com/v0/b/hellome-a7fe7.appspot.com/o/images%2F90X4fWTdrKTlxBZ1ggwRanKPj8P2?alt=media&token=f7704078-a3c4-4f16-ad83-73880fe82084";
      await _auth.currentUser?.updatePhotoURL(defaultProfilePicture);
      status = Status.authenticated;
      notifyListeners();
      return res;
    } catch (e) {
      status = Status.unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<void> uploadNewImage(File file) async {
    await _storage.ref('images').child(_auth.currentUser?.uid ?? "").putFile(file);
    var newPhotoURL = await _storage.ref('images').child(_auth.currentUser?.uid ?? "").getDownloadURL();
    await _auth.currentUser?.updatePhotoURL(newPhotoURL);
    notifyListeners();
  }

  Future<String>
  getImageUrl() async {
    var defaultProfilePicture = "https://firebasestorage.googleapis.com/v0/b/hellome-a7fe7.appspot.com/o/images%2F90X4fWTdrKTlxBZ1ggwRanKPj8P2?alt=media&token=f7704078-a3c4-4f16-ad83-73880fe82084";
    return _auth.currentUser?.photoURL ?? defaultProfilePicture;
  }

  User? getCurrentUser(){
    return _auth.currentUser;
  }

}
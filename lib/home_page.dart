import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_gate.dart';
import 'search.dart';
import 'watchlist.dart';
import 'news.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _signOut() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    //final userEmail = _auth.currentUser?.email ?? 'No user logged in';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
        title: const Text('StockTracker'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
          ],
          backgroundColor: const Color(0xFF5ce1e6), 
          bottom: const TabBar(
            labelColor: Colors.black,
            labelStyle: TextStyle(fontSize: 20),
            unselectedLabelColor: Colors.black,
            unselectedLabelStyle: TextStyle(fontSize: 15),
            indicatorColor: Colors.yellow,
            tabs: [
              Tab(text: "Search"),
              Tab(text: "Watchlist"),
              Tab(text: "News"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SearchPage(),
            WatchlistPage(),
            NewsPage()
          ],
        ),
       ),
    );
  }
}

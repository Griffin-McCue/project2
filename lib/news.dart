import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_gate.dart';
import 'stocks_api.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final user = FirebaseAuth.instance.currentUser;
  List<String> topics = [];
  List<NewsInfo> newsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getNews();
  }

  fetchWatchList() async {
    try {
      topics.clear();
       final snapshot = await FirebaseFirestore.instance
        .collection('watchlists')
        .where('user_id', isEqualTo: user!.uid)
        .get();

      for (var doc in snapshot.docs) {
        if (!(topics.contains(doc['companyName']))) {
          String companyName = doc['companyName'];
          topics.add(companyName);
        }
      }
    } catch (error) {
      print("Error fetching watchlist: $error");
    }
  }

  getNews() async {
    await fetchWatchList();
    if (topics.isEmpty) {
      topics.add("stocks");
      List<NewsInfo> results = await Stocks_Api.fetchNewsInformation(topics);
      setState(() {
        newsList = results;
        isLoading = false;
      });
      return;
    }
    setState(() {
      isLoading = true;
    });
    List<NewsInfo> results = await Stocks_Api.fetchNewsInformation(topics);
    setState(() {
      newsList = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: Text('Loading... Please wait...'));
    } else {
      return Scaffold(
        body: ListView.builder(
          itemCount: newsList.length,
          itemBuilder: (context, index) {
            final news = newsList[index];
            return Container(
              margin: const EdgeInsets.all(15.0),
              padding: const EdgeInsets.all(3.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10.0),
                    color: Colors.black, 
                    child: Text(
                      '${news.headline} [${news.author}]', 
                      style: TextStyle(
                        color: Colors.white, fontSize: 15
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(15.0),
                    color: const Color(0xFFd9d9d9), 
                    child: Text(
                      '(${news.date}) ${news.description}', 
                      style: TextStyle(
                        color: Colors.black, fontSize: 13
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        )
      );
    }
  }
}
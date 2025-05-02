import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'stocks_api.dart';
import 'news_info.dart';

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

  // Fetch user's watchlist topics from Firebase
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

  // Fetch news based on the watchlist topics
  getNews() async {
    await fetchWatchList();
    if (topics.isEmpty) {
      topics.add("stocks");  // Default topic if the watchlist is empty
    }

    // Fetch news information for the topics in the watchlist
    List<NewsInfo> results = await StocksApi.fetchNewsInformation(topics) ?? [];
    
    setState(() {
      newsList = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while fetching news
    if (isLoading) {
      return const Center(child: Text('Loading... Please wait...'));
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('News'),
        ),
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
                  // Headline Section
                  Container(
                    padding: const EdgeInsets.all(10.0),
                    color: Colors.black, 
                    child: Text(
                      '${news.headline} [${news.author}]', 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 15,
                      ),
                    ),
                  ),
                  // Description Section
                  Container(
                    padding: const EdgeInsets.all(15.0),
                    color: const Color(0xFFd9d9d9), 
                    child: Text(
                      '(${news.date}) ${news.description}', 
                      style: const TextStyle(
                        color: Colors.black, 
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }
}

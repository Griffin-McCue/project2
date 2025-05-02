import 'dart:convert';
import 'package:http/http.dart' as http;
import 'search.dart';

class StockResponse {
  final String stockSymbol;
  final String stockName;
  final double currentPrice;
  final List<chartData> chartInfo;

  StockResponse({
    required this.stockSymbol,
    required this.stockName,
    required this.currentPrice,
    required this.chartInfo,
  });
  @override
  String toString() {
    return 'StockResponse(stockSymbol: $stockSymbol, stockName: $stockName, currentPrice: $currentPrice, chartInfo: $chartInfo)';
  }
}

class chartData {
  final String date; 
  final double currentPrice; 
  chartData({
    required this.date, 
    required this.currentPrice,
  });
  @override
  String toString() {
    return 'chartData(date: $date, currentPrice: $currentPrice)';
  }
}

class NewsInfo {
  final String headline; 
  final String description; 
  final String author;
  final String date;
  NewsInfo({
    required this.headline, 
    required this.description,
    required this.author,
    required this.date
  });

  @override
  String toString() {
    return 'NewsInfo(headline: $headline, description: $description, author: $author, date: $date)';
  }
}

class Stocks_Api {
  static fetchStockInformation(String searchItem) async {
    StockResponse currentStock;
    dynamic profileData; 
    String API_KEY = "d04j5l9r01qspgm3bhl0d04j5l9r01qspgm3bhlg";
    String AV_KEY = "L9MLQNBDJ2PSO4Q1";
    try {
      final profile = await http.get(
        Uri.parse('https://finnhub.io/api/v1/stock/profile2?symbol=$searchItem&token=$API_KEY'),
      );
      if (profile.statusCode == 200) {
        profileData = json.decode(profile.body);
      }

      // From 1 month ago - Today
      final today = DateTime.now();
      final endDate = DateTime(today.year, today.month - 1, today.day - 1); 

      final timeSeries = await http.get(
        Uri.parse('https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$searchItem&outputsize=full&apikey=$AV_KEY'),
      );
      if (timeSeries.statusCode == 200) {
        final timeData = json.decode(timeSeries.body);
        print(timeData);
        List<chartData> currentChartInfo = [];
        final dailyInfo = timeData['Time Series (Daily)'] as Map<String, dynamic>;
        for (final day in dailyInfo.entries) {
          final date = DateTime.parse(day.key);
          if (date.isBefore(endDate)) {
            break;
          } else {
            final dayString = '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
            currentChartInfo.add(chartData(
              date: dayString,
              currentPrice: double.parse(day.value['4. close'])
            ));
          }
        }
        final price = currentChartInfo[0].currentPrice;
        currentChartInfo = currentChartInfo.reversed.toList();

        currentStock = StockResponse(
          stockSymbol: searchItem, 
          stockName: profileData['name'],
          currentPrice: price, 
          chartInfo: currentChartInfo,
        );

        return currentStock; 
      } else {
        throw Exception("Error pulling data with status code ${timeSeries.statusCode}");
      }

    } catch (error) {
      //throw Exception("Error loading stock information: $error");
      return null;
    }
  }

  static fetchNewsInformation(List<String> searchItems) async {
    String NEWS_KEY = "24a1d5be804d4acc9c1e50bbe06d46b4";
    List<NewsInfo> articles = [];

    try {
      String advancedSearchQuery = searchItems.map((item) {
         return '"$item"';
      }).join(' OR ');

      final news = await http.get(
        Uri.parse('https://newsapi.org/v2/everything?q=$advancedSearchQuery&sortBy=relevancy&language=en&apiKey=$NEWS_KEY'),
      );

      if (news.statusCode == 200) {
        final newsData = json.decode(news.body);
        print(newsData);
        final newsList = newsData['articles'] as List;

        for (var entry in newsList) {
          if (entry['description'] == null) continue;
          if (articles.length == 5) break;
          var source = entry['source'];
          String currentAuthor = source['name'];

          String currentDate = entry['publishedAt'];
          final date = DateTime.parse(currentDate);
          final dayString = '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

          NewsInfo newEntry = NewsInfo(
            headline: entry['title'],
            description: entry['description'],
            author: currentAuthor,
            date: dayString
          );
          articles.add(newEntry);
        }
        return articles;
      } else {
        throw Exception("Error pulling data with status code ${news.statusCode}");
      }
    } catch (error) {
      throw Exception("Error loading news information: $error");
    }
  }
}
      
/*{ source: {id: null, name: The Mainichi}, 
    author: https://www.facebook.com/themainichi/, 
    title: Amazon Japan ordered to pay 35M. yen for allowing listing of fakes, 
    description: TOKYO (Kyodo) -- A Japanese court on Friday ordered the Japanese unit of online retail giant Amazon.com Inc. to pay 35 million yen ($244,000) in damag, 
    url: https://mainichi.jp/english/articles/20250425/p2g/00m/0bu/047000c, 
    urlToImage: https://cdn.mainichi.jp/vol1/2025/04/25/20250425p2g00m0bu046000p/0c10.jpg?1, 
    publishedAt: 2025-04-26T04:39:02Z, 
    content: TOKYO (Kyodo) -- A Japanese court on Friday ordered the Japanese unit of 
            online retail giant Amazon.com Inc. to pay 35 million yen ($244,000) in damages 
            for failing to take measures to stop sellers f… [+1712 chars]}
*/
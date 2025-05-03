import 'dart:convert';
import 'package:http/http.dart' as http;
import 'news_info.dart';

class StockResponse {
  final String stockSymbol;
  final String stockName;
  final double currentPrice;
  final List<ChartData> chartInfo;

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

class ChartData {
  final String date;
  final double currentPrice;

  ChartData({
    required this.date,
    required this.currentPrice,
  });

  @override
  String toString() {
    return 'ChartData(date: $date, currentPrice: $currentPrice)';
  }
}

class SymbolSearchResult {
  final String symbol;
  final String description;

  SymbolSearchResult({required this.symbol, required this.description});

  factory SymbolSearchResult.fromJson(Map<String, dynamic> json) {
    return SymbolSearchResult(
      symbol: json['symbol'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class StocksApi {
  static const String API_KEY = "d0aksr9r01qm3l9m5q1gd0aksr9r01qm3l9m5q20"; // Your Finnhub API key

  // Fetch stock information (profile and chart)
  static Future<StockResponse?> fetchStockInformation(String searchItem) async {
    StockResponse? currentStock;
    dynamic profileData;

    try {
      final profile = await http.get(
        Uri.parse('https://finnhub.io/api/v1/stock/profile2?symbol=$searchItem&token=$API_KEY'),
      );

      if (profile.statusCode == 200) {
        profileData = json.decode(profile.body);
      } else {
        print("Error fetching stock profile: ${profile.statusCode} - ${profile.body}");
        throw Exception("Error fetching stock profile: ${profile.statusCode}");
      }

      final chart = await http.get(
        Uri.parse('https://finnhub.io/api/v1/stock/candle?symbol=$searchItem&resolution=D&from=1609459200&to=1650422400&token=$API_KEY'),
      );

      if (chart.statusCode == 200) {
        final chartData = json.decode(chart.body);
        List<ChartData> currentChartInfo = [];

        final timestamps = chartData['t'] as List;
        final closes = chartData['c'] as List;

        if (timestamps.isEmpty || closes.isEmpty) {
          print("No chart data returned for $searchItem");
        }

        for (int i = 0; i < timestamps.length; i++) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000);
          final dayString = '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
          currentChartInfo.add(ChartData(
            date: dayString,
            currentPrice: closes[i].toDouble(),
          ));
        }

        final price = currentChartInfo.isNotEmpty ? currentChartInfo[0].currentPrice : 0.0;

        currentStock = StockResponse(
          stockSymbol: searchItem,
          stockName: profileData['name'],
          currentPrice: price,
          chartInfo: currentChartInfo,
        );

        return currentStock;
      } else {
        print("Error fetching stock chart data: ${chart.statusCode} - ${chart.body}");
        throw Exception("Error fetching stock chart data: ${chart.statusCode}");
      }
    } catch (error) {
      print("Error loading stock information for $searchItem: $error");
      return null;
    }
  }

  // 🔍 Fetch stock news information based on topics
  static Future<List<NewsInfo>?> fetchNewsInformation(List<String> topics) async {
    List<NewsInfo> newsList = [];

    try {
      // Loop through each topic in the watchlist and fetch news for each topic
      for (String topic in topics) {
        final response = await http.get(
          Uri.parse('https://finnhub.io/api/v1/news?category=$topic&token=d0aksr9r01qm3l9m5q1gd0aksr9r01qm3l9m5q20'), // Replace with the actual news endpoint from Finnhub
        );

        if (response.statusCode == 200) {
          final newsData = json.decode(response.body);

          // Map the news data to NewsInfo objects
          for (var news in newsData) {
            newsList.add(NewsInfo(
              headline: news['headline'],
              author: news['author'],
              date: news['date'],
              description: news['description'],
            ));
          }
        } else {
          print("Error fetching news for topic '$topic': ${response.statusCode} - ${response.body}");
          throw Exception("Failed to load news data for topic '$topic'");
        }
      }

      return newsList;
    } catch (error) {
      print("Error fetching news information: $error");
      return null;
    }
  }
}
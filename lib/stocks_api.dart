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
  static const String ALPHA_VANTAGE_API_KEY = 'VGP9CB8312IVI1W8';

  // Fetch stock information using Alpha Vantage
  static Future<StockResponse?> fetchStockInformation(String searchItem) async {
    try {
      final url = Uri.parse(
        'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$searchItem&apikey=$ALPHA_VANTAGE_API_KEY',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        print('Error fetching stock data: ${response.statusCode} - ${response.body}');
        throw Exception('Error fetching stock data');
      }

      final data = json.decode(response.body);

      if (data['Time Series (Daily)'] == null) {
        print('Invalid response or symbol not found: ${data.toString()}');
        throw Exception('Invalid response from Alpha Vantage');
      }

      final timeSeries = data['Time Series (Daily)'] as Map<String, dynamic>;

      List<ChartData> chartInfo = [];
      for (var entry in timeSeries.entries.take(30)) {
        final date = entry.key;
        final dailyData = entry.value as Map<String, dynamic>;
        final close = double.tryParse(dailyData['4. close']) ?? 0.0;

        chartInfo.add(ChartData(
          date: date.substring(5), // MM-DD
          currentPrice: close,
        ));
      }

      final latestClose = chartInfo.isNotEmpty ? chartInfo.first.currentPrice : 0.0;

      return StockResponse(
        stockSymbol: searchItem,
        stockName: searchItem, // Alpha Vantage free API doesn't return full name
        currentPrice: latestClose,
        chartInfo: chartInfo,
      );
    } catch (e) {
      print('Error loading stock data for $searchItem: $e');
      return null;
    }
  }

  // Fetch news (still using Finnhub for now)
  static Future<List<NewsInfo>?> fetchNewsInformation(List<String> topics) async {
    List<NewsInfo> newsList = [];

    try {
      for (String topic in topics) {
        final response = await http.get(
          Uri.parse('https://finnhub.io/api/v1/news?category=$topic&token=d0aksr9r01qm3l9m5q1gd0aksr9r01qm3l9m5q20'),
        );

        if (response.statusCode == 200) {
          final newsData = json.decode(response.body);

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

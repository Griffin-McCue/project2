import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class ChartData {
  final String date;
  final double currentPrice;

  ChartData({required this.date, required this.currentPrice});
}

class StockProfile {
  final String country;
  final String currency;
  final String exchange;
  final String name;
  final String ticker;
  final String logoUrl;
  final String category;
  final List<ChartData> priceHistory;

  StockProfile({
    required this.country,
    required this.currency,
    required this.exchange,
    required this.name,
    required this.ticker,
    required this.logoUrl,
    required this.category,
    required this.priceHistory,
  });

  factory StockProfile.fromJson(Map<String, dynamic> json, List<ChartData> history) {
    return StockProfile(
      country: json['country'] ?? '',
      currency: json['currency'] ?? '',
      exchange: json['exchange'] ?? '',
      name: json['name'] ?? '',
      ticker: json['ticker'] ?? '',
      logoUrl: json['logo'] ?? '',
      category: json['finnhubIndustry'] ?? 'Uncategorized',
      priceHistory: history,
    );
  }
}

Future<List<ChartData>> fetchChartData(String symbol) async {
  const String AV_KEY = 'Y5M68XBXFU2HZ9H6';
  final today = DateTime.now();
  final endDate = today.subtract(const Duration(days: 30)); 

  final timeSeries = await http.get(
    Uri.parse('https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=$symbol&outputsize=compact&apikey=$AV_KEY'),
  );

  if (timeSeries.statusCode == 200) {
    final timeData = json.decode(timeSeries.body);
    List<ChartData> currentChartInfo = [];
    final dailyInfo = timeData['Time Series (Daily)'] as Map<String, dynamic>;

    for (final day in dailyInfo.entries) {
      final date = DateTime.parse(day.key);
      if (date.isBefore(endDate)) {
        continue;
      }
      final dayString = '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      currentChartInfo.add(ChartData(
        date: dayString,
        currentPrice: double.parse(day.value['4. close']),
      ));
    }
    return currentChartInfo.reversed.toList();
  } else {
    throw Exception('Failed to load chart data');
  }
}

Future<StockProfile> fetchStockProfileFull(String symbol) async {
  const String finnhubToken = 'cvvvnshr01qud9qkv3hgcvvvnshr01qud9qkv3i0';

  final profileResponse = await http.get(
    Uri.parse('https://finnhub.io/api/v1/stock/profile2?symbol=$symbol&token=$finnhubToken'),
  );
  final chartHistory = await fetchChartData(symbol);

  if (profileResponse.statusCode == 200) {
    final profileJson = json.decode(profileResponse.body);
    return StockProfile.fromJson(profileJson, chartHistory);
  } else {
    throw Exception('Failed to load stock profile');
  }
}

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, List<StockProfile>> categorizedStocks = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    final User? user = _auth.currentUser;
    if (!mounted) return;

    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final snapshot = await _firestore.collection('watchlists').where('user_id', isEqualTo: user.uid).get();
      final watchlistStocks = snapshot.docs.map((doc) => doc['symbol'] as String).toList();

      List<Future<StockProfile>> futures = watchlistStocks.map(fetchStockProfileFull).toList();
      List<StockProfile> profiles = await Future.wait(futures);

      Map<String, List<StockProfile>> categorized = {};
      for (var profile in profiles) {
        categorized.putIfAbsent(profile.category, () => []).add(profile);
      }

      setState(() {
        categorizedStocks = categorized;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading watchlist: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categorizedStocks.isEmpty) {
      return const Center(child: Text('No stocks in your watchlist.'));
    }

    return ListView(
      children: categorizedStocks.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            ...entry.value.map((profile) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          profile.logoUrl.isNotEmpty
                              ? Image.network(profile.logoUrl, width: 40, height: 40, fit: BoxFit.cover)
                              : const Icon(Icons.business),
                          const SizedBox(width: 10),
                          Text(profile.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(profile.ticker, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 250,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                isCurved: true,
                                spots: profile.priceHistory.asMap().entries.map((entry) {
                                  return FlSpot(entry.key.toDouble(), entry.value.currentPrice);
                                }).toList(),
                                barWidth: 2,
                                belowBarData: BarAreaData(show: false),
                                dotData: FlDotData(show: false),
                              ),
                            ],
                            minY: profile.priceHistory.map((data) => data.currentPrice).reduce((a, b) => a < b ? a : b) - 1,
                            maxY: profile.priceHistory.map((data) => data.currentPrice).reduce((a, b) => a > b ? a : b) + 1,
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, _) {
                                    int index = value.toInt();
                                    if (index >= 0 && index < profile.priceHistory.length) {
                                      return Transform.rotate(
                                        angle: -0.5,
                                        child: Text(
                                          profile.priceHistory[index].date,
                                          style: const TextStyle(fontSize: 8),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, _) => Text(
                                    value.toStringAsFixed(0),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            gridData: FlGridData(show: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
          ],
        );
      }).toList(),
    );
  }
}

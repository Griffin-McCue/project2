import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_gate.dart';
import 'stocks_api.dart';
import 'package:fl_chart/fl_chart.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String companyName = "";
  String stockSymbol = "Symbol";
  double displayPrice = 0.0;
  List<chartData> chartPrices = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  _search(String searchItem) async {
    searchItem = searchItem.trim();
    if (searchItem.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Empty Search"),
          content: const Text("Please enter a symbol first."),
          actions: <Widget>[
           TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text("OK"),
            ),
          ],
       ),
      );
      return;
    }
    try {
      StockResponse? result = await Stocks_Api.fetchStockInformation(searchItem);
      if (result == null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Invalid Search"),
            content: Text("No results found for $searchItem"),
            actions: <Widget>[
            TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }
      setState(() {
        stockSymbol = result.stockSymbol;
        companyName = result.stockName; 
        displayPrice = result.currentPrice;
        chartPrices = result.chartInfo;
      });
    } catch (error) {
      print("_search() error: $error");
    }
  }

  _watchAlert() async {
    if (stockSymbol == "Symbol") {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Empty Search"),
          content: const Text("Please enter a valid symbol first."),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }    
    try {
      final user = _auth.currentUser;
      final userDoc = FirebaseFirestore.instance.collection('watchlists');
      await userDoc.add({
        'symbol': stockSymbol,
        'user_id': user!.uid,
        'companyName': companyName,
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Valid Search"),
          content: Text("Added " + stockSymbol + " to the watchlist!"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (error) {
      print("Error logging watchlist entry: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextFormField(
              controller: _searchController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(), 
                hintText: 'Stock symbol'
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _search(_searchController.text),
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll<Color>(Color(0xFFffde59)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              child: Text("Confirm", style: TextStyle(color: Colors.black)),
            ),
            SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  color: Colors.black,
                  height: 70.0,
                  width: 140.0,
                  child: Center(
                    child: Text(
                      stockSymbol,
                      style: TextStyle(color: Colors.white, fontSize: 25),
                    ),
                  ),
                ),
                SizedBox(width: 80),
                Container(
                  color: Colors.black,
                  height: 70.0,
                  width: 140.0,
                  child: Center(
                    child: Text(
                      '$displayPrice',
                      style: TextStyle(color: Colors.white, fontSize: 25),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              companyName, 
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 5),
            if (chartPrices.isNotEmpty)
              Container(
                height: 400,
                width: 400,
                padding: EdgeInsets.all(16),
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        spots: chartPrices.map((point) {
                          int xIndex = chartPrices.toList().indexOf(point);
                          return FlSpot(xIndex.toDouble(), point.currentPrice);
                        }).toList(),
                        barWidth: 2, //line weight
                        belowBarData: BarAreaData(show: false),
                        dotData: FlDotData(show: false),
                      ),
                    ],
                    minY: chartPrices.map((data) => data.currentPrice).reduce((curr, next) => curr < next ? curr : next) - 4,
                    maxY: chartPrices.map((data) => data.currentPrice).reduce((curr, next) => curr > next ? curr : next) + 4,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 6,
                          getTitlesWidget: (value, _) {
                            int index = value.toInt();
                            if (index >= 0 && index < chartPrices.length) {
                              return Text(chartPrices.toList()[index].date);
                            }
                            return Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          interval: 6,
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, _) => Text(
                            value.toString(),
                            style: TextStyle(fontSize: 14),
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
              )
            else
              SizedBox(
                height: 350, 
                width: 350, 
                child: Center(child: Text("No data searched yet."))
              ),
            SizedBox(height: 50),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _watchAlert(),
        backgroundColor: Colors.grey, 
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
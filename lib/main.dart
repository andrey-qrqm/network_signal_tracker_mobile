import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/material.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(MyApp());
}


class Measurement {
  final DateTime timestamp;
  final int ping;
  final int signalStrength;

  Measurement({
    required this.timestamp,
    required this.ping,
    required this.signalStrength,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'ping': ping,
    'signalStrength': signalStrength,
  };
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracking App',
      home: CoordinateScreen(),
    );
  }
}

class CoordinateScreen extends StatefulWidget {
  @override
  _CoordinateScreenState createState() => _CoordinateScreenState();
}

class _CoordinateScreenState extends State<CoordinateScreen> {
  String _status = 'Press start to begin tracking';
  List<Measurement> measurements = [];
  Timer? trackingTimer;
  bool _isTracking = false;
  final FlutterInternetSignal internetSignal = FlutterInternetSignal();

  @override
  void dispose() {
    trackingTimer?.cancel();
    super.dispose();
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;

      if (_isTracking) {
        // Start tracking
        _status = 'Tracking... Total records: ${measurements.length}';
        trackingTimer = Timer.periodic(Duration(seconds: 15), (timer) {
          _trackOnce();
        });
        // Take first measurement immediately
        _trackOnce();
      } else {
        // Stop tracking
        trackingTimer?.cancel();
        measurements.clear();
        _status = 'Tracking stopped. Press start to begin.';
      }
    });
  }


  Future<void> _trackOnce() async {
    try {
      final measurement = await _getMeasurement();
      if (!mounted) return;
      setState(() {
        measurements.add(measurement);
        _status = 'Tracking... Total records: ${measurements.length}';
      });
    } catch (e) {
      print("Tracking error: $e");
    }
  }

  Future<Measurement> _getMeasurement() async {
    int ping = -1;
    int signalStrength = -1;

    try {
      // Ping
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect('8.8.8.8', 53, timeout: Duration(seconds: 5));
      stopwatch.stop();
      ping = stopwatch.elapsedMilliseconds;
      socket.destroy();
    } catch (e) {
      print("Ping error: $e");
    }

    try {
      // Signal Strength
      final mobileSignal = await internetSignal.getMobileSignalStrength();
      signalStrength = mobileSignal ?? -1;
    } catch (e) {
      print("Signal strength error: $e");
    }

    return Measurement(
      timestamp: DateTime.now(),
      ping: ping,
      signalStrength: signalStrength,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'Network Signal Tracker',
          style: GoogleFonts.robotoMono(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.lightBlueAccent,
          ),
        ),
        backgroundColor: Color(0xFF1E1E2E),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleTracking,
                child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking ? Colors.red : Colors.blue,
                ),
              ),
              SizedBox(height: 20),
              Text(_status),
              SizedBox(height: 40),
              Text("Ping and dBm"),
              FractionallySizedBox(
                widthFactor: 0.9, // 80% of screen width
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: measurements.isEmpty
                      ? Center(
                    child: Text(
                      'No data available.\nStart tracking to see measurements.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.robotoMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                  )
                      : LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: measurements.map((m) =>
                              FlSpot(m.timestamp.millisecondsSinceEpoch.toDouble(),
                                  m.signalStrength.toDouble())).toList(),
                          isCurved: true,
                          color: const Color(0xFF69D6FF), // Light blue
                          barWidth: 2.5,
                          dotData: FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: measurements.map((m) =>
                              FlSpot(m.timestamp.millisecondsSinceEpoch.toDouble(),
                                  m.ping.toDouble())).toList(),
                          isCurved: true,
                          color: const Color(0xFFFF6B6B), // Light red
                          barWidth: 2.5,
                          dotData: FlDotData(show: false),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  value.toStringAsFixed(0),
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.lightBlueAccent,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 10,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white12,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.white10, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
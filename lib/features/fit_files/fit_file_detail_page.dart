import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:fit_tool/fit_tool.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../core/services/fit/fit_file_manager.dart';
import '../../l10n/app_localizations.dart';

/// Page for displaying detailed FIT file data with graphs
class FitFileDetailPage extends StatefulWidget {
  const FitFileDetailPage({
    super.key,
    required FitFileInfo fitFileInfo,
    FitFileManager? fitFileManager,
    AnalyticsService? analyticsService,
  }) : _fitFileInfo = fitFileInfo, _fitFileManager = fitFileManager, _analyticsService = analyticsService;

  final FitFileInfo _fitFileInfo;
  final FitFileManager? _fitFileManager;
  final AnalyticsService? _analyticsService;

  @override
  State<FitFileDetailPage> createState() => _FitFileDetailPageState();
}

class _FitFileDetailPageState extends State<FitFileDetailPage> {
  late final FitFileManager _fitFileManager;
  late final AnalyticsService _analyticsService;
  FitFileDetail? _fitFileDetail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fitFileManager = widget._fitFileManager ?? FitFileManager();
    _analyticsService = widget._analyticsService ?? AnalyticsService();
    _analyticsService.logScreenView(screenName: 'fit_file_detail');
    _loadFitFileDetail();
  }

  Future<void> _loadFitFileDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final detail = await _fitFileManager.getFitFileDetail(widget._fitFileInfo.filePath);
      setState(() {
        _fitFileDetail = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToLoadFitFileDetail(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget._fitFileInfo.activityName ?? FitFileManager.extractActivityNameFromFilename(widget._fitFileInfo.fileName)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_fitFileDetail == null || _fitFileDetail!.dataPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.show_chart,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noDataAvailable,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary info
          _buildSummaryCard(),
          const SizedBox(height: 24),

          // Graphs
          if (_fitFileDetail!.dataPoints.any((p) => p.speed != null && (_isRowingActivity() ? _convertSpeedToPace(p.speed!) > 0 : p.speed! > 0)))
            _buildGraphCard(
              title: _isRowingActivity() ? AppLocalizations.of(context)!.pace : AppLocalizations.of(context)!.speed,
              unit: _isRowingActivity() ? '/500m' : 'km/h',
              average: _fitFileDetail!.averageSpeed != null ? (_isRowingActivity() 
                  ? _convertSpeedToPace(_fitFileDetail!.averageSpeed!) 
                  : (_fitFileDetail!.averageSpeed! * 3.6)) : null,
              dataPoints: _fitFileDetail!.dataPoints.where((p) => p.speed != null && (_isRowingActivity() ? _convertSpeedToPace(p.speed!) > 0 : p.speed! > 0)).map((p) => _DataPoint(
                timestamp: p.timestamp,
                value: _isRowingActivity() ? _convertSpeedToPace(p.speed!) : (p.speed! * 3.6), // Convert m/s to pace or km/h
              )).toList(),
              color: Colors.blue,
              decimalPlaces: _isRowingActivity() ? 0 : 1, // Pace doesn't need decimals, speed does
            ),

          if (_fitFileDetail!.dataPoints.any((p) => p.cadence != null && p.cadence! > 0))
            _buildGraphCard(
              title: AppLocalizations.of(context)!.cadence,
              unit: 'rpm',
              average: _fitFileDetail!.averageCadence,
              dataPoints: _fitFileDetail!.dataPoints.where((p) => p.cadence != null && p.cadence! > 0).map((p) => _DataPoint(
                timestamp: p.timestamp,
                value: p.cadence!.toDouble(),
              )).toList(),
              color: Colors.green,
              decimalPlaces: 0,
            ),

          if (_fitFileDetail!.dataPoints.any((p) => p.heartRate != null && p.heartRate! > 0))
            _buildGraphCard(
              title: AppLocalizations.of(context)!.heartRate,
              unit: 'bpm',
              average: _fitFileDetail!.averageHeartRate,
              dataPoints: _fitFileDetail!.dataPoints.where((p) => p.heartRate != null && p.heartRate! > 0).map((p) => _DataPoint(
                timestamp: p.timestamp,
                value: p.heartRate!.toDouble(),
              )).toList(),
              color: Colors.red,
              decimalPlaces: 0,
            ),

          if (_fitFileDetail!.dataPoints.any((p) => p.power != null && p.power! > 0))
            _buildGraphCard(
              title: AppLocalizations.of(context)!.power,
              unit: 'W',
              average: _fitFileDetail!.averagePower,
              dataPoints: _fitFileDetail!.dataPoints.where((p) => p.power != null && p.power! > 0).map((p) => _DataPoint(
                timestamp: p.timestamp,
                value: p.power!.toDouble(),
              )).toList(),
              color: Colors.orange,
              decimalPlaces: 0,
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.summary,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hm().format(_fitFileDetail!.creationDate),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_fitFileDetail!.totalDistance != null)
              Text(
                '${AppLocalizations.of(context)!.distance}: ${(_fitFileDetail!.totalDistance! / 1000).toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (_fitFileDetail!.totalTime != null)
              Text(
                '${AppLocalizations.of(context)!.durationLabel} ${_formatDuration(_fitFileDetail!.totalTime!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCard({
    required String title,
    required String unit,
    required double? average,
    required List<_DataPoint> dataPoints,
    required Color color,
    required int decimalPlaces,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (average != null)
                  Text(
                    '${AppLocalizations.of(context)!.average}: ${_formatAverageValue(average, decimalPlaces, unit)} $unit',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 200,
              child: LineChart(
                _buildLineChartData(dataPoints, color, decimalPlaces, unit),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChartData(List<_DataPoint> dataPoints, Color color, int decimalPlaces, String unit) {
    final startTime = dataPoints.first.timestamp;
    final spots = dataPoints.map((point) {
      final secondsFromStart = point.timestamp.difference(startTime).inSeconds.toDouble();
      return FlSpot(secondsFromStart, point.value);
    }).toList();

    final minY = spots.isNotEmpty ? spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) : 0.0;
    final maxY = spots.isNotEmpty ? spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) : 100.0;

    final bool invertYAxis = unit == '/500m';
    final double chartMinY = minY * 0.1;
    final double chartMaxY = maxY * 1.2;
    final adjustedSpots = invertYAxis 
        ? spots.map((s) => FlSpot(s.x, minY + maxY - s.y)).toList()
        : spots;

    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              final displayValue = invertYAxis ? minY + maxY - value : value;
              final formattedValue = unit == '/500m' 
                  ? _formatPace(displayValue) 
                  : displayValue.toStringAsFixed(decimalPlaces);
              return Text(
                formattedValue,
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final duration = Duration(seconds: value.toInt());
              return Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      minX: spots.isNotEmpty ? spots.first.x : 0,
      maxX: spots.isNotEmpty ? spots.last.x : 100,
      minY: chartMinY,
      maxY: chartMaxY,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final displayValue = invertYAxis ? minY + maxY - spot.y : spot.y;
              final formattedValue = unit == '/500m' 
                  ? _formatPace(displayValue) 
                  : displayValue.toStringAsFixed(decimalPlaces);
              return LineTooltipItem(
                formattedValue,
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: adjustedSpots,
          isCurved: true,
          color: color,
          barWidth: 2,
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.1),
          ),
          dotData: FlDotData(show: false),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Check if this is a rowing activity based on the sport field or activity name
  bool _isRowingActivity() {
    // First check the sport field if available
    if (_fitFileDetail?.sport != null) {
      return _fitFileDetail!.sport == Sport.rowing;
    }
    // Fallback to activity name check
    final activityName = _fitFileDetail?.activityName.toLowerCase() ?? '';
    return activityName.contains('row');
  }

  /// Convert speed (m/s) to pace (seconds per 500m)
  double _convertSpeedToPace(double speedMps) {
    if (speedMps <= 0) return 0;
    // Pace = time to cover 500m = 500 / speed
    return 500 / speedMps;
  }

  /// Format pace value as mm:ss/500m
  String _formatPace(double paceSeconds) {
    if (paceSeconds <= 0) return '--:--';
    final minutes = (paceSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (paceSeconds % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Format average value, handling pace formatting for rowing activities
  String _formatAverageValue(double value, int decimalPlaces, String unit) {
    if (unit == '/500m') {
      return _formatPace(value);
    }
    return value.toStringAsFixed(decimalPlaces);
  }
}

/// Helper class for chart data points
class _DataPoint {
  final DateTime timestamp;
  final double value;

  _DataPoint({required this.timestamp, required this.value});
}
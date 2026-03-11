import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moo_point/data/models/behavior_model.dart';
import 'package:moo_point/services/api/node_backend_service.dart';
import 'package:moo_point/presentation/widgets/dashboard/behavior_alerts_widget.dart';
import 'package:moo_point/presentation/widgets/dashboard/behavior_insights_widget.dart';
import 'package:moo_point/presentation/widgets/charts/behavior_timeline_widget.dart';

class BehaviorChartWidget extends StatefulWidget {
  final int nodeId;

  const BehaviorChartWidget({
    super.key,
    required this.nodeId,
  });

  @override
  State<BehaviorChartWidget> createState() => _BehaviorChartWidgetState();
}

class _BehaviorChartWidgetState extends State<BehaviorChartWidget> {
  final NodeBackendService _service = NodeBackendService();
  BehaviorSummary? _todaySummary;
  List<BehaviorData> _recentData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await _service.getBehaviorSummary(widget.nodeId);
      final data = await _service.getBehaviorData(widget.nodeId, hours: 24);

      setState(() {
        _todaySummary = summary;
        _recentData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final isNotFound = _error!.toLowerCase().contains('404') ||
          _error!.toLowerCase().contains('not found') ||
          _error!.toLowerCase().contains('cannot get');

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isNotFound ? Icons.info_outline : Icons.error_outline,
                  size: 48, color: isNotFound ? Colors.grey : Colors.red),
              const SizedBox(height: 16),
              Text(
                  isNotFound
                      ? 'No behavior data for this node is available'
                      : 'Error loading behavior data',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              if (!isNotFound) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_todaySummary == null || _recentData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No behavior data available yet'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Smart Alerts - Top priority for immediate attention
            BehaviorAlertsWidget(summary: _todaySummary!),
            const SizedBox(height: 8),
            // AI Insights - Natural language summary
            BehaviorInsightsWidget(summary: _todaySummary!),
            const SizedBox(height: 8),
            // 24-Hour Timeline - Visual behavior patterns
            BehaviorTimelineWidget(data: _recentData),
            const SizedBox(height: 8),
            // Existing widgets
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodaySummaryCard(),
                  const SizedBox(height: 16),
                  _buildPieChart(),
                  const SizedBox(height: 16),
                  _buildHealthIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummaryCard() {
    final summary = _todaySummary!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Activity Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildActivityRow(
                'Ruminating', summary.ruminatingHours, Colors.blue),
            _buildActivityRow('Grazing', summary.grazingHours, Colors.green),
            _buildActivityRow('Resting', summary.restingHours, Colors.orange),
            _buildActivityRow('Moving', summary.movingHours, Colors.purple),
            _buildActivityRow('Feeding', summary.feedingHours, Colors.red),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${summary.totalHours.toStringAsFixed(1)} hours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(String label, double hours, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label),
          ),
          Text(
            '${hours.toStringAsFixed(1)} hrs',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final summary = _todaySummary!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Behavior Distribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    if (summary.ruminatingMinutes > 0)
                      PieChartSectionData(
                        value: summary.ruminatingMinutes.toDouble(),
                        title:
                            '${summary.ruminatingPercent.toStringAsFixed(0)}%',
                        color: Colors.blue,
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (summary.grazingMinutes > 0)
                      PieChartSectionData(
                        value: summary.grazingMinutes.toDouble(),
                        title: '${summary.grazingPercent.toStringAsFixed(0)}%',
                        color: Colors.green,
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (summary.restingMinutes > 0)
                      PieChartSectionData(
                        value: summary.restingMinutes.toDouble(),
                        title: '${summary.restingPercent.toStringAsFixed(0)}%',
                        color: Colors.orange,
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (summary.movingMinutes > 0)
                      PieChartSectionData(
                        value: summary.movingMinutes.toDouble(),
                        title: '${summary.movingPercent.toStringAsFixed(0)}%',
                        color: Colors.purple,
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (summary.feedingMinutes > 0)
                      PieChartSectionData(
                        value: summary.feedingMinutes.toDouble(),
                        title: '${summary.feedingPercent.toStringAsFixed(0)}%',
                        color: Colors.red,
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator() {
    final summary = _todaySummary!;
    final isHealthy = summary.isHealthy;

    return Card(
      color: isHealthy ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.warning,
              color: isHealthy ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.healthStatus,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rumination: ${summary.ruminatingHours.toStringAsFixed(1)} hrs (Normal: 6-8 hrs)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:moo_point/services/api/node_backend_service.dart';
import 'package:moo_point/data/models/node_history_model.dart';

class VoltageChartWidget extends StatefulWidget {
  final int nodeId;

  const VoltageChartWidget({
    super.key,
    required this.nodeId,
  });

  @override
  State<VoltageChartWidget> createState() => _VoltageChartWidgetState();
}

class _VoltageChartWidgetState extends State<VoltageChartWidget> {
  final NodeBackendService _service = NodeBackendService();
  List<NodeHistoryPoint> _history = [];
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
      final history = await _service.getNodeHistory(widget.nodeId,
          hours: 24, everyMinutes: 10);
      setState(() {
        _history = history.where((p) => p.voltage != null).toList();
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading voltage data',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No voltage data available for the last 24h'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentVoltageCard(),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 16),
            _buildStatusInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentVoltageCard() {
    final latest = _history.last;
    final voltage = latest.voltage ?? 0;
    final isLow = voltage < 5000;

    return Card(
      color: isLow ? Colors.red.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isLow ? Icons.warning_amber_rounded : Icons.bolt,
              color: isLow ? Colors.red : Colors.blue,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Voltage', style: TextStyle(fontSize: 14)),
                  Text(
                    '${(voltage / 1000).toStringAsFixed(1)} kV',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isLow ? Colors.red : Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isLow ? Colors.red : Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isLow ? 'POWER CUT' : 'OK',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('24h Voltage History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            AspectRatio(
              aspectRatio: 1.5,
              child: LineChart(
                LineChartData(
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 6 != 0) return const SizedBox.shrink();
                          final date = _history[value.toInt()].time;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(DateFormat('HH:mm').format(date),
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${(value / 1000).toStringAsFixed(0)}k',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _history.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.voltage ?? 0);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 5000,
                        color: Colors.red.withValues(alpha: 0.5),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (line) => 'Power Cut Threshold (5kV)',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Technical Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _TechRow(label: 'Update Interval', value: '10 minutes'),
            _TechRow(label: 'Measurement Unit', value: 'Millivolts (mV)'),
            _TechRow(label: 'Sensor Precision', value: '±100mV'),
            SizedBox(height: 12),
            Text(
              'Note: Voltage drops below 5kV are typically indicative of a fence short or power disconnection.',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechRow extends StatelessWidget {
  final String label;
  final String value;
  const _TechRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}

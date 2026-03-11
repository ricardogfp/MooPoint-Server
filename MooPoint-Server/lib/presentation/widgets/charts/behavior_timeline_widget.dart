import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moo_point/data/models/behavior_model.dart';

class BehaviorTimelineWidget extends StatelessWidget {
  final List<BehaviorData> data;

  const BehaviorTimelineWidget({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No timeline data available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '24-Hour Behavior Timeline',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Hourly activity breakdown showing behavior patterns throughout the day',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: _buildStackedBarChart(context),
            ),
            const SizedBox(height: 16),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedBarChart(BuildContext context) {
    // Group data by hour
    final hourlyData = <int, BehaviorData>{};
    for (final point in data) {
      final hour = point.timestamp.hour;
      hourlyData[hour] = point;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 3600, // 1 hour in seconds
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final hour = group.x.toInt();
              final data = hourlyData[hour];
              if (data == null) return null;

              final behaviors = [
                if (data.ruminatingSeconds > 0)
                  'Ruminating: ${(data.ruminatingSeconds / 60).toStringAsFixed(0)}m',
                if (data.grazingSeconds > 0)
                  'Grazing: ${(data.grazingSeconds / 60).toStringAsFixed(0)}m',
                if (data.restingSeconds > 0)
                  'Resting: ${(data.restingSeconds / 60).toStringAsFixed(0)}m',
                if (data.movingSeconds > 0)
                  'Moving: ${(data.movingSeconds / 60).toStringAsFixed(0)}m',
                if (data.feedingSeconds > 0)
                  'Feeding: ${(data.feedingSeconds / 60).toStringAsFixed(0)}m',
              ];

              return BarTooltipItem(
                '${hour.toString().padLeft(2, '0')}:00\n${behaviors.join('\n')}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                if (hour % 3 == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final minutes = (value / 60).toInt();
                if (minutes % 15 == 0) {
                  return Text(
                    '${minutes}m',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 35,
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 900, // 15 minutes
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey[400]!),
            left: BorderSide(color: Colors.grey[400]!),
          ),
        ),
        barGroups: List.generate(24, (hour) {
          final data = hourlyData[hour];
          if (data == null) {
            return BarChartGroupData(
              x: hour,
              barRods: [
                BarChartRodData(
                  toY: 0,
                  color: Colors.grey[300],
                  width: 12,
                ),
              ],
            );
          }

          // Create stacked bar segments
          final segments = <BarChartRodStackItem>[];
          double currentY = 0;

          if (data.ruminatingSeconds > 0) {
            segments.add(BarChartRodStackItem(
              currentY,
              currentY + data.ruminatingSeconds.toDouble(),
              Colors.blue,
            ));
            currentY += data.ruminatingSeconds.toDouble();
          }

          if (data.grazingSeconds > 0) {
            segments.add(BarChartRodStackItem(
              currentY,
              currentY + data.grazingSeconds.toDouble(),
              Colors.green,
            ));
            currentY += data.grazingSeconds.toDouble();
          }

          if (data.restingSeconds > 0) {
            segments.add(BarChartRodStackItem(
              currentY,
              currentY + data.restingSeconds.toDouble(),
              Colors.orange,
            ));
            currentY += data.restingSeconds.toDouble();
          }

          if (data.movingSeconds > 0) {
            segments.add(BarChartRodStackItem(
              currentY,
              currentY + data.movingSeconds.toDouble(),
              Colors.purple,
            ));
            currentY += data.movingSeconds.toDouble();
          }

          if (data.feedingSeconds > 0) {
            segments.add(BarChartRodStackItem(
              currentY,
              currentY + data.feedingSeconds.toDouble(),
              Colors.red,
            ));
            currentY += data.feedingSeconds.toDouble();
          }

          return BarChartGroupData(
            x: hour,
            barRods: [
              BarChartRodData(
                toY: currentY,
                color: Colors.transparent,
                width: 12,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                rodStackItems: segments,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem('Ruminating', Colors.blue),
        _buildLegendItem('Grazing', Colors.green),
        _buildLegendItem('Resting', Colors.orange),
        _buildLegendItem('Moving', Colors.purple),
        _buildLegendItem('Feeding', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

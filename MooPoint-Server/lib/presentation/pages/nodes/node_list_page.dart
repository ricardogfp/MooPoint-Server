import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/presentation/pages/nodes/widgets/node_details_sheet.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';

Widget _nodeListAvatar(NodeModel node, double radius) {
  if (node.photoUrl != null && node.photoUrl!.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(node.photoUrl!),
      backgroundColor: Color(node.statusColor),
      onBackgroundImageError: (error, stackTrace) {
        debugPrint(
            'Error loading photo for node ${node.nodeId} from ${node.photoUrl}: $error');
      },
    );
  }
  final isFence = node.nodeType == NodeType.fence;
  return CircleAvatar(
    backgroundColor: isFence ? Colors.blue : Color(node.statusColor),
    radius: radius,
    child: Icon(isFence ? Icons.flash_on : MdiIcons.cow,
        color: Colors.white, size: radius * 0.85),
  );
}

class NodeListPage extends StatefulWidget {
  const NodeListPage({super.key});

  @override
  State<NodeListPage> createState() => _NodeListPageState();
}

class _NodeListPageState extends State<NodeListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';
  String _selectedBattery = 'All';

  final List<String> _statuses = ['All', 'Active', 'Low Battery', 'Offline'];

  final List<String> _batteryLevels = [
    'All',
    'Good (>80%)',
    'Medium (50-80%)',
    'Low (20-50%)',
    'Critical (<20%)'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NodeModel> _filterNodes(List<NodeModel> nodes) {
    return nodes.where((node) {
      final matchesSearch = node.name
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()) ||
          node.nodeId.toString().contains(_searchController.text.toLowerCase());
      final matchesStatus =
          _selectedStatus == 'All' || node.overallStatus == _selectedStatus;

      bool matchesBattery = _selectedBattery == 'All';
      if (_selectedBattery != 'All') {
        switch (_selectedBattery) {
          case 'Good (>80%)':
            matchesBattery = node.batteryLevel > 80;
            break;
          case 'Medium (50-80%)':
            matchesBattery = node.batteryLevel >= 50 && node.batteryLevel <= 80;
            break;
          case 'Low (20-50%)':
            matchesBattery = node.batteryLevel >= 20 && node.batteryLevel < 50;
            break;
          case 'Critical (<20%)':
            matchesBattery = node.batteryLevel < 20;
            break;
        }
      }

      return matchesSearch && matchesStatus && matchesBattery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HerdState>(
      builder: (context, state, _) {
        final filtered = _filterNodes(state.nodes);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Nodes',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: _statuses.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedBattery,
                          decoration: const InputDecoration(
                            labelText: 'Battery Level',
                            border: OutlineInputBorder(),
                          ),
                          items: _batteryLevels.map((level) {
                            return DropdownMenuItem(
                              value: level,
                              child: Text(level),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBattery = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.search_off_outlined,
                      title: 'No nodes found',
                      subtitle: 'Try adjusting your search or filters',
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final node = filtered[index];
                        return NodeListCard(node: node);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class NodeListCard extends StatelessWidget {
  final NodeModel node;

  const NodeListCard({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final isFence = node.nodeType == NodeType.fence;
    return Card(
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => NodeDetailsSheet(node: node),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _nodeListAvatar(node, 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              node.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Node ID: ${node.nodeId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusPill.fromStatus(node.overallStatus),
                      const SizedBox(height: 4),
                      StatusPill.battery(node.batteryLevel),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(isFence ? Icons.bolt : Icons.location_on,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isFence && node.voltage != null
                          ? 'Voltage: ${node.voltage}V • ${node.locationDescription}'
                          : node.locationDescription,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Last seen: ${DateFormat('MMM dd, HH:mm').format(node.lastUpdated)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  if (!node.isRecent) ...[
                    Icon(Icons.warning, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Stale data',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Battery',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        LinearProgressIndicator(
                          value: node.batteryLevel / 100.0,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(node.batteryStatusColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, int> itemCounts = {'valid': 0, 'aboutToExpire': 0, 'expired': 0};
  List<Map<String, dynamic>> validItems = [];
  List<Map<String, dynamic>> aboutToExpireItems = [];
  List<Map<String, dynamic>> expiredItems = [];
  Set<String> selectedItems = {};
  bool isLoading = true;
  bool showBarChart = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    fetchDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('items')
          .get();

      final now = DateTime.now();
      List<Map<String, dynamic>> newValidItems = [];
      List<Map<String, dynamic>> newAboutToExpireItems = [];
      List<Map<String, dynamic>> newExpiredItems = [];

      int valid = 0, aboutToExpire = 0, expired = 0;

      for (var doc in itemsSnapshot.docs) {
        final data = {...doc.data(), 'id': doc.id};
        final expiryDate = (data['expiryDate'] as Timestamp).toDate();

        if (expiryDate.isBefore(now)) {
          expired++;
          newExpiredItems.add(data);
        } else if (expiryDate.difference(now).inDays <= 7) {
          aboutToExpire++;
          newAboutToExpireItems.add(data);
        } else {
          valid++;
          newValidItems.add(data);
        }
      }

      if (mounted) {
        setState(() {
          validItems = newValidItems;
          aboutToExpireItems = newAboutToExpireItems;
          expiredItems = newExpiredItems;
          itemCounts = {
            'valid': valid,
            'aboutToExpire': aboutToExpire,
            'expired': expired
          };
          isLoading = false;
          selectedItems.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> deleteSelectedItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (String itemId in selectedItems) {
        DocumentReference docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('items')
            .doc(itemId);
        batch.delete(docRef);
      }

      await batch.commit();
      if (mounted) {
        setState(() {
          selectedItems.clear();
        });
        await fetchDashboardData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected items deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting items: $e')),
        );
      }
    }
  }

  Future<void> consumeSelectedItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (String itemId in selectedItems) {
        DocumentReference docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('items')
            .doc(itemId);
        batch.delete(docRef);
      }

      await batch.commit();
      if (mounted) {
        setState(() {
          selectedItems.clear();
        });
        await fetchDashboardData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected items consumed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error consuming items: $e')),
        );
      }
    }
  }

  Widget _buildItemTile(Map<String, dynamic> item, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CheckboxListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['name'] ?? 'Unnamed Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: GoogleFonts.inter().fontFamily,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(type),
                    style: TextStyle(
                      color: _getStatusColor(type),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: GoogleFonts.inter().fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Expires: ${_formatDate((item['expiryDate'] as Timestamp).toDate())}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontFamily: GoogleFonts.inter().fontFamily,
                  ),
                ),
              ],
            ),
          ],
        ),
        value: selectedItems.contains(item['id']),
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              selectedItems.add(item['id']);
            } else {
              selectedItems.remove(item['id']);
            }
          });
        },
        activeColor: _getStatusColor(type),
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildItemList(List<Map<String, dynamic>> items, String type) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getEmptyStateIcon(type),
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                _getEmptyStateText(type),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontFamily: GoogleFonts.inter().fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildItemTile(items[index], type),
        ),
        if (selectedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildActionButton(type),
          ),
      ],
    );
  }

  Widget _buildActionButton(String type) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed:
            type == 'expired' ? deleteSelectedItems : consumeSelectedItems,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getStatusColor(type),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: Icon(
          type == 'expired' ? Icons.delete_outline : Icons.check_circle_outline,
          color: Colors.white,
        ),
        label: Text(
          type == 'expired'
              ? 'Delete Selected Items'
              : 'Consume Selected Items',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: GoogleFonts.inter().fontFamily,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String type) {
    switch (type) {
      case 'expired':
        return Colors.red;
      case 'aboutToExpire':
        return Colors.orange;
      case 'valid':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String type) {
    switch (type) {
      case 'expired':
        return 'EXPIRED';
      case 'aboutToExpire':
        return 'EXPIRING SOON';
      case 'valid':
        return 'VALID';
      default:
        return '';
    }
  }

  IconData _getEmptyStateIcon(String type) {
    switch (type) {
      case 'expired':
        return Icons.delete_outline;
      case 'aboutToExpire':
        return Icons.timer_outlined;
      case 'valid':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _getEmptyStateText(String type) {
    switch (type) {
      case 'expired':
        return 'No expired items';
      case 'aboutToExpire':
        return 'No items about to expire';
      case 'valid':
        return 'No valid items';
      default:
        return 'No items found';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildExpandableSection(String label, int? count, Color color,
      IconData icon, List<Map<String, dynamic>> items, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            maintainState: true,
            tilePadding: EdgeInsets.zero,
            title: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.8),
                    color,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: GoogleFonts.inter().fontFamily,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${count ?? 0} items',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: GoogleFonts.inter().fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: _buildItemList(items, type),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(
              toY: itemCounts['expired']?.toDouble() ?? 0,
              color: Colors.red,
              width: 20,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.red],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            )
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(
              toY: itemCounts['aboutToExpire']?.toDouble() ?? 0,
              color: Colors.orange,
              width: 20,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              gradient: const LinearGradient(
                colors: [Colors.orangeAccent, Colors.orange],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            )
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(
              toY: itemCounts['valid']?.toDouble() ?? 0,
              color: Colors.green,
              width: 20,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              gradient: const LinearGradient(
                colors: [Colors.greenAccent, Colors.green],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            )
          ]),
        ],
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                String text = '';
                switch (value.toInt()) {
                  case 0:
                    text = 'Expired';
                    break;
                  case 1:
                    text = 'About to\nExpire';
                    break;
                  case 2:
                    text = 'Valid';
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontFamily: GoogleFonts.inter().fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontFamily: GoogleFonts.inter().fontFamily,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300],
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernPieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 50,
        sections: [
          PieChartSectionData(
            value: itemCounts['expired']?.toDouble() ?? 0,
            color: Colors.red,
            title: '${itemCounts['expired']}',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: itemCounts['aboutToExpire']?.toDouble() ?? 0,
            color: Colors.orange,
            title: '${itemCounts['aboutToExpire']}',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: itemCounts['valid']?.toDouble() ?? 0,
            color: Colors.green,
            title: '${itemCounts['valid']}',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              showBarChart ? Icons.pie_chart : Icons.bar_chart,
              color: Colors.grey[800],
            ),
            onPressed: () {
              setState(() {
                showBarChart = !showBarChart;
                _animationController.reset();
                _animationController.forward();
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                        fontFamily: GoogleFonts.inter().fontFamily,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        _buildExpandableSection(
                          'Valid Items',
                          itemCounts['valid'],
                          Colors.green,
                          Icons.check_circle,
                          validItems,
                          'valid',
                        ),
                        _buildExpandableSection(
                          'About to Expire',
                          itemCounts['aboutToExpire'],
                          Colors.orange,
                          Icons.warning,
                          aboutToExpireItems,
                          'aboutToExpire',
                        ),
                        _buildExpandableSection(
                          'Expired Items',
                          itemCounts['expired'],
                          Colors.red,
                          Icons.error,
                          expiredItems,
                          'expired',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                              fontFamily: GoogleFonts.inter().fontFamily,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 300,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: showBarChart
                                  ? _buildModernBarChart()
                                  : _buildModernPieChart(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

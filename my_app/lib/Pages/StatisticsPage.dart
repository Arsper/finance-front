import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/%D1%81ategoryStat.dart';
// Проверьте этот импорт, у вас там были странные символы в пути
import 'package:my_app/api/sources/remoteDataSource.dart';
// Убедитесь, что модель CategoryStat доступна. Если она в другом файле, импортируйте её.
// Я добавлю определение класса ниже, если оно не подтянется из импортов.

enum ChartPeriod { week, month, year, custom }

class StatisticsPage extends StatefulWidget {
  final int billId;
  final String billName;

  const StatisticsPage({
    super.key,
    required this.billId,
    required this.billName,
  });

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final UserRemoteDataSource api = UserRemoteDataSource(dio: Dioclient.instance);

  List<CategoryStat> categoryStats = [];
  bool isLoading = true;
  int touchedIndex = -1;

  ChartPeriod selectedPeriod = ChartPeriod.month;
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();
    _setPeriod(ChartPeriod.month);
  }

  void _setPeriod(ChartPeriod period) {
    final now = DateTime.now();
    setState(() {
      selectedPeriod = period;
      endDate = now;
      
      switch (period) {
        case ChartPeriod.week:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case ChartPeriod.month:
          startDate = DateTime(now.year, now.month, 1);
          break;
        case ChartPeriod.year:
          startDate = DateTime(now.year, 1, 1);
          break;
        case ChartPeriod.custom:
          break;
      }
    });
    if (period != ChartPeriod.custom) {
      _loadData();
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
        selectedPeriod = ChartPeriod.custom;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final data = await api.getCategoryStats(widget.billId, startDate, endDate);
      data.sort((a, b) => b.totalAmount.abs().compareTo(a.totalAmount.abs()));

      setState(() {
        categoryStats = data; 
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    double totalExpense = categoryStats.fold(0, (sum, item) => sum + item.totalAmount.abs());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.billName),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "${DateFormat('dd.MM.yy').format(startDate)} — ${DateFormat('dd.MM.yy').format(endDate)}",
              style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : categoryStats.isEmpty
                    ? const Center(child: Text("Нет расходов за этот период"))
                    : Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                // --- ИСПРАВЛЕНО ТУТ ---
                                pieTouchData: PieTouchData( 
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        touchedIndex = -1;
                                        return;
                                      }
                                      touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _generateSections(totalExpense),
                              ),
                            ),
                          ),
                          
                          Expanded(
                            flex: 2,
                            child: ListView.builder(
                              itemCount: categoryStats.length,
                              itemBuilder: (context, index) {
                                final item = categoryStats[index];
                                final percent = totalExpense == 0 ? 0.0 : (item.totalAmount.abs() / totalExpense * 100);
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getColor(index),
                                    radius: 8,
                                  ),
                                  title: Text(item.categoryName),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        item.totalAmount.abs().toStringAsFixed(2),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        "${percent.toStringAsFixed(1)}%",
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.all(10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _periodButton("Неделя", ChartPeriod.week),
          const SizedBox(width: 8),
          _periodButton("Месяц", ChartPeriod.month),
          const SizedBox(width: 8),
          _periodButton("Год", ChartPeriod.year),
          const SizedBox(width: 8),
          _periodButton("Свой", ChartPeriod.custom, onPressed: _pickCustomRange),
        ],
      ),
    );
  }

  Widget _periodButton(String text, ChartPeriod period, {VoidCallback? onPressed}) {
    final isSelected = selectedPeriod == period;
    return ChoiceChip(
      label: Text(text),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          if (onPressed != null) {
            onPressed();
          } else {
            _setPeriod(period);
          }
        }
      },
    );
  }

  List<PieChartSectionData> _generateSections(double total) {
    return List.generate(categoryStats.length, (i) {
      final isTouched = i == touchedIndex;
      final double fontSize = isTouched ? 18.0 : 12.0;
      final double radius = isTouched ? 60.0 : 50.0;
      final item = categoryStats[i];
      final double value = item.totalAmount.abs();
      // Защита от деления на ноль, если total = 0
      final percent = total == 0 ? 0.0 : (value / total * 100);

      return PieChartSectionData(
        color: _getColor(i),
        value: value,
        title: percent > 5 ? '${percent.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    });
  }

  Color _getColor(int index) {
    const List<Color> palette = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, 
      Colors.purple, Colors.teal, Colors.amber, Colors.indigo,
      Colors.pink, Colors.cyan, Colors.deepOrange, Colors.lime
    ];
    return palette[index % palette.length];
  }
}
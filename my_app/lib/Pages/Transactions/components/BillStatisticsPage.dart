import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/Pages/Transactions/components/transaction_filter_service.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/%D1%81ategoryStat.dart';
import 'package:my_app/api/data/dailyStat.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';

class BillStatisticsPage extends StatefulWidget {
  final int billId;
  final String billName;
  final String currencySymbol;

  const BillStatisticsPage({
    super.key,
    required this.billId,
    required this.billName,
    required this.currencySymbol,
  });

  @override
  State<BillStatisticsPage> createState() => _BillStatisticsPageState();
}

class _BillStatisticsPageState extends State<BillStatisticsPage> {
  final UserRemoteDataSource api = UserRemoteDataSource(
    dio: Dioclient.instance,
  );

  bool isLoading = true;
  List<DailyStat> dailyStats = [];
  List<CategoryStat> categoryStats = [];

  final TransactionFilters _filters = TransactionFilters(period: 'month');
  String _categoryType = "expense"; // expense, income

  final List<Color> _chartPalette = [
    const Color(0xFF818CF8),
    const Color(0xFF2DD4BF),
    const Color(0xFFFB923C),
    const Color(0xFF38BDF8),
    const Color(0xFFF472B6),
    const Color(0xFFA78BFA),
  ];

  final Color _expenseColor = const Color(0xFFF43F5E);
  final Color _incomeColor = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _filters.dateRange = TransactionFilterService.calculateRange(
      _filters.period,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      String? startDate;
      String? endDate;

      if (_filters.dateRange != null) {
        final formatter = DateFormat('yyyy-MM-dd');
        startDate = formatter.format(_filters.dateRange!.start);
        endDate = formatter.format(_filters.dateRange!.end);
      }

      final results = await Future.wait([
        api.getDailyStats(
          widget.billId,
          _filters.period,
          startDate: startDate,
          endDate: endDate,
        ),
        api.getCategoryStats(
          widget.billId,
          _filters.period,
          _categoryType,
          startDate: startDate,
          endDate: endDate,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        dailyStats = results[0] as List<DailyStat>;
        categoryStats = results[1] as List<CategoryStat>;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Ошибка отображения статистики в UI: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  double _calculateTotalStructureAmount() {
    return categoryStats.fold(0.0, (sum, item) => sum + item.totalAmount.abs());
  }

  Future<void> _pickCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _filters.dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _filters.period = 'custom';
        _filters.dateRange = picked;
      });
      _loadData();
    }
  }

  String _getSubtitlePeriodText() {
    if (_filters.dateRange == null) return "За всё время";
    final start = DateFormat('dd.MM.yyyy').format(_filters.dateRange!.start);
    final end = DateFormat('dd.MM.yyyy').format(_filters.dateRange!.end);
    if (start == end) return start;
    return "$start — $end";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Аналитика кошелька",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              widget.billName,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(colorScheme),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      _buildLinearChartCard(colorScheme),
                      const SizedBox(height: 16),
                      _buildPieChartCard(colorScheme),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildModernTab('all', 'Всё время'),
                const SizedBox(width: 8),
                _buildModernTab('week', 'Неделя'),
                const SizedBox(width: 8),
                _buildModernTab('month', 'Месяц'),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _pickCustomDateRange,
                  style: IconButton.styleFrom(
                    backgroundColor: _filters.period == 'custom'
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                    foregroundColor: _filters.period == 'custom'
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getSubtitlePeriodText(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinearChartCard(ColorScheme colorScheme) {
    return _buildModernCard(
      colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Динамика баланса",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              _buildLineLegend(),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 190,
            child: dailyStats.isEmpty
                ? const Center(
                    child: Text(
                      "Нет данных за период",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : LineChart(_buildLineChartData(colorScheme)),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(ColorScheme colorScheme) {
    return _buildModernCard(
      colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Распределение",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              _buildTypeSelector(colorScheme),
            ],
          ),
          const SizedBox(height: 24),
          categoryStats.isEmpty
              ? const SizedBox(
                  height: 140,
                  child: Center(
                    child: Text(
                      "Нет операций по категориям",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 145,
                        child: Stack(
                          children: [
                            PieChart(_buildPieChartData()),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Всего",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.4,
                                      ),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${_calculateTotalStructureAmount().toStringAsFixed(0)} ${widget.currencySymbol}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurface,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 6, child: _buildPieLegend(colorScheme)),
                  ],
                ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(ColorScheme colorScheme) {
    List<FlSpot> expenseSpots = [];
    List<FlSpot> incomeSpots = [];

    if (dailyStats.length == 1) {
      expenseSpots.addAll([
        FlSpot(0, dailyStats[0].expenses.abs()),
        FlSpot(1, dailyStats[0].expenses.abs()),
      ]);
      incomeSpots.addAll([
        FlSpot(0, dailyStats[0].incomes.abs()),
        FlSpot(1, dailyStats[0].incomes.abs()),
      ]);
    } else {
      for (int i = 0; i < dailyStats.length; i++) {
        expenseSpots.add(FlSpot(i.toDouble(), dailyStats[i].expenses.abs()));
        incomeSpots.add(FlSpot(i.toDouble(), dailyStats[i].incomes.abs()));
      }
    }

    double xInterval = 1;
    if (dailyStats.length > 4) {
      xInterval = (dailyStats.length / 4).floorToDouble();
    }

    final bool isLargePeriod = dailyStats.length > 60;

    return LineChartData(
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: dailyStats.length == 1 ? 1 : (dailyStats.length - 1).toDouble(),
      minY: 0,
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: xInterval,
            getTitlesWidget: (val, meta) {
              int idx = val.toInt();
              if (idx < 0 || idx >= dailyStats.length) {
                return const SizedBox.shrink();
              }

              String dateFormatPattern = isLargePeriod ? 'MM.yy' : 'dd.MM';

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat(dateFormatPattern).format(dailyStats[idx].date),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        getTouchedSpotIndicator:
            (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((spotIndex) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: barData.color!.withValues(alpha: 0.25),
                    strokeWidth: 1.5,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: isLargePeriod ? 4 : 6,
                        color: barData.color!,
                        strokeWidth: 2,
                        strokeColor: colorScheme.surface,
                      );
                    },
                  ),
                );
              }).toList();
            },
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.95,
          ),
          tooltipRoundedRadius: 14,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          maxContentWidth: 150,
          getTooltipItems: (spots) {
            List<LineTooltipItem?> items = spots.map((s) {
              final isExpense = s.barIndex == 0;
              return LineTooltipItem(
                "${s.y.toStringAsFixed(0)} ${widget.currencySymbol}",
                TextStyle(
                  color: isExpense ? _expenseColor : _incomeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();

            if (spots.isNotEmpty && items.isNotEmpty) {
              int idx = spots.first.x.toInt();
              if (idx >= 0 && idx < dailyStats.length) {
                String fullDate = DateFormat(
                  'dd MMM yyyy',
                  'ru',
                ).format(dailyStats[idx].date);
                items[0] = LineTooltipItem(
                  "$fullDate\n${spots[0].y.toStringAsFixed(0)} ${widget.currencySymbol}",
                  TextStyle(
                    color: spots[0].barIndex == 0
                        ? _expenseColor
                        : _incomeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }
            }
            return items.whereType<LineTooltipItem>().toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: expenseSpots,
          isCurved: dailyStats.length > 2 && dailyStats.length < 100,
          curveSmoothness: 0.35,
          color: _expenseColor,
          barWidth: isLargePeriod ? 2 : 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _expenseColor.withValues(alpha: isLargePeriod ? 0.08 : 0.15),
                _expenseColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        LineChartBarData(
          spots: incomeSpots,
          isCurved: dailyStats.length > 2 && dailyStats.length < 100,
          curveSmoothness: 0.35,
          color: _incomeColor,
          barWidth: isLargePeriod ? 2 : 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _incomeColor.withValues(alpha: isLargePeriod ? 0.08 : 0.15),
                _incomeColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PieChartData _buildPieChartData() {
    final groupedData = _getGroupedCategoryStats();

    return PieChartData(
      sectionsSpace: 4,
      centerSpaceRadius: 46,
      sections: groupedData.asMap().entries.map((entry) {
        int idx = entry.key;
        var item = entry.value;
        double value = item.totalAmount.abs();

        return PieChartSectionData(
          color: item.categoryId == -1
              ? const Color(0xFF94A3B8)
              : _chartPalette[idx % _chartPalette.length],
          value: value,
          showTitle: false,
          radius: 14,
          badgeWidget: const SizedBox.shrink(),
        );
      }).toList(),
    );
  }

  Widget _buildPieLegend(ColorScheme colorScheme) {
    final groupedData = _getGroupedCategoryStats();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedData.length,
      itemBuilder: (context, index) {
        final item = groupedData[index];
        double total = _calculateTotalStructureAmount();
        double percentage = total > 0
            ? (item.totalAmount.abs() / total) * 100
            : 0;

        String percentageDisplay = (percentage > 0 && percentage < 1)
            ? '<1%'
            : '${percentage.toStringAsFixed(0)}%';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.categoryId == -1
                      ? const Color(0xFF94A3B8)
                      : _chartPalette[index % _chartPalette.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.categoryName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      percentageDisplay,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "${item.totalAmount.abs().toStringAsFixed(0)} ${widget.currencySymbol}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<CategoryStat> _getGroupedCategoryStats() {
    if (categoryStats.length <= 5) return categoryStats;
    final sorted = List<CategoryStat>.from(categoryStats)
      ..sort((a, b) => b.totalAmount.abs().compareTo(a.totalAmount.abs()));
    final top5 = sorted.sublist(0, 5);
    final others = sorted.sublist(5);
    double othersTotal = others.fold(
      0.0,
      (sum, item) => sum + item.totalAmount,
    );

    return [
      ...top5,
      CategoryStat(
        categoryId: -1,
        categoryName: 'Другие',
        totalAmount: othersTotal,
      ),
    ];
  }

  Widget _buildModernTab(String value, String label) {
    final isSelected = _filters.period == value;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        setState(() {
          _filters.period = value;
          _filters.dateRange = TransactionFilterService.calculateRange(value);
        });
        _loadData();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTypeButton('expense', 'Расходы', colorScheme),
          _buildTypeButton('income', 'Доходы', colorScheme),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String value, String label, ColorScheme colorScheme) {
    final isSelected = _categoryType == value;
    return GestureDetector(
      onTap: () {
        setState(() => _categoryType = value);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard(ColorScheme colorScheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLineLegend() {
    return Row(
      children: [
        _buildLegendDot(_incomeColor, "Доход"),
        const SizedBox(width: 14),
        _buildLegendDot(_expenseColor, "Расход"),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

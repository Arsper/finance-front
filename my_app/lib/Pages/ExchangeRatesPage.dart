import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/%D1%81urrency.dart'; 
import 'package:my_app/api/data/ratePoint.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';

class ExchangeRatesPage extends StatefulWidget {
  const ExchangeRatesPage({super.key});

  @override
  State<ExchangeRatesPage> createState() => _ExchangeRatesPageState();
}

class _ExchangeRatesPageState extends State<ExchangeRatesPage> {
  late UserRemoteDataSource _dataSource;
  final TextEditingController _amountController = TextEditingController(text: "1");

  List<Currency> _currencies = [];
  Currency? _selectedFrom;
  Currency? _selectedTo;
  
  double? _conversionResult;
  bool _isLoading = false;
  bool _isGraphLoading = false;

  // Данные для графика
  List<RatePoint> _historyPoints = [];
  String _selectedPeriod = "week"; 

  @override
  void initState() {
    super.initState();
    _dataSource = UserRemoteDataSource(dio: Dioclient.instance);
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dataSource.getCurrencies();
      setState(() {
        _currencies = list;
        if (_currencies.isNotEmpty) {
          _selectedFrom = _currencies.first;
          _selectedTo = _currencies.length > 1 ? _currencies[1] : _currencies.first;
        }
      });
      _convert();
      _loadHistory();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _convert() async {
    if (_selectedFrom == null || _selectedTo == null) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null) return;

    final result = await _dataSource.convertCurrency(
      fromId: _selectedFrom!.idCurrencies, 
      toId: _selectedTo!.idCurrencies,
      amount: amount,
    );

    if (mounted) {
      setState(() {
        _conversionResult = result;
      });
    }
  }

  Future<void> _loadHistory() async {
    if (_selectedFrom == null || _selectedTo == null) return;
    
    setState(() => _isGraphLoading = true);
    
    final points = await _dataSource.getExchangeHistory(
      fromId: _selectedFrom!.idCurrencies,
      toId: _selectedTo!.idCurrencies,
      period: _selectedPeriod,
    );
    
    if (mounted) {
      setState(() {
        _historyPoints = points;
        _isGraphLoading = false;
      });
    }
  }

  // Вспомогательная функция для форматирования курса
  String formatRate(double value) {
    if (value < 10) {
      return value.toStringAsFixed(4); // Для 0.8543
    } else {
      return value.toStringAsFixed(2); // Для 95.40
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // 1. Блок конвертера
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text("Конвертер валют", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Сумма",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _convert(),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildCurrencyDropdown(_selectedFrom, (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedFrom = val;
                            if (_selectedFrom == _selectedTo) {
                              _selectedTo = _currencies.firstWhere(
                                (element) => element != val,
                                orElse: () => _currencies.last,
                              );
                            }
                          });
                          _convert();
                          _loadHistory();
                        }),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(Icons.arrow_forward, color: Colors.grey),
                      ),
                      Expanded(
                        child: _buildCurrencyDropdown(_selectedTo, (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedTo = val;
                            if (_selectedTo == _selectedFrom) {
                              _selectedFrom = _currencies.firstWhere(
                                (element) => element != val,
                                orElse: () => _currencies.last,
                              );
                            }
                          });
                          _convert();
                          _loadHistory();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  if (_conversionResult != null)
                    Text(
                      "${_amountController.text} ${_selectedFrom?.code ?? ''} = ${_conversionResult!.toStringAsFixed(2)} ${_selectedTo?.code ?? ''}",
                      style: const TextStyle(fontSize: 20, color: Colors.deepPurple, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. Блок Графика
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Динамика курса", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      
                      ToggleButtons(
                        isSelected: [_selectedPeriod == 'week', _selectedPeriod == 'month'],
                        onPressed: (index) {
                          setState(() {
                            _selectedPeriod = index == 0 ? 'week' : 'month';
                          });
                          _loadHistory();
                        },
                        borderRadius: BorderRadius.circular(8),
                        constraints: const BoxConstraints(minHeight: 30, minWidth: 60),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text("Неделя"),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text("Месяц"),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    height: 250,
                    child: _isGraphLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _historyPoints.isEmpty
                            ? const Center(child: Text("Нет данных для графика"))
                            : LineChart(_buildChartData()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(Currency? value, ValueChanged<Currency?> onChanged) {
    return DropdownButtonFormField<Currency>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _currencies.map((Currency currency) {
        return DropdownMenuItem<Currency>(
          value: currency,
          child: Text(currency.code),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  LineChartData _buildChartData() {
    if (_historyPoints.isEmpty) return LineChartData();

    double minY = _historyPoints.map((e) => e.rate).reduce((a, b) => a < b ? a : b);
    double maxY = _historyPoints.map((e) => e.rate).reduce((a, b) => a > b ? a : b);

    double range = maxY - minY;
    double buffer = range == 0 ? 0.001 : range * 0.1;
    minY -= buffer;
    maxY += buffer;

    final int length = _historyPoints.length;

    return LineChartData(
      clipData: const FlClipData.none(),
      
      // --- НАСТРОЙКА ТУЛТИПА (Цифры при нажатии) ---
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          // Цвет фона тултипа (можно настроить под себя)
          tooltipRoundedRadius: 8,
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                formatRate(spot.y), // Применяем форматирование
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),

      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: Colors.white10,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        
        // --- ОСЬ X (ДАТЫ) ---
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: length > 1 ? (length - 1) / 5 : 1.0, 
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              final lastIndex = length - 1;

              if (index < 0 || index > lastIndex) return const SizedBox.shrink();

              final dateText = DateFormat('dd.MM').format(_historyPoints[index].date);
              const style = TextStyle(
                fontSize: 9, 
                color: Colors.grey, 
                fontWeight: FontWeight.bold
              );

              if (index == lastIndex) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                  child: Text(dateText, style: style),
                );
              }

              final double intervalSize = length > 1 ? (length - 1) / 5 : 1.0;
              if (index > lastIndex - intervalSize) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                fitInside: SideTitleFitInsideData.disable(),
                child: Text(dateText, style: style),
              );
            },
          ),
        ),

        // --- ОСЬ Y (ЦЕНЫ СЛЕВА) ---
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            interval: (maxY - minY) / 4,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                child: Text(
                  formatRate(value), // Применяем форматирование
                  style: const TextStyle(
                      fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.left,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: _historyPoints
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.rate))
              .toList(),
          isCurved: true,
          curveSmoothness: 0.35,
          color: Colors.deepPurpleAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.deepPurpleAccent.withOpacity(0.3),
                Colors.deepPurpleAccent.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
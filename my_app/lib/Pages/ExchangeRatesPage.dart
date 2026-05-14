import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/exchange_dialog.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/сurrency.dart';
import 'package:my_app/api/data/ratePoint.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';

class ExchangeRatesPage extends StatefulWidget {
  const ExchangeRatesPage({super.key});

  @override
  State<ExchangeRatesPage> createState() => _ExchangeRatesPageState();
}

class _ExchangeRatesPageState extends State<ExchangeRatesPage> {
  late UserRemoteDataSource _dataSource;
  final TextEditingController _amountController = TextEditingController(
    text: "1",
  );
  final _formKey = GlobalKey<FormState>(); // Ключ для валидации

  List<Currency> _currencies = [];
  List<dynamic> _allWallets = [];
  Currency? _selectedFrom;
  Currency? _selectedTo;

  double? _conversionResult;
  bool _isLoading = false;
  bool _isGraphLoading = false;

  List<RatePoint> _historyPoints = [];
  String _selectedPeriod = "week";

  @override
  void initState() {
    super.initState();
    _dataSource = UserRemoteDataSource(dio: Dioclient.instance);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _dataSource.getCurrencies(),
        _dataSource.getWallets(),
      ]);

      setState(() {
        _currencies = results[0] as List<Currency>;
        _allWallets = results[1] as List<dynamic>;

        if (_currencies.isNotEmpty) {
          _selectedFrom = _currencies.first;
          _selectedTo = _currencies.length > 1
              ? _currencies[1]
              : _currencies.first;
        }
      });
      _convert();
      _loadHistory();
    } catch (e) {
      debugPrint("Ошибка при получении данных: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _convert() async {
    // Безопасная проверка формы
    if (_formKey.currentState == null) return;

    if (!_formKey.currentState!.validate()) {
      setState(() => _conversionResult = null);
      return;
    }

    if (_selectedFrom == null || _selectedTo == null) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    try {
      final result = await _dataSource.convertCurrency(
        fromId: _selectedFrom!.idCurrencies,
        toId: _selectedTo!.idCurrencies,
        amount: amount,
      );

      if (mounted) {
        setState(() => _conversionResult = result);
      }
    } catch (e) {
      debugPrint("Ошибка конвертации: $e");
    }
  }

  void _showTransferDialog() {
    if (_formKey.currentState == null || !_formKey.currentState!.validate())
      return;

    if (_selectedFrom == null ||
        _selectedTo == null ||
        _conversionResult == null)
      return;

    // Фильтруем кошельки. ВАЖНО: используем 'currencyCode' для сопоставления
    final fromWallets = _allWallets
        .where((w) => w['currencyCode'] == _selectedFrom!.code)
        .toList();
    final toWallets = _allWallets
        .where((w) => w['currencyCode'] == _selectedTo!.code)
        .toList();

    final double initialAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (fromWallets.isNotEmpty) {
      // БЕЗОПАСНОЕ ПОЛУЧЕНИЕ БАЛАНСА: проверяем и null, и правильное имя поля
      final dynamic rawBalance =
          fromWallets.first['currentBalance'] ??
          fromWallets.first['balance'] ??
          0;
      final double balance = (rawBalance as num).toDouble();

      if (initialAmount > balance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Недостаточно средств на кошельке ${_selectedFrom!.code}. "
              "Не хватает: ${(initialAmount - balance).toStringAsFixed(2)}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("У вас нет кошелька в валюте ${_selectedFrom!.code}"),
        ),
      );
      return;
    }

    final double exchangeRate =
        _conversionResult! / (initialAmount > 0 ? initialAmount : 1.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExchangeTransferDialog(
        allWallets: _allWallets,
        fromWallets: fromWallets,
        toWallets: toWallets,
        fromCode: _selectedFrom!.code,
        toCode: _selectedTo!.code,
        initialAmount: initialAmount,
        exchangeRate: exchangeRate,
        onConfirm: (sourceId, targetId, amount, targetAmount) async {
          final success = await _dataSource.transferMoney(
            sourceBillId: sourceId,
            targetBillId: targetId,
            amount: amount,
            targetAmount: targetAmount,
            description: "Обмен ${_selectedFrom!.code} -> ${_selectedTo!.code}",
          );

          if (success && context.mounted) {
            Navigator.pop(context);
            _loadInitialData(); // Обновляем данные
          }
        },
      ),
    );
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

  String formatRate(double value) {
    return value < 10 ? value.toStringAsFixed(4) : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        // Добавили Form
        key: _formKey,
        child: ListView(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Конвертер валют",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        // Разрешаем только цифры и одну точку/запятую
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[.,]?\d*'),
                        ),
                        // Автоматически заменяем запятую на точку для double.tryParse
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final text = newValue.text.replaceAll(',', '.');
                          return newValue.copyWith(text: text);
                        }),
                      ],
                      decoration: const InputDecoration(
                        labelText: "Сумма",
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Введите сумму";
                        final n = double.tryParse(val);
                        if (n == null) return "Некорректное число";
                        if (n <= 0) return "Должно быть больше 0";
                        return null;
                      },
                      onChanged: (val) => _convert(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCurrencyDropdown(_selectedFrom, (val) {
                            if (val == null) return;
                            setState(() {
                              _selectedFrom = val;
                              if (_selectedFrom == _selectedTo) {
                                _selectedTo = _currencies.firstWhere(
                                  (c) => c != val,
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
                                  (c) => c != val,
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
                    if (_conversionResult != null) ...[
                      Text(
                        "${_amountController.text} ${_selectedFrom?.code ?? ''} = ${_conversionResult!.toStringAsFixed(2)} ${_selectedTo?.code ?? ''}",
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showTransferDialog,
                        icon: const Icon(Icons.swap_horiz, color: Colors.white),
                        label: const Text(
                          "СОВЕРШИТЬ ПЕРЕВОД",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ... (блок с графиком без изменений, так как вы его уже исправили)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Динамика курса",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ToggleButtons(
                          isSelected: [
                            _selectedPeriod == 'week',
                            _selectedPeriod == 'month',
                          ],
                          onPressed: (index) {
                            setState(
                              () => _selectedPeriod = index == 0
                                  ? 'week'
                                  : 'month',
                            );
                            _loadHistory();
                          },
                          borderRadius: BorderRadius.circular(8),
                          constraints: const BoxConstraints(
                            minHeight: 30,
                            minWidth: 60,
                          ),
                          children: const [Text("Неделя"), Text("Месяц")],
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
      ),
    );
  }

  Widget _buildCurrencyDropdown(
    Currency? value,
    ValueChanged<Currency?> onChanged,
  ) {
    return DropdownButtonFormField<Currency>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _currencies
          .map((c) => DropdownMenuItem(value: c, child: Text(c.code)))
          .toList(),
      onChanged: onChanged,
    );
  }

  // ... (Ваши импорты иinitState остаются без изменений)

  LineChartData _buildChartData() {
    if (_historyPoints.isEmpty) return LineChartData();

    // 1. Более точный расчет диапазона Y
    double minY = _historyPoints
        .map((e) => e.rate)
        .reduce((a, b) => a < b ? a : b);
    double maxY = _historyPoints
        .map((e) => e.rate)
        .reduce((a, b) => a > b ? a : b);

    // Если курс почти не меняется (min == max), добавляем небольшой отступ вручную
    if (minY == maxY) {
      minY *= 0.95; // -5% отступ
      maxY *= 1.05; // +5% отступ
    } else {
      // Иначе оставляем расчет буфера, но делаем его меньше (5%)
      double buffer = (maxY - minY) * 0.05;
      minY -= buffer;
      maxY += buffer;
    }

    // ВАЖНО: убедитесь, что minY и maxY положительные для курса,
    // если они вдруг стали отрицательными после вычета буфера
    if (minY < 0) minY = 0;

    // 2. Логика для форматирования оси X
    DateFormat dateFormat = _selectedPeriod == 'month'
        ? DateFormat('dd.MM.yy') // С годом для месяца
        : DateFormat('dd.MM'); // Только день.месяц для недели

    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          // ... (tooltip_items остаются без изменений)
          getTooltipItems: (spots) => spots
              .map(
                (s) => LineTooltipItem(
                  formatRate(s.y),
                  const TextStyle(color: Colors.white),
                ),
              )
              .toList(),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, meta) {
              int idx = val.toInt();
              if (idx < 0 || idx >= _historyPoints.length) {
                return const SizedBox.shrink();
              }

              // 3. Улучшенная логика отбора точек оси X (интервал)
              // Для недели показываем каждую вторую (0, 2, 4...)
              // Для месяца — каждую четвертую (0, 4, 8...) чтобы не накладывались
              int interval = _selectedPeriod == 'month' ? 4 : 2;

              if (idx % interval != 0) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 10.0), // Отступ от графика
                child: Text(
                  dateFormat.format(_historyPoints[idx].date),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            // 4. ГЛАВНОЕ: Увеличиваем место для Y, чтобы избежать наложения
            reservedSize: 60, // Увеличили с 40 до 60
            getTitlesWidget: (val, meta) => Text(
              formatRate(val),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: _historyPoints
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.rate))
              .toList(),
          isCurved: true,
          color: Colors.deepPurpleAccent,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.deepPurpleAccent.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/exchange_dialog.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/сurrency.dart';
import 'package:my_app/api/data/ratePoint.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/Pages/Guide/guide_manager.dart';
import 'package:my_app/Pages/Guide/exchange_rates_guide.dart';
import 'package:my_app/helpers/OverlayToastService.dart';

class ExchangeRatesPage extends StatefulWidget {
  final bool startGuide;
  const ExchangeRatesPage({super.key, this.startGuide = false});

  @override
  State<ExchangeRatesPage> createState() => _ExchangeRatesPageState();
}

class _ExchangeRatesPageState extends State<ExchangeRatesPage> {
  final String _guideId = 'exchange_rates_v1';
  final GuideManager _guideManager = GuideManager();

  late UserRemoteDataSource _dataSource;
  final TextEditingController _amountController = TextEditingController(
    text: "1",
  );
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _amountInputKey = GlobalKey();
  final GlobalKey _swapButtonKey = GlobalKey();
  final GlobalKey _transferButtonKey = GlobalKey();
  final GlobalKey _graphKey = GlobalKey();

  List<Currency> _currencies = [];
  List<dynamic> _allWallets = [];
  Currency? _selectedFrom;
  Currency? _selectedTo;

  double? _conversionResult;
  bool _isLoading = false;
  bool _isGraphLoading = false;

  bool _guideWasShown = false;
  bool _hasPhantomData = false;

  List<RatePoint> _historyPoints = [];
  String _selectedPeriod = "week";

  @override
  void initState() {
    super.initState();
    _dataSource = UserRemoteDataSource(dio: Dioclient.instance);
    _initPage();
  }

  @override
  void didUpdateWidget(covariant ExchangeRatesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startGuide && !oldWidget.startGuide) {
      _checkAndStartGuide();
    }
  }

  Future<void> _initPage() async {
    await _checkAndStartGuide();

    if (!_hasPhantomData) {
      _loadInitialData();
    }
  }

  Future<void> _checkAndStartGuide() async {
    final bool alreadySeen = await _guideManager.hasSeenGuide(_guideId);

    if (!mounted ||
        _guideWasShown ||
        alreadySeen ||
        (widget.startGuide == false && alreadySeen)) {
      return;
    }

    await _guideManager.runGuide(
      showGuide: () {
        if (!mounted) return;

        setState(() {
          _guideWasShown = true;
          _hasPhantomData = true;
          _isLoading = false;
          _isGraphLoading = false;

          final phantomUsd = Currency(
            idCurrencies: 1,
            code: 'USD',
            name: 'US Dollar',
            symbol: '\$',
          );
          final phantomEur = Currency(
            idCurrencies: 2,
            code: 'EUR',
            name: 'Euro',
            symbol: '€',
          );

          _currencies = [phantomUsd, phantomEur];
          _selectedFrom = phantomUsd;
          _selectedTo = phantomEur;

          _amountController.text = "100";
          _conversionResult = 92.50;

          _allWallets = [
            {
              'billId': 1,
              'currencyCode': 'USD',
              'currentBalance': 1500.0,
              'name': 'Main USD',
            },
            {
              'billId': 2,
              'currencyCode': 'EUR',
              'currentBalance': 0.0,
              'name': 'Travel EUR',
            },
          ];

          final now = DateTime.now();
          _historyPoints = List.generate(
            7,
            (i) => RatePoint(
              date: now.subtract(Duration(days: 6 - i)),
              rate: 0.90 + (i * 0.005),
            ),
          );
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ExchangeRatesGuide.show(
            context: context,
            amountInputKey: _amountInputKey,
            swapButtonKey: _swapButtonKey,
            transferButtonKey: _transferButtonKey,
            graphKey: _graphKey,
            onFinish: () async {
              await _guideManager.markGuideAsSeen(_guideId);
              if (mounted) {
                setState(() => _hasPhantomData = false);
                _loadInitialData();
              }
            },
            onSkipAll: () async {
              await _guideManager.markGuideAsSeen(_guideId);
              await _guideManager.disableAllGuidesForever();
              if (mounted) {
                setState(() => _hasPhantomData = false);
                _loadInitialData();
              }
            },
          );
        });
      },
      onSkippedOrFinished: () {
        _guideManager.markGuideAsSeen(_guideId);
      },
    );
  }

  Future<void> _loadInitialData() async {
    if (!mounted || _hasPhantomData) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _dataSource.getCurrencies(),
        _dataSource.getWallets(),
      ]);
      if (!mounted || _hasPhantomData) return;

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
      if (mounted) {
        OverlayToastService.show(
          context,
          message: 'Не удалось загрузить данные валют',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _convert() async {
    if (_hasPhantomData || _formKey.currentState == null) return;

    if (_selectedFrom == null || _selectedTo == null) return;
    final text = _amountController.text;
    if (text.isEmpty) {
      setState(() => _conversionResult = null);
      return;
    }

    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      setState(() => _conversionResult = null);
      return;
    }

    try {
      final result = await _dataSource.convertCurrency(
        fromId: _selectedFrom!.idCurrencies,
        toId: _selectedTo!.idCurrencies,
        amount: amount,
      );

      if (mounted && !_hasPhantomData) {
        setState(() => _conversionResult = result);
      }
    } catch (e) {
      debugPrint("Ошибка конвертации: $e");
      if (mounted && !_hasPhantomData) {
        OverlayToastService.show(
          context,
          message: 'Не удалось выполнить конвертацию',
          isError: true,
        );
      }
    }
  }

  void _showTransferDialog() {
    if (_hasPhantomData) return;

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFrom == null ||
        _selectedTo == null ||
        _conversionResult == null) {
      return;
    }

    final fromWallets = _allWallets
        .where((w) => w['currencyCode'] == _selectedFrom!.code)
        .toList();
    final toWallets = _allWallets
        .where((w) => w['currencyCode'] == _selectedTo!.code)
        .toList();

    final double initialAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (fromWallets.isNotEmpty) {
      final dynamic rawBalance =
          fromWallets.first['currentBalance'] ??
          fromWallets.first['balance'] ??
          0;
      final double balance = (rawBalance as num).toDouble();

      if (initialAmount > balance) {
        OverlayToastService.show(
          context,
          message:
              "Недостаточно средств. Не хватает: ${(initialAmount - balance).toStringAsFixed(2)} ${_selectedFrom!.code}",
          isError: true,
        );
        return;
      }
    } else {
      OverlayToastService.show(
        context,
        message: "У вас нет счета в валюте ${_selectedFrom!.code}",
        isError: true,
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
          try {
            final success = await _dataSource.transferMoney(
              sourceBillId: sourceId,
              targetBillId: targetId,
              amount: amount,
              targetAmount: targetAmount,
              description:
                  "Обмен ${_selectedFrom!.code} -> ${_selectedTo!.code}",
            );

            if (success && context.mounted) {
              Navigator.pop(context);
              _loadInitialData();
              OverlayToastService.show(
                context,
                message: 'Обмен успешно выполнен',
                isError: false,
              );
            } else if (!success && context.mounted) {
              OverlayToastService.show(
                context,
                message: 'Не удалось совершить перевод',
                isError: true,
              );
            }
          } catch (e) {
            if (context.mounted) {
              OverlayToastService.show(
                context,
                message: 'Ошибка соединения с сервером',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _loadHistory() async {
    if (_hasPhantomData || _selectedFrom == null || _selectedTo == null) return;
    setState(() => _isGraphLoading = true);

    try {
      final points = await _dataSource.getExchangeHistory(
        fromId: _selectedFrom!.idCurrencies,
        toId: _selectedTo!.idCurrencies,
        period: _selectedPeriod,
      );

      if (mounted && !_hasPhantomData) {
        setState(() {
          _historyPoints = points;
          _isGraphLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !_hasPhantomData) {
        setState(() => _isGraphLoading = false);
        OverlayToastService.show(
          context,
          message: 'Не удалось загрузить график истории',
          isError: true,
        );
      }
    }
  }

  String formatRate(double value) {
    return value < 10 ? value.toStringAsFixed(4) : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return AbsorbPointer(
      absorbing: _hasPhantomData,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
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
                        key: _amountInputKey,
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*[.,]?\d*'),
                          ),
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
                          if (val == null || val.isEmpty) {
                            return "Введите сумму";
                          }
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
                          IconButton(
                            key: _swapButtonKey,
                            icon: const Icon(
                              Icons.swap_horiz,
                              color: Colors.deepPurple,
                            ),
                            onPressed: () {
                              if (_selectedFrom != null &&
                                  _selectedTo != null) {
                                setState(() {
                                  final temp = _selectedFrom;
                                  _selectedFrom = _selectedTo;
                                  _selectedTo = temp;
                                });
                                _convert();
                                _loadHistory();
                              }
                            },
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
                          key: _transferButtonKey,
                          onPressed: _showTransferDialog,
                          icon: const Icon(
                            Icons.swap_horiz,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "СОВЕРШИТЬ ПЕРЕВОД",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
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
              Card(
                key: _graphKey,
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
                            ? const Center(
                                child: Text("Нет данных для графика"),
                              )
                            : LineChart(_buildChartData()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown(
    Currency? value,
    ValueChanged<Currency?> onChanged,
  ) {
    return DropdownButtonFormField<Currency>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: _currencies
          .map((c) => DropdownMenuItem(value: c, child: Text(c.code)))
          .toList(),
      onChanged: onChanged,
    );
  }

  LineChartData _buildChartData() {
    if (_historyPoints.isEmpty) return LineChartData();

    double minY = _historyPoints
        .map((e) => e.rate)
        .reduce((a, b) => a < b ? a : b);
    double maxY = _historyPoints
        .map((e) => e.rate)
        .reduce((a, b) => a > b ? a : b);

    if (minY == maxY) {
      minY *= 0.95;
      maxY *= 1.05;
    } else {
      double buffer = (maxY - minY) * 0.05;
      minY -= buffer;
      maxY += buffer;
    }

    if (minY < 0) minY = 0;

    DateFormat dateFormat = _selectedPeriod == 'month'
        ? DateFormat('dd.MM.yy')
        : DateFormat('dd.MM');

    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
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

              int interval = _selectedPeriod == 'month' ? 4 : 2;

              if (idx % interval != 0) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 10.0),
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
            reservedSize: 60,
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
          color: Theme.of(context).colorScheme.primary,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/AppFloatingButton.dart';
import 'package:my_app/Pages/Transactions/components/BillStatisticsPage.dart';
import 'package:my_app/Pages/Transactions/components/filter_screen.dart';
import 'package:my_app/Pages/Transactions/components/transaction_filter_service.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'components/transaction_form.dart';
import 'components/category_search_picker.dart';

class TransactionsPage extends StatefulWidget {
  final int billId;
  final String billName;
  final String currencySymbol;

  const TransactionsPage({
    super.key,
    required this.billId,
    required this.billName,
    required this.currencySymbol,
  });

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final UserRemoteDataSource api = UserRemoteDataSource(
    dio: Dioclient.instance,
  );
  final ScrollController _scrollController = ScrollController();

  bool get _isFilterActive => !_currentFilters.isEmpty;
  List<dynamic> allTransactions = [];
  List<dynamic> categories = [];
  List<dynamic> activeLimits = [];
  bool isLoading = true;
  bool isLoadMoreLoading = false;
  bool hasMore = true;
  int currentPage = 0;
  final int pageSize = 20;

  double currentBillBalance = 0.0;
  TransactionFilters _currentFilters = TransactionFilters();

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreTransactions();
    }
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      currentPage = 0;
      hasMore = true;
      allTransactions.clear();
    });

    try {
      final results = await Future.wait([
        api
            .getTransactions(
              billId: widget.billId,
              page: currentPage,
              size: pageSize,
              filters: _currentFilters,
            )
            .catchError((e) {
              debugPrint("Ошибка загрузки транзакций: $e");
              return <dynamic>[];
            }),
        api.getCategories().catchError((e) {
          return <dynamic>[];
        }),
        api.getWallets().catchError((e) {
          return <dynamic>[];
        }),
        api.getLimits(widget.billId).catchError((e) {
          return <dynamic>[];
        }),
      ]);

      final List<dynamic> txResult = results[0];
      final List<dynamic> wallets = results[2];
      final currentWallet = wallets.firstWhere(
        (w) => w['billId']?.toString() == widget.billId.toString(),
        orElse: () => {'currentBalance': 0.0},
      );

      if (!mounted) return;
      setState(() {
        allTransactions = txResult;
        categories = results[1];
        activeLimits = results[3];
        currentBillBalance = (currentWallet['currentBalance'] as num? ?? 0.0)
            .toDouble();

        if (txResult.length < pageSize) {
          hasMore = false;
        }
        currentPage++;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (isLoadMoreLoading || !hasMore) {
      return;
    }

    setState(() => isLoadMoreLoading = true);

    try {
      final List<dynamic> newTx = await api.getTransactions(
        billId: widget.billId,
        page: currentPage,
        size: pageSize,
        filters: _currentFilters,
      );

      if (!mounted) return;
      setState(() {
        if (newTx.length < pageSize) {
          hasMore = false;
        }
        allTransactions.addAll(newTx);
        currentPage++;
        isLoadMoreLoading = false;
      });
    } catch (e) {
      debugPrint("Ошибка пагинации: $e");
      if (mounted) setState(() => isLoadMoreLoading = false);
    }
  }

  Future<void> _refreshData() async {
    await _initialLoad();
  }

  Map<String, double> _calculateDailyStats() {
    double income = 0;
    double expense = 0;
    for (var t in allTransactions) {
      final num? sumVal = t['sum'] ?? t['amount'];
      if (sumVal != null) {
        double amt = sumVal.toDouble();
        amt > 0 ? income += amt : expense += amt;
      }
    }
    return {"income": income, "expense": expense.abs()};
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateDailyStats();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.billName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              "Остаток: ${currentBillBalance.toStringAsFixed(2)} ${widget.currencySymbol}",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: "Статистика",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BillStatisticsPage(
                    billId: widget.billId,
                    billName: widget.billName,
                    currencySymbol: widget.currencySymbol,
                  ),
                ),
              );
            },
          ),
          IconButton(
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _isFilterActive,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildActiveFiltersInfo(),
                _buildStatsHeader(stats),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    child: allTransactions.isEmpty
                        ? const Center(child: Text("Нет операций"))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                allTransactions.length + (hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == allTransactions.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final t = allTransactions[index];
                              bool showHeader =
                                  index == 0 ||
                                  t['transactionDate'] !=
                                      allTransactions[index -
                                          1]['transactionDate'];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showHeader)
                                    _buildDateHeader(
                                      t['transactionDate'] ?? '',
                                    ),
                                  _buildTransactionTile(t),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: AppFloatingButton(
        onPressed: () => _openTransactionForm(),
      ),
    );
  }

  Widget _buildStatsHeader(Map<String, double> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statColumn("Доход", stats['income']!, Colors.green),
          _statColumn("Расход", stats['expense']!, Colors.red),
        ],
      ),
    );
  }

  Widget _statColumn(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          "${val.toStringAsFixed(2)} ${widget.currencySymbol}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(String dateStr) {
    if (dateStr.isEmpty) return const SizedBox.shrink();
    try {
      String formatted = DateFormat(
        'EEEE, d MMMM',
        'ru',
      ).format(DateTime.parse(dateStr));
      return Padding(
        padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
        child: Text(
          formatted.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
            letterSpacing: 1.2,
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildTransactionTile(Map<String, dynamic> t) {
    final num sumVal = t['sum'] ?? t['amount'] ?? 0;
    final isExpense = sumVal < 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isExpense ? Colors.red : Colors.green).withValues(
            alpha: 0.1,
          ),
          child: Icon(
            isExpense ? Icons.remove : Icons.add,
            color: isExpense ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          t['description']?.isEmpty ?? true ? "Без описания" : t['description'],
        ),
        subtitle: Text(t['categoryName'] ?? "Без категории"),
        trailing: Text(
          "$sumVal ${widget.currencySymbol}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExpense ? Colors.red : Colors.green,
          ),
        ),
        onTap: () => _openTransactionForm(existing: t),
      ),
    );
  }

  void _openTransactionForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => TransactionForm(
        existing: existing,
        categories: categories,
        currencySymbol: widget.currencySymbol,
        isCategoryEditable: (cat) => true,
        onCategoryTap: (callback) =>
            _showCategoryPicker((id, [name]) => callback(id, name)),
        onSave: (data) => _checkLimitAndSave(data, existing),
        onDelete: () async {
          final dynamic txId =
              existing?['idTransaction'] ??
              existing?['id'] ??
              existing?['transactionId'];
          if (txId == null) return;

          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text("Удаление"),
              content: const Text("Вы уверены?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text("ОТМЕНА"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text(
                    "УДАЛИТЬ",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true && await api.deleteTransaction(txId)) {
            await _initialLoad();
            if (ctx.mounted) Navigator.pop(ctx);
          }
        },
      ),
    );
  }

  void _showCategoryPicker(Function(int, [String?]) onSelect) {
    showDialog(
      context: context,
      builder: (ctx) => CategorySearchPicker(
        billId: widget.billId,
        currencySymbol: widget.currencySymbol,
        onSelect: (id, [name]) {
          onSelect(id, name);
        },
        onChanged: _initialLoad,
      ),
    );
  }

  Future<void> _checkLimitAndSave(
    Map<String, dynamic> data,
    Map<String, dynamic>? existing,
  ) async {
    final num? rawAmount = data['sum'] ?? data['amount'];
    if (rawAmount == null) return;

    final double amount = rawAmount.toDouble();
    final int? categoryId = data['categoryId'];

    if (amount < 0 && categoryId != null) {
      try {
        final limitStatus = await api.checkLimit(
          billId: widget.billId,
          categoryId: categoryId,
          amount: amount.abs(),
        );

        if (limitStatus['exceeded'] == true) {
          final double diff = (limitStatus['diff'] as num? ?? 0.0).toDouble();
          if (!mounted) return;

          bool confirm =
              await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 10),
                      Text("Лимит превышен"),
                    ],
                  ),
                  content: Text(
                    "Эта операция превысит лимит по категории на ${diff.toStringAsFixed(2)} ${widget.currencySymbol}.\n\nВсё равно сохранить?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("ОТМЕНА"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        "СОХРАНИТЬ",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ) ??
              false;

          if (!confirm) return;
        }
      } catch (e) {
        debugPrint("Ошибка проверки лимита: $e");
      }
    }

    try {
      if (existing != null) {
        final dynamic txId =
            existing['idTransaction'] ??
            existing['id'] ??
            existing['transactionId'];
        await api.updateTransaction(txId, data);
      } else {
        await api.addTransaction({...data, "billId": widget.billId});
      }
      await _initialLoad();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Ошибка сохранения: $e");
    }
  }

  void _openFilters() async {
    final result = await Navigator.push<TransactionFilters>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialFilters: _currentFilters,
          categories: categories,
        ),
      ),
    );

    if (result != null) {
      _currentFilters = result;
      _initialLoad();
    }
  }

  Widget _buildActiveFiltersInfo() {
    if (!_isFilterActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Применены фильтры",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () {
              _currentFilters = TransactionFilters();
              _initialLoad();
            },
            child: Text(
              "Сбросить",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

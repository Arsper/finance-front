import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/Pages/Transactions/components/components/filter_screen.dart';
import 'package:my_app/Pages/Transactions/components/transaction_filter_service.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';

// Подключенные компоненты
import 'components/transaction_form.dart';
import 'components/limit_manage_dialog.dart';
import 'components/category_search_picker.dart';
import 'components/category_manage_dialog.dart';

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

  bool get _isFilterActive => !_currentFilters.isEmpty;
  List<dynamic> allTransactions = [];
  List<dynamic> filteredTransactions = [];
  List<dynamic> categories = [];
  List<dynamic> activeLimits = [];
  bool isLoading = true;
  double currentBillBalance = 0.0;

  // Используем вынесенную модель фильтров
  TransactionFilters _currentFilters = TransactionFilters();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        api.getTransactions(billId: widget.billId).catchError((e) => []),
        api.getCategories().catchError((e) => []),
        api.getWallets().catchError((e) => []),
        api.getLimits(widget.billId).catchError((e) => []),
      ]);

      final List<dynamic> wallets = results[2];
      final currentWallet = wallets.firstWhere(
        (w) => w['billId'] == widget.billId,
        orElse: () => {'currentBalance': 0.0},
      );

      if (!mounted) return;
      setState(() {
        allTransactions = results[0];
        categories = results[1];
        activeLimits = results[3];
        currentBillBalance = (currentWallet['currentBalance'] as num)
            .toDouble();
        _applyFilter();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      filteredTransactions = TransactionFilterService.apply(
        transactions: allTransactions,
        filters: _currentFilters,
      );
    });
  }

  Map<String, double> _calculateDailyStats() {
    double income = 0;
    double expense = 0;
    for (var t in filteredTransactions) {
      double amt = (t['amount'] as num).toDouble();
      amt > 0 ? income += amt : expense += amt;
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
            Text(widget.billName, style: const TextStyle(fontSize: 16)),
            Text(
              "Остаток: ${currentBillBalance.toStringAsFixed(2)} ${widget.currencySymbol}",
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible:
                  _isFilterActive, // Показываем точку, если фильтр включен
              child: const Icon(Icons.tune), // Иконка фильтров
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildActiveFiltersInfo(), // Новая панель сверху
                _buildStatsHeader(stats),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: filteredTransactions.isEmpty
                        ? const Center(child: Text("Нет операций"))
                        : ListView.builder(
                            itemCount: filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final t = filteredTransactions[index];
                              bool showHeader =
                                  index == 0 ||
                                  t['transactionDate'] !=
                                      filteredTransactions[index -
                                          1]['transactionDate'];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showHeader)
                                    _buildDateHeader(t['transactionDate']),
                                  _buildTransactionTile(t),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransactionForm(),
        child: const Icon(Icons.add),
      ),
    );
  }


  Widget _buildStatsHeader(Map<String, double> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
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
  }

  Widget _buildTransactionTile(Map<String, dynamic> t) {
    final isExpense = (t['amount'] as num) < 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isExpense ? Colors.red : Colors.green).withOpacity(
            0.1,
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
          "${t['amount']} ${widget.currencySymbol}",
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
        isCategoryEditable: (cat) => cat['userId'] != null,
        onAddCategory: () => _openCategoryManage(),
        onEditCategory: (cat) => _openCategoryManage(existing: cat),
        onCategoryTap: (callback) => _showCategoryPicker((id) => callback(id)),
        onDelete: () async {
          final dynamic txId = existing?['id'] ?? existing?['transactionId'];
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
            await _loadData();
            if (ctx.mounted) Navigator.pop(ctx);
          }
        },
        onSave: (data) => _checkLimitAndSave(data, existing),
      ),
    );
  }

  void _showCategoryPicker(Function(int) onSelect) {
    showDialog(
      context: context,
      builder: (ctx) => CategorySearchPicker(
        categories: categories,
        activeLimits: activeLimits,
        onSelect: (id) {
          onSelect(id);
          Navigator.pop(ctx);
        },
        onManageLimit: (id, limit) {
          Navigator.pop(ctx);
          _openLimitDialog(id, limit);
        },
      ),
    );
  }

  void _openLimitDialog(int categoryId, dynamic existingLimit) {
    showDialog(
      context: context,
      builder: (ctx) => LimitManageDialog(
        categoryId: categoryId,
        existingLimit: existingLimit,
        onSave: (data) async {
          final success = existingLimit == null
              ? await api.addLimit({...data, "walletId": widget.billId})
              : await api.updateLimit(existingLimit['id'], data);
          if (success) {
            await _loadData();
            if (ctx.mounted) Navigator.pop(ctx);
          }
        },
        onDelete: (id) async {
          if (await api.deleteLimit(id)) {
            await _loadData();
            if (ctx.mounted) Navigator.pop(ctx);
          }
        },
      ),
    );
  }

  void _openCategoryManage({Map<String, dynamic>? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => CategoryManageDialog(
        existing: existing,
        onSave: (data) async {
          final ok = existing == null
              ? await api.addCategory(data)
              : await api.updateCategory(existing['categoryId'], data);
          if (ok) {
            _loadData();
            if (ctx.mounted) Navigator.pop(ctx);
          }
        },
        onDelete: (id) async {
          if (await api.deleteCategory(id)) {
            _loadData();
            if (ctx.mounted) Navigator.pop(ctx);
          }
        },
      ),
    );
  }

  Future<void> _checkLimitAndSave(
    Map<String, dynamic> data,
    Map<String, dynamic>? existing,
  ) async {
    final double amount = (data['amount'] as num).toDouble();
    final int? categoryId = data['categoryId'];

    if (amount < 0 && categoryId != null) {
      try {
        final limitStatus = await api.checkLimit(
          billId: widget.billId,
          categoryId: categoryId,
          amount: amount.abs(),
        );

        if (limitStatus['exceeded'] == true) {
          final double diff = (limitStatus['diff'] as num).toDouble();
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
                    "Эта операция превысит лимит по категории на ${diff.toStringAsFixed(2)} ${widget.currencySymbol}.\n\n"
                    "Всё равно сохранить?",
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
        final dynamic txId = existing['id'] ?? existing['transactionId'];
        await api.updateTransaction(txId, data);
      } else {
        await api.addTransaction({...data, "billId": widget.billId});
      }
      await _loadData();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Ошибка сохранения: $e");
    }
  }

  void _openFilters() async {
    // Вызываем наш новый экран (который мы создадим в отдельном файле)
    final result = await Navigator.push<TransactionFilters>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialFilters: _currentFilters,
          categories: categories,
        ),
      ),
    );

    // Если пользователь нажал "Применить" (вернул результат), обновляем список
    if (result != null) {
      setState(() {
        _currentFilters = result;
        _applyFilter();
      });
    }
  }

  Widget _buildActiveFiltersInfo() {
    if (!_isFilterActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
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
              setState(() {
                _currentFilters = TransactionFilters(); // Сброс
                _applyFilter();
              });
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  List<dynamic> allTransactions = [];
  List<dynamic> filteredTransactions = [];
  List<dynamic> categories = [];
  List<dynamic> activeLimits = [];
  bool isLoading = true;
  double currentBillBalance = 0.0;
  DateTime? selectedFilterDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        api.getTransactions(billId: widget.billId),
        api.getCategories(),
        api.getWallets(),
        api.getLimits(widget.billId),
      ]);

      final wallets = results[2];
      final currentWallet = wallets.firstWhere(
        (w) => w['billId'] == widget.billId,
        orElse: () => {'currentBalance': 0.0},
      );

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
      debugPrint("Ошибка загрузки: $e");
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    if (selectedFilterDate == null) {
      filteredTransactions = allTransactions;
    } else {
      String formattedDate = DateFormat(
        'yyyy-MM-dd',
      ).format(selectedFilterDate!);
      filteredTransactions = allTransactions
          .where((t) => t['transactionDate'] == formattedDate)
          .toList();
    }
  }

  Map<String, double> _calculateDailyStats() {
    double income = 0;
    double expense = 0;
    for (var t in filteredTransactions) {
      double amt = (t['amount'] as num).toDouble();
      if (amt > 0) {
        income += amt;
      } else {
        expense += amt;
      }
    }
    return {"income": income, "expense": expense.abs()};
  }

  // --- МЕТОДЫ ВЫЗОВА КОМПОНЕНТОВ ---

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
        onCategoryTap: (callback) {
          _showCategoryPicker((id) {
            callback(id);
          });
        },
        onSave: (data) async {
          final ok = existing == null
              ? await api.addTransaction({...data, "billId": widget.billId})
              : await api.updateTransaction(existing['id'], data);
          if (ok) {
            _loadData();
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
          }
        },
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
              ? await api.addLimit({...data, "billId": widget.billId})
              : await api.updateLimit(existingLimit['id'], data);
          if (success) {
            _loadData();
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
          }
        },
        onDelete: (id) async {
          if (await api.deleteLimit(id)) {
            _loadData();
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
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
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
          }
        },
        onDelete: (id) async {
          if (await api.deleteCategory(id)) {
            _loadData();
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
          }
        },
      ),
    );
  }

  // --- UI СТРАНИЦЫ ---

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
          if (selectedFilterDate != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                selectedFilterDate = null;
                _applyFilter();
              }),
            ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2101),
              );
              if (picked != null) {
                setState(() {
                  selectedFilterDate = picked;
                  _applyFilter();
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
}

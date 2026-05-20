import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/AppFloatingButton.dart';
import 'package:my_app/Pages/Transactions/components/BillStatisticsPage.dart';
import 'package:my_app/Pages/Transactions/components/filter_screen.dart';
import 'package:my_app/Pages/Transactions/components/transaction_filter_service.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/api/sources/local_storage_service.dart';
import 'package:my_app/repositories/transaction_repository.dart';
import 'package:my_app/repositories/wallet_repository.dart';
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
  late final TransactionRepository repository;
  final LocalStorageService localStorage = LocalStorageService();
  final ScrollController _scrollController = ScrollController();

  bool get _isFilterActive => !_currentFilters.isEmpty;
  List<Map<String, dynamic>> allTransactions = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> activeLimits = [];

  bool isLoading = true;
  bool isLoadMoreLoading = false;
  bool hasMore = true;
  int currentPage = 0;
  final int pageSize = 20;

  double currentBillBalance = 0.0;
  TransactionFilters _currentFilters = TransactionFilters();
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    repository = TransactionRepository(
      UserRemoteDataSource(dio: Dioclient.instance),
      localStorage,
    );
    _initialLoad();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
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
    });

    final cachedTx = await localStorage.getTransactions(widget.billId);
    final cachedWallets = await localStorage.getWallets();
    final cachedCategories = await localStorage.getCategories();

    final currentWallet = cachedWallets.firstWhere(
      (w) => w['billId']?.toString() == widget.billId.toString(),
      orElse: () => {'currentBalance': 0.0},
    );

    if (mounted && cachedTx.isNotEmpty) {
      final List<Map<String, dynamic>> localCategories =
          List<Map<String, dynamic>>.from(cachedCategories);

      final List<Map<String, dynamic>> enrichedCachedTx = cachedTx
          .where((tx) => tx['localDeleted'] != true)
          .map((tx) {
            final Map<String, dynamic> mutableTx = Map<String, dynamic>.from(
              tx,
            );
            final int? catId = int.tryParse(
              mutableTx['categoryId']?.toString() ?? '',
            );

            if (catId != null && localCategories.isNotEmpty) {
              final foundCat = localCategories.firstWhere((c) {
                final dynamic rawId =
                    c['categoryId'] ?? c['id'] ?? c['idCategory'];
                return rawId?.toString() == catId.toString();
              }, orElse: () => <String, dynamic>{});
              if (foundCat.isNotEmpty) {
                final String? actualName =
                    (foundCat['name'] ?? foundCat['categoryName'])?.toString();
                if (actualName != null) {
                  mutableTx['categoryName'] = actualName;
                }
              }
            }
            return mutableTx;
          })
          .toList();

      final sortedCachedTx = TransactionFilterService.apply(
        transactions: enrichedCachedTx,
        filters: _currentFilters,
      );

      setState(() {
        final int end = sortedCachedTx.length > pageSize
            ? pageSize
            : sortedCachedTx.length;
        allTransactions = List<Map<String, dynamic>>.from(
          sortedCachedTx.sublist(0, end),
        );
        categories = localCategories;
        currentBillBalance = (currentWallet['currentBalance'] as num? ?? 0.0)
            .toDouble();
        isLoading = false;
      });
    }

    final bool online = await repository.isServerAvailable();
    if (mounted) setState(() => isOffline = !online);

    if (!online) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final walletRepo = WalletRepository(
        remoteDataSource: repository.remote,
        localDataSource: localStorage,
      );
      await repository.syncOfflineTransactions();

      await walletRepo.syncOfflineWallets();
    } catch (e) {
      debugPrint(
        "UI [SYNC] ERROR: Ошибка при последовательной очистке оффлайн-очереди: $e",
      );
    }

    try {
      final walletRepo = WalletRepository(
        remoteDataSource: repository.remote,
        localDataSource: localStorage,
      );

      final results = await Future.wait([
        repository.getTransactions(
          billId: widget.billId,
          page: currentPage,
          size: pageSize,
          filters: _currentFilters,
        ),
        repository.remote.getCategories().catchError((_) => <dynamic>[]),
        walletRepo.getWallets().catchError((_) => <dynamic>[]),
        repository.remote
            .getLimits(widget.billId)
            .catchError((_) => <dynamic>[]),
      ]);

      final List<dynamic> txResult = results[0];
      final List<dynamic> wallets = results[2];
      final freshWallet = wallets.firstWhere(
        (w) => w['billId']?.toString() == widget.billId.toString(),
        orElse: () => {'currentBalance': 0.0},
      );

      if (results[1].isNotEmpty) await localStorage.saveCategories(results[1]);

      if (!mounted) return;
      setState(() {
        allTransactions = List<Map<String, dynamic>>.from(txResult);
        categories = results[1].isNotEmpty
            ? List<Map<String, dynamic>>.from(results[1])
            : categories;
        activeLimits = List<Map<String, dynamic>>.from(results[3]);
        currentBillBalance = (freshWallet['currentBalance'] as num? ?? 0.0)
            .toDouble();

        if (txResult.length < pageSize) {
          hasMore = false;
        }
        currentPage++;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Ошибка обновления данных через сеть: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (isLoadMoreLoading || !hasMore || isOffline) return;

    setState(() => isLoadMoreLoading = true);

    try {
      final List<dynamic> newTx = await repository.getTransactions(
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
        allTransactions.addAll(List<Map<String, dynamic>>.from(newTx));
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
    final bool hasPendingSync = allTransactions.any(
      (tx) => tx['localUpdated'] == true || tx['isSynced'] == false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.billName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isOffline) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.cloud_off,
                    size: 14,
                    color: hasPendingSync ? Colors.orange : Colors.grey,
                  ),
                ],
              ],
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
            onPressed: isOffline
                ? null
                : () {
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
                                allTransactions.length +
                                (hasMore && !isOffline ? 1 : 0),
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
        onPressed: () {
          _openTransactionForm();
        },
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
    final parsedDate = DateTime.tryParse(dateStr);
    if (parsedDate == null) return const SizedBox.shrink();

    try {
      String formatted = DateFormat('EEEE, d MMMM', 'ru').format(parsedDate);
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

    final bool isLocalChanged =
        (t['localUpdated'] == true) || (t['isSynced'] == false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLocalChanged
              ? Colors.orange.withValues(alpha: 0.8)
              : Colors.grey.withValues(alpha: 0.1),
          width: isLocalChanged ? 1.5 : 1.0,
        ),
      ),
      color: isLocalChanged
          ? Colors.orange.withValues(alpha: 0.04)
          : Theme.of(context).cardColor,
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                (t['description'] == null ||
                        t['description'].toString().isEmpty)
                    ? "Без описания"
                    : t['description'],
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isLocalChanged) ...[
              const SizedBox(width: 6),
              const Tooltip(
                message: "Изменено локально (ожидает синхронизации)",
                child: Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(t['categoryName'] ?? "Без категории"),
        trailing: Text(
          "$sumVal ${widget.currencySymbol}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExpense ? Colors.red : Colors.green,
          ),
        ),
        onTap: () {
          _openTransactionForm(existing: t);
        },
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
          if (txId == null) {
            debugPrint(
              "UI Error: Не удалось найти ID транзакции для удаления в переданном объекте.",
            );
            return;
          }

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

          if (confirm == true) {
            try {
              await repository.deleteTransaction(widget.billId, txId);
              await _initialLoad();
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              debugPrint("UI Error: Ошибка при удалении транзакции: $e");
            }
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
    final num? rawAmount = data['amount'] ?? data['sum'];
    if (rawAmount == null) {
      return;
    }

    final double amount = rawAmount.toDouble();
    final int? categoryId = data['categoryId'];

    if (!isOffline && amount < 0 && categoryId != null) {
      try {
        final limitStatus = await repository.remote.checkLimit(
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

          if (!confirm) {
            debugPrint(
              "UI: Пользователь отменил сохранение из-за превышения лимита.",
            );
            return;
          }
        }
      } catch (e) {
        debugPrint(
          "UI Warning: Не удалось проверить лимиты через сервер: $e. Продолжаем сохранение.",
        );
      }
    }

    try {
      if (existing != null) {
        final dynamic txId =
            existing['idTransaction'] ??
            existing['id'] ??
            existing['transactionId'];
        await repository.updateTransaction(widget.billId, txId, data);
      } else {
        await repository.addTransaction(widget.billId, data);
      }
      await _initialLoad();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint(
        "UI Error: Ошибка при сохранении транзакции через репозиторий: $e",
      );
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart'; 
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart';
import 'package:my_app/Pages/StatisticsPage.dart'; 

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
  final UserRemoteDataSource api = UserRemoteDataSource(dio: Dioclient.instance);
  
  List<dynamic> allTransactions = [];
  List<dynamic> filteredTransactions = [];
  List<dynamic> categories = [];
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
      final t = await api.getTransactions(billId: widget.billId);
      final c = await api.getCategories();
      final wallets = await api.getWallets();
      
      final currentWallet = wallets.firstWhere((w) => w['billId'] == widget.billId);

      t.sort((a, b) {
        final dateA = DateTime.parse(a['transactionDate']);
        final dateB = DateTime.parse(b['transactionDate']);
        int cmp = dateB.compareTo(dateA); 
        if (cmp != 0) return cmp;
        return (b['transactionId'] ?? 0).compareTo(a['transactionId'] ?? 0);
      });

      setState(() {
        allTransactions = t;
        categories = c;
        currentBillBalance = (currentWallet['currentBalance'] as num).toDouble();
        _applyFilter();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Ошибка загрузки данных: $e");
      setState(() => isLoading = false);
    }
  }

  bool _isCategoryEditable(Map<String, dynamic> category) {
    return category['isPersonal'] == true;
  }

  void _applyFilter() {
    if (selectedFilterDate == null) {
      filteredTransactions = allTransactions;
    } else {
      String formattedDate = DateFormat('yyyy-MM-dd').format(selectedFilterDate!);
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
      if (amt > 0) income += amt; else expense += amt;
    }
    return {"income": income, "expense": expense.abs()};
  }

  void _showCategoryManageDialog({Map<String, dynamic>? existing, Function? onUpdate}) {
    if (existing != null && !_isCategoryEditable(existing)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Системные категории нельзя изменять"))
        );
      }
      return;
    }

    final _formKey = GlobalKey<FormState>(); 
    final catController = TextEditingController(text: existing?['name'] ?? "");
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? "Новая категория" : "Изменить категорию"),
        content: Form(
          key: _formKey,
          child: CustomerEdit(
            label: "Название",
            icon: Icons.label_outline,
            controller: catController,
            validator: AppValidators.required,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    try {
                      bool success = await api.deleteCategory(existing['categoryId']);
                      if (success) {
                        await _loadData();
                        if (onUpdate != null) onUpdate();
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    } catch (e) {
                       // Error handling
                    }
                  },
                  child: const Text("Удалить", style: TextStyle(color: Colors.red)),
                )
              else
                const SizedBox.shrink(),

              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Отмена"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) { 
                        try {
                          bool ok;
                          if (existing == null) {
                            ok = await api.addCategory({"name": catController.text});
                          } else {
                            ok = await api.updateCategory(existing['categoryId'], {"name": catController.text});
                          }

                          if (ok) {
                            await _loadData();
                            if (onUpdate != null) onUpdate();
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        } catch (e) {
                          // Error handling
                        }
                      }
                    },
                    child: const Text("Сохранить"),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ФОРМА ТРАНЗАКЦИИ ---
  void _openTransactionForm({Map<String, dynamic>? existing}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final _formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
        text: existing != null ? (existing['amount'] as num).abs().toString() : "");
    final descController = TextEditingController(text: existing?['description'] ?? "");
    final dateController = TextEditingController(
        text: existing?['transactionDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    int? selectedCategoryId = existing?['categoryId'];
    bool isIncome = existing != null ? (existing['amount'] as num) > 0 : false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(existing == null ? "Новая операция" : "Редактирование", 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                ToggleButtons(
                  isSelected: [!isIncome, isIncome],
                  onPressed: (index) => setModalState(() => isIncome = index == 1),
                  borderRadius: BorderRadius.circular(10),
                  selectedColor: Colors.white,
                  fillColor: isIncome ? Colors.green : Colors.red,
                  borderColor: colors.outline.withOpacity(0.5),
                  selectedBorderColor: isIncome ? Colors.green : Colors.red,
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 30), child: Text("Расход")),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 30), child: Text("Доход"))
                  ],
                ),
                const SizedBox(height: 15),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedCategoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Категория", 
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category)
                        ),
                        validator: (val) => val == null ? "Выберите категорию" : null,
                        items: categories.map((c) => DropdownMenuItem<int>(
                          value: c['categoryId'], 
                          child: Row(
                            children: [
                              Expanded(child: Text(c['name'], overflow: TextOverflow.ellipsis)),
                              if (!_isCategoryEditable(c))
                                Icon(Icons.lock, size: 14, color: colors.onSurface.withOpacity(0.4))
                            ],
                          )
                        )).toList(),
                        onChanged: (val) => setModalState(() => selectedCategoryId = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _showCategoryManageDialog(onUpdate: () => setModalState(() {})),
                      icon: const Icon(Icons.add),
                    ),
                    Builder(
                      builder: (context) {
                        final selectedCat = categories.firstWhere(
                            (c) => c['categoryId'] == selectedCategoryId, 
                            orElse: () => <String, dynamic>{}
                        );
                        bool canEdit = selectedCategoryId != null && 
                                        selectedCat.isNotEmpty && 
                                        _isCategoryEditable(selectedCat);
                        if (canEdit) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: IconButton.outlined(
                              onPressed: () {
                                _showCategoryManageDialog(
                                  existing: selectedCat, 
                                  onUpdate: () => setModalState(() {
                                    if (!categories.any((c) => c['categoryId'] == selectedCategoryId)) {
                                      selectedCategoryId = null;
                                    }
                                  })
                                );
                              },
                              icon: const Icon(Icons.edit),
                            ),
                          );
                        } else {
                          return const SizedBox.shrink(); 
                        }
                      }
                    ),
                  ],
                ),

                const SizedBox(height: 15),
                
                CustomerEdit(
                  controller: amountController,
                  label: "Сумма",
                  maxLength: 12,
                  icon: isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                  validator: AppValidators.amount,
                ),

                const SizedBox(height: 15),
                
                CustomerEdit(
                  controller: dateController,
                  label: "Дата",
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                  },
                ),

                const SizedBox(height: 15),
                
                CustomerEdit(
                  controller: descController, 
                  label: "Описание",
                  icon: Icons.description_outlined,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 20),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) { 
                      double val = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
                      final data = {
                        "billId": widget.billId,
                        "categoryId": selectedCategoryId,
                        "amount": isIncome ? val : -val,
                        "description": descController.text,
                        "transactionDate": dateController.text,
                      };
                      bool ok = existing == null 
                        ? await api.addTransaction(data) 
                        : await api.updateTransaction(existing['transactionId'], data);
                      if (ok && mounted) { 
                        Navigator.pop(context); 
                        _loadData(); 
                      }
                    }
                  },
                  child: const Text("Сохранить", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
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
          // --- НОВАЯ КНОПКА СТАТИСТИКИ ---
          /*IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Статистика',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatisticsPage(
                    billId: widget.billId,
                    billName: widget.billName,
                  ),
                ),
              );
            },
          ),*/
          // -------------------------------
          
          if (selectedFilterDate != null)
            IconButton(
              icon: const Icon(Icons.close), 
              onPressed: () => setState(() { selectedFilterDate = null; _applyFilter(); })
            ),
          IconButton(
            icon: const Icon(Icons.filter_alt), 
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context, 
                initialDate: DateTime.now(), 
                firstDate: DateTime(2020), 
                lastDate: DateTime(2101)
              );
              if (picked != null) setState(() { selectedFilterDate = picked; _applyFilter(); });
            }
          ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: colors.primary.withOpacity(0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem("Доход", stats['income']!, Colors.green, context),
                      _statItem("Расход", stats['expense']!, Colors.red, context),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: filteredTransactions.isEmpty 
                      ? const Center(child: Text("Ничего не найдено")) 
                      : ListView.builder(
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final t = filteredTransactions[index];
                            final double amount = (t['amount'] as num).toDouble();
                            final bool isPos = amount > 0;
                            bool showHeader = index == 0 || 
                                t['transactionDate'] != filteredTransactions[index - 1]['transactionDate'];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showHeader) _buildDateHeader(t['transactionDate'], context),
                                Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isPos ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                      child: Icon(isPos ? Icons.add : Icons.remove, 
                                          color: isPos ? Colors.green : Colors.red, size: 18),
                                    ),
                                    title: Text(t['categoryName'] ?? "Без категории"),
                                    subtitle: Text(t['description'] ?? ""),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("${isPos ? '+' : ''}${amount.abs().toStringAsFixed(2)} ${widget.currencySymbol}",
                                              style: TextStyle(fontWeight: FontWeight.bold, 
                                                                color: isPos ? Colors.green : Colors.red)),
                                        PopupMenuButton<String>(
                                          onSelected: (val) async {
                                            if (val == 'edit') _openTransactionForm(existing: t);
                                            if (val == 'delete' && await api.deleteTransaction(t['transactionId'])) {
                                              _loadData();
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'edit', child: Text("Изменить")),
                                            const PopupMenuItem(value: 'delete', child: Text("Удалить", 
                                                style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
        child: const Icon(Icons.add)
      ),
    );
  }

  Widget _statItem(String label, double value, Color valueColor, BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text("${value.toStringAsFixed(2)} ${widget.currencySymbol}", 
             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildDateHeader(String dateStr, BuildContext context) {
    String formatted = DateFormat('EEEE, d MMMM', 'ru').format(DateTime.parse(dateStr));
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
      child: Text(formatted.toUpperCase(), 
           style: TextStyle(
             fontSize: 11, 
             fontWeight: FontWeight.bold, 
             color: Theme.of(context).colorScheme.secondary, 
             letterSpacing: 1.2
           )),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/api/DioClient.dart';

class CategorySearchPicker extends StatefulWidget {
  final int billId;
  final String currencySymbol;
  final Function(int id, [String? name]) onSelect;
  final VoidCallback onChanged;

  const CategorySearchPicker({
    super.key,
    required this.billId,
    required this.currencySymbol,
    required this.onSelect,
    required this.onChanged,
  });

  @override
  State<CategorySearchPicker> createState() => _CategorySearchPickerState();
}

class _CategorySearchPickerState extends State<CategorySearchPicker> {
  final UserRemoteDataSource api = UserRemoteDataSource(
    dio: Dioclient.instance,
  );

  List<dynamic> categories = [];
  List<dynamic> activeLimits = [];
  bool isLoading = true;
  String searchQuery = "";
  String filterType = "all";

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  Future<void> _loadCategoryData() async {
    try {
      final results = await Future.wait([
        api.getCategories().catchError((e) => []),
        api.getLimits(widget.billId).catchError((e) => []),
      ]);
      if (mounted) {
        setState(() {
          categories = results[0];
          activeLimits = results[1];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buttonText(String text) {
    return FittedBox(fit: BoxFit.scaleDown, child: Text(text));
  }

  void _openManageCategory({Map<String, dynamic>? existing}) {
    final nameController = TextEditingController(text: existing?['name'] ?? "");
    final formKey = GlobalKey<FormState>();
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              existing == null ? "Новая категория" : "Редактирование",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (existing != null)
              IconButton(
                onPressed: () async {
                  if (await api.deleteCategory(existing['categoryId'])) {
                    widget.onChanged();
                    await _loadCategoryData();
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                icon: Icon(Icons.delete_outline, color: colors.error),
              ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomerEdit(
                controller: nameController,
                label: "Название",
                icon: Icons.label_outline,
                validator: (val) =>
                    (val == null || val.isEmpty) ? "Введите название" : null,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: colors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: _buttonText("ОТМЕНА"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 45),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      widget.onChanged();
                      await _loadCategoryData();
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: _buttonText("СОХРАНИТЬ"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openLimitManage(int categoryId, dynamic existingLimit) {
    final limitController = TextEditingController(
      text: existingLimit != null
          ? existingLimit['limitAmount'].toString()
          : "",
    );
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Лимит на месяц",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (existingLimit != null)
              IconButton(
                onPressed: () async {
                  if (await api.deleteLimit(existingLimit['id'])) {
                    widget.onChanged();
                    await _loadCategoryData();
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                icon: Icon(Icons.delete_outline, color: colors.error),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomerEdit(
              controller: limitController,
              label: "Сумма (${widget.currencySymbol})",
              icon: Icons.speed,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: colors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: _buttonText("ОТМЕНА"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 45),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(limitController.text) ?? 0;
                    final data = {
                      "limitAmount": amount,
                      "categoryId": categoryId,
                      "walletId": widget.billId,
                    };
                    final ok = existingLimit == null
                        ? await api.addLimit(data)
                        : await api.updateLimit(existingLimit['id'], data);
                    if (ok) {
                      widget.onChanged();
                      await _loadCategoryData();
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: _buttonText("ОК"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final filtered = categories.where((c) {
      final bool isPersonal = c['isPersonal'] == true || c['userId'] != null;
      final bool matchesSearch = c['name'].toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      bool matchesType =
          filterType == "all" ||
          (filterType == "personal" ? isPersonal : !isPersonal);
      return matchesSearch && matchesType;
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "Выбор категории",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 550,
        child: Stack(
          children: [
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      CustomerEdit(
                        label: "Поиск...",
                        icon: Icons.search,
                        onChanged: (val) => setState(() => searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildFilterChips(colors),
                      ),
                      const Divider(height: 24),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 70),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final c = filtered[i];
                            final bool isPersonal =
                                c['isPersonal'] == true || c['userId'] != null;
                            final int categoryId = c['categoryId'] ?? c['id'];
                            final limit = activeLimits.firstWhere(
                              (l) =>
                                  l['categoryId'].toString() ==
                                  categoryId.toString(),
                              orElse: () => null,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isPersonal
                                    ? colors.primaryContainer.withValues(
                                        alpha: 0.3,
                                      )
                                    : colors.surfaceContainerHighest.withValues(
                                        alpha: 0.4,
                                      ),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isPersonal
                                      ? colors.primary.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPersonal
                                        ? colors.primary
                                        : colors.secondary.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isPersonal
                                        ? Icons.person_rounded
                                        : Icons.dashboard_customize_outlined,
                                    color: isPersonal
                                        ? colors.onPrimary
                                        : colors.secondary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  c['name'],
                                  style: TextStyle(
                                    fontWeight: isPersonal
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  isPersonal ? "Личная" : "Общая",
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPersonal)
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_note,
                                          color: colors.primary,
                                          size: 22,
                                        ),
                                        onPressed: () =>
                                            _openManageCategory(existing: c),
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        limit != null
                                            ? Icons.alarm_on
                                            : Icons.alarm_add,
                                        color: limit != null
                                            ? Colors.orange
                                            : colors.outline.withValues(
                                                alpha: 0.5,
                                              ),
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          _openLimitManage(categoryId, limit),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  widget.onSelect(categoryId, c['name']);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
            if (!isLoading)
              Positioned(
                bottom: 0,
                right: 0,
                child: FloatingActionButton(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  elevation: 4,
                  onPressed: () => _openManageCategory(),
                  child: const Icon(Icons.add),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme colors) {
    return Row(
      children: ["all", "personal", "system"].map((type) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(
              type == "all"
                  ? "Все"
                  : type == "personal"
                  ? "Личные"
                  : "Общие",
            ),
            selected: filterType == type,
            onSelected: (val) => setState(() => filterType = type),
          ),
        );
      }).toList(),
    );
  }
}

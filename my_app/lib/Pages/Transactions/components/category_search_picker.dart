import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/Pages/Guide/%D1%81ategorySearch_page_guide.dart';
import 'package:my_app/Pages/Guide/guide_manager.dart';
import 'package:my_app/api/sources/local_storage_service.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/helpers/OverlayToastService.dart';
import 'package:my_app/repositories/category_repository.dart';

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
  final CategoryRepository repository = CategoryRepository(
    UserRemoteDataSource(dio: Dioclient.instance),
    LocalStorageService(),
  );
  final GuideManager _guideManager = GuideManager();

  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterChipsKey = GlobalKey();
  final GlobalKey _systemCategoryKey = GlobalKey();
  final GlobalKey _personalCategoryKey = GlobalKey();
  final GlobalKey _limitButtonKey = GlobalKey();
  final GlobalKey _addFabKey = GlobalKey();

  List<dynamic> categories = [];
  List<dynamic> activeLimits = [];
  bool isLoading = false;
  String searchQuery = "";
  String filterType = "all";
  bool isOffline = false;

  bool _isDemoMode = true;

  final List<dynamic> _phantomCategories = [
    {
      'categoryId': -1,
      'name': "Продукты (Демо)",
      'isPersonal': false,
      'userId': null,
    },
    {
      'categoryId': -2,
      'name': "Моё Хобби (Демо)",
      'isPersonal': true,
      'userId': 999,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkAndStartGuide();
  }

  Future<void> _checkAndStartGuide() async {
    final String guideId = 'category_picker_v1';
    final bool alreadySeen = await _guideManager.hasSeenGuide(guideId);

    if (alreadySeen) {
      _switchToRealMode();
      return;
    }

    _guideManager.runGuide(
      showGuide: _triggerGuide,
      onSkippedOrFinished: () {
        _switchToRealMode();
      },
    );
  }

  void _triggerGuide() {
    CategorySearchPickerGuide.show(
      context: context,
      searchKey: _searchKey,
      filterChipsKey: _filterChipsKey,
      systemCategoryKey: _systemCategoryKey,
      personalCategoryKey: _personalCategoryKey,
      limitButtonKey: _limitButtonKey,
      addFabKey: _addFabKey,
      onFinish: () async {
        await _guideManager.markGuideAsSeen('category_picker_v1');
        _switchToRealMode();
      },
      onSkipAll: () async {
        await _guideManager.markGuideAsSeen('category_picker_v1');
        await _guideManager.disableAllGuidesForever();
        _switchToRealMode();
      },
    );
  }

  void _switchToRealMode() {
    if (mounted) {
      setState(() => _isDemoMode = false);
      _loadRealCategoryData();
    }
  }

  Future<void> _loadRealCategoryData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final isOnline = await repository.isServerAvailable();
    if (mounted) setState(() => isOffline = !isOnline);

    final cached = await repository.local.getCategories();
    if (mounted && cached.isNotEmpty) {
      setState(() {
        categories = cached;
        if (!isOnline) isLoading = false;
      });
    }

    if (!isOnline) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final fresh = await repository.getCategories();
      final limits = await repository
          .getLimits(widget.billId)
          .catchError((e) => <dynamic>[]);

      if (mounted) {
        setState(() {
          categories = fresh;
          activeLimits = limits;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _openManageCategory({Map<String, dynamic>? existing}) {
    if (_isDemoMode) return;

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
            Text(existing == null ? "Новая категория" : "Редактирование"),
            if (existing != null && !isOffline)
              IconButton(
                onPressed: () async {
                  if (await repository.deleteCategory(existing['categoryId'])) {
                    widget.onChanged();
                    await _loadRealCategoryData();
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                icon: Icon(Icons.delete_outline, color: colors.error),
              ),
          ],
        ),
        content: Form(
          key: formKey,
          child: CustomerEdit(
            controller: nameController,
            label: "Название",
            icon: Icons.label_outline,
            validator: (val) =>
                (val == null || val.isEmpty) ? "Введите название" : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ОТМЕНА"),
          ),
          ElevatedButton(
            onPressed: isOffline
                ? null
                : () async {
                    if (formKey.currentState!.validate()) {
                      final success = existing == null
                          ? await repository.addCategory(nameController.text)
                          : await repository.updateCategory(
                              existing['categoryId'],
                              nameController.text,
                            );
                      if (success) {
                        widget.onChanged();
                        await _loadRealCategoryData();
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    }
                  },
            child: Text(isOffline ? "ОФЛАЙН" : "СОХРАНИТЬ"),
          ),
        ],
      ),
    );
  }

  void _openLimitManage(int categoryId, dynamic existingLimit) {
    if (_isDemoMode) return;

    final limitController = TextEditingController(
      text: existingLimit != null
          ? existingLimit['limitAmount'].toString()
          : "",
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Лимит на месяц"),
        content: CustomerEdit(
          controller: limitController,
          label: "Сумма",
          icon: Icons.speed,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ОТМЕНА"),
          ),
          ElevatedButton(
            onPressed: isOffline
                ? null
                : () async {
                    final amount = double.tryParse(limitController.text) ?? 0;
                    final data = {
                      "limitAmount": amount,
                      "categoryId": categoryId,
                      "walletId": widget.billId,
                    };
                    final ok = existingLimit == null
                        ? await repository.addLimit(data)
                        : await repository.updateLimit(
                            existingLimit['id'],
                            data,
                          );
                    if (ok) {
                      widget.onChanged();
                      await _loadRealCategoryData();
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
            child: Text(isOffline ? "ОФЛАЙН" : "ОК"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final currentList = _isDemoMode ? _phantomCategories : categories;

    final filtered = currentList.where((c) {
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
      title: Text(
        _isDemoMode ? "Ознакомление" : "Выбор категории",
        style: const TextStyle(fontWeight: FontWeight.bold),
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
                        key: _searchKey,
                        label: "Поиск...",
                        icon: Icons.search,
                        onChanged: (val) => setState(() => searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        key: _filterChipsKey,
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

                            final limit = _isDemoMode
                                ? null
                                : activeLimits.firstWhere(
                                    (l) =>
                                        l['categoryId'].toString() ==
                                        categoryId.toString(),
                                    orElse: () => null,
                                  );

                            Key? containerKey;
                            if (_isDemoMode) {
                              if (!isPersonal) {
                                containerKey = _systemCategoryKey;
                              }
                              if (isPersonal) {
                                containerKey = _personalCategoryKey;
                              }
                            } else {
                              if (i == 0) containerKey = _systemCategoryKey;
                            }

                            return Container(
                              key: containerKey,
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
                                          color: (isOffline && !_isDemoMode)
                                              ? Colors.grey
                                              : colors.primary,
                                          size: 22,
                                        ),
                                        onPressed: () async {
                                          if (await _isNetworkAvailable()) {
                                            _openManageCategory(existing: c);
                                          }
                                        },
                                      ),
                                    IconButton(
                                      key: i == 0 ? _limitButtonKey : null,
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
                                  if (_isDemoMode) return;
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
                  key: _addFabKey,
                  backgroundColor: (isOffline && !_isDemoMode)
                      ? Colors.grey
                      : colors.primary,
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

  Future<bool> _isNetworkAvailable() async {
    final ConnectivityResult connectivityResult = await Connectivity()
        .checkConnectivity();

    if (!mounted) return false;

    if (connectivityResult == ConnectivityResult.none) {
      setState(() => isOffline = true);
      OverlayToastService.show(
        context,
        message: "Нет интернет-соединения.",
        isError: false,
      );
      return false;
    }

    try {
      final bool isOnline = await repository.isServerAvailable();
      if (!mounted) return false;

      setState(() => isOffline = !isOnline);

      if (!isOnline) {
        OverlayToastService.show(
          context,
          message: "Сервер недоступен. Попробуйте позже.",
          isError: false,
        );
        return false;
      }

      return true;
    } catch (e) {
      if (!mounted) return false;

      setState(() => isOffline = true);
      OverlayToastService.show(
        context,
        message: "Ошибка подключения к серверу.",
      );
      return false;
    }
  }
}

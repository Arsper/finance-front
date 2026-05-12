import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../transaction_filter_service.dart';

class FilterScreen extends StatefulWidget {
  final TransactionFilters initialFilters;
  final List<dynamic> categories;

  const FilterScreen({
    super.key,
    required this.initialFilters,
    required this.categories,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late TransactionFilters tempFilters;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    tempFilters = TransactionFilters(
      period: widget.initialFilters.period,
      dateRange: widget.initialFilters.dateRange,
      categoryIds: List<int>.from(widget.initialFilters.categoryIds),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredCategories {
    if (searchQuery.isEmpty) return widget.categories;
    return widget.categories
        .where(
          (c) => c['name'].toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Фильтры"),
        foregroundColor: colorScheme.onSurface,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                tempFilters = TransactionFilters();
                searchQuery = "";
                _searchController.clear();
              });
            },
            child: Text(
              "Сброс",
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Верхняя статичная часть с Flexible, чтобы не ломалась от клавиатуры
          Flexible(
            flex: 0,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Период",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ГОРИЗОНТАЛЬНАЯ ПРОКРУТКА КНОПОК
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: ['all', 'day', 'week', 'month'].map((p) {
                          final labels = {
                            'all': 'Все',
                            'day': 'День',
                            'week': 'Неделя',
                            'month': 'Месяц',
                          };
                          final isSelected = tempFilters.period == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(labels[p]!),
                              selected: isSelected,
                              labelStyle: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                              selectedColor: colorScheme.primary,
                              onSelected: (val) {
                                setState(() {
                                  tempFilters.period = p;
                                  tempFilters.dateRange =
                                      TransactionFilterService.calculateRange(p);
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Произвольный диапазон",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: colorScheme.brightness == Brightness.dark
                          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      leading: Icon(
                        Icons.calendar_month,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      title: Text(
                        tempFilters.dateRange == null
                            ? "Выбрать даты"
                            : "${DateFormat('dd.MM.yy').format(tempFilters.dateRange!.start)} - ${DateFormat('dd.MM.yy').format(tempFilters.dateRange!.end)}",
                        style: TextStyle(
                          fontSize: 14,
                          color: tempFilters.dateRange != null
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      onTap: () async {
                        DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                          initialDateRange: tempFilters.dateRange,
                        );
                        if (picked != null) {
                          setState(() {
                            tempFilters.period = 'custom';
                            tempFilters.dateRange = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Категории",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (tempFilters.categoryIds.isNotEmpty)
                          Text(
                            "Выбрано: ${tempFilters.categoryIds.length}",
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Поиск категории...",
                          prefixIcon: Icon(Icons.search, color: colorScheme.primary, size: 20),
                          filled: true,
                          fillColor: colorScheme.brightness == Brightness.dark
                              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) => setState(() => searchQuery = val),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // Список категорий (основной скролл)
          Expanded(
            child: _filteredCategories.isEmpty
                ? Center(
                    child: Text(
                      "Ничего не найдено",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredCategories.length,
                    itemBuilder: (ctx, i) {
                      final cat = _filteredCategories[i];
                      final isSelected = tempFilters.categoryIds.contains(
                        cat['categoryId'],
                      );
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: colorScheme.primary,
                        title: Text(
                          cat['name'],
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                        ),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              tempFilters.categoryIds.add(cat['categoryId']);
                            } else {
                              tempFilters.categoryIds.remove(cat['categoryId']);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, tempFilters),
            child: const Text(
              "ПРИМЕНИТЬ",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
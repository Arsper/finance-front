import 'package:flutter/material.dart';

class CategorySearchPicker extends StatefulWidget {
  final List<dynamic> categories;
  final List<dynamic> activeLimits;
  final Function(int) onSelect;
  final Function(int categoryId, Map<String, dynamic>? existingLimit)
  onManageLimit;

  const CategorySearchPicker({
    super.key,
    required this.categories,
    required this.activeLimits,
    required this.onSelect,
    required this.onManageLimit,
  });

  @override
  State<CategorySearchPicker> createState() => _CategorySearchPickerState();
}

class _CategorySearchPickerState extends State<CategorySearchPicker> {
  String searchQuery = "";
  String filterType = "all"; 

  @override
  Widget build(BuildContext context) {
    // Получаем текущую схему цветов (адаптируется под тему автоматически)
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final filtered = widget.categories.where((c) {
      final bool isPersonal = c['isPersonal'] == true || c['userId'] != null;
      final bool matchesSearch = c['name'].toLowerCase().contains(searchQuery.toLowerCase());
      
      bool matchesType = true;
      if (filterType == "personal") matchesType = isPersonal;
      if (filterType == "system") matchesType = !isPersonal;

      return matchesSearch && matchesType;
    }).toList();

    return AlertDialog(
      // Убираем жесткий цвет фона, используем системный surface
      backgroundColor: colors.surface,
      title: Text(
        "Выбор категории", 
        style: TextStyle(color: colors.onSurface) // Адаптивный цвет заголовка
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            TextField(
              // Используем onSurface для текста внутри поля
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: "Поиск по названию...",
                hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
                // Границы поля теперь зависят от темы
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colors.primary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
            const SizedBox(height: 16),
            
            // Тематические фильтры
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("Все", "all", colors),
                  const SizedBox(width: 8),
                  _buildFilterChip("Личные", "personal", colors),
                  const SizedBox(width: 8),
                  _buildFilterChip("Общие", "system", colors),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: filtered.isEmpty 
                ? Center(child: Text("Ничего не найдено", style: TextStyle(color: colors.onSurfaceVariant)))
                : ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final c = filtered[i];
                  final bool isPersonal = c['isPersonal'] == true || c['userId'] != null;

                  final limit = widget.activeLimits.firstWhere(
                    (l) => l['categoryId'].toString() == c['categoryId'].toString(),
                    orElse: () => null,
                  );

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(
                      isPersonal ? Icons.person_pin_rounded : Icons.category_rounded,
                      color: isPersonal ? colors.primary : colors.onSurfaceVariant,
                    ),
                    title: Text(
                      c['name'], 
                      style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w500)
                    ),
                    subtitle: isPersonal 
                      ? Text("Личная категория", style: TextStyle(color: colors.primary, fontSize: 11)) 
                      : null,
                    trailing: Icon(
                      limit != null ? Icons.timer : Icons.timer_outlined,
                      color: limit != null ? Colors.orange : colors.onSurfaceVariant.withValues(alpha: 0.3),
                      size: 20,
                    ),
                    onTap: () => widget.onSelect(c['categoryId']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("ОТМЕНА", style: TextStyle(color: colors.primary)),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String type, ColorScheme colors) {
    final bool isSelected = filterType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => filterType = type),
      // Цвета чипов на базе Material 3
      selectedColor: colors.primaryContainer,
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colors.primary : colors.outlineVariant,
        ),
      ),
      showCheckmark: false, // Убираем галочку для чистоты интерфейса
    );
  }
}
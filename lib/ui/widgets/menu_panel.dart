import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../state/cart_state.dart';
import '../theme.dart';
import 'common.dart';

class MenuPanel extends StatefulWidget {
  const MenuPanel({super.key, required this.searchFocus});

  final FocusNode searchFocus;

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  final _search = TextEditingController();
  String _category = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cart = context.watch<CartState>();
    final products = app.products;
    final categories = <String, String>{};
    final counts = <String, int>{};
    for (final product in products) {
      for (final category in product.categories) {
        categories[category.id] = category.name;
        counts[category.id] = (counts[category.id] ?? 0) + 1;
      }
    }
    if (_category != 'all' && !categories.containsKey(_category)) _category = 'all';
    final term = _search.text.trim().toLowerCase();
    final visible = products.where((product) {
      final inCategory = _category == 'all' || product.categoryIds.contains(_category);
      return inCategory && (term.isEmpty || product.name.toLowerCase().contains(term));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: widget.searchFocus,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن صنف... (اضغط / للبحث)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (visible.isNotEmpty) {
                      cart.add(visible.first);
                      _search.clear();
                      setState(() {});
                      widget.searchFocus.requestFocus();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => app.loadMenu(),
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث المنيو',
              ),
            ],
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _CategoryChip(
                label: 'كل الأصناف',
                count: products.length,
                selected: _category == 'all',
                onTap: () => setState(() => _category = 'all'),
              ),
              for (final entry in categories.entries)
                _CategoryChip(
                  label: entry.value,
                  count: counts[entry.key] ?? 0,
                  selected: _category == entry.key,
                  onTap: () => setState(() => _category = entry.key),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                _category == 'all' ? 'كل أصناف المنيو' : categories[_category] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const Spacer(),
              Text('${visible.length} صنف', style: const TextStyle(color: PosColors.muted, fontSize: 12)),
              if (app.menuCachedAt != null) ...[
                const SizedBox(width: 8),
                const StatusPill(label: 'منيو محفوظ', color: PosColors.warning, icon: Icons.offline_bolt_outlined),
              ],
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? EmptyHint(
                  products.isEmpty
                      ? 'لا توجد أصناف في المنيو. اربط صنف بيع بقسم قائمة نشط أولاً.'
                      : 'لا توجد أصناف تطابق البحث في هذا القسم.',
                  icon: Icons.restaurant_menu_outlined,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 175,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => _ProductCard(
                    product: visible[index],
                    imageUrl: app.api?.resolveUrl(visible[index].image) ?? '',
                    onTap: () => cart.add(visible[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: PosColors.brand,
          labelStyle: TextStyle(
            color: selected ? Colors.white : PosColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.imageUrl, required this.onTap});

  final PosProduct product;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    return Material(
      color: PosColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                        errorBuilder: (context, error, stack) => const _ProductPlaceholder(),
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : const _ProductPlaceholder(),
                      )
                    : const _ProductPlaceholder(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.price} ج.م',
                      style: const TextStyle(color: PosColors.brand, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: PosColors.surface,
        alignment: Alignment.center,
        child: const Icon(Icons.local_cafe_outlined, size: 32, color: PosColors.border),
      );
}
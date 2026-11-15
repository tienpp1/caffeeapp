import 'package:flutter/material.dart';

import 'product.dart';
import 'helper.dart';
import 'local_database.dart';
import 'session_helper.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key, required this.title});
  final String title;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final _database = LocalDatabase.instance;
  static const _pageSize = 3;
  Future<Product?>? _product;
  Future<PageResult<Product>>? _related;
  int _relatedPage = 1;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _product ??= _loadProduct();
  }

  Future<Product?> _loadProduct() async {
    final id = ModalRoute.of(context)?.settings.arguments;
    if (id is! int) return null;
    final product = await _database.product(id);
    if (product != null && mounted) _related = _queryRelated(product);
    return product;
  }

  Future<PageResult<Product>> _queryRelated(Product product) =>
      _database.products(
        categoryId: product.categoryId,
        excludeId: product.id,
        page: _relatedPage,
        pageSize: _pageSize,
      );

  void _reloadProduct() {
    setState(() {
      _product = _loadProduct();
    });
  }

  Future<void> _add(Product product) async {
    setState(() => _saving = true);
    try {
      if (SessionHelper.current.value == null) {
        await Navigator.pushNamed(context, '/login');
      }
      final member = SessionHelper.current.value;
      if (!mounted || member == null) return;
      if (member.isAdmin) {
        showMessage(context, 'Đăng nhập bằng tài khoản Member để gọi món.');
        return;
      }
      await _database.addToCart(member.id, product.id);
      if (mounted) showMessage(context, 'Đã thêm món vào giỏ món.');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCart() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await Navigator.pushNamed(context, '/cart');
    if (mounted) _reloadProduct();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<Product?>(
      future: _product,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return LoadError(error: snapshot.error, retry: _reloadProduct);
        }
        final product = snapshot.data;
        if (product == null) {
          return const Center(child: Text('Món này không còn trong thực đơn.'));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;
            final inset = wide ? 36.0 : 20.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(inset, wide ? 30 : 8, inset, 40),
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 11, child: _photo(product, wide)),
                          const SizedBox(width: 54),
                          Expanded(flex: 9, child: _productInfo(product, wide)),
                        ],
                      )
                    else ...[
                      _photo(product, wide),
                      const SizedBox(height: 24),
                      _productInfo(product, wide),
                    ],
                    SizedBox(height: wide ? 50 : 32),
                    _relatedProducts(product, wide),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Widget _photo(Product product, bool wide) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(wide ? 24 : 18),
      child: AspectRatio(
        aspectRatio: wide ? 1.18 : 1.42,
        child: ColoredBox(
          color: const Color(0xFFECE1D2),
          child: ProductImage(
            asset: product.imageUrl,
            imageId: product.imageId,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _productInfo(Product product, bool wide) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final available = product.stock > 0;
    final stockColor = available ? colors.primary : colors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: stockColor.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                available
                    ? Icons.check_circle_outline
                    : Icons.remove_circle_outline,
                color: stockColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                available ? 'Còn ${product.stock} phần' : 'Hết món',
                style: theme.textTheme.labelMedium?.copyWith(color: stockColor),
              ),
            ],
          ),
        ),
        SizedBox(height: wide ? 19 : 12),
        Text(
          product.name,
          style:
              (wide
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(fontFamily: 'Playfair Display', height: 1.16),
        ),
        const SizedBox(height: 10),
        Text(
          money(product.price),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (product.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            product.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.65,
            ),
          ),
        ],
        const SizedBox(height: 22),
        ValueListenableBuilder(
          valueListenable: SessionHelper.current,
          builder: (context, member, _) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (member?.isAdmin != true)
                FilledButton.icon(
                  onPressed: _saving || !available ? null : () => _add(product),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_shopping_cart_outlined, size: 19),
                  label: Text(available ? 'Thêm vào giỏ món' : 'Tạm hết món'),
                ),
              if (member != null && !member.isAdmin)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _openCart,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 19),
                  label: const Text('Xem giỏ món'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _relatedProducts(Product product, bool wide) =>
      FutureBuilder<PageResult<Product>>(
        future: _related,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return LoadError(
              error: snapshot.error,
              retry: () => setState(() {
                _related = _queryRelated(product);
              }),
            );
          }
          final result = snapshot.data;
          if (result == null || result.items.isEmpty) {
            return const SizedBox.shrink();
          }
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 22),
              Text('Món liên quan', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 10.0;
                  final cardWidth = wide
                      ? (constraints.maxWidth - gap * 2) / 3
                      : constraints.maxWidth;
                  return Wrap(
                    runSpacing: gap,
                    spacing: gap,
                    children: [
                      for (final item in result.items)
                        SizedBox(width: cardWidth, child: _relatedTile(item)),
                    ],
                  );
                },
              ),
              Center(
                child: PagingControls(
                  page: _relatedPage,
                  total: result.total,
                  pageSize: _pageSize,
                  onChanged: (page) => setState(() {
                    _relatedPage = page;
                    _related = _queryRelated(product);
                  }),
                ),
              ),
            ],
          );
        },
      );

  Widget _relatedTile(Product item) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, '/details', arguments: item.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: ProductImage(
                  asset: item.imageUrl,
                  imageId: item.imageId,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      money(item.price),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_catalog_widgets.dart';
import 'category.dart';
import 'helper.dart';
import 'local_database.dart';
import 'member.dart';
import 'product.dart';
import 'session_helper.dart';

class ProductAdminPage extends StatelessWidget {
  const ProductAdminPage({super.key, this.title = 'Quản lý món'});

  final String title;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Member?>(
    valueListenable: SessionHelper.current,
    builder: (context, member, child) {
      if (member == null || !member.active || !member.isAdmin) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const WorkspaceEmpty(
            icon: Icons.lock_outline,
            message: 'Chỉ quản trị viên được truy cập.',
          ),
        );
      }
      return _ProductList(
        key: ValueKey(member.id),
        title: title,
        adminId: member.id,
      );
    },
  );
}

typedef _ProductCatalog = ({
  List<Category> categories,
  PageResult<Product> products,
  int page,
  int? categoryId,
});

class _ProductList extends StatefulWidget {
  const _ProductList({super.key, required this.title, required this.adminId});

  final String title;
  final String adminId;

  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  static const _pageSize = 5;
  final _db = LocalDatabase.instance;
  late Future<_ProductCatalog> _catalog;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _catalog = _load(page: 1);
  }

  Future<_ProductCatalog> _load({required int page, int? categoryId}) async {
    final categories = await _db.categories();
    if (!categories.any((item) => item.id == categoryId)) categoryId = null;
    var products = await _db.products(
      categoryId: categoryId,
      page: page,
      pageSize: _pageSize,
    );
    if (page > 1 && products.items.isEmpty) {
      page = products.total == 0
          ? 1
          : (products.total + _pageSize - 1) ~/ _pageSize;
      products = await _db.products(
        categoryId: categoryId,
        page: page,
        pageSize: _pageSize,
      );
    }
    return (
      categories: categories,
      products: products,
      page: page,
      categoryId: categoryId,
    );
  }

  void _reload({required int page, int? categoryId}) {
    setState(() {
      _catalog = _load(page: page, categoryId: categoryId);
    });
  }

  Future<void> _openCategories() async {
    await Navigator.pushNamed(context, '/admin/categories');
    if (mounted) _reload(page: 1);
  }

  Future<void> _edit(_ProductCatalog catalog, [Product? product]) async {
    var name = product?.name ?? '';
    var description = product?.description ?? '';
    var price = product?.price ?? 0;
    var stock = product?.stock ?? 0;
    var categoryId = product?.categoryId ?? catalog.categoryId;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CatalogEditor(
        title: product == null ? 'Thêm món' : 'Sửa món',
        asset: product?.imageUrl ?? '',
        imageId: product?.imageId,
        requireImage: product == null,
        fields: [
          TextFormField(
            initialValue: name,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Tên món'),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Nhập tên món.' : null,
            onSaved: (value) => name = value!.trim(),
          ),
          DropdownButtonFormField<int>(
            initialValue: categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Danh mục'),
            items: [
              for (final item in catalog.categories)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (_) {},
            validator: (value) => value == null ? 'Chọn danh mục.' : null,
            onSaved: (value) => categoryId = value,
          ),
          TextFormField(
            initialValue: product?.price.toString(),
            decoration: const InputDecoration(labelText: 'Đơn giá (₫)'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final number = int.tryParse(value ?? '');
              return number == null || number <= 0 || number > 1000000000
                  ? 'Nhập giá từ 1 đến 1.000.000.000 ₫.'
                  : null;
            },
            onSaved: (value) => price = int.parse(value!),
          ),
          TextFormField(
            initialValue: product?.stock.toString(),
            decoration: const InputDecoration(labelText: 'Số lượng còn'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final number = int.tryParse(value ?? '');
              return number == null || number < 0 || number > 10000
                  ? 'Nhập số lượng từ 0 đến 10.000.'
                  : null;
            },
            onSaved: (value) => stock = int.parse(value!),
          ),
          TextFormField(
            initialValue: description,
            maxLength: 3000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Mô tả'),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập mô tả món.'
                : null,
            onSaved: (value) => description = value!.trim(),
          ),
        ],
        onSave: (image, _) => _db.saveProduct(
          widget.adminId,
          id: product?.id,
          categoryId: categoryId!,
          name: name,
          description: description,
          price: price,
          stock: stock,
          image: image,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    _reload(
      page: product == null ? 1 : catalog.page,
      categoryId: product == null && catalog.categoryId != null
          ? categoryId
          : catalog.categoryId,
    );
    showMessage(context, 'Đã lưu món.');
  }

  Future<void> _delete(_ProductCatalog catalog, Product product) async {
    if (!await confirmCatalogDeletion(context, product.name) || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await _db.deleteProduct(widget.adminId, product.id);
      if (!mounted) return;
      _reload(page: catalog.page, categoryId: catalog.categoryId);
      showMessage(context, 'Đã xóa món.');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProductCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        final catalog = snapshot.data;
        final loaded = snapshot.connectionState == ConnectionState.done;
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: !loaded
              ? const Center(child: CircularProgressIndicator())
              : catalog == null
              ? LoadError(error: snapshot.error, retry: () => _reload(page: 1))
              : _buildCatalog(catalog),
        );
      },
    );
  }

  Widget _buildCatalog(_ProductCatalog catalog) {
    if (catalog.categories.isEmpty) {
      return WorkspaceEmpty(
        icon: Icons.category_outlined,
        message: 'Hãy tạo danh mục để thêm món.',
        action: OutlinedButton(
          onPressed: _openCategories,
          child: const Text('Quản lý danh mục'),
        ),
      );
    }
    final categoryNames = {
      for (final item in catalog.categories) item.id: item.name,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: WorkspaceHeading(
                icon: Icons.restaurant_menu_rounded,
                title: 'Món trong thực đơn',
                detail: '${catalog.products.total} món',
                action: FilledButton.icon(
                  onPressed: _deleting ? null : () => _edit(catalog),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm món'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _filters(catalog),
            ),
            Expanded(
              child: catalog.products.items.isEmpty
                  ? const WorkspaceEmpty(
                      icon: Icons.restaurant_menu_rounded,
                      message: 'Chưa có món trong danh sách.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      itemCount: catalog.products.items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final product = catalog.products.items[index];
                        final colors = Theme.of(context).colorScheme;
                        return WorkspaceCard(
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(
                              14,
                              9,
                              6,
                              9,
                            ),
                            leading: CatalogThumbnail(
                              asset: product.imageUrl,
                              imageId: product.imageId,
                            ),
                            title: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  categoryNames[product.categoryId] ??
                                      'Danh mục',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      money(product.price),
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        color: product.stock > 0
                                            ? colors.primaryContainer
                                            : colors.errorContainer,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        child: Text(
                                          product.stock > 0
                                              ? 'Còn ${product.stock}'
                                              : 'Hết món',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: product.stock > 0
                                                    ? colors.onPrimaryContainer
                                                    : colors.onErrorContainer,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: _deleting
                                ? null
                                : () => _edit(catalog, product),
                            trailing: PopupMenuButton<bool>(
                              tooltip: 'Thao tác món',
                              icon: const Icon(Icons.more_horiz_rounded),
                              enabled: !_deleting,
                              onSelected: (delete) {
                                if (delete) {
                                  _delete(catalog, product);
                                } else {
                                  _edit(catalog, product);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: false, child: Text('Sửa')),
                                PopupMenuItem(value: true, child: Text('Xóa')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (catalog.products.total > _pageSize)
              SafeArea(
                top: false,
                child: IgnorePointer(
                  ignoring: _deleting,
                  child: PagingControls(
                    page: catalog.page,
                    total: catalog.products.total,
                    pageSize: _pageSize,
                    onChanged: (page) =>
                        _reload(page: page, categoryId: catalog.categoryId),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filters(_ProductCatalog catalog) => DropdownButtonFormField<int>(
    key: ValueKey(catalog.categoryId),
    initialValue: catalog.categoryId ?? 0,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Lọc theo danh mục',
      prefixIcon: Icon(Icons.tune_rounded, size: 20),
    ),
    items: [
      const DropdownMenuItem(value: 0, child: Text('Tất cả danh mục')),
      for (final item in catalog.categories)
        DropdownMenuItem(
          value: item.id,
          child: Text(item.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _deleting
        ? null
        : (value) => _reload(page: 1, categoryId: value == 0 ? null : value),
  );
}

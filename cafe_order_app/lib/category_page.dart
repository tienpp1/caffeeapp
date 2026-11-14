import 'package:flutter/material.dart';

import 'admin_catalog_widgets.dart';
import 'category.dart';
import 'helper.dart';
import 'local_database.dart';
import 'member.dart';
import 'session_helper.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key, this.title = 'Quản lý danh mục'});

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
      return _CategoryList(
        key: ValueKey(member.id),
        title: title,
        adminId: member.id,
      );
    },
  );
}

class _CategoryList extends StatefulWidget {
  const _CategoryList({super.key, required this.title, required this.adminId});

  final String title;
  final String adminId;

  @override
  State<_CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<_CategoryList> {
  final _db = LocalDatabase.instance;
  late Future<List<Category>> _categories;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _categories = _db.categories();
  }

  void _reload() => setState(() => _categories = _db.categories());

  Future<void> _edit([Category? category]) async {
    var name = category?.name ?? '';
    var description = category?.description ?? '';
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CatalogEditor(
        title: category == null ? 'Thêm danh mục' : 'Sửa danh mục',
        asset: category?.icon ?? '',
        imageId: category?.imageId,
        allowRemove: true,
        fields: [
          TextFormField(
            initialValue: name,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Tên danh mục'),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên danh mục.'
                : null,
            onSaved: (value) => name = value!.trim(),
          ),
          TextFormField(
            initialValue: description,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Mô tả'),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập mô tả danh mục.'
                : null,
            onSaved: (value) => description = value!.trim(),
          ),
        ],
        onSave: (image, removeImage) => _db.saveCategory(
          widget.adminId,
          id: category?.id,
          name: name,
          description: description,
          image: image,
          removeImage: removeImage,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    _reload();
    showMessage(context, 'Đã lưu danh mục.');
  }

  Future<void> _delete(Category category) async {
    if (!await confirmCatalogDeletion(context, category.name) || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await _db.deleteCategory(widget.adminId, category.id);
      if (!mounted) return;
      _reload();
      showMessage(context, 'Đã xóa danh mục.');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Category>>(
        future: _categories,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return LoadError(error: snapshot.error, retry: _reload);
          }
          final categories = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemCount: categories.isEmpty ? 2 : categories.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return WorkspaceHeading(
                      icon: Icons.category_outlined,
                      title: 'Danh mục thực đơn',
                      detail: '${categories.length} danh mục',
                      action: FilledButton.icon(
                        onPressed: _deleting ? null : _edit,
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm danh mục'),
                      ),
                    );
                  }
                  if (categories.isEmpty) {
                    return const WorkspaceEmpty(
                      icon: Icons.category_outlined,
                      message: 'Chưa có danh mục.',
                    );
                  }
                  final category = categories[index - 1];
                  return WorkspaceCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 9, 6, 9),
                      leading: CatalogThumbnail(
                        asset: category.icon,
                        imageId: category.imageId,
                        icon: Icons.category_outlined,
                      ),
                      title: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        category.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: _deleting ? null : () => _edit(category),
                      trailing: PopupMenuButton<bool>(
                        tooltip: 'Thao tác danh mục',
                        icon: const Icon(Icons.more_horiz_rounded),
                        enabled: !_deleting,
                        onSelected: (delete) {
                          if (delete) {
                            _delete(category);
                          } else {
                            _edit(category);
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
          );
        },
      ),
    );
  }
}

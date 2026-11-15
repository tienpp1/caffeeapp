import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'helper.dart';
import 'local_database.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.statusId});

  final int statusId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = LocalDatabase.statuses.firstWhere(
      (item) => item.id == statusId,
    );
    final (background, foreground, icon) = switch (statusId) {
      1 => (
        const Color(0xFFF6E7CA),
        const Color(0xFF633E14),
        Icons.schedule_rounded,
      ),
      2 => (
        const Color(0xFFF2DED2),
        const Color(0xFF62351F),
        Icons.local_cafe_outlined,
      ),
      3 => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.room_service_outlined,
      ),
      4 => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.done_rounded,
      ),
      5 => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.block_rounded,
      ),
      _ => (colors.primary, colors.onPrimary, Icons.check_circle_outline),
    };
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.name,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceHeading extends StatelessWidget {
  const WorkspaceHeading({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 14,
        spacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(icon, size: 22, color: colors.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ?action,
        ],
      ),
    );
  }
}

class WorkspaceEmpty extends StatelessWidget {
  const WorkspaceEmpty({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}

Future<bool> confirmCatalogDeletion(BuildContext context, String name) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn muốn xóa "$name"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      ) ??
      false;
}

class CatalogThumbnail extends StatelessWidget {
  const CatalogThumbnail({
    super.key,
    required this.asset,
    this.imageId,
    this.icon = Icons.restaurant_outlined,
    this.size = 64,
  });

  final String asset;
  final int? imageId;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: colors.primaryContainer,
        child: SizedBox.square(
          dimension: size,
          child: asset.isEmpty && imageId == null
              ? Icon(icon, color: colors.onPrimaryContainer)
              : ProductImage(asset: asset, imageId: imageId, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class CatalogEditor extends StatefulWidget {
  const CatalogEditor({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.asset = '',
    this.imageId,
    this.requireImage = false,
    this.allowRemove = false,
  });

  final String title;
  final List<Widget> fields;
  final Future<void> Function(Uint8List? image, bool removeImage) onSave;
  final String asset;
  final int? imageId;
  final bool requireImage;
  final bool allowRemove;

  @override
  State<CatalogEditor> createState() => _CatalogEditorState();
}

class _CatalogEditorState extends State<CatalogEditor> {
  static const _imageLimit = 5 * 1024 * 1024;
  final _form = GlobalKey<FormState>();
  Uint8List? _selectedImage;
  bool _removeImage = false;
  bool _picking = false;
  bool _saving = false;
  String? _error;

  bool get _busy => _picking || _saving;
  bool get _hasStoredImage => widget.asset.isNotEmpty || widget.imageId != null;

  Future<void> _pickImage() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      if (await picked.length() > _imageLimit) {
        throw const FormatException('Vui lòng chọn ảnh tối đa 5 MB.');
      }
      final bytes = await picked.readAsBytes();
      await _validateImage(bytes);
      if (!mounted) return;
      setState(() {
        _selectedImage = bytes;
        _removeImage = false;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không đọc được ảnh. Vui lòng thử ảnh khác.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _validateImage(Uint8List bytes) async {
    if (bytes.length > _imageLimit) {
      throw const FormatException('Vui lòng chọn ảnh tối đa 5 MB.');
    }
    if (bytes.length < 12 || !_hasSupportedSignature(bytes)) {
      throw const FormatException('Vui lòng chọn ảnh JPEG, PNG hoặc WebP.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width > 4096 || descriptor.height > 4096) {
          throw const FormatException(
            'Vui lòng chọn ảnh tối đa 4096 × 4096 px.',
          );
        }
        final codec = await descriptor.instantiateCodec(targetWidth: 64);
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  bool _hasSupportedSignature(Uint8List bytes) {
    final jpeg = bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    final png = bytes[0] == 0x89 && String.fromCharCodes(bytes, 1, 4) == 'PNG';
    final webp =
        String.fromCharCodes(bytes, 0, 4) == 'RIFF' &&
        String.fromCharCodes(bytes, 8, 12) == 'WEBP';
    return jpeg || png || webp;
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      setState(() => _error = 'Kiểm tra các ô được đánh dấu trước khi lưu.');
      return;
    }
    if (widget.requireImage && _selectedImage == null) {
      setState(() => _error = 'Vui lòng chọn ảnh món trước khi lưu.');
      return;
    }
    _form.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_selectedImage, _removeImage);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetImage() => setState(() {
    _selectedImage = null;
    _removeImage = false;
    _error = null;
  });

  Widget _preview() {
    final image = _selectedImage;
    if (image != null) {
      return Image.memory(image, fit: BoxFit.contain, cacheWidth: 640);
    }
    return ProductImage(asset: widget.asset, imageId: widget.imageId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        contentPadding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
        actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        title: Text(widget.title),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in widget.fields) ...[
                  field,
                  const SizedBox(height: 12),
                ],
                Text(
                  widget.requireImage ? 'Ảnh món (bắt buộc)' : 'Ảnh hiển thị',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'JPEG, PNG hoặc WebP · tối đa 5 MB',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(_picking ? 'Đang đọc ảnh…' : 'Chọn ảnh'),
                    ),
                    if (_selectedImage != null || _removeImage)
                      TextButton(
                        onPressed: _busy ? null : _resetImage,
                        child: const Text('Hoàn tác'),
                      ),
                    if (widget.allowRemove && _hasStoredImage && !_removeImage)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _selectedImage = null;
                                _removeImage = true;
                                _error = null;
                              }),
                        child: const Text('Bỏ ảnh'),
                      ),
                  ],
                ),
                if (_selectedImage != null ||
                    (_hasStoredImage && !_removeImage)) ...[
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(height: 144, child: _preview()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error case final message?)
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

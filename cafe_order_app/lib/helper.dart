import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'cafe_theme.dart';
import 'product.dart';
import 'local_database.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String errorMessage(Object? error) {
  return error is AppException ? error.message : 'Đã có lỗi. Vui lòng thử lại.';
}

String money(int amount) {
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$value ₫';
}

String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

class ProductImage extends StatefulWidget {
  const ProductImage({
    super.key,
    required this.asset,
    this.imageId,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  final String asset;
  final int? imageId;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  Future<Uint8List?>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) _load();
  }

  void _load() {
    final id = widget.imageId;
    _image = id == null ? null : LocalDatabase.instance.image(id);
  }

  Widget _fallback() => SizedBox(
    width: widget.width,
    height: widget.height,
    child: Icon(
      Icons.local_cafe_outlined,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .45),
    ),
  );

  Widget _asset() {
    if (widget.asset.isEmpty) return _fallback();
    return Image.asset(
      widget.asset,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) return _asset();
    return FutureBuilder<Uint8List?>(
      future: _image,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return _asset();
        return Image.memory(
          data,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, _, _) => _fallback(),
        );
      },
    );
  }
}

class PagingControls extends StatelessWidget {
  const PagingControls({
    super.key,
    required this.page,
    required this.total,
    required this.pageSize,
    required this.onChanged,
  });

  final int page;
  final int total;
  final int pageSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final pages = (total / pageSize).ceil();
    if (pages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            tooltip: 'Trang trước',
            onPressed: page > 1 ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Trang $page / $pages'),
          ),
          IconButton.outlined(
            tooltip: 'Trang sau',
            onPressed: page < pages ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 30, color: cafeMuted),
          const SizedBox(height: 12),
          Text(errorMessage(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soldOut = product.stock == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFFEADBC8),
                    child: ProductImage(
                      asset: product.imageUrl,
                      imageId: product.imageId,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  if (soldOut)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cafeSurface,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Text(
                            'Hết món',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          money(product.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: cafeForest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 17,
                          color: cafeForest,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cart_ext.dart';
import 'helper.dart';
import 'local_database.dart';
import 'member.dart';
import 'session_helper.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key, required this.title});
  final String title;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _database = LocalDatabase.instance;
  Future<List<CartExt>>? _cart;
  String? _memberId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadMemberCart();
    SessionHelper.current.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    SessionHelper.current.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() => setState(_loadMemberCart);

  void _loadMemberCart() {
    final member = SessionHelper.current.value;
    _memberId = member == null || !member.active || member.isAdmin
        ? null
        : member.id;
    _cart = _memberId == null ? null : _database.cart(_memberId!);
  }

  Future<void> _change(CartExt item, int quantity) async {
    final memberId = _memberId;
    if (memberId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _database.setCartQuantity(memberId, item.productId, quantity);
      if (mounted && _memberId == memberId) setState(_loadMemberCart);
    } catch (error) {
      if (mounted && _memberId == memberId) {
        showMessage(context, errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout(List<CartExt> items, Member member) async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => _CheckoutPage(items: items, member: member),
      ),
    );
    if (!mounted || id == null || _memberId != member.id) return;
    setState(_loadMemberCart);
    showMessage(context, 'Đã gửi đơn #$id.');
    await Navigator.pushNamed(
      context,
      '/orders/details',
      arguments: (id: id, admin: false),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: _memberId == null
        ? const Center(
            child: Text('Đăng nhập bằng tài khoản Member để xem giỏ món.'),
          )
        : FutureBuilder<List<CartExt>>(
            key: ValueKey(_memberId),
            future: _cart,
            builder: (context, snapshot) {
              final loading = snapshot.connectionState != ConnectionState.done;
              if (!snapshot.hasData && loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return LoadError(
                  error: snapshot.error,
                  retry: () => setState(_loadMemberCart),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return _emptyCart();
              }
              return _cartContent(items, _busy || loading);
            },
          ),
  );

  Widget _emptyCart() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: theme.colorScheme.primary,
                size: 31,
              ),
            ),
            const SizedBox(height: 18),
            Text('Giỏ món đang trống.', style: _sectionTitle(theme)),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Về thực đơn'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartContent(List<CartExt> items, bool actionsDisabled) {
    final total = _cartTotal(items);
    final member = SessionHelper.current.value!;
    final theme = Theme.of(context);
    final action = FilledButton.icon(
      onPressed: actionsDisabled ? null : () => _checkout(items, member),
      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
      label: const Text('Tiếp tục đặt món'),
      iconAlignment: IconAlignment.end,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 880;
        final order = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Món đã chọn', style: _sectionTitle(theme)),
            const SizedBox(height: 14),
            for (final item in items)
              Padding(
                key: ValueKey(item.productId),
                padding: const EdgeInsets.only(bottom: 10),
                child: _item(item, wide, actionsDisabled),
              ),
          ],
        );
        final bill = _OrderSummary(
          total: total,
          totalLabel: 'Tạm tính',
          items: items,
          action: action,
        );
        final scroll = ListView(
          padding: EdgeInsets.fromLTRB(
            wide ? 34 : 18,
            wide ? 28 : 8,
            wide ? 34 : 18,
            20,
          ),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: order),
                  const SizedBox(width: 28),
                  SizedBox(width: 305, child: bill),
                ],
              )
            else
              order,
          ],
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1130),
            child: wide
                ? scroll
                : Column(
                    children: [
                      Expanded(child: scroll),
                      _CompactTotal(
                        total: total,
                        totalLabel: 'Tạm tính',
                        action: action,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _item(CartExt item, bool wide, bool actionsDisabled) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: ProductImage(
        asset: item.imageUrl,
        imageId: item.imageId,
        width: wide ? 88 : 64,
        height: wide ? 88 : 64,
        fit: BoxFit.cover,
      ),
    );
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          money(item.price),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
    final quantity = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Giảm số lượng',
            onPressed: actionsDisabled || item.quantity <= 1 || item.stock == 0
                ? null
                : () => _change(item, math.min(item.quantity - 1, item.stock)),
            icon: const Icon(Icons.remove_rounded, size: 19),
          ),
          Text('${item.quantity}', style: theme.textTheme.titleSmall),
          IconButton(
            tooltip: 'Tăng số lượng',
            onPressed: actionsDisabled || item.quantity >= item.stock
                ? null
                : () => _change(item, item.quantity + 1),
            icon: const Icon(Icons.add_rounded, size: 19),
          ),
        ],
      ),
    );
    final remove = IconButton(
      tooltip: 'Xóa ${item.name} khỏi giỏ',
      onPressed: actionsDisabled ? null : () => _change(item, 0),
      icon: const Icon(Icons.delete_outline_rounded, size: 21),
    );
    return _OrderPanel(
      padding: EdgeInsets.all(wide ? 16 : 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline = constraints.maxWidth >= 470;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  photo,
                  const SizedBox(width: 13),
                  Expanded(child: label),
                  if (inline) ...[const SizedBox(width: 10), quantity],
                  remove,
                ],
              ),
              if (!inline) ...[
                const SizedBox(height: 9),
                Align(alignment: Alignment.centerRight, child: quantity),
              ],
              if (item.quantity > item.stock)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Món này còn ${item.stock} phần. Hãy điều chỉnh số lượng.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckoutPage extends StatefulWidget {
  const _CheckoutPage({required this.items, required this.member});
  final List<CartExt> items;
  final Member member;

  @override
  State<_CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<_CheckoutPage> {
  final _form = GlobalKey<FormState>();
  final _tableField = GlobalKey<FormFieldState<int>>();
  final _nameField = GlobalKey<FormFieldState<String>>();
  late final _name = TextEditingController(
    text: [
      widget.member.surname,
      widget.member.givenName,
    ].whereType<String>().join(' '),
  );
  final _note = TextEditingController();
  int? _table;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final member = SessionHelper.current.value;
    if (member == null ||
        member.id != widget.member.id ||
        !member.active ||
        member.isAdmin) {
      showMessage(
        context,
        'Phiên đăng nhập đã thay đổi. Hãy quay lại giỏ món.',
      );
      return;
    }
    if (!_form.currentState!.validate()) {
      final field = _table == null ? _tableField : _nameField;
      final target = field.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 220),
          alignment: .1,
        );
      }
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final id = await LocalDatabase.instance.checkout(
        widget.member.id,
        tableNumber: _table!,
        customerName: _name.text.trim(),
        note: _note.text.trim(),
      );
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context, id);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, errorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _cartTotal(widget.items);
    final action = FilledButton.icon(
      onPressed: _saving ? null : _save,
      icon: _saving
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_forward_rounded, size: 19),
      label: Text(_saving ? 'Đang gửi đơn…' : 'Xác nhận gọi món'),
      iconAlignment: IconAlignment.end,
    );
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Gửi đơn gọi món')),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 880;
            final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final sticky = !wide && constraints.maxHeight >= 240 * textScale;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1090),
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            wide ? 34 : 18,
                            wide ? 28 : 8,
                            wide ? 34 : 18,
                            20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _orderForm(theme)),
                                    const SizedBox(width: 28),
                                    SizedBox(
                                      width: 325,
                                      child: _OrderSummary(
                                        total: total,
                                        totalLabel: 'Tổng tiền',
                                        items: widget.items,
                                        action: action,
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _orderForm(theme),
                                const SizedBox(height: 14),
                                _OrderSummary(
                                  total: total,
                                  totalLabel: 'Tổng tiền',
                                  items: widget.items,
                                  showTotal: !sticky,
                                  action: sticky ? null : action,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (sticky)
                        _CompactTotal(
                          total: total,
                          totalLabel: 'Tổng tiền',
                          action: action,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _orderForm(ThemeData theme) {
    return _OrderPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Thông tin tại bàn', style: _sectionTitle(theme)),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            key: _tableField,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Số bàn',
              prefixIcon: Icon(Icons.table_restaurant_outlined),
            ),
            items: [
              for (var number = 1; number <= LocalDatabase.tableCount; number++)
                DropdownMenuItem(value: number, child: Text('Bàn $number')),
            ],
            onChanged: _saving
                ? null
                : (number) => setState(() => _table = number),
            validator: (value) => value == null ? 'Hãy chọn số bàn.' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: _nameField,
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tên khách',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên khách.'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _note,
            enabled: !_saving,
            maxLength: 240,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho quầy',
              hintText: 'Ví dụ ít đá, không đường',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

int _cartTotal(List<CartExt> items) =>
    items.fold(0, (sum, item) => sum + item.price * item.quantity);

TextStyle? _sectionTitle(ThemeData theme) =>
    theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Playfair Display');

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.total,
    required this.totalLabel,
    required this.items,
    this.showTotal = true,
    this.action,
  });

  final int total;
  final String totalLabel;
  final List<CartExt> items;
  final bool showTotal;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _OrderPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tóm tắt đơn', style: _sectionTitle(theme)),
          const SizedBox(height: 13),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                runSpacing: 2,
                children: [
                  Text(
                    '${item.quantity} × ${item.name}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    money(item.price * item.quantity),
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 11),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 14),
          if (showTotal) ...[
            _TotalLine(label: totalLabel, total: total),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Thanh toán tiền mặt tại quầy',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _CompactTotal extends StatelessWidget {
  const _CompactTotal({
    required this.total,
    required this.totalLabel,
    required this.action,
  });

  final int total;
  final String totalLabel;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TotalLine(label: totalLabel, total: total),
            const SizedBox(height: 10),
            action,
          ],
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.total});
  final String label;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 3,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        Text(
          money(total),
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

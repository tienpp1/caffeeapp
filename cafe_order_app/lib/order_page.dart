import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_catalog_widgets.dart';
import 'helper.dart';
import 'order_ticket.dart';
import 'local_database.dart';
import 'session_helper.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.title, this.admin = false});
  final String title;
  final bool admin;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  DateTime? _date;
  Future<List<OrderTicket>>? _orders;

  @override
  void initState() {
    super.initState();
    _load();
    SessionHelper.current.addListener(_reload);
  }

  @override
  void dispose() {
    SessionHelper.current.removeListener(_reload);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    final member = SessionHelper.current.value;
    _orders = member == null || member.isAdmin != widget.admin
        ? null
        : LocalDatabase.instance.orders(
            member.id,
            admin: widget.admin,
            search: _search.text.trim(),
            date: _date,
          );
  }

  void _reload() => setState(_load);

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDate: _date ?? now,
      helpText: 'Lọc theo ngày tạo đơn',
    );
    if (!mounted || selected == null) return;
    _date = selected;
    _reload();
  }

  Future<void> _open(OrderTicket order) async {
    await Navigator.pushNamed(
      context,
      '/orders/details',
      arguments: (id: order.id, admin: widget.admin),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: _orders == null
        ? const WorkspaceEmpty(
            icon: Icons.lock_outline,
            message: 'Tài khoản hiện tại không có quyền xem danh sách này.',
          )
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: _filters(context),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: FutureBuilder<List<OrderTicket>>(
                      future: _orders,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return LoadError(
                            error: snapshot.error,
                            retry: _reload,
                          );
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return const WorkspaceEmpty(
                            icon: Icons.receipt_long_outlined,
                            message: 'Không có đơn phù hợp.',
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _orderCard(context, items[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
  );

  Widget _filters(BuildContext context) {
    final search = TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), _reload);
      },
      decoration: InputDecoration(
        labelText: 'Tìm mã đơn, số bàn hoặc tên',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder(
          valueListenable: _search,
          builder: (context, value, child) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: () {
                    _search.clear();
                    _debounce?.cancel();
                    _reload();
                  },
                  tooltip: 'Xóa từ khóa',
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
    if (!widget.admin) return search;

    final day = _date;
    final picker = day == null
        ? OutlinedButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: const Text('Lọc theo ngày đặt'),
          )
        : InputChip(
            avatar: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text('Ngày đặt ${formatDate(day)}'),
            onPressed: _selectDate,
            onDeleted: () {
              _date = null;
              _reload();
            },
          );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 580
          ? Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                picker,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 8), picker],
            ),
    );
  }

  Widget _orderCard(BuildContext context, OrderTicket order) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return WorkspaceCard(
      onTap: () => _open(order),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: colors.primary,
                  size: 21,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn #${order.id} · Bàn ${order.tableNumber}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDate(order.dated)}'
                    '${widget.admin ? ' · ${order.customerName}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OrderStatusBadge(statusId: order.statusId),
                      Text(
                        money(order.total),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

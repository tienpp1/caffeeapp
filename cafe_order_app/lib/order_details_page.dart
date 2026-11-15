import 'package:flutter/material.dart';

import 'admin_catalog_widgets.dart';
import 'helper.dart';
import 'order_ticket.dart';
import 'local_database.dart';
import 'session_helper.dart';

class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({super.key, required this.title});
  final String title;

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final _database = LocalDatabase.instance;
  Future<(OrderTicket, List<OrderLine>)?>? _data;
  int? _id;
  bool _admin = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SessionHelper.current.addListener(_reload);
  }

  @override
  void dispose() {
    SessionHelper.current.removeListener(_reload);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments case (id: final int id, admin: final bool admin)) {
      if (_id == id && _admin == admin) return;
      _id = id;
      _admin = admin;
      _data = _load();
    }
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<(OrderTicket, List<OrderLine>)?> _load() async {
    final id = _id;
    final admin = _admin;
    final member = SessionHelper.current.value;
    if (id == null ||
        member == null ||
        !member.active ||
        member.isAdmin != admin) {
      return null;
    }
    final order = await _database.order(member.id, id, admin: admin);
    if (order == null ||
        (!admin && order.memberId != member.id) ||
        SessionHelper.current.value?.id != member.id) {
      return null;
    }
    final lines = await _database.orderLines(member.id, id, admin: admin);
    return (order, lines);
  }

  Future<void> _update(
    OrderTicket order,
    int statusId,
    String statusName,
  ) async {
    if (_saving) return;
    final member = SessionHelper.current.value;
    if (member == null || !member.active || !member.isAdmin) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật trạng thái'),
        content: Text(
          statusId == 6
              ? 'Xác nhận đã thu ${money(order.total)} tiền mặt cho đơn #${order.id}?'
              : 'Chuyển đơn #${order.id} sang “$statusName”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: statusId == 5
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving) return;
    final current = SessionHelper.current.value;
    if (current == null ||
        current.id != member.id ||
        !current.active ||
        !current.isAdmin) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _database.updateOrderStatus(member.id, order.id, statusId);
    } catch (error) {
      if (mounted && SessionHelper.current.value?.id == member.id) {
        showMessage(context, errorMessage(error));
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted || SessionHelper.current.value?.id != member.id) return;
    _reload();
    showMessage(context, 'Đã cập nhật trạng thái đơn.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<(OrderTicket, List<OrderLine>)?>(
      future: _data,
      builder: (context, snapshot) {
        if (_data != null && snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return LoadError(error: snapshot.error, retry: _reload);
        }
        final data = snapshot.data;
        if (data == null) {
          return const WorkspaceEmpty(
            icon: Icons.receipt_long_outlined,
            message: 'Không tìm thấy đơn hoặc bạn chưa có quyền xem.',
          );
        }
        final (order, lines) = data;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                WorkspaceHeading(
                  icon: Icons.receipt_long_outlined,
                  title: 'Đơn #${order.id}',
                  detail: 'Ngày đặt ${formatDate(order.dated)}',
                  action: OrderStatusBadge(statusId: order.statusId),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final summary = _summary(context, order);
                    final receipt = _receipt(context, order, lines);
                    if (constraints.maxWidth < 700) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          const SizedBox(height: 12),
                          receipt,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: receipt),
                        const SizedBox(width: 16),
                        Expanded(child: summary),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _summary(BuildContext context, OrderTicket order) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final next = _admin ? LocalDatabase.nextStatuses(order.statusId) : [];
    return WorkspaceCard(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bàn ${order.tableNumber}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _detail(context, 'Khách gọi món', order.customerName),
            if (_admin) _detail(context, 'Tài khoản', order.memberName),
            if (order.note.isNotEmpty) _detail(context, 'Ghi chú', order.note),
            if (order.statusId != 5) ...[
              const SizedBox(height: 8),
              Text(
                order.statusId == 6
                    ? 'Đã thu tiền mặt'
                    : 'Thanh toán tiền mặt tại quầy',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (next.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 14),
              Text('Chuyển trạng thái', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in next)
                    OutlinedButton(
                      style: item.id == 5
                          ? OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                            )
                          : OutlinedButton.styleFrom(
                              backgroundColor: colors.primaryContainer,
                              foregroundColor: colors.onPrimaryContainer,
                            ),
                      onPressed: _saving
                          ? null
                          : () => _update(order, item.id, item.name),
                      child: Text(
                        item.id == 6 ? 'Ghi nhận thu tiền mặt' : item.name,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label · ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );

  Widget _receipt(
    BuildContext context,
    OrderTicket order,
    List<OrderLine> lines,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return WorkspaceCard(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Món đã gọi', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            for (final line in lines) ...[
              Divider(height: 1, color: colors.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.name, style: theme.textTheme.titleSmall),
                          Text(
                            '${line.quantity} × ${money(line.price)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      money(line.quantity * line.price),
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ],
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Tổng tiền', style: theme.textTheme.titleMedium),
                Text(
                  money(order.total),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

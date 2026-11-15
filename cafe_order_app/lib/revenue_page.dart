import 'package:flutter/material.dart';

import 'admin_catalog_widgets.dart';
import 'helper.dart';
import 'local_database.dart';
import 'member.dart';
import 'order_ticket.dart';
import 'session_helper.dart';

const _cafeOffset = Duration(hours: 7);
final _firstReportDate = DateTime(2020);

DateTime _todayAtCafe() {
  final now = DateTime.now().toUtc().add(_cafeOffset);
  return DateTime(now.year, now.month, now.day);
}

enum _Period {
  all('Tất cả'),
  day('Ngày'),
  month('Tháng'),
  year('Năm');

  const _Period(this.label);
  final String label;
}

class RevenuePage extends StatelessWidget {
  const RevenuePage({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Member?>(
    valueListenable: SessionHelper.current,
    builder: (context, member, _) {
      if (member == null || !member.active || !member.isAdmin) {
        return Scaffold(
          appBar: AppBar(title: const Text('Quản lý doanh thu')),
          body: const WorkspaceEmpty(
            icon: Icons.lock_outline,
            message: 'Chỉ quản trị viên được xem doanh thu.',
          ),
        );
      }
      return _RevenueReport(key: ValueKey(member.id), adminId: member.id);
    },
  );
}

class _RevenueReport extends StatefulWidget {
  const _RevenueReport({super.key, required this.adminId});

  final String adminId;

  @override
  State<_RevenueReport> createState() => _RevenueReportState();
}

class _RevenueReportState extends State<_RevenueReport> {
  _Period _period = _Period.all;
  DateTime _date = _todayAtCafe();
  late Future<List<OrderTicket>> _orders = _load();

  Future<List<OrderTicket>> _load() => LocalDatabase.instance.paidOrders(
    widget.adminId,
    year: _period == _Period.all ? null : _date.year,
    month: _period == _Period.day || _period == _Period.month
        ? _date.month
        : null,
    day: _period == _Period.day ? _date.day : null,
  );

  void _refresh() {
    setState(() {
      _orders = _load();
    });
  }

  void _changePeriod(_Period period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _orders = _load();
    });
  }

  Future<void> _chooseDate() async {
    final today = _todayAtCafe();
    final date = _period == _Period.day
        ? await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: _firstReportDate,
            lastDate: today,
            helpText: 'Chọn ngày doanh thu',
          )
        : await showDialog<DateTime>(
            context: context,
            builder: (_) => _ReportDateDialog(
              initialDate: _date,
              today: today,
              chooseMonth: _period == _Period.month,
            ),
          );
    if (!mounted || date == null) return;
    setState(() {
      _date = date;
      _orders = _load();
    });
  }

  Widget _filters(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final label = switch (_period) {
      _Period.all => '',
      _Period.day => material.formatCompactDate(_date),
      _Period.month => material.formatMonthYear(_date),
      _Period.year => 'Năm ${_date.year}',
    };
    return WorkspaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kỳ báo cáo',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final period in _Period.values)
                      ChoiceChip(
                        label: Text(period.label),
                        selected: _period == period,
                        showCheckmark: false,
                        onSelected: (_) => _changePeriod(period),
                      ),
                  ],
                ),
              ],
            ),
            if (_period != _Period.all)
              OutlinedButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(label),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quản lý doanh thu'),
      actions: [
        IconButton(
          tooltip: 'Làm mới doanh thu',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: FutureBuilder<List<OrderTicket>>(
            future: _orders,
            builder: (context, snapshot) {
              final orders = snapshot.data ?? const <OrderTicket>[];
              final loaded = snapshot.connectionState == ConnectionState.done;
              final showOrders =
                  loaded && !snapshot.hasError && orders.isNotEmpty;
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(child: _filters(context)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: !loaded
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : snapshot.hasError
                          ? LoadError(error: snapshot.error, retry: _refresh)
                          : _RevenueSummary(orders: orders),
                    ),
                  ),
                  if (showOrders)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverList.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) =>
                            _PaidOrderRow(order: orders[index]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ReportDateDialog extends StatefulWidget {
  const _ReportDateDialog({
    required this.initialDate,
    required this.today,
    required this.chooseMonth,
  });

  final DateTime initialDate;
  final DateTime today;
  final bool chooseMonth;

  @override
  State<_ReportDateDialog> createState() => _ReportDateDialogState();
}

class _ReportDateDialogState extends State<_ReportDateDialog> {
  late int _year = widget.initialDate.year;
  late int _month = widget.initialDate.month;

  @override
  Widget build(BuildContext context) {
    final lastMonth = _year == widget.today.year ? widget.today.month : 12;
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.chooseMonth ? 'Chọn tháng doanh thu' : 'Chọn năm doanh thu',
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _year,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Năm'),
              items: [
                for (
                  var year = widget.today.year;
                  year >= _firstReportDate.year;
                  year--
                )
                  DropdownMenuItem(value: year, child: Text('$year')),
              ],
              onChanged: (year) {
                if (year == null) return;
                setState(() {
                  _year = year;
                  if (_year == widget.today.year &&
                      _month > widget.today.month) {
                    _month = widget.today.month;
                  }
                });
              },
            ),
            if (widget.chooseMonth) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(_year),
                initialValue: _month,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tháng'),
                items: [
                  for (var month = 1; month <= lastMonth; month++)
                    DropdownMenuItem(value: month, child: Text('Tháng $month')),
                ],
                onChanged: (month) {
                  if (month != null) setState(() => _month = month);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          child: const Text('Áp dụng'),
        ),
      ],
    );
  }
}

class _RevenueSummary extends StatelessWidget {
  const _RevenueSummary({required this.orders});

  final List<OrderTicket> orders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = orders.fold(0, (sum, order) => sum + order.total);
    final count = orders.length;
    final average = count == 0 ? 0 : (total + count ~/ 2) ~/ count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, size) {
            const gap = 10.0;
            final wide = size.maxWidth >= 720;
            final columns = size.maxWidth >= 340 ? 2 : 1;
            final width = wide
                ? (size.maxWidth - 2 * gap) / 3
                : (size.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: wide ? width : size.maxWidth,
                  child: _RevenueMetric(
                    label: 'Tổng doanh thu',
                    value: money(total),
                    icon: Icons.payments_outlined,
                    highlight: true,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _RevenueMetric(
                    label: 'Số đơn đã thanh toán',
                    value: '$count',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _RevenueMetric(
                    label: 'Trung bình mỗi đơn',
                    value: money(average),
                    icon: Icons.analytics_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Đơn đã thanh toán', style: theme.textTheme.titleLarge),
        if (orders.any((order) => order.paidAtUtc == null))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Đơn cũ thiếu giờ thanh toán được tính theo ngày đặt.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (orders.isEmpty)
          const WorkspaceEmpty(
            icon: Icons.receipt_long_outlined,
            message: 'Chưa có đơn đã thanh toán trong kỳ này.',
          ),
      ],
    );
  }
}

class _RevenueMetric extends StatelessWidget {
  const _RevenueMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = highlight ? colors.onPrimary : colors.onSurface;
    return Card(
      color: highlight ? colors.primary : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: highlight ? foreground : colors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaidOrderRow extends StatelessWidget {
  const _PaidOrderRow({required this.order});

  final OrderTicket order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final paidAt = order.paidAtUtc;
    final local = (paidAt ?? order.dated).toUtc().add(_cafeOffset);
    final date = material.formatCompactDate(local);
    final when = paidAt == null
        ? 'Ngày đặt $date · Chưa ghi giờ thanh toán'
        : '$date · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
    return WorkspaceCard(
      child: ListTile(
        title: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              'Đơn #${order.id} · Bàn ${order.tableNumber}',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              money(order.total),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(order.customerName), Text(when)],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.pushNamed(
          context,
          '/orders/details',
          arguments: (id: order.id, admin: true),
        ),
      ),
    );
  }
}

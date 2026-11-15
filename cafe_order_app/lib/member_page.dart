import 'dart:async';

import 'package:flutter/material.dart';

import 'account_widgets.dart';
import 'helper.dart';
import 'local_database.dart';
import 'member.dart';
import 'session_helper.dart';

class MemberPage extends StatelessWidget {
  final String title;

  const MemberPage({super.key, this.title = 'Quản lý thành viên'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ValueListenableBuilder<Member?>(
        valueListenable: SessionHelper.current,
        builder: (context, admin, _) {
          if (admin == null || !admin.active || !admin.isAdmin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chức năng này dành cho quản trị viên.'),
              ),
            );
          }
          return _MemberList(key: ValueKey(admin.id), adminId: admin.id);
        },
      ),
    );
  }
}

class _MemberList extends StatefulWidget {
  final String adminId;

  const _MemberList({super.key, required this.adminId});

  @override
  State<_MemberList> createState() => _MemberListState();
}

class _MemberListState extends State<_MemberList> {
  final _search = TextEditingController();
  late Future<List<Member>> _members;
  Timer? _searchTimer;

  Future<List<Member>> _query() {
    return LocalDatabase.instance.members(
      widget.adminId,
      search: _search.text.trim(),
    );
  }

  @override
  void initState() {
    super.initState();
    _members = _query();
  }

  void _load() {
    _searchTimer?.cancel();
    setState(() {
      _members = _query();
    });
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 220), _load);
  }

  Future<void> _edit(Member member) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _MemberEditor(adminId: widget.adminId, member: member),
    );
    if (!mounted || saved != true) return;
    _load();
    showMessage(context, 'Đã cập nhật thành viên.');
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: FutureBuilder<List<Member>>(
            future: _members,
            builder: (context, snapshot) {
              final loading = snapshot.connectionState != ConnectionState.done;
              final members = snapshot.data ?? [];
              final error = snapshot.error;
              return RefreshIndicator(
                onRefresh: () async {
                  _load();
                  try {
                    await _members;
                  } catch (_) {
                    // The result panel shows the error and retry action.
                  }
                },
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      sliver: SliverToBoxAdapter(
                        child: Material(
                          color: colors.surface,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: colors.outlineVariant),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _search,
                              onChanged: _onSearchChanged,
                              onSubmitted: (_) => _load(),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                labelText: 'Tìm theo tên hoặc email',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon:
                                    ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: _search,
                                      builder: (context, value, _) =>
                                          value.text.isEmpty
                                          ? const SizedBox.shrink()
                                          : IconButton(
                                              tooltip: 'Xóa tìm kiếm',
                                              onPressed: () {
                                                _search.clear();
                                                _load();
                                              },
                                              icon: const Icon(Icons.clear),
                                            ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (loading)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (error != null && !loading)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MemberListNotice(
                          icon: Icons.info_outline,
                          message: error is AppException
                              ? error.message
                              : 'Chưa tải được danh sách thành viên.',
                          onRetry: _load,
                        ),
                      )
                    else if (!loading && members.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MemberListNotice(
                          icon: Icons.person_search_outlined,
                          message: 'Không tìm thấy thành viên.',
                        ),
                      )
                    else if (members.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            '${members.length} thành viên',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        sliver: SliverList.separated(
                          itemCount: members.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return _MemberRow(
                              member: member,
                              onEdit: () => _edit(member),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MemberListNotice extends StatelessWidget {
  const _MemberListNotice({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: colors.primary),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onEdit});

  final Member member;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = [
      member.surname,
      member.givenName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    final role = member.isAdmin ? 'Quản trị viên' : 'Thành viên';
    final status = member.active ? 'Đang hoạt động' : 'Đã khóa';
    final tags = Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        AccountTag(label: role),
        AccountTag(
          label: status,
          active: member.active,
          icon: member.active ? Icons.check_circle_outline : Icons.lock_outline,
        ),
      ],
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 3),
        Text(
          member.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide =
                  box.maxWidth >= 650 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 17;
              return Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: member.active
                        ? const Color(0xFFE7EBDD)
                        : const Color(0xFFF1E8DB),
                    foregroundColor: member.active
                        ? const Color(0xFF354638)
                        : colors.onSurfaceVariant,
                    child: Icon(
                      member.isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(child: identity),
                              const SizedBox(width: 12),
                              tags,
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              identity,
                              const SizedBox(height: 8),
                              tags,
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Sửa thành viên',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MemberEditor extends StatefulWidget {
  final String adminId;
  final Member member;

  const _MemberEditor({required this.adminId, required this.member});

  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  final _form = GlobalKey<FormState>();
  late final _givenName = TextEditingController(text: widget.member.givenName);
  late final _surname = TextEditingController(text: widget.member.surname);
  late int _role = widget.member.role;
  late bool _active = widget.member.active;
  bool _saving = false;
  String? _error;

  bool get _isSelf => widget.adminId == widget.member.id;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final admin = SessionHelper.current.value;
    if (admin == null || admin.id != widget.adminId || !admin.isAdmin) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await LocalDatabase.instance.updateMember(
        widget.adminId,
        widget.member.id,
        givenName: _givenName.text.trim(),
        surname: _surname.text.trim(),
        role: _role,
        active: _active,
      );
      if (_isSelf) await SessionHelper.refresh();
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, true);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa cập nhật được thành viên. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _givenName.dispose();
    _surname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Sửa thành viên'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.member.email,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _surname,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên đệm',
                    hintText: 'Không bắt buộc',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _givenName,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Tên'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập tên thành viên.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Quản trị viên')),
                    DropdownMenuItem(value: 2, child: Text('Thành viên')),
                  ],
                  onChanged: _saving || _isSelf
                      ? null
                      : (role) {
                          if (role != null) setState(() => _role = role);
                        },
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đang hoạt động'),
                  value: _active,
                  onChanged: _saving || _isSelf
                      ? null
                      : (active) => setState(() => _active = active),
                ),
                if (_error != null) AccountFormError(message: _error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Đang lưu…' : 'Lưu thay đổi'),
          ),
        ],
      ),
    );
  }
}

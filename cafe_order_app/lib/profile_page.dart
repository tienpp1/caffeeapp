import 'package:flutter/material.dart';

import 'account_widgets.dart';
import 'local_database.dart';
import 'member.dart';
import 'session_helper.dart';

class ProfilePage extends StatelessWidget {
  final String title;

  const ProfilePage({super.key, this.title = 'Tài khoản'});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất khỏi tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;

    try {
      await SessionHelper.delete();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.popUntil(context, (route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Đã đăng xuất.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa đăng xuất được. Vui lòng thử lại.')),
      );
    }
  }

  Future<void> _changePassword(BuildContext context, String memberId) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PasswordDialog(memberId: memberId),
    );
    if (!context.mounted || changed != true) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ValueListenableBuilder<Member?>(
          valueListenable: SessionHelper.current,
          builder: (context, member, _) {
            if (member == null) {
              return Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập để xem tài khoản'),
                ),
              );
            }
            final name = [
              member.surname,
              member.givenName,
            ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
            final identity = Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      member.isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                      color: colors.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    member.email,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AccountTag(
                    label: member.isAdmin ? 'Quản trị viên' : 'Thành viên',
                    active: true,
                  ),
                ],
              ),
            );
            final actions = Material(
              color: colors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'Bảo mật tài khoản',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 3,
                    ),
                    leading: const Icon(Icons.lock_reset),
                    title: const Text('Đổi mật khẩu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changePassword(context, member.id),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 3,
                    ),
                    leading: Icon(Icons.logout, color: colors.error),
                    title: Text(
                      'Đăng xuất',
                      style: TextStyle(color: colors.error),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _signOut(context),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 930),
                  child: LayoutBuilder(
                    builder: (context, viewport) => viewport.maxWidth >= 740
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: identity),
                              const SizedBox(width: 20),
                              Expanded(child: actions),
                            ],
                          )
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 540),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                identity,
                                const SizedBox(height: 16),
                                actions,
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  final String memberId;

  const _PasswordDialog({required this.memberId});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _hidePasswords = true;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (SessionHelper.current.value?.id != widget.memberId) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await LocalDatabase.instance.changePassword(
        widget.memberId,
        _oldPassword.text,
        _newPassword.text,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, true);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa đổi được mật khẩu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Đổi mật khẩu'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _oldPassword,
                  enabled: !_saving,
                  obscureText: _hidePasswords,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                  ),
                  validator: (value) => (value?.isEmpty ?? true)
                      ? 'Nhập mật khẩu hiện tại.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPassword,
                  enabled: !_saving,
                  obscureText: _hidePasswords,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới',
                    helperText: 'Tối thiểu 8 ký tự',
                  ),
                  validator: (value) {
                    if ((value?.length ?? 0) < 8) {
                      return 'Mật khẩu cần tối thiểu 8 ký tự.';
                    }
                    if (value == _oldPassword.text) {
                      return 'Hãy chọn mật khẩu khác mật khẩu hiện tại.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmation,
                  enabled: !_saving,
                  obscureText: _hidePasswords,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu mới',
                  ),
                  validator: (value) => value != _newPassword.text
                      ? 'Hai mật khẩu chưa trùng nhau.'
                      : null,
                ),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _hidePasswords = !_hidePasswords),
                  icon: Icon(
                    _hidePasswords ? Icons.visibility : Icons.visibility_off,
                  ),
                  label: Text(_hidePasswords ? 'Hiện mật khẩu' : 'Ẩn mật khẩu'),
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
            child: Text(_saving ? 'Đang lưu…' : 'Lưu mật khẩu'),
          ),
        ],
      ),
    );
  }
}

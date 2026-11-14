import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_widgets.dart';
import 'local_database.dart';
import 'session_helper.dart';

class LoginPage extends StatefulWidget {
  final String title;

  const LoginPage({super.key, this.title = 'Đăng nhập'});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _saving = false;
  String? _error;

  Future<void> _signIn() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final member = await LocalDatabase.instance.signIn(
        _email.text.trim(),
        _password.text,
      );
      await SessionHelper.save(member);
      if (!mounted) return;
      TextInput.finishAutofillContext();
      setState(() => _saving = false);
      Navigator.pop(context, true);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Đăng nhập chưa thành công. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _openRegister() async {
    final email = await Navigator.pushNamed<String>(context, '/register');
    if (!mounted || email == null) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _error = null;
    });
  }

  void _fillDemo(String email, String password) {
    setState(() {
      _email.text = email;
      _password.text = password;
      _error = null;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !_saving,
      child: AccountFrame(
        title: widget.title,
        photo: 'assets/products/ca-phe-muoi.jpg',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      enabled: !_saving,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Nhập email của bạn.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      enabled: !_saving,
                      autofillHints: const [AutofillHints.password],
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Nhập mật khẩu của bạn.'
                          : null,
                    ),
                    if (_error != null) AccountFormError(message: _error!),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _signIn,
                      child: Text(_saving ? 'Đang đăng nhập…' : 'Đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text('Chưa có tài khoản?', style: theme.textTheme.bodyMedium),
                TextButton(
                  onPressed: _saving ? null : _openRegister,
                  child: const Text('Tạo tài khoản'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Điền tài khoản mẫu', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Quản trị viên'),
                        onPressed: _saving
                            ? null
                            : () =>
                                  _fillDemo('admin@cafemay.vn', 'Admin@12345'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.person_outline),
                        label: const Text('Thành viên'),
                        onPressed: _saving
                            ? null
                            : () => _fillDemo(
                                'member@cafemay.vn',
                                'Member@12345',
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

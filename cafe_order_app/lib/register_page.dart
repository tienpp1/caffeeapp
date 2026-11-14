import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_widgets.dart';
import 'local_database.dart';

class RegisterPage extends StatefulWidget {
  final String title;

  const RegisterPage({super.key, this.title = 'Đăng ký'});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _givenName = TextEditingController();
  final _surname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidePassword = true;
  bool _saving = false;
  String? _error;

  Future<void> _register() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final member = await LocalDatabase.instance.register(
        email: _email.text.trim(),
        password: _password.text,
        givenName: _givenName.text.trim(),
        surname: _surname.text.trim(),
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo tài khoản. Bạn có thể đăng nhập.'),
        ),
      );
      Navigator.pop(context, member.email);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa tạo được tài khoản. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _givenName.dispose();
    _surname.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surname = TextFormField(
      controller: _surname,
      enabled: !_saving,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.familyName],
      decoration: const InputDecoration(
        labelText: 'Họ và tên đệm',
        hintText: 'Không bắt buộc',
      ),
    );
    final givenName = TextFormField(
      controller: _givenName,
      enabled: !_saving,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.givenName],
      decoration: const InputDecoration(labelText: 'Tên'),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Nhập tên của bạn.' : null,
    );
    return PopScope(
      canPop: !_saving,
      child: AccountFrame(
        title: widget.title,
        photo: 'assets/products/tra-vai.jpg',
        child: AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, box) => box.maxWidth >= 375
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: surname),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: givenName),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            surname,
                            const SizedBox(height: 14),
                            givenName,
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  enabled: !_saving,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) =>
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? 'Nhập địa chỉ email hợp lệ.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  enabled: !_saving,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    helperText: 'Tối thiểu 8 ký tự',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'Mật khẩu cần tối thiểu 8 ký tự.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmation,
                  enabled: !_saving,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value != _password.text
                      ? 'Hai mật khẩu chưa trùng nhau.'
                      : null,
                ),
                if (_error != null) AccountFormError(message: _error!),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _register,
                  child: Text(
                    _saving ? 'Đang tạo tài khoản…' : 'Tạo tài khoản',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

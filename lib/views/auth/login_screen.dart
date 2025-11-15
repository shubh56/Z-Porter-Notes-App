// lib/views/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/app_viewmodel.dart';

/// LoginScreen — combined login / register UI.
/// Uses AppViewModel (Provider) for actions.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _isRegister = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  void _submit(AppViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    if (_isRegister) {
      await vm.register(email, pass);
    } else {
      await vm.signIn(email, pass);
    }
    if (vm.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(vm.error!)));
    } else if (vm.isLoggedIn) {
      // pop or navigate to notes list (provider root will rebuild)
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<AppViewModel>(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? 'Register' : 'Sign in')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        if (!v.contains('@')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter password';
                        if (v.length < 6) return 'Password >= 6 chars';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (vm.isBusy) const CircularProgressIndicator(),
                    if (!vm.isBusy)
                      ElevatedButton(
                        onPressed: () => _submit(vm),
                        child: Text(_isRegister ? 'Create account' : 'Sign in'),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _isRegister = !_isRegister);
                      },
                      child: Text(
                        _isRegister
                            ? 'Have an account? Sign in'
                            : 'Create an account',
                      ),
                    ),
                    if (!_isRegister)
                      TextButton(
                        onPressed: () async {
                          final email = _emailCtl.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter your email to reset password',
                                ),
                              ),
                            );
                            return;
                          }
                          await vm.sendPasswordReset(email);
                          if (vm.error != null) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(vm.error!)));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset email sent'),
                              ),
                            );
                          }
                        },
                        child: const Text('Forgot password?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

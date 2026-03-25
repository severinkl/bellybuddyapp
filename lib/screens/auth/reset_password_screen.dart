import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_button.dart';
import '../../config/constants.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwörter stimmen nicht überein.');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _error = 'Passwort muss mindestens 8 Zeichen lang sein.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .updatePassword(_passwordController.text);
      if (mounted) context.go(RoutePaths.dashboard);
    } catch (e) {
      setState(() => _error = 'Fehler beim Ändern des Passworts.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neues Passwort')),
      body: SafeArea(
        child: Padding(
          padding: AppConstants.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.destructive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.destructive),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Neues Passwort'),
              ),
              AppConstants.gap16,
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passwort bestätigen',
                ),
              ),
              AppConstants.gap24,
              BbButton(
                label: 'Passwort ändern',
                isLoading: _isLoading,
                onPressed: _handleReset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

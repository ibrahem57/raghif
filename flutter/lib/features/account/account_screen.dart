import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../domain/models/user_model.dart';
import '../auth/bloc/auth_bloc.dart';
import '../queue/confirm_action.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, this.embedded = false});
  final bool embedded;

  Future<void> _edit(BuildContext context, UserModel user) async {
    final bloc = context.read<AuthBloc>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _ProfileEditor(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: embedded ? null : AppBar(title: const Text('حسابي')),
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is! Authenticated) {
              return const Center(
                child: Text(
                  'سجّل الدخول لعرض حسابك',
                  style: AppTypography.bodyLarge,
                ),
              );
            }
            final user = state.user;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.accentContainer,
                          child: Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Detail(
                              label: 'رقم الهوية',
                              value: user.nationalId,
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: user.nationalId),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ رقم الهوية'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('نسخ رقم الهوية'),
                            ),
                            const Divider(),
                            _Detail(label: 'رقم الجوال', value: user.phone),
                            const Divider(),
                            _Detail(
                              label: 'محفظة جوال باي',
                              value: user.jawwalPayNumber?.isNotEmpty == true
                                  ? user.jawwalPayNumber!
                                  : 'غير مضافة',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'رقم الهوية ونوع الحساب وحالة التحقق لا تتغير من هذه الصفحة.',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: 'تعديل البيانات',
                        onPressed: state.profileSaving
                            ? null
                            : () => _edit(context, user),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        onPressed: () => confirmLogout(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.bodyLarge),
      ],
    ),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.user});
  final UserModel user;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _wallet = TextEditingController(
    text: widget.user.jawwalPayNumber ?? '',
  );
  bool _submitted = false;
  static final _phonePattern = RegExp(r'^05[69][0-9]{7}$');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_submitted &&
            state is Authenticated &&
            !state.profileSaving &&
            state.profileError == null) {
          Navigator.of(context).pop();
        }
        if (state is Unauthenticated) Navigator.of(context).pop();
      },
      builder: (context, state) {
        final saving = state is Authenticated && state.profileSaving;
        final error = state is Authenticated && _submitted
            ? state.profileError
            : null;
        return PopScope(
          canPop: !saving,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('تعديل البيانات', style: AppTypography.titleLarge),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('profile-name'),
                    controller: _name,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'أدخل الاسم'
                        : value!.trim().length > 100
                        ? 'الاسم طويل جداً'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('profile-phone'),
                    controller: _phone,
                    enabled: !saving,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'رقم الجوال'),
                    validator: (value) =>
                        _phonePattern.hasMatch(value?.trim() ?? '')
                        ? null
                        : 'أدخل رقم جوال صحيحاً من 10 أرقام',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('profile-wallet'),
                    controller: _wallet,
                    enabled: !saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم محفظة جوال باي (اختياري)',
                    ),
                    validator: (value) =>
                        value!.trim().isEmpty ||
                            _phonePattern.hasMatch(value.trim())
                        ? null
                        : 'أدخل رقم محفظة صحيحاً من 10 أرقام',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تغيير رقم الجوال لا يعني التحقق منه برسالة SMS.',
                    style: AppTypography.bodySmall,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.danger,
                        ),
                        semanticsLabel: error,
                      ),
                    ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'حفظ التغييرات',
                    loading: saving,
                    onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      setState(() => _submitted = true);
                      context.read<AuthBloc>().add(
                        UpdateProfileRequestedEvent(
                          name: _name.text,
                          phone: _phone.text,
                          jawwalPayNumber: _wallet.text,
                        ),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

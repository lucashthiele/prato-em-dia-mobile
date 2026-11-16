import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/widgets/app_error_banner.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository_impl.dart';
import '../../../auth/domain/auth_repository.dart';
import '../../../auth/presentation/cubit/change_password_cubit.dart';
import '../../../auth/presentation/pages/change_password_page.dart';
import '../../../prescription/data/current_prescription_api.dart';
import '../../../prescription/domain/current_prescription.dart';
import '../../../prescription/domain/current_prescription_repository.dart';
import '../../../prescription/presentation/pages/prescription_page.dart';
import '../../../prescription/presentation/widgets/no_prescription_empty_state.dart';
import '../../data/profile_api.dart';
import '../../domain/patient_profile.dart';
import '../../domain/profile_repository.dart';
import '../cubit/profile_cubit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.onLogout,
    this.dio,
    this.repository,
    this.prescriptionRepository,
    this.authRepository,
    super.key,
  });

  final Future<void> Function() onLogout;

  /// The shared [Dio] (cookie session). Optional when a [repository] is given.
  final Dio? dio;
  final ProfileRepository? repository;

  /// Prescrição vigente (cartão "Minha prescrição"). Padrão: a partir de [dio].
  final CurrentPrescriptionRepository? prescriptionRepository;

  /// Troca de senha pelo Perfil. Padrão: a partir de [dio].
  final AuthRepository? authRepository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileCubit _cubit;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _birthDate;
  bool _editing = false;
  bool _loggingOut = false;
  late final CurrentPrescriptionRepository _prescriptions;
  late final AuthRepository _auth;

  @override
  void initState() {
    super.initState();
    _prescriptions =
        widget.prescriptionRepository ?? CurrentPrescriptionApi(widget.dio!);
    _auth = widget.authRepository ?? AuthRepositoryImpl(AuthApi(widget.dio!));
    _cubit = ProfileCubit(widget.repository ?? ProfileApi(widget.dio!))..load();
  }

  @override
  void dispose() {
    _cubit.close();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _startEditing(PatientProfile profile) {
    _name.text = profile.fullName;
    _phone.text = profile.phone ?? '';
    setState(() {
      _birthDate = profile.birthDate;
      _editing = true;
    });
  }

  Future<void> _pickBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final chosen = await showDatePicker(
      context: context,
      initialDate: _birthDate == null
          ? DateTime(today.year - 18, today.month, today.day)
          : DateTime.parse(_birthDate!),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Data de nascimento',
    );
    if (chosen != null && mounted) {
      setState(() => _birthDate = _isoDate(chosen));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await _cubit.save(
      PatientProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        birthDate: _birthDate,
      ),
    );
    if (saved && mounted) setState(() => _editing = false);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  /// Troca de senha com a senha atual (Q13). O servidor revoga os refresh
  /// tokens de todos os aparelhos e devolve cookies novos a este: o paciente
  /// segue logado aqui; só os outros aparelhos caem.
  Future<void> _openChangePassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final changed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => BlocProvider(
          create: (_) =>
              ChangePasswordCubit(_auth, mode: ChangePasswordMode.fromProfile),
          child: ChangePasswordPage(
            mode: ChangePasswordMode.fromProfile,
            onPasswordChanged: (_) => Navigator.of(routeContext).pop(true),
            onCancel: () => Navigator.of(routeContext).pop(false),
          ),
        ),
      ),
    );
    if (changed == true) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Senha alterada. Os outros aparelhos foram desconectados.',
          ),
        ),
      );
    }
  }

  void _openPrescription(String? nutritionistName) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrescriptionPage(
          repository: _prescriptions,
          nutritionistName: nutritionistName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando perfil',
              ),
            );
          }
          if (state.status == ProfileStatus.error && state.profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppErrorBanner(
                      message:
                          state.errorMessage ??
                          'Não foi possível carregar seu perfil.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _cubit.load,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          final profile = state.profile!;
          return SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                28,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                      child: const Icon(Icons.person_rounded, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seu perfil',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          Text(
                            profile.fullName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (state.errorMessage != null) ...[
                  AppErrorBanner(message: state.errorMessage!),
                  const SizedBox(height: 16),
                ],
                if (state.saveMessage != null) ...[
                  Semantics(liveRegion: true, child: Text(state.saveMessage!)),
                  const SizedBox(height: 16),
                ],
                Text(
                  'MEUS DADOS',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_editing) _editForm(state) else _readOnlyProfile(profile),
                const SizedBox(height: 28),
                Text(
                  'NUTRICIONISTA',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (state.isLoadingRelationship)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Carregando vínculo',
                  )
                else if (state.relationshipError != null) ...[
                  AppErrorBanner(message: state.relationshipError!),
                  TextButton(
                    onPressed: _cubit.loadRelationship,
                    child: const Text('Tentar novamente'),
                  ),
                ] else if (state.relationship == null)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_outline_rounded),
                    title: Text('Nenhum vínculo ativo no momento.'),
                  )
                else
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        child: const Icon(Icons.health_and_safety_outlined),
                      ),
                      title: Text(state.relationship!.nutritionistFullName),
                      subtitle: const Text('Nutricionista responsável'),
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  'PRESCRIÇÃO',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _PrescriptionCard(
                  repository: _prescriptions,
                  onOpen: () => _openPrescription(
                    state.relationship?.nutritionistFullName,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'SEGURANÇA',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('Trocar senha'),
                    subtitle: const Text(
                      'Ao trocar, os outros aparelhos serão desconectados.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openChangePassword,
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: _loggingOut || state.isSaving ? null : _logout,
                  icon: _loggingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(_loggingOut ? 'Saindo...' : 'Sair da conta'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _readOnlyProfile(PatientProfile profile) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _detail('Nome completo', profile.fullName),
      const Divider(height: 24),
      _detail(
        'Telefone',
        profile.phone?.isNotEmpty == true ? profile.phone! : 'Não informado',
      ),
      const Divider(height: 24),
      _detail('Data de nascimento', _displayDate(profile.birthDate)),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _startEditing(profile),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar dados'),
        ),
      ),
    ],
  );

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );

  Widget _editForm(ProfileState state) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _name,
          enabled: !state.isSaving,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          maxLength: 160,
          decoration: const InputDecoration(labelText: 'Nome completo'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Informe seu nome completo.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          enabled: !state.isSaving,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          maxLength: 32,
          decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: state.isSaving ? null : _pickBirthDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('Nascimento: ${_displayDate(_birthDate)}'),
        ),
        if (_birthDate != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: state.isSaving
                  ? null
                  : () => setState(() => _birthDate = null),
              child: const Text('Remover data'),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: state.isSaving ? null : _save,
          child: state.isSaving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar dados'),
        ),
        TextButton(
          onPressed: state.isSaving
              ? null
              : () => setState(() => _editing = false),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _displayDate(String? date) {
  if (date == null) return 'Não informada';
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}

/// Cartão "Minha prescrição": resumo da versão vigente ou estado vazio (Q24).
class _PrescriptionCard extends StatefulWidget {
  const _PrescriptionCard({required this.repository, required this.onOpen});

  final CurrentPrescriptionRepository repository;
  final VoidCallback onOpen;

  @override
  State<_PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends State<_PrescriptionCard> {
  bool _loading = true;
  CurrentPrescription? _prescription;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prescription = await widget.repository.fetchCurrent();
      if (!mounted) return;
      setState(() {
        _prescription = prescription;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorMessages.ofError(
          error,
          fallback: 'Não foi possível carregar sua prescrição.',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Carregando prescrição',
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppErrorBanner(message: _error!),
          TextButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      );
    }
    final prescription = _prescription;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.assignment_outlined),
        title: const Text('Minha prescrição'),
        subtitle: Text(
          prescription == null
              ? NoPrescriptionEmptyState.message
              : [
                  if (prescription.title != null) prescription.title!,
                  'Versão ${prescription.number}',
                ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: widget.onOpen,
      ),
    );
  }
}

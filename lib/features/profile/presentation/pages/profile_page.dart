import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_environment.dart';
import '../../../../core/design_system/widgets/app_error_banner.dart';
import '../../../auth/domain/auth_session.dart';
import '../../data/profile_api.dart';
import '../../domain/patient_profile.dart';
import '../../domain/profile_repository.dart';
import '../cubit/profile_cubit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.session,
    required this.onLogout,
    this.refreshSession,
    this.repository,
    super.key,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;

  /// Supply the host's session renewal method to retry an expired bearer once.
  final Future<AuthSession?> Function()? refreshSession;
  final ProfileRepository? repository;

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

  @override
  void initState() {
    super.initState();
    _cubit = ProfileCubit(
      widget.repository ??
          ProfileApi(
            Dio(
              BaseOptions(
                baseUrl: AppEnvironment.apiBaseUrl,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
                headers: const {'Accept': 'application/json'},
              ),
            ),
            widget.session,
            refreshSession: widget.refreshSession,
          ),
    )..load();
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

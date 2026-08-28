import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  DateTime? _dateOfBirth;
  Gender _gender = Gender.undisclosed;
  BloodGroup _bloodGroup = BloodGroup.unknown;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProfileProvider>();
      if (provider.profile == null) {
        provider.load();
      } else {
        _prefill(provider.profile!);
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _prefill(UserProfile p) {
    if (_prefilled) return;
    _prefilled = true;
    _firstNameController.text = p.firstName ?? '';
    _lastNameController.text = p.lastName ?? '';
    _phoneController.text = p.phone ?? '';
    _cityController.text = p.city ?? '';
    _countryController.text = p.country ?? '';
    _heightController.text = p.heightCm?.toString() ?? '';
    _weightController.text = p.weightKg?.toString() ?? '';
    _dateOfBirth = p.dateOfBirth;
    _gender = p.gender;
    _bloodGroup = p.bloodGroup;
  }

  Future<void> _pickAvatar() async {
    final provider = context.read<ProfileProvider>();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final size = await picked.length();
    if (size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('That image is larger than 5 MB. Try a smaller photo.')));
      }
      return;
    }
    await provider.uploadAvatar(picked.path);
    if (mounted && provider.avatarError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.avatarError!)));
    }
  }

  Future<void> _pickGender() async {
    final selected = await showModalBottomSheet<Gender>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<Gender>(
          groupValue: _gender,
          onChanged: (g) => Navigator.of(context).pop(g),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: Gender.values
                .map((g) => RadioListTile<Gender>(title: Text(_genderLabels[g]!), value: g))
                .toList(),
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _gender = selected);
  }

  Future<void> _submit() async {
    final provider = context.read<ProfileProvider>();
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());

    final ok = await provider.save({
      if (_firstNameController.text.trim().isNotEmpty) 'firstName': _firstNameController.text.trim(),
      if (_lastNameController.text.trim().isNotEmpty) 'lastName': _lastNameController.text.trim(),
      'gender': _gender.apiValue,
      'bloodGroup': _bloodGroup.apiValue,
      if (_dateOfBirth != null) 'dateOfBirth': _dateOfBirth!.toIso8601String(),
      if (_phoneController.text.trim().isNotEmpty) 'phone': _phoneController.text.trim(),
      if (_cityController.text.trim().isNotEmpty) 'city': _cityController.text.trim(),
      if (_countryController.text.trim().isNotEmpty) 'country': _countryController.text.trim(),
      'heightCm': ?height,
      'weightKg': ?weight,
    });

    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final profile = provider.profile;

    if (profile != null) _prefill(profile);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: provider.loading && profile == null
          ? const LoadingView()
          : provider.error != null && profile == null
          ? ErrorView(message: provider.error!, onRetry: () => provider.load())
          : profile == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          AppAvatar(
                            name: fullName(
                              firstName: profile.firstName,
                              lastName: profile.lastName,
                              username: profile.username,
                            ),
                            imageUrl: profile.imageUrl,
                            size: 96,
                          ),
                          if (provider.avatarUploading)
                            const Positioned.fill(
                              child: CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: provider.avatarUploading ? null : _pickAvatar,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Change photo'),
                      ),
                      const SizedBox(height: 4),
                      Text('JPEG or PNG, up to 5 MB', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (provider.saveError != null) ...[
                  _ErrorBanner(message: provider.saveError!),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'First name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateOfBirth ?? DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _dateOfBirth = picked);
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_dateOfBirth != null ? formatDate(_dateOfBirth!) : 'Date of birth'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _pickGender(),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Gender'),
                          child: Text(_genderLabels[_gender]!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<BloodGroup>(
                        initialValue: _bloodGroup,
                        decoration: const InputDecoration(labelText: 'Blood group'),
                        items: BloodGroup.values
                            .map((b) => DropdownMenuItem(value: b, child: Text(b.label)))
                            .toList(),
                        onChanged: (b) => setState(() => _bloodGroup = b ?? _bloodGroup),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _countryController,
                        decoration: const InputDecoration(labelText: 'Country'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Height (cm)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight (kg)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: provider.saving ? null : _submit,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: provider.saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save changes'),
                ),
              ],
            ),
    );
  }
}

const _genderLabels = {
  Gender.male: 'Male',
  Gender.female: 'Female',
  Gender.other: 'Other',
  Gender.undisclosed: 'Prefer not to say',
};

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: colorScheme.onErrorContainer))),
        ],
      ),
    );
  }
}

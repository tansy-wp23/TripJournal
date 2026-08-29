import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../validation/photo_validation.dart';
import '../../../validation/profile_validation.dart';
import '../controller/profile_controller.dart';
import '../widgets/country_selector.dart';
import '../widgets/date_of_birth_field.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/travel_interest_selector.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  bool _saving = false;
  XFile? _pickedAvatar;
  Uint8List? _pickedAvatarBytes;
  bool _avatarRemoved = false;
  late DateTime? _dateOfBirth;
  late String? _country;
  late final Set<String> _selectedInterests;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileControllerProvider).profile;
    _displayNameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
    _dateOfBirth = profile?.dateOfBirth;
    _country = profile?.country;
    _selectedInterests = {...?profile?.travelInterests};
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  /// Offers camera vs. gallery, then invokes the real device picker — same
  /// pattern as the trip cover photo picker. Any failure (denied permission,
  /// no camera on this device/desktop, user backing out of the OS picker) is
  /// swallowed into a SnackBar rather than thrown; a profile picture is
  /// always optional.
  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const Key('pick-avatar-photo-camera'),
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('pick-avatar-photo-gallery'),
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return; // user backed out of the OS picker

      final bytes = await picked.readAsBytes();
      final sizeError = validatePhotoSize(bytes.length);
      if (sizeError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(sizeError)));
        return;
      }

      setState(() {
        _pickedAvatar = picked;
        _pickedAvatarBytes = bytes;
        _avatarRemoved = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't access photos — you can continue without one.",
          ),
        ),
      );
    }
  }

  void _removeAvatar() => setState(() {
    _pickedAvatar = null;
    _pickedAvatarBytes = null;
    _avatarRemoved = true;
  });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final controller = ref.read(profileControllerProvider.notifier);

    final nameError = await controller.updateDisplayName(
      _displayNameController.text,
    );
    if (!mounted) return;
    if (nameError != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(nameError)));
      return;
    }

    String? avatarError;
    final pending = _pickedAvatar;
    if (pending != null) {
      avatarError = await controller.updateAvatar(pending);
    } else if (_avatarRemoved) {
      avatarError = await controller.removeAvatar();
    }
    if (!mounted) return;
    if (avatarError != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(avatarError)));
      return;
    }

    final detailsError = await controller.updateTravelDetails(
      dateOfBirth: _dateOfBirth,
      country: _country,
      travelInterests: _selectedInterests,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (detailsError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detailsError)));
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider).profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            key: const Key('profile-save-button'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileAvatar(
                      radius: 48,
                      avatarUrl: _avatarRemoved ? null : profile?.avatarUrl,
                      previewBytes: _pickedAvatarBytes,
                      initial: profile != null && profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : '?',
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: InkWell(
                        key: const Key('profile-avatar-picker-button'),
                        onTap: _saving ? null : _pickAvatar,
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_pickedAvatarBytes != null ||
                  (profile?.avatarUrl != null && !_avatarRemoved))
                Center(
                  child: TextButton(
                    key: const Key('profile-remove-avatar-button'),
                    onPressed: _saving ? null : _removeAvatar,
                    child: const Text('Remove photo'),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('profile-display-name-field'),
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                  helperText: 'How your name appears across the app.',
                ),
                textInputAction: TextInputAction.done,
                validator: validateProfileDisplayName,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              Text(
                'Email: ${profile?.email ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email is managed by your Google account and cannot be changed here.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'Travel interests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TravelInterestSelector(
                selected: _selectedInterests,
                onChanged: (next) => setState(() {
                  _selectedInterests
                    ..clear()
                    ..addAll(next);
                }),
              ),
              const SizedBox(height: 16),
              DateOfBirthField(
                value: _dateOfBirth,
                onChanged: (date) => setState(() => _dateOfBirth = date),
                errorText: validateDateOfBirth(_dateOfBirth),
              ),
              const SizedBox(height: 16),
              CountrySelector(
                value: _country,
                onChanged: (country) => setState(() => _country = country),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                key: const Key('profile-cancel-button'),
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

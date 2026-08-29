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

/// Shown once, immediately after a brand-new account's first sign-in
/// (`AuthStatus.needsOnboarding` — see `AuthController.status`). Collects the
/// fields `Profile` gained for this feature: avatar, name, travel interests,
/// date of birth, country.
///
/// Never traps the user: every field here is optional except the display
/// name, and "Skip for now" bypasses even that, so there is always a way off
/// this screen and into the app (`IMPLEMENTATION_PLAN_PROFILE_ONBOARDING.md`
/// — "Skippable, never trapping").
class ProfileOnboardingScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  ConsumerState<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState
    extends ConsumerState<ProfileOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  DateTime? _dateOfBirth;
  String? _country;
  final Set<String> _selectedInterests = {};
  XFile? _pickedAvatar;
  Uint8List? _pickedAvatarBytes;
  bool _saving = false;
  bool _loadedInitialValues = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(profileControllerProvider.notifier).loadProfile();
      _applyInitialValuesOnce();
    });
  }

  /// The profile a brand-new user has going into this screen already has a
  /// Google-derived display name (`AuthController._deriveDisplayName`) — the
  /// field starts pre-filled with that instead of empty, so "Continue"
  /// without touching the name field still saves a real one.
  void _applyInitialValuesOnce() {
    if (_loadedInitialValues || !mounted) return;
    final profile = ref.read(profileControllerProvider).profile;
    if (profile == null) return;
    _loadedInitialValues = true;
    setState(() {
      _displayNameController.text = profile.displayName;
      _dateOfBirth = profile.dateOfBirth;
      _country = profile.country;
      _selectedInterests.addAll(profile.travelInterests);
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const Key('onboarding-avatar-camera'),
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('onboarding-avatar-gallery'),
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
      if (picked == null) return;

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

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final controller = ref.read(profileControllerProvider.notifier);

    final pendingAvatar = _pickedAvatar;
    if (pendingAvatar != null) {
      final avatarError = await controller.updateAvatar(pendingAvatar);
      if (!mounted) return;
      if (avatarError != null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(avatarError)));
        return;
      }
    }

    final error = await controller.completeOnboarding(
      displayName: _displayNameController.text,
      dateOfBirth: _dateOfBirth,
      country: _country,
      travelInterests: _selectedInterests,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      // Entered data is never lost on failure — the form fields still hold
      // everything the user typed/picked, and AuthGate keeps this screen on
      // screen until profileCompleted actually flips.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
    // On success, refreshProfile() (called inside completeOnboarding) flips
    // AuthController.status to authenticated, and AuthGate swaps this screen
    // out on its own — no explicit navigation needed here.
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    final error = await ref
        .read(profileControllerProvider.notifier)
        .skipOnboarding();
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider).profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to TripJournal'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const Key('onboarding-skip-button'),
            onPressed: _saving ? null : _skip,
            child: const Text('Skip for now'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "Let's personalize your profile",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Add a few details, or skip and fill them in later from '
                'your profile page.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileAvatar(
                      radius: 48,
                      avatarUrl: profile?.avatarUrl,
                      previewBytes: _pickedAvatarBytes,
                      initial: _displayNameController.text.isNotEmpty
                          ? _displayNameController.text[0].toUpperCase()
                          : '?',
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: InkWell(
                        key: const Key('onboarding-avatar-picker-button'),
                        onTap: _saving ? null : _pickAvatar,
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
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
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('onboarding-display-name-field'),
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                validator: validateProfileDisplayName,
              ),
              const SizedBox(height: 24),
              Text(
                'What do you enjoy when travelling?',
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
              const SizedBox(height: 24),
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
              const SizedBox(height: 32),
              FilledButton(
                key: const Key('onboarding-continue-button'),
                onPressed: _saving ? null : _continue,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

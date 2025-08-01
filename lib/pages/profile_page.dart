import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/custom_page_route.dart'; // Our custom animation
import './change_password_page.dart'; // The new page we created
import '../models/profile.dart'; // Make sure your Profile model has all the fields
import '../utils/constants.dart'; // Your constants for supabase, etc.

class ProfilePage extends StatefulWidget {
  // We can pass a userId to view someone else's profile
  final String? userId;

  const ProfilePage({Key? key, this.userId}) : super(key: key);

  static Route<void> route({String? userId}) {
    return SlideRightRoute(page: ProfilePage(userId: userId));
  }

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _staggerAnimationController;

  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isMyProfile = false;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _staggerAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fetchProfile();
  }

  @override
  void dispose() {
    _staggerAnimationController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile({bool forceRefresh = false}) async {
    if (!forceRefresh) setState(() => _isLoading = true);

    // SMART LOGIC: Decide which profile to fetch
    final targetUserId = widget.userId ?? supabase.auth.currentUser!.id;
    _isMyProfile = (targetUserId == supabase.auth.currentUser!.id);

    try {
      final response = await supabase.from('profiles').select().eq('id', targetUserId).single();
      if (mounted) {
        _profile = Profile.fromMap(response);
        _usernameController.text = _profile!.username;
        _phoneController.text = _profile!.phoneNumber ?? '';
        _bioController.text = _profile!.bio ?? '';
        if (!forceRefresh) _staggerAnimationController.forward();
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(message: "Could not fetch profile.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final newUsername = _usernameController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newBio = _bioController.text.trim();

    try {
      await supabase.from('profiles').update({
        'username': newUsername,
        'phone_number': newPhone.isNotEmpty ? newPhone : null,
        'bio': newBio,
      }).eq('id', _profile!.id);
      
      if (mounted) {
        await _fetchProfile(forceRefresh: true);
        setState(() => _isEditing = false);
        context.showSnackBar(message: 'Profile updated!');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(message: "Failed to update profile.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onUploadAvatar() async {
    final imagePicker = ImagePicker();
    final imageFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (imageFile == null) return;

    setState(() => _isLoading = true);
    
    try {
      final userId = supabase.auth.currentUser!.id;
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      
      final uniqueFileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$uniqueFileName';
      
      // Upload the new avatar
      await supabase.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      
      // Get the new public URL
      final newImageUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      // Update the user's profile with the new URL
      await supabase.from('profiles').update({'avatar_url': newImageUrl}).eq('id', userId);
      
      if (mounted) {
        await _fetchProfile(forceRefresh: true);
        context.showSnackBar(message: 'Avatar updated!');
      }
    } on StorageException catch (e) {
      if (mounted) context.showErrorSnackBar(message: "Storage Error: ${e.message}");
    } catch (e) {
      if (mounted) context.showErrorSnackBar(message: "Failed to upload avatar.");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMyProfile ? 'My Profile' : 'Profile'),
        actions: [
          if (_isMyProfile && !_isLoading)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: _isEditing
                  ? IconButton(
                      key: const ValueKey('save_icon'),
                      icon: const Icon(Icons.check_rounded),
                      onPressed: _updateProfile,
                      tooltip: 'Save Changes',
                    )
                  : IconButton(
                      key: const ValueKey('edit_icon'),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => setState(() => _isEditing = true),
                      tooltip: 'Edit Profile',
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Profile not found.'))
              // Decide which view to show (edit or display)
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: (_isMyProfile && _isEditing) 
                         ? _buildEditView() 
                         : _buildDisplayView(),
                ), 
    );
  }

  Widget _buildDisplayView() {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => _fetchProfile(forceRefresh: true),
      child: ListView(
        key: const ValueKey('displayView'),
        padding: const EdgeInsets.all(24.0),
        children: [
          _AnimatedDisplayItem(delay: 0, controller: _staggerAnimationController, child: Center(child: _buildAvatar())),
          const SizedBox(height: 24),
          _AnimatedDisplayItem(delay: 0.1, controller: _staggerAnimationController, child: Text(_profile!.username, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          _AnimatedDisplayItem(
              delay: 0.2, controller: _staggerAnimationController,
              child: Text(
                  _profile!.bio?.isNotEmpty == true ? _profile!.bio! : 'No biography available.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              )),
          const SizedBox(height: 24),
          const Divider(),
          _AnimatedDisplayItem(
              delay: 0.3, controller: _staggerAnimationController,
              child: _ProfileInfoTile(
                  icon: Icons.phone_outlined, title: 'Phone',
                  value: _profile!.phoneNumber?.isNotEmpty == true ? _profile!.phoneNumber! : 'Not set',
          )),
          _AnimatedDisplayItem(
              delay: 0.3, controller: _staggerAnimationController,
              child: _ProfileInfoTile(
                  icon: Icons.calendar_today_outlined, title: 'Member Since',
                  value: DateFormat.yMMMMd().format(_profile!.createdAt),
              )),
              const SizedBox(height: 20),
              if (_isMyProfile)
            _AnimatedDisplayItem(
              delay: 0.5, controller: _staggerAnimationController,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(ChangePasswordPage.route()),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Change Password'),
            )),
        ],
      ),
    );
  }

  Widget _buildEditView() {
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('editView'),
        padding: const EdgeInsets.all(24.0),
        children: [
          Center(child: _buildAvatar()), // Avatar is also shown in edit mode
          const SizedBox(height: 24),
          TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)), validator: (val) => val!.isEmpty ? 'Username cannot be empty' : null),
          const SizedBox(height: 20),
          TextFormField(controller: _bioController, decoration: const InputDecoration(labelText: 'Biography', border: OutlineInputBorder(), alignLabelWithHint: true, prefixIcon: Icon(Icons.description_outlined)), maxLines: 3),
          const SizedBox(height: 20),
          TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
          const SizedBox(height: 24),
          ElevatedButton.icon(icon: const Icon(Icons.save), onPressed: _updateProfile, label: const Text('Save Changes')),
          const SizedBox(height: 8),
          TextButton(onPressed: () => setState(() => _isEditing = false), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          backgroundImage: _profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty
              ? CachedNetworkImageProvider(_profile!.avatarUrl!)
              : null,
          child: (_profile?.avatarUrl == null || _profile!.avatarUrl!.isEmpty)
              ? Text(_profile!.username.substring(0, 2).toUpperCase(), style: const TextStyle(fontSize: 40))
              : null,
        ),
        if (_isMyProfile)
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: _onUploadAvatar,
                customBorder: const CircleBorder(),
                child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.edit, color: Colors.white, size: 20)),
              ),
            ),
          ),
      ],
    );
  }
}

// Helper widget for staggered animation
class _AnimatedDisplayItem extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;
  const _AnimatedDisplayItem({required this.controller, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}

// Helper widget for information tiles (e.g., Member Since)
class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _ProfileInfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
      ),
    );
  }
}
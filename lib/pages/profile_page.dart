import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // We'll use this for nice date formatting

import '../models/profile.dart'; // Your existing profile model
import '../utils/constants.dart'; // Your constants for supabase instance

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  // A clean way to handle routing
  static Route<void> route() {
    return MaterialPageRoute(
      builder: (context) => const ProfilePage(),
    );
  }

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  
  // For the animation
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // To fetch the profile data asynchronously
  late final Future<Profile> _profileFuture;

  @override
  void initState() {
    super.initState();

    // Setup the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    _slideAnimation = Tween(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animationController, curve: Curves.easeOut));

    // Fetch the profile data when the page loads
    _profileFuture = _fetchProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Fetches the profile for the currently logged-in user.
  Future<Profile> _fetchProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final response =
        await supabase.from('profiles').select().eq('id', userId).single();
    
    // Create a Profile object from the response data
    final profile = Profile.fromMap(response);
    
    // Start the animation once data is fetched successfully
    _animationController.forward();

    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: FutureBuilder<Profile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          // While data is loading, show a spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // If there's an error, show an error message
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error.toString()}'));
          }
          // If data is loaded successfully, build the animated profile view
          if (snapshot.hasData) {
            final profile = snapshot.data!;
            return _buildAnimatedProfile(profile);
          }
          
          return const Center(child: Text('Something went wrong.'));
        },
      ),
    );
  }

  /// Builds the animated content of the profile page.
  Widget _buildAnimatedProfile(Profile profile) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Big circle avatar with user's initials
              CircleAvatar(
                radius: 50,
                child: Text(
                  profile.username.substring(0, 2).toUpperCase(),
                  style: const TextStyle(fontSize: 40),
                ),
              ),
              const SizedBox(height: 24),
              // Username
              Text(
                profile.username,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Default Biography
              Text(
                'Lover of technology and sciences and building with future series!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              // Member since section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Member since ${DateFormat.yMMMMd().format(profile.createdAt)}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
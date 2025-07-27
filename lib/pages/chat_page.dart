import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart'; // Import Provider for animations
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart';

import '../models/message.dart';
import '../models/profile.dart';
import '../utils/constants.dart';
import '../providers/theme_provider.dart'; // Import ThemeProvider for animations

// Import your other pages to navigate to them
import './splash_page.dart';
import './profile_page.dart';
import './settings_page.dart';

Future<void> logout() async {
  FlutterBackgroundService().invoke('stop');
  await Supabase.instance.client.auth.signOut();
}

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (context) => const ChatPage(),
    );
  }

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final Stream<List<Message>> _messagesStream;
  final Map<String, Profile> _profileCache = {};

  @override
  void initState() {
    super.initState();
    final myUserId = supabase.auth.currentUser!.id;

    FlutterBackgroundService().invoke('set_user', {'userId': myUserId});
    // The stream for the UI remains the same
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((maps) => maps
            .map((map) => Message.fromMap(map: map, myUserId: myUserId))
            .toList());
  }

  Future<void> _loadProfileCache(String profileId) async {
    if (_profileCache.containsKey(profileId)) return;
    try {
      final data =
          await supabase.from('profiles').select().eq('id', profileId).single();
      if (mounted) {
        setState(() {
          _profileCache[profileId] = Profile.fromMap(data);
        });
      }
    } catch (e) {
      print('Error loading profile $profileId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Future Series Chat')),
      body: StreamBuilder<List<Message>>(
        stream: _messagesStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final messages = snapshot.data!;
            return Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: Text('Start your conversation now :)'),
                        )
                      : ListView.builder(
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            _loadProfileCache(message.profileId);

                            // The ChatBubble widget now handles its own animation
                            return _ChatBubble(
                              // Using a unique key helps Flutter manage animations better
                              key: ValueKey(message.id),
                              message: message,
                              profile: _profileCache[message.profileId],
                            );
                          },
                        ),
                ),
                const _MessageBar(),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      // --- The drawer now has all the navigation options ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Text(
                'Future Series',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(ProfilePage.route());
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(SettingsPage.route());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                await logout();
                navigator.pushReplacement(MaterialPageRoute(
                    builder: (context) => const SplashPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
//                        WIDGETS WITHIN THE PAGE
// ===================================================================

class _MessageBar extends StatefulWidget {
  const _MessageBar({Key? key}) : super(key: key);

  @override
  State<_MessageBar> createState() => _MessageBarState();
}

class _MessageBarState extends State<_MessageBar> {
  late final TextEditingController _textController;

  @override
  void initState() {
    _textController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitMessage() async {
    final text = _textController.text;
    final myUserId = supabase.auth.currentUser!.id;
    if (text.isEmpty) return;
    _textController.clear();
    try {
      await supabase.from('messages').insert({
        'profile_id': myUserId,
        'content': text,
      });
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('An unexpected error occurred.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Theme.of(context).cardColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  keyboardType: TextInputType.text,
                  maxLines: null,
                  autofocus: true,
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.all(8),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _submitMessage(),
                icon: Icon(Icons.send_outlined, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- This is the final, complete, and animated version of _ChatBubble ---
class _ChatBubble extends StatefulWidget {
  const _ChatBubble({
    Key? key,
    required this.message,
    required this.profile,
  }) : super(key: key);

  final Message message;
  final Profile? profile;

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Default animation setup, this will be used by Scale and Fade
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    // Start the animation when the widget is built
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme provider but don't listen to its changes here
    // as we don't want to rebuild the entire animation for a theme change.
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // The core widget that holds the bubble's content
    Widget bubble = _buildBubbleContent(context);

    // This switch statement chooses the correct animation wrapper for the bubble
    switch (themeProvider.animationType) {
      case BubbleAnimationType.fade:
        return FadeTransition(opacity: _animation, child: bubble);
      
      case BubbleAnimationType.scale:
        return ScaleTransition(scale: _animation, child: bubble);

      case BubbleAnimationType.slide:
        // For slide, we need a specific Offset animation
        final slideAnimation = Tween(
          begin: widget.message.isMine ? const Offset(1, 0) : const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
        return SlideTransition(position: slideAnimation, child: bubble);
      
      case BubbleAnimationType.none:
      default:
        // If no animation is selected, just return the bubble itself
        return bubble;
    }
  }

  // This helper function builds the bubble content to keep the code clean.
  // This part is now theme-aware and fixes the color issues.
  Widget _buildBubbleContent(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = widget.message.isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = widget.message.isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    List<Widget> chatContents = [
      if (!widget.message.isMine)
        CircleAvatar(
          child: widget.profile == null
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(widget.profile!.username.substring(0, 2).toUpperCase()),
        ),
      const SizedBox(width: 12),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.message.content,
            style: TextStyle(color: textColor),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(format(widget.message.createdAt, locale: 'en_short')),
      const SizedBox(width: 60),
    ];

    if (widget.message.isMine) {
      chatContents = chatContents.reversed.toList();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: widget.message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: chatContents,
      ),
    );
  }
}
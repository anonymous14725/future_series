import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:context_menus/context_menus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:future_series_chat/pages/image_viewer_page.dart';
import 'package:future_series_chat/pages/pdf_viewer_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart'; // Import Provider for animations
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message.dart';
import '../models/profile.dart';
import '../utils/constants.dart';
import './about_page.dart';
import '../providers/theme_provider.dart'; // Import ThemeProvider for animations

// Import your other pages to navigate to them
import './splash_page.dart';
import './profile_page.dart';
import './settings_page.dart';

Future<void> logout() async {
  FlutterBackgroundService().invoke('stop');
  await Supabase.instance.client.auth.signOut();
}

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
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

  // final ReceivePort _port = ReceivePort();
  // A central map to track the state of all downloads
  final Map<String, DownloadTask> _downloadTasks = {};
  final ReceivePort _port = ReceivePort();

  @override
  void initState() {
    super.initState();
    final myUserId = supabase.auth.currentUser!.id;
    _messagesStream = supabase.from('messages').stream(primaryKey: ['id']).order('created_at').map((maps) =>
        maps.map((map) => Message.fromMap(map: map, myUserId: myUserId)).toList()).asBroadcastStream();

    // --- Add a debug print to see if this command is being sent ---
    print('--- [ChatPage] Sending user ID to background service: $myUserId ---');
    FlutterBackgroundService().invoke('set_user', {'userId': myUserId});
    
    _setupDownloaderListener();
    _loadInitialTasks();
  }

  // Load existing tasks when the chat page opens
  Future<void> _loadInitialTasks() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null) {
      for (var task in tasks) {
        _downloadTasks[task.url] = task;
      }
      setState(() {});
    }
  }

  void _setupDownloaderListener() {
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');

    _port.listen((dynamic data) {
      final String taskId = data[0];
      final int statusValue = data[1];
      final int progress = data[2];

      // Find which task in our map corresponds to this update
      final taskEntry = _downloadTasks.entries.firstWhere((entry) => entry.value.taskId == taskId, orElse: () => MapEntry('', DownloadTask(taskId: '', status: DownloadTaskStatus.undefined, progress: 0, url: '', filename: '', savedDir: '', timeCreated: 0, allowCellular: true)));

      if(mounted && taskEntry.key.isNotEmpty) {
        final oldTask = taskEntry.value;
        // --- THIS IS THE FIX ---
        // Create a NEW DownloadTask object with the updated values
        final newTask = DownloadTask(
            taskId: oldTask.taskId,
            status: DownloadTaskStatus.fromInt(statusValue),
            progress: progress,
            url: oldTask.url,
            filename: oldTask.filename,
            savedDir: oldTask.savedDir,
            timeCreated: oldTask.timeCreated,
            allowCellular: true
        );
        // Replace the old task with the new one in our state map
        setState(() {
          _downloadTasks[taskEntry.key] = newTask;
        });
      }
    });
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  Future<void> _handleDownloadRequest(Message message) async {
    final fileName = message.metadata?['fileName'] as String?;
    if (fileName == null) return;

    final savedDir = (await getDownloadsDirectory())!;
    final localFilePath = '${savedDir.path}/$fileName';
    if (await File(localFilePath).exists()) {
      await File(localFilePath).delete();
    }

    final taskId = await FlutterDownloader.enqueue(
      url: message.content,
      savedDir: savedDir.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
      allowCellular: true,
    );

    // Update our central state map with the newly created task
    if (taskId != null) {
      final newTask = DownloadTask(
          taskId: taskId,
          status: DownloadTaskStatus.enqueued,
          progress: 0,
          url: message.content,
          filename: fileName,
          savedDir: savedDir.path,
          timeCreated: DateTime.now().millisecondsSinceEpoch,
          allowCellular: true
      );
      setState(() {
        _downloadTasks[message.content] = newTask;
      });
    }
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final messages = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('Start your conversation now :)'))
                    : ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    _loadProfileCache(message.profileId);

                    return _ChatBubble(
                      key: ValueKey(message.id),
                      message: message,
                      profile: _profileCache[message.profileId],
                      downloadTask: _downloadTasks[message.content],
                      onDownloadRequest: () => _handleDownloadRequest(message),
                      onEdit: _handleEditMessage,
                      onDelete: _handleDeleteMessage,
                      onReply: _handleReplyMessage,
                      onCopy: _handleCopyMessage,
                    );
                  },
                ),
              ),
              const _MessageBar(),
            ],
          );
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
            ListTile(
                leading: const Icon(Icons.info_outlined),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(AboutPage.route());
                }
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
  void _handleEditMessage(Message message) {
    final textController = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextFormField(
            controller: textController,
            autofocus: true,
            maxLines: null,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newContent = textController.text.trim();
                if (newContent.isNotEmpty) {
                  try {
                    await supabase
                        .from('messages')
                        .update({'content': newContent})
                        .eq('id', message.id);
                    Navigator.of(context).pop();
                  } catch (e) {
                    context.showErrorSnackBar(message: "Failed to edit message.");
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _handleDeleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Message?'),
          content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await supabase.from('messages').delete().eq('id', message.id);
                  Navigator.of(context).pop();
                } catch (e) {
                  context.showErrorSnackBar(message: "Failed to delete message.");
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Placeholder for the reply functionality
  void _handleReplyMessage(Message message) {
    context.showSnackBar(message: "Replying to: ${message.content}");
    // You can implement your reply logic here, e.g., by updating a state variable
  }
  void _handleCopyMessage(Message message) {
    // Use the Clipboard API to set the data
    Clipboard.setData(ClipboardData(text: message.content));

    // Show a snackbar to give user feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        duration: Duration(seconds: 2),
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

class _MessageBarState extends State<_MessageBar> with TickerProviderStateMixin {
  late final TextEditingController _textController;
  late final AnimationController _animationController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // A slightly longer duration for the throw
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleFileUpload() async {
    setState(() => _isUploading = true);

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      final file = result.files.first;
      final userId = supabase.auth.currentUser!.id;
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final filePath = '$userId/$uniqueFileName';

      // Upload to Supabase Storage
      await supabase.storage.from('chat-files').upload(filePath, File(file.path!));

      // Get public URL
      final fileUrl = supabase.storage.from('chat-files').getPublicUrl(filePath);

      final mimeType = lookupMimeType(file.path!);
      final messageType = (mimeType?.startsWith('image/') ?? false) ? 'image' : 'file';

      // Insert a new message record for the file
      await supabase.from('messages').insert({
        'profile_id': userId,
        'message_type': messageType,
        'content': fileUrl, // Store the URL in the content field
        'metadata': {
          'fileName': file.name,
          'fileSize': file.size, // Size in bytes
        }
      });

    } catch (e) {
      context.showErrorSnackBar(message: "Failed to upload file.");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _submitMessage() async {
    final text = _textController.text;
    final myUserId = supabase.auth.currentUser!.id;
    if (text.isEmpty) return;
    final messageContent = text;
    _textController.clear();
    try {
      await supabase.from('messages').insert({
        'profile_id': myUserId,
        'content': messageContent,
      });
    } on PostgrestException catch (error) {
      _textController.text = messageContent;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      _textController.text = messageContent;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('An unexpected error occurred.')));
    }
  }

  void _handleSendPressed() {
    // Prevent starting a new animation while one is already playing
    if (_animationController.isAnimating) return;

    // Check if there is text to send
    if (_textController.text.trim().isNotEmpty) {
      // Start the animation and then submit the message
      // The animation will reverse itself after completion.
      _animationController.forward().whenComplete(() {
        _animationController.reverse();
      });
      _submitMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // --- THIS IS THE NEW FILE UPLOAD BUTTON ---
              _isUploading
                  ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                  : IconButton(
                onPressed: _handleFileUpload,
                icon: Icon(Icons.attach_file, color: theme.colorScheme.primary),
                tooltip: 'Attach File',
              ),
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
              AnimatedBuilder(
                animation: CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeInOut, // A smooth curve for the animation
                ),
                builder: (context, child) {
                  // --- This is where the magic happens ---

                  final animationValue = _animationController.value;

                  // 1. Calculate the arc (parabolic) motion for the 'y' axis
                  // This formula creates a perfect 0 -> 1 -> 0 arc
                  final arcValue = 4 * (-animationValue * animationValue + animationValue);

                  // 2. Define the transformation for the "3D throw"
                  final transform = Matrix4.identity()
                  // Move it horizontally
                    ..translate(animationValue * 75.0, 0.0)
                  // Move it vertically in an arc
                    ..translate(0.0, -arcValue * 40.0)
                  // Rotate it around the Y-axis to give a 3D feel
                    ..rotateY(animationValue * 3.14 * 2) // Two full spins
                  // Scale it down as it "flies away"
                    ..scale(1 - (arcValue * 0.5));

                  return Transform(
                    transform: transform,
                    alignment: Alignment.center,
                    child: child, // The original IconButton
                  );
                },
                child: IconButton(
                  onPressed: _handleSendPressed, // Use the new handler
                  icon: Icon(Icons.send, color: theme.colorScheme.primary),
                ),
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
  // We need to pass down callbacks for edit and delete actions
  final Message message;
  final Profile? profile;
  final DownloadTask? downloadTask;
  final VoidCallback onDownloadRequest;
  final Function(Message) onEdit;
  final Function(Message) onDelete;
  final Function(Message) onReply; // For a future reply feature
  final Function(Message) onCopy;

  const _ChatBubble({
    Key? key,
    required this.message,
    this.profile,
    this.downloadTask,
    required this.onDownloadRequest,
    required this.onEdit,
    required this.onDelete,
    required this.onReply,
    required this.onCopy,
  }) : super(key: key);

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late Animation<double> _animation;
  DownloadTask? _task;
  String? _localPath;

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

    _checkIfFileExists();
  }

  @override
  void didUpdateWidget(covariant _ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.downloadTask != oldWidget.downloadTask) {
      _checkIfFileExists();
    }
  }

  Future<void> _checkIfFileExists() async {
    if (widget.downloadTask?.status == DownloadTaskStatus.complete) {
      final path = '${widget.downloadTask!.savedDir}/${widget.downloadTask!.filename}';
      if (await File(path).exists()) {
        if (mounted) setState(() => _localPath = path);
      }
    }
  }

  Future<void> _openFile() async {
    if (_localPath == null) {
      context.showErrorSnackBar(message: 'File not found. Please download again.');
      return;
    }

    final fileName = widget.message.metadata?['fileName'] as String? ?? '';

    // Check for PDF to use our internal viewer
    if (fileName.toLowerCase().endsWith('.pdf')) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PdfViewerPage(filePath: _localPath!, fileName: fileName),
      ));
      return;
    }

    // Fallback for all other files using url_launcher
    try {
      if (!await launchUrl(Uri.parse(widget.message.content), mode: LaunchMode.externalApplication)) {
        throw 'Could not launch URL';
      }
    } catch (e) {
      if(mounted) context.showErrorSnackBar(message: "Could not open file: $e");
    }
  }

  Future<void> _findTask() async {
    if (widget.message.messageType == 'text') return; // No task for text messages
    final tasks = await FlutterDownloader.loadTasksWithRawQuery(
        query: 'SELECT * FROM task WHERE url = "${widget.message.content}"');
    if (tasks != null && tasks.isNotEmpty) {
      _task = tasks.first;
      if (_task!.status == DownloadTaskStatus.complete) {
        _localPath = '${_task!.savedDir}/${_task!.filename}';
      }
    }
  }

  Future<void> _handleDownload() async {
    final fileUrl = widget.message.content;
    try {
      if (!await launchUrl(Uri.parse(fileUrl))) {
        throw 'Could not launch $fileUrl';
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme provider but don't listen to its changes here
    // as we don't want to rebuild the entire animation for a theme change.
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // ROUTER: Decide which bubble to build based on the message type
    Widget bubbleContent;
    switch (widget.message.messageType) {
      case 'image':
        bubbleContent = _buildImageBubble();
        break;
      case 'file':
        bubbleContent = _buildFileBubble();
        break;
      case 'text':
      default:
        bubbleContent = _buildTextBubble();
        break;
    }

    // Now wrap the selected bubble content with the menu
    Widget bubbleWithMenu = ContextMenuRegion(
      contextMenu: GenericContextMenu(buttonConfigs: _buildMenuButtons()),
      child: bubbleContent,
    );

    // This switch statement chooses the correct animation wrapper for the bubble
    switch (themeProvider.animationType) {
      case BubbleAnimationType.fade:
        return FadeTransition(opacity: _animation, child: bubbleWithMenu);

      case BubbleAnimationType.scale:
        return ScaleTransition(scale: _animation, child: bubbleWithMenu);

      case BubbleAnimationType.slide:
        final slideAnimation = Tween(
          begin: widget.message.isMine ? const Offset(1, 0) : const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
        return SlideTransition(position: slideAnimation, child: bubbleWithMenu);

      case BubbleAnimationType.none:
      default:
        return bubbleWithMenu;
    }
  }

  Widget _buildImageBubble() {
    final imageUrl = widget.message.content;
    // Create a unique hero tag for the animation
    final heroTag = 'image_hero_${widget.message.id}';

    return GestureDetector(
      onTap: () {
        // Open the full-screen image viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImageViewerPage(imageUrl: imageUrl, heroTag: heroTag),
          ),
        );
      },
      child: Hero(
        tag: heroTag,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.3, // Max width of 60% of the screen
            maxHeight: 300,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceVariant,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 40),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTextBubble() {
    final theme = Theme.of(context);
    final bubbleColor = widget.message.isMine ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant;
    final textColor = widget.message.isMine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant;

    List<Widget> chatContents = [
      if (!widget.message.isMine)
        InkWell(
          onTap: () => Navigator.of(context).push(ProfilePage.route(userId: widget.message.profileId)),
          borderRadius: BorderRadius.circular(20),
          child: CircleAvatar(
            radius: 20,
            backgroundImage: widget.profile?.avatarUrl != null && widget.profile!.avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(widget.profile!.avatarUrl!) : null,
            child: (widget.profile?.avatarUrl == null || widget.profile!.avatarUrl!.isEmpty)
                ? Text(widget.profile?.username.substring(0, 2).toUpperCase() ?? '??') : null,
          ),
        ),
      const SizedBox(width: 12),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
          child: Text(widget.message.content, style: TextStyle(color: textColor)),
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

  Future<void> _requestDownload() async {
    // This is a simplified version, the full version from previous answers is also correct
    // The key is that this function now EXISTS.
    final fileName = widget.message.metadata?['fileName'] as String?;
    if (fileName == null) return;
    
    final savedDir = (await getDownloadsDirectory())!;
    final localFilePath = '${savedDir.path}/$fileName';
    if (await File(localFilePath).exists()) {
      await File(localFilePath).delete();
    }
    
    await FlutterDownloader.enqueue(
      url: widget.message.content,
      savedDir: savedDir.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: false, // Set to false to avoid AndroidManifest issues
      allowCellular: true,
    );
  }

  Widget _buildFileBubble() {
    final theme = Theme.of(context);
    final fileName = widget.message.metadata?['fileName'] ?? 'file';
    final fileSize = widget.message.metadata?['fileSize'];
    String title;
    Widget actionWidget;
    String readableSize = "";

    final currentStatus = widget.downloadTask?.status;
    final progress = widget.downloadTask?.progress ?? 0;

    // --- SMART LOGIC to determine the bubble's state ---
    if (currentStatus == DownloadTaskStatus.running) {
      title = "Downloading... ${_task?.progress ?? 0}%";
      actionWidget = CircularProgressIndicator(
        value: (_task?.progress ?? 0) / 100,
        strokeWidth: 2,
        // Make the progress indicator match the theme color
        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimaryContainer),
      );
    } else if (currentStatus == DownloadTaskStatus.complete && _localPath != null) {
      title = "Open File";
      actionWidget = Icon(Icons.check_circle, color: theme.colorScheme.onPrimaryContainer);
    } else if (currentStatus == DownloadTaskStatus.failed) {
      title = "Download Failed";
      actionWidget = Icon(Icons.error_outline, color: theme.colorScheme.error);
    } else {
      title = "Download File";
      actionWidget = Icon(Icons.download_for_offline, color: theme.colorScheme.primary);
    }

    VoidCallback onTapAction;
    if (currentStatus == DownloadTaskStatus.complete) {
      onTapAction = _openFile;
    } else if (currentStatus == DownloadTaskStatus.running) {
      onTapAction = () {}; // Do nothing
    } else {
      // If failed or not downloaded, call the function passed from the parent
      onTapAction = widget.onDownloadRequest;
    }
    if (fileSize != null) {
      readableSize = fileSize < 1024 * 1024
          ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
          : '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    final bubbleColor = widget.message.isMine ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant;
    final textColor = widget.message.isMine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTapAction,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16)
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AnimatedSwitcher for the main action icon/progress
            AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: SizedBox(
                  key: ValueKey(title), // Use the title as key to trigger the animation
                  width: 24, // Give a fixed size to avoid layout jumps
                  height: 24,
                  child: Center(child: actionWidget),
                )
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      widget.message.metadata?['fileName'] ?? 'file',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 4),
                  Text(
                      title,
                      style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12)
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ContextMenuButtonConfig> _buildMenuButtons() {
    final isFile = widget.message.messageType != 'text';
    final buttons = <ContextMenuButtonConfig>[
      // Don't show reply for files
      if (!isFile)
        ContextMenuButtonConfig(
          "Reply",
          icon: const Icon(Icons.reply, size: 20),
          onPressed: () => widget.onReply(widget.message),
        ),

      // Only show copy for text messages
      if (widget.message.messageType == 'text')
        ContextMenuButtonConfig(
          "Copy",
          icon: const Icon(Icons.content_copy, size: 20),
          onPressed: () => widget.onCopy(widget.message),
        ),

      // Show download for files/images
      if (isFile)
        ContextMenuButtonConfig("Download", icon: Icon(Icons.download), onPressed: _handleDownload),

      // Edit is only for text messages sent by me
      if (widget.message.isMine && widget.message.messageType == 'text')
        ContextMenuButtonConfig(
          "Edit",
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () => widget.onEdit(widget.message),
        ),

      // Delete is for all messages sent by me
      if (widget.message.isMine)
        ContextMenuButtonConfig(
          "Delete",
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
          onPressed: () => widget.onDelete(widget.message),
        )
    ];

    return buttons;
  }
}
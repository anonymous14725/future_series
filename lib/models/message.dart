class Message {
  Message({
    required this.id,
    required this.profileId,
    required this.content,
    required this.createdAt,
    required this.isMine,
    required this.messageType, // NEW
    this.metadata, // NEW
  });

  final String id;
  final String profileId;
  final String content; // Will store text content OR file URL
  final DateTime createdAt;
  final bool isMine;

  // --- THESE ARE THE NEW, IMPORTANT FIELDS ---
  /// Type of the message, e.g., 'text', 'image', 'file'
  final String messageType;
  /// Additional data like filename, size, or image dimensions
  final Map<String, dynamic>? metadata;

  Message.fromMap({
    required Map<String, dynamic> map,
    required String myUserId,
  })  : id = map['id'],
        profileId = map['profile_id'],
        content = map['content'],
        createdAt = DateTime.parse(map['created_at']),
  // Default to 'text' if not specified for older messages
        messageType = map['message_type'] ?? 'text',
        metadata = map['metadata'],
        isMine = myUserId == map['profile_id'];
}
  import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final String heroTag; // For a smooth hero animation

  const ImageViewerPage({Key? key, required this.imageUrl, required this.heroTag}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(50, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: heroTag, // Connects the chat bubble image to this one
          child: InteractiveViewer( // Allows for pinch-to-zoom and pan
            panEnabled: true,
            minScale: 1.0,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
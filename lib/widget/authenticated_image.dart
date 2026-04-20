// Create new file: lib/widgets/authenticated_image.dart
// ignore_for_file: library_private_types_in_public_api

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthenticatedImage extends StatefulWidget {
  final String url;
  final Future<Map<String, String>> Function() getHeaders;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function()? placeholder;
  final Widget Function(String error)? errorWidget;

  const AuthenticatedImage({
    super.key,
    required this.url,
    required this.getHeaders,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  _AuthenticatedImageState createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final headers = await widget.getHeaders();

      final response = await http.get(Uri.parse(widget.url), headers: headers);


      if (response.statusCode == 200) {
        // More flexible content type checking
        final contentType =
            response.headers['content-type']?.toLowerCase() ?? '';

        // Check if it's an image or if content type is generic but likely an image
        bool isImage =
            contentType.startsWith('image/') ||
            contentType == 'application/octet-stream' ||
            contentType.isEmpty;

        if (isImage) {
          // Additional validation: check if file actually contains image data
          if (response.bodyBytes.isNotEmpty) {
            try {
              setState(() {
                _imageBytes = response.bodyBytes;
                _isLoading = false;
                _error = null;
              });
            } catch (e) {
              throw Exception('Failed to process image data: $e');
            }
          } else {
            throw Exception('Empty response body');
          }
        } else {
          throw Exception(
            'Response is not an image. Content-Type: $contentType',
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder?.call() ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[100],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 8),
                  Text(
                    'Loading image...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
    }

    if (_error != null) {
      return widget.errorWidget?.call(_error!) ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[100],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loadImage,
                    icon: Icon(Icons.refresh, size: 16),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }
}

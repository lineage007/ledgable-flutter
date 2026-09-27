import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_exception.dart';
import '../../app.dart';
import '../../state/providers.dart';
import '../../theme.dart';

/// Photograph a receipt, or choose one from the library, and upload it.
///
/// The anchor feature: receipt capture is the reason the app gets installed. The
/// screen is therefore two large buttons and nothing else, and it moves straight
/// to the review screen as soon as the server has the file — OCR runs on
/// background compute and there is no reason to hold the user here watching it.
class ReceiptCaptureScreen extends ConsumerStatefulWidget {
  const ReceiptCaptureScreen({super.key});

  @override
  ConsumerState<ReceiptCaptureScreen> createState() => _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends ConsumerState<ReceiptCaptureScreen> {
  final _picker = ImagePicker();

  bool _uploading = false;
  double? _progress;
  String? _error;

  Future<void> _capture(ImageSource source) async {
    if (_uploading) return;
    setState(() => _error = null);

    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        // Cap the long edge and recompress: a 12-megapixel original is several
        // megabytes, the API has a size limit, and OCR gains nothing from
        // resolution a till receipt does not carry. 2400px keeps small print
        // legible.
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = _describePermissionProblem(error, source));
      return;
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'Could not open the ${source == ImageSource.camera ? 'camera' : 'photo library'}: $error',
      );
      return;
    }

    if (picked == null) return; // Cancelled.
    await _upload(File(picked.path));
  }

  Future<void> _upload(File file) async {
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final accepted = await ref
          .read(receiptsRepositoryProvider)
          .upload(
            file,
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _progress = sent / total);
            },
          );
      if (!mounted) return;
      // Replace rather than push: going "back" to an empty capture screen after
      // a successful upload is not a useful place to land.
      context.pushReplacement(Routes.receiptReview(accepted.receiptId));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == ApiErrorCode.fileTooLarge
            ? 'That photo is too large for Ledgable to accept. Try taking it again '
                  'a little further back.'
            : error.displayMessage;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = null;
        });
      }
    }
  }

  /// A denied permission is not an error the user can fix by trying again, so it
  /// gets its own sentence pointing at Settings.
  String _describePermissionProblem(PlatformException error, ImageSource source) {
    final isCamera = source == ImageSource.camera;
    if (error.code == 'camera_access_denied') {
      return 'Ledgable does not have permission to use the camera. Turn it on in '
          'Settings → Ledgable → Camera, then try again.';
    }
    if (error.code == 'photo_access_denied') {
      return 'Ledgable does not have permission to see your photos. Turn it on in '
          'Settings → Ledgable → Photos, then try again.';
    }
    return 'Could not open the ${isCamera ? 'camera' : 'photo library'}. '
        '${error.message ?? 'Try again.'}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.c;

    return Scaffold(
      appBar: AppBar(title: const Text('Add a receipt')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.receipt_long_rounded, size: 56, color: colors.accent),
              ),
              const SizedBox(height: 24),
              Text(
                'Snap the whole receipt',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Get the vendor, the total and the GST line in frame. Ledgable reads '
                'them for you and you confirm what it found.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.negative.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.negative.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 18, color: colors.negative),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: colors.negative),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (_uploading) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
                Text(
                  _progress == null || _progress! < 1
                      ? 'Uploading…'
                      : 'Uploaded. Starting to read it…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () => _capture(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Take a photo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _capture(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from library'),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: colors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receipts are kept for seven years, which is what Australian '
                      'record-keeping rules require.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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

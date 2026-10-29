import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';

enum PhotoCaptureKind { id, selfie }

/// Which camera request a capture step should make.
///
/// Camera-only on purpose: the ID photo and the selfie are identity evidence,
/// so the app must never accept a gallery upload — a stored photo of a photo,
/// or of someone else, would defeat the check. The selfie uses the front
/// camera; the ID uses the rear one. On Android the camera intent requests the
/// CAMERA permission itself, since the manifest declares it (for the QR
/// scanner).
@visibleForTesting
({ImageSource source, CameraDevice device}) photoCaptureRequestFor(
  PhotoCaptureKind kind,
) => (
  source: ImageSource.camera,
  device: kind == PhotoCaptureKind.id ? CameraDevice.rear : CameraDevice.front,
);

/// ID-photo and selfie capture — same layout, different copy. Mock-only:
/// nothing here is verified or matched, it's a demo of what the real KYC
/// flow will look like. Photos aren't persisted past this session.
class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({
    super.key,
    required this.kind,
    required this.onContinue,
  });

  final PhotoCaptureKind kind;
  final VoidCallback onContinue;

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  Uint8List? _imageBytes;
  bool _picking = false;
  String? _error;

  bool get _isId => widget.kind == PhotoCaptureKind.id;
  String get _title => _isId ? Strings.idPhotoTitle : Strings.selfiePhotoTitle;
  String get _instructions => _isId
      ? Strings.idPhotoInstructions
      : 'ضع وجهك داخل الإطار، وانظر مباشرة إلى الكاميرا في إضاءة جيدة.';
  IconData get _icon => _isId ? Icons.badge_outlined : Icons.face_outlined;

  Future<void> _captureImage() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final request = photoCaptureRequestFor(widget.kind);
      final file = await ImagePicker().pickImage(
        source: request.source,
        preferredCameraDevice: request.device,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (_) {
      // Permission refused, no camera app, camera in use — all land here.
      if (mounted) setState(() => _error = Strings.captureError);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد الحساب')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isId
                        ? 'الخطوة ١ من ٣ · بطاقة الهوية'
                        : 'الخطوة ٢ من ٣ · الصورة الشخصية',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _isId ? 1 / 3 : 2 / 3,
                      minHeight: 5,
                      backgroundColor: AppColors.neutralContainer,
                      color: AppColors.bread,
                      semanticsLabel: _isId
                          ? 'الخطوة الأولى من ثلاث'
                          : 'الخطوة الثانية من ثلاث',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _title,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _instructions,
                    style: textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          image: true,
                          label: _imageBytes != null
                              ? 'معاينة الصورة الملتقطة'
                              : 'إطار التقاط الصورة',
                          child: AspectRatio(
                            aspectRatio: _isId ? 1.6 : 1.2,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warmSurface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                ),
                              ),
                              child: _imageBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        _imageBytes!,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Center(
                                      child: FractionallySizedBox(
                                        widthFactor: _isId ? 0.9 : 0.6,
                                        heightFactor: 0.85,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppColors.accent,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              _isId ? 12 : 96,
                                            ),
                                          ),
                                          child: Icon(
                                            _icon,
                                            size: 56,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _imageBytes != null
                              ? 'تأكد من وضوح الصورة قبل المتابعة.'
                              : _isId
                              ? 'أظهر البطاقة كاملة، وتجنب انعكاس الضوء.'
                              : 'أظهر وجهك كاملاً، دون تغطيته.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SecondaryButton(
                          text: _picking
                              ? 'جارٍ فتح الكاميرا…'
                              : _imageBytes != null
                              ? Strings.retakePhoto
                              : Strings.capturePrompt,
                          onPressed: _picking ? null : _captureImage,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'خطوة تجريبية: لا تُجرى مطابقة فعلية للهوية، ولا تُحفظ الصور بعد هذه الجلسة.',
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: StatusChip(text: _error!, tone: StatusTone.danger),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  PrimaryButton(
                    text: Strings.continueLabel,
                    onPressed: _imageBytes != null && !_picking
                        ? widget.onContinue
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

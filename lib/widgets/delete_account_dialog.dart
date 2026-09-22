import 'dart:convert';

import 'package:flutter/services.dart';

import '../l10n/localized_material.dart';

import '../services/chessnut_api_client.dart';
import 'app_chrome.dart';
import 'app_feedback.dart';

typedef DeleteAccountSubmitter = Future<ApiResult<bool>> Function({
  required String code,
  required String captchaId,
});

typedef DeleteAccountCaptchaLoader = Future<ApiResult<CaptchaImage>> Function();

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    required this.onDelete,
    required this.onLoadCaptcha,
    super.key,
  });

  final DeleteAccountSubmitter onDelete;
  final DeleteAccountCaptchaLoader onLoadCaptcha;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  int step = 0;
  String code = '';
  bool loading = false;
  bool captchaLoading = false;
  CaptchaImage? captcha;
  String? errorText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final captchaStep = step > 0;
    final canSubmit = captchaStep &&
        !captchaLoading &&
        captcha?.captchaId.trim().isNotEmpty == true &&
        RegExp(r'^\d{6}$').hasMatch(code.trim());
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SectionColumn(
              spacing: 12,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        color: scheme.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        captchaStep
                            ? 'Enter the verification code'
                            : 'Delete Chessnut account?',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                Text(
                  captchaStep
                      ? 'For security, type the 6-digit code shown below before this request can be submitted.'
                      : 'This removes account access and starts deletion of synced records, preferences, points, and analysis history. This action cannot be undone.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (captchaStep) ...[
                  _DeleteCaptchaPreview(
                    captcha: captcha,
                    loading: captchaLoading,
                    onReload: loading ? null : _loadCaptcha,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: TextField(
                      key: const ValueKey('delete-account-code-field'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      minLines: 1,
                      maxLines: 1,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                        hintText: '6-digit code',
                        prefixIcon: Icon(Icons.pin_outlined),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                      ),
                      onChanged: (value) => setState(() => code = value),
                    ),
                  ),
                ],
                if (errorText != null)
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: loading
                            ? null
                            : captchaStep
                                ? (canSubmit ? _submitDelete : null)
                                : _continueToCaptchaStep,
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(captchaStep
                                ? Icons.delete_forever_rounded
                                : Icons.arrow_forward_rounded),
                        label: Text(
                          loading
                              ? 'Deleting'
                              : captchaStep
                                  ? 'Delete permanently'
                                  : 'Continue',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueToCaptchaStep() async {
    setState(() => step = 1);
    await _loadCaptcha();
  }

  Future<void> _loadCaptcha() async {
    setState(() {
      captchaLoading = true;
      errorText = null;
    });
    final result = await widget.onLoadCaptcha();
    if (!mounted) return;
    setState(() {
      captchaLoading = false;
      if (result.isSuccess && result.data != null) {
        captcha = result.data;
        code = '';
      } else {
        errorText = result.status.errorMessage ??
            'Unable to load verification code. Please try again.';
      }
    });
  }

  Future<void> _submitDelete() async {
    final activeCaptcha = captcha;
    if (activeCaptcha == null) return;
    setState(() {
      loading = true;
      errorText = null;
    });
    final result = await widget.onDelete(
      code: code.trim(),
      captchaId: activeCaptcha.captchaId,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop();
      showAppFeedback(
        context,
        'Account deletion requested',
        tone: AppFeedbackTone.success,
      );
      return;
    }
    setState(() {
      loading = false;
      errorText = result.status.errorMessage ?? 'Unable to delete account.';
    });
  }
}

class _DeleteCaptchaPreview extends StatelessWidget {
  const _DeleteCaptchaPreview({
    required this.captcha,
    required this.loading,
    required this.onReload,
  });

  final CaptchaImage? captcha;
  final bool loading;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageBytes = _decodeCaptcha(captcha?.base64 ?? '');
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.58),
              ),
            ),
            child: loading
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : imageBytes == null
                    ? Icon(
                        Icons.refresh_rounded,
                        color: scheme.onSurfaceVariant,
                      )
                    : Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Reload verification code',
          onPressed: onReload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

Uint8List? _decodeCaptcha(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final comma = trimmed.indexOf(',');
  final payload = comma >= 0 ? trimmed.substring(comma + 1) : trimmed;
  try {
    return base64Decode(base64.normalize(payload));
  } catch (_) {
    return null;
  }
}

import 'package:http/http.dart' as http;

import '../l10n/localized_material.dart';

const voiceMovesMicPromptText =
    'Chessnut uses the microphone only while voice moves are on.';
const voiceMovesNetworkIssueText =
    'Voice moves use online speech recognition. Check your network connection and try again.';

typedef VoiceMovesOnlineAvailabilityCheck = Future<bool> Function();

final voiceMovesTranscriptionAvailabilityUri =
    Uri.parse('https://api.openai.com/v1');

VoiceMovesOnlineAvailabilityCheck? debugVoiceMovesOnlineAvailabilityCheck;

class VoiceMovesShortcutButton extends StatelessWidget {
  const VoiceMovesShortcutButton({
    required this.enabled,
    required this.onPressed,
    required this.valueKey,
    this.listening = false,
    this.size = 44,
    super.key,
  });

  final bool enabled;
  final bool listening;
  final VoidCallback onPressed;
  final ValueKey<String> valueKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        listening || enabled ? scheme.primary : scheme.onSurfaceVariant;
    return Tooltip(
      message: enabled ? 'Turn voice moves off' : 'Turn voice moves on',
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton.filledTonal(
          key: valueKey,
          padding: EdgeInsets.zero,
          iconSize: 22,
          onPressed: onPressed,
          icon: Icon(
            enabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: color,
          ),
        ),
      ),
    );
  }
}

Future<void> showVoiceMovesMicPrompt(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Voice moves'),
      content: const Text(voiceMovesMicPromptText),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

Future<bool> ensureVoiceMovesOnlineReady(BuildContext context) async {
  final available = await _checkVoiceMovesOnlineAvailability();
  if (available) return true;
  if (!context.mounted) return false;
  await showVoiceMovesNetworkIssuePrompt(context);
  return false;
}

Future<void> showVoiceMovesNetworkIssuePrompt(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Network issue'),
      content: const Text(voiceMovesNetworkIssueText),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

bool isVoiceMovesNetworkIssueMessage(String message) {
  final lower = message.toLowerCase();
  return lower.contains('internet') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('failed host lookup') ||
      lower.contains('socketexception') ||
      lower.contains('websocket') ||
      lower.contains('unable to reach');
}

Future<bool> _checkVoiceMovesOnlineAvailability() async {
  final debugCheck = debugVoiceMovesOnlineAvailabilityCheck;
  if (debugCheck != null) return debugCheck();
  if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
    return true;
  }
  final client = http.Client();
  try {
    final response = await client
        .head(voiceMovesTranscriptionAvailabilityUri)
        .timeout(const Duration(seconds: 4));
    return response.statusCode < 500;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}

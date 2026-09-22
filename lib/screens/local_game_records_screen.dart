import 'dart:async';

import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';
import '../models/app_models.dart';
import '../services/game_record_save_service.dart';
import '../services/local_game_record_store.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/game_record_tile.dart';

class LocalGameRecordsScreen extends StatefulWidget {
  const LocalGameRecordsScreen({
    required this.store,
    required this.saveService,
    required this.userId,
    required this.onNavigate,
    required this.onReview,
    this.onContinue,
    this.onUploaded,
    this.isChessnutClockDevice = false,
    super.key,
  });

  final LocalGameRecordStore store;
  final GameRecordSaveService saveService;
  final int? userId;
  final ValueChanged<String> onNavigate;
  final FutureOr<void> Function(GameRecord record) onReview;
  final FutureOr<void> Function(GameRecord record)? onContinue;
  final Future<void> Function()? onUploaded;
  final bool isChessnutClockDevice;

  @override
  State<LocalGameRecordsScreen> createState() => _LocalGameRecordsScreenState();
}

class _LocalGameRecordsScreenState extends State<LocalGameRecordsScreen> {
  List<LocalGameRecord> _records = [];
  final _selected = <String>{};
  final _uploading = <String>{};
  bool _loading = true;
  bool _batchUploading = false;
  bool _batchDeleting = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_reload);
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant LocalGameRecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_reload);
      widget.store.addListener(_reload);
      _records = [];
      _loading = true;
      _selected.clear();
      unawaited(_reload());
    } else if (oldWidget.userId != widget.userId) {
      // Start a fresh selection for the new upload destination account.
      _selected.clear();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final records = await widget.store.list();
      if (!mounted || generation != _generation) return;
      setState(() {
        _records = records;
        _loading = false;
        _error = null;
        _selected.retainAll(records.map((r) => r.id));
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Unable to read local games. Please try again.';
      });
    }
  }

  bool _canSelectForUpload(LocalGameRecord record) => !record.isSynced;

  Future<void> _upload(List<LocalGameRecord> records) async {
    if (_batchUploading) return;
    final userId = widget.saveService.apiClient.session?.userId;
    if (userId == null) {
      showAppFeedback(context, 'Sign in to upload local games.');
      widget.onNavigate('Auth');
      return;
    }
    final pending = records.where(_canSelectForUpload).toList();
    if (pending.isEmpty) return;
    // Keep the callback when switching to the cloud tab disposes this view
    // while its last upload is still in flight.
    final onUploaded = widget.onUploaded;
    final apiClient = widget.saveService.apiClient;
    setState(() => _batchUploading = true);
    var uploaded = 0;
    String? error;
    var refreshFailed = false;
    try {
      for (final record in pending) {
        // Leaving this screen or switching accounts cancels the remaining
        // batch. An already-sent request retains its original account.
        if (!mounted ||
            widget.saveService.apiClient.session?.userId != userId) {
          break;
        }
        setState(() => _uploading.add(record.id));
        try {
          final result = await widget.saveService.uploadLocal(record.id);
          if (result.status.isSuccess) {
            uploaded++;
          } else {
            error = result.status.errorMessage;
          }
        } catch (_) {
          error = 'Unable to upload this game. The local copy has been kept.';
        } finally {
          if (mounted) setState(() => _uploading.remove(record.id));
        }
        if (error != null) break;
      }
    } finally {
      if (uploaded > 0 && apiClient.session?.userId == userId) {
        try {
          await onUploaded?.call();
        } catch (_) {
          // A failed list refresh must not turn a saved game into an upload
          // failure or cause it to be uploaded a second time.
          refreshFailed = true;
        }
      }
      if (mounted) {
        setState(() => _batchUploading = false);
        await _reload();
      }
    }
    if (!mounted) return;
    if (error != null) {
      showAppFeedback(context, error, tone: AppFeedbackTone.warning);
    } else if (refreshFailed) {
      showAppFeedback(context,
          'Games uploaded, but cloud records could not be refreshed. Please try again.',
          tone: AppFeedbackTone.warning);
    } else if (uploaded > 0) {
      showAppFeedback(
          context, 'Selected games uploaded. Local copies have been kept.');
    }
  }

  Future<void> _delete(LocalGameRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete local game?'),
        content: const Text(
            'Only the copy on this device will be deleted. Cloud records will not change.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.store.delete(record.id);
    } catch (_) {
      if (mounted) showAppFeedback(context, 'Unable to delete local game.');
    }
  }

  Future<void> _deleteSelected(List<LocalGameRecord> records) async {
    if (_batchDeleting || records.isEmpty) return;
    final ids = records.map((record) => record.id).toSet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected records?'),
        content: const Text(
            'Only the selected copies on this device will be deleted. Cloud records will not change.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            key: const ValueKey('local-games-delete-dialog-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _batchDeleting = true);
    try {
      await widget.store.deleteMany(ids);
      if (mounted) {
        setState(() => _selected.removeAll(ids));
        await _reload();
      }
    } catch (_) {
      if (mounted) {
        showAppFeedback(context, 'Unable to delete selected local games.');
      }
    } finally {
      if (mounted) setState(() => _batchDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _records.where(_canSelectForUpload).toList();
    final selectedRecords =
        _records.where((record) => _selected.contains(record.id)).toList();
    final selectedPending = selectedRecords.where(_canSelectForUpload).toList();
    final busy = _batchUploading || _batchDeleting;
    return ResponsivePage(
        children: (context, spec) => [
              ScreenHeader(
                title: 'Local games',
                subtitle: 'Saved on this device. Upload only when you choose.',
                leading: IconButton.filledTonal(
                  onPressed: () => widget.onNavigate('Back'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              SizedBox(height: spec.gutter),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_error != null) ...[
                Text(_error!),
                TextButton(onPressed: _reload, child: const Text('Try again')),
              ],
              if (!_loading && _error == null && _records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                      'No local games. Games are saved here when you are signed out or a cloud save fails.'),
                ),
              if (_records.isNotEmpty) ...[
                Wrap(spacing: 12, runSpacing: 8, children: [
                  OutlinedButton(
                    key: const ValueKey('local-games-select-all'),
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              if (_selected.length == _records.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(_records.map((r) => r.id));
                              }
                            }),
                    child: Text(_selected.length == _records.length
                        ? 'Clear all'
                        : 'Select all'),
                  ),
                  if (pending.isNotEmpty)
                    FilledButton.icon(
                      key: const ValueKey('local-games-upload-selected'),
                      onPressed: busy || selectedPending.isEmpty
                          ? null
                          : () => _upload(selectedPending),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Upload selected'),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('local-games-delete-selected'),
                    onPressed: busy || selectedRecords.isEmpty
                        ? null
                        : () => _deleteSelected(selectedRecords),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    icon: _batchDeleting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete selected records'),
                  ),
                ]),
                SizedBox(height: spec.gutter),
              ],
              for (final local in _records) _recordCard(context, local),
            ]);
  }

  Widget _recordCard(BuildContext context, LocalGameRecord local) {
    final record = local.record;
    final uploading = _uploading.contains(local.id);
    final canUpload = _canSelectForUpload(local);
    final scheme = Theme.of(context).colorScheme;
    String t(String value) => AppStrings.maybeOf(context)?.t(value) ?? value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GameRecordTile(
        key: ValueKey('local-game-${local.id}'),
        record: record,
        recordKey: 'local-${local.id}',
        isChessnutClockDevice: widget.isChessnutClockDevice,
        onTap: () => widget.onReview(record),
        selectionMode: _selected.isNotEmpty,
        selected: _selected.contains(local.id),
        selectable: !(_batchUploading || _batchDeleting),
        onSelect: () => setState(() {
          if (!_selected.add(local.id)) _selected.remove(local.id);
        }),
        onContinue: !_batchUploading &&
                !_batchDeleting &&
                (record.canContinueBotGame || record.canContinueOtbGame) &&
                widget.onContinue != null
            ? () => widget.onContinue!(record)
            : null,
        onCopyPgn: () async {
          await Clipboard.setData(ClipboardData(text: record.pgn));
          if (context.mounted) showAppFeedback(context, 'PGN copied.');
        },
        onDelete:
            _batchUploading || _batchDeleting ? null : () => _delete(local),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    uploading
                        ? Icons.cloud_upload_outlined
                        : local.isSynced
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                    size: 16,
                    color: local.isSynced
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    uploading
                        ? 'Uploading'
                        : local.isSynced
                            ? 'Synced'
                            : 'Not synced',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ]),
                if (record.isInProgress)
                  Text('In progress',
                      style: Theme.of(context).textTheme.labelMedium),
                if (local.changedSinceUpload)
                  Text('Changed after upload',
                      style: Theme.of(context).textTheme.labelMedium),
                if (!local.isSynced)
                  TextButton.icon(
                    key: ValueKey('local-game-upload-${local.id}'),
                    onPressed: _batchUploading || _batchDeleting || !canUpload
                        ? null
                        : () => _upload([local]),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Sync to cloud'),
                  ),
              ],
            ),
            if (local.isSynced) ...[
              const SizedBox(height: 4),
              Text(
                t('Uploaded to account {account} on {date}')
                    .replaceAll('{account}', '${local.syncedUserId}')
                    .replaceAll('{date}',
                        local.syncedAt!.toLocal().toString().split('.').first),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/app_models.dart';
import 'app_preferences_store.dart';

class Lc0WeightLibraryEntry {
  const Lc0WeightLibraryEntry({
    required this.key,
    required this.label,
    required this.path,
    required this.source,
    this.modelId = 0,
    this.enabled = true,
  });

  factory Lc0WeightLibraryEntry.fromJson(Object? json) {
    if (json is! Map) return Lc0WeightLibraryEntry.defaultWeight;
    return Lc0WeightLibraryEntry(
      key: json['key']?.toString() ?? defaultLc0WeightKey,
      label: json['label']?.toString() ?? defaultLc0WeightLabel,
      path: json['path']?.toString() ?? defaultLc0WeightPath,
      source: json['source']?.toString() ?? 'Downloaded',
      modelId: int.tryParse(json['model_id']?.toString() ?? '') ?? 0,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }

  static const defaultWeight = Lc0WeightLibraryEntry(
    key: defaultLc0WeightKey,
    label: defaultLc0WeightLabel,
    path: defaultLc0WeightPath,
    source: 'Built-in',
  );

  final String key;
  final String label;
  final String path;
  final String source;
  final int modelId;
  final bool enabled;

  bool get isDefault => key == defaultLc0WeightKey;

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'path': path,
      'source': source,
      'model_id': modelId,
      'enabled': enabled,
    };
  }

  Lc0WeightLibraryEntry copyWith({
    String? key,
    String? label,
    String? path,
    String? source,
    int? modelId,
    bool? enabled,
  }) {
    return Lc0WeightLibraryEntry(
      key: key ?? this.key,
      label: label ?? this.label,
      path: path ?? this.path,
      source: source ?? this.source,
      modelId: modelId ?? this.modelId,
      enabled: enabled ?? this.enabled,
    );
  }
}

abstract class Lc0WeightLibraryStore {
  Future<List<Lc0WeightLibraryEntry>> list();

  Future<List<Lc0WeightLibraryEntry>> listAll();

  Future<bool> containsKey(String key);

  Future<void> setEnabled(String key, bool enabled);

  Future<void> rename(String key, String label);

  Future<void> remove(String key);

  Future<Lc0WeightLibraryEntry> download({
    required int modelId,
    required String title,
    required String modelUrl,
    String source = 'Chessnut curated LC0',
  });
}

class AppPreferencesLc0WeightLibraryStore implements Lc0WeightLibraryStore {
  AppPreferencesLc0WeightLibraryStore({
    required this.preferencesStore,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  final AppPreferencesStore preferencesStore;
  final http.Client httpClient;

  @override
  Future<List<Lc0WeightLibraryEntry>> list() async {
    return (await listAll()).where((entry) => entry.enabled).toList();
  }

  @override
  Future<List<Lc0WeightLibraryEntry>> listAll() async {
    final entries = (await preferencesStore.read()).lc0Weights;
    return [
      Lc0WeightLibraryEntry.defaultWeight,
      ...entries.where((entry) => !entry.isDefault),
    ];
  }

  @override
  Future<bool> containsKey(String key) async {
    return (await listAll()).any((entry) => entry.key == key);
  }

  @override
  Future<void> setEnabled(String key, bool enabled) async {
    if (key == defaultLc0WeightKey) return;
    final preferences = await preferencesStore.read();
    final next = preferences.lc0Weights.map((entry) {
      return entry.key == key ? entry.copyWith(enabled: enabled) : entry;
    }).toList();
    await preferencesStore.write(preferences.copyWith(lc0Weights: next));
  }

  @override
  Future<void> rename(String key, String label) async {
    if (key == defaultLc0WeightKey) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final preferences = await preferencesStore.read();
    final next = preferences.lc0Weights.map((entry) {
      return entry.key == key ? entry.copyWith(label: trimmed) : entry;
    }).toList();
    await preferencesStore.write(preferences.copyWith(lc0Weights: next));
  }

  @override
  Future<void> remove(String key) async {
    if (key == defaultLc0WeightKey) return;
    final preferences = await preferencesStore.read();
    final next = preferences.lc0Weights
        .where((entry) => entry.key != key)
        .toList(growable: false);
    await preferencesStore.write(preferences.copyWith(lc0Weights: next));
  }

  @override
  Future<Lc0WeightLibraryEntry> download({
    required int modelId,
    required String title,
    required String modelUrl,
    String source = 'Chessnut curated LC0',
  }) async {
    final key = lc0WeightKeyForTrainModel(modelId);
    final existing = _firstEntryOrNull(
      (await listAll()).where((entry) => entry.key == key),
    );
    if (existing != null) return existing;

    final uri = Uri.parse(modelUrl);
    final response = await httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Unable to download LC0 engine weight.');
    }

    final dir = await _weightDirectory();
    await dir.create(recursive: true);
    final fileName = _safeWeightFileName(modelId, title, uri.pathSegments);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(response.bodyBytes, flush: true);

    final entry = Lc0WeightLibraryEntry(
      key: key,
      label: title.trim().isEmpty ? 'LC0 weight $modelId' : title.trim(),
      path: file.path,
      source: source,
      modelId: modelId,
    );
    final preferences = await preferencesStore.read();
    final next = [
      ...preferences.lc0Weights.where((item) => item.key != entry.key),
      entry,
    ];
    await preferencesStore.write(preferences.copyWith(lc0Weights: next));
    return entry;
  }

  Future<Directory> _weightDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(
      '${supportDir.path}${Platform.pathSeparator}lc0_weights',
    );
  }
}

class MemoryLc0WeightLibraryStore implements Lc0WeightLibraryStore {
  MemoryLc0WeightLibraryStore([List<Lc0WeightLibraryEntry>? entries])
      : entries = [
          Lc0WeightLibraryEntry.defaultWeight,
          ...?entries?.where((entry) => !entry.isDefault),
        ];

  final List<Lc0WeightLibraryEntry> entries;

  @override
  Future<List<Lc0WeightLibraryEntry>> list() async =>
      List.unmodifiable(entries.where((entry) => entry.enabled));

  @override
  Future<List<Lc0WeightLibraryEntry>> listAll() async =>
      List.unmodifiable(entries);

  @override
  Future<bool> containsKey(String key) async {
    return entries.any((entry) => entry.key == key);
  }

  @override
  Future<void> setEnabled(String key, bool enabled) async {
    if (key == defaultLc0WeightKey) return;
    final index = entries.indexWhere((entry) => entry.key == key);
    if (index == -1) return;
    entries[index] = entries[index].copyWith(enabled: enabled);
  }

  @override
  Future<void> rename(String key, String label) async {
    if (key == defaultLc0WeightKey) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final index = entries.indexWhere((entry) => entry.key == key);
    if (index == -1) return;
    entries[index] = entries[index].copyWith(label: trimmed);
  }

  @override
  Future<void> remove(String key) async {
    if (key == defaultLc0WeightKey) return;
    entries.removeWhere((entry) => entry.key == key);
  }

  @override
  Future<Lc0WeightLibraryEntry> download({
    required int modelId,
    required String title,
    required String modelUrl,
    String source = 'Chessnut curated LC0',
  }) async {
    final key = lc0WeightKeyForTrainModel(modelId);
    final existing =
        _firstEntryOrNull(entries.where((entry) => entry.key == key));
    if (existing != null) return existing;
    final entry = Lc0WeightLibraryEntry(
      key: key,
      label: title.trim().isEmpty ? 'LC0 weight $modelId' : title.trim(),
      path: modelUrl,
      source: source,
      modelId: modelId,
    );
    entries.add(entry);
    return entry;
  }
}

String lc0WeightKeyForTrainModel(int modelId) => 'train:$modelId';

Lc0WeightLibraryEntry? _firstEntryOrNull(
  Iterable<Lc0WeightLibraryEntry> entries,
) {
  final iterator = entries.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

String _safeWeightFileName(
  int modelId,
  String title,
  List<String> pathSegments,
) {
  final remoteName = pathSegments.isEmpty ? '' : pathSegments.last;
  final extension = remoteName.endsWith('.pb.gz')
      ? '.pb.gz'
      : remoteName.endsWith('.gz')
          ? '.gz'
          : '.pb.gz';
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${modelId}_${slug.isEmpty ? 'lc0' : slug}$extension';
}

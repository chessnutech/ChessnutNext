import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/lc0_weight_library_service.dart';

void main() {
  test('list only returns enabled weights while downloaded lookup sees all',
      () async {
    final disabledMarket = Lc0WeightLibraryEntry(
      key: lc0WeightKeyForTrainModel(601),
      label: 'Disabled market engine',
      path: 'https://cdn.chessnutech.com/lc0/601.pb.gz',
      source: 'Chessnut curated LC0',
      modelId: 601,
      enabled: false,
    );
    final enabledPersonal = Lc0WeightLibraryEntry(
      key: lc0WeightKeyForTrainModel(602),
      label: 'Enabled personal engine',
      path: 'https://cdn.chessnutech.com/lc0/602.pb.gz',
      source: 'Personal engine',
      modelId: 602,
      enabled: true,
    );
    final store = MemoryLc0WeightLibraryStore([
      disabledMarket,
      enabledPersonal,
    ]);

    expect(
      (await store.listAll()).map((entry) => entry.key),
      containsAll([
        defaultLc0WeightKey,
        disabledMarket.key,
        enabledPersonal.key,
      ]),
    );
    expect(
      (await store.list()).map((entry) => entry.key),
      containsAll([defaultLc0WeightKey, enabledPersonal.key]),
    );
    expect(
      (await store.list()).map((entry) => entry.key),
      isNot(contains(disabledMarket.key)),
    );
    expect(await store.containsKey(disabledMarket.key), isTrue);

    await store.setEnabled(disabledMarket.key, true);

    expect(
      (await store.list()).map((entry) => entry.key),
      contains(disabledMarket.key),
    );

    await store.setEnabled(enabledPersonal.key, false);

    expect(await store.containsKey(enabledPersonal.key), isTrue);
    expect(
      (await store.list()).map((entry) => entry.key),
      isNot(contains(enabledPersonal.key)),
    );
  });

  test('download can label a personal engine source', () async {
    final store = MemoryLc0WeightLibraryStore();

    final entry = await store.download(
      modelId: 710,
      title: 'Kyle training engine',
      modelUrl: 'https://cdn.chessnutech.com/lc0/kyle.pb.gz',
      source: 'Personal engine',
    );

    expect(entry.source, 'Personal engine');
    expect((await store.listAll()).last.source, 'Personal engine');
  });

  test('rename updates downloaded weight labels', () async {
    final downloaded = Lc0WeightLibraryEntry(
      key: lc0WeightKeyForTrainModel(715),
      label: 'aaa',
      path: 'https://cdn.chessnutech.com/lc0/715.pb.gz',
      source: 'Personal engine',
      modelId: 715,
    );
    final store = MemoryLc0WeightLibraryStore([downloaded]);

    await store.rename(downloaded.key, 'Renamed aaa');

    final renamed = (await store.listAll()).singleWhere(
      (entry) => entry.key == downloaded.key,
    );
    expect(renamed.label, 'Renamed aaa');

    await store.rename(downloaded.key, '   ');
    expect(
      (await store.listAll())
          .singleWhere((entry) => entry.key == downloaded.key)
          .label,
      'Renamed aaa',
    );
  });

  test('remove deletes downloaded weights but keeps the built-in default',
      () async {
    final downloaded = Lc0WeightLibraryEntry(
      key: lc0WeightKeyForTrainModel(720),
      label: 'Downloaded personal engine',
      path: 'https://cdn.chessnutech.com/lc0/720.pb.gz',
      source: 'Personal engine',
      modelId: 720,
    );
    final store = MemoryLc0WeightLibraryStore([downloaded]);

    await store.remove(downloaded.key);

    expect(await store.containsKey(downloaded.key), isFalse);

    await store.remove(defaultLc0WeightKey);

    expect(await store.containsKey(defaultLc0WeightKey), isTrue);
  });
}

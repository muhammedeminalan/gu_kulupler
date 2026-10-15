// T-21 · postImageResolverProvider: gönderi görseli Storage yolu → çizilecek
// görsel (indirme adresi + önbellek). Adres bilinmezken yer tutucu (`null`),
// adres gelince sağlayıcı yeni çözücü yayar; adres alınamazsa yer tutucu kalır.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/media/bounded_image.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_storage_service.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/test_container.dart';

const String _path = 'posts/p01/20261013T090000Z_0001020304050607.jpg';
const PostImageModel _image = PostImageModel(path: _path, w: 1200, h: 900);
const PostImageModel _missing = PostImageModel(
  path: 'posts/p01/20261013T090000Z_08090a0b0c0d0e0f.jpg',
  w: 1200,
  h: 900,
);

/// Ağ ve disk önbelleği olmadan: adresi ve yolu taşıyan bellek görseli.
final class _TestImage extends MemoryImage {
  _TestImage(this.url, this.path, {this.coverEdgePx}) : super(Uint8List(1));

  final String url;
  final String path;

  /// Gösterim boyutu ipucu (`BoundedImage.coverEdgePx`).
  final int? coverEdgePx;
}

void main() {
  late FakeStorageService storage;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    storage = GetIt.I<StorageService>() as FakeStorageService;
    addTearDown(GetIt.I.reset);
  });

  Future<void> seedFile(String path) => storage.upload(
    path: path,
    bytes: Uint8List(3),
    contentType: 'image/jpeg',
  );

  /// Sağlayıcıyı dinleyen kap: yayılan her çözücü [emitted] listesine girer.
  (ProviderContainer, List<PostImageResolver>) listen() {
    final container = createContainer(
      overrides: [
        storageImageFactoryProvider.overrideWithValue(_TestImage.new),
      ],
    );
    final emitted = <PostImageResolver>[];
    container.listen(
      postImageResolverProvider,
      (_, next) => emitted.add(next),
      fireImmediately: true,
    );
    return (container, emitted);
  }

  test('adres bilinmezken yer tutucu (null); adres gelince yeni çözücü '
      'yayılır ve görseli verir', () async {
    await seedFile(_path);
    final (container, emitted) = listen();

    expect(emitted.single(_image), isNull);
    await pumpEventQueue();

    expect(emitted, hasLength(2));
    final provider = emitted.last(_image)! as _TestImage;
    expect(provider.url, '${FakeStorageService.downloadBase}$_path');
    // Disk önbelleği anahtarı yoldur (dosya değişmez — D-10).
    expect(provider.path, _path);
    expect(container.read(postImageResolverProvider), same(emitted.last));
  });

  test('bilinen adres yeniden istenmez (her çizimde tek okuma)', () async {
    await seedFile(_path);
    final (container, emitted) = listen();
    emitted.single(_image);
    await pumpEventQueue();

    final resolver = container.read(postImageResolverProvider);
    resolver(_image);
    resolver(_image);
    await pumpEventQueue();

    expect(storage.callsTo('downloadUrl'), hasLength(1));
    expect(emitted, hasLength(2));
  });

  test('adres alınamazsa (dosya yok / yetki) yer tutucu kalır; yeni çözücü '
      'yayılmaz ve istek yinelenmez', () async {
    final (container, emitted) = listen();

    expect(emitted.single(_missing), isNull);
    await pumpEventQueue();
    expect(container.read(postImageResolverProvider)(_missing), isNull);
    await pumpEventQueue();

    expect(emitted, hasLength(1));
    expect(storage.callsTo('downloadUrl'), hasLength(1));
  });

  test('varsayılan görsel üreticisi ağ görselidir ve yolu önbellek anahtarı '
      'yapar', () {
    final container = createContainer();

    final provider = container.read(storageImageFactoryProvider)(
      'https://storage.test/a?token=1',
      _path,
    );

    // Dosya güvenilmeyen içeriktir: varsayılan üretici çözümü sınırlar.
    expect(
      provider,
      isA<BoundedImage>()
          .having(
            (image) => image.maxSourcePixels,
            'maxSourcePixels',
            MediaConstants.imageSourceMaxPixels,
          )
          .having(
            (image) => image.maxEdge,
            'maxEdge',
            MediaConstants.imageDecodeMaxEdgePx,
          ),
    );
    expect(
      provider,
      container.read(storageImageFactoryProvider)(
        'https://storage.test/a?token=2',
        _path,
      ),
    );
  });
  test('T-44 · storageImageProvider: A yolunun adresi gelince yalnızca A '
      'dinleyicisi uyarılır; B yeniden kurulmaz', () async {
    const pathB = 'posts/p02/20261013T090000Z_1111111111111111.jpg';
    await seedFile(_path);
    await seedFile(pathB);
    final container = createContainer(
      overrides: [
        storageImageFactoryProvider.overrideWithValue(_TestImage.new),
      ],
    );
    final a = <ImageProvider?>[];
    final b = <ImageProvider?>[];
    container
      ..listen(storageImageProvider(_path), (_, next) => a.add(next))
      ..listen(storageImageProvider(pathB), (_, next) => b.add(next));
    expect(container.read(storageImageProvider(_path)), isNull);
    expect(container.read(storageImageProvider(pathB)), isNull);

    // B'nin adresini önbelleğe önceden koy: A gelince B'nin değeri aynı.
    await pumpEventQueue();
    expect(a.single, isA<_TestImage>().having((i) => i.path, 'path', _path));
    expect(b.single, isA<_TestImage>().having((i) => i.path, 'path', pathB));

    // Üçüncü yolun adresi gelir: A ve B dinleyicileri uyarılmaz.
    const pathC = 'posts/p03/20261013T090000Z_2222222222222222.jpg';
    await seedFile(pathC);
    container.listen(storageImageProvider(pathC), (_, _) {});
    await pumpEventQueue();
    expect(container.read(storageImageProvider(pathC)), isNotNull);
    expect(a, hasLength(1));
    expect(b, hasLength(1));
    // Her yol yalnızca bir kez istendi.
    expect(storage.callsTo('downloadUrl'), hasLength(3));
  });

  test(
    'T-44 · storageImageProvider: gösterim boyutu üreticiye geçer',
    () async {
      await seedFile(_path);
      final container = createContainer(
        overrides: [
          storageImageFactoryProvider.overrideWithValue(_TestImage.new),
        ],
      );
      final provider = storageImageProvider(_path, coverEdgePx: 120);
      container.listen(provider, (_, _) {});
      await pumpEventQueue();
      expect(
        container.read(provider),
        isA<_TestImage>().having((i) => i.coverEdgePx, 'coverEdgePx', 120),
      );
      // Varsayılan üretici küçük kutuyu BoundedImage'a taşır.
      expect(
        createContainer().read(storageImageFactoryProvider)(
          'https://storage.test/a?token=1',
          _path,
          coverEdgePx: 120,
        ),
        isA<BoundedImage>().having((i) => i.coverEdgePx, 'coverEdgePx', 120),
      );
    },
  );

  test('T-44 · D2-05: cihazda saklanan adresle çözücü ilk çağrıda görsel '
      'döner (yer tutucu yok, okuma yok)', () async {
    final prefs = GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;
    await prefs.setImageUrls({
      _path: (
        url: 'https://storage.test/a?token=0',
        at: GetIt.I<AppClock>().nowUtc(),
      ),
    });
    final container = createContainer(
      overrides: [
        storageImageFactoryProvider.overrideWithValue(_TestImage.new),
      ],
    );

    final image =
        container.read(storageImageResolverProvider)(_path)! as _TestImage;

    expect(image.url, 'https://storage.test/a?token=0');
    await pumpEventQueue();
    expect(storage.callsTo('downloadUrl'), isEmpty);
  });

  test('T-44 · A4-04: bağlantı geri gelince yer tutucudaki yol yeniden '
      'istenir ve görsel gelir', () async {
    final connectivity =
        GetIt.I<ConnectivityService>() as FakeConnectivityService..emit(true);
    final container = createContainer(
      overrides: [
        storageImageFactoryProvider.overrideWithValue(_TestImage.new),
      ],
    )..listen(storageImageProvider(_path), (_, _) {});
    await pumpEventQueue();
    expect(container.read(storageImageProvider(_path)), isNull);
    expect(storage.callsTo('downloadUrl'), hasLength(1));

    // Dosya artık erişilebilir; bekleme süresi dolmadan bağlantı döner.
    await seedFile(_path);
    connectivity.emit(false);
    await pumpEventQueue();

    expect(storage.callsTo('downloadUrl'), hasLength(2));
    expect(container.read(storageImageProvider(_path)), isA<_TestImage>());
  });
}

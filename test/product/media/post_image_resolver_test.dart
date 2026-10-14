// T-21 · postImageResolverProvider: gönderi görseli Storage yolu → çizilecek
// görsel (indirme adresi + önbellek). Adres bilinmezken yer tutucu (`null`),
// adres gelince sağlayıcı yeni çözücü yayar; adres alınamazsa yer tutucu kalır.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/media/bounded_image.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';

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
  _TestImage(this.url, this.path) : super(Uint8List(1));

  final String url;
  final String path;
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
}

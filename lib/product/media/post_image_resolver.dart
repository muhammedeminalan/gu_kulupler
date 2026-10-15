import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/media/bounded_image.dart';
import 'package:gu_kulupler/product/media/image_url_cache.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_image_resolver.g.dart';

/// İndirme adresinden çizilecek görseli kuran çağrı. `path` görselin Storage
/// yoludur: dosyalar değişmediği için (D-10) disk önbelleğinin kalıcı
/// anahtarıdır — adresteki erişim jetonu yenilense de görsel yeniden inmez.
/// `coverEdgePx` görselin `BoxFit.cover` ile çizildiği kutunun kenarıdır
/// (piksel; [BoundedImage.coverEdgePx]); `null` → sınırlı tam boy.
typedef StorageImageFactory =
    ImageProvider Function(String url, String path, {int? coverEdgePx});

/// Storage indirme adresleri önbelleği (PLAN §10.2: 1 saat). Adresi
/// `StorageService.downloadUrl` verir: servis `ProjectDependencyMixin`'de
/// bilerek yoktur (yükleme repository işidir); salt okunur adres çözümü bu
/// köprüden geçer (`feedbackServiceProvider` kalıbı — view'da servis bulucu
/// çağrılmaz, HC13). Testte `registerDefaultFakes` `FakeStorageService`
/// kaydeder: yüklenmemiş yol `notFound` döner (yer tutucu).
///
/// Adresler cihazda saklanır (`AppPreferencesStore.imageUrls` — T-44 ·
/// D2-05): soğuk açılışta görsel yer tutucuya düşmeden, çevrimdışında disk
/// önbelleğinden çizilir. Bağlantı geri gelince (gerçek ya da simüle) yer
/// tutucuda kalan görseller yeniden istenir (A4-04).
@Riverpod(keepAlive: true)
ImageUrlCache imageUrlCache(Ref ref) {
  final prefs = GetIt.I.isRegistered<AppPreferencesStore>()
      ? GetIt.I<AppPreferencesStore>()
      : null;
  final cache = ImageUrlCache(
    fetch: (path) => GetIt.I<StorageService>().downloadUrl(path),
    clock: ref.watch(appClockProvider),
    initial: prefs?.imageUrls ?? const {},
    onStored: prefs == null
        ? null
        : (entries) => unawaited(prefs.setImageUrls(entries)),
  );
  ref
    ..listen(connectivityViewModelProvider.select((s) => s.isOffline), (
      wasOffline,
      isOffline,
    ) {
      if (wasOffline == true && !isOffline) cache.retryFailed();
    })
    ..onDispose(cache.dispose);
  return cache;
}

/// İndirme adresi → görsel: `cached_network_image` (bellek + disk önbelleği),
/// [BoundedImage] ile sarılı — dosya güvenilmeyen içeriktir (Storage Rules
/// piksel boyutunu göremez): piksel sayısı sınırı aşan görsel çözülmeden
/// reddedilir (hücre yer tutucuda kalır), kalanı sınırlı boyutta çözülür.
/// Widget testinde ağ ve disk önbelleği olmadığından, görselin çizildiği
/// test bu sağlayıcıyı bellekteki bir görselle değiştirir:
/// `storageImageFactoryProvider.overrideWithValue((url, path, {coverEdgePx})
/// => …)`.
@Riverpod(keepAlive: true)
StorageImageFactory storageImageFactory(Ref ref) => _cachedNetworkImage;

ImageProvider _cachedNetworkImage(
  String url,
  String path, {
  int? coverEdgePx,
}) => BoundedImage(
  CachedNetworkImageProvider(url, cacheKey: path),
  coverEdgePx: coverEdgePx,
);

/// Storage yolu → çizilecek görsel (`null` yol ya da adresi henüz bilinmeyen
/// görsel → `null`, çağıran yer tutucu / şablon kapak çizer). `coverEdgePx`
/// [StorageImageFactory] ile aynıdır.
typedef StorageImageResolver =
    ImageProvider? Function(String? path, {int? coverEdgePx});

/// Tek Storage yolunun görseli (T-44 · P1-03): adres bilinmezken `null`
/// (çağıran yer tutucu / şablon kapak / baş harfler çizer), adres gelince
/// görsel. **Yalnızca kendi yolunun** adresi değişince yeniden kurulur —
/// başka bir yolun adresi gelince izleyen widget yeniden çizilmez (genel
/// [storageImageResolver] her yeni adreste bütün izleyenleri yeniden
/// kurar). [coverEdgePx] [StorageImageFactory] ile aynıdır.
///
/// Widget'lar doğrudan değil `ref.storageImage(path)` ile izler
/// ([StorageImageRefX]; süresi dolan adres her çizimde arka planda
/// yenilenir).
@riverpod
ImageProvider? storageImage(Ref ref, String path, {int? coverEdgePx}) {
  final cache = ref.watch(imageUrlCacheProvider);
  final imageOf = ref.watch(storageImageFactoryProvider);
  final url = cache.peek(path);
  void onChanged() {
    if (cache.peek(path) != url) ref.invalidateSelf();
  }

  cache.addListener(onChanged);
  ref.onDispose(() => cache.removeListener(onChanged));
  unawaited(cache.request(path));
  return url == null ? null : imageOf(url, path, coverEdgePx: coverEdgePx);
}

/// [dp] boyutlu kutunun cihaz pikseli (yukarı yuvarlanır); `null` → `null`.
/// Küçük görseller ([BoundedImage.coverEdgePx]) gösterim boyutunda çözülür.
int? decodePx(BuildContext context, double? dp) =>
    dp == null ? null : (dp * MediaQuery.devicePixelRatioOf(context)).ceil();

/// `build` içinde tek yolun görseli: `ref.storageImage(event.coverPath)`.
extension StorageImageRefX on WidgetRef {
  /// [path] Storage yolunun görseli ([storageImageProvider] izlenir; yalnızca
  /// bu yolun adresi gelince yeniden çizilir). [displaySize] görselin
  /// `BoxFit.cover` ile çizildiği kutunun kenarıdır (dp; avatar çapı, amblem,
  /// küçük kapak) — görsel bu boyutta çözülür; `null` → sınırlı tam boy
  /// (büyük kapak, gönderi görseli). `null` yol → `null`.
  ImageProvider? storageImage(String? path, {double? displaySize}) {
    if (path == null) return null;
    final image = watch(
      storageImageProvider(
        path,
        coverEdgePx: decodePx(context, displaySize),
      ),
    );
    // Süresi dolan adres kullanılırken arka planda yenilenir (sonuç yalnızca
    // bu yolun sağlayıcısını yeniler).
    unawaited(read(imageUrlCacheProvider).request(path));
    return image;
  }

  /// Bir gönderinin [images] görsellerinin çözücüsü (`PostCard.imageOf`):
  /// yalnızca bu yollar izlenir — başka gönderinin görseli gelince izleyen
  /// widget yeniden çizilmez ([postImageResolverProvider] her adreste
  /// yayar).
  PostImageResolver postImagesOf(List<PostImageModel> images) {
    final resolved = <String, ImageProvider?>{
      for (final image in images) image.path: storageImage(image.path),
    };
    return (image) => resolved[image.path];
  }
}

/// Genel Storage görseli çözücüsü — herhangi bir Storage yolunu çizilecek
/// görsele çevirir; [postImageResolver] ile aynı önbellek ve aynı davranış
/// (eşzamanlı; adres gelince yeni çözücü yayılır, izleyen widget yeniden
/// çizilir). Ekranlar tek yol için [StorageImageRefX.storageImage]'ı
/// kullanır (yalnızca o yolun adresiyle yeniden çizilir); bu çözücü yol
/// kümesi önceden bilinmeyen yerler (SHT-34, FED-03 / MGT-09 formları)
/// içindir:
///
/// ```dart
/// final resolve = ref.watch(storageImageResolverProvider);
/// resolve(coverPath);
/// ```
///
/// Okuma yetkisi Storage Rules'tadır (`events/` ve `posts/` — doğrulanmış
/// kullanıcı, tek dosya `get`).
@Riverpod(keepAlive: true)
StorageImageResolver storageImageResolver(Ref ref) {
  final cache = ref.watch(imageUrlCacheProvider);
  final imageOf = ref.watch(storageImageFactoryProvider);
  // Yeni adres → yeni çözücü (izleyen widget'lar yeniden çizilir).
  cache.addListener(ref.invalidateSelf);
  ref.onDispose(() => cache.removeListener(ref.invalidateSelf));
  return (path, {coverEdgePx}) {
    if (path == null) return null;
    // Süresi dolan adres kullanılırken arka planda yenilenir; sonuç
    // dinleyiciyle gelir (hata yer tutucuda kalır).
    unawaited(cache.request(path));
    final url = cache.peek(path);
    return url == null ? null : imageOf(url, path, coverEdgePx: coverEdgePx);
  };
}

/// Gönderi görseli çözücüsü — Storage yolunu (`PostImageModel.path`,
/// `posts/{postId}/{file}`) çizilecek görsele çevirir. `PostCard.imageOf`,
/// `ImageGrid.imageOf`, `ImageViewerSheet.imageOf` ve FED-03 düzenleme
/// kipindeki mevcut görseller aynı çözücüyü kullanır:
///
/// ```dart
/// PostCard(post: post, imageOf: ref.watch(postImageResolverProvider), …)
/// ```
///
/// Çözücü eşzamanlıdır: adresi henüz bilinmeyen görsel için `null` döner
/// (hücre yer tutucu desenle çizilir — K-18) ve indirme adresini arka planda
/// ister ([ImageUrlCache.request]); adres gelince sağlayıcı yeni bir çözücü
/// yayar, izleyen widget yeniden çizilir ve görsel görünür. Adres alınamazsa
/// (dosya yok, yetki, ağ) yer tutucu kalır; görsel indirilemezse
/// `PostImage.errorBuilder` yine yer tutucuyu gösterir.
///
/// Okuma yetkisi Storage Rules'tadır (`posts/` — doğrulanmış kullanıcı, tek
/// dosya); çözücü yalnızca `posts.images[].path` yollarını çözer.
///
/// Mekanizma [storageImageResolver]'dır (aynı önbellek; o yeni çözücü
/// yaydığında bu da yayar).
@Riverpod(keepAlive: true)
PostImageResolver postImageResolver(Ref ref) {
  final resolve = ref.watch(storageImageResolverProvider);
  return (image) => resolve(image.path);
}

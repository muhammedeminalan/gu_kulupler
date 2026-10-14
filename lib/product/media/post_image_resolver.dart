import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/product/media/bounded_image.dart';
import 'package:gu_kulupler/product/media/image_url_cache.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_image_resolver.g.dart';

/// İndirme adresinden çizilecek görseli kuran çağrı. `path` görselin Storage
/// yoludur: dosyalar değişmediği için (D-10) disk önbelleğinin kalıcı
/// anahtarıdır — adresteki erişim jetonu yenilense de görsel yeniden inmez.
typedef StorageImageFactory = ImageProvider Function(String url, String path);

/// Storage indirme adresleri önbelleği (PLAN §10.2: 1 saat). Adresi
/// `StorageService.downloadUrl` verir: servis `ProjectDependencyMixin`'de
/// bilerek yoktur (yükleme repository işidir); salt okunur adres çözümü bu
/// köprüden geçer (`feedbackServiceProvider` kalıbı — view'da servis bulucu
/// çağrılmaz, HC13). Testte `registerDefaultFakes` `FakeStorageService`
/// kaydeder: yüklenmemiş yol `notFound` döner (yer tutucu).
@Riverpod(keepAlive: true)
ImageUrlCache imageUrlCache(Ref ref) {
  final cache = ImageUrlCache(
    fetch: (path) => GetIt.I<StorageService>().downloadUrl(path),
    clock: ref.watch(appClockProvider),
  );
  ref.onDispose(cache.dispose);
  return cache;
}

/// İndirme adresi → görsel: `cached_network_image` (bellek + disk önbelleği),
/// [BoundedImage] ile sarılı — dosya güvenilmeyen içeriktir (Storage Rules
/// piksel boyutunu göremez): piksel sayısı sınırı aşan görsel çözülmeden
/// reddedilir (hücre yer tutucuda kalır), kalanı sınırlı boyutta çözülür.
/// Widget testinde ağ ve disk önbelleği olmadığından, görselin çizildiği
/// test bu sağlayıcıyı bellekteki bir görselle değiştirir:
/// `storageImageFactoryProvider.overrideWithValue((url, path) => …)`.
@Riverpod(keepAlive: true)
StorageImageFactory storageImageFactory(Ref ref) => _cachedNetworkImage;

ImageProvider _cachedNetworkImage(String url, String path) =>
    BoundedImage(CachedNetworkImageProvider(url, cacheKey: path));

/// Storage yolu → çizilecek görsel (`null` yol ya da adresi henüz bilinmeyen
/// görsel → `null`, çağıran yer tutucu / şablon kapak çizer).
typedef StorageImageResolver = ImageProvider? Function(String? path);

/// Genel Storage görseli çözücüsü — herhangi bir Storage yolunu
/// (`events/{eventId}/{file}` etkinlik kapağı, `EventModel.coverPath`)
/// çizilecek görsele çevirir; [postImageResolver] ile aynı önbellek ve aynı
/// davranış (eşzamanlı; adres gelince yeni çözücü yayılır, izleyen widget
/// yeniden çizilir):
///
/// ```dart
/// EventCard(
///   event: event,
///   coverImage: ref.watch(storageImageResolverProvider)(event.coverPath),
///   …
/// )
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
  return (path) {
    if (path == null) return null;
    // Süresi dolan adres kullanılırken arka planda yenilenir; sonuç
    // dinleyiciyle gelir (hata yer tutucuda kalır).
    unawaited(cache.request(path));
    final url = cache.peek(path);
    return url == null ? null : imageOf(url, path);
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

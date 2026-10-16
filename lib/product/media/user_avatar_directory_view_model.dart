import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';
import 'package:gu_kulupler/product/media/user_avatar_directory_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_avatar_directory_view_model.g.dart';

/// Kimliği bilinen ama kullanıcı belgesi elde olmayan avatar yerlerinin
/// (CLB-03 üye önizlemesi / yönetim kurulu / danışman, CLB-01 ve SRC-01 kart
/// avatar grubu, ADM-03 / MGT-09 danışman, SHT-25 adayları) profil
/// fotoğrafı yolu dizini. Satırlar `ref.userAvatarImageOf(uid)` ile okur
/// (`user_avatar_image.dart`); belge zaten eldeyse dizine gidilmez
/// (`ref.userAvatarImage(user)`).
///
/// * **Toplu okuma (N+1 yok):** [request] yalnızca kimliği bekleyenlere
///   ekler; aynı karede (aynı mikro görev turunda) istenen bütün kimlikler
///   tek `userRepository.getUsers` çağrısında okunur — liste başına bir
///   okuma, satır başına değil. Okuma deposunun bellek önbelleğinden geçer
///   (T-44 · D3-01, `CachePolicy.userTtl`).
/// * **Tazeleme:** çözülen kimlik `CachePolicy.userTtl` süresince yeniden
///   istenmez; süresi dolunca bir sonraki [request] arka planda yeniler
///   (eski yol yenisi gelene dek çizilir — avatar titremez).
/// * **Hata:** okunamayan kimlikler baş harflerde kalır ve
///   `MediaConstants.imageUrlRetryAfter` dolmadan yeniden istenmez (her
///   yeniden çizimde istek yağmaz).
/// * **Dönmeyen kimlik:** başarılı okumada sonuçta olmayan kimlik (çevrimdışı
///   kalıcı önbellekten eksik / boş dönen sorgu ya da belgesi olmayan kimlik)
///   çözülmüş sayılmaz: önceki yolu (varsa) kalır, hata gibi
///   `imageUrlRetryAfter` sonra yeniden istenir — bağlantı dönünce avatar
///   `userTtl` beklemeden gelir (depo önbelleği de önbellekten gelen parçayı
///   saklamaz, CD-167 (1)).
/// * Silinmiş / anonimleştirilmiş kullanıcının yolu `null` çözülür (baş
///   harfler; istek `userTtl` boyunca tekrarlanmaz).
/// * **Oturum:** oturum kullanıcısı değişince (çıkış, hesap değişimi) dizin
///   boşalır, süren okumanın sonucu atılır — hesaplar arası taşıma yok
///   (`RepositoryReadCaches.bindSession` ilkesi).
/// * Bellekte en çok `CachePolicy.userMax` kimlik tutulur (en eski atılır).
///
/// Okuma yetkisi Rules'tadır (`users/{uid}` doğrulanmış her kullanıcıya
/// açık — rules-spec §3.1); yazma yolu yoktur.
@Riverpod(keepAlive: true)
final class UserAvatarDirectoryViewModel extends _$UserAvatarDirectoryViewModel
    with ProjectDependencyMixin {
  final Set<String> _pending = <String>{};
  final Set<String> _inFlight = <String>{};
  final Map<String, DateTime> _resolvedAt = <String, DateTime>{};
  final Map<String, DateTime> _retryAt = <String, DateTime>{};
  bool _flushScheduled = false;

  /// Oturum nesli: oturum değişince artar; eski nesilden dönen okuma atılır.
  int _generation = 0;

  @override
  UserAvatarDirectoryState build() {
    // Oturum kullanıcısı değişince yeniden kurulur: dizin boşalır.
    ref.watch(sessionViewModelProvider.select((s) => s.uid));
    _generation++;
    _pending.clear();
    _inFlight.clear();
    _resolvedAt.clear();
    _retryAt.clear();
    _flushScheduled = false;
    return const UserAvatarDirectoryState();
  }

  /// [uids]'in avatar yollarını ister. Eşzamanlıdır ve state'i değiştirmez
  /// (widget `build` içinde çağrılabilir); okuma mikro görevde, bekleyen
  /// bütün kimliklerle tek çağrıda yapılır. Taze çözülmüş, okunmakta olan,
  /// bekleme süresindeki ve geçersiz kimlikler atlanır.
  void request(Iterable<String> uids) {
    DateTime? now;
    for (final uid in uids) {
      if (_pending.contains(uid) || _inFlight.contains(uid)) continue;
      if (!RepositoryHelpers.isValidId(uid)) continue;
      now ??= appClock.nowUtc();
      final retryAt = _retryAt[uid];
      if (retryAt != null && now.isBefore(retryAt)) continue;
      final resolvedAt = _resolvedAt[uid];
      if (resolvedAt != null &&
          now.difference(resolvedAt) < CachePolicy.userTtl) {
        continue;
      }
      _pending.add(uid);
    }
    if (_pending.isEmpty || _flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(() => unawaited(_flush()));
  }

  Future<void> _flush() async {
    _flushScheduled = false;
    if (!ref.mounted || _pending.isEmpty) return;
    final generation = _generation;
    final batch = _pending.toList(growable: false);
    _pending.clear();
    _inFlight.addAll(batch);
    state = state.copyWith(isFetching: true);
    final result = await userRepository.getUsers(batch);
    // Oturum değiştiyse sonuç eski hesabındır: atılır (alanlar sıfırlandı).
    if (!ref.mounted || generation != _generation) return;
    _inFlight.removeAll(batch);
    final now = appClock.nowUtc();
    switch (result) {
      case FirebaseSuccess(:final data):
        final byId = {for (final user in data) user.uid: user};
        final paths = Map<String, String?>.of(state.avatarPaths);
        final retryAt = now.add(MediaConstants.imageUrlRetryAfter);
        for (final uid in batch) {
          final user = byId[uid];
          if (user == null) {
            // Dönmedi (çevrimdışı eksik sonuç / belge yok): kısa bekleme.
            _retryAt[uid] = retryAt;
            continue;
          }
          _retryAt.remove(uid);
          _resolvedAt[uid] = now;
          paths
            ..remove(uid)
            ..[uid] = _avatarPathOf(user);
        }
        _trim(paths);
        state = state.copyWith(
          avatarPaths: paths,
          isFetching: _inFlight.isNotEmpty,
          isError: false,
        );
      case FirebaseFailure():
        final retryAt = now.add(MediaConstants.imageUrlRetryAfter);
        for (final uid in batch) {
          _retryAt[uid] = retryAt;
        }
        state = state.copyWith(
          isFetching: _inFlight.isNotEmpty,
          isError: true,
        );
    }
  }

  /// En eski çözülenleri atar (ekleme sırası = çözülme sırası).
  void _trim(Map<String, String?> paths) {
    final overflow = paths.length - CachePolicy.userMax;
    if (overflow <= 0) return;
    final oldest = paths.keys.take(overflow).toList(growable: false);
    for (final uid in oldest) {
      paths.remove(uid);
      _resolvedAt.remove(uid);
    }
  }

  /// Silinmiş / anonimleştirilmiş kullanıcının fotoğrafı istenmez.
  static String? _avatarPathOf(UserModel user) =>
      user.isDeleted || user.isAnonymized ? null : user.avatarPath;
}

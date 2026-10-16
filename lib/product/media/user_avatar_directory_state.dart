import 'package:equatable/equatable.dart';

/// `UserAvatarDirectoryViewModel`'in durumu: kimliği bilinen ama belgesi
/// elde olmayan kullanıcıların (üyelik `applicant` anlık görüntüsü, danışman
/// bağı, SHT-25 adayı) profil fotoğrafı yolları.
final class UserAvatarDirectoryState extends Equatable {
  /// Boş dizin.
  const UserAvatarDirectoryState({
    this.avatarPaths = const <String, String?>{},
    this.isFetching = false,
    this.isError = false,
  });

  /// Çözülmüş kimlik → `users.avatarPath`. Değer `null` ise kullanıcının
  /// fotoğrafı yoktur, hesabı silinmiş / anonimleştirilmiştir ya da belgesi
  /// yoktur (baş harfler çizilir). Anahtarı olmayan kimlik henüz çözülmedi.
  final Map<String, String?> avatarPaths;

  /// Toplu okuma sürüyor mu.
  final bool isFetching;

  /// Son toplu okuma başarısız oldu mu (satırlar baş harflerde kalır; aynı
  /// kimlikler bekleme süresinden sonra yeniden istenir).
  final bool isError;

  /// [uid] çözüldü mü (fotoğrafı olsun olmasın).
  bool isResolved(String uid) => avatarPaths.containsKey(uid);

  /// [uid]'in avatar yolu; çözülmediyse ya da fotoğrafı yoksa `null`.
  String? avatarPathOf(String uid) => avatarPaths[uid];

  @override
  List<Object?> get props => [avatarPaths, isFetching, isError];

  /// Verilen alanları değişmiş kopya.
  UserAvatarDirectoryState copyWith({
    Map<String, String?>? avatarPaths,
    bool? isFetching,
    bool? isError,
  }) => UserAvatarDirectoryState(
    avatarPaths: avatarPaths ?? this.avatarPaths,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
  );
}

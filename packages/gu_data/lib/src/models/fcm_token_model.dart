import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fcm_token_model.g.dart';

/// Bir cihazın anlık bildirim belirteci — `account.fcmTokens[]` elemanı
/// (PLAN §9.6.2, domain-model §2.2).
///
/// Gömülü modeldir: kendi belgesi ve `BaseFields` alanları yoktur. T-42
/// (Mod F, CD-165): uygulama girişte / jeton yenilenince / dil değişince
/// yazar (`UserRepository.upsertFcmToken`), çıkışta bu cihazınkini çıkarır
/// (`removeFcmToken`); sunucu yalnızca geçersiz jetonu çıkarır.
@JsonSerializable()
final class FcmTokenModel extends Equatable {
  /// Belirteç kaydı oluşturur.
  const FcmTokenModel({
    required this.token,
    required this.platform,
    required this.updatedAt,
    this.locale = defaultLocale,
  });

  /// Firestore map'inden model üretir. Eksik ya da `null` [updatedAt]
  /// `CheckedFromJsonException` fırlatır.
  factory FcmTokenModel.fromJson(Map<String, Object?> json) =>
      _$FcmTokenModelFromJson(json);

  /// FCM kayıt belirteci (boş olamaz).
  @JsonKey(name: FirestoreFields.token)
  final String token;

  /// Cihaz platformu: `'ios'` ya da `'android'` (`Limits.platforms`).
  @JsonKey(name: FirestoreFields.platform)
  final String platform;

  /// Push metinlerinin dili: `'tr'` ya da `'en'` ([locales]). Uygulama dili
  /// cihaz tercihidir (sunucu göremez); push dili bu yüzden cihaz başınadır.
  /// Alanı olmayan eski eleman [defaultLocale] okunur (CD-165).
  @JsonKey(name: FirestoreFields.locale, defaultValue: defaultLocale)
  final String locale;

  /// [locale] için izinli değerler (Rules `fcmTokenOk` ile aynı küme).
  static const Set<String> locales = {'tr', 'en'};

  /// [locale] yoksa ya da desteklenmeyen dildeyse kullanılan dil.
  static const String defaultLocale = 'tr';

  /// Belirtecin son yazıldığı an (UTC). Dizi elemanı olduğu için sunucu
  /// zamanı kullanılamaz; **istemci** zamanıdır ve zorunludur.
  @JsonKey(name: FirestoreFields.updatedAt)
  @RequiredTimestampConverter()
  final DateTime updatedAt;

  /// Firestore'a yazılacak map.
  Map<String, Object?> toJson() => _$FcmTokenModelToJson(this);

  /// Aynı jeton, platform ve dilin yeniden yazılmadığı süre (T-44 · D2-06):
  /// her açılışta değil, en çok bu aralıkla bir kez `updatedAt` tazelenir.
  static const Duration refreshInterval = Duration(days: 7);

  /// [current] listesine [token]'ın eklenmiş hâli (T-42, CD-165): aynı
  /// jetonlu eski eleman çıkarılır, [token] sona eklenir; liste
  /// `Limits.fcmTokensMax`'ı aşarsa en eski `updatedAt`'li elemanlar atılır
  /// ([token] hiçbir zaman atılmaz). [current] değişmez.
  ///
  /// [current] aynı jetonu aynı platform ve dille [refreshInterval]'dan daha
  /// yeni bir `updatedAt` ile zaten taşıyorsa [current] **aynen** döner:
  /// liste değişmediği için çağıran yazımı atlar (T-44 · D2-06 — açılış
  /// başına yazım haftada bire iner).
  static List<FcmTokenModel> upserted(
    List<FcmTokenModel> current,
    FcmTokenModel token,
  ) {
    for (final item in current) {
      if (item.token == token.token &&
          item.platform == token.platform &&
          item.locale == token.locale &&
          token.updatedAt.difference(item.updatedAt) < refreshInterval) {
        return current;
      }
    }
    final others = [
      for (final item in current)
        if (item.token != token.token) item,
    ];
    final overflow = others.length + 1 - Limits.fcmTokensMax;
    if (overflow > 0) {
      final oldest =
          ([...others]..sort((a, b) => a.updatedAt.compareTo(b.updatedAt)))
              .take(overflow)
              .toSet();
      others.removeWhere(oldest.contains);
    }
    return [...others, token];
  }

  /// Verilen alanları değiştirilmiş kopya.
  FcmTokenModel copyWith({
    String? token,
    String? platform,
    DateTime? updatedAt,
    String? locale,
  }) => FcmTokenModel(
    token: token ?? this.token,
    platform: platform ?? this.platform,
    updatedAt: updatedAt ?? this.updatedAt,
    locale: locale ?? this.locale,
  );

  @override
  List<Object?> get props => [token, platform, updatedAt, locale];
}

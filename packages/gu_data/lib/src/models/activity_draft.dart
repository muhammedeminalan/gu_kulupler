import 'package:equatable/equatable.dart';
import 'package:gu_data/src/models/activity_refs_model.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';

/// Henüz yazılmamış kulüp günlüğü kaydı (PLAN §10.4 `ActivityRepository`).
///
/// Eylemi yapan repository, asıl yazımıyla **aynı batch / transaction** içinde
/// günlüğe eklenecek kaydı bununla tarif eder; `createdAt` (sunucu zamanı)
/// yazım anında eklenir (domain-model §2.11).
final class ActivityDraft extends Equatable {
  /// [clubId] kulübünün günlüğüne, [actorId] kullanıcısının yaptığı [kind]
  /// türünde kayıt. [refs] türün zorunlu referanslarını taşır (üyelik
  /// türlerinde `userId` — PLAN §9.6.13). [id] verilirse belge o kimlikle
  /// yazılır; verilmezse kimlik yazım anında üretilir.
  const ActivityDraft({
    required this.clubId,
    required this.actorId,
    required this.kind,
    this.refs = const ActivityRefsModel(),
    this.id,
  });

  /// Belgenin sabit kimliği; `null` ise yazım anında üretilir.
  ///
  /// Kullanıcının kendi üyelik geçişlerinde zorunludur
  /// (`FirestoreIds.activity`): Security Rules kimliği alanlarla karşılaştırır
  /// ve bir geçişe tek günlük belgesi kabul eder (rules-spec §3.11).
  final String? id;

  /// Kaydın ait olduğu kulüp.
  final String clubId;

  /// Eylemi yapan kullanıcının uid'i (Rules: `actorId == request.auth.uid`).
  final String actorId;

  /// Kaydın türü.
  final ActivityKind kind;

  /// Kaydın işaret ettiği belgeler.
  final ActivityRefsModel refs;

  @override
  List<Object?> get props => [clubId, actorId, kind, refs, id];
}

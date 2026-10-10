import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:json_annotation/json_annotation.dart';

part 'poll_option_model.g.dart';

/// Anket seçeneği — `posts.poll.options[]` elemanı (PLAN §9.6.6,
/// domain-model §2.5).
///
/// Gömülü modeldir: kendi belgesi ve `BaseFields` alanları yoktur. Oylar
/// seçenekte tutulmaz; `posts/{postId}/votes/{uid}` belgelerinden sayılır.
@JsonSerializable()
final class PollOptionModel extends Equatable {
  /// Anket seçeneği oluşturur.
  const PollOptionModel({required this.id, required this.text});

  /// Firestore map'inden model üretir. Eksik [id] ya da [text]
  /// `CheckedFromJsonException` fırlatır.
  factory PollOptionModel.fromJson(Map<String, Object?> json) =>
      _$PollOptionModelFromJson(json);

  /// Seçenek kimliği (`o1`–`o4`, `FirestoreIds.pollOption`). Belge kimliği
  /// **değildir**: JSON'a yazılır ve `votes.optionId` bu değeri taşır.
  @JsonKey(name: FirestoreFields.id)
  final String id;

  /// Seçenek metni (1 – `Limits.pollOptionTextMax`).
  @JsonKey(name: FirestoreFields.text)
  final String text;

  /// Firestore'a yazılacak map.
  Map<String, Object?> toJson() => _$PollOptionModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  PollOptionModel copyWith({String? id, String? text}) =>
      PollOptionModel(id: id ?? this.id, text: text ?? this.text);

  @override
  List<Object?> get props => [id, text];
}

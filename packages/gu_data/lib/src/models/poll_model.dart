import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/models/poll_option_model.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'poll_model.g.dart';

/// Anket — `posts.poll` nesnesi (PLAN §9.6.6, domain-model §2.5).
///
/// Gömülü modeldir: kendi belgesi ve `BaseFields` alanları yoktur. Yalnızca
/// `type == poll` gönderilerde bulunur; anket sorusu gönderinin `text`
/// alanındadır. Seçenekler oluşturulduktan sonra değişmez.
@JsonSerializable()
final class PollModel extends Equatable {
  /// Anket oluşturur.
  const PollModel({
    required this.options,
    required this.endsAt,
    this.showResultsAfterVote = true,
  });

  /// Firestore map'inden model üretir. Eksik ya da `null` [endsAt] ve eksik
  /// [options] `CheckedFromJsonException` fırlatır.
  factory PollModel.fromJson(Map<String, Object?> json) =>
      _$PollModelFromJson(json);

  /// Seçenekler (`Limits.pollOptionsMin` – `Limits.pollOptionsMax`; kimlikler
  /// tekrarsız).
  @JsonKey(name: FirestoreFields.options)
  final List<PollOptionModel> options;

  /// Anketin kapandığı an (UTC). İstemci hesaplar: oluşturma anı +
  /// `Limits.pollDurationsDays` seçeneklerinden biri.
  @JsonKey(name: FirestoreFields.endsAt)
  @RequiredTimestampConverter()
  final DateTime endsAt;

  /// Sonuçlar yalnızca oy verdikten (ya da anket kapandıktan) sonra mı
  /// görünür?
  @JsonKey(name: FirestoreFields.showResultsAfterVote)
  final bool showResultsAfterVote;

  /// Firestore'a yazılacak map.
  Map<String, Object?> toJson() => _$PollModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  PollModel copyWith({
    List<PollOptionModel>? options,
    DateTime? endsAt,
    bool? showResultsAfterVote,
  }) => PollModel(
    options: options ?? this.options,
    endsAt: endsAt ?? this.endsAt,
    showResultsAfterVote: showResultsAfterVote ?? this.showResultsAfterVote,
  );

  @override
  List<Object?> get props => [options, endsAt, showResultsAfterVote];
}

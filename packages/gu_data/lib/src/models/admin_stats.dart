import 'package:equatable/equatable.dart';

/// ADM-01 genel bakış KPI'ları — PLAN §10.4 `AdminRepository.stats` (T-37;
/// sözleşme `docs/plans/T-37.md` §4 a).
///
/// Her değer tek bir `count()` toplama sorgusudur (belge okunmaz; 1 000
/// dizin girdisi başına 1 okuma ücreti). Sayılar okunduğu anın
/// görüntüsüdür; canlı değildir.
final class AdminStats extends Equatable {
  /// Dört sayaç.
  const AdminStats({
    this.clubCount = 0,
    this.userCount = 0,
    this.openReportCount = 0,
    this.upcomingEventCount = 0,
  });

  /// Etkin kulüpler: `clubs where isDeleted == false, status == active`.
  final int clubCount;

  /// Silinmemiş kullanıcılar (askıdakiler dahil): `users where isDeleted ==
  /// false`.
  final int userCount;

  /// Açık şikayetler: `reports where status == open` (CD-37 — Mod C'de
  /// `new_report` belgesi üretilmez, KPI yalnızca bu sorgudan beslenir).
  final int openReportCount;

  /// Yaklaşan yayımdaki etkinlikler: `events where status == published,
  /// isDeleted == false, startsAt >= şimdi` (indeks `events (status,
  /// isDeleted, startsAt)`).
  final int upcomingEventCount;

  @override
  List<Object?> get props => [
    clubCount,
    userCount,
    openReportCount,
    upcomingEventCount,
  ];
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/provider/report_group.dart';

ReportModel _report(
  String reporter,
  ReportTargetType type,
  String target, {
  ReportReason reason = ReportReason.spam,
  int? minute,
  ReportStatus status = ReportStatus.open,
  ReportAction? action,
  int? resolvedMinute,
  bool isDeleted = false,
}) => ReportModel(
  targetType: type,
  targetId: target,
  reporterId: reporter,
  reason: reason,
  targetClubId: type == ReportTargetType.user ? null : 'c01',
  status: status,
  action: action,
  createdAt: minute == null ? null : DateTime.utc(2026, 10, 1, 12, minute),
  resolvedAt: resolvedMinute == null
      ? null
      : DateTime.utc(2026, 10, 2, 12, resolvedMinute),
  isDeleted: isDeleted,
);

void main() {
  group('T-40 · ReportGroup.groupOf', () {
    test('aynı hedefin çoklu şikayeti tek grup; anahtar {type}_{id}', () {
      final groups = ReportGroup.groupOf([
        _report('u1', ReportTargetType.post, 'p1', minute: 30),
        _report('u2', ReportTargetType.user, 'u9', minute: 20),
        _report(
          'u3',
          ReportTargetType.post,
          'p1',
          reason: ReportReason.harassment,
          minute: 10,
        ),
        _report('u4', ReportTargetType.post, 'p1', minute: 5),
        // Aynı kimlik farklı tür → ayrı grup.
        _report('u5', ReportTargetType.comment, 'p1', minute: 1),
      ]);

      expect(groups.map((g) => g.key), [
        'post_p1',
        'user_u9',
        'comment_p1',
      ]);
      final post = groups.first;
      expect(post.targetType, ReportTargetType.post);
      expect(post.targetId, 'p1');
      expect(post.targetClubId, 'c01');
      expect(post.count, 3);
      expect(post.reporterIds, ['u1', 'u3', 'u4']);
      expect(post.reportIds, [
        FirestoreIds.report('u1', 'post', 'p1'),
        FirestoreIds.report('u3', 'post', 'p1'),
        FirestoreIds.report('u4', 'post', 'p1'),
      ]);
      expect(post.reasonCounts, {
        ReportReason.spam: 2,
        ReportReason.harassment: 1,
      });
      expect(post.primaryReason, ReportReason.spam);
      expect(post.firstAt, DateTime.utc(2026, 10, 1, 12, 5));
      expect(post.lastAt, DateTime.utc(2026, 10, 1, 12, 30));
      expect(post.status, ReportStatus.open);
      expect(post.isOpen, isTrue);
      expect(post.openReportIds, hasLength(3));
      expect(post.action, isNull);
      expect(groups[1].targetClubId, isNull);
    });

    test('sıralama: grup son şikayete, grup içi createdAt azalan; zamansız '
        'sonda, eşitlikte girdi sırası; silinmiş atlanır', () {
      final groups = ReportGroup.groupOf([
        _report('u1', ReportTargetType.club, 'c1'),
        _report('u2', ReportTargetType.event, 'e1', minute: 10),
        _report('u3', ReportTargetType.event, 'e1', minute: 40),
        _report('u4', ReportTargetType.post, 'p2', minute: 40),
        _report('u5', ReportTargetType.post, 'p3', minute: 50, isDeleted: true),
      ]);

      expect(groups.map((g) => g.key), ['event_e1', 'post_p2', 'club_c1']);
      expect(groups.first.reporterIds, ['u3', 'u2']);
      expect(groups.first.primaryReason, ReportReason.spam);
      expect(groups.last.firstAt, isNull);
      expect(groups.last.lastAt, isNull);
      expect(ReportGroup.groupOf(const []), isEmpty);
    });

    test('çözülen grup: durum resolved, son çözümün işlemi ve anı', () {
      final group = ReportGroup.groupOf([
        _report(
          'u1',
          ReportTargetType.comment,
          'm1',
          minute: 1,
          status: ReportStatus.resolved,
          action: ReportAction.dismissed,
          resolvedMinute: 1,
        ),
        _report(
          'u2',
          ReportTargetType.comment,
          'm1',
          minute: 2,
          status: ReportStatus.resolved,
          action: ReportAction.removed,
          resolvedMinute: 9,
        ),
      ]).single;

      expect(group.status, ReportStatus.resolved);
      expect(group.isOpen, isFalse);
      expect(group.openReportIds, isEmpty);
      expect(group.action, ReportAction.removed);
      expect(group.resolvedAt, DateTime.utc(2026, 10, 2, 12, 9));
    });
  });
}

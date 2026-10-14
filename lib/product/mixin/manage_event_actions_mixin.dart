import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/event_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/dialogs/cancel_event_dialog.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';

/// SHT-23 menüsünden sonra view'un yapacağı gezinme.
enum ManageEventNext {
  /// Yapılacak bir şey yok (kapatıldı, vazgeçildi, yazıldı ya da yazılamadı).
  none,

  /// MGT-05 düzenleme (`EventEditRoute`): "Düzenle" ya da "Çoğalt" sonrası
  /// yeni taslak.
  edit,

  /// MGT-06 katılımcılar (T-35).
  attendees,

  /// MGT-07 yoklama (T-35).
  scan,

  /// Taslak kaldırıldı (TST-45 gösterildi): EVT-02 önceki sayfaya döner.
  removed,
}

/// SHT-23 sonucu: `next` gezinmesi ve hedef etkinliğin kimliği (çoğaltmada
/// yeni taslağın kimliği).
typedef ManageEventOutcome = ({ManageEventNext next, String eventId});

/// Yönetim akışlarının ViewModel'de bulunmayan yerelleştirilmiş metinleri
/// (view verir): kopya başlığının soneki (`eventCopySuffix`) ve TST-45'teki
/// ad (`statusDraft`).
typedef ManageEventTexts = ({String copySuffix, String draftLabel});

/// Etkinlik yönetimi akışlarının **tek yeri** (PLAN §12.6
/// `ManageEventsViewModel`; domain-model §2.7 durum makinesi, K-F): SHT-23
/// menüsü ve satırlarının yürütülmesi. MGT-04 ve EVT-02 yönetici "⋮" (W-27)
/// ViewModel'leri kullanır; feature'da kopyası yoktur.
///
/// | Satır | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | Düzenle · Yoklama | danışman TST-26 | — | view MGT-05 / MGT-07'ye gider |
/// | Katılımcılar · Paylaş | — | — | MGT-06 · SHT-15 (TST-35, DLG-32) |
/// | [duplicateEvent] | danışman · çevrimdışı | `duplicate` (+7 gün, kapak kopyalanmaz) | TST-13 → MGT-05 (kopya) |
/// | [unpublishEvent] | + K-F (`goingCount == 0`) | iyimser `draft` → `unpublishEvent` | TST-X19 |
/// | [cancelEvent] | DLG-23 (neden) | iyimser `cancelled` → `cancelEvent` (bildirim) | TST-48 |
/// | [setRegistrationOpen] | danışman · çevrimdışı | iyimser `registrationOpen` | TST-X15 |
/// | [softDeleteDraft] | DLG-31, yalnız taslak | iyimser düşer → `softDeleteEvent` | TST-45 "Geri al" → [restoreDraft] |
/// | yazılamadı | — | iyimser değişiklik geri alınır | TST-24 · TST-X18; çakışmada liste yenilenir |
///
/// Kurallar (hangi satır görünür / etkin) yalnızca
/// `EventMenuSheet.actionsFor`'dadır; son karar Rules'un. TST-45 ekrandan uzun
/// yaşar: "Geri al" ViewModel kapandıktan sonra gelebilir; mixin o yolda
/// yalnızca GetIt bağımlılıklarını ve yakaladığı değerleri kullanır,
/// tüketici kancalarda `ref.mounted` denetler.
///
/// Design: SHT-23, DLG-31
mixin ManageEventActionsMixin
    on ProjectDependencyMixin, WriteGuardMixin, ExternalLinkMixin {
  /// Süren etkinlik yazımları: çift dokunuş ikinci yazımı başlatmaz.
  final Set<String> _busyEvents = <String>{};

  // ───────────────────────── tüketicinin verdikleri ─────────────────────────

  /// Oturum (aktörün kimliği, kulübe erişimi); ViewModel kapandıysa `null`
  /// (hiçbir şey yazılmaz).
  SessionState? get eventSession;

  /// [event] iyimser olarak değişti (taslağa alındı, iptal edildi) ya da
  /// yazılamadığı için eski hâline döndü: tüketici satırı değiştirir.
  void onEventChanged(EventModel event) {}

  /// [event] taslağı iyimser olarak kaldırıldı (DLG-31 onayı).
  void onEventRemoved(EventModel event) {}

  /// [event] geri geldi: kaldırma yazılamadı ya da TST-45 "Geri al".
  void onEventRestored(EventModel event) {}

  /// [event] yeni taslak olarak yazıldı ("Çoğalt").
  void onEventAdded(EventModel event) {}

  /// Sunucudaki durum ekrandakinden farklı (çakışma, K-F yarışı): tüketici
  /// listeyi yeniden okur.
  void onEventListStale(String clubId) {}

  // ──────────────────────────────── yetki ───────────────────────────────────

  /// Aktörün kimliği; oturum yoksa `null`.
  String? get eventActorId => eventSession?.uid;

  /// [eventId] için yazım sürüyor mu.
  bool isEventBusy(String eventId) => _busyEvents.contains(eventId);

  /// Gezinen yönetim eyleminden önce (düzenle, yoklama): danışmansa TST-26
  /// ve `false` (Q-09).
  bool ensureEventEditable(String clubId) {
    if (eventSession?.accessTo(clubId) == ClubAccess.advisor) {
      feedback.showToast(ToastId.tst26);
      return false;
    }
    return true;
  }

  /// Yazan yönetim eyleminden önce: danışman → TST-26, çevrimdışı → TST-24.
  bool ensureEventWritable(String clubId) =>
      ensureEventEditable(clubId) && ensureOnline();

  // ──────────────────────────────── akışlar ─────────────────────────────────

  /// SHT-23 "Etkinlik menüsü" ([event] başlıkta; satırlar
  /// `EventMenuSheet.actionsFor`, şimdiki an `appClock`). Yazan satırlar
  /// burada yürütülür; gezinme view'a döner ([ManageEventOutcome]).
  Future<ManageEventOutcome> openEventMenu(
    EventModel event,
    ManageEventTexts texts,
  ) async {
    final none = (next: ManageEventNext.none, eventId: event.id);
    if (isEventBusy(event.id)) return none;
    final action = await feedback.showSheet<EventMenuAction>(
      SheetId.sht23,
      builder: (_) => EventMenuSheet(event: event, now: appClock.nowUtc()),
    );
    switch (action) {
      case null:
        return none;
      case EventMenuAction.edit:
        if (!ensureEventEditable(event.clubId)) return none;
        return (next: ManageEventNext.edit, eventId: event.id);
      case EventMenuAction.duplicate:
        final copy = await duplicateEvent(event, copySuffix: texts.copySuffix);
        if (copy == null) return none;
        return (next: ManageEventNext.edit, eventId: copy.id);
      case EventMenuAction.attendees:
        return (next: ManageEventNext.attendees, eventId: event.id);
      case EventMenuAction.scan:
        if (!ensureEventEditable(event.clubId)) return none;
        return (next: ManageEventNext.scan, eventId: event.id);
      case EventMenuAction.share:
        await shareEvent(event);
        return none;
      case EventMenuAction.unpublish:
        await unpublishEvent(event);
        return none;
      case EventMenuAction.cancel:
        await cancelEvent(event);
        return none;
      case EventMenuAction.delete:
        final removed = await softDeleteDraft(
          event,
          draftLabel: texts.draftLabel,
        );
        return removed
            ? (next: ManageEventNext.removed, eventId: event.id)
            : none;
    }
  }

  /// "Çoğalt" (`SHT-23.duplicate`): [event] yeni taslak olarak kopyalanır —
  /// başlık + [copySuffix], başlangıç / bitiş `Limits.eventCopyShift` (7 gün)
  /// ileri, özel kapak kopyalanmaz (`EventRepository.duplicate`) → TST-13.
  /// Yazılan kopya; yazılamadıysa `null`.
  Future<EventModel?> duplicateEvent(
    EventModel event, {
    required String copySuffix,
  }) async {
    final actorId = eventActorId;
    if (actorId == null || !ensureEventWritable(event.clubId)) return null;
    if (!_begin(event.id)) return null;
    final result = await eventRepository.duplicate(
      event.id,
      createdBy: actorId,
      copyTitleSuffix: copySuffix,
    );
    _end(event.id);
    switch (result) {
      case FirebaseSuccess(:final data):
        onEventAdded(data);
        feedback.showToast(ToastId.tst13);
        return data;
      case FirebaseFailure(:final error, :final message):
        _reportFailure(event.clubId, error, message, 'Etkinlik çoğaltılamadı');
        return null;
    }
  }

  /// "Yayından kaldır / taslağa al" (`SHT-23.unpublish`): yalnızca kayıtlısı
  /// yokken (K-F; satır aksi hâlde devre dışı). İyimser `draft` →
  /// `ManagementRepository.unpublishEvent` → TST-X19 (yalnızca başarıda);
  /// yazılamazsa eski durum geri gelir.
  Future<bool> unpublishEvent(EventModel event) async {
    if (event.status != EventStatus.published || !event.canUnpublish) {
      return false;
    }
    if (!ensureEventWritable(event.clubId) || !_begin(event.id)) return false;
    onEventChanged(event.copyWith(status: EventStatus.draft));
    final result = await managementRepository.unpublishEvent(event.id);
    _end(event.id);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tstX19);
        return true;
      case FirebaseFailure(:final error, :final message):
        onEventChanged(event);
        _reportFailure(event.clubId, error, message, 'Taslağa alınamadı');
        return false;
    }
  }

  /// Kayıtları aç / kapat (PLAN §12.6 `toggleRegistration`; MGT-06 "⋮"
  /// `MGT-06.toggleRegistration` T-35'te bağlanır): iyimser
  /// `registrationOpen` → `EventRepository.setRegistrationOpen` → TST-X15
  /// ("Kayıtlar açıldı / kapatıldı."); yazılamazsa eski değer geri gelir.
  /// İptal edilmiş etkinlikte yazım yok.
  Future<bool> setRegistrationOpen(
    EventModel event, {
    required bool open,
  }) async {
    if (event.status == EventStatus.cancelled ||
        event.registrationOpen == open) {
      return false;
    }
    if (!ensureEventWritable(event.clubId) || !_begin(event.id)) return false;
    onEventChanged(event.copyWith(registrationOpen: open));
    final result = await eventRepository.setRegistrationOpen(event.id, open);
    _end(event.id);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tstX15, params: ToastParams(open: open));
        return true;
      case FirebaseFailure(:final error, :final message):
        onEventChanged(event);
        _reportFailure(event.clubId, error, message, 'Kayıt durumu yazılamadı');
        return false;
    }
  }

  /// "İptal et" (`SHT-23.cancel`): DLG-23 (neden zorunlu) → iyimser
  /// `cancelled` → `ManagementRepository.cancelEvent` (kayıtlılara
  /// `event_cancelled` bildirimi) → TST-48. İptal geri alınamaz.
  Future<bool> cancelEvent(EventModel event) async {
    final actorId = eventActorId;
    if (actorId == null || event.status != EventStatus.published) return false;
    if (!ensureEventEditable(event.clubId) || isEventBusy(event.id)) {
      return false;
    }
    final reason = await CancelEventDialog.show(
      feedback,
      count: event.goingCount,
    );
    if (reason == null || !ensureEventWritable(event.clubId)) return false;
    if (!_begin(event.id)) return false;
    onEventChanged(
      event.copyWith(status: EventStatus.cancelled, cancelReason: reason),
    );
    final result = await managementRepository.cancelEvent(
      event.id,
      clubId: event.clubId,
      reason: reason,
      actorId: actorId,
    );
    _end(event.id);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst48);
        return true;
      case FirebaseFailure(:final error, :final message):
        onEventChanged(event);
        _reportFailure(
          event.clubId,
          error,
          message,
          'Etkinlik iptal edilemedi',
        );
        return false;
    }
  }

  /// "Sil" (`SHT-23.delete`, yalnız taslak): DLG-31 → iyimser kaldırma →
  /// `EventRepository.softDeleteEvent` (D-10) → TST-45 "{Taslak} silindi."
  /// ([draftLabel]) + "Geri al" → [restoreDraft]. Kaldırıldıysa `true`.
  Future<bool> softDeleteDraft(
    EventModel event, {
    required String draftLabel,
  }) async {
    final actorId = eventActorId;
    if (actorId == null || event.status != EventStatus.draft) return false;
    if (!ensureEventEditable(event.clubId) || isEventBusy(event.id)) {
      return false;
    }
    final confirmed = await feedback.showDialog<bool>(DialogId.dlg31);
    if (confirmed != true || !ensureEventWritable(event.clubId)) return false;
    if (!_begin(event.id)) return false;
    onEventRemoved(event);
    final result = await eventRepository.softDeleteEvent(
      event.id,
      actorId: actorId,
    );
    _end(event.id);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(
          ToastId.tst45,
          params: ToastParams(what: draftLabel),
          onAction: () => unawaited(restoreDraft(event)),
        );
        return true;
      case FirebaseFailure(:final error, :final message):
        onEventRestored(event);
        _reportFailure(event.clubId, error, message, 'Taslak silinemedi');
        return false;
    }
  }

  /// TST-45 "Geri al": kaldırılan taslak geri yüklenir
  /// (`EventRepository.restoreEvent`; Rules yalnızca kaldıran yöneticiye
  /// izin verir).
  Future<bool> restoreDraft(EventModel event) async {
    if (!ensureOnline()) return false;
    final result = await eventRepository.restoreEvent(event.id);
    switch (result) {
      case FirebaseSuccess():
        onEventRestored(event);
        return true;
      case FirebaseFailure(:final error, :final message):
        _reportFailure(event.clubId, error, message, 'Taslak geri alınamadı');
        return false;
    }
  }

  /// "Paylaş" (`SHT-23.share`): SHT-15 → kopyala (TST-35) · WhatsApp /
  /// e-posta (DLG-32) · sistem paylaşımı.
  Future<void> shareEvent(EventModel event) async {
    final url = eventShareUrl(event.id);
    final choice = await feedback.showSheet<ShareChoice>(
      SheetId.sht15,
      builder: (_) => ShareSheet(title: event.title, url: url),
    );
    switch (choice) {
      case null:
        return;
      case ShareChoice.copyLink:
        if (await shareService.copyText(url)) {
          feedback.showToast(ToastId.tst35);
        }
      case ShareChoice.whatsapp:
        await openExternalLink(ShareLinks.whatsApp(url));
      case ShareChoice.email:
        await openExternalLink(ShareLinks.email(event.title));
      case ShareChoice.other:
        await shareService.shareText(url, subject: event.title);
    }
  }

  /// [eventId] etkinliğinin paylaşım bağlantısı (EVT-02 ile aynı biçim —
  /// `AppConstants.shareBaseUrl` + `/events/<id>`, K-D).
  static String eventShareUrl(String eventId) =>
      '${AppConstants.shareBaseUrl}${AppPaths.events}/$eventId';

  // ────────────────────────────────── iç ────────────────────────────────────

  bool _begin(String eventId) => _busyEvents.add(eventId);

  void _end(String eventId) => _busyEvents.remove(eventId);

  /// Yazma hatası: ağ → TST-24, yetki → TST-X18 (`WriteGuardMixin`); durum
  /// çakışması (K-F yarışı, artık taslak / yayında değil, bulunamadı) →
  /// liste yenilenir; diğerleri günlüğe + TST-X18.
  void _reportFailure(
    String clubId,
    FirestoreError error,
    String? message,
    String what,
  ) {
    AppLogger.warn('$what: ${error.name}', error: message);
    if (showWriteFailureToast(error)) return;
    switch (error) {
      case FirestoreError.ruleViolation ||
          FirestoreError.failedPrecondition ||
          FirestoreError.notFound ||
          FirestoreError.conflict:
        onEventListStale(clubId);
      case _:
        feedback.showToast(ToastId.tstX18);
    }
  }
}

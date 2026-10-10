// Fixture: HC12c temiz — tek giriş FeedbackService; showGuSheet( yorumda serbest.
class ClubView {
  Future<void> open(FeedbackService feedback, WidgetRef ref, Key key) async {
    await feedback.showSheet<void>(SheetId.sht05, builder: (_) => const SizedBox());
    final ok = await feedback.showDialog<bool>(DialogId.dlg07);
    final picked = await ref
        .read(feedbackServiceProvider)
        .showMenu<String>(scrimKey: key, items: const []);
    feedback.showToast(ToastId.tst07);
    final name = ok ?? false ? 'showDialog(' : "showGuSheet($picked)";
    // ignore-hardcode: platform izin penceresi sarmalayıcısı (fixture gerekçesi)
    await showDialog<void>(context: this.context, builder: (_) => Text(name));
  }

  // Aynı adlı yardımcı metot bildirimleri çağrı değildir.
  Future<void> showMenu() async {}

  bool? showDialog(int x) => null;

  List<int> showBottomSheet() => const [];
}

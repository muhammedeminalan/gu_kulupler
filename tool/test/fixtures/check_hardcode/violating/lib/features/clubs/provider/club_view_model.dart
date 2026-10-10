// Fixture: HC12c — ViewModel de FeedbackService kullanır (satır 4 ve 7; barrel'dan görünen ortak rota dahil).
class ClubViewModel {
  Future<bool?> confirm(BuildContext context) =>
      showCupertinoDialog<bool>(context: context, builder: (_) => const SizedBox());

  Future<void> raw(BuildContext context) async {
    await showGuOverlay<void>(context, builder: (_) => const SizedBox());
  }
}

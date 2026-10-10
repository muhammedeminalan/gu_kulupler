// Fixture: HC12c — alan-bilen ortak widget'ta da yasak (satır 4 ve 5: ifade başı, üçlü ifade).
class ClubCta {
  Object? more(BuildContext context, bool open) {
    showGuPopMenu<void>(context, items: const []);
    return open ? showGuDialog<void>(context, builder: (_) => const SizedBox()) : null;
  }
}

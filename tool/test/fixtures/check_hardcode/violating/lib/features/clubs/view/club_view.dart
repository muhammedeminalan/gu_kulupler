// Fixture: HC12c — overlay primitifleri view'dan doğrudan çağrılıyor (satır 6–12).
import 'package:flutter/material.dart';

class ClubView {
  Future<void> open(BuildContext context) async {
    await showGuSheet<void>(context, builder: (_) => const SizedBox());
    final ok = await showGuDialog<bool>(context, builder: (_) => const SizedBox());
    unawaited(showGuPopMenu<String>(context, items: const []));
    await showModalBottomSheet<void>(context: context, builder: (_) => const SizedBox());
    await showDialog<Map<String, int>>(context: context, builder: (_) => const SizedBox());
    if (ok ?? false) showGeneralDialog(context: context, pageBuilder: (_, _, _) => const SizedBox());
    return showMenu(context: context, position: RelativeRect.fill, items: const []);
  }
}

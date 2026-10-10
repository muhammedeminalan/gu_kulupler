import 'dart:async';

import 'package:gu_kulupler/core/bootstrap/app_bootstrap.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/error/app_error_handler.dart';

void main() {
  unawaited(
    runZonedGuarded(
      () => AppBootstrap.run(
        appBuilder: (toastController) =>
            GuApp(toastController: toastController),
      ),
      AppErrorHandler.onZoneError,
    ),
  );
}

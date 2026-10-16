// T-45 (A3-03, S4-01; D-36, W-104) · gizli anahtar dosyaları git'e girmez:
// APNs Auth Key (.p8), PEM / TLS anahtar ve sertifikaları, Functions
// emülatör gizlileri ve GCP IAM'nin varsayılan servis hesabı anahtar adları.
// Firebase istemci yapılandırması gizli değildir ve izlenmeye devam eder.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/design_files.dart';

/// `git check-ignore --no-index` ile yok sayılan yollar ([paths] içinden).
Set<String> _ignored(List<String> paths) {
  final result = Process.runSync('git', [
    'check-ignore',
    '--no-index',
    ...paths,
  ], workingDirectory: repoRoot);
  // 0: en az biri yok sayıldı · 1: hiçbiri · diğer: hata.
  expect(result.exitCode, anyOf(0, 1), reason: '${result.stderr}');
  return {
    for (final line in '${result.stdout}'.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  };
}

void main() {
  group('T-45 · .gitignore gizli anahtarlar', () {
    test(
      'APNs / PEM / servis hesabı / emülatör gizlisi yolları yok sayılır',
      () {
        const secrets = [
          'AuthKey_ABC123.p8',
          'ios/AuthKey_ABC123.p8',
          'key.pem',
          'ios/push.key',
          'apns.cer',
          'functions/.secret.local',
          'functions/.runtimeconfig.json',
          'gu-kulupler-0123abcd4567.json',
          'service-account.json',
          'credentials.json',
          'serviceAccountKey.json',
          'gu-kulupler-firebase-adminsdk-abc12.json',
          '.env',
          'android/key.properties',
          'upload.jks',
        ];
        expect(_ignored(secrets), secrets.toSet());
      },
    );

    test('izlenen yapılandırma ve bağımlılık dosyaları yok sayılmaz', () {
      const tracked = [
        'firebase.json',
        'firebase.rules-test.json',
        'functions/package.json',
        'functions/package-lock.json',
        'firebase/package-lock.json',
        'tool/admin/package.json',
        'tool/admin/package-lock.json',
        'android/app/google-services.json',
        'ios/Runner/GoogleService-Info.plist',
        'lib/firebase_options.dart',
      ];
      expect(_ignored(tracked), isEmpty);
    });

    test('Firebase CLI yerel önbelleği (`.firebase/`) yok sayılır; '
        'hosting sayfaları izlenir', () {
      const cache = '.firebase/hosting.aG9zdGluZy9wdWJsaWM.cache';
      expect(_ignored(const [cache]), {cache});
      expect(
        _ignored(const [
          'hosting/public/index.html',
          'hosting/public/404.html',
        ]),
        isEmpty,
      );
    });
  });
}

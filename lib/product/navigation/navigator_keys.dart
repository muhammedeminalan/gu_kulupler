import 'package:flutter/widgets.dart';

/// Kök gezgin: kabuksuz rotalar ve tüm overlay'ler (sheet / dialog / menü)
/// buraya itilir; böylece alt sekme çubuğunun üstünde dururlar ve geri tuşu
/// önce onları kapatır (PLAN §13.2).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Kulüpler dalının gezgini (dal 0).
final GlobalKey<NavigatorState> clubsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'clubs',
);

/// Etkinlikler dalının gezgini (dal 1).
final GlobalKey<NavigatorState> eventsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'events',
);

/// Bildirimler dalının gezgini (dal 2).
final GlobalKey<NavigatorState> notificationsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'notifications');

/// Admin dalının gezgini (dal 3).
final GlobalKey<NavigatorState> adminNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'admin',
);

/// Profil dalının gezgini (dal 4).
final GlobalKey<NavigatorState> profileNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'profile',
);

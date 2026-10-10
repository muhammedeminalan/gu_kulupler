/// İkon kaydı — `assets/icons/<fileName>.svg` (PLAN §7.11; D-13).
///
/// 130 Lucide ikonu; sıra `design/extracted/registry.json#iconNames` ile
/// aynıdır (`iconGroups`: nav 35, security 15, user 6, content 22, event 17,
/// status 8, chart 5, club 22). Ad kuralı kebab → camelCase, rakam korunur
/// (`share-2` → `share2`, `code-xml` → `codeXml`). Kayıt ↔ dosya birebirliği
/// `test/icons/gu_icons_test.dart` ile iki yönlü doğrulanır.
///
/// SVG'lerin tümü `viewBox="0 0 24 24"`, `stroke="#1D293D"`,
/// `stroke-width="1.75"`, `fill="none"`; renk `GuIcon` içinde
/// `ColorFilter.srcIn` ile verilir, kalınlık 1.75 sabittir (CD-21, K-24).
enum GuIcons {
  // ── nav · gezinme ve genel (35) ──
  home('home'),
  search('search'),
  bell('bell'),
  user('user'),
  users('users'),
  calendar('calendar'),
  layoutGrid('layout-grid'),
  list('list'),
  menu('menu'),
  chevronLeft('chevron-left'),
  chevronRight('chevron-right'),
  chevronDown('chevron-down'),
  chevronUp('chevron-up'),
  arrowLeft('arrow-left'),
  arrowRight('arrow-right'),
  arrowUp('arrow-up'),
  x('x'),
  plus('plus'),
  minus('minus'),
  check('check'),
  checkCheck('check-check'),
  moreVertical('more-vertical'),
  moreHorizontal('more-horizontal'),
  externalLink('external-link'),
  link('link'),
  copy('copy'),
  share2('share-2'),
  download('download'),
  upload('upload'),
  refreshCw('refresh-cw'),
  slidersHorizontal('sliders-horizontal'),
  arrowUpDown('arrow-up-down'),
  settings('settings'),
  logIn('log-in'),
  logOut('log-out'),

  // ── security · güvenlik ve ayarlar (15) ──
  mail('mail'),
  keyRound('key-round'),
  lock('lock'),
  lockOpen('lock-open'),
  eye('eye'),
  eyeOff('eye-off'),
  shield('shield'),
  shieldCheck('shield-check'),
  badgeCheck('badge-check'),
  smartphone('smartphone'),
  languages('languages'),
  globe('globe'),
  moon('moon'),
  sun('sun'),
  monitor('monitor'),

  // ── user · kullanıcı ve rol (6) ──
  userPlus('user-plus'),
  userCheck('user-check'),
  userX('user-x'),
  userCog('user-cog'),
  crown('crown'),
  graduationCap('graduation-cap'),

  // ── content · içerik (22) ──
  heart('heart'),
  messageCircle('message-circle'),
  send('send'),
  bookmark('bookmark'),
  megaphone('megaphone'),
  flag('flag'),
  ban('ban'),
  image('image'),
  images('images'),
  camera('camera'),
  pin('pin'),
  pinOff('pin-off'),
  pencil('pencil'),
  trash2('trash-2'),
  fileText('file-text'),
  scrollText('scroll-text'),
  lifeBuoy('life-buoy'),
  inbox('inbox'),
  history('history'),
  clipboardList('clipboard-list'),
  listChecks('list-checks'),
  sparkles('sparkles'),

  // ── event · etkinlik (17) ──
  calendarPlus('calendar-plus'),
  calendarCheck('calendar-check'),
  calendarX('calendar-x'),
  calendarDays('calendar-days'),
  clock('clock'),
  mapPin('map-pin'),
  navigation('navigation'),
  qrCode('qr-code'),
  scanLine('scan-line'),
  ticket('ticket'),
  hourglass('hourglass'),
  partyPopper('party-popper'),
  flashlight('flashlight'),
  switchCamera('switch-camera'),
  bellRing('bell-ring'),
  bellOff('bell-off'),
  mic('mic'),

  // ── status · durum (8) ──
  circleCheck('circle-check'),
  circleX('circle-x'),
  triangleAlert('triangle-alert'),
  info('info'),
  circleHelp('circle-help'),
  wifiOff('wifi-off'),
  cloudOff('cloud-off'),
  loaderCircle('loader-circle'),

  // ── chart · grafik (5) ──
  chartColumn('chart-column'),
  chartLine('chart-line'),
  chartPie('chart-pie'),
  trendingUp('trending-up'),
  trendingDown('trending-down'),

  // ── club · kulüp kategorileri (22) ──
  codeXml('code-xml'),
  flaskConical('flask-conical'),
  mountain('mountain'),
  drama('drama'),
  heartHandshake('heart-handshake'),
  briefcase('briefcase'),
  gamepad2('gamepad-2'),
  music('music'),
  rocket('rocket'),
  lightbulb('lightbulb'),
  bookOpen('book-open'),
  pickaxe('pickaxe'),
  puzzle('puzzle'),
  palette('palette'),
  trophy('trophy'),
  landmark('landmark'),
  newspaper('newspaper'),
  film('film'),
  tent('tent'),
  usersRound('users-round'),
  cpu('cpu'),
  dumbbell('dumbbell');

  const GuIcons(this.fileName);

  /// `assets/icons` altındaki dosya adı (uzantısız, kebab-case).
  final String fileName;

  /// Kök uygulamanın varlık anahtarı (`assets/icons/<fileName>.svg`).
  String get assetPath => 'assets/icons/$fileName.svg';
}

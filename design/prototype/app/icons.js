/* ===== ICONS ===== single registry (Lucide, ISC). Paths come from the Lucide library at runtime; nothing is hand-drawn. */
(function () {
  const { html, USED_ICONS } = GU;
  const ICON_GROUPS = {
    nav: ['home', 'search', 'bell', 'user', 'users', 'calendar', 'layout-grid', 'list', 'menu', 'chevron-left', 'chevron-right', 'chevron-down', 'chevron-up', 'arrow-left', 'arrow-right', 'arrow-up', 'x', 'plus', 'minus', 'check', 'check-check', 'more-vertical', 'more-horizontal', 'external-link', 'link', 'copy', 'share-2', 'download', 'upload', 'refresh-cw', 'sliders-horizontal', 'arrow-up-down', 'settings', 'log-in', 'log-out'],
    security: ['mail', 'key-round', 'lock', 'lock-open', 'eye', 'eye-off', 'shield', 'shield-check', 'badge-check', 'smartphone', 'languages', 'globe', 'moon', 'sun', 'monitor'],
    user: ['user-plus', 'user-check', 'user-x', 'user-cog', 'crown', 'graduation-cap'],
    content: ['heart', 'message-circle', 'send', 'bookmark', 'megaphone', 'flag', 'ban', 'image', 'images', 'camera', 'pin', 'pin-off', 'pencil', 'trash-2', 'file-text', 'scroll-text', 'life-buoy', 'inbox', 'history', 'clipboard-list', 'list-checks', 'sparkles'],
    event: ['calendar-plus', 'calendar-check', 'calendar-x', 'calendar-days', 'clock', 'map-pin', 'navigation', 'qr-code', 'scan-line', 'ticket', 'hourglass', 'party-popper', 'flashlight', 'switch-camera', 'bell-ring', 'bell-off', 'mic'],
    status: ['circle-check', 'circle-x', 'triangle-alert', 'info', 'circle-help', 'wifi-off', 'cloud-off', 'loader-circle'],
    chart: ['chart-column', 'chart-line', 'chart-pie', 'trending-up', 'trending-down'],
    club: ['code-xml', 'flask-conical', 'mountain', 'drama', 'heart-handshake', 'briefcase', 'gamepad-2', 'music', 'rocket', 'lightbulb', 'book-open', 'pickaxe', 'puzzle', 'palette', 'trophy', 'landmark', 'newspaper', 'film', 'tent', 'users-round', 'cpu', 'dumbbell'],
    extra: ['bar-chart-3-legacy'].filter(() => false), // placeholder group kept empty; new icons are appended via ensureIcon
  };
  const ICON_GROUP_LABELS = { nav: 'Gezinme', security: 'Güvenlik', user: 'Kullanıcı', content: 'İçerik', event: 'Etkinlik', status: 'Durum', chart: 'Grafik', club: 'Kulüp / kategori', extra: 'Ek' };
  const ALIASES = { 'check-circle': 'circle-check', 'x-circle': 'circle-x', 'alert-triangle': 'triangle-alert', 'help-circle': 'circle-help', unlock: 'lock-open', loader: 'loader-circle', 'loader-2': 'loader-circle', 'bar-chart-3': 'chart-column', 'pie-chart': 'chart-pie', 'line-chart': 'chart-line', 'code-2': 'code-xml' };
  const ICON_NAMES = Object.values(ICON_GROUPS).flat();
  const ICONS = {}; // name -> inner svg markup
  const ICON_SOURCE = { lib: null, version: null, ok: false, missing: [] };

  // minimal built-in fallback (used only if the Lucide library cannot be loaded)
  const FALLBACK = {
    x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>', check: '<path d="M20 6 9 17l-5-5"/>', plus: '<path d="M5 12h14"/><path d="M12 5v14"/>', minus: '<path d="M5 12h14"/>',
    'chevron-left': '<path d="m15 18-6-6 6-6"/>', 'chevron-right': '<path d="m9 18 6-6-6-6"/>', 'chevron-down': '<path d="m6 9 6 6 6-6"/>', 'chevron-up': '<path d="m18 15-6-6-6 6"/>',
    'arrow-left': '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>', 'arrow-right': '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>', 'arrow-up': '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>',
    search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>', bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    user: '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>', users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
    calendar: '<path d="M8 2v4"/><path d="M16 2v4"/><rect width="18" height="18" x="3" y="4" rx="2"/><path d="M3 10h18"/>', heart: '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>',
    'more-vertical': '<circle cx="12" cy="12" r="1"/><circle cx="12" cy="5" r="1"/><circle cx="12" cy="19" r="1"/>', 'more-horizontal': '<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>',
    info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>', 'circle-check': '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>', 'circle-x': '<circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>',
    'triangle-alert': '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    eye: '<path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"/><circle cx="12" cy="12" r="3"/>',
    'eye-off': '<path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49"/><path d="M14.084 14.158a3 3 0 0 1-4.242-4.242"/><path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143"/><path d="m2 2 20 20"/>',
    mail: '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>', lock: '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    'map-pin': '<path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/>', clock: '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
    settings: '<circle cx="12" cy="12" r="3"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
  };
  const GENERIC = '<circle cx="12" cy="12" r="9"/><path d="M12 8v4"/><path d="M12 16h.01"/>';

  const pascal = (n) => n.split('-').map((p) => p.charAt(0).toUpperCase() + p.slice(1)).join('');
  function nodeToMarkup(node) {
    // supports both IconNode shapes: ['svg', attrs, children] (older) and [[tag, attrs], ...] (newer)
    const children = Array.isArray(node) && typeof node[0] === 'string' && node[0] === 'svg' ? node[2] : node;
    if (!Array.isArray(children)) return null;
    return children.map(([tag, attrs]) => `<${tag}${Object.entries(attrs || {}).filter(([k]) => k !== 'key').map(([k, v]) => ` ${k}="${v}"`).join('')}/>`).join('');
  }
  function buildFromLucide(lib) {
    const icons = lib.icons || lib; let ok = 0; ICON_SOURCE.missing = [];
    for (const name of ICON_NAMES) {
      const node = icons[pascal(name)] || lib[pascal(name)];
      const m = node ? nodeToMarkup(node) : null;
      if (m) { ICONS[name] = m; ok++; } else { ICON_SOURCE.missing.push(name); if (!ICONS[name]) ICONS[name] = FALLBACK[name] || GENERIC; }
    }
    ICON_SOURCE.ok = ok > ICON_NAMES.length * 0.8; ICON_SOURCE.lib = 'lucide'; ICON_SOURCE.count = ok;
    return ok;
  }
  function buildFallback() { for (const name of ICON_NAMES) ICONS[name] = FALLBACK[name] || GENERIC; ICON_SOURCE.lib = 'fallback'; ICON_SOURCE.ok = false; }
  function initIcons() {
    if (window.lucide) { try { buildFromLucide(window.lucide); return Promise.resolve(true); } catch (e) { console.warn('lucide parse failed', e); } }
    buildFallback();
    return new Promise((resolve) => {
      const s = document.createElement('script'); s.src = 'https://unpkg.com/lucide@0.468.0/dist/umd/lucide.min.js';
      s.onload = () => { try { buildFromLucide(window.lucide); GU.app.refresh(); } catch (e) { } resolve(true); };
      s.onerror = () => resolve(false); document.head.appendChild(s);
    });
  }
  function resolveName(name) { return ALIASES[name] || name; }
  function ensureIcon(name) { name = resolveName(name); if (!ICONS[name]) { if (!ICON_NAMES.includes(name)) { ICON_NAMES.push(name); ICON_GROUPS.extra.push(name); } const lib = window.lucide; const node = lib && (lib.icons || lib)[pascal(name)]; ICONS[name] = (node && nodeToMarkup(node)) || FALLBACK[name] || GENERIC; } return name; }
  function iconSVG(name, { size = 24, stroke = 1.75, color = 'currentColor', cls = '' } = {}) {
    const n = ensureIcon(name);
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round"${cls ? ` class="${cls}"` : ''}>${ICONS[n]}</svg>`;
  }
  function Icon({ name, size = 24, stroke = 1.75, class: cls, style, color, label }) {
    const n = ensureIcon(name); USED_ICONS.add(n);
    return html`<svg width=${size} height=${size} viewBox="0 0 24 24" fill="none" stroke=${color || 'currentColor'} stroke-width=${stroke} stroke-linecap="round" stroke-linejoin="round" class=${cls} style=${style} aria-hidden=${label ? undefined : 'true'} role=${label ? 'img' : undefined} aria-label=${label} dangerouslySetInnerHTML=${{ __html: ICONS[n] }} />`;
  }
  function svgToPng(svgString, size) {
    return new Promise((resolve, reject) => {
      const img = new Image(); const url = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svgString);
      img.onload = () => { try { const c = document.createElement('canvas'); c.width = size; c.height = size; const ctx = c.getContext('2d'); ctx.drawImage(img, 0, 0, size, size); c.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob'))), 'image/png'); } catch (e) { reject(e); } };
      img.onerror = () => reject(new Error('svg load')); img.src = url;
    });
  }
  const flutterIconName = (name) => { const p = pascal(name); return 'LucideIcons.' + p.charAt(0).toLowerCase() + p.slice(1); };
  Object.assign(GU, { ICON_GROUPS, ICON_GROUP_LABELS, ICON_NAMES, ICONS, ALIASES, ICON_SOURCE, initIcons, iconSVG, Icon, svgToPng, ensureIcon, resolveName, flutterIconName, pascal });
})();

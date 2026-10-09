/* ===== COVER_ART ===== generated imagery: CoverArt, Avatar, LogoPlaceholder, illustrations, QR, patterns (no external images) */
(function () {
  const { html, rngFor, hashStr, initials, ICONS, ensureIcon } = GU;
  const PALETTES = {
    red: { id: 'red', name: ['Kırmızı–Krem', 'Red–Cream'], stops: ['#A80824', '#D00A2D', '#F3B8C2'], ink: '#FFFFFF', pattern: 'rgba(255,255,255,.55)' },
    slate: { id: 'slate', name: ['Slate–Lacivert', 'Slate–Navy'], stops: ['#14213A', '#1D293D', '#3F5F8F'], ink: '#FFFFFF', pattern: 'rgba(255,255,255,.45)' },
    bordeaux: { id: 'bordeaux', name: ['Bordo–Kum', 'Bordeaux–Sand'], stops: ['#4A0C19', '#7A1F30', '#D9BC8C'], ink: '#FFFFFF', pattern: 'rgba(255,255,255,.5)' },
  };
  const PATTERNS = ['mountain', 'lines', 'dots', 'waves'];
  const PATTERN_NAMES = { mountain: ['Dağ silüeti', 'Mountain silhouette'], lines: ['Çizgi', 'Lines'], dots: ['Nokta ızgarası', 'Dot grid'], waves: ['Dalga', 'Waves'] };

  function patternMarkup(pattern, rng, color, w, h) {
    if (pattern === 'mountain') {
      const peaks = [];
      for (let layer = 0; layer < 3; layer++) {
        let d = `M0 ${h}`; let x = 0; const base = h * (0.55 + layer * 0.15);
        while (x < w) { const pw = 60 + rng() * 120; const ph = (0.25 + rng() * 0.45) * h * (1 - layer * 0.2); d += ` L${(x + pw / 2).toFixed(1)} ${(base - ph).toFixed(1)} L${(x + pw).toFixed(1)} ${base.toFixed(1)}`; x += pw; }
        d += ` L${w} ${h} Z`; peaks.push(`<path d="${d}" fill="${color}" opacity="${(0.18 - layer * 0.05).toFixed(2)}"/>`);
      }
      return peaks.join('');
    }
    if (pattern === 'lines') { let s = ''; for (let i = -h; i < w + h; i += 22 + Math.floor(rng() * 6)) s += `<line x1="${i}" y1="0" x2="${i + h}" y2="${h}" stroke="${color}" stroke-width="1.5" opacity=".22"/>`; return s; }
    if (pattern === 'dots') { let s = ''; const step = 18; for (let y = 10; y < h; y += step) for (let x = 10; x < w; x += step) { const r = 1.2 + rng() * 1.4; s += `<circle cx="${x}" cy="${y}" r="${r.toFixed(1)}" fill="${color}" opacity=".28"/>`; } return s; }
    // waves
    let s = ''; for (let i = 0; i < 6; i++) { const y = h * (0.3 + i * 0.13); const amp = 8 + rng() * 10; let d = `M0 ${y}`; for (let x = 0; x <= w; x += 40) d += ` Q${x + 10} ${y - amp} ${x + 20} ${y} T${x + 40} ${y}`; s += `<path d="${d}" fill="none" stroke="${color}" stroke-width="1.5" opacity="${(0.3 - i * 0.03).toFixed(2)}"/>`; }
    return s;
  }
  /** Deterministic cover art. Same seed → same output. */
  function coverArtSVG(seed, iconName = 'sparkles', paletteId = 'red', pattern, { w = 640, h = 360 } = {}) {
    const pal = PALETTES[paletteId] || PALETTES.red; const rng = rngFor('cover:' + seed);
    pattern = pattern || PATTERNS[Math.floor(rng() * PATTERNS.length)];
    const angle = Math.floor(rng() * 90) + 15; const gid = 'g' + hashStr(seed + paletteId).toString(36);
    const icon = ICONS[ensureIcon(iconName)] || ''; const k = h / 24 * 0.8; const ix = w - 24 * k * 0.85; const iy = h - 24 * k * 0.9;
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" preserveAspectRatio="xMidYMid slice"><defs><linearGradient id="${gid}" gradientTransform="rotate(${angle})"><stop offset="0" stop-color="${pal.stops[0]}"/><stop offset=".55" stop-color="${pal.stops[1]}"/><stop offset="1" stop-color="${pal.stops[2]}"/></linearGradient></defs><rect width="${w}" height="${h}" fill="url(#${gid})"/>${patternMarkup(pattern, rng, pal.pattern, w, h)}<g transform="translate(${ix.toFixed(1)} ${iy.toFixed(1)}) scale(${k.toFixed(2)})" fill="none" stroke="${pal.ink}" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round" opacity=".12">${icon}</g></svg>`;
  }
  function Cover({ seed, icon, palette, pattern, ratio = '16-9', class: cls, style, children }) {
    const svg = coverArtSVG(seed, icon, palette, pattern);
    return html`<div class=${GU.cx('cover', 'r' + ratio, cls)} style=${style}><div style="position:absolute;inset:0" dangerouslySetInnerHTML=${{ __html: svg }} />${children}</div>`;
  }
  /* avatar */
  function avatarColors(seed) { const hsh = hashStr('av:' + seed); const hue = hsh % 360; const hue2 = (hue + 36) % 360; return [`hsl(${hue} 48% 42%)`, `hsl(${hue2} 55% 32%)`]; }
  function avatarSVG(name, seed, size = 96) { const [a, b] = avatarColors(seed || name); const gid = 'a' + hashStr(seed || name).toString(36); return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 96 96"><defs><linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient></defs><circle cx="48" cy="48" r="48" fill="url(#${gid})"/><text x="48" y="48" dy=".36em" text-anchor="middle" font-family="Montserrat, sans-serif" font-weight="700" font-size="38" fill="#fff">${initials(name)}</text></svg>`; }
  function Avatar({ user, name, seed, size = 40, class: cls, style }) {
    const nm = user ? user.name : name || '?'; const sd = user ? user.avatarSeed || user.id : seed || nm; const [a, b] = avatarColors(sd);
    const fs = Math.round(size * 0.4);
    return html`<span class=${GU.cx('avatar', cls)} style=${{ width: size + 'px', height: size + 'px', fontSize: fs + 'px', background: `linear-gradient(135deg, ${a}, ${b})`, ...(style || {}) }} aria-hidden="true">${initials(nm)}</span>`;
  }
  function AvatarGroup({ users = [], max = 4, size = 28, total }) {
    const shown = users.slice(0, max); const rest = (total != null ? total : users.length) - shown.length;
    return html`<span class="avatar-group">${shown.map((u) => html`<${Avatar} key=${u.id} user=${u} size=${size} />`)}${rest > 0 ? html`<span class="avatar more" style=${{ minWidth: size + 'px', height: size + 'px', padding: '0 6px', fontSize: Math.max(10, Math.round(size * 0.38)) + 'px' }}>+${rest}</span>` : null}</span>`;
  }
  /* logo placeholder (NOT the university's official logo) */
  function logoSVG({ size = 64, variant = 'emblem', dark = false, color = '#D00A2D' } = {}) {
    const emblem = `<circle cx="32" cy="32" r="30" fill="${color}"/><path d="M16 30 32 18l16 12" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="24" cy="38" r="4" fill="#fff"/><circle cx="32" cy="43" r="4" fill="#fff"/><circle cx="40" cy="38" r="4" fill="#fff"/>`;
    const text = dark ? '#F5F5F1' : '#1D293D';
    if (variant === 'emblem') return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 64 64">${emblem}</svg>`;
    if (variant === 'horizontal') return `<svg xmlns="http://www.w3.org/2000/svg" width="${size * 3.6}" height="${size}" viewBox="0 0 230 64"><g>${emblem}</g><text x="76" y="40" font-family="Montserrat, sans-serif" font-weight="700" font-size="24" letter-spacing="1.5" fill="${text}">GÜ Kulüpler</text></svg>`;
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size * 1.6}" height="${size * 1.6}" viewBox="0 0 160 160"><g transform="translate(48 10)">${emblem}</g><text x="80" y="118" text-anchor="middle" font-family="Montserrat, sans-serif" font-weight="700" font-size="20" letter-spacing="1.5" fill="${text}">GÜ Kulüpler</text></svg>`;
  }
  function appIconSVG(size = 1024) { return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#D00A2D"/><path d="M16 31 32 19l16 12" fill="none" stroke="#fff" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/><circle cx="24" cy="39" r="4.2" fill="#fff"/><circle cx="32" cy="44" r="4.2" fill="#fff"/><circle cx="40" cy="39" r="4.2" fill="#fff"/></svg>`; }
  /* Real university logo (provided by the user as app/assets/gu-logo.png). LogoPlaceholder SVG stays available as a fallback / for the Assets page. */
  const LOGO_SRC = 'app/assets/gu-logo.png';
  function Logo({ size = 64, variant = 'emblem', placeholder }) {
    if (placeholder) return html`<span class="logo" style=${{ display: 'inline-flex', lineHeight: 0 }} dangerouslySetInnerHTML=${{ __html: logoSVG({ size, variant, dark: GU.app.theme() === 'dark' }) }} />`;
    const img = html`<img src=${LOGO_SRC} alt="Gümüşhane Üniversitesi" width=${size} height=${size} style=${{ width: size + 'px', height: size + 'px', display: 'block', borderRadius: '50%' }} />`;
    if (variant === 'horizontal') return html`<span class="logo row" style=${{ gap: Math.round(size * 0.25) + 'px', display: 'inline-flex', alignItems: 'center' }}>${img}<span style=${{ font: `700 ${Math.round(size * 0.4)}px Montserrat, sans-serif`, letterSpacing: '.06em', color: 'var(--text-heading)' }}>GÜ Kulüpler</span></span>`;
    if (variant === 'vertical') return html`<span class="logo col" style=${{ gap: Math.round(size * 0.2) + 'px', display: 'inline-flex', alignItems: 'center' }}>${img}<span style=${{ font: `700 ${Math.round(size * 0.28)}px Montserrat, sans-serif`, letterSpacing: '.06em', color: 'var(--text-heading)' }}>GÜ Kulüpler</span></span>`;
    return html`<span class="logo" style=${{ display: 'inline-flex', lineHeight: 0 }}>${img}</span>`;
  }

  /* illustrations — geometric, single tone + red accent */
  const ILLUSTRATIONS = {
    'onb-discover': (b, a) => `<circle cx="80" cy="76" r="34" fill="none" stroke="${b}" stroke-width="4"/><path d="M104 100l22 22" stroke="${b}" stroke-width="6" stroke-linecap="round"/><circle cx="80" cy="76" r="12" fill="${a}"/><circle cx="36" cy="40" r="6" fill="${b}" opacity=".4"/><circle cx="132" cy="44" r="4" fill="${a}" opacity=".6"/><circle cx="40" cy="120" r="5" fill="${b}" opacity=".3"/>`,
    'onb-join': (b, a) => `<rect x="40" y="36" width="80" height="96" rx="12" fill="none" stroke="${b}" stroke-width="4"/><rect x="56" y="56" width="48" height="6" rx="3" fill="${b}" opacity=".5"/><rect x="56" y="72" width="36" height="6" rx="3" fill="${b}" opacity=".5"/><circle cx="106" cy="118" r="18" fill="${a}"/><path d="M98 118l6 6 10-12" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>`,
    'onb-follow': (b, a) => `<path d="M52 108V72a28 28 0 0 1 56 0v36l8 10H44z" fill="none" stroke="${b}" stroke-width="4" stroke-linejoin="round"/><path d="M70 128a10 10 0 0 0 20 0" fill="none" stroke="${b}" stroke-width="4"/><circle cx="110" cy="48" r="12" fill="${a}"/><rect x="118" y="112" width="24" height="24" rx="4" fill="none" stroke="${b}" stroke-width="3"/><rect x="124" y="118" width="12" height="12" fill="${b}" opacity=".6"/>`,
    'empty-clubs': (b, a) => `<circle cx="60" cy="72" r="22" fill="none" stroke="${b}" stroke-width="4"/><circle cx="100" cy="72" r="22" fill="none" stroke="${b}" stroke-width="4"/><circle cx="80" cy="104" r="22" fill="none" stroke="${b}" stroke-width="4"/><circle cx="80" cy="82" r="10" fill="${a}"/>`,
    'empty-events': (b, a) => `<rect x="32" y="44" width="96" height="84" rx="12" fill="none" stroke="${b}" stroke-width="4"/><path d="M32 68h96" stroke="${b}" stroke-width="4"/><path d="M56 36v16M104 36v16" stroke="${b}" stroke-width="4" stroke-linecap="round"/><rect x="48" y="84" width="16" height="16" rx="4" fill="${b}" opacity=".35"/><rect x="72" y="84" width="16" height="16" rx="4" fill="${a}"/><rect x="96" y="84" width="16" height="16" rx="4" fill="${b}" opacity=".35"/>`,
    'empty-notifications': (b, a) => `<path d="M56 100V72a24 24 0 0 1 48 0v28l8 10H48z" fill="none" stroke="${b}" stroke-width="4" stroke-linejoin="round"/><path d="M72 118a8 8 0 0 0 16 0" fill="none" stroke="${b}" stroke-width="4"/><circle cx="104" cy="52" r="8" fill="${a}"/><path d="M30 60q10-10 0-20M130 60q-10-10 0-20" fill="none" stroke="${b}" stroke-width="3" stroke-linecap="round" opacity=".4"/>`,
    'empty-posts': (b, a) => `<rect x="36" y="40" width="88" height="64" rx="12" fill="none" stroke="${b}" stroke-width="4"/><rect x="52" y="58" width="56" height="6" rx="3" fill="${b}" opacity=".5"/><rect x="52" y="74" width="40" height="6" rx="3" fill="${b}" opacity=".5"/><path d="M60 104v16l16-16" fill="none" stroke="${b}" stroke-width="4" stroke-linejoin="round"/><circle cx="116" cy="44" r="10" fill="${a}"/>`,
    'empty-applications': (b, a) => `<rect x="44" y="32" width="72" height="96" rx="10" fill="none" stroke="${b}" stroke-width="4"/><rect x="60" y="24" width="40" height="16" rx="6" fill="${b}" opacity=".5"/><rect x="60" y="60" width="40" height="6" rx="3" fill="${b}" opacity=".4"/><rect x="60" y="76" width="28" height="6" rx="3" fill="${b}" opacity=".4"/><circle cx="104" cy="112" r="16" fill="${a}"/><path d="M104 104v10l6 4" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>`,
    error: (b, a) => `<path d="M80 36l48 84H32z" fill="none" stroke="${b}" stroke-width="4" stroke-linejoin="round"/><rect x="76" y="68" width="8" height="28" rx="4" fill="${a}"/><circle cx="80" cy="106" r="5" fill="${a}"/>`,
    offline: (b, a) => `<path d="M52 112h56a20 20 0 0 0 2-40 30 30 0 0 0-58 8 16 16 0 0 0 0 32z" fill="none" stroke="${b}" stroke-width="4" stroke-linejoin="round"/><path d="M40 40l80 80" stroke="${a}" stroke-width="5" stroke-linecap="round"/>`,
    'email-verify': (b, a) => `<rect x="32" y="52" width="96" height="64" rx="10" fill="none" stroke="${b}" stroke-width="4"/><path d="M32 60l48 32 48-32" fill="none" stroke="${b}" stroke-width="4" stroke-linejoin="round"/><circle cx="124" cy="52" r="14" fill="${a}"/><path d="M118 52l4 4 8-8" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`,
    locked: (b, a) => `<rect x="44" y="72" width="72" height="56" rx="10" fill="none" stroke="${b}" stroke-width="4"/><path d="M58 72V58a22 22 0 0 1 44 0v14" fill="none" stroke="${b}" stroke-width="4"/><circle cx="80" cy="98" r="7" fill="${a}"/><rect x="77" y="100" width="6" height="12" rx="3" fill="${a}"/>`,
  };
  const ILLUSTRATION_NAMES = Object.keys(ILLUSTRATIONS);
  function illustrationSVG(name, { size = 160, base = 'currentColor', accent = '#D00A2D' } = {}) { const fn = ILLUSTRATIONS[name] || ILLUSTRATIONS.error; return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 160 160" fill="none">${fn(base, accent)}</svg>`; }
  function Illustration({ name, size = 140 }) { return html`<span class="ill" style=${{ display: 'inline-flex', color: 'var(--text-disabled)', lineHeight: 0 }} aria-hidden="true" dangerouslySetInnerHTML=${{ __html: illustrationSVG(name, { size }) }} />`; }

  /* deterministic pseudo-QR (29×29, three finder patterns) */
  function qrMatrix(seed) {
    const n = 29; const rng = rngFor('qr:' + seed); const m = Array.from({ length: n }, () => Array(n).fill(0));
    const finder = (ox, oy) => { for (let y = 0; y < 7; y++) for (let x = 0; x < 7; x++) { const edge = x === 0 || y === 0 || x === 6 || y === 6; const core = x >= 2 && x <= 4 && y >= 2 && y <= 4; m[oy + y][ox + x] = edge || core ? 1 : 0; } };
    finder(0, 0); finder(n - 7, 0); finder(0, n - 7);
    for (let i = 8; i < n - 8; i++) { m[6][i] = i % 2 === 0 ? 1 : 0; m[i][6] = i % 2 === 0 ? 1 : 0; }
    const reserved = (x, y) => (x < 8 && y < 8) || (x >= n - 8 && y < 8) || (x < 8 && y >= n - 8) || x === 6 || y === 6;
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) if (!reserved(x, y)) m[y][x] = rng() < 0.46 ? 1 : 0;
    // alignment pattern
    const ax = n - 9, ay = n - 9; for (let y = -2; y <= 2; y++) for (let x = -2; x <= 2; x++) { const edge = Math.abs(x) === 2 || Math.abs(y) === 2; m[ay + y][ax + x] = edge || (x === 0 && y === 0) ? 1 : 0; }
    return m;
  }
  function qrSVG(seed, size = 220, color = '#101828') { const m = qrMatrix(seed); const n = m.length; let rects = ''; for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) if (m[y][x]) rects += `<rect x="${x}" y="${y}" width="1" height="1"/>`; return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${n} ${n}" shape-rendering="crispEdges"><rect width="${n}" height="${n}" fill="#fff"/><g fill="${color}">${rects}</g></svg>`; }
  function ticketCode(seed) { const rng = rngFor('code:' + seed); const A = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; const grp = () => Array.from({ length: 4 }, () => A[Math.floor(rng() * A.length)]).join(''); return `GU-${grp()}-${grp()}`; }
  function patternSVG(pattern, color = '#1D293D', w = 640, h = 360) { return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}"><rect width="${w}" height="${h}" fill="#FAF9F6"/>${patternMarkup(pattern, rngFor('pattern:' + pattern), color, w, h)}</svg>`; }

  Object.assign(GU, { LOGO_SRC, PALETTES, PATTERNS, PATTERN_NAMES, coverArtSVG, Cover, avatarColors, avatarSVG, Avatar, AvatarGroup, logoSVG, appIconSVG, Logo, ILLUSTRATIONS, ILLUSTRATION_NAMES, illustrationSVG, Illustration, qrMatrix, qrSVG, ticketCode, patternSVG });
})();

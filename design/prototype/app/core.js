/* ===== CORE ===== tokens · css · utils · I18N engine · STORE · ROUTER · overlays · action registry */
(function () {
  const { h, render, Fragment } = preact;
  const { useState, useEffect, useRef, useMemo, useLayoutEffect, useCallback } = preactHooks;
  const html = htm.bind(h);

  const APP_NAME = 'GÜ Kulüpler';
  const APP_VERSION = '1.0.0';
  const ALLOWED_EMAIL_DOMAINS = ['ogr.gumushane.edu.tr', 'gumushane.edu.tr'];
  const DEMO_PASSWORD = 'Demo1234!';
  const STORAGE_KEY = 'gu-kulupler-state-v1';

  /* ---------- tokens ---------- */
  const COLORS = {
    'brand.primary': ['#D00A2D', '#D00A2D'], 'brand.primaryText': ['#D00A2D', '#F2536C'], 'brand.primaryPressed': ['#A80824', '#B8082A'],
    'brand.onPrimary': ['#FFFFFF', '#FFFFFF'], 'brand.primaryContainer': ['#FCE8EC', '#3A0C16'], 'brand.onPrimaryContainer': ['#7A0619', '#FFD9E0'],
    'bg.canvas': ['#FAF9F6', '#17191C'], 'bg.surface': ['#FFFFFF', '#1E2024'], 'bg.surfaceMuted': ['#F1F5F9', '#292E35'], 'bg.surfaceRaised': ['#FFFFFF', '#23272E'],
    'border.default': ['#E2E8F0', '#39414B'], 'border.soft': ['#EEF1F5', '#303740'],
    'text.primary': ['#101828', '#F1F1ED'], 'text.heading': ['#1D293D', '#F5F5F1'], 'text.secondary': ['#45556C', '#C6CCD4'], 'text.muted': ['#62748E', '#AEB5BF'], 'text.disabled': ['#A3AEBF', '#6B7480'],
    'state.success': ['#15803D', '#4ADE80'], 'state.successContainer': ['#DCFCE7', '#0F2E1A'], 'state.warning': ['#B45309', '#FBBF24'], 'state.warningContainer': ['#FEF3C7', '#3A2A0A'],
    'state.danger': ['#B42318', '#FF7A70'], 'state.dangerContainer': ['#FEE4E2', '#3B1512'], 'state.info': ['#1D5FAD', '#7DB7F2'], 'state.infoContainer': ['#E3F0FC', '#0F2538'],
    'overlay.scrim': ['rgba(16,24,40,.48)', 'rgba(0,0,0,.60)'], 'focus.ring': ['#D00A2D', '#F2536C'],
  };
  const COLOR_USAGE = {
    'brand.primary': 'Dolu butonlar, aktif sekme göstergesi, rozetler', 'brand.primaryText': 'Link, ikon, vurgulu metin', 'brand.primaryPressed': 'Basılı durum', 'brand.onPrimary': 'Kırmızı üstü metin/ikon',
    'brand.primaryContainer': 'Tonal arka plan', 'brand.onPrimaryContainer': 'Tonal üstü metin', 'bg.canvas': 'Sayfa zemini', 'bg.surface': 'Kart yüzeyi', 'bg.surfaceMuted': 'Girdi, çip, ikincil alan', 'bg.surfaceRaised': 'Sheet, dialog',
    'border.default': 'Kenarlık', 'border.soft': 'Ayraç', 'text.primary': 'Gövde', 'text.heading': 'Başlık', 'text.secondary': 'İkincil', 'text.muted': 'Yardımcı, zaman damgası', 'text.disabled': 'Devre dışı',
    'state.success': 'Onaylandı, katıldı', 'state.successContainer': 'Başarı zemini', 'state.warning': 'Beklemede, dikkat', 'state.warningContainer': 'Uyarı zemini', 'state.danger': 'Hata, silme', 'state.dangerContainer': 'Hata zemini',
    'state.info': 'Bilgi', 'state.infoContainer': 'Bilgi zemini', 'overlay.scrim': 'Sheet/dialog arkası', 'focus.ring': '2 px halka, 2 px offset',
  };
  const cssVar = (token) => '--' + token.replace(/\./g, '-').replace(/([A-Z])/g, (m) => '-' + m.toLowerCase());
  const TYPE_SCALE = [
    { id: 'display', name: 'Display', font: 'Montserrat', size: 28, line: 34, weight: 700, note: 'Karşılama, hero başlıklar' },
    { id: 'titleL', name: 'Title L', font: 'Montserrat', size: 22, line: 28, weight: 700, note: 'Ekran başlığı' },
    { id: 'titleM', name: 'Title M', font: 'Montserrat', size: 18, line: 24, weight: 600, note: 'Bölüm başlığı' },
    { id: 'titleS', name: 'Title S', font: 'Montserrat', size: 16, line: 22, weight: 600, note: 'Kart başlığı' },
    { id: 'bodyL', name: 'Body L', font: 'Inter', size: 16, line: 24, weight: 400, note: 'Uzun metin' },
    { id: 'bodyM', name: 'Body M', font: 'Inter', size: 15, line: 22, weight: 400, note: 'Varsayılan gövde' },
    { id: 'bodyS', name: 'Body S', font: 'Inter', size: 13, line: 18, weight: 400, note: 'İkincil metin' },
    { id: 'labelL', name: 'Label L', font: 'Inter', size: 14, line: 20, weight: 600, note: 'Buton' },
    { id: 'labelM', name: 'Label M', font: 'Inter', size: 12, line: 16, weight: 600, note: 'Çip, rozet' },
    { id: 'caption', name: 'Caption', font: 'Inter', size: 12, line: 16, weight: 500, note: 'Zaman, yardımcı' },
    { id: 'overline', name: 'Overline', font: 'Montserrat', size: 11, line: 14, weight: 600, note: 'Bölüm üst etiketi', letterSpacing: '0.08em', uppercase: true },
  ];
  const SPACING = [4, 8, 12, 16, 20, 24, 32, 40, 48];
  const RADIUS = { sm: 12, md: 16, lg: 20, xl: 28, full: 999 };
  const SHADOWS = { e0: 'none', e1: '0 1px 2px rgba(16,24,40,.06), 0 1px 3px rgba(16,24,40,.08)', e2: '0 4px 12px rgba(16,24,40,.10)', e3: '0 -8px 32px rgba(16,24,40,.16)' };
  const MOTION = { fast: 120, base: 200, slow: 320, easeStandard: 'cubic-bezier(.2,0,0,1)', easeEmphasized: 'cubic-bezier(.3,0,0,1)' };
  const TOKENS = { COLORS, COLOR_USAGE, TYPE_SCALE, SPACING, RADIUS, SHADOWS, MOTION };

  function tokensCSS() {
    const l = Object.entries(COLORS).map(([k, v]) => `  ${cssVar(k)}: ${v[0]};`).join('\n');
    const d = Object.entries(COLORS).map(([k, v]) => `  ${cssVar(k)}: ${v[1]};`).join('\n');
    const r = Object.entries(RADIUS).map(([k, v]) => `  --r-${k}: ${v}px;`).join('\n');
    const s = Object.entries(SHADOWS).map(([k, v]) => `  --${k}: ${v};`).join('\n');
    const m = `  --motion-fast: ${MOTION.fast}ms;\n  --motion-base: ${MOTION.base}ms;\n  --motion-slow: ${MOTION.slow}ms;\n  --ease-standard: ${MOTION.easeStandard};\n  --ease-emphasized: ${MOTION.easeEmphasized};`;
    return `/* GÜ Kulüpler — design tokens (generated) */\n:root, [data-theme="light"] {\n${l}\n${r}\n${s}\n${m}\n}\n[data-theme="dark"] {\n${d}\n  --e1: none; --e2: none; --e3: none;\n}\n`;
  }

  /* ---------- component css ---------- */
  const TYPE_CSS = TYPE_SCALE.map((s) => `.t-${s.id.replace(/([A-Z])/g, '-$1').toLowerCase()}{font:${s.weight} calc(${s.size}px*var(--ts))/${(s.line / s.size).toFixed(3)} ${s.font},sans-serif;${s.letterSpacing ? `letter-spacing:${s.letterSpacing};` : ''}${s.uppercase ? 'text-transform:uppercase;' : ''}${/title|display/.test(s.id) ? 'color:var(--text-heading);' : ''}${s.id === 'caption' || s.id === 'overline' ? 'color:var(--text-muted);' : ''}}`).join('\n');

  const CSS = `
${tokensCSS().replace(/:root, \[data-theme="light"\]/, '.gu-root[data-theme="light"]').replace(/\[data-theme="dark"\]/, '.gu-root[data-theme="dark"]')}
.gu-root{--ts:1;--safe-top:54px;--safe-bottom:28px;--nav-h:84px;font-family:Inter,system-ui,sans-serif;color:var(--text-primary);background:var(--bg-canvas);-webkit-font-smoothing:antialiased;text-wrap:pretty;font-size:calc(15px*var(--ts));line-height:1.47}
.gu-root *,.gu-root *::before,.gu-root *::after{box-sizing:border-box}
.gu-root :where(button){font:inherit;color:inherit;background:none;border:0;padding:0;margin:0;cursor:pointer;text-align:inherit;-webkit-tap-highlight-color:transparent}
.gu-root :where(input,textarea,select){font:inherit;color:inherit}
.gu-root a{color:var(--brand-primary-text);text-decoration:none}.gu-root a:hover{color:var(--brand-primary-pressed);text-decoration:underline}
.gu-root :focus{outline:none}.gu-root :focus-visible{outline:2px solid var(--focus-ring);outline-offset:2px;border-radius:6px}
.gu-root h1,.gu-root h2,.gu-root h3,.gu-root h4,.gu-root p{margin:0}
.gu-root ul,.gu-root ol{margin:0;padding-left:20px}
.gu-root svg{display:block;flex:none}
.gu-root [hidden]{display:none!important}
${TYPE_CSS}
.c-sec{color:var(--text-secondary)}.c-muted{color:var(--text-muted)}.c-brand{color:var(--brand-primary-text)}.c-danger{color:var(--state-danger)}.c-success{color:var(--state-success)}.c-warning{color:var(--state-warning)}.c-info{color:var(--state-info)}.c-heading{color:var(--text-heading)}.c-disabled{color:var(--text-disabled)}.c-primary{color:var(--text-primary)}
.tnum{font-variant-numeric:tabular-nums}.bold{font-weight:600}.center{text-align:center}.right{text-align:right}
.row{display:flex;align-items:center;gap:8px}.col{display:flex;flex-direction:column}.between{justify-content:space-between}.start{align-items:flex-start}.end{justify-content:flex-end}.wrap{flex-wrap:wrap}.flex1{flex:1;min-width:0}.rel{position:relative}.hidden-vis{visibility:hidden}
.gap2{gap:2px}.gap4{gap:4px}.gap6{gap:6px}.gap8{gap:8px}.gap12{gap:12px}.gap16{gap:16px}.gap20{gap:20px}.gap24{gap:24px}
.p16{padding:16px}.px16{padding-left:16px;padding-right:16px}.py8{padding-top:8px;padding-bottom:8px}.py12{padding-top:12px;padding-bottom:12px}.py16{padding-top:16px;padding-bottom:16px}.pb16{padding-bottom:16px}.pb24{padding-bottom:24px}.pt8{padding-top:8px}.pt16{padding-top:16px}.p12{padding:12px}.p20{padding:20px}
.mt4{margin-top:4px}.mt8{margin-top:8px}.mt12{margin-top:12px}.mt16{margin-top:16px}.mt24{margin-top:24px}.mb8{margin-bottom:8px}.mb12{margin-bottom:12px}.mb16{margin-bottom:16px}.mb24{margin-bottom:24px}.ml-auto{margin-left:auto}
.ellipsis{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.clamp1{display:-webkit-box;-webkit-line-clamp:1;-webkit-box-orient:vertical;overflow:hidden}.clamp2{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}.clamp3{display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}.clamp5{display:-webkit-box;-webkit-line-clamp:5;-webkit-box-orient:vertical;overflow:hidden}.prewrap{white-space:pre-wrap}.break{overflow-wrap:anywhere}
.hscroll{display:flex;gap:8px;overflow-x:auto;padding:3px 16px;scrollbar-width:none;scroll-snap-type:x proximity}.hscroll::-webkit-scrollbar{display:none}.hscroll>*{flex:none;scroll-snap-align:start}
.divider{height:1px;background:var(--border-soft);margin:0}.spacer{flex:1}
.hit{position:relative}.hit::after{content:"";position:absolute;inset:-6px}
.section-title{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:0 16px;margin:24px 0 12px}
.section-title:first-child{margin-top:8px}
.grid2{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.grid3{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
/* device */
.device{position:relative;width:390px;height:844px;overflow:hidden;background:var(--bg-canvas);color:var(--text-primary);isolation:isolate}
.device.is-fluid{width:100%;height:100%}
.statusbar{position:absolute;top:0;left:0;right:0;height:var(--safe-top);display:flex;justify-content:space-between;align-items:flex-start;padding:16px 28px 0 32px;font:600 15px/1 Inter,sans-serif;color:var(--text-heading);z-index:60;pointer-events:none}
.statusbar.on-dark{color:#fff}
.island{position:absolute;top:11px;left:50%;transform:translateX(-50%);width:122px;height:35px;border-radius:20px;background:#000;z-index:61;pointer-events:none}
.homebar{position:absolute;bottom:8px;left:50%;transform:translateX(-50%);width:134px;height:5px;border-radius:3px;background:var(--text-heading);opacity:.85;z-index:62;pointer-events:none}
.homebar.on-dark{background:#fff}
.screen{position:absolute;inset:0;display:flex;flex-direction:column;background:var(--bg-canvas);padding-top:var(--safe-top)}
.screen.has-nav{bottom:var(--nav-h)}
.screen.anim-push{animation:pushIn var(--motion-base) var(--ease-standard)}.screen.anim-pop{animation:popIn var(--motion-base) var(--ease-standard)}.screen.anim-fade{animation:fadeIn var(--motion-base) var(--ease-standard)}
.screen.full-bleed{padding-top:0}
.screen-scroll{flex:1;min-height:0;overflow-y:auto;overscroll-behavior:contain;scrollbar-width:none;padding-bottom:calc(var(--safe-bottom) + 8px)}
.screen-scroll::-webkit-scrollbar{display:none}
.screen-scroll.no-safe{padding-bottom:0}
/* app bar */
.appbar{display:flex;align-items:center;gap:4px;padding:4px 8px;min-height:56px;flex:none;background:var(--bg-canvas);position:relative;z-index:5}
.appbar.is-surface{background:var(--bg-surface);border-bottom:1px solid var(--border-soft)}
.appbar-title{flex:1;min-width:0;padding:0 8px}
.appbar-large{padding:8px 16px 12px}
.appbar-large .t-title-l{flex:1}
/* bottom nav */
.bottomnav{position:absolute;left:0;right:0;bottom:0;height:var(--nav-h);display:flex;border-top:1px solid var(--border-soft);background:var(--bg-surface);padding-bottom:var(--safe-bottom);z-index:50}
.bottomnav>button{flex:1;min-width:0;min-height:56px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;position:relative;color:var(--text-muted);font:600 calc(11px*var(--ts))/1.2 Inter,sans-serif;transition:color var(--motion-fast)}
.bottomnav>button[aria-current="page"]{color:var(--brand-primary-text)}
.bottomnav>button[aria-current="page"]::before{content:"";position:absolute;top:0;left:50%;transform:translateX(-50%);width:28px;height:3px;border-radius:0 0 3px 3px;background:var(--brand-primary)}
.nav-badge{position:absolute;top:6px;left:calc(50% + 4px);min-width:18px;height:18px;padding:0 5px;border-radius:9px;background:var(--brand-primary);color:#fff;font:700 11px/18px Inter,sans-serif;text-align:center;border:2px solid var(--bg-surface);box-sizing:content-box}
/* buttons */
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;border-radius:var(--r-sm);font:600 calc(14px*var(--ts))/1.3 Inter,sans-serif;min-height:48px;padding:0 20px;position:relative;transition:background var(--motion-fast),color var(--motion-fast),transform var(--motion-fast),box-shadow var(--motion-fast);white-space:nowrap;flex:none;user-select:none}
.btn:active:not([aria-disabled="true"]),.btn.is-pressed{transform:scale(.98)}
.btn-sm{min-height:40px;padding:0 14px;font-size:calc(13px*var(--ts))}.btn-lg{min-height:56px;padding:0 24px;font-size:calc(16px*var(--ts))}
.btn-primary{background:var(--brand-primary);color:var(--brand-on-primary)}.btn-primary:hover,.btn-primary.is-hover{background:var(--brand-primary-pressed)}.btn-primary.is-pressed{background:var(--brand-primary-pressed)}
.btn-tonal{background:var(--brand-primary-container);color:var(--brand-on-primary-container)}.btn-tonal:hover,.btn-tonal.is-hover{filter:brightness(.96)}
.btn-outline{border:1px solid var(--border-default);color:var(--text-heading);background:var(--bg-surface)}.btn-outline:hover,.btn-outline.is-hover{background:var(--bg-surface-muted)}
.btn-text{color:var(--brand-primary-text);padding:0 12px;min-height:44px}.btn-text:hover,.btn-text.is-hover{background:var(--brand-primary-container)}
.btn-danger-outline{border:1px solid var(--state-danger);color:var(--state-danger);background:transparent}.btn-danger-outline:hover,.btn-danger-outline.is-hover{background:var(--state-danger-container)}
.btn-danger{background:var(--state-danger);color:#fff}.btn-danger:hover,.btn-danger.is-hover{filter:brightness(.92)}
.btn-ghost{color:var(--text-heading);padding:0 12px}.btn-ghost:hover{background:var(--bg-surface-muted)}
.btn[aria-disabled="true"],.btn.is-disabled{opacity:.5;cursor:not-allowed}
.btn.is-focus{outline:2px solid var(--focus-ring);outline-offset:2px}
.btn-full{width:100%}
.btn.is-loading>*:not(.spinner){visibility:hidden}.btn .spinner{position:absolute;left:50%;top:50%;margin:-10px 0 0 -10px}
.spinner{width:20px;height:20px;border-radius:50%;border:2.5px solid currentColor;border-right-color:transparent;animation:spin .8s linear infinite}
.iconbtn{width:48px;height:48px;display:inline-flex;align-items:center;justify-content:center;border-radius:999px;color:var(--text-heading);position:relative;flex:none;transition:background var(--motion-fast)}
.iconbtn:hover{background:var(--bg-surface-muted)}.iconbtn.on-cover{color:#fff;background:rgba(0,0,0,.28);backdrop-filter:blur(6px)}.iconbtn.on-cover:hover{background:rgba(0,0,0,.4)}
.iconbtn.is-sm{width:40px;height:40px}.iconbtn.is-brand{color:var(--brand-primary-text)}.iconbtn[aria-disabled="true"]{opacity:.45}
.iconbtn .dot-badge{position:absolute;top:8px;right:8px;min-width:18px;height:18px;padding:0 5px;border-radius:9px;background:var(--brand-primary);color:#fff;font:700 11px/18px Inter,sans-serif;text-align:center}
.fab{position:absolute;right:16px;bottom:calc(var(--safe-bottom) + 16px);height:56px;padding:0 20px 0 16px;border-radius:16px;background:var(--brand-primary);color:#fff;display:flex;align-items:center;gap:8px;font:600 calc(14px*var(--ts)) Inter,sans-serif;box-shadow:var(--e2);z-index:20}
.gu-root[data-theme="dark"] .fab{box-shadow:0 4px 16px rgba(0,0,0,.4)}
/* inputs */
.field{display:flex;flex-direction:column;gap:6px;min-width:0}
.field-label{font:600 calc(12px*var(--ts))/1.33 Inter,sans-serif;color:var(--text-secondary);display:flex;justify-content:space-between;gap:8px}
.input{display:flex;align-items:center;gap:8px;min-height:48px;padding:0 14px;border-radius:var(--r-sm);background:var(--bg-surface-muted);border:1px solid transparent;transition:border-color var(--motion-fast),background var(--motion-fast);color:var(--text-primary)}
.input:focus-within,.input.is-focus{border-color:var(--brand-primary-text);background:var(--bg-surface)}
.input.is-error{border-color:var(--state-danger)}.input.is-disabled{opacity:.6}.input.is-readonly{background:transparent;border-color:var(--border-default)}
.input input,.input textarea{flex:1;min-width:0;background:none;border:0;outline:none;padding:0;font:400 calc(15px*var(--ts))/1.47 Inter,sans-serif;color:var(--text-primary)}
.input input::placeholder,.input textarea::placeholder{color:var(--text-muted)}
.input input:focus-visible,.input textarea:focus-visible{outline:none}
.input.is-multiline{align-items:flex-start;padding:12px 14px}.input textarea{resize:none;min-height:88px;line-height:1.47}
.input .in-icon{color:var(--text-muted)}
.field-help{font:500 calc(12px*var(--ts))/1.33 Inter,sans-serif;color:var(--text-muted);display:flex;gap:4px;align-items:flex-start}.field-help.is-error{color:var(--state-danger)}
.field-counter{font:500 calc(12px*var(--ts)) Inter,sans-serif;color:var(--text-muted);font-variant-numeric:tabular-nums}.field-counter.is-over{color:var(--state-danger)}
.picker{display:flex;align-items:center;gap:8px;min-height:48px;padding:0 14px;border-radius:var(--r-sm);background:var(--bg-surface-muted);width:100%;text-align:left;border:1px solid transparent}
.picker .ph{color:var(--text-muted)}.picker.is-error{border-color:var(--state-danger)}
/* chips */
.chip{display:inline-flex;align-items:center;gap:6px;min-height:38px;padding:0 14px;border-radius:10px;border:1px solid var(--border-default);background:var(--bg-surface);font:600 calc(13px*var(--ts))/1.33 Inter,sans-serif;color:var(--text-primary);white-space:nowrap;position:relative;transition:background var(--motion-fast),border-color var(--motion-fast),color var(--motion-fast);flex:none}
.gu-root[data-theme="dark"] .chip{background:var(--bg-surface-muted);border-color:#4A5362;color:var(--text-primary)}
.chip svg{color:var(--text-muted)}
.chip::after{content:"";position:absolute;inset:-6px}
.chip:hover{background:var(--bg-surface-muted)}
.chip.is-selected{background:var(--brand-primary-container);border-color:var(--brand-primary);color:var(--brand-on-primary-container)}.chip.is-selected svg{color:var(--brand-primary-text)}
.gu-root[data-theme="dark"] .chip.is-selected{background:var(--brand-primary);border-color:var(--brand-primary);color:#fff}.gu-root[data-theme="dark"] .chip.is-selected svg{color:#fff}
.gu-root[data-theme="dark"] .chip.is-selected .chip-count{background:#fff;color:var(--brand-primary)}
.chip.is-input{background:var(--bg-surface-muted);border-color:transparent}
.chip[aria-disabled="true"]{opacity:.5}
.chip .chip-count{min-width:18px;height:18px;padding:0 5px;border-radius:9px;background:var(--brand-primary);color:#fff;font:700 11px/18px Inter,sans-serif;text-align:center}
/* badges */
.badge{display:inline-flex;align-items:center;gap:4px;height:22px;padding:0 8px;border-radius:999px;font:600 calc(12px*var(--ts))/1 Inter,sans-serif;white-space:nowrap;flex:none}
.badge-president{background:var(--brand-primary-container);color:var(--brand-on-primary-container)}
.badge-board{background:var(--bg-surface-muted);color:var(--text-heading);border:1px solid var(--border-default)}
.badge-advisor{background:var(--state-warning-container);color:var(--state-warning)}
.badge-member{background:var(--bg-surface-muted);color:var(--text-secondary)}
.badge-superadmin{background:var(--text-heading);color:var(--bg-surface)}
.badge-pending{background:var(--state-warning-container);color:var(--state-warning)}
.badge-success{background:var(--state-success-container);color:var(--state-success)}
.badge-danger{background:var(--state-danger-container);color:var(--state-danger)}
.badge-info{background:var(--state-info-container);color:var(--state-info)}
.badge-full,.badge-neutral{background:var(--bg-surface-muted);color:var(--text-muted)}
.badge-brand{background:var(--brand-primary);color:#fff}
.badge-count{min-width:20px;height:20px;padding:0 6px;border-radius:10px;background:var(--brand-primary);color:#fff;font:700 11px/20px Inter,sans-serif;text-align:center;display:inline-block}
.dot{width:8px;height:8px;border-radius:50%;background:var(--brand-primary);flex:none;display:inline-block}
/* cards */
.card{background:var(--bg-surface);border-radius:var(--r-lg);border:1px solid var(--border-soft);box-shadow:var(--e1);overflow:hidden;position:relative}
.gu-root[data-theme="dark"] .card{border-color:var(--border-default)}
.card.is-muted{background:var(--bg-surface-muted);box-shadow:none;border-color:transparent}
.card.is-tappable{cursor:pointer;transition:transform var(--motion-fast),box-shadow var(--motion-fast)}.card.is-tappable:active{transform:scale(.99)}
.card-body{padding:16px}
.card.is-highlight{animation:highlight 1.5s var(--ease-standard)}
.cover{position:relative;overflow:hidden;background:var(--bg-surface-muted)}.cover svg{width:100%;height:100%;display:block}.cover.r16-9{aspect-ratio:16/9}.cover.r3-2{aspect-ratio:3/2}.cover.r1-1{aspect-ratio:1}
/* list tile */
.tile{display:flex;align-items:center;gap:12px;min-height:56px;padding:8px 16px;width:100%;text-align:left;color:inherit;position:relative}
.tile:hover{background:var(--bg-surface-muted)}.tile.is-plain:hover{background:transparent}.tile-text{flex:1;min-width:0}.tile .trailing{flex:none;color:var(--text-muted);display:flex;align-items:center;gap:4px}
.tile.is-danger{color:var(--state-danger)}.tile[aria-disabled="true"]{opacity:.5}
.tile.in-card{padding:10px 16px}
.group-head{position:sticky;top:0;z-index:2;background:var(--bg-canvas);padding:12px 16px 6px;display:flex;justify-content:space-between;align-items:center}
/* avatar */
.avatar{border-radius:50%;display:inline-flex;align-items:center;justify-content:center;color:#fff;font:700 1em Montserrat,sans-serif;flex:none;overflow:hidden;position:relative;letter-spacing:.02em}
.avatar-group{display:flex;align-items:center}.avatar-group .avatar{border:2px solid var(--bg-surface);margin-left:-8px}.avatar-group .avatar:first-child{margin-left:0}.avatar-group .more{margin-left:-8px;border:2px solid var(--bg-surface);background:var(--bg-surface-muted);color:var(--text-secondary);font:600 11px Inter,sans-serif}
/* segmented / tabs */
.seg{display:flex;background:var(--bg-surface-muted);border-radius:var(--r-sm);padding:3px;gap:2px}
.seg>button{flex:1;min-width:0;min-height:40px;border-radius:10px;font:600 calc(13px*var(--ts))/1.2 Inter,sans-serif;color:var(--text-secondary);padding:0 8px;transition:background var(--motion-fast),color var(--motion-fast);display:flex;align-items:center;justify-content:center;gap:6px}
.seg>button[aria-selected="true"]{background:var(--bg-surface);color:var(--text-heading);box-shadow:var(--e1)}
.gu-root[data-theme="dark"] .seg>button[aria-selected="true"]{background:var(--bg-surface-raised);border:1px solid var(--border-default)}
.tabs{display:flex;border-bottom:1px solid var(--border-soft);background:var(--bg-canvas);flex:none}
.tabs.is-sticky{position:sticky;top:0;z-index:4}
.tabs>button{flex:1;min-width:0;min-height:48px;font:600 calc(14px*var(--ts))/1.2 Inter,sans-serif;color:var(--text-muted);position:relative;padding:0 8px;display:flex;align-items:center;justify-content:center;gap:6px;transition:color var(--motion-fast)}
.tabs>button[aria-selected="true"]{color:var(--brand-primary-text)}
.tabs>button[aria-selected="true"]::after{content:"";position:absolute;left:16px;right:16px;bottom:-1px;height:2px;border-radius:2px 2px 0 0;background:var(--brand-primary)}
.tabs.is-scroll{overflow-x:auto;scrollbar-width:none}.tabs.is-scroll>button{flex:none;padding:0 16px}
/* switch / check / radio */
.switch{width:44px;height:26px;border-radius:13px;background:var(--border-default);position:relative;transition:background var(--motion-base);flex:none;display:inline-block}
.switch::after{content:"";position:absolute;inset:-11px -4px}
.switch[aria-checked="true"]{background:var(--brand-primary)}
.switch>i{position:absolute;top:3px;left:3px;width:20px;height:20px;border-radius:50%;background:#fff;transition:transform var(--motion-base) var(--ease-standard);box-shadow:0 1px 2px rgba(0,0,0,.2)}
.switch[aria-checked="true"]>i{transform:translateX(18px)}
.switch[aria-disabled="true"]{opacity:.5}
.check,.radio{width:22px;height:22px;border:2px solid var(--text-muted);display:inline-flex;align-items:center;justify-content:center;flex:none;color:#fff;transition:background var(--motion-fast),border-color var(--motion-fast);position:relative}
.check{border-radius:6px}.radio{border-radius:50%}
.check::after,.radio::after{content:"";position:absolute;inset:-13px}
.check[aria-checked="true"]{background:var(--brand-primary);border-color:var(--brand-primary)}
.radio[aria-checked="true"]{border-color:var(--brand-primary)}.radio[aria-checked="true"]>i{width:12px;height:12px;border-radius:50%;background:var(--brand-primary);display:block}
.check[aria-disabled="true"],.radio[aria-disabled="true"]{opacity:.5}
.option-row{display:flex;align-items:center;gap:12px;min-height:52px;padding:6px 16px;width:100%;text-align:left}
.option-row:hover{background:var(--bg-surface-muted)}
.option-card{display:flex;gap:12px;align-items:flex-start;padding:14px 16px;border-radius:var(--r-md);border:1px solid var(--border-default);width:100%;text-align:left;background:var(--bg-surface)}
.option-card.is-selected{border-color:var(--brand-primary);background:var(--brand-primary-container)}
/* banners */
.banner{display:flex;gap:10px;align-items:center;padding:10px 16px;font:500 calc(13px*var(--ts))/1.4 Inter,sans-serif;flex:none}
.banner.is-card{border-radius:var(--r-md);margin:0 16px}
.banner-offline{background:var(--text-heading);color:var(--bg-surface)}
.banner-info{background:var(--state-info-container);color:var(--state-info)}
.banner-warning{background:var(--state-warning-container);color:var(--state-warning)}
.banner-danger{background:var(--state-danger-container);color:var(--state-danger)}
.banner-readonly{background:var(--bg-surface-muted);color:var(--text-secondary)}
.banner-success{background:var(--state-success-container);color:var(--state-success)}
.banner .banner-text{flex:1;min-width:0}
.banner .btn-text{color:inherit;min-height:36px;padding:0 10px;text-decoration:underline}
/* progress */
.prog{height:6px;border-radius:3px;background:var(--bg-surface-muted);overflow:hidden;flex:1;min-width:40px}
.prog>i{display:block;height:100%;background:var(--brand-primary);border-radius:3px;transition:width var(--motion-slow) var(--ease-standard)}
.prog.is-warning>i{background:var(--state-warning)}.prog.is-success>i{background:var(--state-success)}.prog.is-muted>i{background:var(--text-muted)}.prog.is-thin{height:4px}
/* skeleton */
.sk{background:linear-gradient(90deg,var(--bg-surface-muted) 25%,var(--border-soft) 50%,var(--bg-surface-muted) 75%);background-size:200% 100%;animation:shimmer 1.2s linear infinite;border-radius:8px;display:block}
.sk.circle{border-radius:50%}
/* sheet */
.overlay-root{position:absolute;inset:0;z-index:100}
.scrim{position:absolute;inset:0;background:var(--overlay-scrim);animation:fadeIn var(--motion-base)}
.sheet{position:absolute;left:0;right:0;bottom:0;max-height:90%;background:var(--bg-surface-raised);border-radius:var(--r-xl) var(--r-xl) 0 0;box-shadow:var(--e3);display:flex;flex-direction:column;animation:sheetIn var(--motion-slow) var(--ease-emphasized);touch-action:none}
.gu-root[data-theme="dark"] .sheet{border-top:1px solid var(--border-default)}
.sheet.is-menu{max-height:80%}
.sheet-handle{width:36px;height:4px;border-radius:2px;background:var(--border-default);margin:8px auto 0;flex:none}
.sheet-head{display:flex;align-items:center;gap:8px;padding:6px 8px 6px 20px;flex:none;min-height:56px}
.sheet-head .t-title-m{flex:1;min-width:0}
.sheet-body{overflow-y:auto;padding:0 16px 16px;flex:1;min-height:0;scrollbar-width:none;touch-action:pan-y}
.sheet-body.is-flush{padding:0 0 8px}
.sheet-foot{padding:12px 16px calc(12px + var(--safe-bottom));border-top:1px solid var(--border-soft);display:flex;gap:12px;flex:none;background:var(--bg-surface-raised)}
.sheet-foot .btn{flex:1}
.sheet-full{height:90%}
.popmenu{position:absolute;top:calc(var(--safe-top) + 48px);right:12px;background:var(--bg-surface-raised);border-radius:var(--r-md);box-shadow:var(--e2);border:1px solid var(--border-soft);min-width:200px;padding:6px;animation:dialogIn var(--motion-base) var(--ease-standard);z-index:101}
.popmenu .tile{border-radius:10px;min-height:48px;padding:6px 12px}
/* dialog */
.dialog{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:min(320px,calc(100% - 48px));background:var(--bg-surface-raised);border-radius:var(--r-lg);padding:24px 20px 16px;box-shadow:var(--e2);animation:dialogIn var(--motion-base) var(--ease-standard);display:flex;flex-direction:column;gap:12px;max-height:85%;overflow:auto}
.gu-root[data-theme="dark"] .dialog{border:1px solid var(--border-default)}
.dialog-actions{display:flex;flex-direction:column;gap:6px;margin-top:8px}
.dialog-actions .btn{width:100%}
.dialog-actions.is-row{flex-direction:row-reverse}.dialog-actions.is-row .btn{flex:1}
/* toast */
.toast-wrap{position:absolute;left:12px;right:12px;bottom:calc(var(--safe-bottom) + 12px);z-index:200;pointer-events:none}
.toast-wrap.above-nav{bottom:calc(var(--nav-h) + 12px)}
.toast{pointer-events:auto;background:var(--text-heading);color:var(--bg-surface);border-radius:var(--r-sm);padding:12px 8px 12px 14px;display:flex;gap:10px;align-items:center;box-shadow:var(--e2);border-left:4px solid var(--toast-color,var(--state-info));animation:toastIn var(--motion-slow) var(--ease-emphasized);font:500 calc(13px*var(--ts))/1.4 Inter,sans-serif}
.toast .toast-icon{color:var(--toast-color);flex:none}
.toast .toast-text{flex:1;min-width:0}
.toast .toast-action{color:#fff;font-weight:700;min-height:36px;padding:0 10px;border-radius:8px;flex:none;background:rgba(255,255,255,.12)}
.gu-root[data-theme="dark"] .toast .toast-action{color:var(--text-heading);background:rgba(0,0,0,.08)}
/* misc */
.ctabar{padding:12px 16px calc(12px + var(--safe-bottom));background:var(--bg-surface);border-top:1px solid var(--border-soft);box-shadow:0 -4px 16px rgba(16,24,40,.06);display:flex;gap:12px;flex:none;z-index:6}
.ctabar.in-nav{padding-bottom:12px}
.ctabar .btn{flex:1}
.gu-root[data-theme="dark"] .ctabar{box-shadow:none}
.empty{display:flex;flex-direction:column;align-items:center;text-align:center;gap:12px;padding:32px 24px}
.empty .ill{display:inline-flex;line-height:0}
.kpi{padding:14px 16px;display:flex;flex-direction:column;gap:6px}
.kpi .kpi-value{font:700 calc(26px*var(--ts))/1.1 Montserrat,sans-serif;color:var(--text-heading);font-variant-numeric:tabular-nums}
.kpi.is-accent .kpi-value{color:var(--brand-primary-text)}
.quick{display:flex;flex-direction:column;align-items:center;gap:8px;padding:14px 8px;border-radius:var(--r-md);background:var(--bg-surface);border:1px solid var(--border-soft);text-align:center;font:600 calc(12px*var(--ts))/1.3 Inter,sans-serif;color:var(--text-heading)}
.quick .quick-icon{width:40px;height:40px;border-radius:12px;background:var(--brand-primary-container);color:var(--brand-primary-text);display:flex;align-items:center;justify-content:center}
.timeline{display:flex;flex-direction:column}
.timeline-item{display:flex;gap:12px;min-height:56px}
.timeline-rail{display:flex;flex-direction:column;align-items:center;width:24px;flex:none}
.timeline-dot{width:12px;height:12px;border-radius:50%;background:var(--border-default);border:2px solid var(--bg-surface);box-shadow:0 0 0 2px var(--border-default);margin-top:4px}
.timeline-dot.is-done{background:var(--state-success);box-shadow:0 0 0 2px var(--state-success)}.timeline-dot.is-active{background:var(--brand-primary);box-shadow:0 0 0 2px var(--brand-primary)}.timeline-dot.is-danger{background:var(--state-danger);box-shadow:0 0 0 2px var(--state-danger)}
.timeline-line{flex:1;width:2px;background:var(--border-default);margin:4px 0}
.cal-grid{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:2px}
.cal-day{aspect-ratio:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;border-radius:12px;font:500 calc(13px*var(--ts)) Inter,sans-serif;color:var(--text-primary);position:relative;min-height:44px}
.cal-day.is-other{color:var(--text-disabled)}.cal-day.is-today{box-shadow:inset 0 0 0 2px var(--brand-primary)}.cal-day.is-selected{background:var(--brand-primary);color:#fff}.cal-day[aria-disabled="true"]{color:var(--text-disabled);cursor:not-allowed}
.cal-day .dots{display:flex;gap:2px;height:4px}.cal-day .dots i{width:4px;height:4px;border-radius:50%;background:var(--brand-primary)}.cal-day.is-selected .dots i{background:#fff}
.cal-head{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));text-align:center;font:600 11px Inter,sans-serif;color:var(--text-muted);padding:4px 0}
.date-badge{width:48px;height:52px;border-radius:12px;background:var(--brand-primary-container);color:var(--brand-on-primary-container);display:flex;flex-direction:column;align-items:center;justify-content:center;flex:none}
.date-badge b{font:700 calc(18px*var(--ts))/1 Montserrat,sans-serif}.date-badge span{font:600 11px/1 Inter,sans-serif;text-transform:uppercase;margin-top:3px}
.stepbar{display:flex;gap:6px}.stepbar>i{flex:1;height:4px;border-radius:2px;background:var(--border-default)}.stepbar>i.is-done{background:var(--brand-primary)}
.wheel{height:160px;overflow-y:auto;scroll-snap-type:y mandatory;scrollbar-width:none;flex:1;mask-image:linear-gradient(transparent,#000 30%,#000 70%,transparent)}.wheel::-webkit-scrollbar{display:none}
.wheel>button{height:40px;width:100%;scroll-snap-align:center;display:flex;align-items:center;justify-content:center;font:600 calc(18px*var(--ts)) Montserrat,sans-serif;color:var(--text-muted)}.wheel>button[aria-selected="true"]{color:var(--text-heading)}
.ticket{background:var(--bg-surface);border-radius:var(--r-lg);position:relative;overflow:hidden;border:1px solid var(--border-soft)}
.ticket-cut{position:relative;height:1px;border-top:2px dashed var(--border-default);margin:0 16px}
.ticket-cut::before,.ticket-cut::after{content:"";position:absolute;top:-13px;width:24px;height:24px;border-radius:50%;background:var(--bg-canvas)}.ticket-cut::before{left:-28px}.ticket-cut::after{right:-28px}
.qr{width:220px;height:220px;background:#fff;padding:12px;border-radius:12px;margin:0 auto;position:relative}
.qr svg{width:100%;height:100%}.qr.is-blur svg{filter:blur(3px);opacity:.5}.qr.is-void::after{content:"";position:absolute;left:10%;top:50%;width:80%;height:4px;background:var(--state-danger);transform:rotate(-30deg)}
.poll-opt{display:flex;flex-direction:column;gap:4px;padding:10px 12px;border-radius:12px;border:1px solid var(--border-default);position:relative;overflow:hidden;width:100%;text-align:left;background:var(--bg-surface)}
.poll-opt .poll-fill{position:absolute;left:0;top:0;bottom:0;background:var(--brand-primary-container);transition:width .6s var(--ease-standard);z-index:0}.poll-opt>*{position:relative;z-index:1}
.poll-opt.is-mine{border-color:var(--brand-primary)}
.heart.is-liked{color:var(--brand-primary-text);animation:pop var(--motion-slow) var(--ease-emphasized)}
.check-draw{stroke-dasharray:60;stroke-dashoffset:60;animation:draw var(--motion-slow) .2s var(--ease-standard) forwards}
.circle-draw{stroke-dasharray:200;stroke-dashoffset:200;animation:draw .5s var(--ease-standard) forwards}
.shake{animation:shake .4s var(--ease-standard)}
.scanline{position:absolute;left:10%;right:10%;height:2px;background:var(--brand-primary);box-shadow:0 0 12px var(--brand-primary);animation:scan 2.2s ease-in-out infinite}
.notif-row{position:relative;overflow:hidden;background:var(--bg-canvas)}
.notif-under{position:absolute;inset:0;display:flex;align-items:center;justify-content:space-between;padding:0 20px;color:#fff;font:600 13px Inter,sans-serif}
.notif-under .u-left{background:var(--state-info)}.notif-under .u-right{background:var(--state-danger)}
.notif-front{position:relative;background:var(--bg-canvas);transition:transform var(--motion-base) var(--ease-standard);touch-action:pan-y}
.pressable{transition:transform var(--motion-fast)}.pressable:active{transform:scale(.98)}
.tooltip{position:absolute;transform:translate(-50%,-110%);background:var(--text-heading);color:var(--bg-surface);padding:4px 8px;border-radius:6px;font:600 11px Inter,sans-serif;white-space:nowrap;pointer-events:none}
.mini-chart{width:100%;height:120px;overflow:visible}
.code{font:500 12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--bg-surface-muted);padding:2px 6px;border-radius:6px;color:var(--text-heading);overflow-wrap:anywhere}
.pre{font:500 12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--bg-surface-muted);padding:12px;border-radius:12px;color:var(--text-heading);overflow:auto;white-space:pre}
/* site chrome */
.site{display:grid;grid-template-columns:232px minmax(0,1fr) 340px;height:100vh;min-height:600px;background:var(--bg-canvas);color:var(--text-primary);overflow:hidden}
.site.is-page{grid-template-columns:232px minmax(0,1fr)}
.site.is-tablet{grid-template-columns:minmax(0,1fr)}.site.is-mobile{display:block;height:auto;min-height:100vh}
.sidemenu{border-right:1px solid var(--border-soft);background:var(--bg-surface);display:flex;flex-direction:column;padding:16px 12px;gap:4px;overflow-y:auto}
.sidemenu .menu-item{display:flex;align-items:center;gap:10px;min-height:44px;padding:0 12px;border-radius:12px;font:600 14px Inter,sans-serif;color:var(--text-secondary);width:100%}
.sidemenu .menu-item:hover{background:var(--bg-surface-muted)}.sidemenu .menu-item[aria-current="page"]{background:var(--brand-primary-container);color:var(--brand-on-primary-container)}
.stage{display:flex;align-items:center;justify-content:center;overflow:hidden;position:relative;background:radial-gradient(ellipse at 50% 0%,color-mix(in srgb,var(--brand-primary) 6%,var(--bg-canvas)),var(--bg-canvas) 70%)}
.frame{position:relative;border-radius:54px;padding:12px;background:#111317;box-shadow:0 0 0 2px #3a3d44,0 30px 80px rgba(0,0,0,.35),inset 0 0 0 1px #000}
.frame>.device{border-radius:44px}
.frame .side-btn{position:absolute;width:3px;background:#2b2e34;border-radius:2px}
.panel{border-left:1px solid var(--border-soft);background:var(--bg-surface);overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:20px;scrollbar-width:thin}
.panel-group{display:flex;flex-direction:column;gap:8px}
.panel-group .t-overline{margin-bottom:2px}
.panel-row{display:flex;align-items:center;justify-content:space-between;gap:8px;min-height:36px;font:500 13px Inter,sans-serif;color:var(--text-secondary)}
.panel .seg>button{min-height:34px;font-size:12px}
.panel .btn{min-height:40px;font-size:13px;padding:0 14px;justify-content:flex-start}
.panel .btn-full{justify-content:center}
.account-row{display:flex;align-items:center;gap:10px;padding:8px;border-radius:12px;border:1px solid var(--border-soft);width:100%;text-align:left;background:var(--bg-surface)}
.account-row.is-active{border-color:var(--brand-primary);background:var(--brand-primary-container)}
.page{overflow-y:auto;height:100vh;padding:32px 40px 80px;scrollbar-width:thin}
.page-inner{max-width:1100px;margin:0 auto;display:flex;flex-direction:column;gap:24px}
.page-tabs{display:flex;gap:4px;flex-wrap:wrap;border-bottom:1px solid var(--border-soft);padding-bottom:12px}
.page-tabs>button{min-height:40px;padding:0 14px;border-radius:10px;font:600 13px Inter,sans-serif;color:var(--text-secondary)}.page-tabs>button[aria-selected="true"]{background:var(--brand-primary-container);color:var(--brand-on-primary-container)}
.asset-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}
.asset-card{background:var(--bg-surface);border:1px solid var(--border-soft);border-radius:16px;padding:12px;display:flex;flex-direction:column;gap:8px;align-items:center;text-align:center}
.asset-card .asset-prev{height:72px;display:flex;align-items:center;justify-content:center;width:100%}
.asset-card .asset-name{font:600 12px Inter,sans-serif;color:var(--text-heading);overflow-wrap:anywhere}
.asset-card .asset-actions{display:flex;gap:4px;flex-wrap:wrap;justify-content:center}
.asset-card .asset-actions .btn{min-height:32px;padding:0 10px;font-size:11px;border-radius:8px}
.table{width:100%;border-collapse:collapse;font:400 13px/1.4 Inter,sans-serif}
.table th{text-align:left;font:600 11px Montserrat,sans-serif;text-transform:uppercase;letter-spacing:.06em;color:var(--text-muted);padding:8px 10px;border-bottom:1px solid var(--border-default)}
.table td{padding:8px 10px;border-bottom:1px solid var(--border-soft);vertical-align:top}
.table tr:hover td{background:var(--bg-surface-muted)}
.swatch{width:100%;height:56px;border-radius:12px;border:1px solid var(--border-soft)}
.ds-pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}
.ds-pane{border-radius:20px;padding:20px;border:1px solid var(--border-soft);background:var(--bg-canvas);color:var(--text-primary);display:flex;flex-direction:column;gap:12px;min-width:0}
.ds-section{display:flex;flex-direction:column;gap:12px;padding:24px 0;border-bottom:1px solid var(--border-soft)}
.flow{display:flex;flex-wrap:wrap;align-items:center;gap:8px}
.flow-node{min-height:40px;padding:0 12px;border-radius:10px;border:1px solid var(--border-default);background:var(--bg-surface);font:600 12px Inter,sans-serif;color:var(--text-heading);display:inline-flex;align-items:center;gap:6px}
.flow-node:hover{border-color:var(--brand-primary)}.flow-node.is-sheet{border-style:dashed}.flow-node.is-dialog{border-radius:999px}.flow-node.is-toast{background:var(--bg-surface-muted)}
.flow-arrow{color:var(--text-disabled)}
.demo-fab{position:fixed;left:16px;bottom:16px;z-index:1000;height:48px;padding:0 16px;border-radius:24px;background:var(--text-heading);color:var(--bg-surface);font:600 13px Inter,sans-serif;display:flex;align-items:center;gap:8px;box-shadow:var(--e2)}
.drawer{position:fixed;left:0;right:0;bottom:0;max-height:85vh;background:var(--bg-surface);border-radius:24px 24px 0 0;box-shadow:var(--e3);z-index:1001;display:flex;flex-direction:column;animation:sheetIn var(--motion-slow) var(--ease-emphasized)}
.drawer .panel{border:0;max-height:70vh}
.drawer-scrim{position:fixed;inset:0;background:var(--overlay-scrim);z-index:1000}
.splash{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:16px;background:var(--bg-canvas)}
.splash .logo{animation:splash 1.2s var(--ease-emphasized)}
.onb-track{display:flex;overflow-x:auto;scroll-snap-type:x mandatory;scrollbar-width:none;flex:1}.onb-track::-webkit-scrollbar{display:none}.onb-track>section{flex:none;width:100%;scroll-snap-align:center;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 32px;gap:16px}
.dots{display:flex;gap:6px;justify-content:center}.dots>i{width:8px;height:8px;border-radius:4px;background:var(--border-default);transition:width var(--motion-base),background var(--motion-base)}.dots>i.is-active{width:24px;background:var(--brand-primary)}
.parallax{position:relative;height:220px;overflow:hidden;flex:none}
.parallax .cover{position:absolute;inset:0;transform:translateY(calc(var(--py,0) * .4px)) scale(calc(1 + var(--pz,0)))}
.parallax-bar{position:absolute;top:0;left:0;right:0;display:flex;align-items:center;gap:4px;padding:calc(var(--safe-top) - 4px) 8px 0;z-index:3}
.emblem{width:72px;height:72px;border-radius:20px;background:var(--bg-surface);border:1px solid var(--border-soft);display:flex;align-items:center;justify-content:center;color:var(--brand-primary-text);box-shadow:var(--e2);flex:none}
.emblem.is-sm{width:44px;height:44px;border-radius:12px;box-shadow:none;background:var(--brand-primary-container)}
.emblem.is-xs{width:32px;height:32px;border-radius:9px;box-shadow:none;background:var(--brand-primary-container)}
.scan-view{position:absolute;inset:0;background:radial-gradient(ellipse at 50% 40%,#2a2f3a,#0b0d12 75%);color:#fff;display:flex;flex-direction:column}
.scan-box{position:relative;width:240px;height:240px;margin:0 auto}
.scan-box>i{position:absolute;width:36px;height:36px;border:3px solid #fff;border-radius:4px}
.scan-box>i:nth-child(1){top:0;left:0;border-right:0;border-bottom:0}.scan-box>i:nth-child(2){top:0;right:0;border-left:0;border-bottom:0}.scan-box>i:nth-child(3){bottom:0;left:0;border-right:0;border-top:0}.scan-box>i:nth-child(4){bottom:0;right:0;border-left:0;border-top:0}
.notif-icon{width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex:none}
.ni-brand{background:var(--brand-primary-container);color:var(--brand-primary-text)}.ni-success{background:var(--state-success-container);color:var(--state-success)}.ni-danger{background:var(--state-danger-container);color:var(--state-danger)}.ni-info{background:var(--state-info-container);color:var(--state-info)}.ni-warning{background:var(--state-warning-container);color:var(--state-warning)}.ni-neutral{background:var(--bg-surface-muted);color:var(--text-secondary)}
.img-grid{display:grid;gap:4px;border-radius:14px;overflow:hidden}.img-grid.n1{grid-template-columns:1fr}.img-grid.n2,.img-grid.n4{grid-template-columns:1fr 1fr}.img-grid.n3{grid-template-columns:2fr 1fr}.img-grid.n3>*:first-child{grid-row:span 2}
.img-grid>button{aspect-ratio:1;display:block;position:relative;overflow:hidden;background:var(--bg-surface-muted)}.img-grid.n1>button{aspect-ratio:16/9}.img-grid>button svg{width:100%;height:100%}
.viewer{position:absolute;inset:0;background:#000;z-index:120;display:flex;flex-direction:column;color:#fff;animation:fadeIn var(--motion-base)}
.map-ph{height:120px;border-radius:12px;background:repeating-linear-gradient(45deg,var(--bg-surface-muted) 0 10px,var(--border-soft) 10px 20px);display:flex;align-items:center;justify-content:center;color:var(--text-muted);font:500 12px ui-monospace,monospace;border:1px solid var(--border-soft)}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes pushIn{from{opacity:0;transform:translateX(16px)}to{opacity:1;transform:none}}
@keyframes popIn{from{opacity:0;transform:translateX(-16px)}to{opacity:1;transform:none}}
@keyframes sheetIn{from{transform:translateY(100%)}to{transform:none}}
@keyframes dialogIn{from{opacity:0;transform:translate(-50%,-50%) scale(.96)}to{opacity:1;transform:translate(-50%,-50%) scale(1)}}
@keyframes toastIn{from{opacity:0;transform:translateY(24px)}to{opacity:1;transform:none}}
@keyframes shimmer{from{background-position:200% 0}to{background-position:-200% 0}}
@keyframes spin{to{transform:rotate(360deg)}}
@keyframes pop{0%{transform:scale(1)}40%{transform:scale(1.35)}100%{transform:scale(1)}}
@keyframes draw{to{stroke-dashoffset:0}}
@keyframes shake{0%,100%{transform:none}20%{transform:translateX(-8px)}40%{transform:translateX(8px)}60%{transform:translateX(-5px)}80%{transform:translateX(5px)}}
@keyframes scan{0%,100%{top:8%}50%{top:90%}}
@keyframes splash{0%{opacity:0;transform:scale(.7)}60%{opacity:1;transform:scale(1.05)}100%{transform:scale(1)}}
@keyframes splashOut{to{opacity:0;visibility:hidden}}
.splash-overlay{animation:splashOut .3s 1.3s var(--ease-standard) forwards}
@keyframes highlight{0%{box-shadow:0 0 0 3px var(--brand-primary)}100%{box-shadow:var(--e1)}}
@media (prefers-reduced-motion:reduce){.gu-root *,.gu-root *::before,.gu-root *::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important}.gu-root .screen,.gu-root .sheet,.gu-root .dialog,.gu-root .toast{animation:fadeIn var(--motion-base)!important}.gu-root .sk{animation:none!important}}
`;

  function injectCSS() {
    if (document.getElementById('gu-css')) return;
    const st = document.createElement('style'); st.id = 'gu-css'; st.textContent = CSS; document.head.appendChild(st);
  }

  /* ---------- utils ---------- */
  const cx = (...a) => a.filter(Boolean).join(' ');
  const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
  const last = (arr) => arr[arr.length - 1];
  let _uid = 0; const uid = (p = 'id') => `${p}_${Date.now().toString(36)}_${(++_uid).toString(36)}`;
  function hashStr(s) { let h = 2166136261; s = String(s); for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function mulberry32(a) { return function () { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  const rngFor = (seed) => mulberry32(hashStr(seed));
  const pad2 = (n) => String(n).padStart(2, '0');
  const initials = (name) => { const parts = String(name || '?').trim().split(/\s+/).filter(Boolean); if (!parts.length) return '?'; if (parts.length === 1) return parts[0][0].toLocaleUpperCase('tr'); return (parts[0][0] + parts[parts.length - 1][0]).toLocaleUpperCase('tr'); };
  const slug = (s) => String(s).toLowerCase().replace(/ğ/g, 'g').replace(/ü/g, 'u').replace(/ş/g, 's').replace(/ı/g, 'i').replace(/ö/g, 'o').replace(/ç/g, 'c').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  function copyText(text) { try { if (navigator.clipboard && navigator.clipboard.writeText) return navigator.clipboard.writeText(text).catch(() => fallbackCopy(text)); } catch (e) { } return Promise.resolve(fallbackCopy(text)); }
  function fallbackCopy(text) { try { const ta = document.createElement('textarea'); ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0'; document.body.appendChild(ta); ta.select(); document.execCommand('copy'); ta.remove(); } catch (e) { } }
  function downloadBlob(blob, name) { try { const url = URL.createObjectURL(blob); const a = document.createElement('a'); a.href = url; a.download = name; document.body.appendChild(a); a.click(); setTimeout(() => { a.remove(); URL.revokeObjectURL(url); }, 2000); } catch (e) { console.warn('download failed', e); } }
  function downloadText(text, name, type = 'text/plain;charset=utf-8') { downloadBlob(new Blob([text], { type }), name); }
  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  /* ---------- dates ---------- */
  const DAY = 864e5;
  const startOfDay = (ts) => { const d = new Date(ts); d.setHours(0, 0, 0, 0); return d.getTime(); };
  const today0 = () => startOfDay(Date.now());
  const at = (dayOff, hh = 0, mm = 0) => today0() + dayOff * DAY + hh * 36e5 + mm * 6e4;
  const dayKey = (ts) => { const d = new Date(ts); return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`; };
  const isSameDay = (a, b) => startOfDay(a) === startOfDay(b);
  function dayDiff(ts) { return Math.round((startOfDay(ts) - today0()) / DAY); }

  /* ---------- I18N engine ---------- */
  const I18N = { tr: {}, en: {} };
  const I18N_META = {};
  const MISSING_KEYS = new Set();
  function defineDictionary(pairs) { for (const k in pairs) { const v = pairs[k]; I18N.tr[k] = v[0]; I18N.en[k] = v[1]; if (v[2]) I18N_META[k] = v[2]; } }
  function matchBrace(str, i) { let d = 0; for (let j = i; j < str.length; j++) { if (str[j] === '{') d++; else if (str[j] === '}') { d--; if (d === 0) return j; } } return str.length - 1; }
  function splitTop(s, max) { const out = []; let d = 0, cur = ''; for (const ch of s) { if (ch === '{') d++; if (ch === '}') d--; if (ch === ',' && d === 0 && out.length < max - 1) { out.push(cur); cur = ''; } else cur += ch; } out.push(cur); return out; }
  function parseBranches(s) { const b = {}; const re = /(=?\w+)\s*\{/g; let m; while ((m = re.exec(s))) { const end = matchBrace(s, m.index + m[0].length - 1); b[m[1]] = s.slice(m.index + m[0].length, end); re.lastIndex = end + 1; } return b; }
  function fmtNum(n, loc) { try { return new Intl.NumberFormat(loc === 'tr' ? 'tr-TR' : 'en-GB').format(n); } catch (e) { return String(n); } }
  function icu(str, params, loc) {
    params = params || {}; let out = ''; let i = 0;
    while (i < str.length) {
      const c = str[i];
      if (c === '{') {
        const end = matchBrace(str, i); const inner = str.slice(i + 1, end); i = end + 1;
        const parts = splitTop(inner, 3); const name = parts[0].trim();
        if (parts.length === 1) { const v = params[name]; out += v == null ? '' : v; continue; }
        const type = parts[1].trim();
        if (type === 'plural') {
          const n = Number(params[name] ?? 0); let cat = 'other';
          try { cat = new Intl.PluralRules(loc === 'tr' ? 'tr' : 'en').select(n); } catch (e) { cat = n === 1 ? 'one' : 'other'; }
          const br = parseBranches(parts[2] || ''); const chosen = br['=' + n] ?? br[cat] ?? br.other ?? '';
          out += icu(chosen.replace(/#/g, fmtNum(n, loc)), params, loc);
        } else if (type === 'select') {
          const br = parseBranches(parts[2] || ''); const v = String(params[name]); out += icu(br[v] ?? br.other ?? '', params, loc);
        } else out += params[name] ?? '';
      } else { out += c; i++; }
    }
    return out;
  }
  function tFor(loc) { return (key, params) => { const s = I18N[loc] && I18N[loc][key]; if (s == null) { if (!MISSING_KEYS.has(key)) { MISSING_KEYS.add(key); console.warn('[i18n] missing key', key); } return key; } return params ? icu(s, params, loc) : s; }; }

  /* ---------- STORE ---------- */
  const HANDLERS = {};
  const store = {
    state: null, listeners: new Set(), _persistTimer: null,
    get() { return this.state; },
    subscribe(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); },
    notify() { this.listeners.forEach((fn) => { try { fn(); } catch (e) { console.error(e); } }); },
    set(next, opts = {}) { this.state = next; if (opts.persist !== false) this.persist(); this.notify(); },
    persist() { clearTimeout(this._persistTimer); this._persistTimer = setTimeout(() => { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(this.state)); } catch (e) { /* storage unavailable: memory only */ } }, 250); },
    load() { try { const raw = localStorage.getItem(STORAGE_KEY); if (!raw) return null; const s = JSON.parse(raw); if (!s || s.seedDay !== dayKey(Date.now()) || s.seedVersion !== SEED_VERSION) return null; return s; } catch (e) { return null; } },
    clearPersisted() { try { localStorage.removeItem(STORAGE_KEY); } catch (e) { } },
    register(map) { Object.assign(HANDLERS, map); },
    dispatch(type, payload) {
      const fn = HANDLERS[type]; if (!fn) { console.error('unknown action', type); return undefined; }
      const res = fn(this.state, payload || {});
      if (res && res.__ret) { this.set(res.state); return res.result; }
      if (res) this.set(res);
      return undefined;
    },
    restore(snap) { const cur = this.state; this.set({ ...snap, session: cur.session, ui: cur.ui }); },
  };
  const ret = (state, result) => ({ __ret: true, state, result });
  const SEED_VERSION = 3;
  // immutable helpers
  const upd = (state, key, id, patch) => ({ ...state, [key]: { ...state[key], [id]: { ...(state[key][id] || {}), ...patch } } });
  const del = (state, key, id) => { const col = { ...state[key] }; delete col[id]; return { ...state, [key]: col }; };
  const put = (state, key, id, obj) => ({ ...state, [key]: { ...state[key], [id]: obj } });

  /* ---------- ROUTER ---------- */
  const TABS = ['clubs', 'events', 'notifications', 'admin', 'profile'];
  const TAB_ROOT = { clubs: 'CLB-01', events: 'EVT-01', notifications: 'NTF-01', admin: 'ADM-01', profile: 'PRF-01' };
  const TAB_OF = (screen) => { const p = screen.slice(0, 3); return { CLB: 'clubs', FED: 'clubs', MGT: 'clubs', EVT: 'events', NTF: 'notifications', PRF: 'profile', SET: 'profile', ADM: 'admin' }[p] || null; };
  const ROUTE_PATH = {
    'SYS-01': () => '/splash', 'SYS-02': () => '/error', 'SYS-03': () => '/offline', 'SYS-04': () => '/not-found', 'ONB-01': () => '/onboarding',
    'AUT-01': () => '/login', 'AUT-02': () => '/register', 'AUT-03': () => '/verify', 'AUT-04': () => '/reset', 'AUT-05': () => '/setup-profile', 'AUT-06': (p) => `/legal/${p.tab || 'kvkk'}`,
    'CLB-01': () => '/clubs', 'CLB-02': () => '/clubs/search', 'CLB-03': (p) => `/clubs/${p.id}`, 'CLB-04': (p) => `/clubs/${p.id}/applied`, 'CLB-05': (p) => `/clubs/${p.id}/application`, 'CLB-06': (p) => `/clubs/${p.id}/members`, 'CLB-07': (p) => `/users/${p.id}`,
    'FED-01': (p) => `/clubs/${p.id}`, 'FED-02': (p) => `/clubs/${p.clubId}/posts/${p.postId}`, 'FED-03': (p) => `/clubs/${p.clubId}/compose${p.edit ? '?edit=' + p.edit : ''}`,
    'EVT-01': () => '/events', 'EVT-02': (p) => `/events/${p.id}`, 'EVT-03': (p) => `/events/${p.id}/ticket`, 'EVT-04': () => '/events/mine',
    'NTF-01': () => '/notifications', 'NTF-02': () => '/settings/notifications',
    'PRF-01': () => '/profile', 'PRF-02': () => '/profile/edit', 'PRF-03': () => '/profile/clubs', 'PRF-04': () => '/profile/saved',
    'SET-01': () => '/settings', 'SET-02': () => '/settings/blocked', 'SET-03': () => '/settings/delete', 'SET-04': () => '/settings/about', 'SET-05': () => '/settings/support',
    'MGT-01': (p) => `/manage/${p.clubId}`, 'MGT-02': (p) => `/manage/${p.clubId}/applications`, 'MGT-03': (p) => `/manage/${p.clubId}/members`, 'MGT-04': (p) => `/manage/${p.clubId}/events`, 'MGT-05': (p) => `/manage/${p.clubId}/events/${p.eventId ? p.eventId + '/edit' : 'new'}`,
    'MGT-06': (p) => `/manage/${p.clubId}/events/${p.eventId}/attendance`, 'MGT-07': (p) => `/manage/${p.clubId}/events/${p.eventId}/scan`, 'MGT-08': (p) => `/manage/${p.clubId}/content`, 'MGT-09': (p) => `/manage/${p.clubId}/settings`, 'MGT-10': (p) => `/manage/${p.clubId}/activity`,
    'ADM-01': () => '/admin', 'ADM-02': () => '/admin/clubs', 'ADM-03': (p) => `/admin/clubs/${p.id ? p.id + '/edit' : 'new'}`, 'ADM-04': () => '/admin/reports', 'ADM-05': () => '/admin/users',
  };
  const routePath = (r) => { const f = ROUTE_PATH[r.screen]; return f ? f(r.params || {}) : '/' + r.screen; };
  const mkRoute = (screen, params = {}) => ({ screen, params, key: uid('r') });
  const nav = {
    mode: 'splash', rootStack: [mkRoute('SYS-01')], activeTab: 'clubs',
    stacks: { clubs: [mkRoute('CLB-01')], events: [mkRoute('EVT-01')], notifications: [mkRoute('NTF-01')], admin: [mkRoute('ADM-01')], profile: [mkRoute('PRF-01')] },
    scroll: {}, anim: 'fade', listeners: new Set(), scrollTopReq: 0, _hashBusy: false,
    subscribe(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); },
    changed() { this.syncHash(); this.listeners.forEach((fn) => fn()); },
    stack() { return this.mode === 'app' ? this.stacks[this.activeTab] : this.rootStack; },
    current() { return last(this.stack()); },
    depth() { return this.stack().length; },
    push(screen, params = {}) { this.stack().push(mkRoute(screen, params)); this.anim = 'push'; this.changed(); },
    replace(screen, params = {}) { const st = this.stack(); st[st.length - 1] = mkRoute(screen, params); this.anim = 'fade'; this.changed(); },
    back() { const st = this.stack(); if (st.length > 1) { st.pop(); this.anim = 'pop'; this.changed(); return true; } if (this.mode === 'auth' && st[0].screen !== 'AUT-01' && st[0].screen !== 'ONB-01') { this.rootStack = [mkRoute('AUT-01')]; this.anim = 'pop'; this.changed(); return true; } return false; },
    popTo(screen) { const st = this.stack(); const idx = st.map((r) => r.screen).lastIndexOf(screen); if (idx >= 0) { st.splice(idx + 1); this.anim = 'pop'; this.changed(); return true; } return false; },
    switchTab(tab) {
      if (tab === this.activeTab) { const st = this.stacks[tab]; if (st.length > 1) { this.stacks[tab] = [st[0]]; this.anim = 'pop'; } else { this.scrollTopReq++; } }
      else { this.activeTab = tab; this.anim = 'fade'; }
      this.changed();
    },
    resetStacks() { TABS.forEach((tb) => { this.stacks[tb] = [mkRoute(TAB_ROOT[tb])]; }); this.scroll = {}; },
    enterApp(tab = 'clubs') { this.mode = 'app'; this.resetStacks(); this.activeTab = tab; this.anim = 'fade'; this.changed(); },
    resetTo(screen, params = {}) {
      const tab = TAB_OF(screen);
      if (tab) { this.mode = 'app'; this.resetStacks(); this.activeTab = tab; if (screen !== TAB_ROOT[tab]) this.stacks[tab].push(mkRoute(screen, params)); }
      else { this.mode = 'auth'; this.rootStack = [mkRoute(screen, params)]; }
      this.anim = 'fade'; this.changed();
    },
    openInTab(tab, routes) { this.mode = 'app'; this.activeTab = tab; this.stacks[tab] = [mkRoute(TAB_ROOT[tab]), ...routes.map((r) => mkRoute(r.screen, r.params || {}))]; this.anim = 'push'; this.changed(); },
    syncHash() { try { const p = '#' + routePath(this.current()); if (location.hash !== p) { this._hashBusy = true; location.hash = p; setTimeout(() => { this._hashBusy = false; }, 0); } } catch (e) { } },
    onHashChange() { if (this._hashBusy) return; try { const st = this.stack(); if (st.length > 1 && location.hash === '#' + routePath(st[st.length - 2])) { st.pop(); this.anim = 'pop'; this.listeners.forEach((fn) => fn()); return; } } catch (e) { } this.syncHash(); },
  };
  try { window.addEventListener('hashchange', () => nav.onHashChange()); } catch (e) { }

  /* ---------- overlays ---------- */
  const ui = {
    sheets: [], dialogs: [], toast: null, toastTimer: null, listeners: new Set(), viewer: null, menu: null,
    subscribe(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); },
    notify() { this.listeners.forEach((fn) => fn()); },
    openSheet(id, props = {}) { this.sheets.push({ id, props, key: uid('s') }); this.notify(); },
    closeSheet(n = 1) { for (let i = 0; i < n; i++) this.sheets.pop(); this.notify(); },
    closeAllSheets() { this.sheets = []; this.notify(); },
    replaceSheet(id, props = {}) { this.sheets.pop(); this.sheets.push({ id, props, key: uid('s') }); this.notify(); },
    openDialog(id, props = {}) { this.dialogs.push({ id, props, key: uid('d') }); this.notify(); },
    closeDialog() { this.dialogs.pop(); this.notify(); },
    openMenu(id, props = {}) { this.menu = { id, props, key: uid('m') }; this.notify(); },
    closeMenu() { this.menu = null; this.notify(); },
    openViewer(props) { this.viewer = props; this.notify(); },
    closeViewer() { this.viewer = null; this.notify(); },
    toast(id, props = {}) {
      clearTimeout(this.toastTimer); this.toast = { id, props, key: uid('t') }; this.notify();
      const ms = props.duration || (props.undo || props.action ? 6000 : 4000);
      this.toastTimer = setTimeout(() => { this.toast = null; this.notify(); }, ms);
    },
    hideToast() { clearTimeout(this.toastTimer); this.toast = null; this.notify(); },
    closeTop() { if (this.viewer) { this.closeViewer(); return true; } if (this.menu) { this.closeMenu(); return true; } if (this.dialogs.length) { this.closeDialog(); return true; } if (this.sheets.length) { this.closeSheet(); return true; } return false; },
  };

  /* ---------- action registry ---------- */
  const registry = {
    actions: new Map(), // pattern -> {screen, count, results:Set, lastAt}
    dead: [], events: [],
    normalize(a) { return a.replace(/\.(c|u|e|p|n|r|d|k|i|pl|cm)[_\w]*\d[\w]*$/g, '.*').replace(/\.(u_[a-z]+|[a-z0-9]+_[a-z0-9]+)$/g, '.*'); },
    record(action, result) {
      const key = action; const rec = this.actions.get(key) || { action: key, screen: key.split('.')[0], count: 0, results: new Set(), lastAt: 0 };
      rec.count++; rec.lastAt = Date.now(); if (result) rec.results.add(result); this.actions.set(key, rec);
      this.events.push({ action, result, at: Date.now() }); if (this.events.length > 500) this.events.shift();
    },
    addResult(action, result) { const rec = this.actions.get(action); if (rec && result) rec.results.add(result); },
    list() { return [...this.actions.values()].sort((a, b) => a.action.localeCompare(b.action)); },
  };
  const USED_ICONS = new Set();

  /* ---------- app singleton ---------- */
  const forms = {};
  const app = {
    APP_NAME, APP_VERSION, ALLOWED_EMAIL_DOMAINS, DEMO_PASSWORD, STORAGE_KEY,
    store, nav, ui, registry, forms, USED_ICONS, MISSING_KEYS, I18N, I18N_META,
    get state() { return store.state; },
    dispatch: (type, payload) => store.dispatch(type, payload),
    locale() { const s = store.state; return (s && s.session && s.session.locale) || 'tr'; },
    t(key, params) { return tFor(app.locale())(key, params); },
    tIn(loc, key, params) { return tFor(loc)(key, params); },
    theme() { const s = store.state; const th = (s && s.session && s.session.theme) || 'system'; if (th !== 'system') return th; try { return matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'; } catch (e) { return 'light'; } },
    textScale() { const s = store.state; return (s && s.session && s.session.textScale) || 1; },
    me() { const s = store.state; return s && s.session && s.session.userId ? s.users[s.session.userId] : null; },
    uid() { const s = store.state; return s && s.session ? s.session.userId : null; },
    online() { return store.state.ui.network !== 'offline'; },
    refresh() { store.notify(); },
    openSheet: (id, props) => ui.openSheet(id, props), closeSheet: (n) => ui.closeSheet(n), replaceSheet: (id, p) => ui.replaceSheet(id, p),
    openDialog: (id, props) => ui.openDialog(id, props), closeDialog: () => ui.closeDialog(),
    openMenu: (id, props) => ui.openMenu(id, props), closeMenu: () => ui.closeMenu(),
    toast: (id, props) => ui.toast(id, props), hideToast: () => ui.hideToast(),
    api(fn, opts = {}) {
      return new Promise((resolve, reject) => {
        const net = store.state.ui.network;
        if (net === 'offline' && !opts.allowOffline) { ui.toast('TST-24'); reject(new Error('offline')); return; }
        const hidden = typeof document !== 'undefined' && document.visibilityState === 'hidden';
        const delay = hidden ? 0 : opts.delay != null ? opts.delay : net === 'slow' ? 1500 : 400 + Math.floor(Math.random() * 500);
        const done = () => { if (opts.fail) { reject(new Error('fail')); return; } try { resolve(fn ? fn() : undefined); } catch (e) { console.error(e); reject(e); } };
        if (delay === 0) Promise.resolve().then(done); else setTimeout(done, delay);
      });
    },
    requireOnline() { if (!app.online()) { ui.toast('TST-24'); return false; } return true; },
    /** write-guard for club context: advisor → read-only toast; offline → offline toast */
    guard(clubId) {
      if (clubId && app.sel && app.sel.isAdvisor(clubId, app.uid())) { ui.toast('TST-26'); return false; }
      return app.requireOnline();
    },
    undoable(snapshot) { return () => store.restore(snapshot); },
    fmt: {
      num: (n) => fmtNum(n, app.locale()),
      date(ts, opts) { try { return new Intl.DateTimeFormat(app.locale() === 'tr' ? 'tr-TR' : 'en-GB', opts || { day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(ts)); } catch (e) { return new Date(ts).toLocaleDateString(); } },
      time(ts) { return app.fmt.date(ts, { hour: '2-digit', minute: '2-digit' }); },
      dateShort(ts) { return app.fmt.date(ts, { day: 'numeric', month: 'short' }); },
      dateLong(ts) { return app.fmt.date(ts, { weekday: 'long', day: 'numeric', month: 'long' }); },
      dateTime(ts) { return `${app.fmt.date(ts, { weekday: 'short', day: 'numeric', month: 'short' })}, ${app.fmt.time(ts)}`; },
      monthYear(ts) { return app.fmt.date(ts, { month: 'long', year: 'numeric' }); },
      monthShort(ts) { return app.fmt.date(ts, { month: 'short' }).replace('.', ''); },
      weekdayShort(ts) { return app.fmt.date(ts, { weekday: 'short' }); },
      range(a, b) { if (!b) return app.fmt.time(a); if (isSameDay(a, b)) return `${app.fmt.time(a)}–${app.fmt.time(b)}`; return `${app.fmt.dateTime(a)} → ${app.fmt.dateTime(b)}`; },
      duration(a, b) { const t = app.t; if (!b) return ''; const m = Math.round((b - a) / 6e4); if (m < 60) return t('time.minutes', { count: m }); const hrs = Math.round(m / 60 * 10) / 10; return t('time.hours', { count: hrs }); },
      rel(ts) { const t = app.t; const diff = Date.now() - ts; const m = Math.round(diff / 6e4); if (m < 1) return t('time.justNow'); if (m < 60) return t('time.minutesAgo', { count: m }); const hh = Math.round(m / 60); if (hh < 24) return t('time.hoursAgo', { count: hh }); const d = Math.round(hh / 24); if (d === 1) return t('time.yesterday'); if (d < 7) return t('time.daysAgo', { count: d }); if (d < 30) return t('time.weeksAgo', { count: Math.round(d / 7) }); return app.fmt.dateShort(ts); },
      dayLabel(ts) { const t = app.t; const d = dayDiff(ts); if (d === 0) return t('time.today'); if (d === 1) return t('time.tomorrow'); if (d === -1) return t('time.yesterday'); return app.fmt.date(ts, { weekday: 'long', day: 'numeric', month: 'long' }); },
      countdown(ts) { const t = app.t; const d = Math.max(0, Math.ceil((ts - Date.now()) / DAY)); return t('time.inDays', { count: d }); },
      pct: (n) => `%${Math.round(n)}`,
    },
  };

  /* ---------- hooks ---------- */
  function useForm(key, init) {
    if (!forms[key]) forms[key] = typeof init === 'function' ? init() : { ...(init || {}) };
    const f = forms[key];
    const set = (patch) => { const cur = forms[key]; const p = typeof patch === 'function' ? patch(cur) : patch; forms[key] = { ...cur, ...p }; app.refresh(); };
    const reset = () => { delete forms[key]; app.refresh(); };
    return [f, set, reset];
  }
  function useBusy() {
    const [busy, setBusy] = useState(false); const ref = useRef(false);
    const run = useCallback(async (fn) => { if (ref.current) return; ref.current = true; setBusy(true); try { return await fn(); } catch (e) { return undefined; } finally { ref.current = false; setBusy(false); } }, []);
    return [busy, run];
  }
  function useCountdown(until) { const [, tick] = useState(0); useEffect(() => { if (!until) return; const id = setInterval(() => tick((x) => x + 1), 1000); return () => clearInterval(id); }, [until]); return Math.max(0, Math.ceil(((until || 0) - Date.now()) / 1000)); }
  function useFocusTrap(ref, onClose, active = true) {
    useEffect(() => {
      if (!active || !ref.current) return; const root = ref.current; const prev = document.activeElement;
      const sel = 'button:not([disabled]),[href],input:not([disabled]),textarea:not([disabled]),select,[tabindex]:not([tabindex="-1"])';
      const first = root.querySelector('[data-autofocus]') || root.querySelector(sel); if (first) setTimeout(() => { try { first.focus({ preventScroll: true }); } catch (e) { } }, 30);
      const onKey = (e) => {
        if (e.key === 'Escape' && onClose) { e.stopPropagation(); onClose(); return; }
        if (e.key !== 'Tab') return; const items = [...root.querySelectorAll(sel)].filter((el) => el.offsetParent !== null); if (!items.length) return;
        const i = items.indexOf(document.activeElement);
        if (e.shiftKey && (i <= 0)) { e.preventDefault(); items[items.length - 1].focus(); } else if (!e.shiftKey && i === items.length - 1) { e.preventDefault(); items[0].focus(); }
      };
      root.addEventListener('keydown', onKey);
      return () => { root.removeEventListener('keydown', onKey); if (prev && prev.focus) { try { prev.focus({ preventScroll: true }); } catch (e) { } } };
    }, [active]);
  }
  function useTicker(ms) { const [, s] = useState(0); useEffect(() => { const id = setInterval(() => s((x) => x + 1), ms); return () => clearInterval(id); }, [ms]); }

  window.GU = {
    h, render, Fragment, html, useState, useEffect, useRef, useMemo, useLayoutEffect, useCallback,
    APP_NAME, APP_VERSION, ALLOWED_EMAIL_DOMAINS, DEMO_PASSWORD, TOKENS, cssVar, tokensCSS, CSS, injectCSS,
    cx, clamp, last, uid, hashStr, mulberry32, rngFor, pad2, initials, slug, copyText, downloadBlob, downloadText, escapeHtml,
    DAY, startOfDay, today0, at, dayKey, isSameDay, dayDiff,
    I18N, I18N_META, MISSING_KEYS, defineDictionary, icu, tFor,
    store, ret, upd, del, put, SEED_VERSION, nav, TABS, TAB_ROOT, TAB_OF, routePath, ui, registry, USED_ICONS, app, forms,
    useForm, useBusy, useCountdown, useFocusTrap, useTicker,
  };
})();

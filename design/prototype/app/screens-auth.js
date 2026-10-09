/* ===== SCREENS: SYS · ONB · AUT ===== */
(function () {
  const { html, cx, Icon, app, useState, useEffect, useRef, useForm, useBusy, useCountdown, Button, IconButton, Input, Picker, Checkbox, Chip, Tabs, AppBar, Scroll, Logo, Illustration, SuccessCheck, Stepbar, Avatar, EmptyState, ErrorState, OfflineState, StickyCTA, Card, ALLOWED_EMAIL_DOMAINS, DEMO_PASSWORD, DEMO_ACCOUNTS, INTERESTS } = GU;
  const t = (k, p) => app.t(k, p); const S = (GU.SCREENS = GU.SCREENS || {});
  const sel = () => app.sel;
  const emailOk = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e || '');
  const domainOk = (e) => ALLOWED_EMAIL_DOMAINS.some((d) => (e || '').toLowerCase().endsWith('@' + d));

  /* auth flow helpers */
  const auth = {
    enterApp(first) {
      app.ui.closeAllSheets(); app.nav.enterApp('clubs');
      const s = app.state.session; const ask = s.notifPermission === 'default' && (!s.notifAskedAt || Date.now() - s.notifAskedAt > 3 * GU.DAY);
      if (ask) setTimeout(() => app.openDialog('DLG-03'), 600);
    },
    afterLogin(userId) {
      const u = sel().user(userId); if (!u) return;
      if (u.status === 'suspended') { app.openDialog('DLG-01'); return; }
      const res = app.dispatch('session.login', { userId }) || {};
      if (!u.emailVerified) { app.nav.resetTo('AUT-03'); return; }
      if (!u.profileComplete) { app.nav.resetTo('AUT-05'); return; }
      auth.enterApp(res.first);
    },
    /** synchronous initial routing (used by boot so the first screen never depends on a timer) */
    routeInitial() { const s = app.state.session; if (s.userId && sel().user(s.userId)) { const u = sel().user(s.userId); if (u.status === 'suspended') { app.dispatch('session.logout'); app.nav.resetTo('AUT-01'); app.openDialog('DLG-01'); } else if (!u.emailVerified) app.nav.resetTo('AUT-03'); else if (!u.profileComplete) app.nav.resetTo('AUT-05'); else app.nav.enterApp('clubs'); } else app.nav.resetTo(s.onboardingDone ? 'AUT-01' : 'ONB-01'); },
    logout() { app.dispatch('session.logout'); app.ui.closeAllSheets(); app.ui.dialogs = []; app.nav.resetTo('AUT-01'); Object.keys(app.forms).forEach((k) => delete app.forms[k]); },
  };
  GU.auth = auth;

  /* SYS-01 Splash */
  S['SYS-01'] = { tab: null, title: 'sys.splash.title', comp: function Splash() {
    useEffect(() => { let id; const go = () => { if (GU.SCANNING) { id = setTimeout(go, 400); return; } const s = app.state.session; if (s.userId && sel().user(s.userId)) { const u = sel().user(s.userId); if (u.status === 'suspended') { app.dispatch('session.logout'); app.nav.resetTo('AUT-01'); app.openDialog('DLG-01'); } else if (!u.emailVerified) app.nav.resetTo('AUT-03'); else if (!u.profileComplete) app.nav.resetTo('AUT-05'); else { app.nav.enterApp('clubs'); } } else app.nav.resetTo(s.onboardingDone ? 'AUT-01' : 'ONB-01'); }; id = setTimeout(go, 1200); return () => clearTimeout(id); }, []);
    return html`<div class="splash" aria-busy="true"><${Logo} size=${96} /><span class="t-title-l" style="letter-spacing:.04em">${app.APP_NAME}</span><span class="t-caption" style="position:absolute;bottom:40px">v${app.APP_VERSION}</span></div>`;
  } };
  /* SYS-02 Error */
  S['SYS-02'] = { tab: null, title: 'sys.error.title', comp: function ErrorScreen() { return html`<${AppBar} onBack=${() => app.nav.back()} backAction="SYS-02.back" title="" /><div class="screen-scroll col" style="justify-content:center"><${ErrorState} onRetry=${() => { app.dispatch('ui.set', { dataMode: 'normal' }); app.nav.back() || app.nav.resetTo('CLB-01'); }} onHome=${() => app.nav.resetTo('CLB-01')} /></div>`; } };
  /* SYS-03 Offline */
  S['SYS-03'] = { tab: null, title: 'sys.offline.title', comp: function OfflineScreen() { return html`<${AppBar} onBack=${() => app.nav.back()} backAction="SYS-03.back" title="" /><div class="screen-scroll col" style="justify-content:center"><${OfflineState} onRetry=${() => (app.nav.back() || app.nav.resetTo('CLB-01'))} /></div>`; } };
  /* SYS-04 Not found */
  S['SYS-04'] = { tab: null, title: 'sys.notFound.title', comp: function NotFound() { return html`<${AppBar} onBack=${() => app.nav.back()} backAction="SYS-04.back" title="" /><div class="screen-scroll col" style="justify-content:center"><div class="empty"><${Illustration} name="locked" /><h2 class="t-title-s">${t('sys.notFound.title')}</h2><p class="t-body-s c-sec" style="max-width:280px">${t('sys.notFound.desc')}</p><div class="row gap8"><${Button} variant="outline" label=${t('common.back')} action="SYS-04.back" onClick=${() => app.nav.back() || app.nav.resetTo('CLB-01')} /><${Button} label=${t('sys.error.home')} action="SYS-04.home" onClick=${() => app.nav.resetTo('CLB-01')} /></div></div></div>`; } };

  /* ONB-01 Onboarding */
  S['ONB-01'] = { tab: null, title: 'onb.title', comp: function Onboarding() {
    const [i, setI] = useState(0); const ref = useRef(); const slides = ['discover', 'join', 'follow'];
    const go = (n) => { const el = ref.current; if (!el) return; el.scrollTo({ left: n * el.clientWidth, behavior: 'smooth' }); setI(n); };
    const finish = () => { app.dispatch('session.set', { onboardingDone: true }); app.nav.resetTo('AUT-01'); };
    return html`<div class="row between" style="padding:4px 8px 0 16px"><${Button} variant="ghost" size="sm" icon="languages" label=${app.locale().toUpperCase()} action="ONB-01.lang" onClick=${() => app.openMenu('SHT-01', { popup: true })} /><${Button} variant="text" size="sm" label=${t('onb.skip')} action="ONB-01.skip" onClick=${finish} /></div>
      <div class="onb-track" ref=${ref} onScroll=${(e) => { const n = Math.round(e.target.scrollLeft / e.target.clientWidth); if (n !== i) setI(n); }} data-action="ONB-01.swipe">${slides.map((s) => html`<section key=${s} aria-label=${t('onb.' + s + '.title')}><${Illustration} name=${'onb-' + s} size=${200} /><h1 class="t-display">${t('onb.' + s + '.title')}</h1><p class="t-body-l c-sec">${t('onb.' + s + '.desc')}</p></section>`)}</div>
      <div class="col gap16" style="padding:0 24px calc(var(--safe-bottom) + 16px)"><div class="dots" aria-hidden="true">${slides.map((s, k) => html`<i key=${s} class=${k === i ? 'is-active' : ''} />`)}</div>
        ${i < 2 ? html`<${Button} size="lg" full label=${t('onb.next')} iconRight="arrow-right" action="ONB-01.next" onClick=${() => go(i + 1)} />` : html`<${Button} size="lg" full label=${t('onb.start')} action="ONB-01.start" onClick=${finish} />`}</div>`;
  } };

  /* AUT-01 Login */
  S['AUT-01'] = { tab: null, title: 'auth.login.title', comp: function Login() {
    const [f, set] = useForm('login', { email: '', password: '', show: false, errors: {}, demoOpen: true, shake: false });
    const [busy, run] = useBusy(); const locked = useCountdown(app.state.session.lockedUntil);
    const validate = () => { const e = {}; if (!f.email) e.email = t('auth.err.required'); else if (!emailOk(f.email)) e.email = t('auth.err.email'); else if (!domainOk(f.email)) e.email = t('auth.err.domain'); if (!f.password) e.password = t('auth.err.required'); else if (f.password.length < 8) e.password = t('auth.err.password'); set({ errors: e }); if (Object.keys(e).length) { const first = document.getElementById(e.email ? 'login-email' : 'login-password'); first && first.focus(); return false; } return true; };
    const login = (email, password) => run(async () => {
      if (locked > 0) { app.openDialog('DLG-02'); return; }
      if (!app.requireOnline()) return;
      await app.api(null, { delay: 900 });
      const u = Object.values(app.state.users).find((x) => x.email.toLowerCase() === email.toLowerCase());
      if (!u || password !== DEMO_PASSWORD) { const n = app.dispatch('session.failedAttempt'); set({ errors: { password: t('auth.err.wrong') }, shake: true }); setTimeout(() => set({ shake: false }), 450); app.toast('TST-01'); if (n >= 5) app.openDialog('DLG-02'); return; }
      set({ errors: {}, password: '' }); auth.afterLogin(u.id);
    });
    const demo = (acc) => { const u = sel().user(acc.id); set({ email: u.email, password: DEMO_PASSWORD, errors: {} }); setTimeout(() => login(u.email, DEMO_PASSWORD), 400); };
    return html`<${Scroll} routeKey="login"><div class="row end" style="padding:4px 8px 0"><${Button} variant="ghost" size="sm" icon="languages" iconRight="chevron-down" label=${app.locale().toUpperCase()} action="AUT-01.lang" onClick=${() => app.openMenu('SHT-01', { popup: true })} /></div>
      <div class="col gap8 center" style="padding:8px 24px 24px;align-items:center"><${Logo} size=${72} /><h1 class="t-display mt8">${t('auth.login.welcome')}</h1><p class="t-body-m c-sec">${t('app.tagline')}</p></div>
      <form class=${cx('col gap16 px16', f.shake && 'shake')} onSubmit=${(e) => { e.preventDefault(); if (validate()) login(f.email, f.password); }} data-action="AUT-01.form">
        <${Input} id="login-email" label=${t('auth.email')} type="email" inputMode="email" icon="mail" value=${f.email} onInput=${(v) => set({ email: v })} placeholder="ad.soyad@ogr.gumushane.edu.tr" error=${f.errors.email} action="AUT-01.email" autofocus />
        <${Input} id="login-password" label=${t('auth.password')} type=${f.show ? 'text' : 'password'} icon="key-round" value=${f.password} onInput=${(v) => set({ password: v })} error=${f.errors.password} action="AUT-01.password" onEnter=${() => validate() && login(f.email, f.password)} trailing=${html`<${IconButton} small icon=${f.show ? 'eye-off' : 'eye'} label=${f.show ? t('auth.hidePassword') : t('auth.showPassword')} action="AUT-01.togglePassword" onClick=${() => set({ show: !f.show })} />`} />
        <div class="row end" style="margin-top:-8px"><${Button} variant="text" size="sm" label=${t('auth.forgot')} action="AUT-01.forgot" onClick=${() => app.nav.push('AUT-04')} /></div>
        <${Button} size="lg" full label=${locked > 0 ? t('auth.lockedFor', { s: locked }) : t('auth.login.cta')} loading=${busy} disabled=${locked > 0} action="AUT-01.login" onClick=${() => validate() && login(f.email, f.password)} onDisabledClick=${() => app.openDialog('DLG-02')} />
        <p class="t-body-s c-sec center">${t('auth.noAccount')} <button type="button" class="c-brand bold" data-action="AUT-01.register" onClick=${() => app.nav.push('AUT-02')}>${t('auth.register.cta')}</button></p>
      </form>
      <div class="px16 mt24"><button type="button" class="row between" style="width:100%;padding:12px 4px" aria-expanded=${f.demoOpen ? 'true' : 'false'} data-action="AUT-01.demoToggle" onClick=${() => set({ demoOpen: !f.demoOpen })}><span class="t-overline">${t('auth.demoAccounts')}</span><${Icon} name=${f.demoOpen ? 'chevron-up' : 'chevron-down'} size=${18} class="c-muted" /></button>
        ${f.demoOpen ? html`<div class="col gap8">${DEMO_ACCOUNTS.map((acc) => { const u = sel().user(acc.id); return html`<button type="button" key=${acc.id} class="account-row pressable" data-action=${'AUT-01.demoAccount.' + acc.id} onClick=${() => demo(acc)}><${Avatar} user=${u} size=${36} /><span class="flex1 col"><span class="t-label-l c-heading ellipsis">${u.name}</span><span class="t-caption">${t(acc.roleKey)} · ${t(acc.descKey)}</span></span><${Icon} name="log-in" size=${18} class="c-muted" /></button>`; })}<p class="t-caption center">${t('auth.demoPassword')}: <span class="code">${DEMO_PASSWORD}</span></p></div>` : null}</div>
      <p class="t-caption center" style="padding:24px 24px 8px">${t('auth.legalPrefix')} <button type="button" class="c-brand" data-action="AUT-01.terms" onClick=${() => app.nav.push('AUT-06', { tab: 'kosullar' })}>${t('legal.kosullar.title')}</button> ${t('common.and')} <button type="button" class="c-brand" data-action="AUT-01.privacy" onClick=${() => app.nav.push('AUT-06', { tab: 'gizlilik' })}>${t('legal.gizlilik.title')}</button> ${t('auth.legalSuffix')}</p></${Scroll}>`;
  } };

  /* AUT-02 Register */
  const strength = (p) => [p.length >= 8, /[A-ZĞÜŞİÖÇ]/.test(p), /\d/.test(p), /[^A-Za-z0-9]/.test(p)].filter(Boolean).length;
  S['AUT-02'] = { tab: null, title: 'auth.register.title', comp: function Register() {
    const [f, set] = useForm('register', { name: '', email: '', password: '', password2: '', show: false, legal: false, errors: {} }); const [busy, run] = useBusy();
    const st = strength(f.password); const rules = [[f.password.length >= 8, t('auth.rule.len')], [/[A-ZĞÜŞİÖÇ]/.test(f.password), t('auth.rule.upper')], [/\d/.test(f.password), t('auth.rule.digit')]];
    const submit = () => run(async () => {
      const e = {}; if (!f.name.trim()) e.name = t('auth.err.required'); if (!f.email) e.email = t('auth.err.required'); else if (!emailOk(f.email)) e.email = t('auth.err.email'); else if (!domainOk(f.email)) e.email = t('auth.err.domain'); else if (Object.values(app.state.users).some((u) => u.email.toLowerCase() === f.email.toLowerCase())) e.email = t('auth.err.exists');
      if (st < 3) e.password = t('auth.err.password'); if (f.password2 !== f.password) e.password2 = t('auth.err.mismatch'); if (!f.legal) e.legal = t('auth.err.legal');
      set({ errors: e }); if (Object.keys(e).length) { const id = Object.keys(e)[0]; const el = document.getElementById('reg-' + id); el && el.focus(); return; }
      if (!app.requireOnline()) return; await app.api(null, { delay: 900 });
      const id = app.dispatch('user.register', { name: f.name.trim(), email: f.email.trim() }); app.dispatch('session.login', { userId: id }); app.nav.resetTo('AUT-03');
    });
    return html`<${AppBar} onBack=${() => app.nav.back()} backAction="AUT-02.back" title=${t('auth.register.title')}><${Button} variant="ghost" size="sm" icon="languages" label=${app.locale().toUpperCase()} action="AUT-02.lang" onClick=${() => app.openMenu('SHT-01', { popup: true })} /></${AppBar}>
      <${Scroll} routeKey="register"><form class="col gap16 px16 pt8" onSubmit=${(e) => { e.preventDefault(); submit(); }} data-action="AUT-02.form">
        <${Input} id="reg-name" label=${t('auth.fullName')} icon="user" value=${f.name} onInput=${(v) => set({ name: v })} error=${f.errors.name} action="AUT-02.name" autofocus />
        <${Input} id="reg-email" label=${t('auth.uniEmail')} type="email" inputMode="email" icon="mail" value=${f.email} onInput=${(v) => set({ email: v })} help=${t('auth.register.emailHelp')} error=${f.errors.email} action="AUT-02.email" placeholder="ad.soyad@ogr.gumushane.edu.tr" />
        <div class="col gap8"><${Input} id="reg-password" label=${t('auth.password')} type=${f.show ? 'text' : 'password'} icon="key-round" value=${f.password} onInput=${(v) => set({ password: v })} error=${f.errors.password} action="AUT-02.password" trailing=${html`<${IconButton} small icon=${f.show ? 'eye-off' : 'eye'} label=${f.show ? t('auth.hidePassword') : t('auth.showPassword')} action="AUT-02.togglePassword" onClick=${() => set({ show: !f.show })} />`} />
          <div class="row gap4" aria-hidden="true">${[0, 1, 2, 3].map((k) => html`<i key=${k} style=${{ flex: 1, height: '4px', borderRadius: '2px', background: k < st ? (st <= 1 ? 'var(--state-danger)' : st === 2 ? 'var(--state-warning)' : 'var(--state-success)') : 'var(--border-default)' }} />`)}</div>
          <ul class="col gap4" style="list-style:none;padding:0">${rules.map(([ok, label]) => html`<li key=${label} class=${cx('row gap6 t-body-s', ok ? 'c-success' : 'c-muted')}><${Icon} name=${ok ? 'circle-check' : 'circle-x'} size=${14} />${label}</li>`)}</ul></div>
        <${Input} id="reg-password2" label=${t('auth.passwordRepeat')} type=${f.show ? 'text' : 'password'} icon="key-round" value=${f.password2} onInput=${(v) => set({ password2: v })} error=${f.errors.password2} action="AUT-02.password2" />
        <div class="col gap6"><div class="row gap12 start" style="align-items:flex-start"><div style="padding-top:2px" id="reg-legal"><${Checkbox} checked=${f.legal} onChange=${(v) => set({ legal: v })} action="AUT-02.legalCheck" label=${t('auth.legalCheck')} /></div><p class="t-body-s c-sec flex1"><button type="button" class="c-brand" data-action="AUT-02.legal" onClick=${() => app.nav.push('AUT-06', { tab: 'kvkk', from: 'register' })}>${t('legal.kvkk.title')}</button> ${t('common.and')} <button type="button" class="c-brand" data-action="AUT-02.legalPrivacy" onClick=${() => app.nav.push('AUT-06', { tab: 'gizlilik', from: 'register' })}>${t('legal.gizlilik.title')}</button> ${t('auth.legalCheck')}</p></div>${f.errors.legal ? html`<div class="field-help is-error" role="alert"><${Icon} name="triangle-alert" size=${14} /><span>${f.errors.legal}</span></div>` : null}</div>
        <${Button} size="lg" full label=${t('auth.register.submit')} loading=${busy} action="AUT-02.submit" onClick=${submit} />
        <p class="t-body-s c-sec center">${t('auth.haveAccount')} <button type="button" class="c-brand bold" data-action="AUT-02.toLogin" onClick=${() => app.nav.resetTo('AUT-01')}>${t('auth.login.cta')}</button></p></form></${Scroll}>`;
  } };

  /* AUT-03 Verify email */
  S['AUT-03'] = { tab: null, title: 'auth.verify.title', comp: function Verify() {
    const me = app.me(); const [f, set] = useForm('verify', { tries: 0, resendAt: 0, changing: false, newEmail: '', done: false, err: '' }); const [busy, run] = useBusy(); const left = useCountdown(f.resendAt);
    const success = () => { app.dispatch('user.update', { userId: me.id, patch: { emailVerified: true } }); set({ done: true }); setTimeout(() => { if (!sel().user(me.id).profileComplete) app.nav.resetTo('AUT-05'); else auth.enterApp(true); }, 1100); };
    const confirm = () => run(async () => { if (!app.requireOnline()) return; await app.api(null, { delay: 1200 }); if (f.tries === 0) { set({ tries: 1 }); app.toast('TST-02'); return; } success(); });
    const resend = () => { if (!app.requireOnline()) return; set({ resendAt: Date.now() + 60000 }); app.toast('TST-03'); };
    if (!me) return html`<div class="empty"><${Button} label=${t('auth.login.cta')} action="AUT-03.toLogin" onClick=${() => app.nav.resetTo('AUT-01')} /></div>`;
    return html`<${Scroll} routeKey="verify"><div class="col gap16 center" style="padding:40px 24px 24px;align-items:center">
      ${f.done ? html`<${SuccessCheck} />` : html`<${Illustration} name="email-verify" size=${160} />`}
      <h1 class="t-title-l">${f.done ? t('auth.verify.success') : t('auth.verify.title')}</h1>
      <p class="t-body-m c-sec" dangerouslySetInnerHTML=${{ __html: t('auth.verify.desc', { email: `<b>${GU.escapeHtml(me.email)}</b>` }) }} />
      ${f.done ? null : html`<div class="col gap12" style="width:100%">
        <${Button} size="lg" full label=${t('auth.verify.confirm')} loading=${busy} action="AUT-03.confirm" onClick=${confirm} />
        <${Button} variant="outline" full label=${left > 0 ? t('auth.resendIn', { s: left }) : t('auth.resend')} disabled=${left > 0} action="AUT-03.resend" onClick=${resend} onDisabledClick=${() => app.toast('TST-X3', { s: left })} />
        ${f.changing ? html`<div class="row gap8 start" style="align-items:flex-end"><div class="flex1"><${Input} label=${t('auth.newEmail')} type="email" value=${f.newEmail} onInput=${(v) => set({ newEmail: v, err: '' })} error=${f.err} action="AUT-03.newEmail" autofocus /></div><${Button} label=${t('common.update')} action="AUT-03.updateEmail" onClick=${() => { if (!emailOk(f.newEmail) || !domainOk(f.newEmail)) { set({ err: t('auth.err.domain') }); return; } app.dispatch('user.update', { userId: me.id, patch: { email: f.newEmail } }); set({ changing: false, newEmail: '' }); app.toast('TST-03'); }} /></div>` : html`<${Button} variant="text" label=${t('auth.changeEmail')} action="AUT-03.changeEmail" onClick=${() => set({ changing: true })} />`}
        <${Button} variant="text" label=${t('auth.logout')} action="AUT-03.logout" onClick=${() => app.openDialog('DLG-06')} />
        <button type="button" class="t-caption c-brand center" style="padding:8px" data-action="AUT-03.demoVerify" onClick=${success}>(${t('common.demo')}) ${t('auth.verify.demoLink')}</button></div>`}</div></${Scroll}>`;
  } };

  /* AUT-04 Reset password */
  S['AUT-04'] = { tab: null, title: 'auth.reset.title', comp: function Reset() {
    const [f, set] = useForm('reset', { email: '', sent: false, err: '', resendAt: 0 }); const [busy, run] = useBusy(); const left = useCountdown(f.resendAt);
    const send = () => run(async () => { if (!f.email) { set({ err: t('auth.err.required') }); return; } if (!emailOk(f.email)) { set({ err: t('auth.err.email') }); return; } if (!app.requireOnline()) return; await app.api(); set({ sent: true, err: '', resendAt: Date.now() + 60000 }); });
    return html`<${AppBar} onBack=${() => app.nav.back()} backAction="AUT-04.back" title=${t('auth.reset.title')} /><${Scroll} routeKey="reset"><div class="col gap16 px16 pt16">
      ${f.sent ? html`<div class="col gap12 center" style="align-items:center;padding-top:24px"><${SuccessCheck} /><h2 class="t-title-m">${t('auth.reset.sentTitle')}</h2><p class="t-body-m c-sec">${t('auth.reset.sentDesc', { email: f.email })}</p><${Button} size="lg" full label=${t('auth.reset.toLogin')} action="AUT-04.toLogin" onClick=${() => app.nav.resetTo('AUT-01')} /><${Button} variant="text" label=${left > 0 ? t('auth.resendIn', { s: left }) : t('auth.resend')} disabled=${left > 0} action="AUT-04.resend" onClick=${() => { set({ resendAt: Date.now() + 60000 }); app.toast('TST-03'); }} onDisabledClick=${() => app.toast('TST-X3', { s: left })} /></div>`
      : html`<p class="t-body-m c-sec">${t('auth.reset.desc')}</p><${Input} label=${t('auth.uniEmail')} type="email" icon="mail" value=${f.email} onInput=${(v) => set({ email: v, err: '' })} error=${f.err} action="AUT-04.email" autofocus onEnter=${send} /><${Button} size="lg" full label=${t('auth.reset.send')} loading=${busy} action="AUT-04.send" onClick=${send} />`}</div></${Scroll}>`;
  } };

  /* AUT-05 Setup profile */
  S['AUT-05'] = { tab: null, title: 'auth.setup.title', comp: function Setup() {
    const me = app.me(); const [f, set] = useForm('setup', { step: 1, photo: false, department: null, year: null, interests: [], errors: {} }); const [busy, run] = useBusy();
    if (!me) return html`<div class="empty"><${Button} label=${t('auth.login.cta')} action="AUT-05.toLogin" onClick=${() => app.nav.resetTo('AUT-01')} /></div>`;
    const toggle = (id) => { if (f.interests.includes(id)) set({ interests: f.interests.filter((x) => x !== id) }); else if (f.interests.length >= 5) app.toast('TST-04'); else set({ interests: [...f.interests, id] }); };
    const next = () => { if (f.step === 2) { const e = {}; if (!f.department) e.department = t('auth.err.required'); if (!f.year) e.year = t('auth.err.required'); set({ errors: e }); if (Object.keys(e).length) return; } if (f.step === 3) { if (!f.interests.length) { set({ errors: { interests: t('auth.setup.minInterest') } }); return; } finish(); return; } set({ step: f.step + 1, errors: {} }); };
    const finish = () => run(async () => { if (!app.requireOnline()) return; await app.api(); app.dispatch('user.update', { userId: me.id, patch: { department: f.department, year: f.year, interests: f.interests, profileComplete: true } }); app.toast('TST-05', { name: me.name.split(' ')[0] }); auth.enterApp(true); });
    return html`<${AppBar} onBack=${() => app.openDialog('DLG-25', { onDiscard: () => { app.closeDialog(); auth.logout(); }, onKeep: () => app.closeDialog() })} backAction="AUT-05.close" closeIcon titleNode=${html`<div class="col gap6"><span class="t-caption">${t('auth.setup.progress', { step: f.step, total: 3 })}</span><${Stepbar} step=${f.step} total=${3} /></div>`} />
      <${Scroll} routeKey="setup"><div class="col gap16 px16 pt16">
        ${f.step === 1 ? html`<h1 class="t-title-l">${t('auth.setup.photoTitle')}</h1><p class="t-body-m c-sec">${t('auth.setup.photoDesc')}</p><div class="col gap12 center" style="align-items:center;padding:16px 0"><${Avatar} user=${me} size=${120} />${f.photo ? html`<span class="badge badge-success"><${Icon} name="circle-check" size=${12} />${t('auth.setup.photoAdded')}</span>` : null}<${Button} variant="tonal" icon="camera" label=${t('auth.setup.addPhoto')} action="AUT-05.photo" onClick=${() => app.openSheet('SHT-16', { onPick: () => set({ photo: true }) })} /><${Button} variant="text" label=${t('auth.setup.skipPhoto')} action="AUT-05.skipPhoto" onClick=${() => set({ step: 2 })} /></div>` : null}
        ${f.step === 2 ? html`<h1 class="t-title-l">${t('auth.setup.eduTitle')}</h1><p class="t-body-m c-sec">${t('auth.setup.eduDesc')}</p><${Picker} label=${t('profile.department')} icon="graduation-cap" value=${f.department ? t('dept.' + f.department) : ''} placeholder=${t('common.select')} error=${f.errors.department} action="AUT-05.department" onClick=${() => app.openSheet('SHT-02', { value: f.department, onSelect: (id) => set({ department: id, errors: { ...f.errors, department: null } }) })} /><${Picker} label=${t('profile.year')} icon="calendar-days" value=${f.year ? t('year.' + f.year) : ''} placeholder=${t('common.select')} error=${f.errors.year} action="AUT-05.year" onClick=${() => app.openSheet('SHT-03', { value: f.year, onSelect: (id) => set({ year: id, errors: { ...f.errors, year: null } }) })} />` : null}
        ${f.step === 3 ? html`<div class="row between"><h1 class="t-title-l">${t('auth.setup.interestTitle')}</h1><span class="t-label-l tnum c-muted">${f.interests.length}/5</span></div><p class="t-body-m c-sec">${t('auth.setup.interestDesc')}</p><div class="row wrap gap8">${INTERESTS.map((i) => html`<${Chip} key=${i.id} label=${t('interest.' + i.id)} selected=${f.interests.includes(i.id)} action=${'AUT-05.toggleInterest.' + i.id} onClick=${() => toggle(i.id)} />`)}</div>${f.errors.interests ? html`<div class="field-help is-error" role="alert"><${Icon} name="triangle-alert" size=${14} /><span>${f.errors.interests}</span></div>` : null}` : null}
      </div></${Scroll}>
      <${StickyCTA}>${f.step > 1 ? html`<${Button} variant="outline" label=${t('common.back')} action="AUT-05.back" onClick=${() => set({ step: f.step - 1, errors: {} })} />` : null}<${Button} label=${f.step === 3 ? t('common.finish') : t('common.continue')} loading=${busy} action=${f.step === 3 ? 'AUT-05.finish' : 'AUT-05.next'} onClick=${next} /></${StickyCTA}>`;
  } };

  /* AUT-06 Legal */
  S['AUT-06'] = { tab: null, title: 'legal.title', comp: function Legal({ params }) {
    const [tab, setTab] = useState(params.tab || 'kvkk'); const ref = useRef(); const items = [1, 2, 3, 4, 5, 6, 7];
    const jump = (n) => { const el = ref.current && ref.current.querySelector(`#legal-${tab}-${n}`); const sc = ref.current && ref.current.querySelector('.screen-scroll'); if (el && sc) sc.scrollTo({ top: el.offsetTop - 120, behavior: 'smooth' }); };
    const accept = () => { if (app.forms.register) app.forms.register = { ...app.forms.register, legal: true, errors: { ...(app.forms.register.errors || {}), legal: null } }; app.nav.back(); };
    return html`<div ref=${ref} class="col flex1" style="min-height:0"><${AppBar} onBack=${() => app.nav.back()} backAction="AUT-06.back" title=${t('legal.title')} />
      <${Tabs} tabs=${['kvkk', 'gizlilik', 'kosullar'].map((id) => ({ id, label: t('legal.' + id + '.short') }))} value=${tab} onChange=${(v) => setTab(v)} action="AUT-06.tab" />
      <div class="hscroll py8" style="flex:none">${items.map((n) => html`<${Chip} key=${n} label=${`${n}. ${t(`legal.${tab}.h${n}`)}`} action=${'AUT-06.jump.' + n} onClick=${() => jump(n)} />`)}</div>
      <${Scroll} routeKey=${'legal-' + tab}><div class="col gap16 px16 pb16"><h1 class="t-title-l">${t('legal.' + tab + '.title')}</h1><p class="t-caption">${t('legal.updated')}</p>${items.map((n) => html`<section key=${n} id=${`legal-${tab}-${n}`} class="col gap4"><h2 class="t-title-s">${n}. ${t(`legal.${tab}.h${n}`)}</h2><p class="t-body-m c-sec">${t(`legal.${tab}.b${n}`)}</p></section>`)}</div></${Scroll}>
      ${params.from === 'register' ? html`<${StickyCTA}><${Button} full label=${t('legal.accept')} action="AUT-06.accept" onClick=${accept} /></${StickyCTA}>` : null}</div>`;
  } };
})();

/* ===== CARDS ===== domain cards: club, event, post (+poll), notification row, member & application rows */
(function () {
  const { html, cx, Icon, app, useState, useRef, Avatar, AvatarGroup, Cover, Button, IconButton, Badge, RoleBadge, StatusBadge, Card, Tile, Progress, DateBadge, Checkbox, PopMenu } = GU;
  const t = (k, p) => app.t(k, p); const sel = () => app.sel;

  const placeName = (ev) => (ev.placeId ? t('place.' + ev.placeId) : ev.placeText || t('event.placeTbd'));
  const catName = (club) => t('cat.' + club.categoryId);
  const deptYear = (u) => [u.department ? t('dept.' + u.department) : null, u.year ? t('year.' + u.year) : null].filter(Boolean).join(' · ');
  const userName = (u) => (u ? u.name : t('common.deletedUser'));

  /** starts the join flow for a club from any screen (section 2.4 / SHT-05 rules) */
  function startJoin(clubId) {
    const club = sel().club(clubId); const u = app.uid(); const m = sel().membership(clubId, u);
    if (!club.applicationsOpen) { app.toast('TST-X1'); return; }
    if (m && m.retryAfter && m.retryAfter > Date.now()) { app.nav.push('CLB-05', { id: clubId }); return; }
    if (!club.approvalRequired) { if (!app.requireOnline()) return; app.flows.join(clubId); return; }
    app.openSheet('SHT-05', { clubId });
  }
  function ClubCTA({ club, screen, size = 'md', full }) {
    const u = app.uid(); const mode = sel().mode(club.id, u); const go = () => app.nav.push('CLB-03', { id: club.id }); const status = () => app.nav.push('CLB-05', { id: club.id });
    if (club.status === 'suspended') return html`<${Badge} kind="danger" icon="ban" label=${t('status.suspended')} />`;
    if (mode === 'visitor') return club.applicationsOpen ? html`<${Button} size=${size} full=${full} label=${t('clubs.card.join')} action=${`${screen}.join.${club.id}`} onClick=${() => startJoin(club.id)} />` : html`<${Button} size=${size} full=${full} variant="outline" disabled label=${t('clubs.card.closed')} action=${`${screen}.join.${club.id}`} onDisabledClick=${() => app.toast('TST-X1')} />`;
    if (mode === 'pending') return html`<${Button} size=${size} full=${full} variant="tonal" icon="hourglass" label=${t('clubs.card.pending')} action=${`${screen}.status.${club.id}`} onClick=${status} />`;
    if (mode === 'rejected') return html`<${Button} size=${size} full=${full} variant="tonal" icon="circle-x" label=${t('clubs.card.rejected')} action=${`${screen}.status.${club.id}`} onClick=${status} class="c-danger" />`;
    if (mode === 'removed') return html`<${Button} size=${size} full=${full} variant="tonal" icon="user-x" label=${t('clubs.card.removed')} action=${`${screen}.status.${club.id}`} onClick=${status} />`;
    return html`<span class="row gap8">${mode === 'manager' ? html`<${Badge} kind="president" icon="shield-check" label=${t('clubs.card.manager')} />` : mode === 'advisor' ? html`<${RoleBadge} role="advisor" />` : null}<${Button} size=${size} full=${full} variant="outline" label=${t('clubs.card.open')} action=${`${screen}.open.${club.id}`} onClick=${go} /></span>`;
  }
  function ClubCard({ club, screen = 'CLB-01', grid, highlight }) {
    const members = sel().clubMembers(club.id).map((m) => m.user); const u = app.uid(); const mode = sel().mode(club.id, u);
    if (grid) return html`<${Card} tappable action=${`${screen}.card.${club.id}`} onClick=${() => app.nav.push('CLB-03', { id: club.id })} label=${club.name} highlight=${highlight}>
      <${Cover} seed=${club.coverSeed} icon=${club.iconName} palette=${club.palette} pattern=${club.pattern} ratio="3-2"><span class="emblem is-xs" style="position:absolute;left:10px;bottom:10px;background:var(--bg-surface)"><${Icon} name=${club.iconName} size=${16} /></span>${mode !== 'visitor' ? html`<span style="position:absolute;right:8px;top:8px"><${StatusBadge} status=${mode === 'pending' ? 'pending' : mode === 'rejected' ? 'rejected' : 'active'} label=${mode === 'pending' ? t('status.pending') : mode === 'rejected' ? t('status.rejected') : t('clubs.card.memberShort')} /></span>` : null}</${Cover}>
      <div class="col gap6" style="padding:10px 12px 12px"><span class="t-title-s clamp2">${club.name}</span><span class="t-caption">${catName(club)} · ${t('clubs.card.members', { count: club.memberCount })}</span><div style="display:flex" onClick=${(e) => e.stopPropagation()}><${ClubCTA} club=${club} screen=${screen} size="sm" full /></div></div></${Card}>`;
    return html`<${Card} tappable action=${`${screen}.card.${club.id}`} onClick=${() => app.nav.push('CLB-03', { id: club.id })} label=${club.name} highlight=${highlight}>
      <${Cover} seed=${club.coverSeed} icon=${club.iconName} palette=${club.palette} pattern=${club.pattern} ratio="16-9">${club.status === 'suspended' ? html`<span style="position:absolute;left:12px;top:12px"><${Badge} kind="danger" icon="ban" label=${t('status.suspended')} /></span>` : null}</${Cover}>
      <div class="card-body col gap8" style="padding-top:12px">
        <div class="row gap12 start"><span class="emblem is-sm"><${Icon} name=${club.iconName} size=${22} /></span><div class="flex1 col gap4"><h3 class="t-title-s clamp2">${club.name}</h3><div class="row gap6 wrap"><${Badge} kind="neutral" label=${catName(club)} /><span class="t-caption tnum row gap4"><${Icon} name="users" size=${14} />${t('clubs.card.members', { count: club.memberCount })}</span></div></div></div>
        <p class="t-body-s c-sec clamp2">${club.summary} ${club.about}</p>
        <div class="row between gap8"><span class="row gap6"><${AvatarGroup} users=${members.slice(0, 3)} size=${24} total=${club.memberCount} /><span class="t-caption">${club.approvalRequired ? t('club.type.approval') : t('club.type.instant')}</span></span><span onClick=${(e) => e.stopPropagation()}><${ClubCTA} club=${club} screen=${screen} size="sm" /></span></div>
      </div></${Card}>`;
  }
  function MyClubChip({ club, screen = 'CLB-01', unread, manager }) {
    return html`<button type="button" class="card is-tappable pressable" style="width:132px;text-align:left" data-action=${`${screen}.myClub.${club.id}`} onClick=${() => app.nav.push('CLB-03', { id: club.id })} aria-label=${club.name}>
      <${Cover} seed=${club.coverSeed} icon=${club.iconName} palette=${club.palette} pattern=${club.pattern} ratio="16-9">${manager ? html`<span style="position:absolute;left:6px;top:6px"><${Badge} kind="president" icon="shield-check" label=${t('clubs.card.manager')} /></span>` : null}${club.status === 'suspended' ? html`<span style="position:absolute;left:6px;top:6px"><${Badge} kind="danger" icon="ban" label=${t('status.suspended')} /></span>` : null}</${Cover}>
      <div class="row gap6" style="padding:8px 10px 10px"><span class="t-label-m c-heading clamp2 flex1">${club.name}</span>${unread ? html`<span class="dot" aria-label=${t('clubs.my.unread')} />` : null}</div></button>`;
  }

  /* events */
  function eventStatusFor(ev, u) {
    const r = sel().myRsvp(ev.id, u); const past = ev.endsAt < Date.now();
    if (ev.status === 'cancelled') return 'cancelled';
    if (ev.status === 'draft') return 'draft';
    if (past) { if (r && r.status === 'attended') return 'attended'; if (r && (r.status === 'going')) return 'absent'; return 'past'; }
    if (r) { if (r.status === 'waitlist') return 'waitlist'; if (r.status === 'going' || r.status === 'attended') return 'going'; }
    if (ev.visibility === 'members' && !sel().canSeeInside(ev.clubId, u)) return 'members';
    if (sel().isFull(ev)) return 'full';
    return null;
  }
  function eventQuickAction(ev, screen) {
    const u = app.uid(); const st = eventStatusFor(ev, u); const nav = app.nav;
    if (st === 'going') return { label: t('event.cta.ticket'), variant: 'tonal', icon: 'ticket', run: () => nav.push('EVT-03', { id: ev.id }) };
    if (st === 'attended' || st === 'absent' || st === 'past' || st === 'cancelled') return null;
    if (st === 'members') return { label: t('event.cta.applyClub'), variant: 'outline', icon: 'lock', run: () => nav.push('CLB-03', { id: ev.clubId }) };
    if (st === 'waitlist') return { label: t('status.waitlist'), variant: 'tonal', icon: 'hourglass', run: () => nav.push('EVT-02', { id: ev.id }) };
    if (st === 'full') return { label: t('event.cta.waitlist'), variant: 'outline', run: () => { if (!app.requireOnline()) return; app.openDialog('DLG-15', { eventId: ev.id }); } };
    if (!ev.registrationOpen) return { label: t('event.cta.closed'), variant: 'outline', disabled: true, run: () => app.toast('TST-X2') };
    return { label: t('event.cta.join'), variant: 'primary', run: () => { if (!app.requireOnline()) return; app.openSheet('SHT-12', { eventId: ev.id }); } };
  }
  function EventCard({ ev, screen = 'EVT-01', compact, showClub = true, highlight }) {
    const club = sel().club(ev.clubId); const u = app.uid(); const st = eventStatusFor(ev, u); const reg = sel().registered(ev.id).length; const quick = eventQuickAction(ev, screen);
    return html`<${Card} tappable action=${`${screen}.card.${ev.id}`} onClick=${() => app.nav.push('EVT-02', { id: ev.id })} label=${ev.title} highlight=${highlight}>
      <div class="row gap12 start" style="padding:12px">
        <div class="col gap8" style="align-items:center"><${DateBadge} ts=${ev.startsAt} />${!compact ? html`<${Cover} seed=${ev.coverSeed} icon=${club ? club.iconName : 'calendar'} palette=${ev.coverPalette} pattern=${ev.coverPattern} ratio="1-1" style=${{ width: '48px', borderRadius: '10px' }} />` : null}</div>
        <div class="flex1 col gap4">
          <div class="row gap6 start"><h3 class="t-title-s clamp2 flex1">${ev.title}</h3>${st ? html`<${StatusBadge} status=${st} />` : null}</div>
          ${showClub && club ? html`<button type="button" class="t-caption c-brand ellipsis" style="text-align:left" data-action=${`${screen}.club.${ev.id}`} onClick=${(e) => { e.stopPropagation(); app.nav.push('CLB-03', { id: club.id }); }}>${club.name}</button>` : null}
          <span class="t-body-s c-sec row gap4"><${Icon} name="clock" size=${14} />${app.fmt.time(ev.startsAt)} · <${Icon} name="map-pin" size=${14} /><span class="ellipsis">${placeName(ev)}</span></span>
          ${ev.capacity != null ? html`<div class="row gap8"><${Progress} value=${reg} max=${ev.capacity} kind=${reg >= ev.capacity ? 'muted' : reg / ev.capacity > 0.85 ? 'warning' : undefined} thin label=${t('event.capacity')} /><span class="t-caption tnum">${reg}/${ev.capacity}</span></div>` : html`<span class="t-caption">${t('event.unlimited')} · ${t('event.registeredCount', { count: reg })}</span>`}
          ${quick ? html`<div class="row end" onClick=${(e) => e.stopPropagation()}><${Button} size="sm" variant=${quick.variant} icon=${quick.icon} label=${quick.label} disabled=${quick.disabled} action=${`${screen}.join.${ev.id}`} onClick=${quick.run} onDisabledClick=${quick.run} /></div>` : null}
        </div></div></${Card}>`;
  }

  /* posts */
  function PollBlock({ post, screen }) {
    const u = app.uid(); const poll = post.poll; const total = poll.options.reduce((a, o) => a + o.votes.length, 0); const mine = poll.options.find((o) => o.votes.includes(u)); const ended = poll.endsAt < Date.now(); const showResults = !!mine || ended || !poll.showResultsAfterVote;
    const vote = (oid) => { if (mine) { app.toast('TST-10'); return; } if (ended) return; if (sel().isAdvisor(post.clubId, u)) { app.toast('TST-26'); return; } if (!app.requireOnline()) return; app.dispatch('post.vote', { postId: post.id, userId: u, optionId: oid }); app.toast('TST-10'); };
    return html`<div class="col gap6" onClick=${(e) => e.stopPropagation()}>
      ${poll.options.map((o) => { const pct = total ? Math.round((o.votes.length / total) * 100) : 0; return html`<button type="button" key=${o.id} class=${cx('poll-opt', mine && mine.id === o.id && 'is-mine')} aria-pressed=${mine && mine.id === o.id ? 'true' : 'false'} aria-disabled=${ended || mine ? 'true' : undefined} data-action=${`${screen}.vote.${post.id}.${o.id}`} onClick=${() => vote(o.id)}>
        ${showResults ? html`<span class="poll-fill" style=${{ width: pct + '%' }} />` : null}
        <span class="row between gap8"><span class="row gap6 t-body-s c-heading">${mine && mine.id === o.id ? html`<${Icon} name="circle-check" size=${16} class="c-brand" />` : null}${o.text}</span>${showResults ? html`<span class="t-label-m tnum">%${pct}</span>` : null}</span></button>`; })}
      <span class="t-caption row gap6"><${Icon} name="chart-column" size=${14} />${t('feed.poll.votes', { count: total })} · ${ended ? t('feed.poll.ended') : t('feed.poll.remaining', { time: app.fmt.countdown(poll.endsAt) })}</span></div>`;
  }
  function ImageGrid({ images, post, screen, onOpen }) {
    const club = sel().club(post.clubId); const n = Math.min(4, images.length);
    return html`<div class=${cx('img-grid', 'n' + n)} onClick=${(e) => e.stopPropagation()}>${images.slice(0, 4).map((seed, i) => html`<button type="button" key=${seed} aria-label=${t('a11y.openImage', { n: i + 1 })} data-action=${`${screen}.image.${post.id}.${i}`} onClick=${() => (onOpen ? onOpen(i) : app.ui.openViewer({ images, index: i, post }))}><span style="position:absolute;inset:0" dangerouslySetInnerHTML=${{ __html: GU.coverArtSVG(seed, club ? club.iconName : 'image', club ? club.palette : 'slate', undefined, { w: 400, h: 400 }) }} /></button>`)}</div>`;
  }
  function PostCard({ post, screen = 'FED-01', expanded, showClub, highlight, hideActions }) {
    const u = app.uid(); const author = sel().user(post.authorId); const club = sel().club(post.clubId); const role = author ? sel().roleIn(post.clubId, author.id) : null; const [more, setMore] = useState(!!expanded); const [popped, setPopped] = useState(false);
    const liked = post.likes.includes(u); const saved = sel().isSaved(u, post.id); const canInteract = !sel().isAdvisor(post.clubId, u);
    const open = () => app.nav.push('FED-02', { clubId: post.clubId, postId: post.id });
    const like = (e) => { e.stopPropagation(); if (!canInteract) { app.toast('TST-26'); return; } if (!app.requireOnline()) return; const snap = app.store.get(); app.dispatch('post.like', { postId: post.id, userId: u }); setPopped(true); setTimeout(() => setPopped(false), 400); app.api(null, { allowOffline: false }).catch(() => { app.store.restore(snap); app.toast('TST-24'); }); };
    const save = (e) => { e.stopPropagation(); const snap = app.store.get(); const nowSaved = app.dispatch('post.save', { postId: post.id, userId: u }); app.toast('TST-11', { saved: nowSaved, undo: () => app.store.restore(snap) }); };
    const share = (e) => { e.stopPropagation(); app.openSheet('SHT-15', { type: 'post', id: post.id }); };
    const comment = (e) => { e.stopPropagation(); if (expanded) return; app.openSheet('SHT-09', { postId: post.id }); };
    const menu = (e) => { e.stopPropagation(); app.openSheet('SHT-08', { postId: post.id }); };
    const long = post.text.length > 280;
    return html`<article class=${cx('card', highlight && 'is-highlight')} aria-label=${post.title || post.text.slice(0, 40)}>
      ${post.pinned ? html`<div class="row gap4 t-caption" style="padding:10px 16px 0"><${Icon} name="pin" size=${14} />${t('feed.pinned')}</div>` : null}
      <div class="row gap10 start" style="padding:12px 8px 0 16px;gap:10px">
        <button type="button" class="row gap10 flex1" style="text-align:left;gap:10px" data-action=${`${screen}.author.${post.id}`} onClick=${() => author && app.nav.push('CLB-07', { id: author.id, clubId: post.clubId })} aria-label=${userName(author)}>
          <${Avatar} user=${author} size=${40} /><span class="flex1 col"><span class="row gap6 wrap"><span class="t-label-l c-heading ellipsis" style="max-width:170px">${userName(author)}</span>${role ? html`<${RoleBadge} role=${role} />` : null}</span><span class="t-caption">${showClub && club ? club.name + ' · ' : ''}${app.fmt.rel(post.createdAt)}${post.editedAt ? ' · ' + t('feed.edited') : ''}</span></span></button>
        <${IconButton} icon="more-horizontal" label=${t('a11y.more')} action=${`${screen}.menu.${post.id}`} onClick=${menu} />
      </div>
      <div class="col gap10" style="padding:10px 16px 12px">
        ${post.type === 'announcement' ? html`<span class="row gap6"><${Badge} kind="president" icon="megaphone" label=${t('feed.type.announcement')} />${post.pushSent ? html`<span class="t-caption row gap4"><${Icon} name="bell-ring" size=${12} />${t('feed.pushSent')}</span>` : null}</span>` : post.type === 'poll' ? html`<${Badge} kind="info" icon="chart-column" label=${t('feed.type.poll')} />` : null}
        ${post.title ? html`<h3 class="t-title-s">${post.title}</h3>` : null}
        <div role=${expanded ? undefined : 'button'} tabindex=${expanded ? undefined : '0'} data-action=${`${screen}.post.${post.id}`} onClick=${expanded ? undefined : open} onKeyDown=${(e) => { if (!expanded && e.key === 'Enter') open(); }} style=${expanded ? undefined : { cursor: 'pointer' }}>
          <p class=${cx('t-body-m prewrap break', !more && long && 'clamp5')}>${post.text}</p>
          ${long && !more ? html`<button type="button" class="t-label-l c-brand mt4" data-action=${`${screen}.more.${post.id}`} onClick=${(e) => { e.stopPropagation(); setMore(true); }}>${t('common.readMore')}</button>` : null}
        </div>
        ${post.images && post.images.length ? html`<${ImageGrid} images=${post.images} post=${post} screen=${screen} />` : null}
        ${post.poll ? html`<${PollBlock} post=${post} screen=${screen} />` : null}
        ${hideActions ? null : html`<div class="row between" style="margin:0 -8px -4px">
          <span class="row gap2">
            <button type="button" class="iconbtn" style="width:auto;padding:0 10px;gap:6px;border-radius:12px" aria-pressed=${liked ? 'true' : 'false'} aria-label=${t('feed.like')} data-action=${`${screen}.like.${post.id}`} onClick=${like}><${Icon} name="heart" size=${22} class=${cx('heart', liked && 'is-liked', popped && 'is-liked')} style=${liked ? { fill: 'currentColor' } : undefined} /><span class="t-label-m tnum">${post.likes.length || ''}</span></button>
            <button type="button" class="iconbtn" style="width:auto;padding:0 10px;gap:6px;border-radius:12px" aria-label=${t('feed.comment')} data-action=${`${screen}.comment.${post.id}`} onClick=${comment}><${Icon} name="message-circle" size=${22} /><span class="t-label-m tnum">${post.commentIds.filter((id) => { const c = app.state.comments[id]; return c && !c.deleted && !c.hidden; }).length || ''}</span></button>
            <${IconButton} icon="share-2" label=${t('common.share')} action=${`${screen}.share.${post.id}`} onClick=${share} />
          </span>
          <button type="button" class="iconbtn" aria-pressed=${saved ? 'true' : 'false'} aria-label=${saved ? t('feed.unsave') : t('feed.save')} data-action=${`${screen}.save.${post.id}`} onClick=${save}><${Icon} name="bookmark" size=${22} class=${saved ? 'c-brand' : ''} style=${saved ? { fill: 'currentColor' } : undefined} /></button>
        </div>`}
      </div></article>`;
  }

  /* notifications */
  const NOTIF_ICON = { application_received: ['user-plus', 'ni-brand'], application_approved: ['circle-check', 'ni-success'], application_rejected: ['circle-x', 'ni-danger'], removed_from_club: ['user-x', 'ni-danger'], role_changed: ['user-cog', 'ni-info'], announcement: ['megaphone', 'ni-brand'], event_new: ['calendar-plus', 'ni-info'], event_reminder: ['bell-ring', 'ni-warning'], event_cancelled: ['calendar-x', 'ni-danger'], waitlist_promoted: ['ticket', 'ni-success'], report_resolved: ['shield-check', 'ni-success'], new_report: ['flag', 'ni-warning'], system: ['info', 'ni-neutral'] };
  const NOTIF_CAT = { application_received: 'clubs', application_approved: 'clubs', application_rejected: 'clubs', removed_from_club: 'clubs', role_changed: 'clubs', announcement: 'clubs', report_resolved: 'clubs', new_report: 'clubs', event_new: 'events', event_reminder: 'events', event_cancelled: 'events', waitlist_promoted: 'events', system: 'system' };
  function notifParams(n) { const r = n.refs || {}; const st = app.state; const club = r.clubId ? st.clubs[r.clubId] : null; const ev = r.eventId ? st.events[r.eventId] : null; const post = r.postId ? st.posts[r.postId] : null; const user = r.applicantId ? st.users[r.applicantId] : null; return { club: club ? club.name : '', event: ev ? ev.title : '', post: post ? post.title || post.text.slice(0, 60) : '', user: user ? user.name : '', role: r.role ? t('role.' + r.role) : '', time: ev ? app.fmt.time(ev.startsAt) : '', reason: ev && ev.cancelReason ? t('cancelReason.' + ev.cancelReason) : '' }; }
  function notifTitle(n) { if (n.type === 'system') return t('notifType.system.' + (n.refs.textKey || 'welcome') + '.title'); return t(`notifType.${n.type}.title`, notifParams(n)); }
  function notifBody(n) { if (n.type === 'system') return t('notifType.system.' + (n.refs.textKey || 'welcome') + '.body'); return t(`notifType.${n.type}.body`, notifParams(n)); }
  function NotificationRow({ n, screen = 'NTF-01' }) {
    const [dx, setDx] = useState(0); const start = useRef(null); const timer = useRef(null); const [menu, setMenu] = useState(false); const moved = useRef(false);
    const [icon, cls] = NOTIF_ICON[n.type] || NOTIF_ICON.system;
    const del = () => { const snap = n; app.dispatch('notif.delete', { id: n.id }); app.toast('TST-16', { undo: () => app.dispatch('notif.restore', { notification: snap }) }); };
    const toggleRead = () => app.dispatch('notif.read', { id: n.id, read: !n.read });
    const onDown = (e) => { start.current = e.clientX; moved.current = false; timer.current = setTimeout(() => { setMenu(true); moved.current = true; }, 550); };
    const onMove = (e) => { if (start.current == null) return; const d = e.clientX - start.current; if (Math.abs(d) > 8) { clearTimeout(timer.current); moved.current = true; setDx(Math.max(-140, Math.min(140, d))); } };
    const onUp = () => { clearTimeout(timer.current); if (start.current == null) return; if (dx < -90) { setDx(0); del(); GU.registry.record(`${screen}.swipeDelete.${n.id}`, 'toast'); } else if (dx > 90) { setDx(0); toggleRead(); GU.registry.record(`${screen}.swipeRead.${n.id}`, 'state'); } else setDx(0); start.current = null; };
    const tap = () => { if (moved.current) return; app.flows.openNotification(n); };
    return html`<div class="notif-row">
      <div class="notif-under"><span class=${cx('row gap6', dx > 0 ? '' : 'hidden-vis')} style="color:var(--state-info)"><${Icon} name=${n.read ? 'bell-ring' : 'check'} size=${18} />${n.read ? t('notif.markUnread') : t('notif.markRead')}</span><span class=${cx('row gap6', dx < 0 ? '' : 'hidden-vis')} style="color:var(--state-danger)">${t('common.delete')}<${Icon} name="trash-2" size=${18} /></span></div>
      <div class="notif-front" style=${{ transform: `translateX(${dx}px)` }} onPointerDown=${onDown} onPointerMove=${onMove} onPointerUp=${onUp} onPointerCancel=${onUp} data-action=${`${screen}.swipe.${n.id}`}>
        <button type="button" class="tile" style="align-items:flex-start;padding:12px 16px" data-action=${`${screen}.item.${n.id}`} onClick=${tap} onContextMenu=${(e) => { e.preventDefault(); setMenu(true); }} aria-label=${notifTitle(n)}>
          <span class=${cx('notif-icon', cls)}><${Icon} name=${icon} size=${20} /></span>
          <span class="tile-text col gap2"><span class=${cx('t-body-m', n.read ? 'c-heading' : 'c-heading bold')}>${notifTitle(n)}</span><span class="t-body-s c-sec clamp2">${notifBody(n)}</span><span class="t-caption">${app.fmt.rel(n.createdAt)}</span></span>
          ${!n.read ? html`<span class="dot" style="margin-top:8px" aria-label=${t('notif.unread')} />` : null}
        </button></div>
      ${menu ? html`<${PopMenu} id=${screen} onClose=${() => setMenu(false)}>
        <${Tile} title=${n.read ? t('notif.markUnread') : t('notif.markRead')} leading=${html`<${Icon} name="check" size=${20} />`} action=${`${screen}.menu.${n.id}.read`} onClick=${() => { setMenu(false); toggleRead(); }} />
        <${Tile} title=${t('common.delete')} leading=${html`<${Icon} name="trash-2" size=${20} />`} action=${`${screen}.menu.${n.id}.delete`} onClick=${() => { setMenu(false); del(); }} danger />
        <${Tile} title=${t('notif.muteType')} leading=${html`<${Icon} name="bell-off" size=${20} />`} action=${`${screen}.menu.${n.id}.mute`} onClick=${() => { setMenu(false); const key = { announcement: 'announcements', event_reminder: 'eventReminders', event_new: 'newEvents', application_approved: 'applicationResults', application_rejected: 'applicationResults', application_received: 'management', new_report: 'management', system: 'system' }[n.type] || 'system'; app.dispatch('settings.update', { userId: app.uid(), patch: { [key]: false } }); app.toast('TST-19'); }} />
      </${PopMenu}>` : null}
    </div>`;
  }

  /* members & applications */
  function MemberRow({ m, screen, onMenu, menuAction, sub, trailing, showRate, clubId }) {
    const u = m.user; const rate = showRate ? sel().attendanceRate(clubId || m.clubId, u.id) : null;
    return html`<${Tile} leading=${html`<${Avatar} user=${u} size=${40} />`} title=${html`<span class="row gap6 wrap"><span class="ellipsis" style="max-width:190px">${u.name}</span><${RoleBadge} role=${m.role} /></span>`} subtitle=${sub || deptYear(u)} sub2=${rate != null ? html`<span class="row gap6"><${Progress} value=${rate} max=${100} thin kind="success" label=${t('mgtMembers.rate')} /><span class="tnum">%${rate}</span></span>` : null}
      trailing=${trailing !== undefined ? trailing : onMenu ? html`<${IconButton} icon="more-vertical" label=${t('a11y.more')} action=${menuAction || `${screen}.menu.${u.id}`} onClick=${(e) => { e.stopPropagation(); onMenu(); }} />` : null} action=${`${screen}.member.${u.id}`} onClick=${() => app.nav.push('CLB-07', { id: u.id, clubId: clubId || m.clubId })} />`;
  }
  function ApplicationRow({ m, screen = 'MGT-02', selecting, selected, onSelect, onApprove, onReject, onOpen, readOnly }) {
    const u = m.user;
    return html`<div class="row gap8" style="padding:6px 8px 6px 16px;min-height:64px;position:relative">
      ${selecting ? html`<${Checkbox} checked=${selected} onChange=${onSelect} action=${`${screen}.select.${u.id}`} label=${u.name} />` : null}
      <button type="button" class="row gap12 flex1 start" style="text-align:left;padding:4px 0" data-action=${`${screen}.row.${u.id}`} onClick=${onOpen} onContextMenu=${(e) => { e.preventDefault(); onSelect && onSelect(true); }}>
        <${Avatar} user=${u} size=${44} /><span class="flex1 col gap2"><span class="row gap6"><span class="t-label-l c-heading ellipsis" style="max-width:170px">${u.name}</span>${m.priorCount ? html`<${Badge} kind="neutral" icon="history" label=${t('applications.prior')} />` : null}</span><span class="t-body-s c-muted ellipsis">${deptYear(u)}</span>${m.note ? html`<span class="t-body-s c-sec clamp1" style="font-style:italic">“${m.note}”</span>` : html`<span class="t-caption">${t('applications.noNote')}</span>`}<span class="t-caption">${app.fmt.rel(m.appliedAt)}</span></span></button>
      ${!selecting ? html`<span class="row gap2"><${IconButton} icon="check" label=${t('applications.approve')} action=${`${screen}.approve.${u.id}`} onClick=${onApprove} disabled=${readOnly} onDisabledClick=${() => app.toast('TST-26')} style=${{ color: 'var(--state-success)', background: 'var(--state-success-container)', width: '44px', height: '44px' }} /><${IconButton} icon="x" label=${t('applications.reject')} action=${`${screen}.reject.${u.id}`} onClick=${onReject} disabled=${readOnly} onDisabledClick=${() => app.toast('TST-26')} style=${{ color: 'var(--state-danger)', background: 'var(--state-danger-container)', width: '44px', height: '44px' }} /></span>` : null}
    </div>`;
  }

  Object.assign(GU, { placeName, catName, deptYear, userName, startJoin, ClubCTA, ClubCard, MyClubChip, eventStatusFor, eventQuickAction, EventCard, PollBlock, ImageGrid, PostCard, NOTIF_ICON, NOTIF_CAT, notifTitle, notifBody, NotificationRow, MemberRow, ApplicationRow });
})();

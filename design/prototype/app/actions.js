/* ===== STORE ACTIONS & SELECTORS ===== every mutation goes through store.dispatch(type, payload); selectors read derived data */
(function () {
  const { store, ret, upd, del, put, app, uid, DAY, dayKey, INTERESTS, seed } = GU;
  const now = () => Date.now();
  const mkey = (c, u) => `${c}_${u}`;
  const rkey = (e, u) => `${e}_${u}`;

  /* ---------- selectors ---------- */
  const sel = {
    club: (id) => store.state.clubs[id] || null,
    user: (id) => store.state.users[id] || null,
    event: (id) => store.state.events[id] || null,
    post: (id) => store.state.posts[id] || null,
    membership: (clubId, u) => store.state.memberships[mkey(clubId, u)] || null,
    roleIn(clubId, u) { const m = sel.membership(clubId, u); return m && m.status === 'active' ? m.role : null; },
    isManager(clubId, u) { const r = sel.roleIn(clubId, u); return r === 'board' || r === 'president'; },
    isPresident: (clubId, u) => sel.roleIn(clubId, u) === 'president',
    isAdvisor: (clubId, u) => sel.roleIn(clubId, u) === 'advisor',
    isSuper(u) { const usr = sel.user(u); return !!(usr && usr.global === 'superadmin'); },
    isMemberOf(clubId, u) { return !!sel.roleIn(clubId, u); },
    canManage: (clubId, u) => sel.isManager(clubId, u) || sel.isSuper(u),
    mode(clubId, u) {
      if (sel.isSuper(u)) return 'super';
      const m = sel.membership(clubId, u); if (!m) return 'visitor';
      if (m.status === 'pending') return 'pending'; if (m.status === 'rejected') return 'rejected'; if (m.status === 'removed') return 'removed';
      if (m.status === 'active') { if (m.role === 'advisor') return 'advisor'; if (m.role === 'board' || m.role === 'president') return 'manager'; return 'member'; }
      return 'visitor';
    },
    canSeeInside(clubId, u) { const md = sel.mode(clubId, u); return ['member', 'manager', 'advisor', 'super'].includes(md); },
    myMemberships(u) { return Object.values(store.state.memberships).filter((m) => m.userId === u); },
    myClubs(u) { return sel.myMemberships(u).filter((m) => m.status === 'active').map((m) => ({ ...m, club: store.state.clubs[m.clubId] })).filter((m) => m.club); },
    managedClubs(u) { return sel.myMemberships(u).filter((m) => m.status === 'active' && ['board', 'president', 'advisor'].includes(m.role) && store.state.clubs[m.clubId]).map((m) => ({ ...m, club: store.state.clubs[m.clubId], readOnly: m.role === 'advisor' })); },
    pendingOf(u) { return sel.myMemberships(u).filter((m) => m.status === 'pending'); },
    clubMembers(clubId) { return Object.values(store.state.memberships).filter((m) => m.clubId === clubId && m.status === 'active' && store.state.users[m.userId] && !store.state.users[m.userId].deleted).map((m) => ({ ...m, user: store.state.users[m.userId] })); },
    board(clubId) { return sel.clubMembers(clubId).filter((m) => m.role === 'board' || m.role === 'president').sort((a, b) => (a.role === 'president' ? -1 : 1)); },
    apps(clubId, status) { return Object.values(store.state.memberships).filter((m) => m.clubId === clubId && m.status === status && m.role === 'member' && store.state.users[m.userId]).map((m) => ({ ...m, user: store.state.users[m.userId] })); },
    pendingApps: (clubId) => sel.apps(clubId, 'pending').sort((a, b) => b.appliedAt - a.appliedAt),
    approvedApps: (clubId) => sel.apps(clubId, 'active').filter((m) => m.decidedAt).sort((a, b) => b.decidedAt - a.decidedAt),
    rejectedApps: (clubId) => sel.apps(clubId, 'rejected').sort((a, b) => b.decidedAt - a.decidedAt),
    visibleClubs() { return Object.values(store.state.clubs).filter((c) => c.status === 'active'); },
    allClubs() { return Object.values(store.state.clubs); },
    canSeeEvent(ev, u) { if (!ev) return false; if (ev.status === 'draft') return sel.canManage(ev.clubId, u); if (ev.visibility === 'public') return true; return sel.canSeeInside(ev.clubId, u); },
    eventRsvps(eventId) { return Object.values(store.state.rsvps).filter((r) => r.eventId === eventId); },
    registered(eventId) { return sel.eventRsvps(eventId).filter((r) => r.status === 'going' || r.status === 'attended'); },
    waitlist(eventId) { return sel.eventRsvps(eventId).filter((r) => r.status === 'waitlist').sort((a, b) => (a.waitlistAt || a.createdAt) - (b.waitlistAt || b.createdAt)); },
    attended(eventId) { return sel.eventRsvps(eventId).filter((r) => r.status === 'attended'); },
    isFull(ev) { return ev.capacity != null && sel.registered(ev.id).length >= ev.capacity; },
    remaining(ev) { return ev.capacity == null ? Infinity : Math.max(0, ev.capacity - sel.registered(ev.id).length); },
    myRsvp: (eventId, u) => store.state.rsvps[rkey(eventId, u)] || null,
    waitPosition(eventId, u) { const wl = sel.waitlist(eventId); const i = wl.findIndex((r) => r.userId === u); return i < 0 ? 0 : i + 1; },
    userRsvps(u) { return Object.values(store.state.rsvps).filter((r) => r.userId === u && store.state.events[r.eventId]).map((r) => ({ ...r, event: store.state.events[r.eventId] })); },
    visibleEvents(u) { return Object.values(store.state.events).filter((e) => e.status !== 'draft' && store.state.clubs[e.clubId] && store.state.clubs[e.clubId].status === 'active' && sel.canSeeEvent(e, u)); },
    clubEvents(clubId) { return Object.values(store.state.events).filter((e) => e.clubId === clubId); },
    notifsFor(u) { return Object.values(store.state.notifications).filter((n) => n.userId === u).sort((a, b) => b.createdAt - a.createdAt); },
    unread: (u) => sel.notifsFor(u).filter((n) => !n.read).length,
    blockedBy(u) { const me = sel.user(u); return me ? me.blocked || [] : []; },
    clubPosts(clubId, viewer) { const blocked = sel.blockedBy(viewer); return Object.values(store.state.posts).filter((p) => p.clubId === clubId && !p.deleted && !p.hidden && !blocked.includes(p.authorId)).sort((a, b) => (b.pinned - a.pinned) || (b.createdAt - a.createdAt)); },
    allPostsOf(clubId) { return Object.values(store.state.posts).filter((p) => p.clubId === clubId && !p.deleted).sort((a, b) => b.createdAt - a.createdAt); },
    postComments(postId, viewer) { const p = store.state.posts[postId]; const blocked = sel.blockedBy(viewer); if (!p) return []; return p.commentIds.map((id) => store.state.comments[id]).filter((c) => c && !c.deleted && !c.hidden && !blocked.includes(c.authorId)); },
    savedPosts(u) { return (store.state.saved[u] || []).map((id) => store.state.posts[id]).filter(Boolean); },
    isSaved: (u, postId) => (store.state.saved[u] || []).includes(postId),
    reports(status) { return Object.values(store.state.reports).filter((r) => r.status === status).sort((a, b) => Math.max(...b.reasons.map((x) => x.createdAt)) - Math.max(...a.reasons.map((x) => x.createdAt))); },
    reportsOnTarget(type, id) { return Object.values(store.state.reports).filter((r) => r.targetType === type && r.targetId === id && r.status === 'open'); },
    dailyAnnouncements(clubId) { return store.state.dailyAnnouncementCount[`${clubId}_${dayKey(now())}`] || 0; },
    canReapply(m) { return !m || !m.retryAfter || m.retryAfter <= now(); },
    commonClubs(a, b) { const A = sel.myClubs(a).map((m) => m.clubId); return sel.myClubs(b).filter((m) => A.includes(m.clubId)).map((m) => m.club); },
    attendanceRate(clubId, u) { const past = sel.clubEvents(clubId).filter((e) => e.endsAt < now() && e.status === 'published'); const mine = past.map((e) => sel.myRsvp(e.id, u)).filter(Boolean); if (!mine.length) return null; return Math.round((mine.filter((r) => r.status === 'attended').length / mine.length) * 100); },
    settings(u) { return store.state.settings[u] || { announcements: true, eventReminders: true, newEvents: true, applicationResults: true, management: true, system: true, reminderTime: '1h', quiet: false, quietFrom: '22:00', quietTo: '08:00', clubs: {} }; },
    clubSettings(u, clubId) { return (sel.settings(u).clubs || {})[clubId] || { announcements: true, events: true, posts: true, muted: false }; },
    listState() { const s = store.state.ui; if (s.loadingUntil && s.loadingUntil > now()) return 'loading'; if (s.dataMode === 'empty') return 'empty'; if (s.dataMode === 'error') return 'error'; return 'normal'; },
    activityOf(clubId) { return store.state.activity.filter((a) => a.clubId === clubId); },
    interestMatches(clubId) { const club = store.state.clubs[clubId]; if (!club) return []; const ints = INTERESTS.filter((i) => i.cat === club.categoryId).map((i) => i.id); return Object.values(store.state.users).filter((u) => !u.staff && u.status === 'active' && !u.deleted && u.interests.some((i) => ints.includes(i))).map((u) => u.id); },
    kpis(clubId) { const members = sel.clubMembers(clubId); const monthAgo = now() - 30 * DAY; return { members: Math.max(members.length, store.state.clubs[clubId].memberCount), newMembers: members.filter((m) => m.decidedAt && m.decidedAt > monthAgo).length, pending: sel.pendingApps(clubId).length, upcoming: sel.clubEvents(clubId).filter((e) => e.status === 'published' && e.startsAt > now()).length, announcements: Object.values(store.state.posts).filter((p) => p.clubId === clubId && p.type === 'announcement' && !p.deleted && p.createdAt > monthAgo).length }; },
    memberGrowth(clubId) { const members = sel.clubMembers(clubId); const weeks = []; for (let w = 7; w >= 0; w--) { const end = now() - w * 7 * DAY; weeks.push(members.filter((m) => (m.decidedAt || 0) <= end).length + Math.round(store.state.clubs[clubId].memberCount * 0.6 * (1 - w * 0.02))); } return weeks; },
  };

  /* ---------- notification helper ---------- */
  const TYPE_SETTING = { announcement: 'announcements', event_reminder: 'eventReminders', event_new: 'newEvents', application_approved: 'applicationResults', application_rejected: 'applicationResults', application_received: 'management', new_report: 'management', system: 'system' };
  function notify(state, userId, type, refs = {}, opts = {}) {
    const u = state.users[userId]; if (!u || u.deleted) return state;
    const st = state.settings[userId]; if (st && !opts.force) { const k = TYPE_SETTING[type]; if (k && st[k] === false) return state; const cs = refs.clubId && st.clubs && st.clubs[refs.clubId]; if (cs && (cs.muted || (type === 'announcement' && cs.announcements === false) || (type === 'event_new' && cs.events === false))) return state; }
    const id = uid('n'); return put(state, 'notifications', id, { id, userId, type, refs, createdAt: now(), read: false });
  }
  function notifyMany(state, ids, type, refs, opts) { return [...new Set(ids)].reduce((s, u) => notify(s, u, type, refs, opts), state); }
  function act(state, clubId, actorId, kind, refs = {}) { return { ...state, activity: [{ id: uid('a'), clubId, actorId, kind, createdAt: now(), refs }, ...state.activity] }; }
  const managersOf = (state, clubId) => Object.values(state.memberships).filter((m) => m.clubId === clubId && m.status === 'active' && (m.role === 'board' || m.role === 'president')).map((m) => m.userId);
  const membersOf = (state, clubId) => Object.values(state.memberships).filter((m) => m.clubId === clubId && m.status === 'active' && m.role !== 'advisor').map((m) => m.userId);
  const superadmins = (state) => Object.values(state.users).filter((u) => u.global === 'superadmin').map((u) => u.id);
  const bumpMembers = (state, clubId, d) => upd(state, 'clubs', clubId, { memberCount: Math.max(0, (state.clubs[clubId].memberCount || 0) + d) });

  store.register({
    /* session */
    'session.login': (s, { userId }) => { const u = s.users[userId]; if (!u) return s; const first = !s.session.firstLogin[userId]; return ret({ ...s, session: { ...s.session, userId, failedAttempts: 0, lockedUntil: null, lastLoginAt: now(), firstLogin: { ...s.session.firstLogin, [userId]: true } } }, { first }); },
    'session.logout': (s) => ({ ...s, session: { ...s.session, userId: null } }),
    'session.set': (s, patch) => ({ ...s, session: { ...s.session, ...patch } }),
    'session.failedAttempt': (s) => { const n = (s.session.failedAttempts || 0) + 1; return ret({ ...s, session: { ...s.session, failedAttempts: n, lockedUntil: n >= 5 ? now() + 30000 : s.session.lockedUntil } }, n); },
    'ui.set': (s, patch) => ({ ...s, ui: { ...s.ui, ...patch } }),
    /* users */
    'user.update': (s, { userId, patch }) => upd(s, 'users', userId, patch),
    'user.register': (s, { name, email }) => { const id = uid('u'); return ret(put(put(s, 'users', id, { id, name, email, department: null, year: null, interests: [], avatarSeed: id, blocked: [], status: 'active', emailVerified: false, profileComplete: false, bio: '', staff: false, global: null, createdAt: now() }), 'settings', id, sel.settings('__none__')), id); },
    'user.block': (s, { userId, targetId }) => upd(s, 'users', userId, { blocked: [...new Set([...(s.users[userId].blocked || []), targetId])] }),
    'user.unblock': (s, { userId, targetId }) => upd(s, 'users', userId, { blocked: (s.users[userId].blocked || []).filter((x) => x !== targetId) }),
    'user.setStatus': (s, { userId, status, reason }) => upd(s, 'users', userId, { status, suspendReason: reason || null }),
    'user.delete': (s, { userId }) => {
      let n = upd(s, 'users', userId, { deleted: true, name: 'Silinmiş kullanıcı', email: '', interests: [], bio: '' });
      const memberships = Object.fromEntries(Object.entries(n.memberships).filter(([, m]) => m.userId !== userId));
      const rsvps = Object.fromEntries(Object.entries(n.rsvps).filter(([, r]) => r.userId !== userId));
      const notifications = Object.fromEntries(Object.entries(n.notifications).filter(([, x]) => x.userId !== userId));
      const saved = { ...n.saved }; delete saved[userId];
      return { ...n, memberships, rsvps, notifications, saved, session: { ...n.session, userId: null } };
    },
    /* memberships */
    'membership.apply': (s, { clubId, userId, note }) => {
      const prev = s.memberships[mkey(clubId, userId)];
      let n = put(s, 'memberships', mkey(clubId, userId), { clubId, userId, status: 'pending', role: 'member', note: note || '', appliedAt: now(), decidedAt: null, decidedBy: null, retryAfter: null, rejectReason: null, stale: false, priorCount: prev ? (prev.priorCount || 0) + 1 : 0 });
      n = notifyMany(n, managersOf(n, clubId), 'application_received', { clubId, applicantId: userId });
      return act(n, clubId, userId, 'application_received', { userId });
    },
    'membership.instantJoin': (s, { clubId, userId }) => { let n = put(s, 'memberships', mkey(clubId, userId), { clubId, userId, status: 'active', role: 'member', note: '', appliedAt: now(), decidedAt: now(), decidedBy: null, retryAfter: null, rejectReason: null, stale: false, priorCount: 0 }); n = bumpMembers(n, clubId, 1); return act(n, clubId, userId, 'member_joined', { userId }); },
    'membership.approve': (s, { clubId, userId, actorId }) => { let n = upd(s, 'memberships', mkey(clubId, userId), { status: 'active', decidedAt: now(), decidedBy: actorId, stale: false }); n = bumpMembers(n, clubId, 1); n = notify(n, userId, 'application_approved', { clubId }); return act(n, clubId, actorId, 'application_approved', { userId }); },
    'membership.reject': (s, { clubId, userId, actorId, reason, note }) => { let n = upd(s, 'memberships', mkey(clubId, userId), { status: 'rejected', decidedAt: now(), decidedBy: actorId, retryAfter: now() + 7 * DAY, rejectReason: reason || null, rejectNote: note || '', stale: false }); n = notify(n, userId, 'application_rejected', { clubId }); return act(n, clubId, actorId, 'application_rejected', { userId }); },
    'membership.undoDecision': (s, { clubId, userId }) => { const m = s.memberships[mkey(clubId, userId)]; if (!m) return s; let n = upd(s, 'memberships', mkey(clubId, userId), { status: 'pending', decidedAt: null, decidedBy: null, retryAfter: null, rejectReason: null }); if (m.status === 'active') n = bumpMembers(n, clubId, -1); return n; },
    'membership.cancel': (s, { clubId, userId }) => del(s, 'memberships', mkey(clubId, userId)),
    'membership.leave': (s, { clubId, userId }) => { let n = del(s, 'memberships', mkey(clubId, userId)); n = bumpMembers(n, clubId, -1); return act(n, clubId, userId, 'member_left', { userId }); },
    'membership.remove': (s, { clubId, userId, actorId, reason }) => { let n = upd(s, 'memberships', mkey(clubId, userId), { status: 'removed', decidedAt: now(), decidedBy: actorId, retryAfter: now() + 7 * DAY, rejectReason: 'other', rejectNote: reason || '' }); n = bumpMembers(n, clubId, -1); n = notify(n, userId, 'removed_from_club', { clubId }, { force: true }); return act(n, clubId, actorId, 'member_removed', { userId }); },
    'membership.setRole': (s, { clubId, userId, role, actorId }) => { let n = upd(s, 'memberships', mkey(clubId, userId), { role }); n = notify(n, userId, 'role_changed', { clubId, role }, { force: true }); return act(n, clubId, actorId, 'role_changed', { userId, role }); },
    'membership.transfer': (s, { clubId, fromId, toId }) => { let n = s; if (fromId && s.memberships[mkey(clubId, fromId)]) n = upd(n, 'memberships', mkey(clubId, fromId), { role: 'board' }); n = n.memberships[mkey(clubId, toId)] ? upd(n, 'memberships', mkey(clubId, toId), { role: 'president', status: 'active' }) : put(n, 'memberships', mkey(clubId, toId), { clubId, userId: toId, status: 'active', role: 'president', note: '', appliedAt: now(), decidedAt: now(), decidedBy: fromId, retryAfter: null, rejectReason: null, stale: false, priorCount: 0 }); n = upd(n, 'clubs', clubId, { presidentId: toId }); n = notify(n, toId, 'role_changed', { clubId, role: 'president' }, { force: true }); return act(n, clubId, fromId || toId, 'role_changed', { userId: toId, role: 'president' }); },
    'membership.saveNote': (s, { clubId, userId, note }) => upd(s, 'memberships', mkey(clubId, userId), { note }),
    /* rsvps */
    'rsvp.join': (s, { eventId, userId, reminder }) => { const ev = s.events[eventId]; const full = ev.capacity != null && Object.values(s.rsvps).filter((r) => r.eventId === eventId && (r.status === 'going' || r.status === 'attended')).length >= ev.capacity; const status = full ? 'waitlist' : 'going'; const n = put(s, 'rsvps', rkey(eventId, userId), { eventId, userId, status, reminder: reminder || 'none', createdAt: now(), waitlistAt: full ? now() : null, scannedAt: null, ticketCode: GU.ticketCode(eventId + ':' + userId) }); const pos = full ? Object.values(n.rsvps).filter((r) => r.eventId === eventId && r.status === 'waitlist').length : 0; return ret(n, { status, position: pos }); },
    'rsvp.leave': (s, { eventId, userId }) => { const r = s.rsvps[rkey(eventId, userId)]; let n = del(s, 'rsvps', rkey(eventId, userId)); if (r && r.status !== 'waitlist') { const wl = Object.values(n.rsvps).filter((x) => x.eventId === eventId && x.status === 'waitlist').sort((a, b) => (a.waitlistAt || 0) - (b.waitlistAt || 0)); if (wl.length) { n = upd(n, 'rsvps', rkey(eventId, wl[0].userId), { status: 'going', waitlistAt: null }); n = notify(n, wl[0].userId, 'waitlist_promoted', { eventId, clubId: s.events[eventId].clubId }, { force: true }); } } return n; },
    'rsvp.promote': (s, { eventId, userId }) => { let n = upd(s, 'rsvps', rkey(eventId, userId), { status: 'going', waitlistAt: null }); return notify(n, userId, 'waitlist_promoted', { eventId, clubId: s.events[eventId].clubId }, { force: true }); },
    'rsvp.setAttended': (s, { eventId, userId, attended }) => upd(s, 'rsvps', rkey(eventId, userId), { status: attended ? 'attended' : 'going', scannedAt: attended ? now() : null }),
    'rsvp.scan': (s, { eventId, userId }) => { const r = s.rsvps[rkey(eventId, userId)]; if (!r) return ret(s, 'invalid'); if (r.status === 'attended') return ret(s, 'used'); return ret(upd(s, 'rsvps', rkey(eventId, userId), { status: 'attended', scannedAt: now() }), 'valid'); },
    'rsvp.setReminder': (s, { eventId, userId, reminder }) => upd(s, 'rsvps', rkey(eventId, userId), { reminder }),
    'rsvp.markAllAttended': (s, { eventId }) => { const rs = { ...s.rsvps }; Object.values(rs).forEach((r) => { if (r.eventId === eventId && r.status === 'going') rs[rkey(eventId, r.userId)] = { ...r, status: 'attended', scannedAt: now() }; }); return { ...s, rsvps: rs }; },
    /* posts */
    'post.create': (s, { clubId, authorId, type, title, text, images, poll, pinned, push }) => {
      const id = uid('p'); let n = s;
      if (pinned) { const ps = { ...n.posts }; Object.values(ps).forEach((p) => { if (p.clubId === clubId && p.pinned) ps[p.id] = { ...p, pinned: false }; }); n = { ...n, posts: ps }; }
      n = put(n, 'posts', id, { id, clubId, authorId, type, title: title || null, text, images: images || [], poll: poll || null, pinned: !!pinned, createdAt: now(), likes: [], commentIds: [], pushSent: !!push, hidden: false, deleted: false, editedAt: null });
      if (type === 'announcement' && push) { const k = `${clubId}_${dayKey(now())}`; n = { ...n, dailyAnnouncementCount: { ...n.dailyAnnouncementCount, [k]: (n.dailyAnnouncementCount[k] || 0) + 1 } }; n = notifyMany(n, membersOf(n, clubId).filter((u) => u !== authorId), 'announcement', { postId: id, clubId }); }
      return ret(act(n, clubId, authorId, type === 'announcement' ? 'announcement' : type === 'poll' ? 'poll' : 'post_created', { postId: id }), id);
    },
    'post.update': (s, { postId, patch }) => { let n = s; if (patch.pinned) { const ps = { ...n.posts }; Object.values(ps).forEach((p) => { if (p.clubId === s.posts[postId].clubId && p.pinned && p.id !== postId) ps[p.id] = { ...p, pinned: false }; }); n = { ...n, posts: ps }; } return upd(n, 'posts', postId, { ...patch, editedAt: now() }); },
    'post.delete': (s, { postId }) => upd(s, 'posts', postId, { deleted: true }),
    'post.hide': (s, { postId }) => upd(s, 'posts', postId, { hidden: true }),
    'post.pin': (s, { postId, pinned }) => { let n = s; const p = s.posts[postId]; if (pinned) { const ps = { ...n.posts }; Object.values(ps).forEach((x) => { if (x.clubId === p.clubId && x.pinned) ps[x.id] = { ...x, pinned: false }; }); n = { ...n, posts: ps }; } return upd(n, 'posts', postId, { pinned }); },
    'post.like': (s, { postId, userId }) => { const p = s.posts[postId]; const liked = p.likes.includes(userId); return ret(upd(s, 'posts', postId, { likes: liked ? p.likes.filter((x) => x !== userId) : [...p.likes, userId] }), !liked); },
    'post.save': (s, { postId, userId }) => { const list = s.saved[userId] || []; const has = list.includes(postId); return ret({ ...s, saved: { ...s.saved, [userId]: has ? list.filter((x) => x !== postId) : [postId, ...list] } }, !has); },
    'post.vote': (s, { postId, userId, optionId }) => { const p = s.posts[postId]; if (!p.poll) return s; const options = p.poll.options.map((o) => ({ ...o, votes: o.id === optionId ? [...o.votes, userId] : o.votes })); return upd(s, 'posts', postId, { poll: { ...p.poll, options } }); },
    'comment.add': (s, { postId, authorId, text }) => { const id = uid('cm'); let n = put(s, 'comments', id, { id, postId, authorId, text, createdAt: now(), deleted: false, hidden: false }); n = upd(n, 'posts', postId, { commentIds: [...s.posts[postId].commentIds, id] }); return ret(n, id); },
    'comment.delete': (s, { commentId }) => upd(s, 'comments', commentId, { deleted: true }),
    'comment.hide': (s, { commentId }) => upd(s, 'comments', commentId, { hidden: true }),
    /* events */
    'event.save': (s, { event }) => { const id = event.id || uid('e'); const prev = s.events[id] || {}; return ret(put(s, 'events', id, { createdAt: now(), status: 'draft', registrationOpen: true, autoReminder: true, coverSeed: 'event-' + id, ...prev, ...event, id }), id); },
    'event.publish': (s, { eventId, notifyMembers, actorId }) => { const ev = s.events[eventId]; let n = upd(s, 'events', eventId, { status: 'published', publishedAt: now() }); if (notifyMembers !== false) { const targets = membersOf(n, ev.clubId).concat(ev.visibility === 'public' ? sel.interestMatches(ev.clubId) : []).filter((u) => u !== actorId); n = notifyMany(n, targets, 'event_new', { eventId, clubId: ev.clubId }); } return act(n, ev.clubId, actorId || ev.createdBy, 'event_published', { eventId }); },
    'event.cancel': (s, { eventId, reason, actorId }) => { const ev = s.events[eventId]; let n = upd(s, 'events', eventId, { status: 'cancelled', cancelReason: reason }); const att = Object.values(n.rsvps).filter((r) => r.eventId === eventId).map((r) => r.userId); n = notifyMany(n, att, 'event_cancelled', { eventId, clubId: ev.clubId }, { force: true }); return act(n, ev.clubId, actorId, 'event_cancelled', { eventId }); },
    'event.unpublish': (s, { eventId }) => upd(s, 'events', eventId, { status: 'draft' }),
    'event.delete': (s, { eventId }) => del(s, 'events', eventId),
    'event.duplicate': (s, { eventId }) => { const ev = s.events[eventId]; const id = uid('e'); return ret(put(s, 'events', id, { ...ev, id, title: ev.title + ' (kopya)', status: 'draft', createdAt: now(), startsAt: ev.startsAt + 7 * DAY, endsAt: ev.endsAt + 7 * DAY, coverSeed: 'event-' + id, cancelReason: null }), id); },
    'event.toggleRegistration': (s, { eventId }) => upd(s, 'events', eventId, { registrationOpen: !s.events[eventId].registrationOpen }),
    /* notifications */
    'notif.add': (s, { userId, type, refs }) => { const id = uid('n'); return ret(put(s, 'notifications', id, { id, userId, type, refs: refs || {}, createdAt: now(), read: false }), id); },
    'notif.read': (s, { id, read = true }) => (s.notifications[id] ? upd(s, 'notifications', id, { read }) : s),
    'notif.readAll': (s, { userId }) => { const ns = { ...s.notifications }; Object.values(ns).forEach((n) => { if (n.userId === userId && !n.read) ns[n.id] = { ...n, read: true }; }); return { ...s, notifications: ns }; },
    'notif.delete': (s, { id }) => del(s, 'notifications', id),
    'notif.restore': (s, { notification }) => put(s, 'notifications', notification.id, notification),
    /* reports */
    'report.create': (s, { targetType, targetId, reason, note, reporterId }) => {
      const existing = Object.values(s.reports).find((r) => r.targetType === targetType && r.targetId === targetId && r.status === 'open'); const entry = { reporterId, reason, note: note || '', createdAt: now() };
      let n; let id;
      if (existing) { id = existing.id; n = upd(s, 'reports', id, { reasons: [...existing.reasons, entry] }); } else { id = uid('r'); n = put(s, 'reports', id, { id, targetType, targetId, status: 'open', reasons: [entry], action: null, resolvedAt: null }); }
      n = notifyMany(n, superadmins(n), 'new_report', { reportId: id }, { force: true });
      return ret(n, id);
    },
    'report.resolve': (s, { reportId, action, actorId }) => {
      const r = s.reports[reportId]; let n = upd(s, 'reports', reportId, { status: 'resolved', action, resolvedAt: now(), resolvedBy: actorId });
      if (action === 'removed') { if (r.targetType === 'post') n = upd(n, 'posts', r.targetId, { hidden: true }); if (r.targetType === 'comment') n = upd(n, 'comments', r.targetId, { hidden: true }); }
      if (action === 'suspended' && r.targetType === 'user') n = upd(n, 'users', r.targetId, { status: 'suspended' });
      if (action === 'suspended' && r.targetType === 'club') n = upd(n, 'clubs', r.targetId, { status: 'suspended' });
      n = notifyMany(n, r.reasons.map((x) => x.reporterId), 'report_resolved', { reportId }, { force: true });
      return n;
    },
    /* clubs */
    'club.create': (s, { club, presidentId, actorId }) => { const id = uid('c'); let n = put(s, 'clubs', id, { id, coverSeed: 'club-' + id, palette: 'red', pattern: 'mountain', memberCount: 1, approvalRequired: true, applicationsOpen: true, requireNote: false, founded: new Date().getFullYear(), conditions: [], social: {}, status: 'active', createdAt: now(), ...club, presidentId }); n = put(n, 'memberships', mkey(id, presidentId), { clubId: id, userId: presidentId, status: 'active', role: 'president', note: '', appliedAt: now(), decidedAt: now(), decidedBy: actorId, retryAfter: null, rejectReason: null, stale: false, priorCount: 0 }); n = notify(n, presidentId, 'role_changed', { clubId: id, role: 'president' }, { force: true }); return ret(act(n, id, actorId, 'settings_changed', {}), id); },
    'club.update': (s, { clubId, patch, actorId }) => { const n = upd(s, 'clubs', clubId, patch); return actorId ? act(n, clubId, actorId, 'settings_changed', {}) : n; },
    'club.setStatus': (s, { clubId, status, reason }) => upd(s, 'clubs', clubId, { status, suspendReason: status === 'suspended' ? reason : null }),
    /* settings */
    'settings.update': (s, { userId, patch }) => put(s, 'settings', userId, { ...sel.settings(userId), ...patch }),
    'settings.club': (s, { userId, clubId, patch }) => { const st = sel.settings(userId); const cur = (st.clubs || {})[clubId] || { announcements: true, events: true, posts: true, muted: false }; return put(s, 'settings', userId, { ...st, clubs: { ...(st.clubs || {}), [clubId]: { ...cur, ...patch } } }); },
    /* search */
    'search.add': (s, { q }) => ({ ...s, ui: { ...s.ui, recentSearches: [q, ...s.ui.recentSearches.filter((x) => x.toLocaleLowerCase('tr') !== q.toLocaleLowerCase('tr'))].slice(0, 6) } }),
    'search.remove': (s, { i }) => ({ ...s, ui: { ...s.ui, recentSearches: s.ui.recentSearches.filter((_, k) => k !== i) } }),
    'search.set': (s, { list }) => ({ ...s, ui: { ...s.ui, recentSearches: list } }),
    /* misc */
    'support.send': (s, { userId, subject, message }) => { const no = '#GU-' + (4821 + s.supportTickets.length); return ret({ ...s, supportTickets: [...s.supportTickets, { no, userId, subject, message, createdAt: now() }] }, no); },
    'announcement.count': (s, { clubId }) => { const k = `${clubId}_${dayKey(now())}`; return { ...s, dailyAnnouncementCount: { ...s.dailyAnnouncementCount, [k]: (s.dailyAnnouncementCount[k] || 0) + 1 } }; },
    'seed.reset': (s) => { const fresh = seed(); return { ...fresh, session: { ...fresh.session, ...s.session, firstLogin: s.session.firstLogin, onboardingDone: s.session.onboardingDone }, ui: { ...fresh.ui, ...s.ui, dataMode: 'normal', loadingUntil: 0 } }; },
  });

  /* ---------- flows (compound actions used by several screens) ---------- */
  const flows = {
    /** join or apply to a club; returns 'applied' | 'joined' | 'closed' | 'wait' */
    join(clubId, { note } = {}) {
      const u = app.uid(); const club = sel.club(clubId); const m = sel.membership(clubId, u);
      if (!club.applicationsOpen) { app.toast('TST-CLOSED'); return 'closed'; }
      if (m && m.retryAfter && m.retryAfter > now()) return 'wait';
      if (!club.approvalRequired) { app.dispatch('membership.instantJoin', { clubId, userId: u }); app.toast('TST-34', { action: () => app.nav.push('CLB-03', { id: clubId }) }); return 'joined'; }
      app.dispatch('membership.apply', { clubId, userId: u, note }); return 'applied';
    },
    openManage(clubId) { const u = app.uid(); const managed = sel.managedClubs(u); if (clubId) { app.nav.push('MGT-01', { clubId }); return; } if (managed.length > 1) app.openSheet('SHT-18'); else if (managed.length === 1) app.nav.push('MGT-01', { clubId: managed[0].clubId }); },
    openNotification(n) {
      const u = app.uid(); app.dispatch('notif.read', { id: n.id, read: true }); const r = n.refs || {}; const nav = app.nav;
      switch (n.type) {
        case 'application_received': nav.openInTab('clubs', [{ screen: 'MGT-01', params: { clubId: r.clubId } }, { screen: 'MGT-02', params: { clubId: r.clubId } }]); if (r.applicantId && sel.membership(r.clubId, r.applicantId)) setTimeout(() => app.openSheet('SHT-19', { clubId: r.clubId, userId: r.applicantId }), 250); break;
        case 'application_approved': case 'role_changed': nav.openInTab('clubs', [{ screen: 'CLB-03', params: { id: r.clubId } }]); break;
        case 'application_rejected': case 'removed_from_club': nav.openInTab('clubs', [{ screen: 'CLB-03', params: { id: r.clubId } }, { screen: 'CLB-05', params: { id: r.clubId } }]); break;
        case 'announcement': { const p = sel.post(r.postId); if (!p || p.deleted || p.hidden) { nav.openInTab('clubs', [{ screen: 'SYS-04', params: {} }]); break; } nav.openInTab('clubs', [{ screen: 'CLB-03', params: { id: r.clubId, tab: 'posts' } }, { screen: 'FED-02', params: { clubId: r.clubId, postId: r.postId } }]); break; }
        case 'event_new': { const ev = sel.event(r.eventId); if (!ev) { nav.openInTab('events', [{ screen: 'SYS-04', params: {} }]); break; } nav.openInTab('events', [{ screen: 'EVT-02', params: { id: r.eventId } }]); break; }
        case 'event_cancelled': nav.openInTab('events', [{ screen: 'EVT-02', params: { id: r.eventId, showCancelled: true } }]); break;
        case 'event_reminder': case 'waitlist_promoted': { if (sel.myRsvp(r.eventId, u)) nav.openInTab('events', [{ screen: 'EVT-02', params: { id: r.eventId } }, { screen: 'EVT-03', params: { id: r.eventId } }]); else nav.openInTab('events', [{ screen: 'EVT-02', params: { id: r.eventId } }]); break; }
        case 'report_resolved': app.toast('TST-17'); break;
        case 'new_report': nav.openInTab('admin', [{ screen: 'ADM-04', params: { reportId: r.reportId } }]); if (sel.isSuper(u) && store.state.reports[r.reportId]) setTimeout(() => app.openSheet('SHT-26', { reportId: r.reportId }), 250); break;
        default: nav.openInTab('profile', [{ screen: 'SET-01', params: {} }, { screen: 'SET-04', params: {} }]);
      }
    },
    /** simulate a random new notification for the current user (Control Panel) */
    simulateNotification() {
      const u = app.uid(); if (!u) return; const evs = sel.visibleEvents(u).filter((e) => e.startsAt > now()); const clubs = sel.myClubs(u);
      const pool = [];
      if (evs.length) pool.push({ type: 'event_new', refs: { eventId: evs[Math.floor(Math.random() * evs.length)].id } });
      if (clubs.length) { const c = clubs[Math.floor(Math.random() * clubs.length)]; const posts = sel.clubPosts(c.clubId, u).filter((p) => p.type === 'announcement'); if (posts.length) pool.push({ type: 'announcement', refs: { postId: posts[0].id, clubId: c.clubId } }); }
      const mine = sel.userRsvps(u).filter((r) => r.event.startsAt > now() && r.status === 'going'); if (mine.length) pool.push({ type: 'event_reminder', refs: { eventId: mine[0].eventId } });
      pool.push({ type: 'system', refs: { textKey: 'maintenance' } });
      const pick = pool[Math.floor(Math.random() * pool.length)]; const id = app.dispatch('notif.add', { userId: u, ...pick });
      const n = store.state.notifications[id]; app.toast('TST-55', { title: GU.notifTitle ? GU.notifTitle(n) : pick.type, action: () => flows.openNotification(n) });
    },
  };
  app.sel = sel; app.flows = flows;
  Object.assign(GU, { sel, flows, notifyUser: notify });
})();

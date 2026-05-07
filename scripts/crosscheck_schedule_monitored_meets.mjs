#!/usr/bin/env node
/**
 * Cross-check teams/{teamId}/schedule_items (meet rows from official PDF schedule)
 * against monitored_meets and set coach_approved when a confident match exists.
 *
 * Matching:
 * - monitored meet start day falls within schedule item [start_date, end_date]
 * - title similarity (token overlap + substring)
 * - optional team alias gate: teams/{teamId} club_code, name, display_name, schedule_match_aliases
 *   so PDF short codes match PAC full club names (not OAPB-specific)
 *
 * Usage:
 *   node crosscheck_schedule_monitored_meets.mjs [--dry-run] [--team-id=oapb] [serviceAccount.json]
 */

import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { existsSync, readFileSync } from 'fs';
const TITLE_THRESHOLD = 0.38;
const SHORT_TITLE_THRESHOLD = 0.28;
const PACIFIC_TZ = 'America/Los_Angeles';

function initDb(credPath) {
  const raw = JSON.parse(readFileSync(credPath, 'utf8'));
  const projectId = raw.project_id || process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    console.error('Missing project_id');
    process.exit(1);
  }
  if (getApps().length === 0) {
    initializeApp({ credential: cert(raw), projectId });
  }
  return getFirestore();
}

/** YYYY-MM-DD strings from PDF schedule (Pacific calendar semantics). */
function scheduleYmdWindow(item) {
  const norm = (s) => {
    if (!s || typeof s !== 'string') return null;
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s.trim());
    return m ? `${m[1]}-${m[2]}-${m[3]}` : null;
  };

  let start = norm(item.start_date);
  if (!start && item.start_date_ts?.toDate) {
    start = toPacificYmd(item.start_date_ts.toDate());
  }

  let end = norm(item.end_date) ?? start;
  if (!end && item.end_date_ts?.toDate) {
    end = toPacificYmd(item.end_date_ts.toDate());
  }

  if (!start || !end) return null;
  if (end < start) [start, end] = [end, start];
  return { start, end };
}

function toPacificYmd(date) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: PACIFIC_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const y = parts.find((p) => p.type === 'year')?.value;
  const mo = parts.find((p) => p.type === 'month')?.value;
  const d = parts.find((p) => p.type === 'day')?.value;
  if (!y || !mo || !d) return null;
  return `${y}-${mo}-${d}`;
}

function firestoreTimeToDate(st) {
  if (!st) return null;
  if (st?.toDate) return st.toDate();
  if (st?.seconds != null) return new Date(st.seconds * 1000);
  if (typeof st === 'string') {
    const parsed = Date.parse(st);
    return Number.isNaN(parsed) ? null : new Date(parsed);
  }
  return null;
}

/** Pacific calendar date for monitored meet start (matches PDF schedule rows). */
function meetStartPacificYmd(data) {
  const st =
    data.start_time ??
    data.startTime ??
    data.start_date ??
    data.startDate ??
    null;
  const d = firestoreTimeToDate(st);
  return d ? toPacificYmd(d) : null;
}

function normalizeTitle(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const STOPWORDS = new Set([
  'the',
  'and',
  'for',
  'meet',
  'open',
  'junior',
  'senior',
  'all',
  'no',
  'day',
  'sat',
  'sun',
  'fri',
]);

function titleTokens(s) {
  return normalizeTitle(s)
    .split(' ')
    .filter((w) => w.length > 1 && !STOPWORDS.has(w));
}

function titleScore(schedTitle, meetTitle) {
  const na = normalizeTitle(schedTitle);
  const nb = normalizeTitle(meetTitle);
  if (!na.length || !nb.length) return 0;
  if (na.includes(nb) || nb.includes(na)) return 1;

  const ta = new Set(titleTokens(schedTitle));
  const tb = new Set(titleTokens(meetTitle));
  if (ta.size === 0 || tb.size === 0) return 0;

  let inter = 0;
  for (const w of ta) {
    if (tb.has(w)) inter++;
  }
  const denom = Math.min(ta.size, tb.size);
  let base = inter / denom;

  for (const w of ta) {
    if (w.length >= 3 && nb.includes(w)) {
      base = Math.max(base, 0.55);
      break;
    }
  }

  const hostParen = /\((?:host:\s*)?([^)]+)\)/i.exec(meetTitle);
  if (hostParen) {
    const hostNorm = normalizeTitle(hostParen[1]);
    for (const w of ta) {
      if (w.length >= 3 && hostNorm.includes(w)) {
        base = Math.max(base, 0.62);
        break;
      }
    }
  }

  if (base < TITLE_THRESHOLD) {
    for (const a of ta) {
      for (const b of tb) {
        if (a.length >= 4 && b.length >= 4 && (a.includes(b) || b.includes(a))) {
          base = Math.max(base, TITLE_THRESHOLD + 0.04);
          break;
        }
      }
    }
  }

  return base;
}

/** Too-generic tokens — never use alone to claim “our club” on the PDF row. */
const ALIAS_GENERIC_TOKENS = new Set([
  ...STOPWORDS,
  'swim',
  'swimming',
  'team',
  'club',
  'school',
  'academy',
  'sports',
  'sport',
  'center',
  'centre',
  'association',
  'league',
  'aquatic',
  'aquatics',
  'pool',
  'pools',
  'inc',
]);

/**
 * First two words of the club name as printed (“Orinda Aquatics …”), not “first two non-generic tokens”
 * (which would skip “Aquatics” and yield misleading phrases).
 */
function primaryClubPhrase(str) {
  const rawParts = normalizeTitle(String(str || '')).split(' ').filter(Boolean);
  if (!rawParts.length) return '';
  if (rawParts.length === 1) return rawParts[0];
  return `${rawParts[0]} ${rawParts[1]}`;
}

function isStrongAliasNeedle(needle, teamIdNorm, clubCodeNorm) {
  if (needle.length >= 4) return true;
  if (needle.length >= 3 && teamIdNorm && needle === teamIdNorm) return true;
  if (needle.length >= 3 && clubCodeNorm && needle === clubCodeNorm) return true;
  return false;
}

/**
 * @param {string} teamId
 * @param {Record<string, unknown>} teamData teams/{teamId} fields (may be empty)
 * @returns {{ needles: string[], teamIdNorm: string, clubCodeNorm: string }}
 */
function buildTeamAliases(teamId, teamData) {
  const needles = new Set();
  const teamIdNorm = normalizeTitle(teamId);
  const clubRaw = teamData?.club_code ?? teamData?.clubCode ?? '';
  const clubCodeNorm = normalizeTitle(String(clubRaw || ''));

  const addPhrase = (s) => {
    const n = normalizeTitle(String(s || ''));
    if (n.length >= 2) needles.add(n);
  };

  addPhrase(teamId);
  if (clubRaw) addPhrase(clubRaw);
  addPhrase(teamData?.name);
  addPhrase(teamData?.display_name ?? teamData?.displayName);

  const extra = teamData?.schedule_match_aliases ?? teamData?.scheduleMatchAliases;
  if (Array.isArray(extra)) {
    for (const x of extra) addPhrase(x);
  } else if (typeof extra === 'string') {
    addPhrase(extra);
  }

  for (const phraseSrc of [teamData?.name, teamData?.display_name ?? teamData?.displayName]) {
    const prim = primaryClubPhrase(phraseSrc);
    if (prim.length >= 4) needles.add(prim);
    for (const w of prim.split(/\s+/)) {
      if (w.length >= 5 && !ALIAS_GENERIC_TOKENS.has(w)) needles.add(w);
    }
  }

  const sorted = [...needles].sort((a, b) => b.length - a.length);
  return { needles: sorted, teamIdNorm, clubCodeNorm };
}

/** Schedule row mentions our club (short code or distinctive name fragment). */
function scheduleClaimsTeamHome(schedTitle, aliases) {
  if (!aliases?.needles?.length) return false;
  const ns = normalizeTitle(schedTitle);
  for (const needle of aliases.needles) {
    if (!isStrongAliasNeedle(needle, aliases.teamIdNorm, aliases.clubCodeNorm)) continue;
    if (ns.includes(needle)) return true;
  }
  return false;
}

/** Monitored title or sheet/entry URL shows our club (any alias needle). */
function monitoredMeetMatchesTeamAliases(meetData, meetTitle, aliases) {
  if (!aliases?.needles?.length) return false;
  const nm = normalizeTitle(meetTitle);
  const urls = String(meetData.meet_sheet_url || meetData.entry_url || '').toLowerCase();
  const hay = `${nm} ${urls}`;
  for (const needle of aliases.needles) {
    if (needle.length < 3) continue;
    if (hay.includes(needle)) return true;
  }
  return false;
}

function titleScorePlus(schedTitle, meetTitle, meetData, aliases) {
  let sc = titleScore(schedTitle, meetTitle);
  if (aliases?.needles?.length) {
    const claims = scheduleClaimsTeamHome(schedTitle, aliases);
    const matched = monitoredMeetMatchesTeamAliases(meetData, meetTitle, aliases);
    if (claims && matched) {
      sc = Math.min(1, sc + 0.15);
    }
  }
  return sc;
}

async function fetchTeamDoc(db, teamId) {
  const snap = await db.collection('teams').doc(teamId).get();
  return snap.exists ? snap.data() || {} : {};
}

/** Same calendar day + same normalized title → duplicate monitored rows for one real meet. */
function monitoredMeetDedupeKey(meetYmd, meetTitle) {
  return `${meetYmd}|${normalizeTitle(meetTitle)}`;
}

/** Legacy PAC numeric ids vs pac_* ids often duplicate one meet — mirror coach_* onto every sibling row. */
function monitoredMeetDupRefs(monitored, canonicalRef, canonicalMeetTitle) {
  const canon = monitored.find((m) => m.ref.path === canonicalRef.path);
  if (!canon) {
    return [];
  }
  const ymd = meetStartPacificYmd(canon.data);
  const key = monitoredMeetDedupeKey(ymd, canonicalMeetTitle);
  const out = [];
  for (const m of monitored) {
    if (m.ref.path === canonicalRef.path) {
      continue;
    }
    const mt =
      m.data.title ||
      m.data.meet_name ||
      m.data.meetName ||
      m.data.name ||
      '';
    const ymd2 = meetStartPacificYmd(m.data);
    if (monitoredMeetDedupeKey(ymd2, mt) === key) {
      out.push(m.ref);
    }
  }
  return out;
}

function coachApprovedMirrorPatch(fullPatch) {
  const keys = [
    'coach_approved',
    'coach_approved_via',
    'coach_approved_crosschecked_at',
    'coach_approved_schedule_item_id',
    'coach_approved_schedule_item_ids',
    'coach_approved_match_score',
  ];
  const out = {};
  for (const k of keys) {
    if (fullPatch[k] !== undefined) {
      out[k] = fullPatch[k];
    }
  }
  return out;
}

/** Prefer PAC `pac_*` docs over legacy numeric ids when scores tie (stable UI / sheet URLs). */
function preferMonitoredRef(candidate, incumbent) {
  const cp = candidate.id.startsWith('pac_');
  const ip = incumbent.id.startsWith('pac_');
  if (cp !== ip) return cp;
  return candidate.id < incumbent.id;
}

async function fetchScheduleMeetItems(db, teamId) {
  const snap = await db
    .collection('teams')
    .doc(teamId)
    .collection('schedule_items')
    .where('item_type', 'in', ['meet', 'high_school'])
    .get();

  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

async function fetchAllMonitoredMeets(db) {
  const out = [];
  let last = null;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    let q = db.collection('monitored_meets').orderBy('__name__').limit(400);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      out.push({ ref: doc.ref, id: doc.id, data: doc.data() });
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < 400) break;
  }
  return out;
}

function parseOrdMs(ymd) {
  const [y, m, d] = ymd.split('-').map(Number);
  return Date.UTC(y, m - 1, d);
}

function ymdWithin(meetYmd, win, slackDays = 2) {
  if (!meetYmd || !win) return false;
  const slackMs = slackDays * 86400000;
  const mo = parseOrdMs(meetYmd);
  const so = parseOrdMs(win.start);
  const eo = parseOrdMs(win.end);
  return mo >= so - slackMs && mo <= eo + slackMs;
}

/** If PDF mentions Zone N, require monitored title to reference the same N when it mentions any zone. */
function zoneNumeralGuard(schedTitle, meetTitle) {
  const sm = /zone\s*(\d+)/i.exec(schedTitle || '');
  if (!sm) return true;
  const want = sm[1];
  const matches = [...String(meetTitle || '').matchAll(/zone\s*(\d+)/gi)].map((x) => x[1]);
  if (matches.length === 0) return true;
  return matches.some((n) => n === want);
}

function scheduleYearMatchesMeetPacific(schedItem, meetYmd) {
  const sy = schedItem.year;
  if (sy == null || meetYmd == null) return true;
  const my = Number(meetYmd.slice(0, 4));
  return Number(sy) === my;
}

/** Drop monitored titles whose prominent calendar year disagrees with PDF row year (e.g. "2027 Sectionals"). */
function scheduleYearMatchesEmbeddedTitle(meetTitle, scheduleYear) {
  if (scheduleYear == null) return true;
  const m = /\b(20\d{2})\b/.exec(meetTitle || '');
  if (!m) return true;
  return Number(m[1]) === Number(scheduleYear);
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const teamArg = process.argv.find((a) => a.startsWith('--team-id='));
  const teamId = teamArg ? teamArg.split('=')[1] : 'oapb';

  const jsonCred = process.argv.find((a) => a.endsWith('.json') && !a.includes('--'));
  const credPath =
    jsonCred ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    '/Users/yan.xia/swimAgentBasic/scripts/serviceAccountKey.json';

  if (!existsSync(credPath)) {
    console.error(`Missing credentials: ${credPath}`);
    process.exit(1);
  }

  const db = initDb(credPath);
  console.log(`Team ${teamId}; dryRun=${dryRun}; loading schedule meets + monitored_meets…`);

  const teamData = await fetchTeamDoc(db, teamId);
  const teamAliases = buildTeamAliases(teamId, teamData);
  if (teamAliases.needles.length) {
    console.log(
      `Team aliases (${teamAliases.needles.length}): ${teamAliases.needles.slice(0, 8).join(', ')}${teamAliases.needles.length > 8 ? '…' : ''}`,
    );
  } else {
    console.warn(
      'No team aliases from Firestore (teams/{teamId} missing or empty name/club_code). Short-name vs full-name filtering disabled.',
    );
  }

  const scheduleItems = await fetchScheduleMeetItems(db, teamId);
  const monitored = await fetchAllMonitoredMeets(db);

  console.log(`Schedule meet-like rows: ${scheduleItems.length}; monitored_meets: ${monitored.length}`);

  /** @type {{ ref: FirebaseFirestore.DocumentReference, patch: Record<string, unknown>, schedId: string, score: number, title: string }[]} */
  const updates = [];
  /** @type string[] */
  const ambiguous = [];
  /** @type string[] */
  const noMatch = [];

  /** @type Map<string, typeof updates[0]> */
  const byMeetPath = new Map();

  for (const item of scheduleItems) {
    const win = scheduleYmdWindow(item);
    if (!win) {
      noMatch.push(`${item.schedule_item_id}: no date window`);
      continue;
    }

    let best = null;
    let bestScore = 0;
    for (const m of monitored) {
      const meetYmd = meetStartPacificYmd(m.data);
      if (!ymdWithin(meetYmd, win)) continue;
      if (!scheduleYearMatchesMeetPacific(item, meetYmd)) continue;

      const mt =
        m.data.title ||
        m.data.meet_name ||
        m.data.meetName ||
        m.data.name ||
        '';
      if (
        scheduleClaimsTeamHome(item.title || '', teamAliases) &&
        !monitoredMeetMatchesTeamAliases(m.data, mt, teamAliases)
      ) {
        continue;
      }
      if (!zoneNumeralGuard(item.title || '', mt)) continue;
      if (!scheduleYearMatchesEmbeddedTitle(mt, item.year)) continue;

      const sc = titleScorePlus(item.title || '', mt, m.data, teamAliases);
      if (
        sc > bestScore ||
        (sc === bestScore &&
          sc > 0 &&
          best &&
          preferMonitoredRef(m, best.m))
      ) {
        bestScore = sc;
        best = { m, meetTitle: mt };
      }
    }

    const thresh =
      (item.title || '').length <= 14 || titleTokens(item.title || '').length <= 2
        ? SHORT_TITLE_THRESHOLD
        : TITLE_THRESHOLD;

    if (!best || bestScore < thresh) {
      noMatch.push(
        `${item.schedule_item_id} "${item.title}" (${win.start}${win.end !== win.start ? `–${win.end}` : ''}) — bestScore=${bestScore.toFixed(2)}`,
      );
      continue;
    }

    const aliasTieBoost =
      teamAliases.needles.length > 0 &&
      scheduleClaimsTeamHome(item.title || '', teamAliases) &&
      monitoredMeetMatchesTeamAliases(best.m.data, best.meetTitle, teamAliases);

    const secondBest = (() => {
      let s2 = 0;
      const bestYmd = meetStartPacificYmd(best.m.data);
      const bestKey = monitoredMeetDedupeKey(bestYmd, best.meetTitle);
      for (const m of monitored) {
        if (m.ref.path === best.m.ref.path) continue;
        const meetYmd = meetStartPacificYmd(m.data);
        if (!ymdWithin(meetYmd, win)) continue;
        if (!scheduleYearMatchesMeetPacific(item, meetYmd)) continue;

        const mt =
          m.data.title ||
          m.data.meet_name ||
          m.data.meetName ||
          m.data.name ||
          '';
        if (monitoredMeetDedupeKey(meetYmd, mt) === bestKey) continue;
        if (
          scheduleClaimsTeamHome(item.title || '', teamAliases) &&
          !monitoredMeetMatchesTeamAliases(m.data, mt, teamAliases)
        ) {
          continue;
        }
        if (!zoneNumeralGuard(item.title || '', mt)) continue;
        if (!scheduleYearMatchesEmbeddedTitle(mt, item.year)) continue;

        const sc = titleScorePlus(item.title || '', mt, m.data, teamAliases);
        if (sc > s2) s2 = sc;
      }
      return s2;
    })();

    const tieMargin = aliasTieBoost ? 0.05 : 0.08;
    if (secondBest >= thresh && secondBest >= bestScore - tieMargin) {
      ambiguous.push(
        `${item.schedule_item_id}: "${item.title}" vs "${best.meetTitle}" (${bestScore.toFixed(2)}) close to another (${secondBest.toFixed(2)})`,
      );
      continue;
    }

    const path = best.m.ref.path;
    const existing = byMeetPath.get(path);
    const patchBase = {
      coach_approved: true,
      coach_approved_via: 'team_schedule_pdf_crosscheck',
      coach_approved_crosschecked_at: FieldValue.serverTimestamp(),
    };

    if (!existing) {
      byMeetPath.set(path, {
        ref: best.m.ref,
        patch: {
          ...patchBase,
          coach_approved_schedule_item_id: item.schedule_item_id,
          coach_approved_schedule_item_ids: [item.schedule_item_id],
          coach_approved_match_score: Math.round(bestScore * 1000) / 1000,
        },
        schedId: item.schedule_item_id,
        score: bestScore,
        title: best.meetTitle,
      });
    } else {
      const ids = existing.patch.coach_approved_schedule_item_ids;
      if (Array.isArray(ids) && !ids.includes(item.schedule_item_id)) {
        ids.push(item.schedule_item_id);
      }
      if (bestScore > existing.score) {
        existing.patch.coach_approved_match_score =
          Math.round(bestScore * 1000) / 1000;
        existing.patch.coach_approved_schedule_item_id = item.schedule_item_id;
        existing.score = bestScore;
        existing.schedId = item.schedule_item_id;
        existing.title = best.meetTitle;
      }
    }
  }

  updates.push(...byMeetPath.values());

  /** @type {{ ref: FirebaseFirestore.DocumentReference, patch: Record<string, unknown> }[]} */
  const writeOps = [];
  const writtenPaths = new Set();

  function enqueueWrite(ref, patch) {
    const p = ref.path;
    if (writtenPaths.has(p)) {
      return;
    }
    writtenPaths.add(p);
    writeOps.push({ ref, patch });
  }

  for (const u of updates) {
    enqueueWrite(u.ref, u.patch);
    const dupRefs = monitoredMeetDupRefs(monitored, u.ref, u.title);
    const mirror = coachApprovedMirrorPatch(u.patch);
    for (const dr of dupRefs) {
      enqueueWrite(dr, mirror);
    }
  }

  console.log('\n--- Proposed coach_approved writes ---');
  for (const u of updates) {
    const dups = monitoredMeetDupRefs(monitored, u.ref, u.title);
    const note =
      dups.length > 0 ? ` (+ mirror: ${dups.map((r) => r.id).join(', ')})` : '';
    console.log(
      `  ${u.ref.id} ← ${u.schedId} (score ${u.score.toFixed(2)}) "${u.title}"${note}`,
    );
  }

  if (ambiguous.length) {
    console.log('\n--- Skipped (ambiguous) ---');
    ambiguous.forEach((l) => console.log(`  ${l}`));
  }

  if (noMatch.length) {
    console.log('\n--- No confident match ---');
    noMatch.forEach((l) => console.log(`  ${l}`));
  }

  console.log(
    `\nSummary: primary matches ${updates.length}, total writes ${writeOps.length}, ambiguous ${ambiguous.length}, no match ${noMatch.length}`,
  );

  if (dryRun || writeOps.length === 0) {
    console.log(dryRun ? '[dry-run] no writes.' : 'Nothing to write.');
    return;
  }

  let batch = db.batch();
  let n = 0;
  for (const w of writeOps) {
    batch.set(w.ref, w.patch, { merge: true });
    n++;
    if (n % 400 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  if (n % 400 !== 0) await batch.commit();
  console.log(`Committed coach_approved fields on ${writeOps.length} monitored_meets doc(s).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

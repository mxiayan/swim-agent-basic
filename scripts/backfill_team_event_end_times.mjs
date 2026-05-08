#!/usr/bin/env node
/**
 * Backfill Firestore `team_events` → `event_data.end_time_local` when it is empty.
 *
 * Uses a JSON rules file: copy `team_event_end_time_rules.example.json` →
 * `team_event_end_time_rules.json` and adjust `start_time_local` / `end_time_local`
 * to match your coach-ingest `HH:MM` strings (24h). First matching rule wins.
 *
 * Prereq: cd scripts && npm install
 * Auth:   export GOOGLE_APPLICATION_CREDENTIALS=...
 *         optional: export FIREBASE_PROJECT_ID=...
 *
 * Inspect docs missing end time:
 *   node backfill_team_event_end_times.mjs --inspect
 *
 * Dry-run:
 *   node backfill_team_event_end_times.mjs --dry-run --rules team_event_end_time_rules.json
 *
 * Apply:
 *   node backfill_team_event_end_times.mjs --apply --rules team_event_end_time_rules.json
 *
 * Options:
 *   --team-id ID     only process events for this team_id
 *   --limit N        cap documents scanned (unordered)
 *   --force          overwrite non-empty end_time_local (use with care)
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { parseArgs } from 'util';

const COLLECTION = 'team_events';
const BATCH_SIZE = 400;

function initDb() {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const explicitProject = process.env.FIREBASE_PROJECT_ID;

  if (getApps().length > 0) {
    return getFirestore();
  }

  if (credPath && existsSync(credPath)) {
    const raw = JSON.parse(readFileSync(credPath, 'utf8'));
    const projectId = raw.project_id || explicitProject;
    if (!projectId) {
      console.error('Set FIREBASE_PROJECT_ID or use a service account JSON with project_id.');
      process.exit(1);
    }
    initializeApp({ credential: cert(raw), projectId });
    return getFirestore();
  }

  initializeApp({
    credential: applicationDefault(),
    projectId: explicitProject,
  });
  return getFirestore();
}

/** Normalize to HH:MM 24h for comparison, or null. */
function normalizeHm(raw) {
  const t = String(raw ?? '').trim();
  if (!t) return null;

  let m = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(t);
  if (m) {
    const h = parseInt(m[1], 10);
    const min = parseInt(m[2], 10);
    if (h > 23 || min > 59) return null;
    return `${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')}`;
  }

  m = /^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$/.exec(t);
  if (m) {
    let h12 = parseInt(m[1], 10);
    const min = parseInt(m[2], 10);
    const ap = m[3].toUpperCase();
    if (h12 < 1 || h12 > 12 || min > 59) return null;
    let h24 = h12 % 12;
    if (ap === 'PM') h24 += 12;
    return `${String(h24).padStart(2, '0')}:${String(min).padStart(2, '0')}`;
  }

  return null;
}

function loadRules(path) {
  if (!path || !existsSync(path)) {
    console.error(`Rules file not found: ${path}`);
    process.exit(1);
  }
  const raw = JSON.parse(readFileSync(path, 'utf8'));
  const rules = Array.isArray(raw.rules) ? raw.rules : [];
  return rules
    .map((r) => ({
      team_id: String(r.team_id || '').trim(),
      event_type: String(r.event_type || '').trim().toUpperCase(),
      title_contains_any: Array.isArray(r.title_contains_any)
        ? r.title_contains_any.map((x) => String(x).toLowerCase())
        : [],
      groups_contains_any: Array.isArray(r.groups_contains_any)
        ? r.groups_contains_any.map((x) => String(x).toUpperCase())
        : [],
      start_time_local: String(r.start_time_local || '').trim(),
      end_time_local: String(r.end_time_local || '').trim(),
    }))
    .filter((r) => r.end_time_local.length > 0);
}

function eventData(root) {
  const ed = root.event_data;
  return ed && typeof ed === 'object' ? ed : {};
}

function titleOf(root) {
  const t = eventData(root).title;
  return t == null ? '' : String(t).trim();
}

function groupsOf(root) {
  const g = eventData(root).applies_to_groups;
  if (!Array.isArray(g)) return [];
  return g.map((x) => String(x).trim().toUpperCase()).filter(Boolean);
}

function matchRule(root, rule, filterTeamId) {
  const teamId = root.team_id == null ? '' : String(root.team_id).trim();
  if (filterTeamId && teamId !== filterTeamId) return false;
  if (rule.team_id && teamId !== rule.team_id) return false;

  const et = root.event_type == null ? '' : String(root.event_type).trim().toUpperCase();
  if (rule.event_type && et !== rule.event_type) return false;

  const title = titleOf(root).toLowerCase();
  if (rule.title_contains_any.length > 0) {
    const hit = rule.title_contains_any.some((needle) => title.includes(needle));
    if (!hit) return false;
  }

  if (rule.groups_contains_any.length > 0) {
    const grp = groupsOf(root);
    const hit = rule.groups_contains_any.some((need) => grp.some((g) => g.includes(need)));
    if (!hit) return false;
  }

  const startRaw = eventData(root).start_time_local;
  const startNorm = normalizeHm(startRaw);
  if (rule.start_time_local) {
    const want = normalizeHm(rule.start_time_local);
    if (!startNorm || !want || startNorm !== want) return false;
  }

  return true;
}

function pickEndTime(root, rules, filterTeamId) {
  for (const rule of rules) {
    if (matchRule(root, rule, filterTeamId)) {
      return rule.end_time_local.trim();
    }
  }
  return null;
}

async function main() {
  const { values } = parseArgs({
    options: {
      inspect: { type: 'boolean', default: false },
      'dry-run': { type: 'boolean', default: false },
      apply: { type: 'boolean', default: false },
      rules: { type: 'string', default: '' },
      'team-id': { type: 'string', default: '' },
      limit: { type: 'string', default: '' },
      force: { type: 'boolean', default: false },
    },
    allowPositionals: true,
  });

  const inspect = values.inspect;
  const dryRun = values['dry-run'];
  const apply = values.apply;
  const rulesPath = values.rules;
  const filterTeamId = String(values['team-id'] || '').trim();
  const lim = parseInt(values.limit || '0', 10);
  const force = values.force;

  const modes = [inspect, dryRun, apply].filter(Boolean).length;
  if (modes === 0) {
    console.log(`Usage:
  node backfill_team_event_end_times.mjs --inspect
  node backfill_team_event_end_times.mjs --dry-run --rules team_event_end_time_rules.json
  node backfill_team_event_end_times.mjs --apply --rules team_event_end_time_rules.json

Options:
  --team-id oapb   filter by team_id
  --limit N        scan at most N docs
  --force          overwrite existing end_time_local
`);
    process.exit(0);
  }

  if ((dryRun || apply) && !rulesPath) {
    console.error('--dry-run and --apply require --rules path/to.json');
    process.exit(1);
  }

  if (apply && dryRun) {
    console.error('Use only one of --apply or --dry-run');
    process.exit(1);
  }

  const db = initDb();
  let q = db.collection(COLLECTION);
  if (lim > 0) {
    q = q.limit(lim);
  }

  const snap = await q.get();
  console.log(`\nCollection "${COLLECTION}": scanned ${snap.size} document(s)\n`);

  if (inspect) {
    let missing = 0;
    const samples = [];
    for (const doc of snap.docs) {
      const root = doc.data();
      const ed = eventData(root);
      const end = ed.end_time_local == null ? '' : String(ed.end_time_local).trim();
      const start = ed.start_time_local == null ? '' : String(ed.start_time_local).trim();
      if (end !== '') continue;
      missing += 1;
      if (samples.length < 25) {
        samples.push({
          id: doc.id,
          team_id: root.team_id,
          event_type: root.event_type,
          title: titleOf(root),
          start_time_local: start,
          applies_to_groups: groupsOf(root),
        });
      }
    }
    console.log(`Documents with empty event_data.end_time_local: ${missing}\n`);
    console.log('Sample (up to 25) — use this to craft rules (match start_time_local + title):');
    console.log('---');
    for (const s of samples) {
      console.log(JSON.stringify(s));
    }
    console.log(`
Next:
  cp team_event_end_time_rules.example.json team_event_end_time_rules.json
  Edit rules, then:
  node backfill_team_event_end_times.mjs --dry-run --rules team_event_end_time_rules.json
`);
    process.exit(0);
  }

  const rules = loadRules(rulesPath);
  if (rules.length === 0) {
    console.error('No rules with end_time_local in JSON.');
    process.exit(1);
  }

  const planned = [];
  let skippedHasEnd = 0;
  let noMatch = 0;

  for (const doc of snap.docs) {
    const root = doc.data();
    const ed = eventData(root);
    const end = ed.end_time_local == null ? '' : String(ed.end_time_local).trim();
    if (end !== '' && !force) {
      skippedHasEnd += 1;
      continue;
    }

    const nextEnd = pickEndTime(root, rules, filterTeamId);
    if (!nextEnd) {
      noMatch += 1;
      continue;
    }

    if (end !== '' && force && end === nextEnd) {
      skippedHasEnd += 1;
      continue;
    }

    planned.push({
      ref: doc.ref,
      id: doc.id,
      team_id: root.team_id,
      title: titleOf(root),
      start: ed.start_time_local,
      endNext: nextEnd,
    });
  }

  console.log(`Rules loaded: ${rules.length}`);
  if (filterTeamId) console.log(`Filter team_id: ${filterTeamId}`);
  console.log(`Will update: ${planned.length}`);
  console.log(`Skipped (already has end, or force+same): ${skippedHasEnd}`);
  console.log(`No matching rule: ${noMatch}\n`);

  for (const p of planned.slice(0, 20)) {
    console.log(
      `  ${p.id} | team=${p.team_id} | start=${p.start} → end=${p.endNext} | ${p.title.slice(0, 48)}`,
    );
  }
  if (planned.length > 20) {
    console.log(`  ... (${planned.length - 20} more)`);
  }

  if (dryRun) {
    console.log('\nDry run — no writes. Pass --apply to commit.\n');
    process.exit(0);
  }

  if (!apply) {
    process.exit(0);
  }

  for (let i = 0; i < planned.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = planned.slice(i, i + BATCH_SIZE);
    for (const p of chunk) {
      batch.update(p.ref, {
        'event_data.end_time_local': p.endNext,
        end_time_local_backfilled_at: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    console.log(`Committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${chunk.length} writes)`);
  }

  console.log('\nDone.\n');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

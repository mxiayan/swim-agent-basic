#!/usr/bin/env node
/**
 * Backfill Firestore `monitored_meets` with `meet_zone` (and optional `host_group`)
 * from existing `region_id` / `region_name` fields — matches Swim Agent filter logic.
 *
 * Prereq: cd scripts && npm install
 * Auth:   export GOOGLE_APPLICATION_CREDENTIALS=... (same as firebase_health_check.mjs)
 *
 * 1) See what values you have in test data:
 *      node backfill_meet_zones.mjs --inspect
 *
 * 2) Copy meet_zone_mapping.example.json → meet_zone_mapping.json and fill
 *    `byRegionId` / `byRegionNameContains` / optional `defaultZone`.
 *
 * 3) Dry-run (prints planned writes, no changes):
 *      node backfill_meet_zones.mjs --dry-run --mapping meet_zone_mapping.json
 *
 * 4) Apply:
 *      node backfill_meet_zones.mjs --apply --mapping meet_zone_mapping.json
 *
 * Options:
 *   --collection NAME     default: monitored_meets
 *   --limit N              only process first N docs (order not guaranteed)
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { parseArgs } from 'util';

const COLLECTION_DEFAULT = 'monitored_meets';
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

function loadMapping(path) {
  if (!path || !existsSync(path)) {
    console.error(`Mapping file not found: ${path}`);
    process.exit(1);
  }
  const raw = JSON.parse(readFileSync(path, 'utf8'));
  return {
    defaultZone: (raw.defaultZone || '').trim(),
    defaultHostGroup: (raw.defaultHostGroup || '').trim(),
    byRegionId: raw.byRegionId && typeof raw.byRegionId === 'object' ? raw.byRegionId : {},
    byRegionNameContains: Array.isArray(raw.byRegionNameContains)
      ? raw.byRegionNameContains
      : [],
  };
}

function deriveMeetZoneFromRegion(d) {
  if (!d) return '';
  const rid = d.region_id;
  if (rid != null && String(rid).trim() !== '') {
    const s = String(rid).trim();
    if (/^Z\d+[NSEW]?$/i.test(s)) return s.toUpperCase();
    const pc = s.match(/^PC_Z(\d+)([NSEW])?$/i);
    if (pc) return `Z${pc[1]}${pc[2] || ''}`.toUpperCase();
  }
  if (d.region_name == null) return '';
  const text = String(d.region_name).trim();
  if (!text) return '';
  const m = text.match(/zone\s*(\d+)\s*(north|south|east|west|n|s|e|w)?/i);
  if (!m) return '';
  const num = m[1];
  const q = (m[2] || '').toLowerCase();
  let suf = '';
  if (q === 'north' || q === 'n') suf = 'N';
  else if (q === 'south' || q === 's') suf = 'S';
  else if (q === 'east' || q === 'e') suf = 'E';
  else if (q === 'west' || q === 'w') suf = 'W';
  return `Z${num}${suf}`;
}

function zoneFromData(d, mapping) {
  const rid = d.region_id;
  if (rid != null && rid !== '') {
    const key = String(rid).trim();
    const z = mapping.byRegionId[key];
    if (z && String(z).trim()) {
      return String(z).trim();
    }
  }

  const rn = (d.region_name != null ? String(d.region_name) : '').trim();
  if (rn) {
    const lower = rn.toLowerCase();
    for (const rule of mapping.byRegionNameContains) {
      const needle = (rule.contains || '').toLowerCase();
      const zone = (rule.zone || '').trim();
      if (needle && zone && lower.includes(needle)) {
        return zone;
      }
    }
  }

  if (mapping.defaultZone) {
    return mapping.defaultZone;
  }

  return deriveMeetZoneFromRegion(d);
}

function hostFromData(_d, mapping) {
  return mapping.defaultHostGroup ? mapping.defaultHostGroup : '';
}

async function main() {
  const { values } = parseArgs({
    options: {
      inspect: { type: 'boolean', default: false },
      // util.parseArgs: long flag --dry-run must be declared as 'dry-run'
      'dry-run': { type: 'boolean', default: false },
      apply: { type: 'boolean', default: false },
      mapping: { type: 'string', default: '' },
      collection: { type: 'string', default: COLLECTION_DEFAULT },
      limit: { type: 'string', default: '' },
    },
    allowPositionals: true,
  });

  const inspect = values.inspect;
  const dryRun = values['dry-run'];
  const apply = values.apply;
  const mappingPath = values.mapping;
  const collection = values.collection;
  const limit = values.limit;

  const modes = [inspect, dryRun, apply].filter(Boolean).length;
  if (modes === 0) {
    console.log(`Usage:
  node backfill_meet_zones.mjs --inspect
  node backfill_meet_zones.mjs --dry-run --mapping meet_zone_mapping.json
  node backfill_meet_zones.mjs --apply --mapping meet_zone_mapping.json
`);
    process.exit(0);
  }

  if ((dryRun || apply) && !mappingPath) {
    console.error('--dry-run and --apply require --mapping path/to.json');
    process.exit(1);
  }

  if (apply && dryRun) {
    console.error('Use only one of --apply or --dry-run');
    process.exit(1);
  }

  const db = initDb();
  const colName = collection || COLLECTION_DEFAULT;
  let q = db.collection(colName);
  const lim = parseInt(limit || '0', 10);
  if (lim > 0) {
    q = q.limit(lim);
  }

  const snap = await q.get();
  console.log(`\nCollection "${colName}": ${snap.size} document(s)\n`);

  if (inspect) {
    const combo = new Map();
    for (const doc of snap.docs) {
      const d = doc.data();
      const rid = d.region_id == null ? '' : String(d.region_id);
      const rn = d.region_name == null ? '' : String(d.region_name);
      const k = `${rid}\t|\t${rn}`;
      combo.set(k, (combo.get(k) || 0) + 1);
    }
    console.log('Unique region_id | region_name (tab-separated) → count');
    console.log('---');
    const sorted = [...combo.entries()].sort((a, b) => b[1] - a[1]);
    for (const [k, c] of sorted) {
      console.log(`${k} → ${c}`);
    }
    console.log(`
Next: add entries to meet_zone_mapping.json:
  "byRegionId": { "<region_id from left column>": "Z2" }
or
  "byRegionNameContains": [ { "contains": "substring of region_name", "zone": "Z2" } ]
or set "defaultZone": "Z2" if every meets in this dataset share one Pacific zone id.
`);
    process.exit(0);
  }

  const mapping = loadMapping(mappingPath);
  const planned = [];
  let unresolved = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const zone = zoneFromData(d, mapping);
    if (!zone) {
      unresolved += 1;
      planned.push({ ref: doc.ref, id: doc.id, skip: true, reason: 'no zone resolved' });
      continue;
    }
    const host = hostFromData(d, mapping);
    const update = {
      meet_zone: zone,
      meet_zone_backfilled_at: FieldValue.serverTimestamp(),
    };
    if (host) {
      update.host_group = host;
    }
    planned.push({ ref: doc.ref, id: doc.id, update, zone, host });
  }

  const toWrite = planned.filter((p) => !p.skip);
  console.log(`Resolved zone for ${toWrite.length} doc(s); ${unresolved} unresolved (check mapping).\n`);

  if (unresolved > 0) {
    console.log('Unresolved document IDs (first 20):');
    planned
      .filter((p) => p.skip)
      .slice(0, 20)
      .forEach((p) => console.log(`  ${p.id}`));
    if (unresolved > 20) console.log(`  ... and ${unresolved - 20} more`);
    console.log('');
  }

  for (const p of toWrite.slice(0, 15)) {
    console.log(`  ${p.id} → meet_zone=${p.zone}${p.host ? ` host_group=${p.host}` : ''}`);
  }
  if (toWrite.length > 15) {
    console.log(`  ... (${toWrite.length - 15} more)`);
  }

  if (dryRun) {
    console.log('\nDry run only — no writes. Pass --apply to commit.\n');
    process.exit(unresolved > 0 ? 1 : 0);
  }

  if (!apply) {
    process.exit(0);
  }

  for (let i = 0; i < toWrite.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = toWrite.slice(i, i + BATCH_SIZE);
    for (const p of chunk) {
      batch.set(p.ref, p.update, { merge: true });
    }
    await batch.commit();
    console.log(`Committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${chunk.length} writes)`);
  }

  console.log('\nDone. Re-run: npm run health\n');
  process.exit(unresolved > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

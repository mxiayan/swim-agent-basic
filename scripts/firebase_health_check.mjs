#!/usr/bin/env node
/**
 * Firebase / Firestore health check for Swim Agent (Pacific zones, meets, swimmers).
 *
 * Setup (one time):
 *   cd scripts && npm install
 *
 * Auth — use ONE of:
 *   1) Service account JSON:
 *        export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/serviceAccount.json
 *   2) gcloud ADC (no JSON file):
 *        gcloud auth application-default login
 *        export FIREBASE_PROJECT_ID=your-project-id
 *
 * Run:
 *   npm run health
 *   # or
 *   node firebase_health_check.mjs
 *
 * Exit code: 0 = no blocking failures, 1 = at least one blocking failure.
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';

const ok = (msg) => console.log(`  [OK]   ${msg}`);
const warn = (msg) => console.log(`  [WARN] ${msg}`);
const fail = (msg) => console.log(`  [FAIL] ${msg}`);
const info = (msg) => console.log(`  [..]   ${msg}`);

const METADATA_CLUBS = 'metadata_clubs';
const SWIMMERS = 'swimmers';
const MONITORED_MEETS = 'monitored_meets';

const CLUB_LOOKUP_FIELDS = [
  'club_code',
  'code',
  'lsc_club_code',
  'team_code',
  'club_id',
];

/** Same aliases as [MonitoredMeetsRecord] in the Flutter app. */
const MEET_ZONE_KEYS = [
  'meet_zone',
  'meetZone',
  'MeetZone',
  'zone_id',
  'zoneId',
  'zone',
  'pacific_zone',
  'PacificZone',
];

const MEET_HOST_KEYS = [
  'host_group',
  'hostGroup',
  'HostGroup',
  'hosting_club',
  'hostingClub',
  'host_club_code',
  'club_code',
];

/** Same logic as [MonitoredMeetsRecord._deriveMeetZoneFromRegion] in Dart. */
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

function resolveMeetZone(d) {
  if (!d) return '';
  for (const k of MEET_ZONE_KEYS) {
    const v = d[k];
    if (v != null && String(v).trim() !== '') return String(v).trim();
  }
  const derived = deriveMeetZoneFromRegion(d);
  return derived || '';
}

function resolveHostGroup(d) {
  if (!d) return '';
  for (const k of MEET_HOST_KEYS) {
    const v = d[k];
    if (v != null && String(v).trim() !== '') return String(v).trim();
  }
  return '';
}

let blockingFailures = 0;
let warnings = 0;

function bumpFail() {
  blockingFailures += 1;
}
function bumpWarn() {
  warnings += 1;
}

function initFirebaseAdmin() {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const explicitProject = process.env.FIREBASE_PROJECT_ID;

  if (getApps().length > 0) {
    return getFirestore();
  }

  if (credPath && existsSync(credPath)) {
    const raw = JSON.parse(readFileSync(credPath, 'utf8'));
    const projectId = raw.project_id || explicitProject;
    if (!projectId) {
      console.error('Could not determine project_id from service account JSON. Set FIREBASE_PROJECT_ID.');
      process.exit(1);
    }
    initializeApp({
      credential: cert(raw),
      projectId,
    });
    info(`Initialized with service account (project: ${projectId})`);
    return getFirestore();
  }

  try {
    initializeApp({
      credential: applicationDefault(),
      projectId: explicitProject,
    });
    info(`Initialized with Application Default Credentials (project: ${explicitProject || 'default'})`);
    return getFirestore();
  } catch (e) {
    console.error(`
Could not initialize Firebase Admin.

Option A — service account:
  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json

Option B — gcloud:
  gcloud auth application-default login
  export FIREBASE_PROJECT_ID=your-gcp-project-id

${e?.message || e}
`);
    process.exit(1);
  }
}

async function findMetadataClubDoc(db, clubKey) {
  const key = String(clubKey || '').trim();
  if (!key) return null;

  const col = db.collection(METADATA_CLUBS);
  let snap = await col.doc(key).get();
  if (snap.exists) return snap;

  const upper = key.toUpperCase();
  if (upper !== key) {
    snap = await col.doc(upper).get();
    if (snap.exists) return snap;
  }

  for (const field of CLUB_LOOKUP_FIELDS) {
    const q = await col.where(field, '==', key).limit(1).get();
    if (!q.empty) return q.docs[0];
  }
  if (upper !== key) {
    for (const field of ['club_code', 'code', 'lsc_club_code']) {
      const q = await col.where(field, '==', upper).limit(1).get();
      if (!q.empty) return q.docs[0];
    }
  }
  return null;
}

function clubKeyFromSwimmer(data) {
  const d = data || {};
  const candidates = [
    d.club_code,
    d.lsc_club_code,
    d.usa_swimming_club_code,
    d.group_id,
  ];
  for (const c of candidates) {
    if (typeof c === 'string' && c.trim()) return c.trim();
  }
  return '';
}

async function main() {
  console.log('\n=== Firebase / Firestore health check (Swim Agent) ===\n');

  const db = initFirebaseAdmin();

  // --- metadata_clubs ---
  console.log(`Collection: ${METADATA_CLUBS}`);
  let metaSnap;
  try {
    metaSnap = await db.collection(METADATA_CLUBS).limit(100).get();
  } catch (e) {
    fail(`Cannot read ${METADATA_CLUBS}: ${e.message}`);
    bumpFail();
    metaSnap = null;
  }

  if (metaSnap) {
    if (metaSnap.empty) {
      warn('No documents (empty collection). App cannot resolve zone from club.');
      bumpWarn();
    } else {
      ok(`Readable; sample size ${metaSnap.size} (max 100)`);
      let missingZone = 0;
      for (const doc of metaSnap.docs) {
        const z = doc.get('zone_id');
        if (z == null || String(z).trim() === '') {
          missingZone += 1;
          warn(`Doc "${doc.id}": missing or empty zone_id`);
          bumpWarn();
        }
      }
      if (missingZone === 0) {
        ok('All sampled metadata_clubs docs have non-empty zone_id');
      }
    }
  }

  // --- swimmers ---
  console.log(`\nCollection: ${SWIMMERS}`);
  let swimSnap;
  try {
    swimSnap = await db.collection(SWIMMERS).limit(50).get();
  } catch (e) {
    fail(`Cannot read ${SWIMMERS}: ${e.message}`);
    bumpFail();
    swimSnap = null;
  }

  if (swimSnap) {
    if (swimSnap.empty) {
      warn('No swimmer documents.');
      bumpWarn();
    } else {
      ok(`Readable; sample size ${swimSnap.size} (max 50)`);
      for (const doc of swimSnap.docs) {
        const d = doc.data();
        const id = doc.id;
        if (d.owner_id == null || d.owner_id === '') {
          warn(`Swimmer "${id}": missing owner_id (app resolves by owner_id or doc(uid))`);
          bumpWarn();
        }
        const ck = clubKeyFromSwimmer(d);
        if (!ck) {
          warn(`Swimmer "${id}": no club_code / lsc_club_code / group_id — zone hydration cannot lookup metadata`);
          bumpWarn();
        }
        const zone = d.zone_id;
        if (zone == null || String(zone).trim() === '') {
          if (ck) {
            warn(`Swimmer "${id}": zone_id empty but club key "${ck}" present (client will try metadata_clubs on login)`);
            bumpWarn();
          } else {
            warn(`Swimmer "${id}": zone_id empty and no club key`);
            bumpWarn();
          }
        } else {
          ok(`Swimmer "${id}": zone_id=${zone}`);
        }
      }
    }
  }

  // --- Cross-check: swimmer club -> metadata zone ---
  console.log('\nCross-check: swimmer club key -> metadata_clubs -> zone_id');
  if (swimSnap && !swimSnap.empty && metaSnap && !metaSnap.empty) {
    let checked = 0;
    for (const doc of swimSnap.docs) {
      const ck = clubKeyFromSwimmer(doc.data());
      if (!ck) continue;
      checked += 1;
      const metaDoc = await findMetadataClubDoc(db, ck);
      if (!metaDoc) {
        fail(`Club key "${ck}" (swimmer ${doc.id}): no matching metadata_clubs document`);
        bumpFail();
        continue;
      }
      const z = metaDoc.get('zone_id');
      if (z == null || String(z).trim() === '') {
        fail(`metadata_clubs "${metaDoc.id}": matched swimmer club "${ck}" but zone_id is empty`);
        bumpFail();
      } else {
        ok(`Swimmer ${doc.id} club "${ck}" -> metadata "${metaDoc.id}" -> zone_id=${z}`);
      }
      if (checked >= 10) break;
    }
    if (checked === 0) {
      warn('No swimmers in sample had a club key to cross-check.');
      bumpWarn();
    }
  } else {
    warn('Skip cross-check (missing swimmers or metadata data).');
    bumpWarn();
  }

  // --- monitored_meets ---
  console.log(`\nCollection: ${MONITORED_MEETS}`);
  let meetSnap;
  try {
    meetSnap = await db.collection(MONITORED_MEETS).limit(50).get();
  } catch (e) {
    fail(`Cannot read ${MONITORED_MEETS}: ${e.message}`);
    bumpFail();
    meetSnap = null;
  }

  if (meetSnap) {
    if (meetSnap.empty) {
      warn('No monitored_meets documents — Meets tab will be empty.');
      bumpWarn();
    } else {
      ok(`Readable; sample size ${meetSnap.size} (max 50)`);
      info(
        'Optional: coach_approved (bool) on meet docs — set by coach-email parse / Agent pipeline.',
      );
      const zoneIds = new Set();
      if (metaSnap) {
        for (const d of metaSnap.docs) {
          const z = d.get('zone_id');
          if (z != null && String(z).trim()) {
            zoneIds.add(String(z).trim().toUpperCase());
          }
        }
      }

      const first = meetSnap.docs[0];
      if (first) {
        const keys = Object.keys(first.data() || {}).sort();
        info(`Sample doc "${first.id}" field names: ${keys.join(', ')}`);
      }

      let missingZoneCount = 0;
      for (const doc of meetSnap.docs) {
        const d = doc.data();
        const id = doc.id;
        const mz = resolveMeetZone(d);
        const hg = resolveHostGroup(d);
        if (mz === '') {
          fail(
            `monitored_meets "${id}": no zone in any known field (${MEET_ZONE_KEYS.join(', ')})`,
          );
          bumpFail();
          missingZoneCount += 1;
        } else if (zoneIds.size > 0 && !zoneIds.has(mz.toUpperCase())) {
          warn(
            `monitored_meets "${id}": resolved zone="${mz}" not in sampled metadata_clubs zone_id set`,
          );
          bumpWarn();
        } else {
          ok(`monitored_meets "${id}": zone=${mz}`);
        }
        if (hg === '') {
          warn(
            `monitored_meets "${id}": no host in known fields (${MEET_HOST_KEYS.join(', ')}) — home-club sort degraded`,
          );
          bumpWarn();
        }
      }
      if (missingZoneCount === 0 && meetSnap.size > 0) {
        info('All sampled meets have a zone via snake_case or camelCase (or alias) fields.');
      }
    }
  }

  // --- Query smoke test (optional server filter; app filters client-side) ---
  console.log('\nQuery smoke test (optional — app uses client-side zone filter):');
  for (const field of ['meet_zone', 'meetZone']) {
    try {
      await db.collection(MONITORED_MEETS).where(field, '==', '__probe_zone__').limit(1).get();
      ok(`where("${field}" == ...) OK`);
    } catch (e) {
      if (String(e.message || e).includes('index')) {
        warn(`where("${field}"): index hint — ${e.message}`);
        bumpWarn();
      } else {
        warn(`where("${field}"): ${e.message}`);
        bumpWarn();
      }
    }
  }

  // --- Summary ---
  console.log('\n=== Summary ===');
  console.log(`  Blocking failures: ${blockingFailures}`);
  console.log(`  Warnings:         ${warnings}`);
  if (blockingFailures > 0) {
    console.log('\nFix FAIL items before expecting the app to work end-to-end.\n');
    process.exit(1);
  }
  console.log('\nNo blocking failures. Review WARN lines for data quality.\n');
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

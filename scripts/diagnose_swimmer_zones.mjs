#!/usr/bin/env node
/**
 * Deep diagnosis for swimmer zone + meets (matches app logic).
 *
 *   cd scripts && node diagnose_swimmer_zones.mjs
 *   # or pass key file (avoids exporting env in some shells):
 *   node diagnose_swimmer_zones.mjs /path/to/serviceAccount.json
 *
 * Or: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *
 * Optional: SWIMMER_OWNER_UID=firebaseAuthUid to focus one swimmer
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';

const MEET_ZONE_KEYS = [
  'meet_zone', 'meetZone', 'MeetZone', 'zone_id', 'zoneId', 'zone', 'pacific_zone', 'PacificZone',
];

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
  return deriveMeetZoneFromRegion(d) || '';
}

function isSwimmerZonePlaceholder(raw) {
  if (raw == null) return true;
  const t = String(raw).trim().toLowerCase();
  if (!t) return true;
  if (t.includes('unknown')) return true;
  if (['n/a', 'na', 'none', 'tbd', 'null'].includes(t)) return true;
  if (t.startsWith('select')) return true;
  return false;
}

function initDb(credPathArg) {
  const credPath = credPathArg || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const explicitProject = process.env.FIREBASE_PROJECT_ID;
  if (getApps().length > 0) return getFirestore();
  if (credPath && existsSync(credPath)) {
    const raw = JSON.parse(readFileSync(credPath, 'utf8'));
    const projectId = raw.project_id || explicitProject;
    if (!projectId) {
      console.error('service account JSON missing project_id; set FIREBASE_PROJECT_ID');
      process.exit(1);
    }
    initializeApp({ credential: cert(raw), projectId });
    return getFirestore();
  }
  try {
    initializeApp({ credential: applicationDefault(), projectId: explicitProject });
    return getFirestore();
  } catch (e) {
    console.error(`
No credentials. Use one of:
  export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/serviceAccount.json
  node diagnose_swimmer_zones.mjs /absolute/path/to/serviceAccount.json

${e.message || e}
`);
    process.exit(1);
  }
}

const CLUB_LOOKUP_FIELDS = ['club_code', 'code', 'lsc_club_code', 'team_code', 'club_id'];

async function findMetadataClubDoc(db, clubKey) {
  const key = String(clubKey || '').trim();
  if (!key) return null;
  const col = db.collection('metadata_clubs');
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
  return null;
}

async function main() {
  console.log('\n=== diagnose_swimmer_zones (Firestore) ===\n');
  const credArg = process.argv[2] && !process.argv[2].startsWith('-') ? process.argv[2] : '';

  const db = initDb(credArg || undefined);
  const focusUid = process.env.SWIMMER_OWNER_UID || '';

  const swimmersSnap = await db.collection('swimmers').limit(20).get();
  console.log(`swimmers: ${swimmersSnap.size} doc(s) (max 20)\n`);

  for (const doc of swimmersSnap.docs) {
    const d = doc.data();
    let owner = '';
    if (d.owner_id != null) {
      if (typeof d.owner_id === 'object' && d.owner_id.path) {
        owner = `${d.owner_id.path} (DocumentReference)`;
      } else {
        owner = String(d.owner_id);
      }
    }
    if (focusUid && owner !== focusUid && doc.id !== focusUid) continue;

    const name = d.name ?? d.display_name ?? '';
    const clubCode = d.club_code ?? d.lsc_club_code ?? d.group_id ?? '';
    const zoneId = d.zone_id != null ? String(d.zone_id) : '';
    const zoneDisp = d.zone_display_name != null ? String(d.zone_display_name) : '';

    console.log(`--- swimmer doc id=${doc.id} ---`);
    console.log('  owner_id:', owner || '(missing)');
    console.log('  name:', name);
    console.log('  club_code / group_id (lookup key):', clubCode || '(missing)');
    console.log('  zone_id (raw):', JSON.stringify(zoneId));
    console.log('  zone_display_name (raw):', JSON.stringify(zoneDisp));
    console.log('  isPlaceholder(zone_id):', isSwimmerZonePlaceholder(zoneId));
    console.log('  isPlaceholder(zone_display_name):', isSwimmerZonePlaceholder(zoneDisp));
    console.log('  App "currentSwimmerZoneForMeets" would be:',
      isSwimmerZonePlaceholder(zoneId) ? '(empty — bad for filter)' : zoneId.trim());

    const meta = clubCode ? await findMetadataClubDoc(db, clubCode) : null;
    if (!clubCode) {
      console.log('  metadata_clubs lookup: SKIPPED (no club key)');
    } else if (!meta) {
      console.log(`  metadata_clubs lookup for "${clubCode}": NOT FOUND`);
    } else {
      const mz = meta.get('zone_id');
      const md = meta.get('zone_display_name');
      console.log(`  metadata_clubs match doc=${meta.id} zone_id=${JSON.stringify(mz)} zone_display_name=${JSON.stringify(md)}`);
    }
    console.log('  All field keys:', Object.keys(d).sort().join(', '));
    console.log('');
  }

  const meetsSnap = await db.collection('monitored_meets').limit(5).get();
  console.log(`Sample monitored_meets (first ${meetsSnap.size}):\n`);
  for (const doc of meetsSnap.docs) {
    const d = doc.data();
    const resolved = resolveMeetZone(d);
    console.log(`  id=${doc.id} resolved_meet_zone=${resolved || '(none)'} region_id=${JSON.stringify(d.region_id)} region_name=${JSON.stringify(d.region_name)}`);
  }

  const meetSample = await db.collection('monitored_meets').limit(200).get();
  const z2count = meetSample.docs.filter((x) => resolveMeetZone(x.data()) === 'Z2').length;
  console.log(`\nHeuristic: meets with resolved zone Z2 in first ${meetSample.size} docs: ${z2count}`);

  console.log(`
Tip: If swimmer zone_id stays empty in Firestore after app login, rules may block writes.
     Admin backfill (service account):  npm run hydrate-swimmers:apply
`);

  console.log('Done.\n');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

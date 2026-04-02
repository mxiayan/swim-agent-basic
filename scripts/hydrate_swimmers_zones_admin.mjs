#!/usr/bin/env node
/**
 * Firestore **Admin** one-shot: copy `zone_id` / `zone_display_name` / `club_id`
 * from `metadata_clubs` onto `swimmers` when `club_code` exists but zone is missing
 * or placeholder (same rules as the Flutter `refreshSwimmerAppState` merge).
 *
 * Use when diagnose shows empty `zone_id` because **security rules** block the
 * client `set(merge)` from the app.
 *
 *   cd scripts
 *   node hydrate_swimmers_zones_admin.mjs --dry-run
 *   node hydrate_swimmers_zones_admin.mjs
 *   node hydrate_swimmers_zones_admin.mjs /path/to/serviceAccount.json
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';

function initDb(credPathArg) {
  const credPath = credPathArg || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const explicitProject = process.env.FIREBASE_PROJECT_ID;
  if (getApps().length > 0) return getFirestore();
  if (credPath && existsSync(credPath)) {
    const raw = JSON.parse(readFileSync(credPath, 'utf8'));
    const projectId = raw.project_id || explicitProject;
    if (!projectId) {
      console.error('Missing project_id in JSON; set FIREBASE_PROJECT_ID');
      process.exit(1);
    }
    initializeApp({ credential: cert(raw), projectId });
    return getFirestore();
  }
  initializeApp({ credential: applicationDefault(), projectId: explicitProject });
  return getFirestore();
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
  if (upper !== key) {
    for (const field of ['club_code', 'code', 'lsc_club_code']) {
      const q = await col.where(field, '==', upper).limit(1).get();
      if (!q.empty) return q.docs[0];
    }
  }
  return null;
}

async function main() {
  const args = process.argv.slice(2).filter((a) => a !== '--dry-run');
  const dryRun = process.argv.includes('--dry-run');
  const credArg = args[0] && args[0].endsWith('.json') ? args[0] : '';

  console.log('\n=== hydrate_swimmers_zones_admin ===\n');
  const db = initDb(credArg || undefined);

  const snap = await db.collection('swimmers').limit(500).get();
  let updated = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const clubKey = (d.club_code || d.lsc_club_code || d.group_id || '').toString().trim();
    const rawZone = d.zone_id != null ? String(d.zone_id) : '';

    if (!clubKey) {
      console.log(`skip swimmers/${doc.id}: no club_code / lsc_club_code / group_id`);
      skipped += 1;
      continue;
    }

    if (rawZone && !isSwimmerZonePlaceholder(rawZone)) {
      console.log(`skip swimmers/${doc.id}: zone_id already ${rawZone}`);
      skipped += 1;
      continue;
    }

    const meta = await findMetadataClubDoc(db, clubKey);
    if (!meta?.exists) {
      console.log(`skip swimmers/${doc.id}: metadata_clubs not found for "${clubKey}"`);
      skipped += 1;
      continue;
    }

    const z = meta.get('zone_id');
    if (z == null || !String(z).trim()) {
      console.log(`skip swimmers/${doc.id}: metadata ${meta.id} has empty zone_id`);
      skipped += 1;
      continue;
    }

    const zoneId = String(z).trim();
    const zd = meta.get('zone_display_name');
    const zdStr = zd != null && String(zd).trim() ? String(zd).trim() : null;

    const patch = {
      zone_id: zoneId,
      club_id: meta.id,
      hydrated_by_admin_at: FieldValue.serverTimestamp(),
    };
    if (zdStr) {
      patch.zone_display_name = zdStr;
    }

    const label = `${doc.id} club=${clubKey} -> zone_id=${zoneId}${zdStr ? ` display=${zdStr}` : ''}`;

    if (dryRun) {
      console.log(`[dry-run] ${label}`);
    } else {
      await doc.ref.set(patch, { merge: true });
      console.log(`WRITE ${label}`);
    }
    updated += 1;
  }

  console.log(`\nDone. ${dryRun ? 'Would update' : 'Updated'}: ${updated}, skipped: ${skipped}`);
  console.log('Re-run: npm run diagnose\n');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

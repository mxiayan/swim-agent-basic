#!/usr/bin/env node
/**
 * Merge Pacific Swimming (or any LSC) club rows into Firestore ``metadata_clubs``.
 * Unlike ``seed_metadata_club_home_pools.mjs``, ``home_pool_location`` is optional.
 *
 * Source example (Pacific Zone 2 member clubs):
 *   https://www.pacswim.org/members/zones/zone-2/zone-2-teams-directory
 *
 * Usage:
 *   cd scripts
 *   node seed_metadata_clubs_zones.mjs --dry-run \\
 *     --zone-id=Z2 \\
 *     --zone-display='Pacific Swimming Zone 2' \\
 *     data/pacific_swimming_zone2_clubs.json [serviceAccount.json]
 *
 * Row fields (JSON array):
 *   document_id   — Firestore doc id (required); usually USA Swimming club code (e.g. OAPB)
 *   club_code     — optional; defaults to document_id
 *   club_name     — display name (required)
 *   name          — optional alias for ``name`` field; defaults to club_name
 *   zone_id / zone_display_name — optional per-row overrides of CLI defaults
 *   lsc_name / lsc_code — optional per-row; otherwise CLI defaults
 *   home_pool_location — optional canonical pool line
 *   city_state — optional note only (not written unless you map it yourself)
 *
 * Uses GOOGLE_APPLICATION_CREDENTIALS when no JSON path is passed.
 *
 * Companion — creates ``teams/{teamId}`` stubs from the same JSON:
 *   node seed_teams_from_json.mjs [--dry-run] data/pacific_swimming_zone2_clubs.json
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

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

function argValue(flag) {
  const a = process.argv.find((x) => x === flag || x.startsWith(`${flag}=`));
  if (!a) return '';
  if (a.includes('=')) return a.split('=').slice(1).join('=').trim();
  const i = process.argv.indexOf(flag);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1].trim();
  return '';
}

function mergeRow(row, globalDefaults) {
  const out = { ...globalDefaults };
  const copy = [
    'home_pool_location',
    'club_code',
    'club_name',
    'name',
    'lsc_name',
    'lsc_code',
    'zone_id',
    'zone_display_name',
  ];
  for (const k of copy) {
    if (row[k] != null && String(row[k]).trim() !== '') {
      out[k] = String(row[k]).trim();
    }
  }
  const clubName = out.club_name || out.name;
  if (clubName && !out.name) out.name = clubName;
  if (clubName && !out.club_name) out.club_name = clubName;

  if (row.pacific_swimming === true) out.pacific_swimming = true;
  return out;
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const positional = process.argv.slice(2).filter((a) => !a.startsWith('--'));
  const jsonFiles = positional.filter((a) => a.endsWith('.json'));
  const jsonPathRaw = jsonFiles[0];
  const credArg = jsonFiles.length > 1 ? jsonFiles[1] : '';

  const zoneId = argValue('--zone-id');
  const zoneDisplay = argValue('--zone-display');
  const lscName = argValue('--lsc-name') || 'Pacific Swimming';
  const lscCode = argValue('--lsc-code') || 'PC';

  if (!jsonPathRaw) {
    console.error(
      'Usage: node seed_metadata_clubs_zones.mjs [--dry-run] --zone-id=Z2 --zone-display="..." <clubs.json> [serviceAccount.json]',
    );
    process.exit(1);
  }

  const jsonPath = resolve(__dirname, jsonPathRaw);
  if (!existsSync(jsonPath)) {
    console.error(`Missing JSON: ${jsonPath}`);
    process.exit(1);
  }

  if (!zoneId || !zoneDisplay) {
    console.error('Required: --zone-id and --zone-display');
    process.exit(1);
  }

  let rows;
  try {
    rows = JSON.parse(readFileSync(jsonPath, 'utf8'));
  } catch (e) {
    console.error('Invalid JSON:', e.message);
    process.exit(1);
  }
  if (!Array.isArray(rows)) {
    console.error('JSON root must be an array');
    process.exit(1);
  }

  const globalDefaults = {
    zone_id: zoneId,
    zone_display_name: zoneDisplay,
    lsc_name: lscName,
    lsc_code: lscCode,
    pacific_swimming: true,
  };

  console.log('\n=== seed_metadata_clubs_zones ===\n');
  console.log(`defaults: zone_id=${zoneId} zone_display_name=${JSON.stringify(zoneDisplay)} LSC=${lscName} (${lscCode})\n`);

  const db = initDb(credArg || undefined);
  const col = db.collection('metadata_clubs');

  let n = 0;
  for (const row of rows) {
    const rawId = String(row.document_id ?? '').trim();
    if (!rawId) continue;

    const docId = rawId.toUpperCase();
    const clubName = String(row.club_name || row.name || '').trim();
    if (!clubName) {
      console.warn(`Skip ${docId}: missing club_name`);
      continue;
    }

    const merge = mergeRow({ ...row, document_id: docId }, globalDefaults);
    if (!merge.club_code) merge.club_code = docId;

    n += 1;
    if (dryRun) {
      console.log(`[dry-run] metadata_clubs/${docId} ← ${JSON.stringify(merge)}`);
      continue;
    }
    await col.doc(docId).set(merge, { merge: true });
    console.log(`updated metadata_clubs/${docId}`);
  }

  console.log(
    dryRun ? `\nDry-run: ${n} row(s) would be merged.\n` : `\nDone: merged ${n} document(s).\n`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

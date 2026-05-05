#!/usr/bin/env node
/**
 * Merge canonical home pool lines onto ``metadata_clubs`` for Gemini coach-email parsing.
 *
 * JSON format: array of objects:
 *   document_id        — Firestore doc id under metadata_clubs (required)
 *   home_pool_location — single authoritative line for that club’s pool (required)
 *   club_code, club_name, lsc_name, lsc_code, zone_id, zone_display_name — optional merges
 *   pacific_swimming   — if true, treated as PC (optional; lsc_name / lsc_code usually enough)
 *
 *   cd scripts
 *   cp pc_swim_home_pools.example.json pc_swim_home_pools.json
 *   # Add Pacific clubs; tag each as PC via lsc_name (e.g. Pacific Swimming),
 *   # lsc_code PC, or pacific_swimming: true — otherwise the parser skips them.
 *   node seed_metadata_club_home_pools.mjs --dry-run pc_swim_home_pools.json
 *   node seed_metadata_club_home_pools.mjs pc_swim_home_pools.json [serviceAccount.json]
 *
 * Uses GOOGLE_APPLICATION_CREDENTIALS when no JSON path is passed.
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
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

function pickMerge(row) {
  const out = {};
  const copy = [
    'home_pool_location',
    'club_code',
    'club_name',
    'name',
    'lsc_name',
    'lsc_code',
    'lsc',
    'zone_id',
    'zone_display_name',
  ];
  for (const k of copy) {
    if (row[k] != null && String(row[k]).trim() !== '') {
      out[k] = String(row[k]).trim();
    }
  }
  if (row.pacific_swimming === true) {
    out.pacific_swimming = true;
  }
  return out;
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const positional = process.argv.slice(2).filter((a) => a !== '--dry-run');
  const jsonFiles = positional.filter((a) => a.endsWith('.json'));
  const jsonPath = jsonFiles[0];
  const credArg = jsonFiles.length > 1 ? jsonFiles[1] : '';

  if (!jsonPath || !existsSync(jsonPath)) {
    console.error(
      'Usage: node seed_metadata_club_home_pools.mjs [--dry-run] <clubs.json> [serviceAccount.json]',
    );
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

  console.log('\n=== seed_metadata_club_home_pools ===\n');
  const db = initDb(credArg || undefined);
  const col = db.collection('metadata_clubs');

  let n = 0;
  for (const row of rows) {
    const docId = String(row.document_id || '').trim();
    const pool = String(row.home_pool_location || '').trim();
    if (!docId || !pool) {
      console.warn('Skip row missing document_id or home_pool_location:', JSON.stringify(row));
      continue;
    }
    const merge = pickMerge(row);
    if (!merge.home_pool_location) {
      merge.home_pool_location = pool;
    }
    n += 1;
    if (dryRun) {
      console.log(`[dry-run] metadata_clubs/${docId} merge keys: ${Object.keys(merge).join(', ')}`);
      continue;
    }
    await col.doc(docId).set(merge, { merge: true });
    console.log(`updated metadata_clubs/${docId}`);
  }

  console.log(
    dryRun
      ? `\nDry-run: ${n} row(s) would be merged.\n`
      : `\nDone: merged ${n} document(s).\n`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

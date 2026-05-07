#!/usr/bin/env node
/**
 * Import season schedule JSON into Firestore:
 *   teams/{team_id}/schedule_items/{schedule_item_id}
 *
 * Also merges team-level metadata onto teams/{team_id} (schedule_source, season, etc.).
 *
 *   cd scripts
 *   node import_team_schedule_items.mjs [--dry-run] data/oapb_team_schedule_2025_2026.json [serviceAccount.json]
 *
 * Requires firebase-admin (project uses it elsewhere). Uses batches of 400 writes.
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { existsSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
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

/** Parse YYYY-MM-DD to UTC midnight Timestamp (date-only fields). */
function dateOnlyToTs(iso) {
  if (iso == null || iso === '') return null;
  const s = String(iso).trim();
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  const y = Number(m[1]);
  const mo = Number(m[2]) - 1;
  const d = Number(m[3]);
  return Timestamp.fromDate(new Date(Date.UTC(y, mo, d)));
}

function teamDocPayload(root) {
  return {
    team_id: root.team_id,
    team_name: root.team_name,
    season: root.season,
    schedule_source: root.source ?? null,
    schedule_collection_hint: root.collection_recommendation ?? null,
    schedule_items_imported_at: FieldValue.serverTimestamp(),
  };
}

function itemDocPayload(row) {
  const out = { ...row };
  out.start_date_ts = dateOnlyToTs(row.start_date);
  out.end_date_ts = dateOnlyToTs(row.end_date);
  return out;
}

async function commitBatches(db, ops, dryRun) {
  const chunk = 400;
  for (let i = 0; i < ops.length; i += chunk) {
    const slice = ops.slice(i, i + chunk);
    const batch = db.batch();
    for (const { ref, data } of slice) {
      batch.set(ref, data, { merge: true });
    }
    if (dryRun) {
      console.log(`[dry-run] would commit batch ${i / chunk + 1} (${slice.length} docs)`);
    } else {
      await batch.commit();
      console.log(`Committed batch ${i / chunk + 1} (${slice.length} docs)`);
    }
  }
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const positional = process.argv.slice(2).filter((a) => a !== '--dry-run');
  const jsonFiles = positional.filter((a) => a.endsWith('.json'));
  const jsonPath = jsonFiles[0]
    ? join(process.cwd(), jsonFiles[0])
    : join(__dirname, 'data', 'oapb_team_schedule_2025_2026.json');
  const credArg = jsonFiles.length > 1 ? jsonFiles[1] : '';

  if (!existsSync(jsonPath)) {
    console.error(
      'Usage: node import_team_schedule_items.mjs [--dry-run] <schedule.json> [serviceAccount.json]',
    );
    console.error(`Missing file: ${jsonPath}`);
    process.exit(1);
  }

  const root = JSON.parse(readFileSync(jsonPath, 'utf8'));
  const teamId = root.team_id;
  const items = root.schedule_items;
  if (!teamId || !Array.isArray(items)) {
    console.error('JSON must include team_id and schedule_items[]');
    process.exit(1);
  }

  const db = initDb(credArg);
  const teamRef = db.collection('teams').doc(teamId);
  const col = teamRef.collection('schedule_items');

  const ops = [];
  ops.push({ ref: teamRef, data: teamDocPayload(root) });

  for (const row of items) {
    const id = row.schedule_item_id;
    if (!id) {
      console.warn('Skipping row without schedule_item_id', row);
      continue;
    }
    ops.push({ ref: col.doc(id), data: itemDocPayload(row) });
  }

  console.log(
    `Team ${teamId}: ${items.length} schedule items (+1 team metadata doc). dryRun=${dryRun}`,
  );
  await commitBatches(db, ops, dryRun);
  console.log('Done.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

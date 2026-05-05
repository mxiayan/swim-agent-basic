#!/usr/bin/env node
/**
 * Seed ``metadata_teams/{document_id}`` for hybrid grounding (sender lookup).
 * Include ``sender_emails`` (array) for FieldFilter array_contains on From address,
 * and ``grounding_truth`` (verbatim block for Gemini GROUNDING_FACTS).
 * Document id becomes ``team_id`` on ``team_events`` when this row matches.
 *
 *   cd scripts
 *   cp metadata_teams.example.json metadata_teams.json
 *   node seed_metadata_teams.mjs --dry-run metadata_teams.json
 *   node seed_metadata_teams.mjs metadata_teams.json [serviceAccount.json]
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
  const strFields = [
    'organization_display_name',
    'home_pool_canonical',
    'home_pool_address',
    'home_pool_location',
    'supplementary_notes',
    'grounding_truth',
    'parser_hints',
    'parser_schedule_context',
    'default_timezone',
    'display_name',
  ];
  for (const k of strFields) {
    if (row[k] != null && String(row[k]).trim() !== '') {
      out[k] = String(row[k]).trim();
    }
  }
  if (Array.isArray(row.sender_emails) && row.sender_emails.length > 0) {
    out.sender_emails = row.sender_emails
      .map((e) => String(e).trim().toLowerCase())
      .filter(Boolean);
  }
  if (Array.isArray(row.groups) && row.groups.length > 0) {
    out.groups = row.groups.map((g) => String(g).trim());
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
      'Usage: node seed_metadata_teams.mjs [--dry-run] <teams.json> [serviceAccount.json]',
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

  console.log('\n=== seed_metadata_teams ===\n');
  const db = initDb(credArg || undefined);
  const col = db.collection('metadata_teams');

  let n = 0;
  for (const row of rows) {
    const docId = String(row.document_id || '').trim().toLowerCase();
    const merge = pickMerge(row);
    if (!docId || Object.keys(merge).length === 0) {
      console.warn('Skip row missing document_id or merge fields:', JSON.stringify(row));
      continue;
    }
    if (!merge.sender_emails || merge.sender_emails.length === 0) {
      console.warn('Skip row: sender_emails array required for hybrid lookup:', docId);
      continue;
    }
    const hasPool =
      merge.home_pool_canonical ||
      merge.home_pool_address ||
      merge.home_pool_location;
    if (!merge.grounding_truth && !hasPool) {
      console.warn(
        'Skip row: set grounding_truth or at least one home_pool_* field:',
        docId,
      );
      continue;
    }
    n += 1;
    if (dryRun) {
      console.log(`[dry-run] metadata_teams/${docId} ← ${JSON.stringify(merge)}`);
      continue;
    }
    await col.doc(docId).set(merge, { merge: true });
    console.log(`updated metadata_teams/${docId}`);
  }

  console.log(
    dryRun ? `\nDry-run: ${n} row(s).\n` : `\nDone: ${n} document(s).\n`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

#!/usr/bin/env node
/**
 * One-shot Admin fix: `teams/oapb` → `parser_hints` wrongly ties Soda Center to
 * Saint Mary's College. Correct facility is Campolindo High School (Moraga).
 *
 *   cd scripts
 *   node fix_oapb_parser_hints_soda_venue.mjs --dry-run [/path/to/serviceAccount.json]
 *   node fix_oapb_parser_hints_soda_venue.mjs [/path/to/serviceAccount.json]
 *
 * Uses GOOGLE_APPLICATION_CREDENTIALS if no JSON path is passed (same pattern as
 * hydrate_swimmers_zones_admin.mjs).
 */

import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';

const TEAM_ID = 'oapb';
const DOC_PATH = `teams/${TEAM_ID}`;

/** Canonical ground truth for coach-email / parser matching */
const REPLACEMENT_STRING =
  'Soda Aquatic Center at Campolindo High School, 300 Moraga Rd, Moraga, CA 94556';

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

function pathTouchesSoda(pathParts) {
  return pathParts.some((p) => /soda/i.test(String(p)));
}

/**
 * Replace Saint Mary's–related text when the JSON path or the string itself
 * mentions Soda (covers nested keys like `soda_center`, `Soda Center`, etc.).
 */
function fixHintsNode(node, pathParts, stats) {
  if (node === null || node === undefined) return node;

  if (typeof node === 'string') {
    if (!/saint\s*mary/i.test(node)) return node;
    const sodaContext = pathTouchesSoda(pathParts) || /soda/i.test(node);
    if (!sodaContext) return node;
    stats.replaced += 1;
    return REPLACEMENT_STRING;
  }

  if (Array.isArray(node)) {
    let changed = false;
    const next = node.map((item, i) => {
      const v = fixHintsNode(item, [...pathParts, String(i)], stats);
      if (v !== item) changed = true;
      return v;
    });
    return changed ? next : node;
  }

  if (typeof node === 'object') {
    let changed = false;
    const next = {};
    for (const [k, v] of Object.entries(node)) {
      const v2 = fixHintsNode(v, [...pathParts, k], stats);
      next[k] = v2;
      if (v2 !== v) changed = true;
    }
    return changed ? next : node;
  }

  return node;
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const args = process.argv.slice(2).filter((a) => a !== '--dry-run');
  const credArg = args[0] && args[0].endsWith('.json') ? args[0] : '';

  console.log('\n=== fix_oapb_parser_hints_soda_venue ===\n');
  const db = initDb(credArg || undefined);
  const ref = db.doc(DOC_PATH);
  const snap = await ref.get();
  if (!snap.exists) {
    console.error(`Missing document ${DOC_PATH}`);
    process.exit(1);
  }

  const data = snap.data() || {};
  const hints = data.parser_hints;
  if (hints === undefined) {
    console.error('No parser_hints field on document; nothing to patch.');
    process.exit(1);
  }

  const stats = { replaced: 0 };
  const fixed = fixHintsNode(hints, [], stats);

  if (stats.replaced === 0) {
    console.log(
      'No matching Saint Mary strings found under Soda-related paths (or in Soda-related strings).',
    );
    console.log('Current parser_hints (JSON):');
    console.log(JSON.stringify(hints, null, 2));
    console.log(
      '\nIf the wrong campus is stored without "Saint Mary" wording or without a "soda" key in the path, edit Firestore manually or extend this script.',
    );
    process.exit(0);
  }

  console.log(`Found ${stats.replaced} string field(s) to replace.\n`);
  if (dryRun) {
    console.log('--- BEFORE (parser_hints) ---');
    console.log(JSON.stringify(hints, null, 2));
    console.log('\n--- AFTER (dry-run) ---');
    console.log(JSON.stringify(fixed, null, 2));
    console.log('\nRe-run without --dry-run to write.');
    return;
  }

  await ref.set({ parser_hints: fixed }, { merge: true });
  console.log(`Updated ${DOC_PATH} parser_hints (merge).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

#!/usr/bin/env node
/**
 * Merge lightweight club rows into Firestore ``teams/{teamId}`` for schedule imports,
 * cross-check aliases, and future app wiring. Uses ``set(..., { merge: true })`` so
 * existing fields (``parser_hints``, branding, etc.) stay intact.
 *
 * Intended for the same Pacific zone JSON used by ``seed_metadata_clubs_zones.mjs``:
 *   data/pacific_swimming_zone2_clubs.json
 *
 * Doc id defaults to lowercase USA club code:
 *   document_id / club_code ``OAPB`` → ``teams/oapb``
 *
 * Usage:
 *   cd scripts
 *   node seed_teams_from_json.mjs --dry-run \\
 *     --lsc-name='Pacific Swimming' \\
 *     data/pacific_swimming_zone2_clubs.json [serviceAccount.json]
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

function pickTeamMerge(row, { lscName }) {
  const clubName = String(row.club_name || row.name || '').trim();
  const codeRaw = String(row.club_code || row.document_id || '').trim().toUpperCase();
  const loc = String(row.city_state || row.location || '').trim();

  const out = {};
  if (clubName) {
    out.name = clubName;
    out.display_name = String(row.display_name || clubName).trim();
  }
  if (codeRaw) out.club_code = codeRaw;
  if (lscName) out.lsc_name = lscName;
  out.sport = String(row.sport || 'swimming').trim();
  if (loc) out.location = loc;

  const aliases = row.schedule_match_aliases ?? row.scheduleMatchAliases;
  if (Array.isArray(aliases) && aliases.length) {
    out.schedule_match_aliases = aliases.map((x) => String(x).trim()).filter(Boolean);
  }

  const groups = row.groups;
  if (Array.isArray(groups) && groups.length) {
    out.groups = groups.map((x) => String(x).trim()).filter(Boolean);
  }

  return out;
}

function defaultTeamId(row) {
  const explicit = String(row.team_id || row.teamId || '').trim().toLowerCase();
  if (explicit) return explicit;
  const code = String(row.document_id || row.club_code || '').trim().toLowerCase();
  return code;
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const positional = process.argv.slice(2).filter((a) => !a.startsWith('--'));
  const jsonFiles = positional.filter((a) => a.endsWith('.json'));
  const jsonPathRaw = jsonFiles[0];
  const credArg = jsonFiles.length > 1 ? jsonFiles[1] : '';

  const lscName = argValue('--lsc-name') || 'Pacific Swimming';

  if (!jsonPathRaw) {
    console.error(
      'Usage: node seed_teams_from_json.mjs [--dry-run] [--lsc-name="Pacific Swimming"] <clubs.json> [serviceAccount.json]',
    );
    process.exit(1);
  }

  const jsonPath = resolve(__dirname, jsonPathRaw);
  if (!existsSync(jsonPath)) {
    console.error(`Missing JSON: ${jsonPath}`);
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

  console.log('\n=== seed_teams_from_json ===\n');
  console.log(`lsc_name default: ${JSON.stringify(lscName)}\n`);

  const db = initDb(credArg || undefined);
  const teamsCol = db.collection('teams');

  let n = 0;
  for (const row of rows) {
    const teamId = defaultTeamId(row);
    if (!teamId) continue;

    const merge = pickTeamMerge(row, { lscName });
    if (!merge.name && !merge.club_code) {
      console.warn(`Skip teams/${teamId}: missing club_name and club_code`);
      continue;
    }

    n += 1;
    if (dryRun) {
      console.log(`[dry-run] teams/${teamId} ← ${JSON.stringify(merge)}`);
      continue;
    }
    await teamsCol.doc(teamId).set(merge, { merge: true });
    console.log(`updated teams/${teamId}`);
  }

  console.log(
    dryRun ? `\nDry-run: ${n} row(s) would be merged.\n` : `\nDone: merged ${n} team document(s).\n`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

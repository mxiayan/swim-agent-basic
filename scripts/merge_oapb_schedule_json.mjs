#!/usr/bin/env node
/**
 * Merge scripts/data/oapb_schedule_meta.json + oapb_schedule_items_*.json arrays
 * into scripts/data/oapb_team_schedule_2025_2026.json
 */
import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const dataDir = join(__dirname, 'data');

const meta = JSON.parse(readFileSync(join(dataDir, 'oapb_schedule_meta.json'), 'utf8'));
const shards = ['oapb_schedule_items_1.json', 'oapb_schedule_items_2.json', 'oapb_schedule_items_3.json', 'oapb_schedule_items_4.json'];

const schedule_items = [];
for (const name of shards) {
  const arr = JSON.parse(readFileSync(join(dataDir, name), 'utf8'));
  if (!Array.isArray(arr)) throw new Error(`${name} must be a JSON array`);
  schedule_items.push(...arr);
}

meta.schedule_items = schedule_items;
const out = join(dataDir, 'oapb_team_schedule_2025_2026.json');
writeFileSync(out, JSON.stringify(meta, null, 2), 'utf8');
console.log(`Wrote ${out} (${schedule_items.length} items)`);

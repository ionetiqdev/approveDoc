// reset-testbed.js
// Clears all document, audience and distribution data from approveDoc.
// Preserves: users, lookup tables, organisations, profiles, issues.
// Also empties the Supabase Storage 'documents' bucket.
//
// Usage: node reset-testbed.js YOUR_SERVICE_ROLE_KEY
// Requires: npm install @supabase/supabase-js ws

const { createClient } = require('@supabase/supabase-js');
const ws = require('ws');

const SERVICE_KEY = process.argv[2];
if (!SERVICE_KEY) {
  console.error('Usage: node reset-testbed.js YOUR_SERVICE_ROLE_KEY');
  process.exit(1);
}

const sb = createClient(
  'https://nkwpqboslnbeifyaegos.supabase.co',
  SERVICE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false }, realtime: { transport: ws } }
);

// Tables and their primary key columns, in FK-safe delete order (children first)
const TABLES = [
  { name: 'ad_distribution_item',   pk: 'distrib_item_id' },
  { name: 'ad_distribution_audience', pk: 'id' },
  { name: 'ad_distribution',         pk: 'distribution_id' },
  { name: 'ad_audience_member',      pk: 'member_id' },
  { name: 'ad_audience_criteria',    pk: 'criteria_id' },
  { name: 'ad_audience',             pk: 'audience_id' },
  { name: 'ad_document_file',        pk: 'id' },
  { name: 'ad_document_version',     pk: 'version_id' },
  { name: 'ad_related_document',     pk: 'id' },
  { name: 'ad_document',             pk: 'doc_id' },
];

const BUCKETS = ['documents'];

async function truncateTables() {
  console.log('\n── Clearing database tables ──');
  for (const { name, pk } of TABLES) {
    // Select all PKs then delete — works regardless of column names
    const { data, error: selErr } = await sb.from(name).select(pk);
    if (selErr) { console.error(`  ✗ ${name} (select): ${selErr.message}`); continue; }
    if (!data || data.length === 0) { console.log(`  - ${name}: already empty`); continue; }

    const { error: delErr } = await sb.from(name).delete().in(pk, data.map(r => r[pk]));
    if (delErr) { console.error(`  ✗ ${name} (delete): ${delErr.message}`); continue; }
    console.log(`  ✓ ${name}: ${data.length} row(s) deleted`);
  }
}

async function emptyBucket(bucket) {
  let totalDeleted = 0;

  async function listAndDelete(prefix) {
    const { data: files, error } = await sb.storage.from(bucket).list(prefix, { limit: 1000 });
    if (error) { console.error(`    list error (${prefix}): ${error.message}`); return; }
    if (!files || files.length === 0) return;

    const filePaths = [];
    const folders   = [];

    for (const f of files) {
      if (f.id) {
        filePaths.push(prefix ? `${prefix}/${f.name}` : f.name);
      } else {
        folders.push(prefix ? `${prefix}/${f.name}` : f.name);
      }
    }

    if (filePaths.length > 0) {
      const { error: delErr } = await sb.storage.from(bucket).remove(filePaths);
      if (delErr) console.error(`    delete error: ${delErr.message}`);
      else totalDeleted += filePaths.length;
    }

    for (const folder of folders) {
      await listAndDelete(folder);
    }
  }

  await listAndDelete('');
  return totalDeleted;
}

async function emptyBuckets() {
  console.log('\n── Emptying storage buckets ──');
  for (const bucket of BUCKETS) {
    const count = await emptyBucket(bucket);
    console.log(`  ✓ ${bucket}: ${count} file(s) deleted`);
  }
}

async function verify() {
  console.log('\n── Verification ──');
  for (const { name } of TABLES) {
    const { count } = await sb.from(name).select('*', { count: 'exact', head: true });
    console.log(`  ${name}: ${count ?? 0} rows`);
  }
}

(async () => {
  console.log('approveDoc Test Bed Reset');
  console.log('=========================');
  console.log('Preserving: users, lookups, organisations, profiles, issues');

  await truncateTables();
  await emptyBuckets();
  await verify();

  console.log('\nDone. Ready to build a fresh test bed.');
  process.exit(0);
})();

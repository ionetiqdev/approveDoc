// create-real-users.js
// Usage: node create-real-users.js YOUR_SERVICE_ROLE_KEY
// Requires: npm install @supabase/supabase-js ws
//
// Run 2: fixes Sarah, Susan, David who have new auth UUIDs but
// ad_user/audience not yet updated. George and Mark are already done.

const { createClient } = require('@supabase/supabase-js');
const ws = require('ws');

const SERVICE_KEY = process.argv[2];
if (!SERVICE_KEY) {
  console.error('Usage: node create-real-users.js YOUR_SERVICE_ROLE_KEY');
  process.exit(1);
}

const sb = createClient(
  'https://nkwpqboslnbeifyaegos.supabase.co',
  SERVICE_KEY,
  {
    auth: { autoRefreshToken: false, persistSession: false },
    realtime: { transport: ws },
  }
);

const ORG_ID = '0b116913-5b27-4c19-8eb9-bf5c4787e780';
const PASSWORD = 'ionetiQ2000!';

// Sarah, Susan, David: new auth accounts already created in run 1.
// oldAuthId = the @testdata.invalid UUID still in ad_user
// newId     = the new UUID already created in auth.users
const USERS = [
  { email: 'ad.user3@gardensol.net',    displayName: 'Sarah Scott',  role: 'user',  oldAuthId: '0eb5466c-b4f8-4382-8275-4da17d7608a6', newId: '318f049f-a484-4091-9d3d-d7522c93f8f8' },
  { email: 'ad.manager2@gardensol.net', displayName: 'Susan Moore',  role: 'admin', oldAuthId: '2946c015-8861-4535-8542-ec3df2d67ddd', newId: '39a1fa58-64e7-48d1-aa20-219e984107f8' },
  { email: 'ad.admin@gardensol.net',    displayName: 'David Harris', role: 'admin', oldAuthId: '73f14583-4f23-43d0-a1ef-7466dfe4440b', newId: '8c1ff14e-b84f-474a-b125-fc71626aa8de' },
];

(async () => {
  let allOk = true;

  for (const u of USERS) {
    console.log(`\n── ${u.displayName} (${u.email}) ──`);
    console.log(`   old: ${u.oldAuthId}`);
    console.log(`   new: ${u.newId}`);

    // 1. Update audience memberships FIRST (before ad_user, to avoid FK violation)
    const { error: audErr } = await sb.from('ad_audience_member').update({ user_id: u.newId }).eq('user_id', u.oldAuthId);
    if (audErr) { console.error(`  x ad_audience_member: ${audErr.message}`); allOk = false; continue; }
    console.log('  + audience memberships updated');

    // 2. Update distribution items
    const { error: distErr } = await sb.from('ad_distribution_item').update({ user_id: u.newId }).eq('user_id', u.oldAuthId);
    if (distErr) { console.error(`  x ad_distribution_item: ${distErr.message}`); allOk = false; continue; }
    console.log('  + distribution items updated');

    // 3. Now safe to update ad_user
    const { error: adErr } = await sb.from('ad_user').update({ user_id: u.newId, email: u.email }).eq('user_id', u.oldAuthId);
    if (adErr) { console.error(`  x ad_user: ${adErr.message}`); allOk = false; continue; }
    console.log('  + ad_user updated');

    // 4. Upsert profiles, delete old
    const { error: profErr } = await sb.from('profiles').upsert(
      { id: u.newId, display_name: u.displayName, email: u.email, role: u.role, organisation_id: ORG_ID, updated_at: new Date().toISOString() },
      { onConflict: 'id' }
    );
    if (profErr) { console.error(`  x profiles: ${profErr.message}`); allOk = false; continue; }
    await sb.from('profiles').delete().eq('id', u.oldAuthId);
    console.log('  + profiles upserted');
  }

  console.log(allOk ? '\nAll users migrated successfully.' : '\nSome steps failed - check errors above.');
  process.exit(0);
})();

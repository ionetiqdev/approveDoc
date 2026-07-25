// upload-avatars.js
// Run from the folder containing the 6 PNG files
// Usage: node upload-avatars.js YOUR_SERVICE_ROLE_KEY
// Requires: npm install @supabase/supabase-js ws

const { createClient } = require('@supabase/supabase-js');
const ws  = require('ws');
const fs  = require('fs');
const path = require('path');

const SERVICE_KEY = process.argv[2];
if (!SERVICE_KEY) {
  console.error('Usage: node upload-avatars.js YOUR_SERVICE_ROLE_KEY');
  process.exit(1);
}

const sb = createClient(
  'https://nkwpqboslnbeifyaegos.supabase.co',
  SERVICE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false }, realtime: { transport: ws } }
);

const BUCKET = 'avatars';
const ORG_ID = '0b116913-5b27-4c19-8eb9-bf5c4787e780';

const USERS = [
  { file: 'jennifer-anderson.png', userId: '7133112d-8f3d-443d-997b-f88c2dd12b62', name: 'Jennifer Anderson' },
  { file: 'george_taylor.png',     userId: '05a42e21-0684-47ca-b527-fbf2e73c24f9', name: 'George Taylor'    },
  { file: 'sarah_scott.png',       userId: '318f049f-a484-4091-9d3d-d7522c93f8f8', name: 'Sarah Scott'      },
  { file: 'mark-king.png',         userId: 'b69d083b-eb65-4576-b80d-a42a4eb7fee0', name: 'Mark King'        },
  { file: 'susan-moore.png',       userId: '39a1fa58-64e7-48d1-aa20-219e984107f8', name: 'Susan Moore'      },
  { file: 'david_harris.png',      userId: '8c1ff14e-b84f-474a-b125-fc71626aa8de', name: 'David Harris'     },
];

(async () => {
  // Ensure avatars bucket exists
  const { data: buckets } = await sb.storage.listBuckets();
  if (!buckets?.find(b => b.name === BUCKET)) {
    console.log('Creating avatars bucket...');
    const { error } = await sb.storage.createBucket(BUCKET, { public: true });
    if (error) { console.error('Could not create bucket:', error.message); process.exit(1); }
    console.log('+ Bucket created');
  }

  let allOk = true;

  for (const u of USERS) {
    console.log(`\n── ${u.name} ──`);

    const filePath = path.join(process.cwd(), u.file);
    if (!fs.existsSync(filePath)) {
      console.error(`  x File not found: ${u.file}`);
      allOk = false;
      continue;
    }

    const fileData = fs.readFileSync(filePath);
    const storagePath = `${ORG_ID}/${u.userId}/avatar.png`;

    // Upload to storage (upsert so re-running is safe)
    const { error: upErr } = await sb.storage
      .from(BUCKET)
      .upload(storagePath, fileData, { contentType: 'image/png', upsert: true });

    if (upErr) { console.error(`  x Upload failed: ${upErr.message}`); allOk = false; continue; }
    console.log('  + Uploaded to storage');

    // Get public URL
    const { data: { publicUrl } } = sb.storage.from(BUCKET).getPublicUrl(storagePath);

    // Update profiles.avatar_url
    const { error: profErr } = await sb.from('profiles')
      .update({ avatar_url: publicUrl, updated_at: new Date().toISOString() })
      .eq('id', u.userId);

    if (profErr) { console.error(`  x profiles update failed: ${profErr.message}`); allOk = false; continue; }
    console.log(`  + avatar_url set: ${publicUrl}`);
  }

  console.log(allOk ? '\nAll avatars uploaded successfully.' : '\nSome steps failed - check errors above.');
  process.exit(0);
})();

# Mave Vault — Vercel + Supabase Full Package

Mave Vault adalah premium AI Prompt Library dengan frontend static yang siap di-host di Vercel dan backend Supabase.

## Isi package

- `index.html` — shell aplikasi.
- `css/style.css` — UI responsive black × burgundy.
- `js/config.js` — isi URL + anon key Supabase.
- `js/app.js` — Auth, dashboard, Vault, Featured, Profile, Reviews, Feedback, Owner Panel, upload, CRUD, download, WhatsApp.
- `supabase/schema.sql` — database, enum, trigger profile, RLS, Storage bucket + policies.
- `supabase/functions/admin-update-rank` — Edge Function untuk perubahan USER/VIP.
- `vercel.json` — konfigurasi hosting Vercel.

## 1. Buat project Supabase

Buka Supabase Dashboard dan buat project baru.

Masuk ke **SQL Editor**, lalu jalankan seluruh isi:

`supabase/schema.sql`

Jangan menghapus bagian RLS atau Storage policy.

## 2. Aktifkan Auth

Di Supabase:

**Authentication → Providers → Email**

Aktifkan Email provider.

Untuk testing cepat, email confirmation boleh dimatikan. Untuk production lebih aman tetap aktifkan confirmation.

Atur URL redirect di:

**Authentication → URL Configuration**

Tambahkan URL Vercel, contoh:

`https://mave-vault.vercel.app`

Jika memakai custom domain, tambahkan juga domain tersebut.

## 3. Isi config frontend

Edit `js/config.js`:

```js
window.MV_CONFIG={
  supabaseUrl:'https://PROJECT_REF.supabase.co',
  supabaseAnonKey:'YOUR_SUPABASE_ANON_KEY',
  siteName:'Mave Vault',
  storageBucket:'vault-media'
};
```

**Hanya anon/publishable key yang boleh berada di frontend.**

JANGAN pernah memasukkan `SUPABASE_SERVICE_ROLE_KEY` ke `config.js`.

## 4. Buat akun Owner

Register melalui halaman Mave Vault seperti user biasa.

Setelah akun dibuat, ambil UUID user dari:

**Supabase → Authentication → Users**

Kemudian jalankan di SQL Editor:

```sql
update public.profiles
set rank='OWNER', updated_at=now()
where id='UUID_AKUN_OWNER';
```

Logout/login kembali.

Owner Panel akan otomatis muncul.

Register dari frontend **tidak pernah menyediakan pilihan OWNER atau VIP**. Semua akun baru selalu USER.

## 5. Deploy Edge Function

Install Supabase CLI, login, lalu link project:

```bash
supabase login
supabase link --project-ref PROJECT_REF
```

Set secret service role:

```bash
supabase secrets set SUPABASE_URL=https://PROJECT_REF.supabase.co SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
```

Deploy:

```bash
supabase functions deploy admin-update-rank
```

Service role key hanya berada di Edge Function secret.

## 6. Deploy ke Vercel

Upload repository/folder ini ke GitHub lalu import repository tersebut di Vercel.

Atau gunakan Vercel CLI:

```bash
npm i -g vercel
vercel login
vercel
```

Karena ini frontend static, tidak perlu build command. Root directory adalah folder project Mave Vault.

## 7. Alur akun

### USER
- Register/Login
- Vault public
- Prompt public
- Review
- Feedback
- Profile
- My Prompts
- Updates/Berita
- Tidak melihat Owner Panel

### VIP
- Semua akses USER
- Prompt access VIP
- Tetap tidak melihat Owner Panel

### OWNER
- Semua akses VIP
- Owner Panel
- Create/Edit/Delete Prompt
- Publish/Draft
- Upload landscape image
- Featured 3 slot
- Manage USER/VIP
- Create/Edit/Delete Updates/Berita
- Feedback Inbox
- Activity Logs
- WhatsApp setting
- Tidak bisa didemote lewat UI/Edge Function

## 8. Storage

Bucket `vault-media` dibuat otomatis oleh SQL.

Folder yang digunakan frontend:

- `prompts/`
- `updates/`

File dapat di-upload Owner dari Owner Panel. User publik hanya membaca URL gambar.

## 9. Data asli

Mave Vault tidak membuat prompt/review/member/rating palsu.

Jika database kosong, UI menampilkan empty state. Data baru muncul setelah benar-benar dibuat melalui Auth, Owner Panel, atau interaksi user.

## 10. Fitur aktif

- Supabase Auth login/register/logout
- Password reset
- Session persistence
- Profile
- USER/VIP/OWNER
- RLS
- Storage
- Prompt CRUD
- Prompt image upload
- Search AI name
- AI filter
- Featured 3 slots
- Prompt detail modal
- Copy prompt
- TXT download
- WhatsApp purchase
- Real reviews 1–5
- Real review count/average
- Kritik & Saran
- Updates/Berita
- Owner member rank management
- Activity logs
- Owner settings
- Responsive portrait + landscape
- Vercel routing

## Security rules penting

1. `anon key` boleh di frontend.
2. `service role key` tidak boleh di frontend.
3. Rank Owner/VIP tidak berasal dari input register.
4. RLS tetap aktif.
5. Owner pertama dipromosikan melalui SQL.
6. Jangan menonaktifkan RLS di production.

// Eşzamanlılık testi (Adım 2): aynı anda gelen istekler para çoğaltmamalı, bakiyeyi negatife
// düşürmemeli, başlangıç SP'sini iki kez vermemeli.
//
// pgTAP testleri tek bağlantıda çalıştığı için yarış koşulunu sınayamaz. Bu betik aynı anda
// birden çok bağımsız istek gönderir (`supabase db query --linked`, her biri ayrı bağlantı ve
// transaction); istekler pg_sleep_until ile aynı ana kilitlenir.
//
// Veritabanı şifresi gerekir: CLI şifresiz çalışırken her çağrıda geçici bir giriş rolünün
// şifresini yeniler, paralel çağrılar birbirinin şifresini bozar. Şifre SUPABASE_DB_PASSWORD
// ortam değişkeninden ya da kökteki .env.local dosyasından (git'e girmez) okunur, hiçbir
// çıktıda gösterilmez.
//
// Gerçek (commit edilen) veri yazar: kendine ait bir test okulu ve kullanıcılar açar, sonunda
// siler. Silme için ledger'ın "yalnızca eklenir" tetikleyicisi tek bir transaction içinde
// kapatılıp açılır (başka işlemler o sırada ledger'a erişemez). YALNIZCA geliştirme
// projesinde çalıştırın.
//
// Kullanım (proje kökünde, Docker gerekmez): npm run db:test:concurrency

import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

if (!process.env.SUPABASE_DB_PASSWORD && existsSync(".env.local")) {
  const line = readFileSync(".env.local", "utf8").split(/\r?\n/).find((l) => l.startsWith("SUPABASE_DB_PASSWORD="));
  if (line) process.env.SUPABASE_DB_PASSWORD = line.slice("SUPABASE_DB_PASSWORD=".length).trim().replace(/^["']|["']$/g, "");
}
const secret = process.env.SUPABASE_DB_PASSWORD;
if (!secret) {
  console.error("SUPABASE_DB_PASSWORD bulunamadı. Proje kökünde .env.local dosyasına şu satırı ekleyin:");
  console.error("SUPABASE_DB_PASSWORD=veritabani-sifreniz");
  process.exit(2);
}
const redact = (s) => s.split(secret).join("***");

const PER_REQUEST_TIMEOUT_MS = 90_000;
const tmp = mkdtempSync(join(tmpdir(), "kampusbet-esz-"));
let fileNo = 0;

// SQL'i buluttaki veritabanında çalıştırır. { ok, rows, code, message } döner.
function runSql(sql) {
  const file = join(tmp, `q${fileNo++}.sql`);
  writeFileSync(file, sql);
  return new Promise((resolve) => {
    const child = spawn(`npx supabase db query --linked -f "${file}"`, { shell: true, env: process.env });
    let out = "";
    const timer = setTimeout(() => {
      out += `\nERROR:  TIMEO: ${PER_REQUEST_TIMEOUT_MS / 1000} sn içinde yanıt gelmedi`;
      child.kill();
    }, PER_REQUEST_TIMEOUT_MS);
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (out += d));
    child.on("close", (exitCode) => {
      clearTimeout(timer);
      out = redact(out);
      if (exitCode === 0) {
        const json = out.slice(out.indexOf("{"), out.lastIndexOf("}") + 1);
        try {
          resolve({ ok: true, rows: JSON.parse(json).rows ?? [] });
        } catch {
          resolve({ ok: false, code: null, message: `Çıktı okunamadı: ${out}` });
        }
        return;
      }
      const m = out.match(/ERROR:\s+([0-9A-Z]{5}):\s*([^\\"\n]*)/);
      resolve({ ok: false, code: m?.[1] ?? null, message: m?.[2] ?? out.trim() });
    });
  });
}

async function mustRun(sql) {
  const r = await runSql(sql);
  if (!r.ok) throw new Error(`SQL başarısız (${r.code}): ${r.message}`);
  return r.rows;
}

const run = randomUUID().slice(0, 8);
const school = randomUUID();
const users = { gunluk: randomUUID(), harcama: randomUUID(), kayit: randomUUID() };
const ids = Object.values(users);
const idList = ids.map((id) => `'${id}'`).join(", ");

const asUser = (uid) => `
  set local role authenticated;
  set local request.jwt.claims to '{"sub":"${uid}","role":"authenticated"}';`;

// Tüm istekler bu ana kadar bekler, sonra aynı anda çalışır.
function synced(at, body) {
  return `begin;
select pg_sleep_until('${at}'::timestamptz);
${body}
commit;`;
}

const results = [];
function check(name, pass, detail) {
  results.push({ name, pass, detail });
  console.log(`${pass ? "ok    " : "HATA  "} ${name}${detail ? `  (${detail})` : ""}`);
}

// makeSql(at) son select'inde `(now() < at) as on_time` döndürmeli: istek bekleme anından önce
// ulaştıysa (gerçekten eşzamanlı başladıysa) true olur.
async function parallel(n, makeSql) {
  const at = new Date(Date.now() + 20_000).toISOString();
  return Promise.all(Array.from({ length: n }, () => runSql(synced(at, makeSql(`'${at}'::timestamptz`)))));
}

const onTime = (res) => `zamanında başlayan: ${res.filter((r) => r.ok && r.rows[0]?.on_time === true).length}/${res.filter((r) => r.ok).length}`;

// Beklenmeyen hataları (ilk üç farklı mesaj) gösterir.
function showUnexpected(res, expectedCodes = []) {
  const msgs = [...new Set(res.filter((r) => !r.ok && !expectedCodes.includes(r.code)).map((r) => `${r.code ?? "?"}: ${r.message}`.slice(0, 300)))];
  for (const m of msgs.slice(0, 3)) console.log(`        beklenmeyen hata -> ${m}`);
}

async function setup() {
  await mustRun(`begin;
insert into public.clusters (id, name, type) values ('${school}', 'Eşzamanlılık Test Okulu ${run}', 'school');
insert into auth.users (id, email, aud, role) values
  ('${users.gunluk}', 'esz-${run}-gunluk@test.local', 'authenticated', 'authenticated'),
  ('${users.harcama}', 'esz-${run}-harcama@test.local', 'authenticated', 'authenticated'),
  ('${users.kayit}', 'esz-${run}-kayit@test.local', 'authenticated', 'authenticated');
commit;`);
  for (const uid of [users.gunluk, users.harcama]) {
    await mustRun(`begin; ${asUser(uid)}
select id from public.create_profile('Test', 'Kişi', '${school}');
commit;`);
  }
}

async function cleanup() {
  await mustRun(`begin;
alter table public.ledger_entries disable trigger ledger_entries_append_only;
delete from public.ledger_entries where user_id in (${idList});
alter table public.ledger_entries enable trigger ledger_entries_append_only;
delete from public.login_streaks where user_id in (${idList});
delete from public.balances where user_id in (${idList});
delete from public.user_clusters where user_id in (${idList});
delete from public.profile_private where user_id in (${idList});
delete from public.profiles where id in (${idList});
delete from auth.users where id in (${idList});
delete from public.clusters where id = '${school}';
commit;`);
}

async function main() {
  console.log(`Eşzamanlılık testi ${run} başlıyor (her senaryo ~25 sn)...`);
  await setup();

  // 1) Aynı kullanıcı aynı anda 10 kez günlük ödül ister: yalnızca biri ödül almalı.
  {
    const res = await parallel(10, (at) => `${asUser(users.gunluk)}
select (now() < ${at}) as on_time, claimed from public.claim_daily_login();`);
    const errors = res.filter((r) => !r.ok);
    const claimed = res.filter((r) => r.ok && r.rows[0]?.claimed === true).length;
    const [{ n }] = await mustRun(
      `select count(*)::int as n from public.ledger_entries where user_id = '${users.gunluk}' and reason = 'daily_login'`,
    );
    check("10 eşzamanlı günlük ödül isteğinden yalnızca biri ödül alır", errors.length === 0 && claimed === 1 && n === 1,
      `hata: ${errors.length}, ödül alan: ${claimed}, ledger satırı: ${n}, ${onTime(res)}`);
    showUnexpected(res);
  }

  // 2) 1000 SP'si olan kullanıcıdan aynı anda 10 kez 300 SP düşülür: yalnızca 3'ü geçmeli.
  {
    const res = await parallel(10, (at) => `
select (now() < ${at}) as on_time,
       private.post_ledger('${users.harcama}', 'SP', -300, 'admin_adjust', null, null,
                           '${users.gunluk}', 'eşzamanlılık testi') as balance;`);
    const passed = res.filter((r) => r.ok).length;
    const insufficient = res.filter((r) => !r.ok && r.code === "KB001").length;
    const [{ sp }] = await mustRun(
      `select sp_balance::int as sp from public.balances where user_id = '${users.harcama}'`,
    );
    check("10 eşzamanlı 300 SP düşümünden yalnızca 3'ü geçer, bakiye 100 kalır",
      passed === 3 && insufficient === 7 && sp === 100,
      `geçen: ${passed}, yetersiz bakiye: ${insufficient}, bakiye: ${sp}, ${onTime(res)}`);
    showUnexpected(res, ["KB001"]);
  }

  // 3) Aynı kullanıcı aynı anda 10 kez profil oluşturur: tek profil, tek başlangıç SP'si.
  {
    const res = await parallel(10, (at) => `${asUser(users.kayit)}
select (now() < ${at}) as on_time, id from public.create_profile('Test', 'Kişi', '${school}');`);
    const passed = res.filter((r) => r.ok).length;
    const dup = res.filter((r) => !r.ok && r.code === "23505").length;
    const [{ bonus, sp }] = await mustRun(`select
      (select count(*)::int from public.ledger_entries where user_id = '${users.kayit}' and reason = 'signup_bonus') as bonus,
      (select sp_balance::int from public.balances where user_id = '${users.kayit}') as sp`);
    check("10 eşzamanlı profil oluşturmadan yalnızca biri geçer, başlangıç SP'si bir kez verilir",
      passed === 1 && dup === 9 && bonus === 1 && sp === 1000,
      `geçen: ${passed}, çakışma: ${dup}, başlangıç kaydı: ${bonus}, bakiye: ${sp}`);
    showUnexpected(res, ["23505"]);
  }

  // 4) Sonuçta önbellek bakiyesi ledger'la tutarlı, balance_after zinciri kopuk değil.
  {
    const [{ mismatch, broken }] = await mustRun(`select
      (select count(*)::int from private.balance_mismatches() where user_id in (${idList})) as mismatch,
      (select count(*)::int from (
         select balance_after, sum(amount) over (partition by user_id, currency order by id) as running
         from public.ledger_entries where user_id in (${idList})
       ) t where balance_after <> running) as broken`);
    check("bakiye ledger toplamına eşit ve balance_after zinciri tutarlı", mismatch === 0 && broken === 0,
      `uyuşmayan bakiye: ${mismatch}, kopuk satır: ${broken}`);
  }
}

let failed = false;
try {
  await main();
  failed = results.some((r) => !r.pass);
} catch (e) {
  failed = true;
  console.error(`Test yarıda kaldı: ${e.message}`);
} finally {
  try {
    await cleanup();
    console.log("Test verisi silindi.");
  } catch (e) {
    failed = true;
    console.error(`Temizlik başarısız, elle silinmeli (okul ${school}): ${e.message}`);
  }
  rmSync(tmp, { recursive: true, force: true });
}

console.log(failed ? "SONUÇ: BAŞARISIZ" : `SONUÇ: ${results.length}/${results.length} geçti`);
process.exit(failed ? 1 : 0);

// Eşzamanlılık testlerinin ortak kodu.
//
// pgTAP testleri tek bağlantıda çalıştığı için yarış koşulunu sınayamaz. Bu testler aynı anda
// birden çok bağımsız istek gönderir (`supabase db query --linked`, her biri ayrı bağlantı ve
// transaction); istekler pg_sleep_until ile aynı ana kilitlenir.
//
// Veritabanı şifresi gerekir: CLI şifresiz çalışırken her çağrıda geçici bir giriş rolünün
// şifresini yeniler, paralel çağrılar birbirinin şifresini bozar. Şifre SUPABASE_DB_PASSWORD
// ortam değişkeninden ya da kökteki .env.local dosyasından (git'e girmez) okunur, hiçbir
// çıktıda gösterilmez.
//
// Testler gerçek (commit edilen) veri yazar: kendilerine ait bir test okulu ve kullanıcılar
// açar, sonunda siler. Silme için ledger'ın "yalnızca eklenir" tetikleyicisi tek bir
// transaction içinde kapatılıp açılır (başka işlemler o sırada ledger'a erişemez).
// YALNIZCA geliştirme projesinde çalıştırın.

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
export function runSql(sql) {
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

export async function mustRun(sql) {
  const r = await runSql(sql);
  if (!r.ok) throw new Error(`SQL başarısız (${r.code}): ${r.message}`);
  return r.rows;
}

export const asUser = (uid) => `
  set local role authenticated;
  set local request.jwt.claims to '{"sub":"${uid}","role":"authenticated"}';`;

// n isteği aynı ana kilitleyip paralel gönderir. makeSql(at) son select'inde
// `(now() < at) as on_time` döndürmeli: istek bekleme anından önce ulaştıysa true olur.
export async function parallel(n, makeSql) {
  const at = new Date(Date.now() + 20_000).toISOString();
  return Promise.all(
    Array.from({ length: n }, (_, i) =>
      runSql(`begin;
select pg_sleep_until('${at}'::timestamptz);
${makeSql(`'${at}'::timestamptz`, i)}
commit;`),
    ),
  );
}

export const onTime = (res) =>
  `zamanında başlayan: ${res.filter((r) => r.ok && r.rows[0]?.on_time === true).length}/${res.filter((r) => r.ok).length}`;

// Beklenmeyen hataları (ilk üç farklı mesaj) gösterir.
export function showUnexpected(res, expectedCodes = []) {
  const msgs = [
    ...new Set(
      res.filter((r) => !r.ok && !expectedCodes.includes(r.code)).map((r) => `${r.code ?? "?"}: ${r.message}`.slice(0, 300)),
    ),
  ];
  for (const m of msgs.slice(0, 3)) console.log(`        beklenmeyen hata -> ${m}`);
}

const results = [];
export function check(name, pass, detail) {
  results.push({ name, pass, detail });
  console.log(`${pass ? "ok    " : "HATA  "} ${name}${detail ? `  (${detail})` : ""}`);
}

// Test dünyası: kendine ait bir okul ve verilen adlarla kullanıcılar.
export function createWorld(names) {
  const run = randomUUID().slice(0, 8);
  const users = Object.fromEntries(names.map((n) => [n, randomUUID()]));
  const ids = Object.values(users);
  return { run, school: randomUUID(), users, ids, idList: ids.map((id) => `'${id}'`).join(", ") };
}

// Okulu ve kullanıcıları açar. withProfile: profili oluşturulacak adlar (1000 SP ile başlar),
// verified: okul maili doğrulanmış sayılacak adlar.
export async function setupWorld(w, { withProfile = [], verified = [] } = {}) {
  const profileCalls = withProfile
    .map(
      (n) => `  perform set_config('request.jwt.claims', '{"sub":"${w.users[n]}","role":"authenticated"}', true);
  perform public.create_profile('Test', '${n}', '${w.school}');`,
    )
    .join("\n");
  const verifiedList = verified.map((n) => `'${w.users[n]}'`).join(", ") || "null";
  await mustRun(`begin;
insert into public.clusters (id, name, type) values ('${w.school}', 'Eşzamanlılık Test Okulu ${w.run}', 'school');
insert into auth.users (id, email, aud, role)
  select id, 'esz-${w.run}-' || id || '@test.local', 'authenticated', 'authenticated'
  from unnest(array[${w.idList}]::uuid[]) as id;
do $$ begin
${profileCalls || "  null;"}
end $$;
update public.profile_private
  set student_email = user_id || '@ogr.esz.test', student_email_verified_at = now()
  where user_id in (${verifiedList});
commit;`);
}

export async function cleanupWorld(w) {
  await mustRun(`begin;
create temp table esz_bets on commit drop as
  select id from public.bets where cluster_id = '${w.school}' or creator_id in (${w.idList});
alter table public.xp_events disable trigger xp_events_append_only;
delete from public.xp_events where user_id in (${w.idList});
alter table public.xp_events enable trigger xp_events_append_only;
delete from public.leaderboard_snapshots where school_id = '${w.school}' or user_id in (${w.idList});
delete from private.leaderboard_runs where school_id = '${w.school}';
alter table public.ledger_entries disable trigger ledger_entries_append_only;
delete from public.ledger_entries where user_id in (${w.idList});
alter table public.ledger_entries enable trigger ledger_entries_append_only;
delete from public.bet_disputes where bet_id in (select id from esz_bets) or raised_by in (${w.idList});
delete from public.wagers where bet_id in (select id from esz_bets) or user_id in (${w.idList});
delete from public.bet_options where bet_id in (select id from esz_bets);
delete from public.bets where id in (select id from esz_bets);
alter table public.quest_claims disable trigger quest_claims_append_only;
delete from public.quest_claims where user_id in (${w.idList})
  or quest_id in (select id from public.quests where school_id = '${w.school}');
alter table public.quest_claims enable trigger quest_claims_append_only;
delete from public.quests where school_id = '${w.school}';
delete from public.user_inventory where user_id in (${w.idList})
  or item_id in (select id from public.market_items where school_id = '${w.school}');
delete from public.market_items where school_id = '${w.school}';
delete from public.login_streaks where user_id in (${w.idList});
delete from public.balances where user_id in (${w.idList});
delete from public.user_clusters where user_id in (${w.idList});
delete from public.profile_private where user_id in (${w.idList});
delete from public.profiles where id in (${w.idList});
delete from auth.users where id in (${w.idList});
delete from public.clusters where id = '${w.school}';
commit;`);
}

// Önbellek bakiyesi ledger'la tutarlı, balance_after zinciri kopuk değil.
export async function checkLedgerIntegrity(w) {
  const [{ mismatch, broken }] = await mustRun(`select
    (select count(*)::int from private.balance_mismatches() where user_id in (${w.idList})) as mismatch,
    (select count(*)::int from (
       select balance_after, sum(amount) over (partition by user_id, currency order by id) as running
       from public.ledger_entries where user_id in (${w.idList})
     ) t where balance_after <> running) as broken`);
  check("bakiye ledger toplamına eşit ve balance_after zinciri tutarlı", mismatch === 0 && broken === 0,
    `uyuşmayan bakiye: ${mismatch}, kopuk satır: ${broken}`);
  const [{ xp_mismatch }] = await mustRun(`select count(*)::int as xp_mismatch from public.profiles p
    where p.id in (${w.idList})
      and p.xp <> coalesce((select sum(e.amount) from public.xp_events e where e.user_id = p.id), 0)`);
  check("profildeki XP, XP olaylarının toplamına eşit", xp_mismatch === 0, `uyuşmayan profil: ${xp_mismatch}`);
}

// Testi çalıştırır, ne olursa olsun test verisini siler ve çıkış kodunu ayarlar.
export async function runSuite(title, w, main) {
  let failed = false;
  console.log(`${title} (${w.run}) başlıyor; her senaryo ~25 sn...`);
  try {
    await main();
    failed = results.some((r) => !r.pass);
  } catch (e) {
    failed = true;
    console.error(`Test yarıda kaldı: ${e.message}`);
  } finally {
    try {
      await cleanupWorld(w);
      console.log("Test verisi silindi.");
    } catch (e) {
      failed = true;
      console.error(`Temizlik başarısız, elle silinmeli (okul ${w.school}): ${e.message}`);
    }
    rmSync(tmp, { recursive: true, force: true });
  }
  console.log(failed ? `${title}: BAŞARISIZ` : `${title}: ${results.length}/${results.length} geçti`);
  process.exit(failed ? 1 : 0);
}

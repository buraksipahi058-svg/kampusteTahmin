// Eşzamanlılık testi (Adım 2): aynı anda gelen istekler para çoğaltmamalı, bakiyeyi negatife
// düşürmemeli, başlangıç SP'sini iki kez vermemeli. Ayrıntılar: lib.mjs.
//
// Kullanım (proje kökünde, Docker gerekmez): npm run db:test:concurrency

import {
  asUser, check, checkLedgerIntegrity, createWorld, mustRun, onTime, parallel, runSuite, setupWorld, showUnexpected,
} from "./lib.mjs";

const w = createWorld(["gunluk", "harcama", "kayit"]);
const { users } = w;

await runSuite("Para eşzamanlılık testi", w, async () => {
  await setupWorld(w, { withProfile: ["gunluk", "harcama"] });

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
select (now() < ${at}) as on_time, id from public.create_profile('Test', 'Kişi', '${w.school}');`);
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

  await checkLedgerIntegrity(w);
});

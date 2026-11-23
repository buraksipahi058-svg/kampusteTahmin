// Eşzamanlılık testi (Adım 2, 9): aynı anda gelen istekler para çoğaltmamalı, bakiyeyi negatife
// düşürmemeli, başlangıç SP'sini, görev ödülünü ya da market ürününü iki kez vermemeli. Ayrıntılar: lib.mjs.
//
// Kullanım (proje kökünde, Docker gerekmez): npm run db:test:concurrency

import { randomUUID } from "node:crypto";
import {
  asUser, check, checkLedgerIntegrity, createWorld, mustRun, onTime, parallel, runSuite, setupWorld, showUnexpected,
} from "./lib.mjs";

const w = createWorld(["gunluk", "harcama", "kayit", "gorev", "market"]);
const { users } = w;

await runSuite("Para eşzamanlılık testi", w, async () => {
  await setupWorld(w, { withProfile: ["gunluk", "harcama", "gorev", "market"], verified: ["gorev"] });

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

  // 4) Tamamlanmış görevin ödülü aynı anda 10 kez istenir: ödül bir kez verilir.
  {
    const quest = randomUUID();
    await mustRun(`do $$
declare b uuid;
begin
  b := private.create_bet('${users.gorev}', '${w.school}', 'sp_social', 'school', 'Eşzamanlılık görevi bahsi', null,
                          array['A', 'B'], now() + interval '1 hour', '${users.gorev}');
  perform private.stake_wager(b, (select id from public.bet_options where bet_id = b and position = 1), '${users.gorev}', 10);
end $$;
insert into public.quests (id, school_id, title, period, action, target, reward_currency, reward_amount)
values ('${quest}', '${w.school}', 'Eşzamanlılık görevi', 'daily', 'wager', 1, 'SP', 50);`);
    const res = await parallel(10, (at) => `${asUser(users.gorev)}
select (now() < ${at}) as on_time, balance from public.claim_quest_reward('${quest}');`);
    const passed = res.filter((r) => r.ok).length;
    const already = res.filter((r) => !r.ok && r.code === "KB020").length;
    const [{ n, sp }] = await mustRun(`select
      (select count(*)::int from public.ledger_entries where user_id = '${users.gorev}' and reason = 'quest_reward') as n,
      (select sp_balance::int from public.balances where user_id = '${users.gorev}') as sp`);
    check("aynı görev ödülü için 10 eşzamanlı istekten yalnızca biri geçer",
      passed === 1 && already === 9 && n === 1 && sp === 1040,
      `geçen: ${passed}, zaten alınmış: ${already}, ledger ödül kaydı: ${n}, bakiye: ${sp}, ${onTime(res)}`);
    showUnexpected(res, ["KB020"]);
  }

  // 4b) Aynı kişi XP veren 5 farklı görevin ödülünü aynı anda ister: hepsi geçer (kilitlenme yok), XP bir kez yazılır.
  // (QA'da bulundu: XP profil satırını FOR UPDATE ile kilitleyince yabancı anahtar kilitleriyle çakışıp 40P01 veriyordu.)
  {
    const quests = Array.from({ length: 5 }, () => randomUUID());
    await mustRun(`insert into public.quests (id, school_id, title, period, action, target, reward_currency, reward_amount, reward_xp)
select q, '${w.school}', 'XP görevi ' || n, 'daily', 'wager', 1, 'SP', 10, 20
from unnest(array['${quests.join("','")}']::uuid[]) with ordinality as t(q, n);`);
    const [{ xp: xpBefore }] = await mustRun(`select xp from public.profiles where id = '${users.gorev}'`);
    const res = await parallel(5, (at, i) => `${asUser(users.gorev)}
select (now() < ${at}) as on_time, balance from public.claim_quest_reward('${quests[i]}');`);
    const passed = res.filter((r) => r.ok).length;
    const [{ xp, events }] = await mustRun(`select
      (select xp from public.profiles where id = '${users.gorev}') as xp,
      (select count(*)::int from public.xp_events where user_id = '${users.gorev}' and reason = 'quest') as events`);
    check("aynı kişinin XP'li 5 farklı görev ödülü aynı anda: hepsi geçer, kilitlenme yok",
      passed === 5 && xp - xpBefore === 100 && events === 5,
      `geçen: ${passed}, XP artışı: ${xp - xpBefore}, XP olayı: ${events}, ${onTime(res)}`);
    showUnexpected(res);
  }

  // 4c) Kazanılmış başarımın ("Kampüslü": okul maili doğrulandı) ödülü aynı anda 10 kez istenir: bir kez verilir,
  // XP de bir kez yazılır (Adım 16).
  {
    const res = await parallel(10, (at) => `${asUser(users.gorev)}
select (now() < ${at}) as on_time, balance from public.claim_achievement('kampuslu');`);
    const passed = res.filter((r) => r.ok).length;
    const already = res.filter((r) => !r.ok && r.code === "KB028").length;
    const [{ n, events }] = await mustRun(`select
      (select count(*)::int from public.ledger_entries where user_id = '${users.gorev}' and reason = 'achievement_reward') as n,
      (select count(*)::int from public.xp_events where user_id = '${users.gorev}' and reason = 'achievement') as events`);
    check("aynı başarımın 10 eşzamanlı ödül isteğinden yalnızca biri geçer, SP ve XP bir kez yazılır",
      passed === 1 && already === 9 && n === 1 && events === 1,
      `geçen: ${passed}, zaten alındı: ${already}, ledger kaydı: ${n}, XP olayı: ${events}, ${onTime(res)}`);
    showUnexpected(res, ["KB028"]);
  }

  // 5) Aynı ürün aynı anda 10 kez satın alınır: bir kez alınır, para bir kez düşer.
  {
    const item = randomUUID();
    await mustRun(`insert into public.market_items (id, school_id, name, category, icon, price, currency)
values ('${item}', '${w.school}', 'Eşzamanlılık rozeti', 'badge', '⭐', 300, 'SP');`);
    const res = await parallel(10, (at) => `${asUser(users.market)}
select (now() < ${at}) as on_time, public.purchase_market_item('${item}') as balance;`);
    const passed = res.filter((r) => r.ok).length;
    const owned = res.filter((r) => !r.ok && r.code === "KB022").length;
    const [{ inv, n, sp }] = await mustRun(`select
      (select count(*)::int from public.user_inventory where user_id = '${users.market}') as inv,
      (select count(*)::int from public.ledger_entries where user_id = '${users.market}' and reason = 'market_purchase') as n,
      (select sp_balance::int from public.balances where user_id = '${users.market}') as sp`);
    check("aynı ürün için 10 eşzamanlı satın almadan yalnızca biri geçer, para bir kez düşer",
      passed === 1 && owned === 9 && inv === 1 && n === 1 && sp === 700,
      `geçen: ${passed}, zaten sende: ${owned}, envanter: ${inv}, ledger kaydı: ${n}, bakiye: ${sp}, ${onTime(res)}`);
    showUnexpected(res, ["KB022"]);
  }

  await checkLedgerIntegrity(w);
});

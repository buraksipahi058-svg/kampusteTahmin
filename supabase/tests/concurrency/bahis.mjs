// Eşzamanlılık testi (Adım 3): aynı bahse aynı anda gelen yatırımlar havuzu bozmamalı, kişi
// bir bahse iki kez yatıramamalı, sonuçlandırma yarışında hiçbir yatırım ödemesiz kalmamalı,
// bahis iki kez sonuçlandırılamamalı. Ayrıntılar: lib.mjs.
//
// Kullanım (proje kökünde, Docker gerekmez): npm run db:test:concurrency

import {
  asUser, check, checkLedgerIntegrity, createWorld, mustRun, onTime, parallel, runSuite, setupWorld, showUnexpected,
} from "./lib.mjs";

const bettors = Array.from({ length: 10 }, (_, i) => `b${i}`);
const w = createWorld(["acan", "hakem", ...bettors]);
const { users } = w;
const everyone = ["acan", "hakem", ...bettors];

const createBet = (title) => `private.create_bet('${users.acan}', '${w.school}', 'sp_social', 'school',
  '${title}', null, array['Evet', 'Hayır'], now() + interval '30 minutes', '${users.hakem}')`;
const option = (betId, position) =>
  `(select id from public.bet_options where bet_id = '${betId}' and position = ${position})`;

// Bahsin havuzu, seçenek toplamları ve yatırımlar birbirini tutuyor mu; sonuçlandıysa
// her yatırımın ödemesi yazılmış ve dağıtılan toplam havuza eşit mi.
async function betState(betId) {
  const [s] = await mustRun(`select
    b.status::text as status,
    b.pool_total::int as pool,
    (select coalesce(sum(pool_amount), 0)::int from public.bet_options where bet_id = b.id) as option_sum,
    (select coalesce(sum(amount), 0)::int from public.wagers where bet_id = b.id) as wager_sum,
    (select count(*)::int from public.wagers where bet_id = b.id) as wagers,
    (select count(*)::int from public.wagers where bet_id = b.id and payout is null) as unpaid,
    (select coalesce(sum(payout), 0)::int from public.wagers where bet_id = b.id) as paid
  from public.bets b where b.id = '${betId}'`);
  return s;
}

await runSuite("Bahis eşzamanlılık testi", w, async () => {
  await setupWorld(w, { withProfile: everyone, verified: everyone });
  const [bets] = await mustRun(`select
    ${createBet("Eşzamanlı yatırım")} as a,
    ${createBet("Çift yatırım")} as b,
    ${createBet("Yatırım ve sonuç yarışı")} as c,
    ${createBet("Çift sonuçlandırma")} as d`);

  // 1) 10 kişi aynı anda aynı bahse yatırır: hepsi geçmeli, havuz kaybolmamalı.
  {
    const res = await parallel(10, (at, i) => `${asUser(users[`b${i}`])}
select (now() < ${at}) as on_time, id from public.place_wager('${bets.a}', ${option(bets.a, i < 5 ? 1 : 2)}, ${i < 5 ? 100 : 50});`);
    const s = await betState(bets.a);
    check("10 kişi aynı anda yatırır, hepsi havuza eksiksiz eklenir",
      res.every((r) => r.ok) && s.wagers === 10 && s.pool === 750 && s.option_sum === 750 && s.wager_sum === 750,
      `geçen: ${res.filter((r) => r.ok).length}, havuz: ${s.pool}, seçenek toplamı: ${s.option_sum}, yatırım toplamı: ${s.wager_sum}, ${onTime(res)}`);
    showUnexpected(res);
  }

  // 2) Aynı kişi aynı bahse aynı anda 10 kez yatırır: yalnızca biri geçmeli, bir kez ödemeli.
  {
    const res = await parallel(10, (at) => `${asUser(users.b0)}
select (now() < ${at}) as on_time, id from public.place_wager('${bets.b}', ${option(bets.b, 1)}, 10);`);
    const passed = res.filter((r) => r.ok).length;
    const rejected = res.filter((r) => !r.ok && ["KB004", "23505"].includes(r.code)).length;
    const [{ stakes }] = await mustRun(`select count(*)::int as stakes from public.ledger_entries l
      join public.wagers wg on wg.id = l.ref_id where l.reason = 'bet_stake' and wg.bet_id = '${bets.b}'`);
    const s = await betState(bets.b);
    check("aynı kişinin 10 eşzamanlı yatırımından yalnızca biri geçer, para bir kez düşer",
      passed === 1 && rejected === 9 && stakes === 1 && s.pool === 10,
      `geçen: ${passed}, reddedilen: ${rejected}, ledger yatırma kaydı: ${stakes}, havuz: ${s.pool}, ${onTime(res)}`);
    showUnexpected(res, ["KB004", "23505"]);
  }

  // 3) 9 yatırım ve sonuçlandırma aynı anda: yatırımlar ya sonuçtan önce girer ya reddedilir;
  //    giren her yatırımın ödemesi yazılır, dağıtılan toplam havuza eşit olur.
  {
    const res = await parallel(10, (at, i) =>
      i === 0
        ? `select (now() < ${at}) as on_time, 'sonuc' as kind;
           select private.lock_bet('${bets.c}');
           select private.settle_bet('${bets.c}', ${option(bets.c, 1)}, '${users.hakem}');
           select (now() < ${at}) as on_time, 'sonuc' as kind;`
        : `${asUser(users[`b${i}`])}
           select (now() < ${at}) as on_time, 'yatirim' as kind
           from public.place_wager('${bets.c}', ${option(bets.c, i % 2 ? 1 : 2)}, 20);`,
    );
    const settle = res[0];
    const wagersOk = res.slice(1).filter((r) => r.ok).length;
    const wagersClosed = res.slice(1).filter((r) => !r.ok && r.code === "KB003").length;
    const s = await betState(bets.c);
    check("yatırım ve sonuçlandırma yarışında ödemesiz yatırım kalmaz, dağıtılan toplam havuza eşit",
      settle.ok && wagersOk + wagersClosed === 9 && s.status === "settled" && s.wagers === wagersOk &&
        s.unpaid === 0 && s.paid === s.pool && s.option_sum === s.pool,
      `sonuçlandırma: ${settle.ok ? "geçti" : settle.code}, sonuçtan önce giren: ${wagersOk}, kapalıya düşen: ${wagersClosed}, havuz: ${s.pool}, dağıtılan: ${s.paid}, ödemesiz: ${s.unpaid}`);
    showUnexpected(res, ["KB003"]);
  }

  // 4) Kilitli bahis aynı anda 5 kez sonuçlandırılır: yalnızca biri geçmeli, ödeme bir kez yapılmalı.
  {
    await mustRun(`begin;
do $$ begin
  perform set_config('request.jwt.claims', '{"sub":"${users.b0}","role":"authenticated"}', true);
  perform public.place_wager('${bets.d}', ${option(bets.d, 1)}, 100);
  perform set_config('request.jwt.claims', '{"sub":"${users.b1}","role":"authenticated"}', true);
  perform public.place_wager('${bets.d}', ${option(bets.d, 2)}, 100);
  perform private.lock_bet('${bets.d}');
end $$;
commit;`);
    const res = await parallel(5, (at) => `
select (now() < ${at}) as on_time;
select private.settle_bet('${bets.d}', ${option(bets.d, 1)}, '${users.hakem}');
select (now() < ${at}) as on_time;`);
    const passed = res.filter((r) => r.ok).length;
    const already = res.filter((r) => !r.ok && r.code === "KB006").length;
    const [{ payouts, b0 }] = await mustRun(`select
      (select count(*)::int from public.ledger_entries l join public.wagers wg on wg.id = l.ref_id
        where l.reason in ('bet_payout', 'bet_refund') and wg.bet_id = '${bets.d}') as payouts,
      (select payout::int from public.wagers where bet_id = '${bets.d}' and user_id = '${users.b0}') as b0`);
    check("aynı anda 5 sonuçlandırmadan yalnızca biri geçer, ödeme bir kez yapılır",
      passed === 1 && already === 4 && payouts === 1 && b0 === 200,
      `geçen: ${passed}, zaten sonuçlanmış: ${already}, ödeme kaydı: ${payouts}, kazananın ödemesi: ${b0}`);
    showUnexpected(res, ["KB006"]);
  }

  await checkLedgerIntegrity(w);
});

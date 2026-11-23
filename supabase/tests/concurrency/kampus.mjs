// Eşzamanlılık testi (Adım 17a): aynı QR'ı aynı anda okutan kişi ödülü bir kez almalı; kontenjanlı görevde
// aynı anda gelen gönderilerden yalnızca kontenjan kadarı geçmeli. Ayrıntılar: lib.mjs.
//
// Kullanım (proje kökünde, Docker gerekmez): npm run db:test:concurrency

import { randomUUID } from "node:crypto";
import {
  asUser, check, checkLedgerIntegrity, createWorld, mustRun, onTime, parallel, runSuite, setupWorld, showUnexpected,
} from "./lib.mjs";

const students = Array.from({ length: 10 }, (_, i) => `o${i}`);
const w = createWorld(["yetkili", ...students]);
const { users } = w;

// Görevi doğrudan ekler (yönetim fonksiyonu pgTAP'te sınanıyor); kodu postgres olarak hesaplar.
async function createTask(quota) {
  const id = randomUUID();
  await mustRun(`insert into public.campus_tasks (id, school_id, title, verification, period, reward_amount, reward_xp,
  quota, created_by) values ('${id}', '${w.school}', 'Eşzamanlılık kampüs görevi', 'qr', 'once', 25, 10,
  ${quota ?? "null"}, '${users.yetkili}');
insert into private.campus_task_secrets (task_id) values ('${id}');`);
  const [{ code }] = await mustRun(`select private.campus_qr_code('${id}', now()) as code`);
  return { id, code };
}

await runSuite("Kampüs görevi eşzamanlılık testi", w, async () => {
  await setupWorld(w, { withProfile: ["yetkili", ...students], verified: students });

  // 1) Aynı kişi aynı QR'ı aynı anda 10 kez okutur: ödül bir kez.
  {
    const task = await createTask(null);
    const res = await parallel(10, (at) => `${asUser(users.o0)}
select (now() < ${at}) as on_time, balance from public.submit_campus_task_qr('${task.id}', '${task.code}');`);
    const passed = res.filter((r) => r.ok).length;
    const already = res.filter((r) => !r.ok && r.code === "KB030").length;
    const [{ n, subs }] = await mustRun(`select
      (select count(*)::int from public.ledger_entries where user_id = '${users.o0}' and reason = 'campus_task_reward') as n,
      (select count(*)::int from public.campus_task_submissions where task_id = '${task.id}') as subs`);
    check("aynı QR'ın 10 eşzamanlı okutmasından yalnızca biri ödül alır",
      passed === 1 && already === 9 && n === 1 && subs === 1,
      `geçen: ${passed}, zaten yapıldı: ${already}, ledger kaydı: ${n}, gönderi: ${subs}, ${onTime(res)}`);
    showUnexpected(res, ["KB030"]);
  }

  // 2) Kontenjanı 3 olan göreve 10 kişi aynı anda gönderir: yalnızca 3'ü geçer.
  {
    const task = await createTask(3);
    const res = await parallel(10, (at, i) => `${asUser(users[students[i]])}
select (now() < ${at}) as on_time, balance from public.submit_campus_task_qr('${task.id}', '${task.code}');`);
    const passed = res.filter((r) => r.ok).length;
    const full = res.filter((r) => !r.ok && r.code === "KB031").length;
    const [{ approved }] = await mustRun(`select count(*)::int as approved from public.campus_task_submissions
      where task_id = '${task.id}' and status = 'approved'`);
    check("kontenjanı 3 olan göreve 10 eşzamanlı gönderiden yalnızca 3'ü geçer",
      passed === 3 && full === 7 && approved === 3,
      `geçen: ${passed}, kontenjan doldu: ${full}, onaylı gönderi: ${approved}, ${onTime(res)}`);
    showUnexpected(res, ["KB031"]);
  }

  await checkLedgerIntegrity(w);
});

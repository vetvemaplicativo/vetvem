// Verificação em PRODUÇÃO com token anônimo (o mesmo que o portal usa).
//   FIREBASE_API_KEY=<chave pública do app web> node functions/test/verify_public_exposure.js --phase 1|2|3
//
// --phase 1: espelho existe, é legível e NÃO contém campo privado (users ainda
//            vaza — só informa).
// --phase 2: regra provisória (bloqueio do login anônimo/telefone): users/{uid} e a
//            query DEVEM falhar com 403 para o token anônimo.
// --phase 3: além do acima, users/{uid} e a query de profissionais DEVEM falhar
//            com 403 para o token anônimo. Sai com código 1 se algo falhar.
// Nunca imprime VALORES de campos, só nomes de chaves e status HTTP.
const PROJECT = process.env.FIREBASE_PROJECT_ID || "vetvem-18bf4";
const API_KEY = process.env.FIREBASE_API_KEY;
const phase = process.argv.includes("--phase") ? process.argv[process.argv.indexOf("--phase") + 1] : "3";
if (!API_KEY) { console.error("Defina FIREBASE_API_KEY"); process.exit(2); }

const PRIVATE = ["phone", "email", "address", "pixKeys", "termos_aceitos", "termos_aceitos_em",
  "termos_versao", "fcmToken", "platform", "feeOverride", "pixChangedAt", "createdAt",
  "accountStatus", "blocked", "role"];
const DB = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
let failed = false;
const check = (ok, msg) => { console.log(`${ok ? "OK  " : "FAIL"} ${msg}`); if (!ok) failed = true; };

(async () => {
  const su = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ returnSecureToken: true }),
  }).then((r) => r.json());
  if (!su.idToken) { console.error("Falha no login anônimo:", su.error?.message); process.exit(2); }
  const H = { Authorization: `Bearer ${su.idToken}`, "Content-Type": "application/json" };
  console.log(`Token anônimo obtido (fase ${phase}).`);

  // 1) Vitrine legível e sem campos privados
  const pubRes = await fetch(`${DB}/professionals_public?pageSize=50`, { headers: H });
  check(pubRes.status === 200, `professionals_public legível (HTTP ${pubRes.status})`);
  const pubDocs = (await pubRes.json()).documents || [];
  check(pubDocs.length > 0, `vitrine tem profissionais (${pubDocs.length})`);
  const vazados = new Set();
  for (const d of pubDocs) for (const k of Object.keys(d.fields || {})) if (PRIVATE.includes(k)) vazados.add(k);
  check(vazados.size === 0, `vitrine sem campo privado${vazados.size ? ` — VAZOU: ${[...vazados].join(", ")}` : ""}`);

  // 2) users: tentativa direta e por query (o que um raspador faria)
  const uid = pubDocs[0]?.name.split("/").pop();
  if (uid) {
    const r = await fetch(`${DB}/users/${uid}`, { headers: H });
    const leaked = r.status === 200 ? Object.keys((await r.json()).fields || {}).filter((k) => PRIVATE.includes(k)) : [];
    if (phase === "2" || phase === "3") check(r.status === 403, `users/{uid} de profissional NEGADO (HTTP ${r.status})`);
    else console.log(`INFO users/{uid} HTTP ${r.status}${leaked.length ? ` — expõe: ${leaked.join(", ")}` : ""}`);
  }
  const q = await fetch(`${DB}:runQuery`, {
    method: "POST", headers: H,
    body: JSON.stringify({ structuredQuery: { from: [{ collectionId: "users" }], limit: 5,
      where: { fieldFilter: { field: { fieldPath: "role" }, op: "EQUAL", value: { stringValue: "professional" } } } } }),
  });
  const qBody = await q.json();
  const returned = Array.isArray(qBody) ? qBody.filter((x) => x.document).length : 0;
  if (phase === "2" || phase === "3") check(q.status === 403 && returned === 0, `query users role==professional NEGADA (HTTP ${q.status}, ${returned} docs)`);
  else console.log(`INFO query users role==professional HTTP ${q.status}, ${returned} docs`);

  // 3) Limpeza: remove o usuário anônimo criado pelo teste
  await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ idToken: su.idToken }),
  });
  process.exit(failed ? 1 : 0);
})();

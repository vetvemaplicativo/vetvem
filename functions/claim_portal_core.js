// Transição portal -> app: move o tutorId dos pedidos concluídos do uid do celular (portal)
// para o uid do app, e reaponta os anexos do prontuário (a regra do Storage libera o arquivo
// para quem está em metadata.tutorId).
const admin = require("firebase-admin");
const lib = require("./claim_portal_lib");

const realStorage = {
  async listFiles(prefix) {
    const [files] = await admin.storage().bucket().getFiles({ prefix });
    return files;
  },
  async setTutor(file, uid) {
    await file.setMetadata({ metadata: { tutorId: uid } });
  },
};

// deps: { storage, nowMs }
async function claim({ appUid, phoneUid, nowMs = Date.now(), storage = realStorage }) {
  const db = admin.firestore();
  const snap = await db.collection("appointments")
    .where("tutorId", "==", phoneUid).where("status", "==", "completed").get();
  const docs = snap.docs.slice(0, lib.MAX_CLAIM);

  const moved = [];
  for (const doc of docs) {
    const ok = await db.runTransaction(async (tx) => {
      const cur = (await tx.get(doc.ref)).data();
      if (!lib.isClaimable(cur, phoneUid)) return false; // mudou desde a consulta
      tx.update(doc.ref, { tutorId: appUid, claimedFromPortalUid: phoneUid, claimedFromPortalAt: nowMs });
      return cur;
    });
    if (ok) moved.push({ id: doc.id, vetId: ok.vetId || "" });
  }

  let attachments = 0;
  for (const m of moved) {
    if (!m.vetId) continue;
    try {
      const files = await storage.listFiles(`prontuarios/${m.vetId}/${m.id}/`);
      for (const f of files) { await storage.setTutor(f, appUid); attachments++; }
    } catch (e) {
      console.warn("claim_portal anexos:", m.id, e.message);
    }
  }
  return { moved: moved.length, attachments, appointmentIds: moved.map((m) => m.id) };
}

module.exports = { claim };

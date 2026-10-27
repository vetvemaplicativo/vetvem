// Profissional com cadastro REJEITADO que reenvia um documento volta sozinho para a
// fila de análise (accountStatus: pending), sem depender de trocar o CRMV. As regras
// do Firestore não deixam o app mudar accountStatus de "rejected", então é feito aqui.
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

exports.reopenOnResubmit = onDocumentWritten(
  { document: "users/{uid}/documents/{docType}", region: "southamerica-east1" },
  async (event) => {
    const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
    if (!after || after.status !== "submitted") return;
    const uid = event.params.uid;
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const user = (await userRef.get()).data();
    if (!user || user.role !== "professional" || user.accountStatus !== "rejected") return;
    await userRef.update({
      accountStatus: "pending",
      rejectionReason: admin.firestore.FieldValue.delete(),
    });
    await db.collection("notifications").doc(uid).collection("pending").add({
      title: "Documentos recebidos",
      body: "Recebemos seus documentos e seu cadastro voltou para análise. Avisaremos quando houver uma decisão.",
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

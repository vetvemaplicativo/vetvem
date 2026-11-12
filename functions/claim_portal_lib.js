// Transição portal -> app: quem agendou pelo site (login por celular/SMS) e depois baixou o app
// (login por e-mail/Google/Apple) pode TRAZER suas consultas CONCLUÍDAS para a conta do app.
// A posse do número é provada por um ID token de login por telefone recente, enviado junto
// com o ID token da conta do app. Regras puras aqui; Firestore/Storage em claim_portal_core.js.

const MAX_CLAIM = 100;                     // pedidos por chamada
const PHONE_TOKEN_MAX_AGE_MS = 10 * 60 * 1000; // o SMS tem que ter sido confirmado há no máximo 10 min
const APP_PROVIDERS = ["password", "google.com", "apple.com"];

// Valida o par de tokens já decodificados. Retorna { ok:true, appUid, phoneUid } ou { ok:false, error }.
function validateTokens(appTok, phoneTok, nowMs) {
  if (!appTok || !phoneTok) return { ok: false, error: "Tokens ausentes." };
  const appProvider = appTok.firebase && appTok.firebase.sign_in_provider;
  if (!APP_PROVIDERS.includes(appProvider)) {
    return { ok: false, error: "Entre no app com e-mail, Google ou Apple para trazer suas consultas." };
  }
  const phoneProvider = phoneTok.firebase && phoneTok.firebase.sign_in_provider;
  if (phoneProvider !== "phone") return { ok: false, error: "Confirme o seu celular por SMS." };
  if (appTok.uid === phoneTok.uid) return { ok: false, error: "A conta do celular e a do app são a mesma." };
  const authMs = Number(phoneTok.auth_time || 0) * 1000;
  if (!authMs || nowMs - authMs > PHONE_TOKEN_MAX_AGE_MS) {
    return { ok: false, error: "A confirmação por SMS expirou. Confirme o celular de novo." };
  }
  return { ok: true, appUid: appTok.uid, phoneUid: phoneTok.uid };
}

// Só pedido CONCLUÍDO que ainda pertence ao uid do celular.
const isClaimable = (a, phoneUid) => !!a && a.status === "completed" && a.tutorId === phoneUid;

module.exports = { MAX_CLAIM, PHONE_TOKEN_MAX_AGE_MS, APP_PROVIDERS, validateTokens, isClaimable };

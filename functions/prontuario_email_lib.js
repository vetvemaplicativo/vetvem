// E-mail do prontuário para quem agendou pelo PORTAL (sem app instalado) — regras puras.
// O profissional marca "enviar ao cliente" no Pro (appointments.sentToClient = true); o servidor
// manda o prontuário por e-mail uma vez e, depois, só os COMPLEMENTOS novos.
// Quem agendou pelo app já vê tudo dentro do app e não recebe este e-mail.
const { petLabel } = require("./appointment_amount");

const MAX_ATTACH_BYTES = 20 * 1024 * 1024; // total anexado ao e-mail (o Resend aceita até ~40 MB)
const APP_LINK = "https://vetvem.com.br/baixar";

const esc = (t) => String(t == null ? "" : t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const nl2br = (t) => esc(t).replace(/\r?\n/g, "<br>");

const hasEmail = (a) => typeof a.email === "string" && a.email.includes("@");
const complementsOf = (a) => (Array.isArray(a.complementos) ? a.complementos : []);

// O que enviar agora para este pedido? "full" (1º envio) | "complement" | null
function decide(a) {
  if (!a || a.bookingOrigin !== "portal_web" || !hasEmail(a) || a.sentToClient !== true) return null;
  if (!a.prontuarioEmailSentAt) return a.prontuario ? "full" : null;
  return complementsOf(a).length > Number(a.prontuarioEmailComplements || 0) ? "complement" : null;
}

const safeName = (n) => String(n || "anexo").replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 80) || "anexo";

// Anexos (do prontuário e dos complementos) que entram neste envio.
function anexosFor(a, mode) {
  if (mode === "complement") {
    return complementsOf(a).slice(Number(a.prontuarioEmailComplements || 0)).flatMap((c) => (Array.isArray(c.anexos) ? c.anexos : []));
  }
  const p = a.prontuario || {};
  return [...(Array.isArray(p.anexos) ? p.anexos : []), ...complementsOf(a).flatMap((c) => (Array.isArray(c.anexos) ? c.anexos : []))];
}

function section(title, inner) {
  return `<h3 style="margin:22px 0 6px;font-size:15px;color:#ff6b2b">${esc(title)}</h3>${inner}`;
}
const list = (items) => `<ul style="margin:4px 0 0;padding-left:20px;line-height:1.6">${items.map((i) => `<li>${i}</li>`).join("")}</ul>`;

function complementBlocks(items) {
  return items.map((c) => {
    const when = c.addedAt ? new Date(c.addedAt).toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" }) : "";
    return `<div style="background:#f6f1ff;border-radius:10px;padding:12px;margin:8px 0">` +
      (when ? `<div style="font-size:12px;color:#646471">${esc(when)}</div>` : "") +
      (c.texto ? `<div style="line-height:1.5">${nl2br(c.texto)}</div>` : "") + `</div>`;
  }).join("");
}

// { subject, html }. `extra`: { links: [{name,url}], failed: [nome] } sobre os anexos.
function buildEmail(a, mode, extra = {}) {
  const pet = petLabel(a, "seu pet");
  const first = String(a.tutorName || "").trim().split(/\s+/)[0];
  const vet = a.vetName || "o profissional";
  const crmv = a.vetCrmv ? ` (CRMV ${esc(a.vetCrmv)})` : "";
  const p = a.prontuario || {};
  const isComplement = mode === "complement";
  const news = isComplement ? complementsOf(a).slice(Number(a.prontuarioEmailComplements || 0)) : complementsOf(a);

  let body = "";
  if (!isComplement) {
    if (p.peso) body += section("Peso", `<p style="margin:4px 0">${esc(p.peso)} kg</p>`);
    const vacinas = (Array.isArray(p.vacinas) ? p.vacinas : []).filter((v) => v && v.nome);
    if (vacinas.length) {
      body += section("Vacinas", list(vacinas.map((v) => `${esc(v.nome)}${v.proximaDose ? ` — próxima dose: ${esc(v.proximaDose)}` : ""}`)));
    }
    const meds = (Array.isArray(p.medicamentos) ? p.medicamentos : []).filter((m) => m && m.nome);
    if (meds.length) {
      body += section("Medicamentos", list(meds.map((m) => {
        const det = [m.dosagem, m.frequencia, m.duracao].filter(Boolean).map(esc).join(" · ");
        return `<strong>${esc(m.nome)}</strong>${det ? ` — ${det}` : ""}`;
      })));
    }
    if (p.observacoes) body += section("Observações do profissional", `<p style="margin:4px 0;line-height:1.5">${nl2br(p.observacoes)}</p>`);
  }
  if (news.length) body += section(isComplement ? "Complemento ao prontuário" : "Complementos", complementBlocks(news));

  const anexosCount = anexosFor(a, mode).length;
  if (anexosCount) {
    let t = `<p style="margin:4px 0">Os arquivos estão <strong>anexados a este e-mail</strong>.</p>`;
    if (extra.links && extra.links.length) {
      t += `<p style="margin:4px 0">Arquivos grandes (links válidos por 7 dias):</p>` +
        list(extra.links.map((l) => `<a href="${esc(l.url)}">${esc(l.name || "arquivo")}</a>`));
    }
    if (extra.failed && extra.failed.length) {
      t += `<p style="margin:4px 0;color:#b45309">Não conseguimos anexar: ${extra.failed.map(esc).join(", ")}. Fale com a gente em suporte@vetvem.com.br que enviamos.</p>`;
    }
    body += section("Anexos", t);
  }

  const intro = isComplement
    ? `<p>O profissional <strong>${esc(vet)}</strong>${crmv} acrescentou uma informação ao prontuário de <strong>${esc(pet)}</strong>.</p>`
    : `<p>O prontuário do atendimento de <strong>${esc(pet)}</strong> com <strong>${esc(vet)}</strong>${crmv}, em ${esc(a.date || "")}${a.time ? ` às ${esc(a.time)}` : ""}, já está disponível. Guarde este e-mail: ele é o registro oficial da consulta.</p>`;

  const html = `<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;color:#1a1a2e">
<p>Olá${first ? ", " + esc(first) : ""}!</p>${intro}${body}
<hr style="border:none;border-top:1px solid #e5e7eb;margin:26px 0">
<p style="font-size:13px;line-height:1.5">Quer ter o histórico de ${esc(pet)} sempre à mão, com agendamento em tempo real? <a href="${APP_LINK}">Baixe o app VetVem</a>.</p>
<p style="font-size:11px;color:#646471">Registro vinculado à consulta na plataforma VetVem. Este e-mail contém dados de saúde do seu animal — não encaminhe a terceiros. Dúvidas: suporte@vetvem.com.br</p></div>`;

  return {
    subject: isComplement ? `Complemento no prontuário de ${pet} 🐾` : `Prontuário de ${pet} — ${vet} 🐾`,
    html,
  };
}

module.exports = { MAX_ATTACH_BYTES, decide, anexosFor, buildEmail, safeName, esc };

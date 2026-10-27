// Lógica pura do blog automático (sem rede, sem Firebase): calendário editorial
// aleatório, datas comemorativas, regras de risco e validação do artigo.
// Usada por blog_auto.js; fica separada para poder ser testada com `node`.

const crypto = require("crypto");

const TZ = "America/Sao_Paulo";
// Janela em que um post pode ir ao ar (minutos desde 00:00, horário de Brasília).
const JANELA = { ini: 7 * 60 + 30, fim: 21 * 60 };
const JANELA_DATA = { ini: 7 * 60 + 30, fim: 11 * 60 + 30 }; // datas comemorativas: de manhã

const CATEGORIAS = [
  "saude-animal", "dicas-veterinarias", "bem-estar-pet", "alimentacao-pet",
  "curiosidades", "ciencia-e-pesquisa", "datas-comemorativas", "novidades-vetvem",
];

// Tipos que SEMPRE ficam como rascunho para o Ronald aprovar (saúde, vacina,
// alimentação e descobertas científicas). Os demais vão direto ao ar, a menos
// que a IA marque "sensível" ou o texto tenha cara de dose/receita.
const KINDS_SEMPRE_RASCUNHO = new Set(["guia", "ciencia"]);

// Datas fixas (MM-DD). A IA confirma a origem por busca antes de escrever.
const DATAS_FIXAS = {
  "10-04": { nome: "Dia Mundial dos Animais", nota: "Também lembra São Francisco de Assis, protetor dos animais." },
  "09-09": { nome: "Dia do Médico-Veterinário (Brasil)", nota: "Confirme a origem da data e a importância da profissão." },
  "08-08": { nome: "Dia Internacional do Gato", nota: "Confirme a origem da data." },
  "08-26": { nome: "Dia Internacional do Cachorro", nota: "Confirme a origem da data." },
  "09-28": { nome: "Dia Mundial da Raiva", nota: "Foco em prevenção e vacinação antirrábica no Brasil. Confirme os dados oficiais." },
  "07-06": { nome: "Dia Mundial das Zoonoses", nota: "Explique zoonoses comuns com pets e prevenção. Confirme a origem da data." },
};

function dataComemorativa(dateKey) {
  const [y, m, d] = dateKey.split("-").map(Number);
  const mmdd = `${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
  if (DATAS_FIXAS[mmdd]) return DATAS_FIXAS[mmdd];
  // Dia Mundial do Veterinário: último sábado de abril.
  if (m === 4) {
    let last = new Date(Date.UTC(y, 3, 30));
    while (last.getUTCDay() !== 6) last = new Date(last.getTime() - 86400000);
    if (last.getUTCDate() === d) {
      return { nome: "Dia Mundial do Veterinário", nota: "Último sábado de abril. Confirme a origem da data." };
    }
  }
  return null;
}

/* ---------- aleatoriedade determinística (mesmo resultado em todo tick) ---------- */

function rngFrom(seed) {
  let a = crypto.createHash("sha256").update(String(seed)).digest().readUInt32LE(0);
  return function () { // mulberry32
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffle(arr, rng) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function dateKeySP(d = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(d); // YYYY-MM-DD
}

function minutosSP(d = new Date()) {
  const p = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    .formatToParts(d);
  return Number(p.find((x) => x.type === "hour").value) * 60 + Number(p.find((x) => x.type === "minute").value);
}

// 0 = segunda ... 6 = domingo
function diaDaSemana(dateKey) {
  const [y, m, d] = dateKey.split("-").map(Number);
  return (new Date(Date.UTC(y, m - 1, d)).getUTCDay() + 6) % 7;
}

function inicioDaSemana(dateKey) {
  const [y, m, d] = dateKey.split("-").map(Number);
  const t = new Date(Date.UTC(y, m - 1, d) - diaDaSemana(dateKey) * 86400000);
  return t.toISOString().slice(0, 10);
}

/**
 * Plano do dia: 3 posts por semana em dias sorteados (nunca consecutivos), com
 * o tipo de cada um também sorteado e o horário sorteado entre 07:30 e 21:00.
 * Datas comemorativas viram post extra de manhã (ou trocam o tipo do dia).
 * `salt` mantém o sorteio imprevisível para quem olha de fora.
 */
function planoDoDia(dateKey, salt = "") {
  const semana = inicioDaSemana(dateKey);
  const rng = rngFrom(`blog|${salt}|${semana}|dias`);

  let dias = null;
  for (let i = 0; i < 300 && !dias; i++) {
    const c = shuffle([0, 1, 2, 3, 4, 5, 6], rng).slice(0, 3).sort((a, b) => a - b);
    if (c[1] - c[0] >= 2 && c[2] - c[1] >= 2) dias = c;
  }
  if (!dias) dias = [0, 2, 4];
  const tipos = shuffle(["guia", "ciencia", "curiosidade"], rng);

  const hoje = diaDaSemana(dateKey);
  const idx = dias.indexOf(hoje);
  const data = dataComemorativa(dateKey);

  let kind = idx >= 0 ? tipos[idx] : null;
  let janela = JANELA;
  if (data) { kind = "data"; janela = JANELA_DATA; }
  if (!kind) return { post: false, dias, tipos };

  const r = rngFrom(`blog|${salt}|${dateKey}|hora`);
  const minuto = janela.ini + Math.floor(r() * (janela.fim - janela.ini + 1));
  return { post: true, kind, data, minuto, dias, tipos };
}

/* ---------- risco / validação ---------- */

const RE_DOSE = [
  /\b\d+([.,]\d+)?\s?(mg|mcg|µg|ml|ui|g)\s?(\/|por)\s?(kg|dia|dose)\b/i,
  /\bdosagem\b/i,
  /\bdose\s(de|di[aá]ria|recomendada|ideal)\b/i,
  /\b\d+\s?(comprimidos?|gotas?)\s(a cada|por dia|de \d+)/i,
];

function pareceReceita(texto) {
  return RE_DOSE.some((re) => re.test(texto));
}

function semHtml(html) {
  return String(html || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}

function contarPalavras(html) {
  const t = semHtml(html);
  return t ? t.split(" ").length : 0;
}

/* ---------- medidas de SEO/legibilidade (estilo Yoast), só informativas ---------- */

const norm = (s) => String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
const STOP = new Set(["de", "do", "da", "dos", "das", "o", "a", "os", "as", "e", "em", "no", "na", "nos", "nas", "para", "por", "um", "uma", "que", "com"]);

// Palavras/expressões de transição comuns em português (aproximação da lista do Yoast).
const TRANSICAO = [
  "alem disso", "alem do mais", "por isso", "por esse motivo", "no entanto", "porem", "mas", "entretanto", "contudo", "todavia",
  "ou seja", "por exemplo", "assim", "dessa forma", "desse modo", "portanto", "logo", "por outro lado", "em contrapartida",
  "tambem", "ainda", "enquanto", "porque", "pois", "quando", "embora", "apesar", "se ", "caso", "ate porque", "mesmo assim",
  "em seguida", "depois", "antes", "primeiro", "segundo", "por fim", "finalmente", "em resumo", "de fato", "na pratica",
  "com isso", "nesse caso", "alem", "sobretudo", "principalmente", "inclusive", "afinal", "dessa maneira", "como resultado",
];

function textoDeHtml(html) { return semHtml(html); }

function palavrasDaFrase(kw) { return norm(kw).split(/\s+/).filter((w) => w && !STOP.has(w)); }

function contemFrase(texto, kw) {
  const t = norm(texto);
  const palavras = palavrasDaFrase(kw);
  return palavras.length > 0 && palavras.every((w) => t.includes(w));
}

function analisarSEO(a) {
  const html = String(a.conteudo_html || "");
  const kw = a.palavra_chave || "";
  const primeiroP = (html.match(/<p[^>]*>([\s\S]*?)<\/p>/i) || [, ""])[1];
  const subtitulos = [...html.matchAll(/<h[23][^>]*>([\s\S]*?)<\/h[23]>/gi)].map((m) => textoDeHtml(m[1]));
  const frases = textoDeHtml(html).split(/(?<=[.!?])\s+/).filter((f) => f.length > 3);
  const comTransicao = frases.filter((f) => { const n = ` ${norm(f)} `; return TRANSICAO.some((t) => n.includes(` ${t.trim()} `) || n.includes(` ${t.trim()},`)); }).length;
  return {
    kwNoTitulo: contemFrase(a.titulo, kw),
    kwNaIntroducao: contemFrase(textoDeHtml(primeiroP), kw),
    kwEmSubtitulo: subtitulos.some((s) => contemFrase(s, kw)),
    kwNaMetaDescricao: contemFrase(a.meta_descricao, kw),
    pctTransicao: frases.length ? Math.round((100 * comTransicao) / frases.length) : 0,
    frases: frases.length,
  };
}

/** Retorna lista de problemas que IMPEDEM publicar (se vazia, o artigo é aceitável). */
// Mínimo de palavras por tipo: novidade científica tem menos fatos confirmáveis, então aceita texto
// mais enxuto (melhor curto e correto do que enchido com suposição).
const MIN_PALAVRAS = { ciencia: 450 };

function validarArtigo(a, kind) {
  const erros = [];
  const palavras = contarPalavras(a.conteudo_html);
  const minimo = MIN_PALAVRAS[kind] || 600;
  if (!a.titulo) erros.push("título ausente");
  else if (a.titulo.length > 75) erros.push(`título longo demais (${a.titulo.length} caracteres; máximo 70)`);
  if (!a.meta_descricao) erros.push("meta description ausente");
  else if (a.meta_descricao.length > 165) erros.push(`meta description longa demais (${a.meta_descricao.length} caracteres; máximo 160)`);
  if (!a.meta_titulo) erros.push("título SEO ausente");
  else if (a.meta_titulo.length > 70) erros.push(`título SEO longo demais (${a.meta_titulo.length} caracteres; máximo 60)`);
  if (palavras < minimo) erros.push(`texto curto (${palavras} palavras; mínimo ${minimo})`);
  if (palavras > 2200) erros.push(`texto longo demais (${palavras} palavras)`);
  if ((String(a.conteudo_html).match(/<h2/gi) || []).length < 3) erros.push("menos de 3 seções (h2)");
  if (/<h1/i.test(a.conteudo_html)) erros.push("contém h1");
  if (!CATEGORIAS.includes(a.categoria)) erros.push("categoria inválida");
  return erros;
}

/**
 * Decide status final do post. Retorna { status, motivo }.
 * 'publish' só quando o tipo permite E nada sinalizou risco.
 */
function decidirStatus({ kind, dataInfo, artigo, fontesValidas, textoCompleto }) {
  if (KINDS_SEMPRE_RASCUNHO.has(kind)) return { status: "draft", motivo: "assunto de saúde/ciência: revisão obrigatória" };
  if (dataInfo && /raiva|zoonose/i.test(dataInfo.nome)) return { status: "draft", motivo: "data ligada a doença: revisão obrigatória" };
  if (artigo.sensivel) return { status: "draft", motivo: `marcado como sensível pela IA: ${artigo.motivo_sensivel || "sem detalhe"}` };
  if (pareceReceita(textoCompleto)) return { status: "draft", motivo: "o texto menciona dose/medicação" };
  if (fontesValidas.length < 1) return { status: "draft", motivo: "sem fonte verificada" };
  return { status: "publish", motivo: "" };
}

module.exports = {
  TZ, JANELA, CATEGORIAS, KINDS_SEMPRE_RASCUNHO, DATAS_FIXAS,
  dataComemorativa, rngFrom, shuffle, dateKeySP, minutosSP, diaDaSemana, inicioDaSemana,
  planoDoDia, pareceReceita, semHtml, contarPalavras, validarArtigo, decidirStatus, analisarSEO,
};

import { words } from "./shared";

/** The picker's groups, in the order Apple's own picker uses (EmojiCategory). */
export type EmojiCategory = "people" | "nature" | "food" | "activity" | "travel" | "objects" | "symbols" | "flags";

export const categoryTitles: Record<EmojiCategory, string> = {
  people: "Carinhas e pessoas",
  nature: "Animais e natureza",
  food: "Comidas e bebidas",
  activity: "Atividades",
  travel: "Viagens e lugares",
  objects: "Objetos",
  symbols: "Símbolos",
  flags: "Bandeiras",
};

export type EmojiItem = {
  emoji: string;
  /** The system's Portuguese name, for the tooltip. */
  name: string;
  category: EmojiCategory;
  /** Folded words the search matches: the name's first, then the keywords. */
  terms: string[];
  /** How many of `terms` came from the name (they rank above keywords). */
  nameWords: number;
};

type Row = readonly [emoji: string, name: string, keywords?: string];

/** A small slice of the system's list: the emoji people reach for, with pt-BR keywords. */
const rows: Record<EmojiCategory, readonly Row[]> = {
  people: [
    ["😀", "Rosto risonho", "feliz sorriso alegre"],
    ["😃", "Rosto risonho com olhos grandes", "feliz sorriso"],
    ["😄", "Rosto risonho com olhos sorridentes", "feliz sorriso"],
    ["😁", "Rosto contente com olhos sorridentes", "feliz dentes"],
    ["😆", "Rosto risonho com olhos semicerrados", "rir risada"],
    ["🥹", "Rosto segurando as lágrimas", "emocionado grato"],
    ["😅", "Rosto risonho com gota de suor", "ufa nervoso"],
    ["😂", "Rosto chorando de rir", "rir lol engraçado"],
    ["🤣", "Rolando no chão de rir", "rir kkk engraçado"],
    ["🥲", "Rosto sorridente com lágrima", "grato aliviado"],
    ["☺️", "Rosto sorridente", "feliz fofo"],
    ["😊", "Rosto sorridente com olhos sorridentes", "feliz corado"],
    ["😇", "Rosto sorridente com auréola", "anjo inocente"],
    ["🙂", "Rosto levemente sorridente", "sorriso"],
    ["🙃", "Rosto de cabeça para baixo", "ironia bobo"],
    ["😉", "Rosto piscando", "piscadinha"],
    ["😌", "Rosto aliviado", "calma paz"],
    ["😍", "Rosto sorridente com olhos de coração", "amor apaixonado"],
    ["🥰", "Rosto sorridente com corações", "amor apaixonado carinho"],
    ["😘", "Rosto mandando um beijo", "beijo amor coração"],
    ["😋", "Rosto saboreando comida", "delícia gostoso"],
    ["😜", "Rosto piscando com língua", "brincadeira"],
    ["🤪", "Rosto bobo", "doido maluco"],
    ["🤓", "Rosto de nerd", "óculos inteligente"],
    ["😎", "Rosto sorridente com óculos escuros", "legal sol"],
    ["🤩", "Rosto deslumbrado", "estrela uau"],
    ["🥳", "Rosto festivo", "festa aniversário comemoração"],
    ["😏", "Rosto com sorriso maroto", "malicioso"],
    ["😔", "Rosto pensativo", "triste desanimado"],
    ["😢", "Rosto chorando", "triste lágrima"],
    ["😭", "Rosto chorando muito", "triste choro"],
    ["😤", "Rosto bufando", "orgulho irritado"],
    ["😡", "Rosto furioso", "raiva bravo"],
    ["🤯", "Cabeça explodindo", "chocado uau"],
    ["😳", "Rosto ruborizado", "vergonha"],
    ["🥵", "Rosto fervendo", "calor quente"],
    ["🥶", "Rosto congelado", "frio gelado"],
    ["😱", "Rosto gritando de medo", "susto pânico"],
    ["😰", "Rosto ansioso com gota de suor", "nervoso medo"],
    ["🤔", "Rosto pensativo com a mão no queixo", "pensando hmm dúvida"],
    ["🤗", "Rosto abraçando", "abraço carinho"],
    ["🫡", "Rosto fazendo continência", "sim senhor respeito"],
    ["🤫", "Rosto fazendo silêncio", "shh segredo"],
    ["🫠", "Rosto derretendo", "calor vergonha"],
    ["😴", "Rosto dormindo", "sono zzz cansado"],
    ["🙄", "Rosto revirando os olhos", "tédio"],
    ["😬", "Rosto fazendo careta", "nervoso"],
    ["🤠", "Rosto com chapéu de caubói", "cowboy"],
    ["😈", "Rosto sorridente com chifres", "diabo travesso"],
    ["💀", "Caveira", "morto morri"],
    ["👻", "Fantasma", "halloween boo"],
    ["🤖", "Robô", "máquina"],
    ["👋", "Mão acenando", "oi tchau olá"],
    ["👍", "Polegar para cima", "joinha ok curti"],
    ["👎", "Polegar para baixo", "não ruim"],
    ["👏", "Mãos aplaudindo", "palmas parabéns"],
    ["🙌", "Mãos para cima", "viva comemoração festa"],
    ["🫶", "Mãos formando coração", "amor carinho"],
    ["🙏", "Mãos juntas", "por favor obrigado oração"],
    ["🤝", "Aperto de mãos", "acordo negócio"],
    ["💪", "Bíceps flexionado", "força forte academia"],
    ["✌️", "Mão em V", "paz vitória"],
    ["🤞", "Dedos cruzados", "sorte torcida"],
    ["👀", "Olhos", "olhar vendo"],
  ],
  nature: [
    ["🐶", "Rosto de cachorro", "cão pet"],
    ["🐱", "Rosto de gato", "gatinho pet"],
    ["🦊", "Rosto de raposa", "animal"],
    ["🐻", "Rosto de urso", "animal"],
    ["🐼", "Rosto de panda", "urso"],
    ["🐨", "Coala", "animal"],
    ["🦁", "Rosto de leão", "animal rei"],
    ["🐸", "Rosto de sapo", "animal"],
    ["🐵", "Rosto de macaco", "animal"],
    ["🐧", "Pinguim", "animal frio"],
    ["🦋", "Borboleta", "inseto"],
    ["🐢", "Tartaruga", "animal devagar"],
    ["🐙", "Polvo", "mar"],
    ["🐬", "Golfinho", "mar"],
    ["🌸", "Flor de cerejeira", "flor primavera"],
    ["🌹", "Rosa", "flor amor"],
    ["🌻", "Girassol", "flor sol"],
    ["🌵", "Cacto", "deserto planta"],
    ["🌴", "Palmeira", "praia verão"],
    ["🍀", "Trevo de quatro folhas", "sorte"],
    ["🍁", "Folha de bordo", "outono"],
    ["☀️", "Sol", "calor dia"],
    ["🌙", "Lua crescente", "noite"],
    ["⭐", "Estrela", "brilho"],
    ["⚡", "Alta tensão", "raio energia"],
    ["🔥", "Fogo", "chama quente incêndio"],
    ["🌈", "Arco-íris", "chuva cores"],
    ["❄️", "Floco de neve", "frio inverno"],
    ["🌊", "Onda de água", "mar praia"],
    ["💧", "Gota", "água suor"],
  ],
  food: [
    ["🍎", "Maçã vermelha", "fruta"],
    ["🍌", "Banana", "fruta"],
    ["🍉", "Melancia", "fruta verão"],
    ["🍓", "Morango", "fruta"],
    ["🥑", "Abacate", "fruta"],
    ["🌶️", "Pimenta", "picante quente ardido"],
    ["🌽", "Espiga de milho", "milho junina"],
    ["🧀", "Fatia de queijo", "queijo"],
    ["🍔", "Hambúrguer", "lanche"],
    ["🍟", "Batata frita", "lanche"],
    ["🍕", "Pizza", "fatia"],
    ["🌮", "Taco", "mexicano"],
    ["🍣", "Sushi", "japonês peixe"],
    ["🍿", "Pipoca", "cinema filme"],
    ["🍩", "Rosquinha", "donut doce"],
    ["🎂", "Bolo de aniversário", "festa parabéns"],
    ["🍫", "Barra de chocolate", "doce"],
    ["🍦", "Sorvete de casquinha", "doce verão"],
    ["☕", "Bebida quente", "café chá"],
    ["🧉", "Mate", "chimarrão"],
    ["🍺", "Caneca de cerveja", "bar"],
    ["🍻", "Canecas de cerveja brindando", "brinde festa bar"],
    ["🥂", "Taças brindando", "brinde festa comemoração"],
    ["🍷", "Taça de vinho", "bebida"],
    ["🍾", "Garrafa com rolha estourando", "champanhe festa comemoração"],
  ],
  activity: [
    ["🎃", "Abóbora de halloween", "halloween"],
    ["🎄", "Árvore de natal", "natal"],
    ["🎆", "Fogos de artifício", "festa réveillon"],
    ["🎇", "Estrelinha", "fogos festa"],
    ["🧨", "Bombinha", "fogos explosão"],
    ["✨", "Brilhos", "mágica novo"],
    ["🎈", "Balão", "festa aniversário"],
    ["🎉", "Confete", "festa comemoração parabéns"],
    ["🎊", "Bola de confete", "festa comemoração"],
    ["🎁", "Presente embrulhado", "presente aniversário"],
    ["🪅", "Pinhata", "festa"],
    ["🪩", "Globo espelhado", "festa balada dança"],
    ["🏆", "Troféu", "campeão vitória"],
    ["🥇", "Medalha de primeiro lugar", "ouro campeão"],
    ["⚽", "Bola de futebol", "futebol gol"],
    ["🏀", "Bola de basquete", "basquete"],
    ["🎾", "Tênis", "bola raquete"],
    ["🏐", "Bola de vôlei", "vôlei"],
    ["🎮", "Videogame", "jogo controle"],
    ["🎲", "Dado", "jogo sorte"],
    ["🎯", "Alvo", "dardo meta"],
    ["🎸", "Guitarra", "música rock"],
  ],
  travel: [
    ["🚗", "Carro", "automóvel"],
    ["🚕", "Táxi", "carro"],
    ["🚌", "Ônibus", "transporte"],
    ["🚒", "Caminhão de bombeiro", "fogo incêndio"],
    ["🚲", "Bicicleta", "bike pedal"],
    ["✈️", "Avião", "viagem voo"],
    ["🚀", "Foguete", "espaço lançamento"],
    ["🏠", "Casa", "lar"],
    ["🏖️", "Praia com guarda-sol", "férias verão"],
    ["🌋", "Vulcão", "fogo erupção"],
    ["⛺", "Barraca", "acampamento"],
    ["🌍", "Globo mostrando Europa e África", "mundo terra"],
  ],
  objects: [
    ["⌚", "Relógio", "hora"],
    ["📱", "Celular", "telefone iphone"],
    ["💻", "Laptop", "computador mac"],
    ["⌨️", "Teclado", "computador"],
    ["📷", "Câmera", "foto"],
    ["🎧", "Fone de ouvido", "música"],
    ["💡", "Lâmpada", "ideia luz"],
    ["🕯️", "Vela", "luz chama"],
    ["🧯", "Extintor de incêndio", "fogo"],
    ["💰", "Saco de dinheiro", "grana"],
    ["📦", "Pacote", "caixa entrega"],
    ["📚", "Livros", "estudo leitura"],
    ["✏️", "Lápis", "escrever"],
    ["📌", "Tachinha", "fixar"],
    ["📎", "Clipe de papel", "anexo"],
    ["🔑", "Chave", "senha"],
    ["🔒", "Cadeado fechado", "seguro"],
  ],
  symbols: [
    ["❤️", "Coração vermelho", "amor"],
    ["🩷", "Coração rosa", "amor fofo"],
    ["🧡", "Coração laranja", "amor"],
    ["💛", "Coração amarelo", "amor amizade"],
    ["💚", "Coração verde", "amor"],
    ["💙", "Coração azul", "amor"],
    ["💜", "Coração roxo", "amor"],
    ["🖤", "Coração preto", "luto"],
    ["🤍", "Coração branco", "paz"],
    ["🤎", "Coração marrom", "amor"],
    ["💔", "Coração partido", "triste fim"],
    ["❤️‍🔥", "Coração em chamas", "fogo paixão"],
    ["💕", "Dois corações", "amor coração"],
    ["💖", "Coração brilhante", "amor coração"],
    ["💘", "Coração com flecha", "cupido amor"],
    ["💯", "Cem pontos", "perfeito"],
    ["✅", "Marca de seleção", "feito ok certo"],
    ["❌", "Xis", "errado não"],
    ["⚠️", "Aviso", "cuidado atenção"],
    ["❓", "Ponto de interrogação", "pergunta dúvida"],
    ["💬", "Balão de fala", "conversa mensagem"],
    ["💤", "Zzz", "sono dormir"],
  ],
  flags: [
    ["🏁", "Bandeira quadriculada", "corrida chegada"],
    ["🏳️‍🌈", "Bandeira do arco-íris", "orgulho"],
    ["🇧🇷", "Bandeira: Brasil", "brasil"],
    ["🇵🇹", "Bandeira: Portugal", "portugal"],
    ["🇦🇷", "Bandeira: Argentina", "argentina"],
    ["🇺🇸", "Bandeira: Estados Unidos", "eua"],
    ["🇯🇵", "Bandeira: Japão", "japão"],
  ],
};

function item(category: EmojiCategory, [emoji, name, keywords = ""]: Row): EmojiItem {
  const nameWords = words(name);
  const terms = [...nameWords];
  // One-letter keywords are articles; they'd only add noise (EmojiItem).
  for (const keyword of words(keywords)) if (keyword.length > 1 && !terms.includes(keyword)) terms.push(keyword);
  return { emoji, name, category, terms, nameWords: nameWords.length };
}

export const sections = (Object.keys(rows) as EmojiCategory[]).map((category) => ({
  category,
  items: rows[category].map((row) => item(category, row)),
}));

const all = sections.flatMap((section) => section.items);
const byEmoji = new Map(all.map((entry) => [entry.emoji, entry]));

export function emojiItem(emoji: string): EmojiItem | undefined {
  return byEmoji.get(emoji);
}

/** Lower is better; null when some typed word matches nothing (EmojiSearch.score). */
function score(tokens: string[], entry: EmojiItem): number | null {
  let total = 0;
  for (const token of tokens) {
    let best: number | null = null;
    for (const [position, term] of entry.terms.entries()) {
      if (!term.startsWith(token)) continue;
      const isName = position < entry.nameWords;
      // Exact words beat prefixes; name words beat keywords; the first name word wins.
      let value = isName ? position : 20 + Math.floor(Math.min(position - entry.nameWords, 40) / 4);
      if (term.length !== token.length) value += 10;
      best = best === null ? value : Math.min(best, value);
    }
    if (best === null) return null;
    total += best;
  }
  return total;
}

/** The matches, best first; ties keep the picker's order. Typing an emoji finds it. */
export function searchEmoji(query: string): EmojiItem[] {
  const trimmed = query.trim();
  if (!trimmed) return [];
  const tokens = words(trimmed);
  if (tokens.length === 0) return all.filter((entry) => entry.emoji === trimmed);
  return all
    .map((entry, index) => ({ entry, index, value: score(tokens, entry) }))
    .filter((match): match is { entry: EmojiItem; index: number; value: number } => match.value !== null)
    .sort((a, b) => a.value - b.value || a.index - b.index)
    .map(({ entry }) => entry);
}


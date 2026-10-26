import type { Lang } from "@/lib/lang";
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

/** The groups' titles as the English app shows them. */
const englishTitles: Record<EmojiCategory, string> = {
  people: "Smileys & People",
  nature: "Animals & Nature",
  food: "Food & Drink",
  activity: "Activities",
  travel: "Travel & Places",
  objects: "Objects",
  symbols: "Symbols",
  flags: "Flags",
};

export function categoryTitlesFor(lang: Lang): Record<EmojiCategory, string> {
  return lang === "en" ? englishTitles : categoryTitles;
}

export type EmojiItem = {
  emoji: string;
  /** The system's name in the page's language, for the tooltip. */
  name: string;
  category: EmojiCategory;
  /** Folded words the search matches: the name's first, then the keywords. */
  terms: string[];
  /** How many of `terms` came from the name (they rank above keywords). */
  nameWords: number;
};

type Row = readonly [emoji: string, name: string, keywords?: string];

/** A small slice of the system's list: the emoji people reach for, with pt-BR names and keywords. */
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

/**
 * The same emoji in English: macOS's own short names (CoreEmoji's AppleName, first
 * letter capitalized like the app) and English keywords in the spirit of the pt ones.
 */
const english: Record<string, readonly [name: string, keywords: string]> = {
  "😀": ["Grinning face", "happy smile cheerful"],
  "😃": ["Grinning face with big eyes", "happy smile"],
  "😄": ["Grinning face with smiling eyes", "happy smile"],
  "😁": ["Beaming face with smiling eyes", "happy teeth"],
  "😆": ["Grinning face with squinting eyes", "laugh laughing"],
  "🥹": ["Smiling face holding back tears", "touched grateful"],
  "😅": ["Grinning face with sweat", "phew nervous"],
  "😂": ["Face with tears of joy", "laugh lol funny"],
  "🤣": ["Rolling on the floor laughing face", "laugh lmao funny"],
  "🥲": ["Smiling face with tear", "grateful relieved"],
  "☺️": ["Smiling face", "happy cute"],
  "😊": ["Smiling face with smiling eyes", "happy blush"],
  "😇": ["Smiling face with halo", "angel innocent"],
  "🙂": ["Slightly smiling face", "smile"],
  "🙃": ["Upside down face", "irony silly"],
  "😉": ["Winking face", "wink"],
  "😌": ["Relieved face", "calm peace"],
  "😍": ["Smiling face with heart-eyes", "love crush"],
  "🥰": ["Smiling face with hearts", "love crush affection"],
  "😘": ["Face blowing a kiss", "kiss love heart"],
  "😋": ["Smiling face licking lips", "delicious yummy"],
  "😜": ["Winking face with stuck-out tongue", "kidding"],
  "🤪": ["Goofy face", "crazy wacky"],
  "🤓": ["Smiling face with glasses", "nerd glasses smart"],
  "😎": ["Smiling face with sunglasses", "cool sun"],
  "🤩": ["Face with starry eyes", "star wow"],
  "🥳": ["Party face", "party birthday celebration"],
  "😏": ["Smirking face", "smug"],
  "😔": ["Sad pensive face", "sad down"],
  "😢": ["Crying face", "sad tear"],
  "😭": ["Loudly crying face", "sad sobbing"],
  "😤": ["Face with steam from nose", "proud annoyed"],
  "😡": ["Red angry face", "anger mad"],
  "🤯": ["Exploding head", "shocked mind blown"],
  "😳": ["Face with wide open eyes", "embarrassed"],
  "🥵": ["Hot face", "heat hot"],
  "🥶": ["Cold face", "freezing icy"],
  "😱": ["Face screaming in fear", "scared panic"],
  "😰": ["Anxious face with sweat", "nervous fear"],
  "🤔": ["Thinking face", "thinking hmm doubt"],
  "🤗": ["Hugging face", "hug affection"],
  "🫡": ["Saluting face", "yes sir respect"],
  "🤫": ["Shushing face", "shh secret"],
  "🫠": ["Melting face", "heat embarrassed"],
  "😴": ["Sleeping face", "sleepy zzz tired"],
  "🙄": ["Face with rolling eyes", "bored"],
  "😬": ["Grimacing face", "nervous"],
  "🤠": ["Cowboy face", "cowboy"],
  "😈": ["Smiling face with horns", "devil mischievous"],
  "💀": ["Skull", "dead dying"],
  "👻": ["Ghost", "halloween boo"],
  "🤖": ["Robot face", "machine"],
  "👋": ["Waving hand", "hi bye hello"],
  "👍": ["Thumbs up", "ok like approve"],
  "👎": ["Thumbs down", "no bad"],
  "👏": ["Clapping hands", "applause congrats"],
  "🙌": ["Hands raised in celebration", "hooray celebration party"],
  "🫶": ["Heart hands", "love affection"],
  "🙏": ["Hands pressed together", "please thanks prayer"],
  "🤝": ["Handshake", "deal agreement"],
  "💪": ["Flexed bicep", "strength strong gym"],
  "✌️": ["Peace hand sign", "peace victory"],
  "🤞": ["Fingers crossed", "luck hope"],
  "👀": ["Eyes", "look watching"],
  "🐶": ["Dog face", "puppy pet"],
  "🐱": ["Cat face", "kitty pet"],
  "🦊": ["Fox face", "animal"],
  "🐻": ["Bear face", "animal"],
  "🐼": ["Panda face", "bear"],
  "🐨": ["Koala face", "animal"],
  "🦁": ["Lion face", "animal king"],
  "🐸": ["Frog face", "animal"],
  "🐵": ["Monkey face", "animal"],
  "🐧": ["Penguin", "animal cold"],
  "🦋": ["Butterfly", "insect"],
  "🐢": ["Turtle", "animal slow"],
  "🐙": ["Octopus", "sea"],
  "🐬": ["Dolphin", "sea"],
  "🌸": ["Cherry blossom", "flower spring"],
  "🌹": ["Rose", "flower love"],
  "🌻": ["Sunflower", "flower sun"],
  "🌵": ["Cactus", "desert plant"],
  "🌴": ["Palm tree", "beach summer"],
  "🍀": ["Four leaf clover", "luck"],
  "🍁": ["Maple leaf", "autumn fall"],
  "☀️": ["Sun", "heat day"],
  "🌙": ["Crescent moon", "night"],
  "⭐": ["Star", "shine"],
  "⚡": ["Lightning bolt", "electricity energy"],
  "🔥": ["Fire", "flame hot lit"],
  "🌈": ["Rainbow", "rain colors"],
  "❄️": ["Snowflake", "cold winter"],
  "🌊": ["Wave", "sea beach"],
  "💧": ["Droplet", "water sweat"],
  "🍎": ["Red apple", "fruit"],
  "🍌": ["Banana", "fruit"],
  "🍉": ["Watermelon", "fruit summer"],
  "🍓": ["Strawberry", "fruit"],
  "🥑": ["Avocado", "fruit"],
  "🌶️": ["Hot pepper", "spicy hot chili"],
  "🌽": ["Ear of corn", "corn maize"],
  "🧀": ["Cheese wedge", "cheese"],
  "🍔": ["Hamburger", "burger"],
  "🍟": ["French fries", "fries snack"],
  "🍕": ["Pizza", "slice"],
  "🌮": ["Taco", "mexican"],
  "🍣": ["Sushi", "japanese fish"],
  "🍿": ["Popcorn", "cinema movie"],
  "🍩": ["Doughnut", "donut sweet"],
  "🎂": ["Birthday cake", "party birthday"],
  "🍫": ["Chocolate bar", "sweet candy"],
  "🍦": ["Soft ice cream", "sweet summer"],
  "☕": ["Hot beverage", "coffee tea"],
  "🧉": ["Maté", "mate yerba"],
  "🍺": ["Beer mug", "beer bar"],
  "🍻": ["Clinking beer mugs", "cheers party bar"],
  "🥂": ["Clinking glasses", "cheers toast celebration"],
  "🍷": ["Wine glass", "drink"],
  "🍾": ["Bottle with popping cork", "champagne party celebration"],
  "🎃": ["Jack-o-lantern", "halloween pumpkin"],
  "🎄": ["Christmas tree", "christmas"],
  "🎆": ["Fireworks", "party new year"],
  "🎇": ["Firework sparkler", "fireworks celebration"],
  "🧨": ["Firecracker", "fireworks explosion"],
  "✨": ["Sparkles", "magic new"],
  "🎈": ["Balloon", "party birthday"],
  "🎉": ["Party popper", "party celebration congrats"],
  "🎊": ["Confetti ball", "party celebration"],
  "🎁": ["Present", "gift birthday"],
  "🪅": ["Piñata", "party"],
  "🪩": ["Mirror ball", "party disco dance"],
  "🏆": ["Trophy", "champion win"],
  "🥇": ["Gold medal", "gold champion"],
  "⚽": ["Soccer ball", "football goal"],
  "🏀": ["Basketball", "ball"],
  "🎾": ["Tennis ball", "ball racket"],
  "🏐": ["Volleyball", "ball"],
  "🎮": ["Video game controller", "game controller"],
  "🎲": ["Game die", "game luck"],
  "🎯": ["Bullseye", "dart target"],
  "🎸": ["Guitar", "music rock"],
  "🚗": ["Car", "automobile"],
  "🚕": ["Taxi", "car"],
  "🚌": ["Bus", "transport"],
  "🚒": ["Fire engine", "fire truck"],
  "🚲": ["Bicycle", "bike pedal"],
  "✈️": ["Airplane", "travel flight"],
  "🚀": ["Rocket", "space launch"],
  "🏠": ["House", "home"],
  "🏖️": ["Beach with umbrella", "vacation summer"],
  "🌋": ["Volcano", "fire eruption"],
  "⛺": ["Tent", "camping"],
  "🌍": ["Globe showing Europe and Africa", "world earth"],
  "⌚": ["Watch", "time"],
  "📱": ["Mobile phone", "phone iphone"],
  "💻": ["Laptop", "computer mac"],
  "⌨️": ["Keyboard", "computer"],
  "📷": ["Camera", "photo"],
  "🎧": ["Headphones", "music"],
  "💡": ["Light bulb", "idea light"],
  "🕯️": ["Candle", "light flame"],
  "🧯": ["Fire extinguisher", "fire"],
  "💰": ["Money bag", "cash"],
  "📦": ["Package", "box delivery"],
  "📚": ["Books", "study reading"],
  "✏️": ["Pencil", "write"],
  "📌": ["Pushpin", "pin"],
  "📎": ["Paperclip", "attachment"],
  "🔑": ["Key", "password"],
  "🔒": ["Closed lock", "secure"],
  "❤️": ["Red heart", "love"],
  "🩷": ["Pink heart", "love cute"],
  "🧡": ["Orange heart", "love"],
  "💛": ["Yellow heart", "love friendship"],
  "💚": ["Green heart", "love"],
  "💙": ["Blue heart", "love"],
  "💜": ["Purple heart", "love"],
  "🖤": ["Black heart", "mourning"],
  "🤍": ["White heart", "peace"],
  "🤎": ["Brown heart", "love"],
  "💔": ["Broken heart", "sad end"],
  "❤️‍🔥": ["Heart on fire", "fire passion"],
  "💕": ["Two hearts", "love heart"],
  "💖": ["Sparkling heart", "love heart"],
  "💘": ["Heart with arrow", "cupid love"],
  "💯": ["Hundred points symbol", "perfect"],
  "✅": ["Check mark symbol", "done ok right"],
  "❌": ["Cross mark", "wrong no"],
  "⚠️": ["Warning", "careful attention"],
  "❓": ["Red question mark", "question doubt"],
  "💬": ["Speech balloon", "chat message"],
  "💤": ["Sleeping sign", "sleep"],
  "🏁": ["Chequered flag", "race finish"],
  "🏳️‍🌈": ["Rainbow flag", "pride"],
  "🇧🇷": ["Flag of Brazil", "brazil"],
  "🇵🇹": ["Flag of Portugal", "portugal"],
  "🇦🇷": ["Flag of Argentina", "argentina"],
  "🇺🇸": ["Flag of the United States", "usa america"],
  "🇯🇵": ["Flag of Japan", "japan"],
};

function item(category: EmojiCategory, [emoji, name, keywords = ""]: Row): EmojiItem {
  const nameWords = words(name);
  const terms = [...nameWords];
  // One-letter keywords are articles; they'd only add noise (EmojiItem).
  for (const keyword of words(keywords)) if (keyword.length > 1 && !terms.includes(keyword)) terms.push(keyword);
  return { emoji, name, category, terms, nameWords: nameWords.length };
}

type Section = { category: EmojiCategory; items: EmojiItem[] };

function build(lang: Lang): { sections: Section[]; all: EmojiItem[]; byEmoji: Map<string, EmojiItem> } {
  const sections = (Object.keys(rows) as EmojiCategory[]).map((category) => ({
    category,
    items: rows[category].map((row) => {
      const translated = lang === "en" ? english[row[0]] : undefined;
      return item(category, translated ? [row[0], translated[0], translated[1]] : row);
    }),
  }));
  const all = sections.flatMap((section) => section.items);
  return { sections, all, byEmoji: new Map(all.map((entry) => [entry.emoji, entry])) };
}

const built: Record<Lang, ReturnType<typeof build>> = { pt: build("pt"), en: build("en") };

/** The Portuguese sections, as before the English page. */
export const sections = built.pt.sections;

export function sectionsFor(lang: Lang): Section[] {
  return built[lang].sections;
}

export function emojiItem(emoji: string, lang: Lang = "pt"): EmojiItem | undefined {
  return built[lang].byEmoji.get(emoji);
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
export function searchEmoji(query: string, lang: Lang = "pt"): EmojiItem[] {
  const all = built[lang].all;
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


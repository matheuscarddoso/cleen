import Image from "next/image";
import { DownloadButton, MoreLink, OutlineLink } from "@/components/Buttons";
import { Gallery } from "@/components/Gallery";
import { Navigation } from "@/components/Navigation";
import { ClaudeLive } from "@/components/ClaudeLive";
import { Everyday } from "@/components/Everyday";
import { LiveActivities } from "@/components/LiveActivities";
import { Keycaps } from "@/components/Pieces";
import { AILimits, CommandHotkeys, SmartAnswers, SnippetExpand } from "@/components/Reasons";
import { Replica } from "@/components/replica/Replica";
import type { TabId } from "@/components/replica/tabs";
import { Tile } from "@/components/Tile";
import { LangProvider } from "@/components/LangProvider";
import { LangSwitch } from "@/components/LangSwitch";
import { locale, pick, type Lang } from "@/lib/lang";
import { site } from "@/lib/site";

type L = ReturnType<typeof pick>;

const tools = (l: L): { tab: TabId; title: [string, string]; tone: "blue" | "dusk" | "teal" }[] => [
  { tab: "weather", title: l(["O tempo de agora", "e da semana inteira."], ["The weather now", "and for the whole week."]), tone: "blue" },
  { tab: "stocks", title: l(["B3 e Nasdaq,", "com o gráfico do dia."], ["NYSE and Nasdaq,", "with the day's chart."]), tone: "teal" },
  { tab: "timer", title: l(["Pomodoro ou timer,", "ao lado da câmera."], ["Pomodoro or timer,", "right by the camera."]), tone: "dusk" },
  { tab: "converter", title: l(["Unidades e moedas.", "Return cola o resultado."], ["Units and currencies.", "Return pastes the result."]), tone: "blue" },
  { tab: "emoji", title: l(["Emoji em português,", "colados onde você está."], ["Emoji by name,", "pasted right where you are."]), tone: "teal" },
  { tab: "icons", title: l(["Ícones do Lucide,", "em SVG ou JSX."], ["Lucide icons,", "as SVG or JSX."]), tone: "dusk" },
  { tab: "system", title: l(["CPU, memória e rede,", "sempre à vista."], ["CPU, memory, and network,", "always in view."]), tone: "blue" },
];

const included = (l: L): readonly (readonly [string, string])[] =>
  l(
    [
      ["Grátis", "Sem assinatura e sem conta."],
      ["Todas as ferramentas", "Quase trinta, e as que vierem."],
      ["Atualiza sozinho", "Confere a assinatura antes de trocar."],
      ["Sem telemetria", "Nada sai do seu Mac."],
      ["Código aberto", "Para quem quiser conferir."],
      ["Português e inglês", "Segue o idioma do seu Mac."],
    ],
    [
      ["Free", "No subscription and no account."],
      ["Every tool", "Almost thirty, plus any to come."],
      ["Updates itself", "Checks the signature before it swaps."],
      ["No telemetry", "Nothing leaves your Mac."],
      ["Open source", "For anyone who wants to check."],
      ["English and Portuguese", "Follows your Mac's language."],
    ],
  );

/** The rest of the reasons, each with its own small picture. */
const reasons = (l: L) => [
  {
    title: l(["Fala português.", "Até nas contas."], ["Speaks plain English.", "Even in the math."]),
    text: l(
      "Moedas com a cotação do dia, unidades, fusos e datas, escritos do jeito que você falaria.",
      "Currencies at today's rate, units, time zones, and dates, typed the way you'd say them.",
    ),
    visual: <SmartAnswers />,
  },
  {
    title: l(["Snippets que se", "escrevem sozinhos."], ["Snippets that", "write themselves."]),
    text: l(
      "Digite ;email em qualquer app e ele vira o seu e-mail. Também dá para escolher pela busca.",
      "Type ;email in any app and it turns into your email address. You can also pick one from search.",
    ),
    visual: <SnippetExpand />,
  },
  {
    title: l(["Os limites das suas IAs.", "Só das que você usa."], ["Your AI limits.", "Only for the ones you use."]),
    text: l(
      "Sessão e semana do Claude Code, Codex, Cursor, Copilot e Grok. Você escolhe quais aparecem.",
      "Session and weekly limits for Claude Code, Codex, Cursor, Copilot, and Grok. You choose which ones show up.",
    ),
    visual: <AILimits />,
  },
];

/** First install, in the order things show up on screen. */
const install = (l: L) => [
  {
    title: l("Baixe o Cleen", "Download Cleen"),
    text: l(
      "Clique em Baixar. O arquivo Cleen.dmg vai para a pasta Downloads.",
      "Click Download. The Cleen.dmg file goes to your Downloads folder.",
    ),
  },
  {
    title: l("Arraste para Aplicativos", "Drag it to Applications"),
    text: l(
      "Dê dois cliques no Cleen.dmg. Na janela que abre, arraste o ícone do Cleen para a pasta Aplicativos, logo ao lado.",
      "Double-click Cleen.dmg. In the window that opens, drag the Cleen icon onto the Applications folder right next to it.",
    ),
  },
  {
    title: l("Tente abrir uma vez", "Try to open it once"),
    text: l(
      "Abra a pasta Aplicativos e dê dois cliques no Cleen. O macOS avisa que não conseguiu verificar o app: feche esse aviso. É normal, o Cleen ainda não passou pela verificação paga da Apple.",
      "Open your Applications folder and double-click Cleen. macOS says it couldn't verify the app: close that alert. That's expected, since Cleen hasn't gone through Apple's paid verification yet.",
    ),
  },
  {
    title: l("Libere em Privacidade e Segurança", "Allow it in Privacy & Security"),
    text: l(
      "Abra Ajustes do Sistema › Privacidade e Segurança e role até o fim. Ao lado do aviso sobre o Cleen, clique em Abrir Mesmo Assim e confirme com a sua senha ou o Touch ID. Só nesta primeira vez.",
      "Open System Settings › Privacy & Security and scroll to the bottom. Next to the message about Cleen, click Open Anyway and confirm with your password or Touch ID. Only this first time.",
    ),
  },
  {
    title: l("Passe o mouse no notch", "Hover over the notch"),
    text: l(
      "O Cleen mora em volta da câmera. Um tour rápido mostra o resto, e daqui em diante ele se atualiza sozinho.",
      "Cleen lives around the camera. A quick tour shows you the rest, and from then on it updates itself.",
    ),
  },
];

const faq = (l: L): readonly (readonly [string, string])[] =>
  l(
    [
      ["O que é o Cleen?", "Um app para Mac que mora no notch. Ele limpa o disco, tem um launcher completo no ⌥ Espaço, guarda o que você copiou, mostra o Claude Code trabalhando e os limites das suas IAs, e traz quase trinta ferramentas a um gesto."],
      ["Dá para usar no lugar do Raycast?", "Para o dia a dia, sim. A busca abre apps, troca de janela pelo título, acha arquivos, converte moedas, unidades, fusos e datas, cola snippets e emoji, roda comandos do sistema e mostra as ações de cada resultado com ⌘K. Cada comando pode ganhar um apelido e um atalho só dele."],
      ["Abre ao passar o mouse ou ao clicar?", "Você escolhe em Ajustes › Aparência. Também abre com ⌃⌥C, com dois dedos para baixo no trackpad, e a busca abre com ⌥ Espaço."],
      ["Quais Macs funcionam?", "Macs com chip Apple e macOS 26 ou mais novo. Em telas sem notch, o Cleen desenha um no topo, inclusive em monitores externos."],
      ["É seguro limpar o Mac com ele?", "Toda remoção passa por uma trava que protege pastas do sistema e as pastas principais da sua conta. Antes de apagar qualquer coisa, o notch cresce e lista o que vai sair, quanto ocupa e se vai para o Lixo ou embora de vez. Nada acontece até você clicar em Confirmar."],
      ["É uma assinatura?", "Não. O Cleen é grátis e o código é aberto no GitHub."],
      ["Como recebo as atualizações?", "Sozinho. A cada seis horas ele procura uma versão nova, confere a integridade e a assinatura, e troca o app. Dá para desligar em Ajustes › Sobre."],
      ["As notas sincronizam com outro app?", "Sim, em Ajustes › Notas. Com o Obsidian, cada nota vira um arquivo .md numa pasta Cleen do seu cofre, e o que você muda lá volta para cá. Com o app Notas, cada nota ganha uma cópia numa pasta Cleen."],
      ["Meus dados ficam comigo?", "Sim. Nada é coletado nem enviado. A rede só é usada para tempo, cotações, câmbio, ícones do Lucide e para ler os limites das suas ferramentas de IA, direto em cada serviço."],
      ["Por que o macOS avisa na primeira vez?", "O Cleen ainda não é notarizado pela Apple. Na primeira abertura, vá em Ajustes do Sistema › Privacidade e Segurança e clique em Abrir Mesmo Assim. É só uma vez."],
    ],
    [
      ["What is Cleen?", "A Mac app that lives in the notch. It cleans up your disk, has a full launcher on ⌥ Space, keeps what you've copied, shows Claude Code at work and your AI limits, and puts almost thirty tools a gesture away."],
      ["Can it replace Raycast?", "For everyday use, yes. Search opens apps, switches windows by title, finds files, converts currencies, units, time zones, and dates, pastes snippets and emoji, runs system commands, and shows each result's actions with ⌘K. Any command can get its own alias and shortcut."],
      ["Does it open on hover or on click?", "You choose in Settings › Appearance. It also opens with ⌃⌥C or a two-finger swipe down on the trackpad, and search opens with ⌥ Space."],
      ["Which Macs does it work on?", "Macs with Apple silicon running macOS 26 or later. On displays without a notch, Cleen draws one at the top, external displays included."],
      ["Is it safe to clean my Mac with it?", "Every removal goes through a safeguard that protects system folders and the main folders in your account. Before anything is deleted, the notch expands and lists what will go, how much space it takes, and whether it goes to the Trash or is gone for good. Nothing happens until you click Confirm."],
      ["Is it a subscription?", "No. Cleen is free, and its source code is on GitHub."],
      ["How do I get updates?", "Automatically. Every six hours it looks for a new version, checks its integrity and signature, and swaps in the new app. You can turn this off in Settings › About."],
      ["Do notes sync with other apps?", "Yes, in Settings › Notes. With Obsidian, each note becomes an .md file in a Cleen folder in your vault, and changes you make there come back. With the Notes app, each note gets a copy in a Cleen folder."],
      ["Does my data stay with me?", "Yes. Nothing is collected or sent. The network is only used for weather, stock quotes, exchange rates, Lucide icons, and reading your AI tools' limits, straight from each service."],
      ["Why does macOS warn me the first time?", "Cleen isn't notarized by Apple yet. The first time you open it, go to System Settings › Privacy & Security and click Open Anyway. You only do this once."],
    ],
  );

/** What search engines read about the app. */
const structuredData = (lang: Lang) => ({
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: site.name,
  operatingSystem: "macOS 26",
  applicationCategory: "UtilitiesApplication",
  softwareVersion: site.version,
  downloadUrl: site.download,
  inLanguage: locale[lang],
  offers: { "@type": "Offer", price: "0", priceCurrency: "BRL" },
  author: { "@type": "Person", name: site.author, url: site.authorUrl },
});

/** The whole landing page, in one language. */
export function Landing({ lang }: { lang: Lang }) {
  const l = pick(lang);
  return (
    <LangProvider lang={lang}>
      <script type="application/ld+json">{JSON.stringify(structuredData(lang))}</script>
      <Navigation lang={lang} />
      <div className="ribbon">
        <p className="ribbon-text mx-auto max-w-[1000px] px-5 py-4 text-center text-[14px] leading-[1.43]">
          {l("Novo na busca do Cleen: ações com ⌘K, troca de janela, arquivos e snippets.", "New in Cleen's search: actions with ⌘K, window switching, files, and snippets.")}{" "}
          <a href={site.download} className="ribbon-link whitespace-nowrap hover:underline">
            {l("Baixe grátis ›", "Get it free ›")}
          </a>
        </p>
      </div>

      <main id="topo" className="mx-auto max-w-[1380px] px-3 pb-10 pt-3 sm:px-6">
        {/* Hero */}
        <section className="overflow-hidden rounded-[18px] bg-tile">
          <div className="px-6 pt-14 text-center sm:pt-16">
            <Image src="/cleen-icon.png" alt={l("Ícone do Cleen", "Cleen icon")} width={96} height={96} priority className="mx-auto" unoptimized />
            <p className="mt-3 text-[17px] font-semibold text-new">{l("Novo", "New")}</p>
            <h1 className="mt-1 text-[clamp(40px,5vw,56px)] font-semibold leading-[1.07] tracking-[-0.005em]">Cleen</h1>
            <p className="mt-1 text-[clamp(22px,2.4vw,28px)] font-normal leading-[1.14] tracking-[0.007em]">{l("Tudo no notch.", "Everything in the notch.")}</p>
            <p className="mx-auto mt-5 max-w-[580px] text-[clamp(17px,1.6vw,21px)] leading-[1.38] tracking-[0.011em] text-mute">
              {l(
                "Limpeza, busca, janelas e quase trinta ferramentas, a um olhar. Grátis, sem conta e sem assinatura.",
                "Cleanup, search, windows, and nearly thirty tools, at a glance. Free, with no account and no subscription.",
              )}
            </p>
            <div className="mt-7 flex flex-wrap items-center justify-center gap-4">
              <DownloadButton lang={lang} />
              <OutlineLink href="#recursos">{l("Saiba mais", "Learn more")}</OutlineLink>
            </div>
            <p className="mt-6 text-[14px] text-mute">{l("Código aberto. Atualiza sozinho.", "Open source. Updates itself.")}</p>
            <p className="mt-2 text-[12px] text-faint">
              {l("macOS 26 ou mais novo · Mac com chip Apple · Versão ", "macOS 26 or later · Mac with Apple silicon · Version ")}{site.version}
              <sup>1</sup>
            </p>
          </div>
          <div className="px-5 pb-5 pt-8 sm:px-[8.33%] sm:pb-[5%] sm:pt-12">
            <div className="mx-auto max-w-[940px]">
              <Replica label={l("O Cleen aberto no notch, no Início", "Cleen open in the notch, on Home")} tab="home" control="lg" />
            </div>
          </div>
        </section>

        {/* Feature tiles */}
        <div id="recursos" className="mt-3 grid scroll-mt-16 gap-3 lg:grid-cols-2 sm:mt-6 sm:gap-6">
          <Tile lang={lang} id="busca" dark eyebrow={l("Busca", "Search")} title={l(<>Um launcher inteiro.<br />No notch.</>, <>A full launcher.<br />In the notch.</>)} more="#todo-motivo"
              visual={<Replica label={l("A busca do Cleen", "Cleen's search")} mode="search" tone="teal" />}>
              {l(
                "⌥ Espaço abre na hora. Troque de janela, ache arquivos, converta moedas e fusos, cole snippets. E ⌘K mostra o que mais dá para fazer com cada resultado.",
                "⌥ Space opens it instantly. Switch windows, find files, convert currencies and time zones, paste snippets. And ⌘K shows what else you can do with each result.",
              )}
          </Tile>
          <Tile lang={lang} id="limpeza" eyebrow={l("Limpeza", "Cleanup")} title={l(<>Seu Mac mais leve.<br />Num clique.</>, <>A lighter Mac.<br />In one click.</>)} more="#perguntas"
              visual={<Replica label={l("A visão geral do disco", "The disk overview")} tab="overview" />}>
              {l(
                "Caches, restos de apps, node_modules parados e duplicados. Antes de apagar, o notch mostra a lista do que sai.",
                "Caches, app leftovers, idle node_modules, and duplicates. Before anything is deleted, the notch lists what goes.",
              )}
          </Tile>
          <Tile lang={lang} id="claude" eyebrow="Claude Code" title={l(<>Seus agentes.<br />À vista.</>, <>Your agents.<br />In view.</>)} more="#ferramentas" visual={<ClaudeLive />}>
              {l(
                "Cada sessão ao vivo ao lado da câmera, as permissões aprovadas direto do notch e os limites do plano sempre à vista.",
                "Every live session next to the camera, permissions approved right from the notch, and your plan's limits always in view.",
              )}
          </Tile>
          <Tile lang={lang} dark eyebrow={l("Notch fechado", "Closed notch")} title={l(<>O notch fala.<br />Com você.</>, <>The notch talks.<br />To you.</>)} more="#ferramentas" visual={<LiveActivities />}>
              {l(
                "O espaço livre, o carregador, os fones, a próxima reunião, a música nova e o timer. Em tela cheia, fica só preto.",
                "Free space, the charger, your headphones, the next meeting, a new song, and the timer. In full screen, it's just black.",
              )}
          </Tile>
        </div>

        {/* Make it yours */}
        <section className="mt-24 sm:mt-32">
          <div className="px-4 text-center">
            <h2 className="mx-auto max-w-[760px] text-[clamp(36px,5vw,64px)] font-semibold leading-none tracking-[-0.009em]">
              {l("Do seu jeito,", "Your way,")}
              <br />
              {l("do tamanho certo.", "and just the right size.")}
            </h2>
            <p className="mx-auto mt-4 max-w-[600px] text-[19px] leading-[1.42] text-mute">
              {l(
                "Monte o Início com os widgets que importam, escolha as abas da barra e o tamanho do painel.",
                "Set up Home with the widgets that matter, and pick the tabs in the bar and the size of the panel.",
              )}
            </p>
          </div>
          <div className="mt-12 rounded-[18px] bg-tile px-5 py-5 sm:px-[8.33%] sm:py-[5%]">
            <div className="mx-auto max-w-[940px]">
              <Replica label={l("Ajustes de aparência do notch", "The notch's Appearance settings")} mode="settings" settings="appearance" tone="dusk" control="lg" />
            </div>
          </div>
        </section>

        {/* Everyday features */}
        <section id="dia-a-dia" className="mt-24 scroll-mt-16 sm:mt-32">
          <div className="text-center">
            <h2 className="text-[clamp(36px,5vw,64px)] font-semibold leading-none tracking-[-0.009em]">
              {l("As pequenas coisas.", "The little things.")}
              <br />
              {l("Todo dia.", "Every day.")}
            </h2>
          </div>
          <div className="mt-12">
            <Everyday />
          </div>
        </section>

        {/* Every reason */}
        <section id="todo-motivo" className="mt-24 scroll-mt-16 sm:mt-32">
          <div className="text-center">
            <h2 className="text-[clamp(36px,5vw,64px)] font-semibold leading-none tracking-[-0.009em]">
              {l("Todo motivo para pôr", "Every reason to put")}
              <br />
              {l("o notch para trabalhar.", "the notch to work.")}
            </h2>
          </div>
          <div className="mt-12 grid gap-3 sm:gap-5 lg:grid-cols-3">
            <div className="flex flex-col overflow-hidden rounded-[18px] bg-tile">
              <div className="px-8 pt-10 text-center">
                <h3 className="text-[24px] font-semibold leading-tight tracking-[-0.015em]">{l(<>Abra de qualquer lugar.<br />E dê um atalho a cada comando.</>, <>Open it from anywhere.<br />And give any command a shortcut.</>)}</h3>
              </div>
              <div className="flex flex-1 items-center py-12">
                <div className="w-full px-6">
                  <Keycaps lang={lang} />
                  <CommandHotkeys />
                </div>
              </div>
            </div>
            <div className="flex flex-col overflow-hidden rounded-[18px] bg-tile">
              <div className="px-8 pt-10 text-center">
                <h3 className="text-[24px] font-semibold leading-tight tracking-[-0.015em]">{l(<>Escolha as ferramentas.<br />Na ordem que quiser.</>, <>Pick your tools.<br />In any order you like.</>)}</h3>
              </div>
              <div className="mt-auto px-5 pb-6 pt-10">
                <Replica label={l("O Início do Cleen", "Cleen's Home")} tab="home" tone="dusk" />
              </div>
            </div>
            <div className="flex flex-col overflow-hidden rounded-[18px] bg-tile">
              <div className="px-8 pt-10 text-center">
                <h3 className="text-[24px] font-semibold leading-tight tracking-[-0.015em]">{l(<>Brilho do monitor externo.<br />Pelo próprio cabo.</>, <>External display brightness.<br />Right over the cable.</>)}</h3>
              </div>
              <div className="mt-auto px-5 pb-6 pt-10">
                <Replica label={l("Brilho da tela do Mac e do monitor externo", "Brightness of the Mac's display and an external display")} mode="settings" settings="displays" tone="teal" />
              </div>
            </div>
            {reasons(l).map((reason) => (
              <div key={reason.title[0]} className="flex flex-col overflow-hidden rounded-[18px] bg-tile">
                <div className="px-8 pt-10 text-center">
                  <h3 className="text-[24px] font-semibold leading-tight tracking-[-0.015em]">
                    {reason.title[0]}
                    <br />
                    {reason.title[1]}
                  </h3>
                  <p className="mx-auto mt-3 max-w-[320px] text-[15px] leading-[1.47] text-mute">{reason.text}</p>
                </div>
                <div className="mt-auto px-6 pb-8 pt-10">{reason.visual}</div>
              </div>
            ))}
          </div>
        </section>

        {/* Tools */}
        <section id="ferramentas" className="mt-24 scroll-mt-16 sm:mt-32">
          <div className="text-center">
            <h2 className="text-[clamp(36px,5vw,64px)] font-semibold leading-none tracking-[-0.009em]">
              {l("Ferramentas. Em volta do notch", "Tools. Around the notch")}
              <br className="max-[734px]:hidden" />
              {l(" e ao longo do seu dia.", " and all through your day.")}
            </h2>
            <div className="mt-4">
              <MoreLink href="#instalar">{l("Baixe e experimente", "Download and try it")}</MoreLink>
            </div>
          </div>
          <div className="mt-12">
            <Gallery label={l("Ferramentas do Cleen", "Cleen's tools")}>
              {tools(l).map((tool) => (
                <article key={tool.tab} className="flex h-[410px] w-[300px] shrink-0 snap-start flex-col overflow-hidden rounded-[18px] bg-tile sm:h-[480px] sm:w-[480px]">
                  <h3 className="px-[7.3%] pt-[30px] text-center text-[19px] font-semibold leading-[1.21] tracking-[0.012em] sm:pt-[34px] sm:text-[24px] sm:leading-[1.17] sm:tracking-[0.009em]">
                    {tool.title[0]}
                    <br />
                    {tool.title[1]}
                  </h3>
                  <div className="mt-auto w-full px-5 pb-6">
                    <Replica label={`${tool.title[0]} ${tool.title[1]}`} tab={tool.tab} tone={tool.tone} />
                  </div>
                </article>
              ))}
            </Gallery>
          </div>
        </section>

        {/* Get it */}
        <section id="instalar" className="mt-24 scroll-mt-16 sm:mt-32">
          <div className="text-center">
            <h2 className="text-[clamp(36px,5vw,64px)] font-semibold leading-none tracking-[-0.009em]">{l("Baixe o Cleen.", "Get Cleen.")}</h2>
            <p className="mt-3 text-[19px] text-mute">{l("Grátis. Para sempre.", "Free. Forever.")}</p>
          </div>
          <div className="mx-auto mt-10 max-w-[680px] rounded-[18px] bg-tile px-8 py-12 text-center">
            <Image src="/cleen-icon.png" alt="" width={84} height={84} className="mx-auto" unoptimized />
            <h3 className="mt-3 text-[28px] font-semibold tracking-[-0.02em]">Cleen</h3>
            <p className="mt-1 text-[48px] font-semibold tracking-[-0.03em]">{l("Grátis", "Free")}</p>
            <p className="text-[15px] text-mute">{l("Sem conta, sem assinatura, sem anúncio.", "No account, no subscription, no ads.")}</p>
            <div className="mt-6">
              <DownloadButton lang={lang} label={l("Baixar para Mac", "Download for Mac")} />
            </div>
            <p className="mt-4 text-[12px] text-faint">
              {l("Versão ", "Version ")}{site.version}{l(" · cerca de 7 MB ·", " · about 7 MB ·")}{" "}
              <a href={site.releases} className="text-link hover:underline">
                {l("todas as versões", "all versions")}
              </a>
            </p>
          </div>
          <div className="mx-auto mt-12 grid max-w-[900px] gap-x-8 gap-y-8 sm:grid-cols-3">
            {included(l).map(([title, text]) => (
              <div key={title} className="text-center">
                <h4 className="text-[17px] font-semibold">{title}</h4>
                <p className="mt-1 text-[14px] text-mute">{text}</p>
              </div>
            ))}
          </div>
          <div className="mt-20 text-center">
            <h3 className="text-[28px] font-semibold tracking-[-0.02em]">{l("Pronto em um minuto.", "Ready in a minute.")}</h3>
            <p className="mx-auto mt-2 max-w-[520px] text-balance text-[17px] leading-[1.47] text-mute">
              {l(
                "Primeira vez instalando um app fora da App Store? É só seguir na ordem.",
                "First time installing an app from outside the App Store? Just follow these steps in order.",
              )}
            </p>
          </div>
          <ol className="mx-auto mt-10 max-w-[640px] divide-y divide-line border-y border-line text-left">
            {install(l).map(({ title, text }, index) => (
              <li key={title} className="flex gap-5 py-6">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-line text-[15px] font-semibold tabular-nums">{index + 1}</span>
                <div className="pt-1">
                  <h4 className="text-[19px] font-semibold leading-[1.21]">{title}</h4>
                  <p className="mt-1.5 text-[16px] leading-[1.5] text-mute">{text}</p>
                </div>
              </li>
            ))}
          </ol>
        </section>

      </main>

      {/* FAQ */}
      <section id="perguntas" className="scroll-mt-16 bg-tile px-6 py-[60px] sm:py-[100px]">
        <h2 className="text-center text-[clamp(32px,5vw,64px)] font-semibold leading-none tracking-[-0.009em]">{l("Perguntas? Respostas.", "Questions? Answers.")}</h2>
        <div className="mx-auto mt-10 max-w-[820px] border-t border-line sm:mt-12">
          {faq(l).map(([question, answer]) => (
            <details key={question} className="group border-b border-line [&_summary::-webkit-details-marker]:hidden">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 py-5 text-[17px] font-semibold leading-[1.24] sm:py-6 sm:text-[21px] sm:leading-[1.19]">
                {question}
                <svg viewBox="0 0 24 24" aria-hidden className="h-6 w-6 shrink-0 transition-transform duration-300 ease-(--ease-apple) group-open:rotate-45" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
                  <path d="M12 5v14M5 12h14" />
                </svg>
              </summary>
              <p className="pb-7 text-[17px] leading-[1.47] text-ink sm:pr-12">{answer}</p>
            </details>
          ))}
        </div>
      </section>

      <footer className="bg-page text-[12px] text-mute">
        <div className="mx-auto max-w-[980px] border-t border-line px-5 py-6 leading-relaxed">
          <p>
            {l(
              "1. O Cleen ainda não é notarizado pela Apple: na primeira abertura, libere em Ajustes do Sistema › Privacidade e Segurança › Abrir Mesmo Assim.",
              "1. Cleen isn't notarized by Apple yet: the first time you open it, allow it in System Settings › Privacy & Security › Open Anyway.",
            )}
          </p>
          <p className="mt-2">
            {l(
              "Mac e macOS são marcas da Apple Inc., registradas nos EUA e em outros países. O Cleen não é afiliado à Apple. Claude é uma marca da Anthropic.",
              "Mac and macOS are trademarks of Apple Inc., registered in the U.S. and other countries. Cleen is not affiliated with Apple. Claude is a trademark of Anthropic.",
            )}
          </p>
        </div>
        <div className="mx-auto flex max-w-[980px] flex-col gap-2 border-t border-line px-5 py-5 md:flex-row md:justify-between">
          <p>
            Copyright © {new Date().getFullYear()}{" "}
            <a href={site.authorUrl} className="hover:underline">
              {site.author}
            </a>
            .
          </p>
          <div className="flex flex-wrap gap-5">
            <LangSwitch />
            <a href={site.repo} className="hover:underline">GitHub</a>
            <a href={site.releases} className="hover:underline">{l("Versões", "Releases")}</a>
            <a href={`${site.repo}/issues`} className="hover:underline">{l("Pedir um recurso", "Request a feature")}</a>
          </div>
        </div>
      </footer>
    </LangProvider>
  );
}

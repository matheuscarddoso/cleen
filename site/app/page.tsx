import Image from "next/image";
import { DownloadButton, MoreLink, OutlineLink } from "@/components/Buttons";
import { Navigation } from "@/components/Navigation";
import { ClaudeStrip, Keycaps, LiveStack } from "@/components/Pieces";
import { Reveal } from "@/components/Reveal";
import { Shot } from "@/components/Shot";
import { Tile } from "@/components/Tile";
import { site } from "@/lib/site";

const tools = [
  { title: "Tempo", text: "Agora e os próximos sete dias, onde você está.", shot: "/shots/weather.png", alt: "Aba Tempo com São Paulo e a previsão da semana", tone: "blue" },
  { title: "Ações", text: "Cotações com o gráfico do dia, B3 e Nasdaq.", shot: "/shots/stocks.png", alt: "Aba Ações com Ibovespa, Apple, NVIDIA e Petrobras", tone: "teal" },
  { title: "Timer e Pomodoro", text: "A contagem fica ao lado da câmera.", shot: "/shots/timer.png", alt: "Aba Timer com um timer de 10 minutos", tone: "dusk" },
  { title: "Conversor", text: "Unidades e moedas. Return cola o resultado.", shot: "/shots/converter.png", alt: "Aba Conversor de quilômetros para milhas", tone: "blue" },
  { title: "Emoji", text: "Busca em português e cola no app em que você está.", shot: "/shots/emoji.png", alt: "Aba Emoji com a grade de carinhas", tone: "teal" },
  { title: "Ícones Lucide", text: "Mais de 1.900 ícones. Cole o SVG ou o JSX.", shot: "/shots/icons.png", alt: "Aba Ícones com ícones do Lucide", tone: "dusk" },
  { title: "Sistema", text: "CPU, memória, rede e processos.", shot: "/shots/system.png", alt: "Aba Sistema com CPU, memória e processos", tone: "blue" },
] as const;

const everyday = [
  { color: "#ff9500", glyph: "⏱", title: "Timer", text: "Timer simples ou Pomodoro, com a contagem no notch fechado." },
  { color: "#34c759", glyph: "⬇", title: "Shelf e AirDrop", text: "Arraste arquivos até o notch e mande para onde quiser." },
  { color: "#007aff", glyph: "◉", title: "Espelho", text: "A câmera frontal antes da chamada, em um toque." },
  { color: "#af52de", glyph: "≡", title: "Teleprompter", text: "O roteiro rolando logo abaixo da câmera." },
] as const;

const included = [
  ["Grátis", "Sem assinatura e sem conta."],
  ["Todas as ferramentas", "Mais de vinte, e as que vierem."],
  ["Atualiza sozinho", "Confere a assinatura antes de trocar."],
  ["Sem telemetria", "Nada sai do seu Mac."],
  ["Código aberto", "Para quem quiser conferir."],
  ["Português e inglês", "Segue o idioma do seu Mac."],
] as const;

const faq = [
  ["O que é o Cleen?", "Um app para Mac que mora no notch. Ele limpa o disco, move janelas, busca apps, cola emoji e ícones, mostra o Claude Code trabalhando e traz mais de vinte ferramentas a um gesto."],
  ["Abre ao passar o mouse ou ao clicar?", "Você escolhe em Ajustes › Aparência. Também abre com ⌃⌥C, com dois dedos para baixo no trackpad, e a busca abre com ⌥ Espaço."],
  ["Quais Macs funcionam?", "Macs com chip Apple e macOS 26 ou mais novo. Em telas sem notch, o Cleen desenha um no topo, inclusive em monitores externos."],
  ["É seguro limpar o Mac com ele?", "Toda remoção passa por uma trava que protege pastas do sistema e as pastas principais da sua conta. O que é seu vai para o Lixo; só caches que se recriam sozinhos são apagados de vez, sempre com dois cliques."],
  ["É uma assinatura?", "Não. O Cleen é grátis e o código é aberto no GitHub."],
  ["Como recebo as atualizações?", "Sozinho. A cada seis horas ele procura uma versão nova, confere a integridade e a assinatura, e troca o app. Dá para desligar em Ajustes › Sobre."],
  ["Meus dados ficam comigo?", "Sim. Nada é coletado nem enviado. A rede só é usada para tempo, cotações, câmbio, ícones do Lucide e para ler os limites das suas ferramentas de IA, direto em cada serviço."],
  ["Por que o macOS avisa na primeira vez?", "O Cleen ainda não é notarizado pela Apple. Na primeira abertura, vá em Ajustes do Sistema › Privacidade e Segurança e clique em Abrir Mesmo Assim. É só uma vez."],
] as const;

/** What search engines read about the app. */
const structuredData = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: site.name,
  operatingSystem: "macOS 26",
  applicationCategory: "UtilitiesApplication",
  softwareVersion: site.version,
  downloadUrl: site.download,
  offers: { "@type": "Offer", price: "0", priceCurrency: "BRL" },
  author: { "@type": "Person", name: site.author, url: site.authorUrl },
};

export default function Home() {
  return (
    <>
      <script type="application/ld+json">{JSON.stringify(structuredData)}</script>
      <Navigation />
      <a href={site.download} className="block bg-accent px-5 py-3 text-center text-[14px] text-white hover:underline">
        Cleen {site.version}: busca no notch com ⌥ Espaço, Claude Code ao vivo e mais. Baixe grátis ›
      </a>

      <main id="topo" className="mx-auto max-w-[1340px] px-3 pb-10 pt-3 sm:px-5">
        {/* Hero */}
        <section className="overflow-hidden rounded-[28px] bg-tile">
          <Reveal className="px-6 pt-14 text-center sm:pt-16">
            <Image src="/icon.png" alt="Ícone do Cleen" width={96} height={96} priority className="mx-auto" />
            <p className="mt-3 text-[17px] font-semibold text-new">Novo</p>
            <h1 className="mt-1 text-[clamp(48px,7vw,80px)] font-semibold leading-[1.05] tracking-[-0.03em]">Cleen</h1>
            <p className="mt-1 text-[clamp(24px,3vw,32px)] font-medium tracking-[-0.015em]">Tudo no notch.</p>
            <p className="mx-auto mt-5 max-w-[560px] text-[19px] leading-[1.42] text-mute">
              Limpeza, busca, janelas e mais de vinte ferramentas, a um olhar. Grátis, sem conta e sem assinatura.
            </p>
            <div className="mt-7 flex flex-wrap items-center justify-center gap-4">
              <DownloadButton />
              <OutlineLink href="#recursos">Saiba mais</OutlineLink>
            </div>
            <p className="mt-6 text-[14px] text-mute">Código aberto. Atualiza sozinho.</p>
            <p className="mt-2 text-[12px] text-faint">
              macOS 26 ou mais novo · Mac com chip Apple · Versão {site.version}
              <sup>1</sup>
            </p>
          </Reveal>
          <div className="mx-auto mt-12 max-w-[1000px] px-4 sm:px-8">
            <div className="notch-drop">
              <Shot src="/shots/home.png" alt="O Cleen aberto no notch: tempo em São Paulo, um timer e o uso de CPU e memória, com a barra de ferramentas embaixo" priority scale={0.86} rounded="rounded-t-[26px]" />
            </div>
          </div>
        </section>

        {/* Feature tiles */}
        <div id="recursos" className="mt-3 grid scroll-mt-16 gap-3 lg:grid-cols-2 sm:mt-5 sm:gap-5">
          <Reveal>
            <Tile id="busca" dark eyebrow="Busca" title={<>Um launcher inteiro.<br />No notch.</>} more="#todo-motivo"
              visual={<Shot src="/shots/search.png" alt="Busca do Cleen com comandos de janela" tone="teal" scale={1} />}>
              ⌥ Espaço abre na hora. Mova janelas, abra apps, faça contas e cole emoji, ícones e cores.
            </Tile>
          </Reveal>
          <Reveal delay={90}>
            <Tile id="limpeza" eyebrow="Limpeza" title={<>Seu Mac mais leve.<br />Num clique.</>} more="#perguntas"
              visual={<Shot src="/shots/overview.png" alt="Visão geral do disco com o que dá para limpar" scale={1} />}>
              Caches, restos de apps, node_modules parados e duplicados. O que é seu vai para o Lixo.
            </Tile>
          </Reveal>
          <Reveal>
            <Tile id="claude" eyebrow="Claude Code" title={<>Seus agentes.<br />À vista.</>} more="#ferramentas" visual={<ClaudeStrip />}>
              Cada sessão ao vivo ao lado da câmera, e as permissões aprovadas direto do notch.
            </Tile>
          </Reveal>
          <Reveal delay={90}>
            <Tile dark eyebrow="Notch fechado" title={<>O notch fala.<br />Com você.</>} more="#ferramentas" visual={<LiveStack />}>
              Carregador, fones, a próxima reunião, a música nova e o timer. Em tela cheia, fica só preto.
            </Tile>
          </Reveal>
        </div>

        {/* Make it yours */}
        <section className="mt-24 sm:mt-32">
          <Reveal className="px-4 text-center">
            <h2 className="mx-auto max-w-[760px] text-[clamp(34px,5vw,56px)] font-semibold leading-[1.07] tracking-[-0.025em]">
              Do seu jeito,
              <br />
              do tamanho certo.
            </h2>
            <p className="mx-auto mt-4 max-w-[600px] text-[19px] leading-[1.42] text-mute">
              Monte o Início com os widgets que importam, escolha as abas da barra e o tamanho do painel.
            </p>
          </Reveal>
          <Reveal className="mt-12 overflow-hidden rounded-[28px] bg-tile px-4 pt-10 sm:px-16 sm:pt-16">
            <Shot src="/shots/appearance.png" alt="Ajustes de aparência do notch" tone="dusk" scale={0.9} rounded="rounded-t-[26px]" />
          </Reveal>
          <div className="mt-10 grid gap-8 px-2 sm:grid-cols-2 lg:grid-cols-4">
            {everyday.map((item, index) => (
              <Reveal key={item.title} delay={index * 70} className="text-center">
                <span aria-hidden className="mx-auto flex h-14 w-14 items-center justify-center rounded-[16px] text-[26px] text-white" style={{ background: item.color }}>
                  {item.glyph}
                </span>
                <h3 className="mt-4 text-[19px] font-semibold">{item.title}</h3>
                <p className="mx-auto mt-1 max-w-[240px] text-[15px] leading-[1.45] text-mute">{item.text}</p>
              </Reveal>
            ))}
          </div>
        </section>

        {/* Every reason */}
        <section id="todo-motivo" className="mt-24 scroll-mt-16 sm:mt-32">
          <Reveal className="text-center">
            <h2 className="text-[clamp(34px,5vw,56px)] font-semibold leading-[1.07] tracking-[-0.025em]">
              Todo motivo para pôr
              <br />o notch para trabalhar.
            </h2>
          </Reveal>
          <div className="mt-12 grid gap-3 sm:gap-5 lg:grid-cols-3">
            <Reveal className="flex flex-col overflow-hidden rounded-[28px] bg-tile">
              <div className="px-8 pt-10 text-center">
                <h3 className="text-[24px] font-semibold leading-tight tracking-[-0.015em]">Abra de qualquer lugar,<br />com um atalho.</h3>
              </div>
              <div className="flex flex-1 items-center py-14">
                <div className="w-full">
                  <Keycaps />
                </div>
              </div>
            </Reveal>
            <Reveal delay={80} className="flex flex-col overflow-hidden rounded-[28px] bg-tile">
              <div className="px-8 pt-10 text-center">
                <h3 className="text-[24px] font-semibold leading-tight tracking-[-0.015em]">Escolha as ferramentas.<br />Na ordem que quiser.</h3>
              </div>
              <div className="mt-10 flex flex-1 items-end px-6">
                <Shot src="/shots/home.png" alt="O Início do Cleen com widgets de tempo, timer e sistema" scale={1} />
              </div>
            </Reveal>
            <Reveal delay={160} className="flex flex-col overflow-hidden rounded-[28px] bg-tile">
              <div className="px-8 pt-10 text-center">
                <h3 className="text-[24px] font-semibold leading-tight tracking-[-0.015em]">Brilho do monitor externo.<br />Pelo próprio cabo.</h3>
              </div>
              <div className="mt-10 flex flex-1 items-end px-6">
                <Shot src="/shots/displays.png" alt="Ajustes de brilho da tela do Mac e do monitor externo" tone="teal" scale={1} />
              </div>
            </Reveal>
          </div>
        </section>

        {/* Tools */}
        <section id="ferramentas" className="mt-24 scroll-mt-16 sm:mt-32">
          <Reveal className="text-center">
            <h2 className="text-[clamp(34px,5vw,56px)] font-semibold leading-[1.07] tracking-[-0.025em]">
              Ferramentas. Em volta do notch
              <br />e ao longo do seu dia.
            </h2>
            <div className="mt-4">
              <MoreLink href="#instalar">Baixe e experimente</MoreLink>
            </div>
          </Reveal>
          <div className="no-scrollbar -mx-3 mt-12 flex snap-x snap-mandatory gap-5 overflow-x-auto px-3 pb-4 sm:-mx-5 sm:px-5">
            {tools.map((tool) => (
              <article key={tool.title} className="w-[min(420px,85vw)] shrink-0 snap-start overflow-hidden rounded-[28px] bg-tile">
                <div className="px-5 pt-5">
                  <Shot src={tool.shot} alt={tool.alt} tone={tool.tone} scale={1} rounded="rounded-[18px]" />
                </div>
                <div className="px-7 pb-8 pt-6 text-center">
                  <h3 className="text-[21px] font-semibold tracking-[-0.01em]">{tool.title}</h3>
                  <p className="mt-1 text-[15px] leading-[1.45] text-mute">{tool.text}</p>
                </div>
              </article>
            ))}
          </div>
        </section>

        {/* Get it */}
        <section id="instalar" className="mt-24 scroll-mt-16 sm:mt-32">
          <Reveal className="text-center">
            <h2 className="text-[clamp(34px,5vw,56px)] font-semibold leading-[1.07] tracking-[-0.025em]">Baixe o Cleen.</h2>
            <p className="mt-3 text-[19px] text-mute">Grátis. Para sempre.</p>
          </Reveal>
          <Reveal className="mx-auto mt-10 max-w-[680px] rounded-[28px] bg-tile px-8 py-12 text-center">
            <Image src="/icon.png" alt="" width={84} height={84} className="mx-auto" />
            <h3 className="mt-3 text-[28px] font-semibold tracking-[-0.02em]">Cleen</h3>
            <p className="mt-1 text-[48px] font-semibold tracking-[-0.03em]">Grátis</p>
            <p className="text-[15px] text-mute">Sem conta, sem assinatura, sem anúncio.</p>
            <div className="mt-6">
              <DownloadButton label="Baixar para Mac" />
            </div>
            <p className="mt-4 text-[12px] text-faint">
              Versão {site.version} · cerca de 4 MB ·{" "}
              <a href={site.releases} className="text-link hover:underline">
                todas as versões
              </a>
            </p>
          </Reveal>
          <div className="mx-auto mt-12 grid max-w-[900px] gap-x-8 gap-y-8 sm:grid-cols-3">
            {included.map(([title, text]) => (
              <div key={title} className="text-center">
                <h4 className="text-[17px] font-semibold">{title}</h4>
                <p className="mt-1 text-[14px] text-mute">{text}</p>
              </div>
            ))}
          </div>
          <Reveal className="mt-20 text-center">
            <h3 className="text-[28px] font-semibold tracking-[-0.02em]">Pronto em um minuto.</h3>
          </Reveal>
          <ol className="mx-auto mt-10 grid max-w-[900px] gap-8 sm:grid-cols-3">
            {[
              ["Baixe", "O instalador vem direto dos releases do GitHub."],
              ["Arraste", "Leve o Cleen para Aplicativos e abra por lá."],
              ["Libere uma vez", "Em Ajustes do Sistema › Privacidade e Segurança, clique em Abrir Mesmo Assim."],
            ].map(([title, text], index) => (
              <li key={title} className="text-center">
                <span className="mx-auto flex h-11 w-11 items-center justify-center rounded-full border border-line text-[17px] font-semibold">{index + 1}</span>
                <h4 className="mt-4 text-[19px] font-semibold">{title}</h4>
                <p className="mx-auto mt-1 max-w-[240px] text-[15px] leading-[1.45] text-mute">{text}</p>
              </li>
            ))}
          </ol>
        </section>

        {/* FAQ */}
        <section id="perguntas" className="mx-auto mt-24 max-w-[980px] scroll-mt-16 sm:mt-32">
          <Reveal className="text-center">
            <h2 className="text-[clamp(34px,5vw,56px)] font-semibold leading-[1.07] tracking-[-0.025em]">Perguntas? Respostas.</h2>
          </Reveal>
          <div className="mt-10 rounded-[28px] bg-tile px-6 sm:px-10">
            {faq.map(([question, answer], index) => (
              <details key={question} className={`group py-5 ${index > 0 ? "border-t border-line/70" : ""}`}>
                <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-[17px] font-semibold">
                  {question}
                  <svg viewBox="0 0 16 16" aria-hidden className="h-4 w-4 shrink-0 text-mute transition-transform duration-300 group-open:rotate-45" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
                    <path d="M8 2v12M2 8h12" />
                  </svg>
                </summary>
                <p className="mt-3 max-w-[720px] text-[17px] leading-[1.47] text-mute">{answer}</p>
              </details>
            ))}
          </div>
        </section>
      </main>

      <footer className="bg-page text-[12px] text-mute">
        <div className="mx-auto max-w-[980px] border-t border-line px-5 py-6 leading-relaxed">
          <p>
            1. O Cleen ainda não é notarizado pela Apple: na primeira abertura, libere em Ajustes do Sistema › Privacidade e Segurança › Abrir Mesmo Assim.
          </p>
          <p className="mt-2">Mac e macOS são marcas da Apple Inc., registradas nos EUA e em outros países. O Cleen não é afiliado à Apple. Claude é uma marca da Anthropic.</p>
        </div>
        <div className="mx-auto flex max-w-[980px] flex-col gap-2 border-t border-line px-5 py-5 md:flex-row md:justify-between">
          <p>
            Copyright © {new Date().getFullYear()}{" "}
            <a href={site.authorUrl} className="hover:underline">
              {site.author}
            </a>
            .
          </p>
          <div className="flex gap-5">
            <a href={site.repo} className="hover:underline">GitHub</a>
            <a href={site.releases} className="hover:underline">Versões</a>
            <a href={`${site.repo}/issues`} className="hover:underline">Pedir um recurso</a>
          </div>
        </div>
      </footer>
    </>
  );
}

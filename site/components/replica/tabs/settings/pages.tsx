"use client";

import {
  AppWindow,
  ArrowLeftRight,
  Asterisk,
  Calendar,
  Camera,
  ChartColumn,
  ChartLine,
  ChartNoAxesColumn,
  ChartPie,
  CircleCheck,
  CircleMinus,
  CirclePlus,
  Clipboard,
  CloudSun,
  Code,
  Copy,
  File,
  Folder,
  Grid3x3,
  HardDrive,
  Inbox,
  Laptop,
  Layers,
  LayoutGrid,
  ListChecks,
  Menu,
  MessagesSquare,
  Monitor,
  NotebookText,
  Power,
  Puzzle,
  Smile,
  TextAlignCenter,
  Timer,
  Trash2,
  Wrench,
  type LucideIcon,
} from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";
import { site } from "@/lib/site";
import { notch } from "../../style";
import { BrightnessSlider, card, Caps, GlyphButton, Group, Keycap, Pill, Reveal, Row, Segmented, Stepper, Switch } from "./controls";
import { heights, widths, type Appearance, type Displays, type Idle } from "./model";

/** A page's groups, 10 apart like NotchSettingsView's stack. */
function Stack({ gap = 10, children }: { gap?: number; children: ReactNode }) {
  return (
    <div className="flex flex-col" style={{ gap }}>
      {children}
    </div>
  );
}

/** A switch row: the label names the switch for screen readers too. */
function SwitchRow({ title, note, on, onChange }: { title: string; note?: string; on: boolean; onChange: (on: boolean) => void }) {
  return (
    <Row title={title} note={note}>
      <Switch label={title} on={on} onChange={onChange} />
    </Row>
  );
}

const delays = [
  { label: "Nenhum", value: 0 },
  { label: "Curto", value: 0.12 },
  { label: "Médio", value: 0.3 },
  { label: "Longo", value: 0.6 },
] as const;

const idles: { label: string; value: Idle }[] = [
  { label: "Disco", value: "disk" },
  { label: "Bateria", value: "battery" },
  { label: "CPU", value: "cpu" },
  { label: "Nada", value: "none" },
];

/** The on/off settings of Aparência. */
type Toggle = { [K in keyof Appearance]: Appearance[K] extends boolean ? K : never }[keyof Appearance];

/** Aparência: NotchAppearanceSettings, then "Notch fechado" (ClosedNotchSettings). */
export function AppearancePage({ prefs, onChange }: { prefs: Appearance; onChange: (patch: Partial<Appearance>) => void }) {
  const toggle = (key: Toggle, title: string, note?: string) => (
    <SwitchRow
      title={title}
      note={note}
      on={prefs[key]}
      onChange={(on) => {
        const patch: Partial<Appearance> = {};
        patch[key] = on;
        onChange(patch);
      }}
    />
  );
  return (
    <Stack>
      <Group>
        <Row title="Abrir">
          <Segmented
            label="Abrir"
            options={[
              { label: "Ao passar o mouse", value: true },
              { label: "Ao clicar", value: false },
            ]}
            value={prefs.hover}
            onChange={(hover) => onChange({ hover })}
          />
        </Row>
        <Reveal shown={prefs.hover}>
          <Row title="Atraso">
            <Segmented label="Atraso" options={delays} value={prefs.delay} onChange={(delay) => onChange({ delay })} />
          </Row>
        </Reveal>
        {toggle("gestures", "Gestos no trackpad", "Dois dedos para baixo no notch abrem, para cima fecham, para os lados trocam a música.")}
        <Row title="Largura" note="Mais largo cabe mais widgets no Início." anchor="size">
          <Segmented label="Largura" options={widths} value={prefs.width} onChange={(width) => onChange({ width })} />
        </Row>
        <Row title="Altura" note="Mais alto mostra mais itens nas listas.">
          <Segmented label="Altura" options={heights} value={prefs.height} onChange={(height) => onChange({ height })} />
        </Row>
        {toggle("allScreens", "Monitores externos", "Desenha um notch no topo de cada tela.")}
      </Group>
      <Stack gap={6}>
        <p className="pl-1 pt-1.5 text-[11px] font-medium leading-[13px]" style={{ color: notch.secondary }}>
          Notch fechado
        </p>
        <Group>
          {toggle("wings", "Indicadores ao lado da câmera", "O que está tocando, avisos e o indicador abaixo.")}
          <Reveal shown={prefs.wings}>
            <Row title="Quando nada acontece">
              <Segmented label="Quando nada acontece" options={idles} value={prefs.idle} onChange={(idle) => onChange({ idle })} />
            </Row>
          </Reveal>
          <Reveal shown={prefs.wings}>{toggle("power", "Carregador e bateria", "Ao ligar ou tirar da tomada, com a carga completa e com bateria fraca.")}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("headphones", "Fones", "AirPods e outros fones sem fio conectando.")}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("track", "Música nova", "O nome da faixa por um instante quando ela troca.")}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("meeting", "Próxima reunião", "Dez minutos antes de um evento do Calendário.")}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("agents", "Claude Code", "Quando uma sessão termina e fica esperando você.")}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("hideInFullscreen", "Esconder em tela cheia", "Durante um vídeo ou apresentação, o notch fica só preto.")}</Reveal>
          {toggle(
            "mediaKeys",
            "Volume e brilho no notch",
            "As teclas de volume e brilho mostram o nível aqui, no lugar do aviso do macOS. Precisa da permissão de Acessibilidade.",
          )}
        </Group>
      </Stack>
    </Stack>
  );
}

/** One screen's row in Telas: its glyph, name and how it's driven, the pill, the figure. */
function DisplayRow({ icon: Icon, name, note, value, gliding, onChange }: { icon: LucideIcon; name: string; note: string; value: number; gliding: boolean; onChange: (value: number) => void }) {
  return (
    <div className="flex min-h-12 items-center gap-3 px-3">
      <Icon size={16} strokeWidth={1.7} className="w-[18px] shrink-0" style={{ color: notch.secondary }} aria-hidden />
      <div className="flex min-w-0 flex-1 flex-col gap-px">
        <span className="truncate text-[12px] font-medium leading-[14px]">{name}</span>
        <span className="truncate text-[10px] leading-[12px] tracking-[0.006em]" style={{ color: notch.tertiary }}>
          {note}
        </span>
      </div>
      <span aria-hidden className="w-2 shrink-0" />
      <BrightnessSlider label={`Brilho: ${name}`} value={value} gliding={gliding} onChange={onChange} />
      <span className="w-9 shrink-0 text-right text-[11px] font-semibold tabular-nums" style={{ color: notch.secondary }}>
        {Math.round(value * 100)}%
      </span>
    </div>
  );
}

/** Telas (DisplaySettings): a brightness pill for every screen, the monitor's over the cable. */
export function DisplaysPage({ levels, gliding, onChange }: { levels: Displays; gliding: boolean; onChange: (patch: Partial<Displays>) => void }) {
  return (
    <Stack gap={8}>
      <Group>
        <DisplayRow icon={Laptop} name="Tela do Mac" note="Igual às teclas de brilho" value={levels.builtIn} gliding={gliding} onChange={(builtIn) => onChange({ builtIn })} />
        <DisplayRow icon={Monitor} name="Monitor externo" note="Pelo cabo, direto no monitor" value={levels.external} gliding={gliding} onChange={(external) => onChange({ external })} />
      </Group>
      <p className="px-1 text-[10px] leading-[12px] tracking-[0.006em]" style={{ color: notch.tertiary }}>
        O monitor externo recebe o brilho pelo próprio cabo, como nos botões dele. Se ele não aceitar, o Cleen escurece a imagem.
      </p>
    </Stack>
  );
}

/** A two-step button: the first click arms it in red, the second does it (ConfirmingButton). */
function Confirming({ title, confirm, disabled, onConfirm }: { title: string; confirm: string; disabled: boolean; onConfirm: () => void }) {
  const [armed, setArmed] = useState(false);
  useEffect(() => {
    if (!armed) return;
    const timer = window.setTimeout(() => setArmed(false), 3000);
    return () => window.clearTimeout(timer);
  }, [armed]);
  return (
    <Pill
      kind={armed ? "destructive" : "primary"}
      disabled={disabled}
      onClick={() => {
        if (armed) onConfirm();
        setArmed(!armed);
      }}
    >
      {armed ? confirm : title}
    </Pill>
  );
}

const menuBar = [
  { label: "Ícone", value: "icon" },
  { label: "Disco", value: "disk" },
  { label: "CPU", value: "cpu" },
  { label: "Memória", value: "memory" },
] as const;

/** Geral: GeneralSettings, ClipboardSettings and AlertSettings, one group each. */
export function GeneralPage() {
  const [login, setLogin] = useState(true);
  const [menu, setMenu] = useState<(typeof menuBar)[number]["value"]>("disk");
  const [history, setHistory] = useState(true);
  const [shotOpens, setShotOpens] = useState(true);
  const [shotCopies, setShotCopies] = useState(false);
  const [thumbnail, setThumbnail] = useState(false);
  const [saved, setSaved] = useState(128);
  const [alert, setAlert] = useState(true);
  const [threshold, setThreshold] = useState(10);
  return (
    <Stack>
      <Group>
        <SwitchRow title="Abrir ao iniciar a sessão" on={login} onChange={setLogin} />
        <Row title="Na barra de menus">
          <Segmented label="Na barra de menus" options={menuBar} value={menu} onChange={setMenu} />
        </Row>
        <Row title="Abrir e fechar o notch" note="Funciona em qualquer app.">
          <Keycap>⌃ ⌥ C</Keycap>
        </Row>
        <Row title="Buscar" note="Apps, janelas, emoji, cores e cálculos, de qualquer app.">
          <Keycap>⌥ Espaço</Keycap>
        </Row>
      </Group>
      <Group>
        <SwitchRow title="Histórico da área de transferência" note="Guarda as últimas 300 cópias neste Mac. Senhas de gerenciadores ficam de fora." on={history} onChange={setHistory} />
        <SwitchRow title="Abrir o notch ao tirar um screenshot" note="Com opções para copiar, compartilhar, enviar por AirDrop ou excluir." on={shotOpens} onChange={setShotOpens} />
        <SwitchRow title="Copiar o screenshot ao tirar" note="Vai direto para a área de transferência, pronto para colar." on={shotCopies} onChange={setShotCopies} />
        <SwitchRow title="Usar também a miniatura do macOS" note="O Cleen a substitui. Ligada, o arquivo só é salvo quando ela some, e o Cleen abre com atraso." on={thumbnail} onChange={setThumbnail} />
        <Row title="Apagar histórico" note={saved === 1 ? "1 item guardado" : `${saved} itens guardados`}>
          <Confirming title="Apagar" confirm="Confirmar" disabled={saved === 0} onConfirm={() => setSaved(0)} />
        </Row>
      </Group>
      <Group>
        <SwitchRow title="Avisar quando o disco estiver quase cheio" note="No máximo duas vezes por dia." on={alert} onChange={setAlert} />
        <Row title="Avisar abaixo de">
          <Stepper label="Avisar abaixo de" choices={range(2, 100, 1)} value={threshold} onChange={setThreshold} format={(value) => `${value} GB`} disabled={!alert} />
        </Row>
      </Group>
    </Stack>
  );
}

function range(from: number, to: number, step: number): number[] {
  return Array.from({ length: Math.floor((to - from) / step) + 1 }, (_, index) => from + index * step);
}

/** Every tool in the app's order, and whether it starts in the bar (NotchTab). */
const allTabs: { title: string; icon: LucideIcon; shown: boolean }[] = [
  { title: "Início", icon: LayoutGrid, shown: true },
  { title: "Calendário", icon: Calendar, shown: true },
  { title: "Shelf", icon: Inbox, shown: true },
  { title: "Área de transferência", icon: Clipboard, shown: true },
  { title: "Screenshots", icon: Camera, shown: true },
  { title: "Uso de IA", icon: ChartColumn, shown: true },
  { title: "Timer", icon: Timer, shown: false },
  { title: "Notas", icon: NotebookText, shown: false },
  { title: "Lembretes", icon: ListChecks, shown: false },
  { title: "Conversor", icon: ArrowLeftRight, shown: false },
  { title: "Emoji", icon: Smile, shown: false },
  { title: "Tempo", icon: CloudSun, shown: false },
  { title: "Atalhos", icon: Layers, shown: false },
  { title: "Agentes", icon: Asterisk, shown: true },
  { title: "Ícones", icon: Grid3x3, shown: false },
  { title: "Ações", icon: ChartLine, shown: false },
  { title: "Teleprompter", icon: TextAlignCenter, shown: false },
  { title: "Perguntar", icon: MessagesSquare, shown: false },
  { title: "Visão geral", icon: HardDrive, shown: true },
  { title: "Limpeza", icon: Trash2, shown: true },
  { title: "Projetos", icon: Code, shown: true },
  { title: "Arquivos grandes", icon: File, shown: true },
  { title: "Duplicados", icon: Copy, shown: true },
  { title: "Mapa do disco", icon: ChartPie, shown: true },
  { title: "Desinstalar apps", icon: AppWindow, shown: true },
  { title: "Restos de apps", icon: Puzzle, shown: true },
  { title: "Sistema", icon: ChartNoAxesColumn, shown: true },
  { title: "Inicialização", icon: Power, shown: true },
  { title: "Manutenção", icon: Wrench, shown: true },
];

const defaultShown = allTabs.map((tab) => tab.shown);

/** Abas (TabSettings): every tool with its switch and drag handle, in one card. */
export function TabsPage() {
  const [shown, setShown] = useState(defaultShown);
  const count = shown.filter(Boolean).length;
  return (
    <Stack gap={8}>
      <div className="overflow-hidden rounded-[12px]" style={card}>
        {allTabs.map(({ title, icon: Icon }, index) => (
          <div key={title} className="flex h-8 items-center gap-2.5 px-3">
            <Menu size={11} strokeWidth={2} className="shrink-0" style={{ color: notch.tertiary }} aria-hidden />
            <Icon size={13} strokeWidth={1.9} className="w-[18px] shrink-0" style={{ color: notch.secondary }} aria-hidden />
            <span className="flex-1 truncate text-[12px] font-medium leading-[14px]">{title}</span>
            <Switch
              label={title}
              on={shown[index] ?? false}
              disabled={(shown[index] ?? false) && count === 1}
              onChange={(on) => setShown((current) => current.map((value, at) => (at === index ? on : value)))}
            />
          </div>
        ))}
      </div>
      <div className="flex items-center justify-between">
        <span className="text-[10px] leading-[12px] tracking-[0.006em]" style={{ color: notch.tertiary }}>
          Arraste para mudar a ordem.
        </span>
        <Pill kind="secondary" onClick={() => setShown(defaultShown)}>
          Restaurar padrão
        </Pill>
      </div>
    </Stack>
  );
}

/** From 30 in weeks, clamped to 7…365 like NotchStepper(step: 7). */
const staleDays = [7, ...range(9, 359, 7), 365];

const fileSizes = [25, 50, 100, 250, 500, 1000] as const;

/** Limpeza (CleaningSettings): when a project counts as idle, a file as large, and where to look. */
export function CleaningPage() {
  const [stale, setStale] = useState(30);
  const [large, setLarge] = useState<number>(50);
  const [extra, setExtra] = useState<string[]>([]);
  return (
    <Stack>
      <Group>
        <Row title="Projeto parado depois de" note="Dependências desses projetos já vêm marcadas.">
          <Stepper label="Projeto parado depois de" choices={staleDays} value={stale} onChange={setStale} format={(value) => `${value} dias`} />
        </Row>
        <Row title="Arquivo grande a partir de">
          <Stepper label="Arquivo grande a partir de" choices={fileSizes} value={large} onChange={setLarge} format={(value) => (value >= 1000 ? `${value / 1000} GB` : `${value} MB`)} minWidth={60} />
        </Row>
      </Group>
      <Caps>Pastas de projetos</Caps>
      <Group>
        {["~/Projects", "~/Developer"].map((root) => (
          <Row key={root} title={root}>
            <span className="text-[10px]" style={{ color: notch.tertiary }}>
              Padrão
            </span>
          </Row>
        ))}
        {extra.map((root) => (
          <Row key={root} title={root}>
            <GlyphButton icon={CircleMinus} label="Remover" onClick={() => setExtra((current) => current.filter((item) => item !== root))} />
          </Row>
        ))}
        <Row title="Adicionar pasta…">
          <GlyphButton icon={CirclePlus} label="Adicionar pasta" onClick={() => setExtra((current) => (current.includes("~/Code") ? current : [...current, "~/Code"]))} />
        </Row>
      </Group>
    </Stack>
  );
}

/** Claude Code (ClaudeCodeSettings): the opt-in hook that brings permission requests to the notch. */
export function AgentsPage() {
  const [installed, setInstalled] = useState(false);
  return (
    <Stack gap={8}>
      <Group>
        <Row
          title="Aprovar permissões pelo notch"
          note="Quando o Claude Code pedir permissão, o pedido aparece no notch. Com o Cleen fechado, ele pergunta no terminal, como sempre."
        >
          <Pill kind={installed ? "secondary" : "primary"} onClick={() => setInstalled(!installed)}>
            {installed ? "Remover" : "Instalar"}
          </Pill>
        </Row>
        <Row title="Ajustes do Claude Code" note="~/.claude/settings.json">
          <GlyphButton icon={Folder} label="Mostrar no Finder" />
        </Row>
      </Group>
      <p
        aria-live="polite"
        className="flex items-start gap-1.5 px-1 text-[10.5px] leading-[13px] transition-opacity duration-200"
        style={{ color: notch.secondary, opacity: installed ? 1 : 0 }}
      >
        <CircleCheck size={12} strokeWidth={2.2} className="shrink-0" style={{ color: notch.good }} aria-hidden />
        {installed ? "Ligado. O original ficou guardado em settings.json.cleen-backup." : ""}
      </p>
    </Stack>
  );
}

/** Sobre: PermissionSettings, then the version, updates and what Cleen has freed (AboutSettings). */
export function AboutPage() {
  const [automatic, setAutomatic] = useState(true);
  const [checked, setChecked] = useState(false);
  const granted = (
    <span className="flex items-center gap-1 text-[11px] font-medium" style={{ color: notch.good }}>
      <CircleCheck size={12} strokeWidth={2.2} aria-hidden /> Concedido
    </span>
  );
  return (
    <Stack>
      <Group>
        <Row title="Acesso Total ao Disco" note="Para ver Lixeira, Mail, Safari e containers de outros apps.">
          {granted}
        </Row>
        <Row title="Calendário" note="Para os eventos no Início e no Calendário.">
          {granted}
        </Row>
        <Row title="Lembretes" note="Para os lembretes no Início.">
          <Pill>Permitir</Pill>
        </Row>
      </Group>
      <Group>
        <Row title="Versão" note={checked ? "Esta é a versão mais nova." : undefined}>
          <span className="flex items-center gap-2">
            <span className="text-[11px] font-medium tabular-nums" style={{ color: notch.secondary }}>
              {site.version}
            </span>
            <Pill kind="secondary" onClick={() => setChecked(true)}>
              Procurar agora
            </Pill>
          </span>
        </Row>
        <SwitchRow title="Atualizar sozinho" note="Procura uma versão nova a cada seis horas." on={automatic} onChange={setAutomatic} />
        <Row title="Liberado pelo Cleen">
          <span className="text-[11px] font-semibold tabular-nums">48,6 GB</span>
        </Row>
        <Row title="Privacidade" note="Nada sai do seu Mac. Seus arquivos sempre vão para o Lixo; só caches que se recriam são apagados de vez." />
      </Group>
      <div className="flex justify-end">
        <Pill kind="secondary">Sair do Cleen</Pill>
      </div>
    </Stack>
  );
}

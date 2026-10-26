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
import { useL } from "@/components/LangProvider";
import { pick, type Lang } from "@/lib/lang";
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

function delays(lang: Lang) {
  const l = pick(lang);
  return [
    { label: l("Nenhum", "None"), value: 0 },
    { label: l("Curto", "Short"), value: 0.12 },
    { label: l("Médio", "Medium"), value: 0.3 },
    { label: l("Longo", "Long"), value: 0.6 },
  ] as const;
}

function idles(lang: Lang): { label: string; value: Idle }[] {
  const l = pick(lang);
  return [
    { label: l("Disco", "Disk"), value: "disk" },
    { label: l("Bateria", "Battery"), value: "battery" },
    { label: "CPU", value: "cpu" },
    { label: l("Nada", "Nothing"), value: "none" },
  ];
}

/** The on/off settings of Aparência. */
type Toggle = { [K in keyof Appearance]: Appearance[K] extends boolean ? K : never }[keyof Appearance];

/** Aparência: NotchAppearanceSettings, then "Notch fechado" (ClosedNotchSettings). */
export function AppearancePage({ prefs, onChange }: { prefs: Appearance; onChange: (patch: Partial<Appearance>) => void }) {
  const l = useL();
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
        <Row title={l("Abrir", "Open")}>
          <Segmented
            label={l("Abrir", "Open")}
            options={[
              { label: l("Ao passar o mouse", "On hover"), value: true },
              { label: l("Ao clicar", "On click"), value: false },
            ]}
            value={prefs.hover}
            onChange={(hover) => onChange({ hover })}
          />
        </Row>
        <Reveal shown={prefs.hover}>
          <Row title={l("Atraso", "Delay")}>
            <Segmented label={l("Atraso", "Delay")} options={delays(l.lang)} value={prefs.delay} onChange={(delay) => onChange({ delay })} />
          </Row>
        </Reveal>
        {toggle("gestures", l("Gestos no trackpad", "Trackpad gestures"), l("Dois dedos para baixo no notch abrem, para cima fecham, para os lados trocam a música.", "Two fingers down on the notch open it, up closes it, sideways changes the song."))}
        <Row title={l("Largura", "Width")} note={l("Mais largo cabe mais widgets no Início.", "Wider fits more widgets on Home.")} anchor="size">
          <Segmented label={l("Largura", "Width")} options={widths(l.lang)} value={prefs.width} onChange={(width) => onChange({ width })} />
        </Row>
        <Row title={l("Altura", "Height")} note={l("Mais alto mostra mais itens nas listas.", "Taller shows more items in lists.")}>
          <Segmented label={l("Altura", "Height")} options={heights(l.lang)} value={prefs.height} onChange={(height) => onChange({ height })} />
        </Row>
        {toggle("allScreens", l("Monitores externos", "External displays"), l("Desenha um notch no topo de cada tela.", "Draws a notch at the top of every screen."))}
      </Group>
      <Stack gap={6}>
        <p className="pl-1 pt-1.5 text-[11px] font-medium leading-[13px]" style={{ color: notch.secondary }}>
          {l("Notch fechado", "Closed notch")}
        </p>
        <Group>
          {toggle("wings", l("Indicadores ao lado da câmera", "Indicators beside the camera"), l("O que está tocando, avisos e o indicador abaixo.", "What's playing, alerts, and the indicator below."))}
          <Reveal shown={prefs.wings}>
            <Row title={l("Quando nada acontece", "When nothing's happening")}>
              <Segmented label={l("Quando nada acontece", "When nothing's happening")} options={idles(l.lang)} value={prefs.idle} onChange={(idle) => onChange({ idle })} />
            </Row>
          </Reveal>
          <Reveal shown={prefs.wings}>{toggle("power", l("Carregador e bateria", "Charger and battery"), l("Ao ligar ou tirar da tomada, com a carga completa e com bateria fraca.", "When plugged in or unplugged, fully charged, and when the battery is low."))}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("headphones", l("Fones", "Headphones"), l("AirPods e outros fones sem fio conectando.", "AirPods and other wireless headphones connecting."))}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("track", l("Música nova", "New song"), l("O nome da faixa por um instante quando ela troca.", "The track's name for a moment when it changes."))}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("meeting", l("Próxima reunião", "Next meeting"), l("Dez minutos antes de um evento do Calendário.", "Ten minutes before a Calendar event."))}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("agents", "Claude Code", l("Quando uma sessão termina e fica esperando você.", "When a session finishes and waits for you."))}</Reveal>
          <Reveal shown={prefs.wings}>{toggle("hideInFullscreen", l("Esconder em tela cheia", "Hide in full screen"), l("Durante um vídeo ou apresentação, o notch fica só preto.", "During a video or presentation, the notch stays plain black."))}</Reveal>
          {toggle(
            "mediaKeys",
            l("Volume e brilho no notch", "Volume and brightness in the notch"),
            l(
              "As teclas de volume e brilho mostram o nível aqui, no lugar do aviso do macOS. Precisa da permissão de Acessibilidade.",
              "The volume and brightness keys show the level here instead of the macOS overlay. Needs Accessibility permission.",
            ),
          )}
        </Group>
      </Stack>
    </Stack>
  );
}

/** One screen's row in Telas: its glyph, name and how it's driven, the pill, the figure. */
function DisplayRow({ icon: Icon, name, note, value, gliding, onChange }: { icon: LucideIcon; name: string; note: string; value: number; gliding: boolean; onChange: (value: number) => void }) {
  const l = useL();
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
      <BrightnessSlider label={`${l("Brilho", "Brightness")}: ${name}`} value={value} gliding={gliding} onChange={onChange} />
      <span className="w-9 shrink-0 text-right text-[11px] font-semibold tabular-nums" style={{ color: notch.secondary }}>
        {Math.round(value * 100)}%
      </span>
    </div>
  );
}

/** Telas (DisplaySettings): a brightness pill for every screen, the monitor's over the cable. */
export function DisplaysPage({ levels, gliding, onChange }: { levels: Displays; gliding: boolean; onChange: (patch: Partial<Displays>) => void }) {
  const l = useL();
  return (
    <Stack gap={8}>
      <Group>
        <DisplayRow icon={Laptop} name={l("Tela do Mac", "Mac display")} note={l("Igual às teclas de brilho", "Same as the brightness keys")} value={levels.builtIn} gliding={gliding} onChange={(builtIn) => onChange({ builtIn })} />
        <DisplayRow icon={Monitor} name={l("Monitor externo", "External monitor")} note={l("Pelo cabo, direto no monitor", "Over the cable, straight to the monitor")} value={levels.external} gliding={gliding} onChange={(external) => onChange({ external })} />
      </Group>
      <p className="px-1 text-[10px] leading-[12px] tracking-[0.006em]" style={{ color: notch.tertiary }}>
        {l(
          "O monitor externo recebe o brilho pelo próprio cabo, como nos botões dele. Se ele não aceitar, o Cleen escurece a imagem.",
          "The external monitor gets its brightness over the cable itself, just like its own buttons. If it doesn't accept it, Cleen dims the picture.",
        )}
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

type MenuBarItem = "icon" | "disk" | "cpu" | "memory";

function menuBar(lang: Lang): { label: string; value: MenuBarItem }[] {
  const l = pick(lang);
  return [
    { label: l("Ícone", "Icon"), value: "icon" },
    { label: l("Disco", "Disk"), value: "disk" },
    { label: "CPU", value: "cpu" },
    { label: l("Memória", "Memory"), value: "memory" },
  ];
}

/** Geral: GeneralSettings, ClipboardSettings and AlertSettings, one group each. */
export function GeneralPage() {
  const l = useL();
  const [login, setLogin] = useState(true);
  const [menu, setMenu] = useState<MenuBarItem>("disk");
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
        <SwitchRow title={l("Abrir ao iniciar a sessão", "Open at login")} on={login} onChange={setLogin} />
        <Row title={l("Na barra de menus", "In the menu bar")}>
          <Segmented label={l("Na barra de menus", "In the menu bar")} options={menuBar(l.lang)} value={menu} onChange={setMenu} />
        </Row>
        <Row title={l("Abrir e fechar o notch", "Open and close the notch")} note={l("Funciona em qualquer app.", "Works in any app.")}>
          <Keycap>⌃ ⌥ C</Keycap>
        </Row>
        <Row title={l("Buscar", "Search")} note={l("Apps, janelas, emoji, cores e cálculos, de qualquer app.", "Apps, windows, emoji, colors and math, from any app.")}>
          <Keycap>{l("⌥ Espaço", "⌥ Space")}</Keycap>
        </Row>
      </Group>
      <Group>
        <SwitchRow
          title={l("Histórico da área de transferência", "Clipboard history")}
          note={l("Guarda as últimas 300 cópias neste Mac. Senhas de gerenciadores ficam de fora.", "Keeps the last 300 copies on this Mac. Passwords from password managers are left out.")}
          on={history} onChange={setHistory} />
        <SwitchRow
          title={l("Abrir o notch ao tirar um screenshot", "Open the notch when you take a screenshot")}
          note={l("Com opções para copiar, compartilhar, enviar por AirDrop ou excluir.", "With options to copy, share, AirDrop, or delete.")}
          on={shotOpens} onChange={setShotOpens} />
        <SwitchRow
          title={l("Copiar o screenshot ao tirar", "Copy the screenshot when taken")}
          note={l("Vai direto para a área de transferência, pronto para colar.", "Goes straight to the clipboard, ready to paste.")}
          on={shotCopies} onChange={setShotCopies} />
        <SwitchRow
          title={l("Usar também a miniatura do macOS", "Also use the macOS thumbnail")}
          note={l("O Cleen a substitui. Ligada, o arquivo só é salvo quando ela some, e o Cleen abre com atraso.", "Cleen replaces it. When it's on, the file is only saved once it fades, and Cleen opens late.")}
          on={thumbnail} onChange={setThumbnail} />
        <Row title={l("Apagar histórico", "Clear History")} note={saved === 1 ? l("1 item guardado", "1 item saved") : l(`${saved} itens guardados`, `${saved} items saved`)}>
          <Confirming title={l("Apagar", "Delete")} confirm={l("Confirmar", "Confirm")} disabled={saved === 0} onConfirm={() => setSaved(0)} />
        </Row>
      </Group>
      <Group>
        <SwitchRow title={l("Avisar quando o disco estiver quase cheio", "Notify when the disk is almost full")} note={l("No máximo duas vezes por dia.", "At most twice a day.")} on={alert} onChange={setAlert} />
        <Row title={l("Avisar abaixo de", "Notify below")}>
          <Stepper label={l("Avisar abaixo de", "Notify below")} choices={range(2, 100, 1)} value={threshold} onChange={setThreshold} format={(value) => `${value} GB`} disabled={!alert} />
        </Row>
      </Group>
    </Stack>
  );
}

function range(from: number, to: number, step: number): number[] {
  return Array.from({ length: Math.floor((to - from) / step) + 1 }, (_, index) => from + index * step);
}

/** Every tool in the app's order, and whether it starts in the bar (NotchTab). */
function allTabs(lang: Lang): { title: string; icon: LucideIcon; shown: boolean }[] {
  const l = pick(lang);
  return [
    { title: l("Início", "Home"), icon: LayoutGrid, shown: true },
    { title: l("Calendário", "Calendar"), icon: Calendar, shown: true },
    { title: "Shelf", icon: Inbox, shown: true },
    { title: l("Área de transferência", "Clipboard"), icon: Clipboard, shown: true },
    { title: "Screenshots", icon: Camera, shown: true },
    { title: l("Uso de IA", "AI Usage"), icon: ChartColumn, shown: true },
    { title: "Timer", icon: Timer, shown: false },
    { title: l("Notas", "Notes"), icon: NotebookText, shown: false },
    { title: l("Lembretes", "Reminders"), icon: ListChecks, shown: false },
    { title: l("Conversor", "Converter"), icon: ArrowLeftRight, shown: false },
    { title: "Emoji", icon: Smile, shown: false },
    { title: l("Tempo", "Weather"), icon: CloudSun, shown: false },
    { title: l("Atalhos", "Shortcuts"), icon: Layers, shown: false },
    { title: l("Agentes", "Agents"), icon: Asterisk, shown: true },
    { title: l("Ícones", "Icons"), icon: Grid3x3, shown: false },
    { title: l("Ações", "Stocks"), icon: ChartLine, shown: false },
    { title: "Teleprompter", icon: TextAlignCenter, shown: false },
    { title: l("Perguntar", "Ask"), icon: MessagesSquare, shown: false },
    { title: l("Visão geral", "Overview"), icon: HardDrive, shown: true },
    { title: l("Limpeza", "Cleanup"), icon: Trash2, shown: true },
    { title: l("Projetos", "Projects"), icon: Code, shown: true },
    { title: l("Arquivos grandes", "Large Files"), icon: File, shown: true },
    { title: l("Duplicados", "Duplicates"), icon: Copy, shown: true },
    { title: l("Mapa do disco", "Disk Map"), icon: ChartPie, shown: true },
    { title: l("Desinstalar apps", "Uninstall Apps"), icon: AppWindow, shown: true },
    { title: l("Restos de apps", "App Leftovers"), icon: Puzzle, shown: true },
    { title: l("Sistema", "System"), icon: ChartNoAxesColumn, shown: true },
    { title: l("Inicialização", "Startup"), icon: Power, shown: true },
    { title: l("Manutenção", "Maintenance"), icon: Wrench, shown: true },
  ];
}

const defaultShown = allTabs("pt").map((tab) => tab.shown);

/** Abas (TabSettings): every tool with its switch and drag handle, in one card. */
export function TabsPage() {
  const l = useL();
  const [shown, setShown] = useState(defaultShown);
  const count = shown.filter(Boolean).length;
  return (
    <Stack gap={8}>
      <div className="overflow-hidden rounded-[12px]" style={card}>
        {allTabs(l.lang).map(({ title, icon: Icon }, index) => (
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
          {l("Arraste para mudar a ordem.", "Drag to reorder.")}
        </span>
        <Pill kind="secondary" onClick={() => setShown(defaultShown)}>
          {l("Restaurar padrão", "Restore Defaults")}
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
  const l = useL();
  const [stale, setStale] = useState(30);
  const [large, setLarge] = useState<number>(50);
  const [extra, setExtra] = useState<string[]>([]);
  return (
    <Stack>
      <Group>
        <Row title={l("Projeto parado depois de", "Project idle after")} note={l("Dependências desses projetos já vêm marcadas.", "These projects' dependencies come selected.")}>
          <Stepper label={l("Projeto parado depois de", "Project idle after")} choices={staleDays} value={stale} onChange={setStale} format={(value) => l(`${value} dias`, `${value} days`)} />
        </Row>
        <Row title={l("Arquivo grande a partir de", "Large file from")}>
          <Stepper label={l("Arquivo grande a partir de", "Large file from")} choices={fileSizes} value={large} onChange={setLarge} format={(value) => (value >= 1000 ? `${value / 1000} GB` : `${value} MB`)} minWidth={60} />
        </Row>
      </Group>
      <Caps>{l("Pastas de projetos", "Project folders")}</Caps>
      <Group>
        {["~/Projects", "~/Developer"].map((root) => (
          <Row key={root} title={root}>
            <span className="text-[10px]" style={{ color: notch.tertiary }}>
              {l("Padrão", "Default")}
            </span>
          </Row>
        ))}
        {extra.map((root) => (
          <Row key={root} title={root}>
            <GlyphButton icon={CircleMinus} label={l("Remover", "Remove")} onClick={() => setExtra((current) => current.filter((item) => item !== root))} />
          </Row>
        ))}
        <Row title={l("Adicionar pasta…", "Add Folder…")}>
          <GlyphButton icon={CirclePlus} label={l("Adicionar pasta", "Add folder")} onClick={() => setExtra((current) => (current.includes("~/Code") ? current : [...current, "~/Code"]))} />
        </Row>
      </Group>
    </Stack>
  );
}

/** Claude Code (ClaudeCodeSettings): the opt-in hook that brings permission requests to the notch. */
export function AgentsPage() {
  const l = useL();
  const [installed, setInstalled] = useState(false);
  return (
    <Stack gap={8}>
      <Group>
        <Row
          title={l("Aprovar permissões pelo notch", "Approve permissions from the notch")}
          note={l(
            "Quando o Claude Code pedir permissão, o pedido aparece no notch. Com o Cleen fechado, ele pergunta no terminal, como sempre.",
            "When Claude Code asks for permission, the request shows up in the notch. With Cleen closed, it asks in the terminal as usual.",
          )}
        >
          <Pill kind={installed ? "secondary" : "primary"} onClick={() => setInstalled(!installed)}>
            {installed ? l("Remover", "Remove") : l("Instalar", "Install")}
          </Pill>
        </Row>
        <Row title={l("Ajustes do Claude Code", "Claude Code settings")} note="~/.claude/settings.json">
          <GlyphButton icon={Folder} label={l("Mostrar no Finder", "Show in Finder")} />
        </Row>
      </Group>
      <p
        aria-live="polite"
        className="flex items-start gap-1.5 px-1 text-[10.5px] leading-[13px] transition-opacity duration-200"
        style={{ color: notch.secondary, opacity: installed ? 1 : 0 }}
      >
        <CircleCheck size={12} strokeWidth={2.2} className="shrink-0" style={{ color: notch.good }} aria-hidden />
        {installed ? l("Ligado. O original ficou guardado em settings.json.cleen-backup.", "On. The original is saved as settings.json.cleen-backup.") : ""}
      </p>
    </Stack>
  );
}

/** Sobre: PermissionSettings, then the version, updates and what Cleen has freed (AboutSettings). */
export function AboutPage() {
  const l = useL();
  const [automatic, setAutomatic] = useState(true);
  const [checked, setChecked] = useState(false);
  const granted = (
    <span className="flex items-center gap-1 text-[11px] font-medium" style={{ color: notch.good }}>
      <CircleCheck size={12} strokeWidth={2.2} aria-hidden /> {l("Concedido", "Granted")}
    </span>
  );
  return (
    <Stack>
      <Group>
        <Row title={l("Acesso Total ao Disco", "Full Disk Access")} note={l("Para ver Lixeira, Mail, Safari e containers de outros apps.", "To see the Trash, Mail, Safari, and other apps' containers.")}>
          {granted}
        </Row>
        <Row title={l("Calendário", "Calendar")} note={l("Para os eventos no Início e no Calendário.", "For the events on Home and in Calendar.")}>
          {granted}
        </Row>
        <Row title={l("Lembretes", "Reminders")} note={l("Para os lembretes no Início.", "For the reminders on Home.")}>
          <Pill>{l("Permitir", "Allow")}</Pill>
        </Row>
      </Group>
      <Group>
        <Row title={l("Versão", "Version")} note={checked ? l("Esta é a versão mais nova.", "This is the latest version.") : undefined}>
          <span className="flex items-center gap-2">
            <span className="text-[11px] font-medium tabular-nums" style={{ color: notch.secondary }}>
              {site.version}
            </span>
            <Pill kind="secondary" onClick={() => setChecked(true)}>
              {l("Procurar agora", "Check Now")}
            </Pill>
          </span>
        </Row>
        <SwitchRow title={l("Atualizar sozinho", "Update automatically")} note={l("Procura uma versão nova a cada seis horas.", "Checks for a new version every six hours.")} on={automatic} onChange={setAutomatic} />
        <Row title={l("Liberado pelo Cleen", "Freed by Cleen")}>
          <span className="text-[11px] font-semibold tabular-nums">{l("48,6 GB", "48.6 GB")}</span>
        </Row>
        <Row
          title={l("Privacidade", "Privacy")}
          note={l(
            "Nada sai do seu Mac. Seus arquivos sempre vão para o Lixo; só caches que se recriam são apagados de vez.",
            "Nothing leaves your Mac. Your files always go to the Trash; only caches that rebuild themselves are deleted for good.",
          )}
        />
      </Group>
      <div className="flex justify-end">
        <Pill kind="secondary">{l("Sair do Cleen", "Quit Cleen")}</Pill>
      </div>
    </Stack>
  );
}

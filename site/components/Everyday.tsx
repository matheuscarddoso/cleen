"use client";

import { ChevronDown, ChevronUp, ClipboardList, FileText, Link2, Pause, Play, RefreshCw, RotateCcw } from "lucide-react";
import { useEffect, useRef, useState, type ComponentType, type ReactNode, type SVGProps } from "react";
import { Camera, Inbox, NotebookPen, Pin, ScrollText, Search, Send, Settings, Timer } from "./Icons";
import { Shoulders, Swap } from "./Notch";
import { Wallpaper } from "./Wallpaper";
import { useSeconds } from "./useLoop";

/** How long each feature plays before the next one takes over. */
const SHOW_MS = 6500;

type Feature = {
  key: string;
  title: string;
  text: string;
  icon: ComponentType<SVGProps<SVGSVGElement>>;
  gradient: string;
};

const features: Feature[] = [
  { key: "teleprompter", title: "Teleprompter", text: "O roteiro rola sob a câmera, e um arco de luz atrás do texto segue a sua voz.", icon: ScrollText, gradient: "linear-gradient(180deg,#ffb340,#ff7a00)" },
  { key: "clipboard", title: "Histórico", text: "Tudo o que você copiou, com os fixados na frente. ⌘1 a ⌘9 colam direto.", icon: ClipboardList, gradient: "linear-gradient(180deg,#7d7aff,#5856d6)" },
  { key: "timer", title: "Timers", text: "Pomodoro ou timer simples, contando no notch fechado.", icon: Timer, gradient: "linear-gradient(180deg,#ff6961,#d70015)" },
  { key: "shelf", title: "Shelf", text: "Solte arquivos no notch e mande por AirDrop num gesto.", icon: Inbox, gradient: "linear-gradient(180deg,#5ac8fa,#0a7aff)" },
  { key: "notes", title: "Notas", text: "Listas e tarefas em Markdown, sincronizadas com o Obsidian ou o app Notas.", icon: NotebookPen, gradient: "linear-gradient(180deg,#ffd60a,#ff9f0a)" },
  { key: "mirror", title: "Espelho", text: "Uma olhada na câmera antes da chamada, sem abrir app.", icon: Camera, gradient: "linear-gradient(180deg,#8e8e93,#48484a)" },
];

/**
 * Apple's "watch" switcher: the scene on top shows one feature at a time; below, each
 * feature with its button and a bar that fills while it's on, then hands over to the next.
 * It only advances on screen, with the tab visible, and never with reduced motion.
 */
export function Everyday() {
  const ref = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const [running, setRunning] = useState(false);
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    let visible = false;
    const update = () => {
      setReduced(motion.matches);
      setRunning(visible && !motion.matches && document.visibilityState === "visible");
    };
    const observer = new IntersectionObserver(([entry]) => {
      visible = entry?.isIntersecting ?? false;
      update();
    }, { threshold: 0.4 });
    observer.observe(element);
    motion.addEventListener("change", update);
    document.addEventListener("visibilitychange", update);
    return () => {
      observer.disconnect();
      motion.removeEventListener("change", update);
      document.removeEventListener("visibilitychange", update);
    };
  }, []);

  const next = () => setIndex((current) => (current + 1) % features.length);

  return (
    <div ref={ref}>
      <Stage>
        <Swap shown={index === 0}><Teleprompter playing={running && index === 0} /></Swap>
        <Swap shown={index === 1}><Clipboard key={index === 1 ? "on" : "off"} playing={running && index === 1} /></Swap>
        <Swap shown={index === 2}><TimerScene counting={running && index === 2} /></Swap>
        <Swap shown={index === 3}><Shelf key={index === 3 ? "on" : "off"} /></Swap>
        <Swap shown={index === 4}><Notes key={index === 4 ? "on" : "off"} playing={running && index === 4} /></Swap>
        <Swap shown={index === 5}><Mirror /></Swap>
      </Stage>

      <div className="mx-auto mt-10 grid max-w-[1180px] grid-cols-2 gap-x-6 gap-y-10 sm:grid-cols-3 lg:grid-cols-6">
        {features.map((feature, position) => {
          const Icon = feature.icon;
          const active = position === index;
          return (
            <div key={feature.key} className="flex h-full flex-col items-center text-center">
              <span
                aria-hidden
                className="flex h-14 w-14 items-center justify-center rounded-[14px] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_4px_10px_rgba(0,0,0,0.12)]"
                style={{ background: feature.gradient }}
              >
                <Icon className="h-7 w-7" strokeWidth={1.75} />
              </span>
              <h3 className="mt-3 text-[21px] font-semibold leading-[1.19] tracking-[0.011em]">{feature.title}</h3>
              <p className="mt-1 max-w-[230px] flex-1 text-balance text-[17px] leading-[1.47] text-mute">{feature.text}</p>
              <button
                type="button"
                onClick={() => setIndex(position)}
                aria-pressed={active}
                className={`mt-4 rounded-full px-4 py-2 text-[17px] leading-[1.18] transition-[background-color,color,scale] duration-200 active:scale-[0.96] ${active ? "cursor-default bg-[#e8e8ed] text-ink" : "bg-accent text-white hover:bg-[#0077ed]"}`}
              >
                {active ? "Mostrando" : "Ver"}
              </button>
              <span aria-hidden className="mt-4 h-[3px] w-24 overflow-hidden rounded-full bg-black/10">
                {active && !reduced && (
                  <span
                    key={index}
                    className="block h-full origin-left rounded-full bg-ink"
                    style={{ animation: `progress ${SHOW_MS}ms linear forwards`, animationPlayState: running ? "running" : "paused" }}
                    onAnimationEnd={next}
                  />
                )}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** Design size of the scenes; the stage scales it to whatever width it gets. */
const DESIGN = { width: 960, height: 380 } as const;
/** Below this, the stage zooms into the panel instead of shrinking the whole scene. */
const PANEL_FOCUS = 720;

function Stage({ children }: { children: ReactNode }) {
  const box = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState<number | null>(null);
  useEffect(() => {
    const element = box.current;
    if (!element) return;
    const observer = new ResizeObserver(([entry]) => {
      if (entry) setWidth(entry.contentRect.width);
    });
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  const scale = width === null ? 1 : width / (width < PANEL_FOCUS ? PANEL_FOCUS : DESIGN.width);
  const offset = width === null ? 0 : (width - DESIGN.width * scale) / 2;
  return (
    <div
      ref={box}
      className="relative mx-auto max-w-[1160px] overflow-hidden rounded-[18px]"
      style={width === null ? { aspectRatio: `${DESIGN.width} / ${DESIGN.height}` } : { height: DESIGN.height * scale }}
    >
      <Wallpaper tone="blue" />
      <div aria-hidden className="absolute left-0 top-0 origin-top-left" style={{ width: DESIGN.width, height: DESIGN.height, transform: `translateX(${offset}px) scale(${scale})` }}>
        {children}
      </div>
    </div>
  );
}

/** The open notch: a black panel hanging from the top edge, title and icons on top. */
function Panel({ title, children, height }: { title: string; children: ReactNode; height: number }) {
  return (
    <div className="absolute left-1/2 top-0 w-[680px] -translate-x-1/2 rounded-b-[30px] bg-black px-7 pb-6 pt-4 text-white shadow-[0_24px_60px_rgba(0,0,0,0.45)]" style={{ height }}>
      <Shoulders size={12} />
      <div className="flex items-center justify-between">
        <span className="text-[17px] font-semibold">{title}</span>
        <span className="flex gap-4 text-white/75">
          <Search className="h-4 w-4" />
          <Pin className="h-4 w-4" />
          <Settings className="h-4 w-4" />
        </span>
      </div>
      {children}
    </div>
  );
}

const script =
  "Bom dia, pessoal. Hoje eu quero mostrar três mudanças no checkout. Primeiro, o pagamento agora cabe em uma tela só. Depois, o Pix aparece antes do cartão, que é como a maioria paga. E por último, o recibo chega no e-mail na hora, sem ninguém precisar pedir.";

/**
 * The teleprompter while it reads, as TeleprompterPlayer: header and tab bar gone, the
 * script in a monospaced face gliding up under the lens, pace on the camera's left and
 * the transport on its right, and the arc of light behind the text following the voice.
 */
function Teleprompter({ playing }: { playing: boolean }) {
  return (
    <div className="absolute left-1/2 top-0 h-[300px] w-[680px] -translate-x-1/2 overflow-hidden rounded-b-[30px] bg-black text-white shadow-[0_24px_60px_rgba(0,0,0,0.45)]">
      <VoiceArc speaking={playing} />
      <div className="relative flex h-[38px] items-center justify-between px-5 text-white/60">
        <span className="flex items-center gap-2.5">
          <ChevronDown className="h-4 w-4" strokeWidth={2.2} />
          <span className="text-[13px] font-semibold tabular-nums text-white/55">150 ppm</span>
          <ChevronUp className="h-4 w-4" strokeWidth={2.2} />
        </span>
        <span className="flex items-center gap-4">
          {playing ? <Pause className="h-4 w-4" fill="currentColor" strokeWidth={0} /> : <Play className="h-4 w-4" fill="currentColor" strokeWidth={0} />}
          <RotateCcw className="h-4 w-4" strokeWidth={2.2} />
        </span>
      </div>
      <div className="relative mt-1 h-[244px] overflow-hidden [mask-image:linear-gradient(transparent,black_18%,black_72%,transparent)]">
        <div className="teleprompter-roll px-12 text-center font-mono text-[23px] font-medium leading-[1.5] text-white" style={{ animationPlayState: playing ? "running" : "paused" }}>
          <p className="pb-10">{script}</p>
          <p className="pb-10">{script}</p>
        </div>
      </div>
    </div>
  );
}

/**
 * PrompterArc: a dome rising from the middle of the bottom edge, brightest along its rim.
 * Loudness lifts and brightens it; the voice's pitch leans it violet or cyan. Here a made-
 * up voice drives it, a frame at a time, without re-rendering; silent, it just breathes.
 */
function VoiceArc({ speaking }: { speaking: boolean }) {
  const arc = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const element = arc.current;
    if (!element) return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let frame = 0;
    let level = 0.12;
    const draw = (now: number) => {
      const time = now / 1000;
      const breath = reduced ? 0.12 : 0.1 + 0.05 * Math.sin(time * 1.5);
      // Syllables: a quick wobble inside words, a dip between phrases.
      const voice = speaking && !reduced ? Math.max(0, 0.42 + 0.22 * Math.sin(time * 9.1) * Math.sin(time * 3.7) + 0.14 * Math.sin(time * 1.3)) * (Math.sin(time * 0.9) > -0.6 ? 1 : 0.15) : 0;
      level += (Math.max(voice, breath) - level) * 0.18;
      const radius = Math.min(285, 58 + 92 * level * 1.6);
      const lean = speaking ? Math.sin(time * 0.7) : 0;
      const [from, to, amount] = lean < 0 ? [[61, 107, 255], [122, 92, 255], -lean] : [[61, 107, 255], [51, 199, 255], lean];
      const rim = from.map((channel, i) => Math.round(channel + (to[i]! - channel) * amount)).join(" ");
      element.style.setProperty("--rim", rim);
      element.style.setProperty("--a0", String(0.18 + 0.22 * level));
      element.style.setProperty("--a1", String(0.35 + 0.45 * level));
      element.style.setProperty("--a2", String(0.55 + 0.45 * level));
      element.style.transform = `translate(-50%, 50%) scale(${radius / 150})`;
      if (!reduced) frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frame);
  }, [speaking]);
  return (
    <div
      ref={arc}
      aria-hidden
      className="absolute bottom-0 left-1/2 h-[300px] w-[390px] blur-[6px]"
      style={{
        transform: "translate(-50%, 50%) scale(0.5)",
        background: "radial-gradient(closest-side, rgb(var(--rim, 61 107 255) / var(--a0, 0.2)) 0%, rgb(var(--rim, 61 107 255) / var(--a1, 0.4)) 62%, rgb(var(--rim, 61 107 255) / var(--a2, 0.6)) 80%, transparent 100%)",
      }}
    />
  );
}

function TimerScene({ counting }: { counting: boolean }) {
  const total = 25 * 60;
  const elapsed = useSeconds(counting, false, 7 * 60 + 12);
  const remaining = Math.max(0, total - elapsed);
  const clock = `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")}`;
  const circumference = 2 * Math.PI * 58;
  return (
    <Panel title="Timer" height={250}>
      <div className="mt-6 flex items-center gap-8">
        <span className="relative flex shrink-0 items-center justify-center">
          <Timer className="absolute h-8 w-8 text-white/70" strokeWidth={1.75} />
          <svg viewBox="0 0 132 132" className="h-[132px] w-[132px] -rotate-90">
            <circle cx="66" cy="66" r="58" fill="none" stroke="rgba(255,255,255,0.12)" strokeWidth="8" />
            <circle
              cx="66" cy="66" r="58" fill="none" stroke="#ff453a" strokeWidth="8" strokeLinecap="round"
              strokeDasharray={circumference} strokeDashoffset={circumference * (1 - remaining / total)}
              className="transition-[stroke-dashoffset] duration-1000 ease-linear"
            />
          </svg>
        </span>
        <div className="min-w-0">
          <p className="text-[14px] font-medium text-white/55">Pomodoro · foco 2 de 4</p>
          <p className="text-[68px] font-light leading-none tabular-nums tracking-[-0.02em]">{clock}</p>
          <p className="mt-2 text-[14px] text-white/45">a contagem segue no notch fechado</p>
        </div>
        <div className="ml-auto flex flex-col items-end gap-3 text-[14px] font-medium">
          <span className="flex rounded-full bg-white/10 p-1">
            <span className="rounded-full px-3 py-1 text-white/70">Timer</span>
            <span className="rounded-full bg-white px-3 py-1 text-black">Pomodoro</span>
          </span>
          <span className="flex gap-2">
            <span className="rounded-full bg-white px-4 py-1.5 text-black">Pausar</span>
            <span className="rounded-full bg-white/10 px-4 py-1.5">+1 min</span>
          </span>
        </div>
      </div>
    </Panel>
  );
}

const copies = [
  { kind: "text", from: "Mensagens", age: "agora", body: "Reunião passou para as 14h, sala 3" },
  { kind: "link", from: "Safari", age: "2min", body: "cleen.ocardoso.com" },
  { kind: "image", from: "Screenshot", age: "8min", body: "" },
  { kind: "file", from: "Finder", age: "1h", body: "contrato.pdf" },
  { kind: "code", from: "Terminal", age: "3h", body: "npm run dev -- --port 3000" },
] as const;

/** Holding ⌘ shows each card's number; ⌘2 pastes the second where you were typing. */
const clipboardSteps = [1400, 1300, 500, 2400] as const;

function Clipboard({ playing }: { playing: boolean }) {
  const [step, setStep] = useState(0);
  useEffect(() => {
    if (!playing) return;
    const timer = window.setTimeout(() => setStep((current) => (current + 1) % clipboardSteps.length), clipboardSteps[step]);
    return () => window.clearTimeout(timer);
  }, [playing, step]);
  const holding = step === 1 || step === 2;
  const pasted = step === 3;
  return (
    <Panel title="Área de transferência" height={262}>
      <div className="mt-4 flex items-center gap-2 text-[13px] font-medium">
        <span className="flex h-[30px] w-[200px] items-center gap-2 rounded-[8px] px-2.5 text-white/40 shadow-[inset_0_0_0_1px_rgba(255,255,255,0.18)]">
          <Search className="h-3.5 w-3.5" /> Buscar
        </span>
        <span className="rounded-full bg-white/[0.14] px-3 py-1">Tudo</span>
        <span className="px-2 text-white/55">Texto</span>
        <span className="px-2 text-white/55">Imagens</span>
        <span className="px-2 text-white/55">Links</span>
        <span className="ml-auto text-[12px] text-white/45">{pasted ? "Colado no Mail" : holding ? "Segurando ⌘" : ""}</span>
      </div>
      <div className="mt-3.5 flex gap-2.5">
        {copies.map((copy, position) => {
          const chosen = position === 1 && (step === 2 || pasted);
          return (
            <div
              key={copy.body + copy.kind}
              className={`relative flex h-[132px] w-[112px] shrink-0 flex-col gap-2 rounded-[14px] bg-white/[0.06] p-3 transition-[scale,box-shadow] duration-200 ${chosen ? "scale-[0.96] shadow-[inset_0_0_0_1.5px_rgba(255,255,255,0.55)]" : "shadow-[inset_0_0_0_1px_rgba(255,255,255,0.08)]"}`}
            >
              <span className="truncate text-[11px] font-medium text-white/55">
                {copy.from} · {copy.age}
              </span>
              {copy.kind === "image" ? (
                <span className="h-[62px] rounded-[8px]" style={{ background: "linear-gradient(135deg,#5ac8fa,#5856d6 55%,#ff2d55)" }} />
              ) : copy.kind === "file" ? (
                <span className="flex items-center gap-1.5 text-[13px] font-medium">
                  <FileText className="h-4 w-4 text-[#ff453a]" /> {copy.body}
                </span>
              ) : copy.kind === "link" ? (
                <span className="flex items-start gap-1.5 text-[13px] font-medium text-[#64d2ff]">
                  <Link2 className="mt-0.5 h-3.5 w-3.5 shrink-0" /> <span className="min-w-0 break-all">{copy.body}</span>
                </span>
              ) : (
                <span className={`line-clamp-3 text-[13px] leading-[1.35] ${copy.kind === "code" ? "font-mono text-[12px] text-white/85" : ""}`}>{copy.body}</span>
              )}
              <span
                className={`absolute bottom-2 right-2 rounded-[5px] bg-white/[0.14] px-1.5 py-px text-[11px] font-medium tabular-nums text-white/80 transition-opacity duration-200 ${holding ? "opacity-100" : "opacity-0"}`}
              >
                ⌘{position + 1}
              </span>
            </div>
          );
        })}
      </div>
    </Panel>
  );
}

const files = [
  { name: "contrato.pdf", tag: "PDF", color: "#ff453a" },
  { name: "capa.png", tag: "PNG", color: "#30d158" },
  { name: "assets.zip", tag: "ZIP", color: "#8e8e93" },
  { name: "pitch.key", tag: "KEY", color: "#0a84ff" },
] as const;

function Shelf() {
  return (
    <Panel title="Shelf" height={256}>
      <div className="mt-6 flex items-end gap-5">
        {files.map((file, position) => (
          <div key={file.name} className={`flex w-[104px] flex-col items-center ${position === files.length - 1 ? "shelf-drop" : ""}`}>
            <span className="drop-shadow-[0_6px_10px_rgba(0,0,0,0.45)]">
              <span
                className="relative flex h-[104px] w-[82px] items-end justify-center rounded-[8px] bg-gradient-to-b from-white to-[#e5e5ea] pb-3"
                style={{ clipPath: "polygon(0 0, 72% 0, 100% 22%, 100% 100%, 0 100%)" }}
              >
                <span aria-hidden className="absolute right-0 top-0 h-[23px] w-[23px] rounded-bl-[4px] bg-[#c7c7cc]" style={{ clipPath: "polygon(0 0, 0 100%, 100% 100%)" }} />
                <span className="rounded-[4px] px-1.5 py-0.5 text-[11px] font-medium text-white" style={{ background: file.color }}>
                  {file.tag}
                </span>
              </span>
            </span>
            <span className="mt-2 text-[13px] font-medium text-white/85">{file.name}</span>
          </div>
        ))}
        <div className="ml-auto flex flex-col items-end gap-2 pb-6 text-[14px] font-medium">
          <span className="flex items-center gap-2 rounded-full bg-[#0a84ff] px-4 py-1.5">
            <Send className="h-3.5 w-3.5" /> AirDrop
          </span>
          <span className="whitespace-nowrap rounded-full bg-white/10 px-4 py-1.5">Selecionar tudo</span>
        </div>
      </div>
    </Panel>
  );
}

/** The new item typed in, letter by letter, then the pending one ticked. */
const NOTE_TYPED = "café em grão";

/**
 * Notas as Obsidian's Live Preview shows it: the line being typed shows its Markdown,
 * dimmed; once the cursor leaves it, it renders as a checkbox, and the note is in the
 * vault's Cleen folder as a .md file.
 */
function Notes({ playing }: { playing: boolean }) {
  const [typed, setTyped] = useState(0);
  const [ticked, setTicked] = useState(false);
  const done = typed >= NOTE_TYPED.length;
  useEffect(() => {
    if (!playing) return;
    const timer = window.setTimeout(
      () => (done ? setTicked(true) : setTyped((count) => count + 1)),
      done ? 1100 : typed === 0 ? 900 : 90 + (typed % 3) * 25,
    );
    return () => window.clearTimeout(timer);
  }, [done, playing, typed]);
  const editing = !ticked;
  return (
    <Panel title="Notas" height={244}>
      <div className="mt-3 flex items-center gap-1">
        <span className="rounded-full bg-white/[0.14] px-3 py-1 text-[13px] font-medium">Mercado</span>
        <span className="px-2 text-[16px] text-white/55">+</span>
        <span className="ml-auto flex items-center gap-1.5 text-[12px] font-medium text-white/45">
          <RefreshCw className={`h-3 w-3 ${ticked ? "" : "motion-safe:animate-spin [animation-duration:1.6s]"}`} strokeWidth={2.4} />
          {ticked ? "No cofre do Obsidian" : "Sincronizando…"}
        </span>
      </div>
      <div className="mt-2.5 h-[140px] rounded-[12px] bg-white/[0.045] px-4 py-3 text-[15px] leading-[1.5] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.07)]">
        <p className="text-[21px] font-semibold leading-[1.3]">Mercado</p>
        <NoteCheck checked text="leite" />
        <NoteCheck checked={ticked} text="pão integral" />
        {editing ? (
          <p className="flex items-center">
            <span className="text-white/30">- [ ]&nbsp;</span>
            {NOTE_TYPED.slice(0, typed)}
            <span className="ml-px inline-block h-[17px] w-[2px] animate-pulse rounded-full bg-white motion-reduce:animate-none" />
          </p>
        ) : (
          <NoteCheck checked={false} text={NOTE_TYPED} />
        )}
      </div>
    </Panel>
  );
}

function NoteCheck({ checked, text }: { checked: boolean; text: string }) {
  return (
    <p className="flex items-center gap-2">
      <span className={`flex h-[15px] w-[15px] shrink-0 items-center justify-center rounded-[4.5px] transition-colors duration-200 ${checked ? "bg-white/90" : "shadow-[inset_0_0_0_1.2px_rgba(255,255,255,0.5)]"}`}>
        {checked && (
          <svg viewBox="0 0 12 12" className="h-2.5 w-2.5" fill="none" stroke="#000" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
            <path d="M2.6 6.2 5 8.4l4.4-5" />
          </svg>
        )}
      </span>
      <span className={`transition-colors duration-200 ${checked ? "text-white/40 line-through" : ""}`}>{text}</span>
    </p>
  );
}

function Mirror() {
  return (
    <Panel title="Espelho" height={340}>
      <div
        className="relative mx-auto mt-4 h-[250px] w-[420px] overflow-hidden rounded-[22px]"
        style={{ background: "radial-gradient(70% 80% at 22% 18%, #f3d9b1 0%, transparent 60%), radial-gradient(60% 70% at 85% 30%, #7a8fa8 0%, transparent 65%), linear-gradient(180deg, #a08a76, #3d3631)" }}
      >
        <svg viewBox="0 0 420 250" className="absolute inset-0 h-full w-full blur-[3px]">
          <defs>
            <linearGradient id="skin" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0" stopColor="#d9b49a" />
              <stop offset="1" stopColor="#a77d62" />
            </linearGradient>
          </defs>
          <rect x="190" y="150" width="40" height="40" rx="14" fill="#b88b6e" />
          <ellipse cx="210" cy="112" rx="50" ry="62" fill="url(#skin)" />
          <path d="M158 104c-6-52 40-72 72-62 34 8 46 34 40 62-6-24-26-38-56-36-30 0-50 14-56 36z" fill="#2b211c" />
          <path d="M70 262c8-58 64-82 140-82s132 24 140 82z" fill="#2f3b4c" />
        </svg>
        <span className="absolute left-3 top-3 rounded-full bg-black/50 px-2.5 py-1 text-[12px] font-medium backdrop-blur">Câmera FaceTime HD</span>
      </div>
    </Panel>
  );
}

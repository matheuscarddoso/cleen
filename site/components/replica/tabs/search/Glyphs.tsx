import { notch } from "../../style";
import type { ItemIcon, Region } from "./catalog";

/** SwiftUI's `color.gradient`: the same color, a touch lighter at the top. */
function gradient(color: string) {
  return `linear-gradient(180deg, color-mix(in srgb, ${color}, white 16%), ${color})`;
}

/** SF's rectangle.*.filled: a window outline with the part it takes filled in. */
function WindowGlyph({ region: [x, y, width, height] }: { region: Region }) {
  const inner = { x: 2.4, y: 2.4, width: 9.2, height: 6.2 };
  return (
    <svg viewBox="0 0 14 11" width={13} height={10.2} aria-hidden>
      <rect x="0.75" y="0.75" width="12.5" height="9.5" rx="2.2" fill="none" stroke="#fff" strokeWidth="1.5" />
      <rect
        x={inner.x + x * inner.width}
        y={inner.y + y * inner.height}
        width={Math.max(1, width * inner.width)}
        height={Math.max(1, height * inner.height)}
        rx="0.9"
        fill="#fff"
      />
    </svg>
  );
}

/** A result's 20 pt icon (SearchRow.icon). Apps are drawn, never their real artwork. */
export function ItemGlyph({ icon }: { icon: ItemIcon }) {
  switch (icon.kind) {
    case "symbol": {
      const Glyph = icon.glyph;
      return (
        <span className="flex size-5 items-center justify-center rounded-[5.5px] text-white" style={{ background: gradient(icon.color) }}>
          <Glyph size={12} strokeWidth={2.3} aria-hidden />
        </span>
      );
    }
    case "window":
      return (
        <span className="flex size-5 items-center justify-center rounded-[5.5px]" style={{ background: gradient("rgb(10,133,255)") }}>
          <WindowGlyph region={icon.region} />
        </span>
      );
    case "app": {
      const Glyph = icon.look.glyph;
      return (
        <span className="flex size-5 items-center justify-center">
          <span
            className="flex size-[19px] items-center justify-center rounded-[4.6px] shadow-[0_0.5px_1px_rgba(0,0,0,0.5),inset_0_0_0_0.5px_rgba(255,255,255,0.18)]"
            style={{ background: `linear-gradient(180deg, ${icon.look.from}, ${icon.look.to})`, color: icon.look.ink ?? "#fff" }}
          >
            <Glyph size={11.5} strokeWidth={2.2} aria-hidden />
          </span>
        </span>
      );
    }
    case "emoji":
      return <span className="flex size-5 items-center justify-center text-[16px] leading-none" aria-hidden>{icon.emoji}</span>;
    case "color":
      return <span className="block size-5 rounded-[5.5px] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.2)]" style={{ background: icon.hex }} />;
    case "lucide": {
      const Glyph = icon.glyph;
      return (
        <span className="flex size-5 items-center justify-center rounded-[5.5px]" style={{ background: notch.control, color: notch.primary }}>
          <Glyph size={15} strokeWidth={2} aria-hidden />
        </span>
      );
    }
  }
}

/** SF's xmark.circle.fill: a grey disc with the cross cut out of it. */
export function ClearGlyph() {
  return (
    <svg viewBox="0 0 16 16" width={14} height={14} aria-hidden>
      <circle cx="8" cy="8" r="7.5" fill={notch.tertiary} />
      <path d="M5.4 5.4 10.6 10.6M10.6 5.4 5.4 10.6" stroke="#000" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}

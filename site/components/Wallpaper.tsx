/** A Tahoe-style wallpaper drawn in CSS: deep blue, violet and a cool glow. */
export function Wallpaper({ tone = "blue" }: { tone?: "blue" | "dusk" | "teal" }) {
  const palettes = {
    blue: "radial-gradient(120% 90% at 18% 10%, #3b5bdb 0%, transparent 55%), radial-gradient(90% 80% at 85% 20%, #7048e8 0%, transparent 50%), radial-gradient(120% 120% at 50% 110%, #0b7285 0%, transparent 55%), #0a1033",
    dusk: "radial-gradient(110% 90% at 80% 0%, #f08c00 0%, transparent 45%), radial-gradient(100% 90% at 10% 30%, #c2255c 0%, transparent 55%), radial-gradient(120% 120% at 50% 120%, #5f3dc4 0%, transparent 60%), #1a0b2e",
    teal: "radial-gradient(110% 90% at 15% 0%, #0ca678 0%, transparent 50%), radial-gradient(100% 90% at 90% 30%, #1c7ed6 0%, transparent 55%), radial-gradient(120% 120% at 50% 120%, #3b5bdb 0%, transparent 60%), #051b2c",
  } as const;
  return <div aria-hidden className="absolute inset-0" style={{ background: palettes[tone] }} />;
}

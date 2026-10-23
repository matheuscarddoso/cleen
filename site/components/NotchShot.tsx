import Image from "next/image";
import { Wallpaper } from "./Wallpaper";

/**
 * A real capture of Cleen's notch window (transparent, 2×) hanging from the top edge
 * of a screen, the way it opens on a Mac. The capture already includes the notch strip,
 * so it sits flush with the top.
 */
export function NotchShot({
  src,
  alt,
  tone = "blue",
  priority = false,
  className = "",
  width = 1504,
  height = 540,
  scale = 0.86,
}: {
  src: string;
  alt: string;
  tone?: "blue" | "dusk" | "teal";
  priority?: boolean;
  className?: string;
  width?: number;
  height?: number;
  /** How much of the card's width the capture takes. */
  scale?: number;
}) {
  return (
    <div className={`relative overflow-hidden rounded-[28px] border border-line ${className}`}>
      <Wallpaper tone={tone} />
      <div className="relative flex justify-center pb-6">
        <Image
          src={src}
          alt={alt}
          width={width}
          height={height}
          priority={priority}
          sizes="(min-width: 1024px) 900px, 100vw"
          className="h-auto select-none"
          style={{ width: `${scale * 100}%` }}
          draggable={false}
        />
      </div>
    </div>
  );
}

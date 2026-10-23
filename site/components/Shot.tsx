import Image from "next/image";
import { Wallpaper } from "./Wallpaper";

/**
 * A real capture of Cleen's notch window (transparent, 2×) hanging from the top edge of a
 * screen: wallpaper behind, the panel flush with the top as it opens on a Mac. Sits at the
 * bottom of a tile, so its own bottom corners are cut by the tile.
 */
export function Shot({
  src,
  alt,
  tone = "blue",
  priority = false,
  scale = 0.88,
  className = "",
  rounded = "rounded-t-[22px]",
}: {
  src: string;
  alt: string;
  tone?: "blue" | "dusk" | "teal";
  priority?: boolean;
  scale?: number;
  className?: string;
  rounded?: string;
}) {
  return (
    <div className={`relative overflow-hidden ${rounded} ${className}`}>
      <Wallpaper tone={tone} />
      <div className="relative flex justify-center">
        <Image
          src={src}
          alt={alt}
          width={1504}
          height={540}
          priority={priority}
          sizes="(min-width: 1000px) 900px, 100vw"
          className="h-auto select-none"
          style={{ width: `${scale * 100}%` }}
          draggable={false}
        />
      </div>
    </div>
  );
}

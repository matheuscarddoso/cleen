import { Play, type LucideProps } from "lucide-react";

/**
 * Lucide's play triangle, centered by eye rather than by its box: the point carries
 * less weight than the flat side, so it sits a further 3% of its size to the right
 * (the glyph itself already leans 0.85 of 24 units that way).
 */
export function OpticalPlay({ size = 24, style, ...props }: LucideProps & { size?: number }) {
  return <Play size={size} style={{ ...style, translate: `${(Number(size) * 0.031).toFixed(2)}px 0` }} {...props} />;
}

/**
 * A changing figure the way `.contentTransition(.numericText())` shows it: only the
 * characters that changed slide in. Each one is keyed by its place from the right, so
 * a price gaining a digit doesn't reanimate the rest. The full text is there once for
 * screen readers.
 */
export function NumericText({ value, animated }: { value: string; animated: boolean }) {
  const characters = Array.from(value);
  return (
    <>
      <span className="sr-only">{value}</span>
      <span aria-hidden className="inline-flex whitespace-pre tabular-nums">
        {characters.map((character, index) => (
          <span key={`${characters.length - index}-${character}`} className={animated ? "inline-block animate-[numeric_300ms_ease-out]" : "inline-block"}>
            {character}
          </span>
        ))}
      </span>
    </>
  );
}

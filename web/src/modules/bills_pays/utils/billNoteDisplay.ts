/** True when note has visible text (plain or HTML from the rich editor). */
export function billNoteHasVisibleContent(note: string | null | undefined): boolean {
  const raw = note?.trim() ?? '';
  if (!raw) return false;
  const text = raw
    .replace(/<[^>]*>/g, '')
    .replace(/&nbsp;/gi, ' ')
    .trim();
  return Boolean(text);
}

export function billNoteHtml(note: string | null | undefined): string {
  return note?.trim() ?? '';
}
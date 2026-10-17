/** Convert shared ISO links to the Korean local time expected by date inputs. */
export function localExploreTime(value: string | null): string {
  if (!value) return '';
  const text = value.trim().replace(' ', 'T');
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$/.test(text)) {
    const time = Date.parse(text);
    const day = Date.parse(`${text.slice(0, 10)}T00:00:00Z`);
    // Preserve invalid input so form validation can explain it instead of
    // silently moving impossible dates into the following month.
    if (Number.isFinite(time) && Number.isFinite(day) && new Date(day).toISOString().slice(0, 10) === text.slice(0, 10)) {
      return new Date(time + 9 * 3600000).toISOString().slice(0, 16);
    }
  }
  return text;
}

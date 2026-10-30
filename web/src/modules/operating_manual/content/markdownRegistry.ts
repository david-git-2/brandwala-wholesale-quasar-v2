const mdModules = import.meta.glob<string>('./md/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
});

export function getOperatingManualMarkdown(filename: string): string | undefined {
  const key = `./md/${filename}`;
  return mdModules[key];
}

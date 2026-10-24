const mdModules = import.meta.glob<string>('./md/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
});

export function getDocsMarkdown(filename: string): string | undefined {
  const key = `./md/${filename}`;
  return mdModules[key];
}

export function listDocsMarkdownFiles(): string[] {
  return Object.keys(mdModules).map((path) => path.replace('./md/', ''));
}

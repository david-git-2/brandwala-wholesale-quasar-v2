export function getInitials(name: string): string {
  if (!name || !name.trim()) return 'M';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] ?? '';
  const last = parts[parts.length - 1] ?? '';
  if (parts.length === 1) return first.substring(0, 2).toUpperCase();
  const char1 = first[0] ?? '';
  const char2 = last[0] ?? '';
  return (char1 + char2).toUpperCase() || 'M';
}

const colors: string[] = [
  'primary',
  'secondary',
  'accent',
  'positive',
  'negative',
  'info',
  'warning',
  'teal',
  'deep-purple',
  'indigo',
  'blue',
  'light-blue',
  'cyan',
  'amber',
  'orange',
  'deep-orange',
];

export function getAvatarColor(name: string): string {
  if (!name) return 'primary';
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  const index = Math.abs(hash) % colors.length;
  return colors[index] ?? 'primary';
}

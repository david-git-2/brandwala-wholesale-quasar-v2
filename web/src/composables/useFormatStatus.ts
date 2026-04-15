export const formatStatus = (value?: string | null) => {
  if (!value) return ''

  return value
    .toLowerCase()
    .split('_')
    .filter(Boolean)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')
}

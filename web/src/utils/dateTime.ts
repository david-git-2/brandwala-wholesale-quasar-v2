import { date } from 'quasar'

const APP_DATE_MASK = 'DD/MM/YYYY'
const APP_TIME_MASK = 'hh:mm A'
const APP_DATE_TIME_MASK = `${APP_DATE_MASK} ${APP_TIME_MASK}`

const toDate = (value: string | number | Date) => {
  const parsed = value instanceof Date ? value : new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

export const formatAppDate = (value?: string | number | Date | null, fallback = 'N/A') => {
  if (value === undefined || value === null || value === '') {
    return fallback
  }

  const parsed = toDate(value)
  if (!parsed) {
    return fallback
  }

  return date.formatDate(parsed, APP_DATE_MASK)
}

export const formatAppDateTime = (
  value?: string | number | Date | null,
  fallback = 'N/A',
) => {
  if (value === undefined || value === null || value === '') {
    return fallback
  }

  const parsed = toDate(value)
  if (!parsed) {
    return fallback
  }

  return date.formatDate(parsed, APP_DATE_TIME_MASK)
}

export const formatCurrentDateTimeForName = (prefix?: string) => {
  const value = date.formatDate(new Date(), APP_DATE_TIME_MASK)
  return prefix ? `${prefix} ${value}` : value
}


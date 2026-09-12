import { readThemeRgb, rgba } from './dashboardChartSetup';

const readCssVar = (name: string, fallback: string) => {
  if (typeof document === 'undefined') return fallback;
  const value = getComputedStyle(document.body).getPropertyValue(name).trim();
  return value || fallback;
};

export const dashboardChartColors = () => ({
  primary: rgba(readThemeRgb(), 0.9),
  primarySoft: rgba(readThemeRgb(), 0.15),
  success: readCssVar('--bw-success', '#1a7f4b'),
  warning: readCssVar('--bw-warning', '#b45309'),
  error: readCssVar('--bw-error', '#b83a3a'),
  muted: readCssVar('--bw-theme-muted', '#64748b'),
  surface: readCssVar('--bw-theme-border', '#e2e8f0'),
});

export const dashboardChartPalette = () => {
  const c = dashboardChartColors();
  return [c.success, c.warning, c.error, c.primary, c.muted];
};

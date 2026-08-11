import { ArcElement, Chart as ChartJS, DoughnutController, Tooltip } from 'chart.js';

let registered = false;

/** Register Chart.js doughnut pieces once for thrift dashboard. */
export const ensureThriftChartsRegistered = () => {
  if (registered) return;
  ChartJS.register(ArcElement, DoughnutController, Tooltip);
  registered = true;
};

export const readThemeRgb = (fallback = '45 212 191') => {
  if (typeof document === 'undefined') return fallback;
  const value = getComputedStyle(document.documentElement)
    .getPropertyValue('--bw-theme-primary-rgb')
    .trim();
  return value || fallback;
};

export const rgba = (rgb: string, alpha: number) => `rgb(${rgb} / ${alpha})`;

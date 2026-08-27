import {
  ArcElement,
  BarController,
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  DoughnutController,
  Filler,
  Legend,
  LinearScale,
  LineController,
  LineElement,
  PointElement,
  Tooltip,
} from 'chart.js';

let registered = false;

export const ensureDashboardChartsRegistered = () => {
  if (registered) return;
  ChartJS.register(
    CategoryScale,
    LinearScale,
    BarElement,
    BarController,
    PointElement,
    LineElement,
    LineController,
    ArcElement,
    DoughnutController,
    Tooltip,
    Legend,
    Filler,
  );
  registered = true;
};

export const readThemeRgb = (fallback = '2 132 199') => {
  if (typeof document === 'undefined') return fallback;
  const value = getComputedStyle(document.documentElement)
    .getPropertyValue('--bw-theme-primary-rgb')
    .trim();
  return value || fallback;
};

export const rgba = (rgb: string, alpha: number) => `rgb(${rgb} / ${alpha})`;

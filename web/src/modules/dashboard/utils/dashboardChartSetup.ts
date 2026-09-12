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
import type { TooltipOptions } from 'chart.js';

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

export const readThemeRgb = (fallback = '2 132 199', root?: Element | null) => {
  if (typeof document === 'undefined') return fallback;
  const el = root ?? document.body;
  const value = getComputedStyle(el).getPropertyValue('--bw-theme-primary-rgb').trim();
  return value || fallback;
};

export const rgba = (rgb: string, alpha: number) => `rgb(${rgb} / ${alpha})`;

export const dashboardTooltip = (): Partial<TooltipOptions> => ({
  backgroundColor: 'var(--bw-theme-ink)',
  titleFont: { size: 0 },
  bodyFont: { size: 12, family: 'var(--bw-font-ui)' },
  padding: 8,
  cornerRadius: 6,
  displayColors: false,
});

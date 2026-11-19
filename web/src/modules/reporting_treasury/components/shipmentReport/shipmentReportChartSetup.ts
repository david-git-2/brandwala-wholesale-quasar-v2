import {
  ArcElement,
  BarController,
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  DoughnutController,
  LinearScale,
  Tooltip,
} from 'chart.js';
import type { TooltipOptions } from 'chart.js';

let registered = false;

export const ensureShipmentReportChartsRegistered = () => {
  if (registered) return;
  ChartJS.register(
    CategoryScale,
    LinearScale,
    BarElement,
    BarController,
    ArcElement,
    DoughnutController,
    Tooltip,
  );
  registered = true;
};

export const readCssVar = (name: string, fallback: string) => {
  if (typeof document === 'undefined') return fallback;
  const value = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return value || fallback;
};

export const shipmentReportTooltip = (): Partial<TooltipOptions> => ({
  backgroundColor: 'var(--tf-theme-ink)',
  titleFont: { size: 0 },
  bodyFont: { size: 12, family: 'var(--tf-font-ui)' },
  padding: 10,
  cornerRadius: 6,
  displayColors: true,
  boxPadding: 6,
  boxWidth: 10,
  boxHeight: 10,
});

function hexToRgbParts(hex: string): [number, number, number] | null {
  const h = hex.replace('#', '').trim();
  if (h.length !== 6) return null;
  return [
    Number.parseInt(h.slice(0, 2), 16),
    Number.parseInt(h.slice(2, 4), 16),
    Number.parseInt(h.slice(4, 6), 16),
  ];
}

/** Resolve a theme token (hex or space-separated rgb) to `rgb(r g b / a)`. */
export function colorFromToken(cssVar: string, alpha = 1, fallbackHex = '#64748b'): string {
  const raw = readCssVar(cssVar, fallbackHex).trim();
  if (raw.includes('/')) return raw;
  if (raw.startsWith('rgb')) {
    if (alpha >= 1) return raw;
    const inner = raw.replace(/^rgba?\(|\)$/g, '').replace(/,/g, ' ');
    return `rgb(${inner} / ${alpha})`;
  }
  const parts = hexToRgbParts(raw.startsWith('#') ? raw : `#${raw}`);
  if (!parts) return `rgb(100 116 139 / ${alpha})`;
  return `rgb(${parts[0]} ${parts[1]} ${parts[2]} / ${alpha})`;
}

const COST_KIND_VARS: Record<string, string> = {
  material: '--tf-info',
  freight: '--tf-warning',
  customs: '--tf-status-progress',
  handling: '--tf-theme-primary',
  finance: '--tf-status-attention',
  vendor: '--tf-theme-muted',
  cargo: '--tf-warning',
  local: '--tf-neutral-muted',
  other: '--tf-neutral-chrome-text',
};

export function colorForCostKind(kind: string, alpha = 0.92): string {
  const key = kind.trim().toLowerCase();
  const token = COST_KIND_VARS[key] ?? '--tf-neutral-muted';
  return colorFromToken(token, alpha);
}

export function chartEarnedColor(alpha = 0.9) {
  return colorFromToken('--tf-info', alpha);
}

export function chartProfitColor(profit: number, alpha = 0.92) {
  return profit >= 0
    ? colorFromToken('--tf-success', alpha)
    : colorFromToken('--tf-error', alpha);
}
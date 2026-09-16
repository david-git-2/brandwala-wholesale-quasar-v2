import type { ApexOptions } from 'apexcharts';

export const createSparklineOptions = (
  color: string,
  gradientColor?: string,
): ApexOptions => ({
  chart: {
    type: 'area',
    sparkline: {
      enabled: true,
    },
    animations: {
      enabled: true,
      easing: 'easeinout',
      speed: 400,
    },
    dropShadow: {
      enabled: true,
      top: 2,
      left: 0,
      blur: 3,
      color,
      opacity: 0.25,
    },
  },
  stroke: {
    curve: 'smooth',
    width: 2,
    colors: [color],
  },
  fill: {
    type: 'gradient',
    gradient: {
      shadeIntensity: 1,
      opacityFrom: 0.35,
      opacityTo: 0.02,
      stops: [0, 95, 100],
      colorStops: [
        {
          offset: 0,
          color: gradientColor || color,
          opacity: 0.3,
        },
        {
          offset: 100,
          color: gradientColor || color,
          opacity: 0.0,
        },
      ],
    },
  },
  tooltip: {
    theme: 'dark',
    x: { show: false },
    y: {
      formatter: (val: number) => `৳${Math.round(val).toLocaleString()}`,
      title: {
        formatter: () => '',
      },
    },
    marker: { show: false },
  },
  colors: [color],
});

export const createRadialBarOptions = (
  labels: string[],
  colors: string[],
  totalLabel = 'Total Units',
): ApexOptions => ({
  chart: {
    type: 'radialBar',
    sparkline: {
      enabled: true,
    },
    animations: {
      enabled: true,
      easing: 'easeinout',
      speed: 500,
    },
  },
  plotOptions: {
    radialBar: {
      startAngle: -90,
      endAngle: 90,
      hollow: {
        margin: 0,
        size: '68%',
      },
      track: {
        background: '#f1efe9',
        strokeWidth: '97%',
        margin: 5,
        dropShadow: {
          enabled: false,
        },
      },
      dataLabels: {
        name: {
          show: true,
          fontSize: '11px',
          fontWeight: 600,
          color: '#736a61',
          offsetY: -18,
        },
        value: {
          show: true,
          fontSize: '20px',
          fontWeight: 700,
          color: '#0f172a',
          offsetY: -6,
          formatter: (val: number) => `${Math.round(val)}%`,
        },
        total: {
          show: true,
          label: totalLabel,
          fontSize: '10px',
          fontWeight: 600,
          color: '#736a61',
          formatter: () => '',
        },
      },
    },
  },
  fill: {
    type: 'gradient',
    gradient: {
      shade: 'dark',
      type: 'horizontal',
      shadeIntensity: 0.5,
      gradientToColors: colors,
      inverseColors: true,
      opacityFrom: 1,
      opacityTo: 1,
      stops: [0, 100],
    },
  },
  colors,
  labels,
  stroke: {
    lineCap: 'round',
  },
});

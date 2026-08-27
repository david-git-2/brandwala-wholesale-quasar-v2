import {
  ArcElement,
  BarController,
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  DoughnutController,
  Legend,
  LinearScale,
  Tooltip,
} from 'chart.js';

let registered = false;

export const ensureProcurementChartsRegistered = () => {
  if (registered) return;
  ChartJS.register(
    CategoryScale,
    LinearScale,
    BarElement,
    BarController,
    ArcElement,
    DoughnutController,
    Tooltip,
    Legend,
  );
  registered = true;
};

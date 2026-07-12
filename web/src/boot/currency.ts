import { defineBoot } from '#q-app';
import { formatAmountBdt } from 'src/utils/currency';

export default defineBoot(({ app }) => {
  app.config.globalProperties.$formatBdt = formatAmountBdt;
});

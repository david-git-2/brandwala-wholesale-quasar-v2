import { defineBoot } from '#q-app';
import { IconSet } from 'quasar';

import phosphorIconSet from '../icon-set/phosphor';

export default defineBoot(() => {
  IconSet.set(phosphorIconSet);
});

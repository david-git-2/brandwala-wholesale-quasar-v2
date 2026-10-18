import { defineBoot } from '#q-app';
import type { QNotifyCreateOptions } from 'quasar';

import { notify, notifyFromQuasarOptions } from 'src/utils/tfNotify';

export default defineBoot(({ app }) => {
  app.config.globalProperties.$notify = notify;
  app.config.globalProperties.$q.notify = (opts: string | QNotifyCreateOptions) =>
    notifyFromQuasarOptions(opts);
});

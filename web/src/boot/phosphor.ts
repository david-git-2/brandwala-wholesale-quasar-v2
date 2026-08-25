import { defineBoot } from '#q-app';
import { Notify } from 'quasar';

export default defineBoot(({ app }) => {
  app.config.globalProperties.$q.iconMapFn = (iconName: string) => {
    if (iconName.startsWith('ph ') || iconName.startsWith('ph-')) {
      return {
        cls: iconName,
      };
    }
    // Return void to let Quasar fall back to its default behavior for other icons
  };

  Notify.setDefaults({
    position: 'bottom',
    progress: true,
    timeout: 3000,
    classes: 'app-notify',
    icon: 'ph ph-info',
    actions: [
      {
        icon: 'ph ph-x',
        color: 'white',
        flat: true,
        round: true,
        dense: true,
        'aria-label': 'Dismiss',
      },
    ],
  });

  Notify.registerType('positive', {
    icon: 'ph ph-check-circle',
    color: 'positive',
    textColor: 'white',
    classes: 'app-notify app-notify--positive',
  });
  Notify.registerType('negative', {
    icon: 'ph ph-warning-circle',
    color: 'negative',
    textColor: 'white',
    classes: 'app-notify app-notify--negative',
  });
  Notify.registerType('warning', {
    icon: 'ph ph-warning',
    color: 'warning',
    textColor: 'white',
    classes: 'app-notify app-notify--warning',
  });
  Notify.registerType('info', {
    icon: 'ph ph-info',
    color: 'info',
    textColor: 'white',
    classes: 'app-notify app-notify--info',
  });
});

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
    icon: 'ph ph-info',
  });

  Notify.registerType('positive', {
    icon: 'ph ph-check-circle',
    color: 'positive',
  });
  Notify.registerType('negative', {
    icon: 'ph ph-warning-circle',
    color: 'negative',
  });
  Notify.registerType('warning', {
    icon: 'ph ph-warning',
    color: 'warning',
  });
  Notify.registerType('info', {
    icon: 'ph ph-info',
    color: 'info',
  });
});


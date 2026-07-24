import { defineBoot } from '#q-app';

export default defineBoot(({ app }) => {
  app.config.globalProperties.$q.iconMapFn = (iconName: string) => {
    if (iconName.startsWith('ph ') || iconName.startsWith('ph-')) {
      return {
        cls: iconName,
      };
    }
    // Return void to let Quasar fall back to its default behavior for other icons
  };
});

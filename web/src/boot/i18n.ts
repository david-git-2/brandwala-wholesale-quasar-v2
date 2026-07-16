import { defineBoot } from '#q-app';
import { createI18n } from 'vue-i18n';
import messages from 'src/i18n';

export default defineBoot(({ app }) => {
  const savedLocale = localStorage.getItem('locale') || 'en-US';

  const i18n = createI18n({
    locale: savedLocale,
    legacy: false,
    globalInjection: true,
    messages,
  });

  app.use(i18n);
});

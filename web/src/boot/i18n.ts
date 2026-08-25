import { defineBoot } from '#q-app';
import { createI18n } from 'vue-i18n';
import messages from 'src/i18n';

function syncDocumentLang(locale: string) {
  if (typeof document === 'undefined') return;
  document.documentElement.lang = locale === 'bn' ? 'bn' : 'en';
}

export default defineBoot(({ app }) => {
  const savedLocale = localStorage.getItem('locale') || localStorage.getItem('bw_locale') || 'en-US';

  const i18n = createI18n({
    locale: savedLocale,
    legacy: false,
    globalInjection: true,
    messages,
  });

  syncDocumentLang(savedLocale);
  app.use(i18n);
});

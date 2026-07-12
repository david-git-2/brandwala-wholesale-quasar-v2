import { defineBoot } from '#q-app';
import { applyDarkMode, applyDensity, applyNavPinned } from 'src/composables/useAppearance';

export default defineBoot(() => {
  if (typeof window !== 'undefined') {
    const localDark = window.localStorage.getItem('brandwala.appearance.darkMode');
    const localDensity = window.localStorage.getItem('brandwala.appearance.density');
    const localNavPinned = window.localStorage.getItem('brandwala.appearance.navPinned');

    // Default darkMode is false
    if (localDark === 'true') {
      applyDarkMode(true);
    } else {
      applyDarkMode(false);
    }

    // Default density is comfortable
    if (localDensity === 'compact') {
      applyDensity('compact');
    } else {
      applyDensity('comfortable');
    }

    // Default navPinned is true
    if (localNavPinned === 'false') {
      applyNavPinned(false);
    } else {
      applyNavPinned(true);
    }
  }
});

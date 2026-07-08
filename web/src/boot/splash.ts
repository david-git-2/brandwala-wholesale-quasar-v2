import { defineBoot } from '#q-app/wrappers';

const SPLASH_ID = 'app-splash';

export default defineBoot(() => {
  const splash = document.getElementById(SPLASH_ID);
  if (!splash) {
    return;
  }

  const removeSplash = () => {
    splash.addEventListener(
      'transitionend',
      () => {
        splash.remove();
      },
      { once: true },
    );
    splash.classList.add('app-splash--hide');
  };

  // Wait one frame so Vue can paint before the fade-out starts.
  requestAnimationFrame(() => {
    requestAnimationFrame(removeSplash);
  });
});

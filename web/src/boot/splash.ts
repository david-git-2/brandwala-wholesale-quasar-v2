import { defineBoot } from '#q-app';

const SPLASH_ID = 'app-splash';

const isAuthCallbackRoute = () => {
  if (typeof window === 'undefined') {
    return false;
  }

  let path = window.location.pathname || '/';
  if (window.location.hash?.startsWith('#/')) {
    path = window.location.hash.slice(1);
  }

  return path.startsWith('/auth/callback');
};

export default defineBoot(() => {
  const splash = document.getElementById(SPLASH_ID);
  if (!splash) {
    return;
  }

  if (isAuthCallbackRoute()) {
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

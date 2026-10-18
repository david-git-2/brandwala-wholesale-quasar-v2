import type { RouteRecordRaw } from 'vue-router';
import { landingSeo } from '../content';

const landingRoutes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('layouts/ExternalLayout.vue'),
    children: [
      {
        path: '',
        name: 'landing-home',
        component: () => import('../pages/LandingPage.vue'),
        meta: {
          title: landingSeo.title,
          public: true,
        },
      },
    ],
  },
];

export default landingRoutes;

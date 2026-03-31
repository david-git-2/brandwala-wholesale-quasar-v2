import type { RouteRecordRaw } from 'vue-router';
import authRoutes from 'src/modules/auth/routes';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/app/home',
  },
  {
    path: '/app/home',
    name: 'app-home',
    component: () => import('layouts/MainLayout.vue'),
    children: [
      {
        path: '',
        component: () => import('pages/IndexPage.vue'),
      },
    ],
  },
  {
    path: '/platform/home',
    name: 'platform-home',
    component: () => import('layouts/MainLayout.vue'),
    children: [
      {
        path: '',
        component: () => import('pages/IndexPage.vue'),
      },
    ],
  },
  {
    path: '/shop/home',
    name: 'shop-home',
    component: () => import('layouts/MainLayout.vue'),
    children: [
      {
        path: '',
        component: () => import('pages/IndexPage.vue'),
      },
    ],
  },
  ...authRoutes,

  // Always leave this as last one
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
];

export default routes;

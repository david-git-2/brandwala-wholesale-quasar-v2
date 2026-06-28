import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftBarcodeRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/barcodes',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff'],
         requireTenantContext: true,
         requiredModule: 'thrift_barcode',
      }),
      children: [
         {
            path: '',
            name: 'thrift-barcodes-page',
            component: () => import('../barcode/pages/ThriftBarcodePage.vue'),
            meta: {
               title: 'Thrift Barcodes',
               headerTitle: 'Barcode Management',
            },
         },
      ],
   },
   {
      path: '/:tenantSlug?/app/thrift/barcodes/print-preview',
      component: () => import('layouts/ExternalLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff'],
         requireTenantContext: true,
         requiredModule: 'thrift_barcode',
      }),
      children: [
         {
            path: '',
            name: 'thrift-barcodes-print-preview',
            component: () => import('../barcode/pages/ThriftBarcodePrintPreviewPage.vue'),
            meta: {
               title: 'Barcode Print Preview',
               headerTitle: 'Print Preview',
            },
         },
      ],
   },
];

export default thriftBarcodeRoutes;

import type { RouteRecordRaw } from 'vue-router';
import adminRoutes from './adminRoutes';
import shopRoutes from './shopRoutes';

const shopOrderRoutes: RouteRecordRaw[] = [...adminRoutes, ...shopRoutes];

export default shopOrderRoutes;

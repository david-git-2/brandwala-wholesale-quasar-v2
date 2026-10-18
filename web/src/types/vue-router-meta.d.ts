import 'vue-router';

declare module 'vue-router' {
  interface RouteMeta {
    breadcrumb?: string;
    headerTitle?: string;
    title?: string;
    hasPageToolbar?: boolean;
  }
}

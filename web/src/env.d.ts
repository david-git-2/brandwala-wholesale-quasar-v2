/// <reference types="vite/client" />

declare module 'vue' {
  interface ComponentCustomProperties {
    $notify: import('src/utils/tfNotify').TfNotifyApi;
  }
}

declare module 'vue-router' {
  interface RouteMeta {
    breadcrumb?: string;
    headerTitle?: string;
    title?: string;
    hasPageToolbar?: boolean;
  }
}

interface ImportMetaEnv {
  readonly VITE_APP_VERSION?: string;
}

declare namespace NodeJS {
  interface ProcessEnv {
    NODE_ENV: string;
    VUE_ROUTER_MODE: 'hash' | 'history' | 'abstract' | undefined;
    VUE_ROUTER_BASE: string | undefined;
    VITE_LOCAL_APP_URL: string | undefined;
    VITE_PRODUCTION_APP_URL: string | undefined;
    VITE_SUPABASE_ANON_KEY: string | undefined;
    VITE_SUPABASE_URL: string | undefined;
    VITE_APP_VERSION: string | undefined;
    VITE_GEMINI_API_KEY: string | undefined;
    GEMINI_API_KEY: string | undefined;
  }
}

declare module '*.png' {
  const content: string;
  export default content;
}

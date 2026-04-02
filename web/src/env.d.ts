declare namespace NodeJS {
  interface ProcessEnv {
    NODE_ENV: string;
    VUE_ROUTER_MODE: 'hash' | 'history' | 'abstract' | undefined;
    VUE_ROUTER_BASE: string | undefined;
    VITE_LOCAL_APP_URL: string | undefined;
    VITE_PRODUCTION_APP_URL: string | undefined;
    VITE_SUPABASE_ANON_KEY: string | undefined;
    VITE_SUPABASE_URL: string | undefined;
  }
}

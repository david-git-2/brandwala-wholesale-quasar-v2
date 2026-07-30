export type HelpScope = 'platform' | 'app' | 'shop' | 'investor';

export type HelpAudience =
  | 'superadmin'
  | 'admin'
  | 'staff'
  | 'viewer'
  | 'merchant'
  | 'investor';

export type HelpTab = 'overview' | 'workflows' | 'terms' | 'faqs';

/** Guide body copy — always ship both locales. UI chrome stays in vue-i18n. */
export type LocalizedText = {
  en: string;
  bn: string;
};

export interface ModuleGuideWorkflow {
  id: string;
  title: LocalizedText;
  steps: LocalizedText[];
}

export interface ModuleGuideTerm {
  term: LocalizedText;
  definition: LocalizedText;
}

export interface ModuleGuideFaq {
  question: LocalizedText;
  answer: LocalizedText;
}

export interface ModuleGuide {
  id: string;
  title: LocalizedText;
  caption: LocalizedText;
  icon: string;
  scopes: HelpScope[];
  audiences: HelpAudience[];
  routeMatchers: string[];
  overview: LocalizedText;
  workflows: ModuleGuideWorkflow[];
  terms: ModuleGuideTerm[];
  faqs: ModuleGuideFaq[];
}

export interface HelpResolveContext {
  scope: HelpScope;
  audience: HelpAudience;
}

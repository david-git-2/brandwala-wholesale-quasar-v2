export type HelpScope = 'platform' | 'app' | 'shop' | 'investor';

export type HelpAudience =
  | 'superadmin'
  | 'admin'
  | 'staff'
  | 'viewer'
  | 'merchant'
  | 'investor';

export type HelpTab = 'overview' | 'workflows' | 'terms' | 'faqs';

export interface ModuleGuideWorkflow {
  id: string;
  title: string;
  steps: string[];
}

export interface ModuleGuideTerm {
  term: string;
  definition: string;
}

export interface ModuleGuideFaq {
  question: string;
  answer: string;
}

export interface ModuleGuide {
  id: string;
  title: string;
  caption: string;
  icon: string;
  scopes: HelpScope[];
  audiences: HelpAudience[];
  routeMatchers: string[];
  overview: string;
  workflows: ModuleGuideWorkflow[];
  terms: ModuleGuideTerm[];
  faqs: ModuleGuideFaq[];
}

export interface HelpResolveContext {
  scope: HelpScope;
  audience: HelpAudience;
}

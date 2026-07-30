import type { HelpAudience, HelpResolveContext, HelpScope, ModuleGuide } from '../types';
import { localizedSearchBlob } from './localize';
import { MODULE_GUIDE_REGISTRY } from './moduleGuideRegistry';

export const mapAccessRoleToHelpAudience = (
  role: string | null | undefined,
): HelpAudience | null => {
  if (!role) return null;
  switch (role) {
    case 'superadmin':
      return 'superadmin';
    case 'admin':
      return 'admin';
    case 'staff':
      return 'staff';
    case 'viewer':
      return 'viewer';
    case 'customer_admin':
    case 'customer_negotiator':
    case 'customer_staff':
      return 'merchant';
    case 'investor_portal':
      return 'investor';
    default:
      return null;
  }
};

export const resolveHelpScopeFromPath = (path: string): HelpScope | null => {
  // Order matters: `/app/shop/...` must resolve as app, not shop.
  if (path.includes('/platform')) return 'platform';
  if (path.includes('/app/') || /\/app$/.test(path)) return 'app';
  if (path.includes('/investor/') || /\/investor$/.test(path)) return 'investor';
  if (path.includes('/shop/') || /\/shop$/.test(path)) return 'shop';
  return null;
};

const matchesContext = (guide: ModuleGuide, ctx: HelpResolveContext): boolean =>
  guide.scopes.includes(ctx.scope) && guide.audiences.includes(ctx.audience);

export const listModuleGuides = (ctx: HelpResolveContext): ModuleGuide[] =>
  MODULE_GUIDE_REGISTRY.filter((guide) => matchesContext(guide, ctx));

export const getModuleGuideById = (id: string): ModuleGuide | undefined =>
  MODULE_GUIDE_REGISTRY.find((guide) => guide.id === id);

export const resolveModuleGuideFromPath = (
  path: string,
  ctx: HelpResolveContext,
): ModuleGuide | undefined => {
  const candidates = listModuleGuides(ctx).filter((guide) =>
    guide.routeMatchers.some((matcher) => path.includes(matcher)),
  );

  if (candidates.length === 0) return undefined;

  // Prefer the longest matcher hit (most specific path).
  return [...candidates].sort((a, b) => {
    const aLen = Math.max(
      ...a.routeMatchers.filter((m) => path.includes(m)).map((m) => m.length),
      0,
    );
    const bLen = Math.max(
      ...b.routeMatchers.filter((m) => path.includes(m)).map((m) => m.length),
      0,
    );
    return bLen - aLen;
  })[0];
};

export const searchModuleGuides = (query: string, ctx: HelpResolveContext): ModuleGuide[] => {
  const q = query.trim().toLowerCase();
  const base = listModuleGuides(ctx);
  if (!q) return base;

  return base.filter((guide) => {
    const haystack = [
      localizedSearchBlob(guide.title),
      localizedSearchBlob(guide.caption),
      localizedSearchBlob(guide.overview),
      ...guide.workflows.flatMap((w) => [
        localizedSearchBlob(w.title),
        ...w.steps.map(localizedSearchBlob),
      ]),
      ...guide.terms.flatMap((t) => [
        localizedSearchBlob(t.term),
        localizedSearchBlob(t.definition),
      ]),
      ...guide.faqs.flatMap((f) => [
        localizedSearchBlob(f.question),
        localizedSearchBlob(f.answer),
      ]),
    ]
      .join(' ')
      .toLowerCase();
    return haystack.includes(q);
  });
};

export const helpCenterPathForScope = (
  scope: HelpScope,
  tenantSlug: string | null,
): string => {
  switch (scope) {
    case 'platform':
      return '/platform/help';
    case 'app':
      return tenantSlug ? `/${tenantSlug}/app/help` : '/app/help';
    case 'shop':
      return tenantSlug ? `/${tenantSlug}/shop/help` : '/shop/help';
    case 'investor':
      return tenantSlug ? `/${tenantSlug}/investor/help` : '/investor/help';
    default:
      return '/app/help';
  }
};

export const resolveNotificationLink = (
  linkPath: string | null | undefined,
  tenantSlug: string | null | undefined,
): string | null => {
  if (!linkPath) {
    return null;
  }

  if (tenantSlug && (linkPath.startsWith('/app/') || linkPath.startsWith('/shop/'))) {
    return `/${tenantSlug}${linkPath}`;
  }

  return linkPath;
};

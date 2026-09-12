export const resolveNotificationLink = (
  linkPath: string | null | undefined,
  tenantSlug: string | null | undefined,
): string | null => {
  if (!linkPath) {
    return null;
  }

  if (linkPath.startsWith('/app/') && tenantSlug) {
    return `/${tenantSlug}${linkPath}`;
  }

  return linkPath;
};

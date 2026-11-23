import type { RouteLocationNormalized } from 'vue-router';

const DROPSHIP_FLOW_PATH_RE = /\/dropship\/(?:cart|review|delivery|checkout)\/?$/;

export function isDropshipOrderFlowRoute(
  route: Pick<RouteLocationNormalized, 'path'>,
): boolean {
  return DROPSHIP_FLOW_PATH_RE.test(route.path);
}
import type { RouteLocationNormalized } from 'vue-router';

const DROPSHIP_FLOW_PATH_RE =
  /\/(?:dropship\/(?:place-order|review|delivery|checkout)|[^/]+\/dropship\/cart)\/?$/;

export function isDropshipOrderFlowRoute(
  route: Pick<RouteLocationNormalized, 'path'>,
): boolean {
  return DROPSHIP_FLOW_PATH_RE.test(route.path);
}
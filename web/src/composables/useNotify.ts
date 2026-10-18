import { notify } from 'src/utils/tfNotify';

/** Composable wrapper around the global `notify` helper. */
export function useNotify() {
  return notify;
}

export { notify } from 'src/utils/tfNotify';

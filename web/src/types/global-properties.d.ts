import 'vue';
import type { BdtFormatOptions } from 'src/utils/currency';
import type { TfNotifyApi } from 'src/utils/tfNotify';

declare module 'vue' {
  interface ComponentCustomProperties {
    $formatBdt: (value: number | string | null | undefined, options?: BdtFormatOptions) => string;
    $notify: TfNotifyApi;
  }
}

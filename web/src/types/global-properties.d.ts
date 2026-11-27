import 'vue';
import type { TfNotifyApi } from 'src/utils/tfNotify';

declare module 'vue' {
  interface ComponentCustomProperties {
    $notify: TfNotifyApi;
  }
}

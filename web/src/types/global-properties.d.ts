import 'vue'
import type { BdtFormatOptions } from 'src/utils/currency'

declare module 'vue' {
  interface ComponentCustomProperties {
    $formatBdt: (value: number | string | null | undefined, options?: BdtFormatOptions) => string
  }
}


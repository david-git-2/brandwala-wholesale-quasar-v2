<template>
  <q-page class="q-pa-md preview-canvas">
    <div class="preview-page__shell a4-sheet">
      <!-- Actions Bar (hidden when printing) -->
      <div class="preview-page__actions q-mb-md no-print row justify-between items-center q-col-gutter-sm">
        <div class="col-auto">
          <q-btn
            flat
            dense
            no-caps
            icon="arrow_back"
            label="Back to Barcodes"
            color="primary"
            @click="goBack"
          />
        </div>
        
        <div class="col-auto">
          <q-btn
            color="primary"
            icon="print"
            label="Print Barcodes"
            class="preview-page__print-btn pill-btn"
            :loading="loading"
            @click="printPage"
          />
        </div>
      </div>

      <!-- Loading Indicator -->
      <div v-if="loading" class="text-center q-pa-xl">
        <q-spinner size="50px" color="primary" />
        <div class="q-mt-md text-grey-7">Loading barcodes for print preview...</div>
      </div>

      <!-- Selected items indicator (hidden when printing) -->
      <div v-else-if="printList.length > 0" class="q-mb-md text-caption text-grey-8 no-print">
        Showing <strong>{{ printList.length }}</strong> barcodes ready for printing.
      </div>
      <div v-else class="text-center q-pa-xl text-grey-6 no-print">
        No barcodes selected for print. Please return to the Barcode Management page to select barcodes.
      </div>

      <!-- Printable Barcodes Grid -->
      <div v-if="printList.length > 0" class="barcode-grid">
        <div
          v-for="barcode in printList"
          :key="barcode.id"
          class="barcode-card"
        >
          <div class="barcode-card__inner">
            <div class="barcode-card__tenant">THRIFT</div>
            <!-- Accurate Scannable Barcode Renderer -->
            <div class="barcode-card__barcode">
              <BarcodeRenderer :value="barcode.barcode_id" :display-value="false" />
            </div>
            <div class="barcode-card__text">{{ barcode.barcode_id }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Post-Print Confirmation Dialog -->
    <q-dialog v-model="showPostPrintDialog" persistent>
      <q-card style="min-width: 380px; border-radius: 12px;">
        <q-card-section class="bg-primary text-white q-py-sm">
          <div class="text-subtitle1 text-weight-bold">Mark as Printed?</div>
        </q-card-section>

        <q-card-section class="q-py-md">
          Did the print job complete successfully? Would you like to mark these <strong>{{ printList.length }}</strong> barcodes as <strong>Printed</strong> in the database?
        </q-card-section>

        <q-card-actions align="right" class="q-pt-none">
          <q-btn flat label="No, Keep Unprinted" color="grey" @click="closePostPrint(false)" />
          <q-btn unelevated label="Yes, Mark Printed" color="primary" class="pill-btn" @click="closePostPrint(true)" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useThriftBarcodeStore } from '../stores/thriftBarcodeStore'
import BarcodeRenderer from '../components/BarcodeRenderer.vue'
import type { ThriftBarcode } from '../types'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const barcodeStore = useThriftBarcodeStore()

const loading = ref(false)
const printList = ref<ThriftBarcode[]>([])
const showPostPrintDialog = ref(false)

const barcodeIds = computed(() => {
  const queryIds = route.query.ids
  if (typeof queryIds !== 'string') return []
  return queryIds.split(',').map(Number).filter(n => Number.isFinite(n) && n > 0)
})

const goBack = () => {
  void router.push({ name: 'thrift-barcodes-page' })
}

const printPage = () => {
  window.print()
  // Prompt user after standard browser print returns
  showPostPrintDialog.value = true
}

const closePostPrint = async (markAsPrinted: boolean) => {
  showPostPrintDialog.value = false
  if (markAsPrinted && authStore.tenantId && printList.value.length > 0) {
    loading.value = true
    try {
      const ids = printList.value.map(b => b.id)
      await barcodeStore.markBarcodesPrinted(ids)
      
      // Update local printList states
      printList.value = printList.value.map(b => ({ ...b, is_printed: 1 }))
    } catch (err) {
      console.error('Failed to update printed status:', err)
    } finally {
      loading.value = false
    }
  }
}

onMounted(async () => {
  if (!authStore.tenantId) return
  loading.value = true
  
  try {
    await barcodeStore.fetchBarcodes(authStore.tenantId)
    if (barcodeIds.value.length > 0) {
      printList.value = barcodeStore.barcodes.filter(b => barcodeIds.value.includes(b.id))
    }
  } catch (err) {
    console.error(err)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.preview-canvas {
  background: #eef1f6;
  min-height: 100vh;
}

.a4-sheet {
  max-width: 210mm;
  margin: 0 auto;
  background: #fff;
  padding: 15mm;
  box-shadow: 0 8px 24px rgba(17, 24, 39, 0.12);
  border: 1px solid #d9dce3;
  border-radius: 8px;
}

.preview-page__actions {
  border-bottom: 1px solid rgba(0,0,0,0.08);
  padding-bottom: 12px;
}

.pill-btn {
  border-radius: 999px;
}

/* 3 columns grid for printable labels */
.barcode-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8mm;
}

.barcode-card {
  border: 1px dashed #777; /* Fully visible dashed border */
  padding: 4mm;
  text-align: center;
  background: #fff;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  box-sizing: border-box;
  height: 36mm;
  border-radius: 6px;
}

.barcode-card__tenant {
  font-size: 10px;
  font-weight: bold;
  letter-spacing: 0.1em;
  color: #606266;
  margin-bottom: 2px;
}

.barcode-card__barcode {
  width: 100%;
  max-width: 50mm;
  height: 12mm;
  margin: 2px 0;
}

.barcode-card__text {
  font-size: 13px;
  font-family: monospace;
  font-weight: bold;
  letter-spacing: 0.05em;
  color: #000;
  margin-top: 2px;
}

@media print {
  @page {
    size: A4;
    margin: 15mm 10mm 15mm 10mm;
  }

  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  body {
    background: #fff !important;
  }

  .preview-canvas {
    background: transparent !important;
    padding: 0 !important;
  }

  .a4-sheet {
    box-shadow: none !important;
    border: none !important;
    padding: 0 !important;
    width: auto !important;
    max-width: none !important;
  }

  .no-print {
    display: none !important;
  }

  .barcode-grid {
    gap: 10mm;
  }

  .barcode-card {
    border: 1px dashed #000 !important; /* Keep dashed border visible on print */
  }
}
</style>

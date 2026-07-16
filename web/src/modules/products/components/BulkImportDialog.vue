<template>
  <q-dialog v-model="isOpen" persistent max-width="95vw" width="1100px">
    <q-card class="floating-surface shadow-2 q-pa-md bulk-import-card">
      <!-- Title -->
      <q-card-section class="row items-center justify-between q-pb-none">
        <div>
          <div class="text-h6 text-weight-bold text-primary flex items-center gap-sm no-wrap">
            <q-icon name="drive_folder_upload" size="md" class="q-mr-xs" />
            Bulk Import Products
            <q-btn flat round dense icon="info" color="primary" size="sm" class="q-ml-xs">
              <q-menu style="width: 480px; max-width: 90vw" class="q-pa-md border-radius-lg shadow-3">
                <div class="text-subtitle2 text-weight-bold q-mb-xs">Import Guidelines</div>
                <div class="text-caption text-grey-8 q-mb-md">
                  You can paste Excel columns in any sequence. The mapper will auto-detect columns matching these names:
                </div>
                <q-markup-table dense flat bordered class="q-mb-md border-radius-sm">
                  <thead>
                    <tr>
                      <th class="text-left">Field</th>
                      <th class="text-left">Preferred Header</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr><td class="text-left text-weight-medium">Product Name *</td><td class="text-left font-mono">Name</td></tr>
                    <tr><td class="text-left text-weight-medium">Barcode</td><td class="text-left font-mono">Barcode</td></tr>
                    <tr><td class="text-left text-weight-medium">Product Code</td><td class="text-left font-mono">Product Code</td></tr>
                    <tr><td class="text-left text-weight-medium">Price</td><td class="text-left font-mono">Price</td></tr>
                    <tr><td class="text-left text-weight-medium">Image URL</td><td class="text-left font-mono">Image URL</td></tr>
                    <tr><td class="text-left text-weight-medium">Brand</td><td class="text-left font-mono">Brand</td></tr>
                    <tr><td class="text-left text-weight-medium">Category</td><td class="text-left font-mono">Category</td></tr>
                    <tr><td class="text-left text-weight-medium">Vendor Code</td><td class="text-left font-mono">Vendor Code</td></tr>
                  </tbody>
                </q-markup-table>
                <div class="row justify-between items-center q-mt-sm">
                  <div class="text-caption text-grey-7">* Required for mapping</div>
                  <q-btn outline color="primary" size="sm" label="Copy Sample Table" icon="content_copy" class="pill-btn" no-caps @click="copyTemplate" />
                </div>
              </q-menu>
            </q-btn>
          </div>
          <div class="text-caption text-grey-8">
            Upload a CSV file or paste tabular data from Excel/Google Sheets.
          </div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup :disable="importing" />
      </q-card-section>

      <q-separator class="q-my-md" />

      <!-- Main Section -->
      <q-card-section class="q-pa-none dialog-body-scroll">
        <div class="row q-col-gutter-lg">
          <!-- Left side: Source Input and Configuration -->
          <div class="col-12 col-md-5 column q-gutter-y-md">
            <!-- Source selection tabs -->
            <q-btn-toggle
              v-model="importMode"
              toggle-color="primary"
              color="grey-2"
              text-color="grey-7"
              toggle-text-color="white"
              no-caps
              unelevated
              spread
              class="pill-toggle"
              :options="[
                { label: 'Paste Table Data', value: 'paste' },
                { label: 'Upload File', value: 'file' },
              ]"
              @update:model-value="onModeChange"
            />

            <!-- Paste Tab -->
            <div v-if="importMode === 'paste'" class="column q-gutter-y-sm">
              <div class="text-subtitle2 text-weight-medium">Paste Tabular Text (CSV / Excel Rows)</div>
              <q-input
                v-model="rawPasteText"
                type="textarea"
                filled
                dense
                rows="8"
                class="soft-input font-mono-textarea"
                placeholder="Name&#9;Barcode&#9;Price&#9;Image URL&#10;Product A&#9;12345&#9;10.99&#9;https://example.com/a.jpg&#10;Product B&#9;67890&#9;15.50&#9;https://example.com/b.jpg"
                @update:model-value="parseInput"
              />
            </div>

            <!-- Upload File Tab -->
            <div v-else class="column q-gutter-y-sm">
              <div class="text-subtitle2 text-weight-medium">Choose CSV / TSV File</div>
              <q-file
                v-model="fileUpload"
                label="Pick file (.csv, .tsv, .txt)"
                filled
                dense
                accept=".csv,.tsv,.txt"
                class="soft-input"
                @update:model-value="onFileSelected"
              >
                <template #prepend>
                  <q-icon name="attach_file" />
                </template>
                <template #append v-if="fileUpload">
                  <q-icon
                    name="close"
                    @click.stop.prevent="clearFile"
                    class="cursor-pointer"
                  />
                </template>
              </q-file>
            </div>

            <!-- Import Fallback Settings -->
            <q-card flat bordered class="q-pa-md border-radius-lg bg-grey-1">
              <div class="text-subtitle2 text-weight-bold q-mb-md flex items-center">
                <q-icon name="settings" size="xs" class="q-mr-xs" />
                Default Fallbacks
              </div>
              <div class="column q-gutter-y-sm">
                <!-- Default Vendor -->
                <q-select
                  v-model="defaultVendor"
                  :options="vendorOptions"
                  label="Default Vendor"
                  filled
                  dense
                  clearable
                  emit-value
                  map-options
                  class="soft-input"
                >
                  <template #prepend>
                    <q-icon name="storefront" />
                  </template>
                </q-select>

                <!-- Default Market -->
                <q-select
                  v-model="defaultMarket"
                  :options="marketOptions"
                  label="Default Market"
                  filled
                  dense
                  clearable
                  emit-value
                  map-options
                  class="soft-input"
                >
                  <template #prepend>
                    <q-icon name="public" />
                  </template>
                </q-select>

                <!-- Default Currency -->
                <q-select
                  v-model="defaultCurrency"
                  :options="currencyOptions"
                  label="Default Price Currency"
                  filled
                  dense
                  emit-value
                  map-options
                  class="soft-input"
                >
                  <template #prepend>
                    <q-icon name="payments" />
                  </template>
                </q-select>

                <!-- Default Available -->
                <q-toggle
                  v-model="defaultIsAvailable"
                  label="Mark products as Available by default"
                  color="primary"
                  dense
                />
              </div>
            </q-card>
          </div>

          <!-- Right side: Columns Mapper & Preview -->
          <div class="col-12 col-md-7 column q-gutter-y-md">
            <!-- Header Check -->
            <div v-if="headers.length === 0" class="flex flex-center text-grey-5 q-pa-xl column">
              <q-icon name="table_chart" size="64px" />
              <div class="text-h6 q-mt-sm">No Data Parsed Yet</div>
              <div class="text-caption">Enter pasted data or upload a file to begin column mapping.</div>
            </div>

            <template v-else>
              <!-- Mapping section -->
              <q-card flat bordered class="q-pa-md border-radius-lg">
                <div class="text-subtitle2 text-weight-bold q-mb-xs">Map Columns to Product Fields</div>
                <div class="text-caption text-grey-8 q-mb-md">
                  Match the column headers from your source file to target product attributes.
                </div>

                <div class="row q-col-gutter-sm">
                  <div
                    v-for="target in targetFields"
                    :key="target.key"
                    class="col-12 col-sm-6"
                  >
                    <q-select
                      v-model="mapping[target.key]"
                      :options="headerOptions"
                      :label="`${target.label}${target.required ? ' *' : ''}`"
                      filled
                      dense
                      clearable
                      class="soft-input-mapping"
                      :rules="target.required ? [(val) => !!val || 'Required field mapping'] : []"
                      hide-bottom-space
                      @update:model-value="onMappingChange"
                    />
                  </div>
                </div>
              </q-card>

              <!-- Preview section -->
              <div class="column q-gutter-y-sm">
                <div class="row justify-between items-center">
                  <div class="text-subtitle2 text-weight-bold">
                    Parsed Preview ({{ parsedRows.length }} rows found)
                  </div>
                  <q-chip
                    v-if="hasRequiredFieldsMapped"
                    dense
                    color="green-1"
                    text-color="green-9"
                    icon="check_circle"
                    label="Ready to Import"
                  />
                  <q-chip
                    v-else
                    dense
                    color="red-1"
                    text-color="red-9"
                    icon="warning"
                    label="Mapping 'Name' is required"
                  />
                </div>

                <q-markup-table flat bordered dense class="preview-table bg-white">
                  <thead>
                    <tr>
                      <th class="text-left" style="width: 50px">Image</th>
                      <th class="text-left">Product Name</th>
                      <th class="text-left">Barcode</th>
                      <th class="text-left">Product Code</th>
                      <th class="text-left">Price</th>
                      <th class="text-left">Brand</th>
                      <th class="text-left">Category</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(row, idx) in previewItems.slice(0, 10)" :key="idx">
                      <td class="text-left">
                        <q-avatar size="32px" square class="bg-grey-2 border-radius-sm">
                          <img
                            v-if="row.image_url"
                            :src="row.image_url"
                            style="object-fit: contain"
                          />
                          <q-icon v-else name="image" size="18px" color="grey-6" />
                        </q-avatar>
                      </td>
                      <td class="text-left text-weight-medium">
                        <div class="ellipsis" style="max-width: 180px">
                          {{ row.name || '<Missing Name>' }}
                        </div>
                      </td>
                      <td class="text-left font-mono text-grey-8">{{ row.barcode || '-' }}</td>
                      <td class="text-left font-mono text-grey-8">{{ row.product_code || '-' }}</td>
                      <td class="text-left text-primary text-weight-medium">
                        <span v-if="row.list_price_amount != null">
                          {{ formatPrice(row.list_price_amount) }}
                        </span>
                        <span v-else>-</span>
                      </td>
                      <td class="text-left text-grey-8">{{ row.brand || '-' }}</td>
                      <td class="text-left text-grey-8">{{ row.category || '-' }}</td>
                    </tr>
                    <tr v-if="parsedRows.length > 10">
                      <td colspan="7" class="text-center text-grey-6 text-caption py-sm">
                        And {{ parsedRows.length - 10 }} more rows...
                      </td>
                    </tr>
                  </tbody>
                </q-markup-table>
              </div>
            </template>
          </div>
        </div>
      </q-card-section>

      <q-separator class="q-my-md" />

      <!-- Footer Buttons -->
      <q-card-actions align="right" class="q-pa-none">
        <q-btn
          flat
          label="Cancel"
          no-caps
          class="pill-btn slim-btn"
          v-close-popup
          :disable="importing"
        />
        <q-btn
          color="primary"
          label="Import Products"
          no-caps
          class="pill-btn slim-btn"
          icon="check"
          :loading="importing"
          :disable="!canSubmit"
          @click="onImport"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, reactive } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useMarketStore } from 'src/modules/market/stores/marketStore';
import { useProductStore } from '../stores/productStore';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import { showSuccessNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'success'): void;
}>();

const copyTemplate = () => {
  const template = `Name\tBarcode\tProduct Code\tPrice\tImage URL\tBrand\tCategory\tVendor Code\nELF Hydrating Face Cream\t5012345678901\tELF-FC-01\t14.99\thttps://example.com/facecream.jpg\tELF\tSkincare\tELF\nELF Matte Liquid Lipstick\t5012345678902\tELF-LL-02\t8.50\thttps://example.com/lipstick.jpg\tELF\tMakeup\tELF`;
  void navigator.clipboard.writeText(template).then(() => {
    showSuccessNotification('Sample table template copied to clipboard!');
  });
};

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const marketStore = useMarketStore();
const productStore = useProductStore();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const importMode = ref<'paste' | 'file'>('paste');
const rawPasteText = ref('');
const fileUpload = ref<File | null>(null);
const importing = ref(false);

const defaultVendor = ref<string | null>(null);
const defaultMarket = ref<string | null>('GB');
const defaultCurrency = ref<number | null>(null);
const defaultIsAvailable = ref(true);

const currencies = ref<{ label: string; value: number }[]>([]);

// Header parsed from file/paste
const headers = ref<string[]>([]);
const parsedRows = ref<string[][]>([]);

// Target product database fields
const targetFields = [
  { key: 'name', label: 'Product Name', required: true },
  { key: 'image_url', label: 'Image URL', required: false },
  { key: 'barcode', label: 'Barcode', required: false },
  { key: 'product_code', label: 'Product Code', required: false },
  { key: 'list_price_amount', label: 'Price Amount', required: false },
  { key: 'vendor_code', label: 'Vendor Code', required: false },
  { key: 'brand', label: 'Brand Name', required: false },
  { key: 'category', label: 'Category Name', required: false },
  { key: 'product_weight', label: 'Product Weight', required: false },
  { key: 'package_weight', label: 'Package Weight', required: false },
];

// Mapping map: targetFieldKey -> sourceHeaderColumnName
const mapping = reactive<Record<string, string | null>>({
  name: null,
  image_url: null,
  barcode: null,
  product_code: null,
  list_price_amount: null,
  vendor_code: null,
  brand: null,
  category: null,
  product_weight: null,
  package_weight: null,
});

// Dropdown options for columns
const headerOptions = computed(() => {
  return headers.value.map((h) => ({ label: h, value: h }));
});

// Dropdown options for fallback dropdowns
const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({ label: `${v.name} (${v.code})`, value: v.code })),
);

const marketOptions = computed(() =>
  marketStore.items.map((m) => ({ label: `${m.name} (${m.code})`, value: m.code })),
);

const currencyOptions = computed(() => currencies.value);

const hasRequiredFieldsMapped = computed(() => {
  return !!mapping.name;
});

const previewItems = ref<any[]>([]);

const canSubmit = computed(() => {
  return (
    hasRequiredFieldsMapped.value &&
    parsedRows.value.length > 0 &&
    !importing.value
  );
});

// Formatting functions
const formatPrice = (val: number) => {
  const currencySymbol = currencies.value.find((c) => c.value === defaultCurrency.value)?.label?.match(/\((.+)\)/)?.[1] ?? '£';
  return `${currencySymbol}${val.toFixed(2)}`;
};

const onModeChange = () => {
  headers.value = [];
  parsedRows.value = [];
  previewItems.value = [];
  rawPasteText.value = '';
  fileUpload.value = null;
  resetMapping();
};

const resetMapping = () => {
  for (const key of Object.keys(mapping)) {
    mapping[key] = null;
  }
};

const clearFile = () => {
  fileUpload.value = null;
  headers.value = [];
  parsedRows.value = [];
  previewItems.value = [];
  resetMapping();
};

const onFileSelected = (file: File | null) => {
  if (!file) return;
  const reader = new FileReader();
  reader.onload = (e) => {
    const text = e.target?.result as string;
    rawPasteText.value = text;
    parseInput();
  };
  reader.readAsText(file);
};

// Delimiter Detector and Line Parser
const parseInput = () => {
  const text = rawPasteText.value.trim();
  if (!text) {
    headers.value = [];
    parsedRows.value = [];
    previewItems.value = [];
    return;
  }

  // Split lines
  const lines = text.split(/\r?\n/).map((line) => line.trim()).filter((line) => line.length > 0);
  if (lines.length === 0) return;

  // Auto-detect delimiter from the first line
  const firstLine = lines[0] || '';
  let delimiter = ',';
  if (firstLine.includes('\t')) {
    delimiter = '\t';
  } else if (firstLine.includes(';')) {
    delimiter = ';';
  }

  const allParsed: string[][] = [];

  for (const line of lines) {
    const parsedLine = parseDelimiterLine(line, delimiter);
    allParsed.push(parsedLine);
  }

  if (allParsed.length > 0) {
    headers.value = allParsed[0] || [];
    parsedRows.value = allParsed.slice(1);
    autoSuggestMapping();
    generatePreview();
  }
};

// Parse a single CSV/TSV line respecting quotes
const parseDelimiterLine = (line: string, delimiter: string): string[] => {
  const result: string[] = [];
  let inQuotes = false;
  let current = '';

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === delimiter && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());

  // Clean quotes from parsed cells
  return result.map((val) => {
    let cleaned = val;
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    // Replace doubled quotes
    return cleaned.replace(/""/g, '"');
  });
};

// Auto suggest column mapping based on keywords
const autoSuggestMapping = () => {
  resetMapping();

  const rules: Record<string, string[]> = {
    name: ['name', 'title', 'product', 'designation', 'description'],
    image_url: ['image', 'url', 'image_url', 'photo', 'pic', 'picture', 'link'],
    barcode: ['barcode', 'bar code', 'upc', 'ean', 'gtin'],
    product_code: ['sku', 'product_code', 'product code', 'item code', 'ref', 'code'],
    list_price_amount: ['price', 'amount', 'list price', 'rate', 'cost', 'gbp'],
    vendor_code: ['vendor', 'vendor_code', 'vendor code', 'supplier', 'supplier_code'],
    brand: ['brand', 'manufacturer', 'make'],
    category: ['category', 'type', 'group', 'tag'],
    product_weight: ['product weight', 'net weight', 'weight', 'product_weight'],
    package_weight: ['package weight', 'gross weight', 'package_weight'],
  };

  for (const targetKey of Object.keys(rules)) {
    const keywords = rules[targetKey] || [];
    
    // 1. Try exact matches first
    let found = false;
    for (const header of headers.value) {
      const lowerHeader = header.toLowerCase().trim();
      if (keywords.some((keyword) => lowerHeader === keyword)) {
        mapping[targetKey] = header;
        found = true;
        break;
      }
    }
    
    if (found) continue;

    // 2. Fall back to partial matches (excluding false positives like matching 'code' inside 'barcode')
    for (const header of headers.value) {
      const lowerHeader = header.toLowerCase().trim();
      if (keywords.some((keyword) => {
        if (keyword === 'code' && lowerHeader.includes('barcode')) return false;
        return lowerHeader.includes(keyword);
      })) {
        mapping[targetKey] = header;
        break;
      }
    }
  }
};

const onMappingChange = () => {
  generatePreview();
};

// Dynamic items preview builder
const generatePreview = () => {
  if (!mapping.name) {
    previewItems.value = [];
    return;
  }

  const nameIdx = headers.value.indexOf(mapping.name);
  const imageUrlIdx = mapping.image_url ? headers.value.indexOf(mapping.image_url) : -1;
  const barcodeIdx = mapping.barcode ? headers.value.indexOf(mapping.barcode) : -1;
  const codeIdx = mapping.product_code ? headers.value.indexOf(mapping.product_code) : -1;
  const priceIdx = mapping.list_price_amount ? headers.value.indexOf(mapping.list_price_amount) : -1;
  const vendorIdx = mapping.vendor_code ? headers.value.indexOf(mapping.vendor_code) : -1;
  const brandIdx = mapping.brand ? headers.value.indexOf(mapping.brand) : -1;
  const categoryIdx = mapping.category ? headers.value.indexOf(mapping.category) : -1;
  const productWeightIdx = mapping.product_weight ? headers.value.indexOf(mapping.product_weight) : -1;
  const packageWeightIdx = mapping.package_weight ? headers.value.indexOf(mapping.package_weight) : -1;

  previewItems.value = parsedRows.value.map((row) => {
    const rawPrice = priceIdx !== -1 ? row[priceIdx] : null;
    let cleanPrice: number | null = null;
    if (rawPrice) {
      // Strip currency signs and commas
      const numericString = rawPrice.replace(/[^\d.-]/g, '');
      const parsed = parseFloat(numericString);
      if (!isNaN(parsed)) cleanPrice = parsed;
    }

    const rawProductWeight = productWeightIdx !== -1 ? row[productWeightIdx] : null;
    let cleanProductWeight: number | null = null;
    if (rawProductWeight) {
      const parsed = parseFloat(rawProductWeight.replace(/[^\d.-]/g, ''));
      if (!isNaN(parsed)) cleanProductWeight = parsed;
    }

    const rawPackageWeight = packageWeightIdx !== -1 ? row[packageWeightIdx] : null;
    let cleanPackageWeight: number | null = null;
    if (rawPackageWeight) {
      const parsed = parseFloat(rawPackageWeight.replace(/[^\d.-]/g, ''));
      if (!isNaN(parsed)) cleanPackageWeight = parsed;
    }

    return {
      name: nameIdx !== -1 ? row[nameIdx]?.trim() || '' : '',
      image_url: imageUrlIdx !== -1 ? row[imageUrlIdx]?.trim() || null : null,
      barcode: barcodeIdx !== -1 ? row[barcodeIdx]?.trim() || null : null,
      product_code: codeIdx !== -1 ? row[codeIdx]?.trim() || null : null,
      list_price_amount: cleanPrice,
      vendor_code: vendorIdx !== -1 ? row[vendorIdx]?.trim() : null,
      brand: brandIdx !== -1 ? row[brandIdx]?.trim() : null,
      category: categoryIdx !== -1 ? row[categoryIdx]?.trim() : null,
      product_weight: cleanProductWeight,
      package_weight: cleanPackageWeight,
    };
  });
};

const onImport = async () => {
  if (!canSubmit.value) return;

  importing.value = true;
  try {
    const payloads = previewItems.value.map((item) => {
      return {
        tenant_id: authStore.tenantId ?? null,
        name: item.name,
        product_code: item.product_code || null,
        barcode: item.barcode || null,
        brand: item.brand || null,
        category: item.category || null,
        list_price_amount: item.list_price_amount,
        list_price_currency_id: item.list_price_amount != null ? defaultCurrency.value : null,
        reference_cost_amount: null,
        reference_cost_currency_id: null,
        image_url: item.image_url || null,
        vendor_code: item.vendor_code || defaultVendor.value || null,
        market_code: defaultMarket.value || null,
        is_available: defaultIsAvailable.value,
        product_weight: item.product_weight,
        package_weight: item.package_weight,
        available_units: null,
        expire_date: null,
        minimum_order_quantity: null,
        tariff_code: null,
        languages: null,
        batch_code_manufacture_date: null,
      };
    });

    const result = await productStore.bulkCreateProducts(payloads);
    if (result && result.success) {
      emit('success');
      isOpen.value = false;
    }
  } catch (err) {
    console.error('Error during bulk import:', err);
  } finally {
    importing.value = false;
  }
};

onMounted(async () => {
  try {
    const currencyData = await globalReferenceRepository.listCurrencies();
    currencies.value = currencyData
      .filter((c) => c.is_active)
      .map((c) => ({ label: `${c.code} (${c.symbol})`, value: c.id }));

    // Preselect GBP if available
    const gbpCurrency = currencies.value.find((c) => c.label.startsWith('GBP'));
    if (gbpCurrency) {
      defaultCurrency.value = gbpCurrency.value;
    }
  } catch (e) {
    console.error('Error fetching currencies:', e);
  }

  // Pre-load reference options
  try {
    await Promise.all([
      vendorStore.fetchVendors(authStore.tenantId ?? null),
      marketStore.fetchMarkets(),
    ]);
  } catch (err) {
    console.error('Error fetching vendors/markets:', err);
  }
});
</script>

<style scoped>
.bulk-import-card {
  border-radius: 16px;
  background: #fbfbfd;
}

.pill-toggle {
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.font-mono-textarea :deep(.q-placeholder),
.font-mono-textarea :deep(textarea) {
  font-family: monospace;
  font-size: 12px;
  line-height: 1.5;
}

.soft-input :deep(.q-field__control),
.soft-input-mapping :deep(.q-field__control) {
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.9);
}

.border-radius-lg {
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.06);
}

.preview-table {
  border-radius: 10px;
  overflow: hidden;
  max-height: 320px;
}

.preview-table table {
  table-layout: fixed;
  width: 100%;
}

.preview-table :deep(thead th) {
  position: sticky;
  top: 0;
  z-index: 1;
  background-color: #f5f7fa;
  font-weight: 700;
  color: #2c3e50;
  border-bottom: 2px solid rgba(0, 0, 0, 0.06);
}

.dialog-body-scroll {
  max-height: 65vh;
  overflow-y: auto;
  padding-right: 4px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 36px;
  padding-left: 16px;
  padding-right: 16px;
}

.gap-sm {
  gap: 8px;
}

.border-radius-sm {
  border-radius: 4px;
}

.ellipsis {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>

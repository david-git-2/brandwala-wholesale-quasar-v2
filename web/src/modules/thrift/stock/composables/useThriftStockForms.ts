import { ref, computed, type Ref } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { supabase } from 'src/boot/supabase';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import type { ThriftStock, ThriftSection, ThriftCondition } from '../types';
import type { CloudinarySelectedImage } from 'src/components/CloudinaryUploaderDialog.vue';
import {
  useCreateStockMutation,
  useUpdateStockMutation,
  useAttachStockImageMutation,
} from './useThriftStockMutations';
import {
  useThriftCategoriesQuery,
  useThriftTypesQuery,
  useThriftBoxesQuery,
  useThriftShelvesQuery,
} from 'src/modules/thrift/shared/composables/useThriftMasterDataQuery';
import { useThriftSettingsQuery } from 'src/modules/thrift/settings/composables/useThriftSettingsQuery';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { useThriftShipmentsQuery } from 'src/modules/thrift/shipment/composables/useThriftShipmentQuery';
import {
  cleanupStockImageAssets,
  deleteStockCloudinaryImageStrict,
  uploadStockImage as uploadStockImageAssets,
  type StockImageUploadResult,
} from 'src/utils/stockImageClient';
import {
  type ThriftStockPricingInput,
} from '../repositories/thriftStockRepository';
import {
  DEFAULT_THRIFT_CLOUDINARY_FOLDER,
  buildThriftShipmentCloudinaryFolder,
} from 'src/utils/cloudinaryClient';
import { computeThriftUnitCosts, type ThriftStockCostInput, type ThriftUnitCostBreakdown } from 'src/modules/thrift/shared/utils/computeThriftUnitCosts';
import { resolveListedSellPrice } from 'src/modules/thrift/shared/utils/resolveListedSellPrice';
import { formatThriftActionableError } from 'src/modules/thrift/shared/utils/formatThriftActionableError';
import type { ShipmentOption } from './useThriftStockCosting';

export function useThriftStockForms(
  stocks: Ref<ThriftStock[]>,
  costBreakdownByStockId: Ref<Record<number, ThriftUnitCostBreakdown>>,
  shipmentStocksCache: Ref<Map<number, ThriftStock[]>>,
  invalidateShipmentCache: (shipmentId: number) => void,
) {
  const $q = useQuasar();
  const authStore = useAuthStore();
  const tenantIdRef = computed(() => authStore.tenantId ?? 0);

  // Master Data Queries
  const { data: settingsData } = useThriftSettingsQuery(tenantIdRef);
  const settings = computed(() => settingsData.value || null);
  const { data: currenciesData } = useThriftCurrenciesQuery();
  const currencies = computed(() => currenciesData.value || []);
  const { data: categoriesData } = useThriftCategoriesQuery(tenantIdRef);
  const { data: typesData } = useThriftTypesQuery(tenantIdRef);
  const { data: boxesData } = useThriftBoxesQuery(tenantIdRef);
  const { data: shelvesData } = useThriftShelvesQuery(tenantIdRef);
  const { data: shipmentsData } = useThriftShipmentsQuery(tenantIdRef);

  const categories = computed(() => categoriesData.value ?? []);
  const types = computed(() => typesData.value ?? []);
  const boxesList = computed(() => boxesData.value ?? []);
  const shelves = computed(() => shelvesData.value ?? []);
  const shipments = computed<ShipmentOption[]>(() => (shipmentsData.value || []) as ShipmentOption[]);

  const shipmentById = computed(() => {
    const map = new Map<number, ShipmentOption>();
    for (const shipment of shipments.value) {
      map.set(shipment.id, shipment);
    }
    return map;
  });

  function findCurrencyById(id: number | null | undefined): ThriftCurrency | undefined {
    if (!id) return undefined;
    return currencies.value.find((c) => c.id === id);
  }

  function shipmentPurchaseCurrency(shipmentId: number | null | undefined): ThriftCurrency | undefined {
    if (!shipmentId) return undefined;
    return findCurrencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
  }

  function shipmentCostCurrency(shipmentId: number | null | undefined): ThriftCurrency | undefined {
    if (!shipmentId) return undefined;
    return findCurrencyById(shipmentById.value.get(shipmentId)?.cost_currency_id);
  }

  // Mutations
  const createStockMutation = useCreateStockMutation();
  const updateStockMutation = useUpdateStockMutation();
  const attachStockImageMutation = useAttachStockImageMutation();

  // Dialog & Form States
  const dialogOpen = ref(false);
  const editingId = ref<number | null>(null);
  const quickAddDialogOpen = ref(false);
  const isUploaderOpen = ref(false);
  const uploaderTarget = ref<'quick' | 'edit'>('quick');
  const quickSubmitting = ref(false);
  const imageRemoveConfirmOpen = ref(false);
  const actionLoading = ref(false);

  const quickAddForm = ref({
    shipment_id: null as number | null,
    box_id: null as number | null,
    category_id: null as number | null,
    type_id: null as number | null,
    section: null as ThriftSection | null,
    barcode: '',
    brand_name: '',
    condition: 'EXCELLENT',
    product_weight: 250,
    imagePreviewUrl: '',
    pendingBlob: null as Blob | null,
  });
  const quickAddBarcodeLoading = ref(false);

  const canSubmitQuickAdd = computed(() => {
    const f = quickAddForm.value;
    return !!(
      f.shipment_id &&
      f.category_id &&
      f.type_id &&
      f.section &&
      f.barcode.trim() &&
      f.brand_name.trim() &&
      f.condition &&
      f.product_weight != null &&
      Number(f.product_weight) > 0
    );
  });

  const editImage = ref({
    url: '',
    originalUrl: '',
    pendingBlob: null as Blob | null,
    pendingPreviewUrl: null as string | null,
    removed: false,
  });

  const form = ref({
    category_id: null as number | null,
    type_id: null as number | null,
    shipment_id: null as number | null,
    box_id: null as number | null,
    name: '',
    brand_name: '',
    barcode: '',
    section: 'UNISEX' as ThriftSection | null,
    shelf_id: null as number | null,
    color: '',
    size: '',
    condition: 'EXCELLENT' as ThriftCondition | null,
    quantity: 1,
    product_weight: 250,
    extra_weight: 0,
    note: '',
  });

  const originUnitPrice = ref(0);
  const extraOriginUnitPrice = ref(0);
  const additionalChargesCost = ref(0);
  const pricing = ref<ThriftStockPricingInput>({
    listed_unit_price: 0,
    is_listed_price_manual: false,
  });

  const purchaseCurrency = computed(() => {
    const shipmentId = form.value.shipment_id;
    if (!shipmentId) return undefined;
    return findCurrencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
  });
  const costCurrency = computed(() => {
    const shipmentId = form.value.shipment_id;
    if (!shipmentId) return undefined;
    return findCurrencyById(shipmentById.value.get(shipmentId)?.cost_currency_id);
  });
  const purchaseCurrencySymbol = computed(() => purchaseCurrency.value?.symbol ?? '');
  const costCurrencySymbol = computed(() => costCurrency.value?.symbol ?? '');

  const quickAddPurchaseCurrency = computed(() => {
    const shipmentId = quickAddForm.value.shipment_id;
    if (!shipmentId) return undefined;
    return findCurrencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
  });

  const filteredBoxes = computed(() => {
    if (!form.value.shipment_id) return [];
    return boxesList.value.filter((b) => b.shipment_id === form.value.shipment_id);
  });

  const quickAddFilteredBoxes = computed(() => {
    if (!quickAddForm.value.shipment_id) return [];
    return boxesList.value.filter((b) => b.shipment_id === quickAddForm.value.shipment_id);
  });

  const uploaderCloudinaryFolder = computed(() => {
    const shipmentId =
      uploaderTarget.value === 'quick' ? quickAddForm.value.shipment_id : form.value.shipment_id;
    if (shipmentId && shipmentId > 0) {
      return buildThriftShipmentCloudinaryFolder(shipmentId);
    }
    return DEFAULT_THRIFT_CLOUDINARY_FOLDER;
  });

  function onShipmentChange() {
    form.value.box_id = null;
  }

  function onQuickShipmentChange() {
    quickAddForm.value.box_id = null;
    void loadFirstAvailableBarcode();
  }

  async function loadFirstAvailableBarcode() {
    if (!authStore.tenantId || !quickAddForm.value.shipment_id) {
      quickAddForm.value.barcode = '';
      return;
    }

    quickAddBarcodeLoading.value = true;
    try {
      const { data, error } = await supabase
        .from('thrift_barcodes')
        .select('barcode_id')
        .eq('tenant_id', authStore.tenantId)
        .eq('status', 'AVAILABLE')
        .order('barcode_id', { ascending: true })
        .limit(1)
        .maybeSingle();

      if (error) throw error;
      quickAddForm.value.barcode = data?.barcode_id ?? '';
    } catch (err) {
      console.error('Failed to load available barcode:', err);
      quickAddForm.value.barcode = '';
      $q.notify({
        type: 'negative',
        message: formatThriftActionableError(err, 'Failed to load available barcode'),
      });
    } finally {
      quickAddBarcodeLoading.value = false;
    }
  }

  function getBoxName(boxId: number | undefined | null) {
    if (!boxId) return '—';
    const bx = boxesList.value.find((b) => b.id === boxId);
    return bx ? bx.name : `#${boxId}`;
  }

  function openAddDialog() {
    quickAddForm.value = {
      shipment_id: null,
      box_id: null,
      category_id: null,
      type_id: null,
      section: null,
      barcode: '',
      brand_name: '',
      condition: 'EXCELLENT',
      product_weight: 250,
      imagePreviewUrl: '',
      pendingBlob: null,
    };
    quickAddDialogOpen.value = true;
  }

  function buildPricingFromRow(row: ThriftStock): ThriftStockPricingInput {
    const breakdown = costBreakdownByStockId.value[row.id];
    return {
      listed_unit_price: resolveListedSellPrice(row.pricing, breakdown),
      is_listed_price_manual: !!row.pricing?.is_listed_price_manual,
      markup_rate_override: row.pricing?.markup_rate_override ?? null,
    };
  }

  function openEditDialog(row: ThriftStock) {
    editingId.value = row.id;
    form.value = {
      category_id: row.category_id,
      type_id: row.type_id,
      shipment_id: row.shipment_id,
      box_id: row.box_id ?? null,
      name: row.name || '',
      brand_name: row.brand_name || '',
      barcode: row.barcode || '',
      section: row.section,
      shelf_id: row.shelf_id ?? null,
      color: row.color || '',
      size: row.size || '',
      condition: row.condition,
      quantity: row.quantity,
      product_weight: row.product_weight ?? 250,
      extra_weight: row.extra_weight ?? 0,
      note: row.note || '',
    };
    originUnitPrice.value = row.origin_unit_price ?? 0;
    extraOriginUnitPrice.value = row.extra_origin_unit_price ?? 0;
    additionalChargesCost.value = row.additional_charges_cost ?? 0;
    pricing.value = buildPricingFromRow(row);

    editImage.value = {
      url: row.image_url || '',
      originalUrl: row.image_url || '',
      pendingBlob: null,
      pendingPreviewUrl: null,
      removed: false,
    };
    dialogOpen.value = true;
  }

  function openEditUploader() {
    uploaderTarget.value = 'edit';
    isUploaderOpen.value = true;
  }

  function revokeBlobPreview(url: string | null) {
    if (url && url.startsWith('blob:')) {
      URL.revokeObjectURL(url);
    }
  }

  function resetEditImage() {
    revokeBlobPreview(editImage.value.pendingPreviewUrl);
    editImage.value = {
      url: '',
      originalUrl: '',
      pendingBlob: null,
      pendingPreviewUrl: null,
      removed: false,
    };
  }

  function onQuickAddDialogHide() {
    if (quickAddForm.value.imagePreviewUrl?.startsWith('blob:')) {
      revokeBlobPreview(quickAddForm.value.imagePreviewUrl);
    }
    quickAddForm.value.imagePreviewUrl = '';
    quickAddForm.value.pendingBlob = null;
  }

  function onEditDialogHide() {
    if (editImage.value.pendingPreviewUrl) {
      revokeBlobPreview(editImage.value.pendingPreviewUrl);
      editImage.value.pendingBlob = null;
      editImage.value.pendingPreviewUrl = null;
      if (!editImage.value.removed) {
        editImage.value.url = editImage.value.originalUrl;
      }
    }
  }

  function onImageSelected(selected: CloudinarySelectedImage) {
    if (uploaderTarget.value === 'quick') {
      if (quickAddForm.value.imagePreviewUrl?.startsWith('blob:')) {
        revokeBlobPreview(quickAddForm.value.imagePreviewUrl);
      }
      quickAddForm.value.pendingBlob = selected.blob;
      quickAddForm.value.imagePreviewUrl = selected.previewUrl;
    } else {
      revokeBlobPreview(editImage.value.pendingPreviewUrl);
      editImage.value.pendingBlob = selected.blob;
      editImage.value.pendingPreviewUrl = selected.previewUrl;
      editImage.value.url = selected.previewUrl;
      editImage.value.removed = false;
    }
    isUploaderOpen.value = false;
  }

  function removeEditImage() {
    revokeBlobPreview(editImage.value.pendingPreviewUrl);
    editImage.value.pendingBlob = null;
    editImage.value.pendingPreviewUrl = null;
    editImage.value.url = '';
    editImage.value.removed = true;
    imageRemoveConfirmOpen.value = false;
  }

  async function uploadStockImageBlob(
    barcode: string,
    stockId: number,
    blob: Blob,
    shipmentId?: number | null,
  ): Promise<StockImageUploadResult> {
    if (!shipmentId) {
      throw new Error('Shipment ID is required to upload image');
    }
    return uploadStockImageAssets(blob, {
      barcode,
      stockId,
      shipmentId,
      cloudinaryFolder: buildThriftShipmentCloudinaryFolder(shipmentId),
    });
  }

  async function submitQuickAdd() {
    if (!canSubmitQuickAdd.value || !authStore.tenantId) return;

    const brandName = quickAddForm.value.brand_name.trim();
    const condition = quickAddForm.value.condition;
    const productWeight = Number(quickAddForm.value.product_weight);
    const categoryId = quickAddForm.value.category_id;
    const typeId = quickAddForm.value.type_id;
    const section = quickAddForm.value.section;

    if (!brandName) {
      $q.notify({ type: 'negative', message: 'Brand name is required' });
      return;
    }
    if (!categoryId) {
      $q.notify({ type: 'negative', message: 'Category is required' });
      return;
    }
    if (!typeId) {
      $q.notify({ type: 'negative', message: 'Type is required' });
      return;
    }
    if (!section) {
      $q.notify({ type: 'negative', message: 'Section is required' });
      return;
    }
    if (!condition) {
      $q.notify({ type: 'negative', message: 'Condition is required' });
      return;
    }
    if (!Number.isFinite(productWeight) || productWeight <= 0) {
      $q.notify({ type: 'negative', message: 'Product weight is required' });
      return;
    }
    if (!quickAddForm.value.barcode.trim()) {
      $q.notify({
        type: 'negative',
        message: 'Generate barcodes first (Thrift → Barcodes), then try Quick Add again.',
      });
      return;
    }

    quickSubmitting.value = true;
    let createdStockId: number | null = null;
    let uploadedImage: StockImageUploadResult | null = null;

    try {
      const defaultOriginPrice = settings.value?.default_origin_unit_price ?? 0;

      const created = await createStockMutation.mutateAsync({
        tenantId: authStore.tenantId,
        shipmentId: quickAddForm.value.shipment_id!,
        categoryId,
        typeId,
        section,
        color: '',
        size: '',
        name: brandName,
        brandName,
        condition: condition as ThriftCondition,
        barcode: quickAddForm.value.barcode.trim(),
        stockType: 'SINGLE',
        quantity: 1,
        boxId: quickAddForm.value.box_id || undefined,
        productWeight,
        extraWeight: 0,
        note: '',
        userEmail: authStore.user?.email || 'admin@brandwala.com',
        pricing: {
          listed_unit_price: 0,
          is_listed_price_manual: false,
        },
        originUnitPrice: defaultOriginPrice,
        extraOriginUnitPrice: 0,
        additionalChargesCost: 0,
      });
      createdStockId = created.id;

      if (quickAddForm.value.pendingBlob) {
        uploadedImage = await uploadStockImageBlob(
          quickAddForm.value.barcode.trim(),
          created.id,
          quickAddForm.value.pendingBlob,
          quickAddForm.value.shipment_id,
        );

        await attachStockImageMutation.mutateAsync({
          id: created.id,
          imageUrl: uploadedImage.secureUrl,
          insertedBy: created.inserted_by,
        });
      }

      if (quickAddForm.value.shipment_id) {
        invalidateShipmentCache(quickAddForm.value.shipment_id);
      }

      $q.notify({
        type: 'positive',
        message: `Stock ${created.barcode || createdStockId} registered`,
      });
      quickAddDialogOpen.value = false;
    } catch (err: unknown) {
      if (uploadedImage) {
        await cleanupStockImageAssets({ imageUrl: uploadedImage.secureUrl });
      }
      $q.notify({ type: 'negative', message: formatThriftActionableError(err, 'Quick add failed') });
    } finally {
      quickSubmitting.value = false;
    }
  }

  async function onSubmit() {
    if (!authStore.tenantId) return;

    actionLoading.value = true;
    let orphanImage: StockImageUploadResult | null = null;
    try {
      const finalPricing: ThriftStockPricingInput = { ...pricing.value };

      if (!finalPricing.is_listed_price_manual && form.value.shipment_id) {
        const shipment = shipmentById.value.get(form.value.shipment_id);
        if (shipment) {
          const dummyStock: ThriftStockCostInput & { id: number; shipment_id: number } = {
            id: editingId.value || -1,
            shipment_id: form.value.shipment_id,
            quantity: form.value.quantity,
            product_weight: form.value.product_weight,
            extra_weight: form.value.extra_weight,
            origin_unit_price: originUnitPrice.value,
            extra_origin_unit_price: extraOriginUnitPrice.value,
            additional_charges_cost: additionalChargesCost.value,
            pricing: finalPricing,
          };

          const currentSettings = settings.value;
          const cache = shipmentStocksCache.value.get(form.value.shipment_id) || [];
          const otherStocks = editingId.value
            ? cache.filter((s) => s.id !== editingId.value)
            : cache;
          const merged = [...otherStocks, dummyStock];
          const U = merged.reduce((acc, s) => acc + (s.quantity || 0), 0);

          const breakdown = computeThriftUnitCosts(
            dummyStock,
            shipment,
            currentSettings || {},
            Math.max(U, 1),
            finalPricing,
            merged,
          );
          finalPricing.listed_unit_price = breakdown.suggested_sell_unit_price;
        }
      }

      if (editingId.value) {
        const stockPatch: Partial<ThriftStock> = {
          category_id: form.value.category_id!,
          type_id: form.value.type_id!,
          shipment_id: form.value.shipment_id!,
          box_id: form.value.box_id || undefined,
          name: form.value.name,
          brand_name: form.value.brand_name,
          barcode: form.value.barcode,
          section: form.value.section,
          shelf_id: form.value.shelf_id ?? null,
          color: form.value.color,
          size: form.value.size,
          condition: form.value.condition,
          quantity: form.value.quantity,
          product_weight: form.value.product_weight,
          extra_weight: form.value.extra_weight,
          note: form.value.note,
          origin_unit_price: originUnitPrice.value,
          extra_origin_unit_price: extraOriginUnitPrice.value,
          additional_charges_cost: additionalChargesCost.value,
        };

        let newImageUrl: string | undefined = undefined;
        if (editImage.value.removed) {
          newImageUrl = '';
        } else if (editImage.value.pendingBlob) {
          const uploaded = await uploadStockImageBlob(
            form.value.barcode,
            editingId.value,
            editImage.value.pendingBlob,
            form.value.shipment_id,
          );
          newImageUrl = uploaded.secureUrl;
        }

        await updateStockMutation.mutateAsync({
          id: editingId.value,
          stock: stockPatch,
          pricing: finalPricing,
          imageUrl: newImageUrl,
        });

        if (editImage.value.removed && editImage.value.originalUrl) {
          await deleteStockCloudinaryImageStrict(editImage.value.originalUrl);
        }

        $q.notify({ type: 'positive', message: 'Thrift stock updated successfully' });
      } else {
        const created = await createStockMutation.mutateAsync({
          tenantId: authStore.tenantId,
          shipmentId: form.value.shipment_id!,
          categoryId: form.value.category_id!,
          typeId: form.value.type_id!,
          section: form.value.section || 'UNISEX',
          color: form.value.color,
          size: form.value.size,
          name: form.value.name,
          brandName: form.value.brand_name,
          condition: form.value.condition || 'EXCELLENT',
          barcode: form.value.barcode,
          stockType: 'SINGLE',
          quantity: form.value.quantity,
          boxId: form.value.box_id || undefined,
          productWeight: form.value.product_weight || undefined,
          extraWeight: form.value.extra_weight || undefined,
          note: form.value.note || '',
          userEmail: authStore.user?.email || 'admin@brandwala.com',
          pricing: finalPricing,
          imageUrl: undefined,
          shelfId: form.value.shelf_id,
          originUnitPrice: originUnitPrice.value || undefined,
          extraOriginUnitPrice: extraOriginUnitPrice.value || undefined,
          additionalChargesCost: additionalChargesCost.value || undefined,
        });

        if (editImage.value.pendingBlob && !editImage.value.removed) {
          const uploaded = await uploadStockImageBlob(
            form.value.barcode,
            created.id,
            editImage.value.pendingBlob,
            form.value.shipment_id,
          );
          orphanImage = uploaded;
          await attachStockImageMutation.mutateAsync({
            id: created.id,
            imageUrl: uploaded.secureUrl,
            insertedBy: created.inserted_by,
          });
        }

        orphanImage = null;
        $q.notify({ type: 'positive', message: 'Thrift stock registered successfully' });
      }
      if (form.value.shipment_id) {
        invalidateShipmentCache(form.value.shipment_id);
      }
      if (editingId.value) {
        const originalShipmentId = stocks.value.find((s) => s.id === editingId.value)?.shipment_id;
        if (originalShipmentId && originalShipmentId !== form.value.shipment_id) {
          invalidateShipmentCache(originalShipmentId);
        }
      }
      resetEditImage();
      dialogOpen.value = false;
    } catch (err: unknown) {
      if (orphanImage) {
        await cleanupStockImageAssets({
          imageUrl: orphanImage.secureUrl,
        });
      }
      $q.notify({ type: 'negative', message: formatThriftActionableError(err, 'Saving failed') });
    } finally {
      actionLoading.value = false;
    }
  }

  return {
    settings,
    currencies,
    categories,
    types,
    boxesList,
    shelves,
    shipments,
    shipmentById,
    purchaseCurrency,
    costCurrency,
    purchaseCurrencySymbol,
    costCurrencySymbol,
    quickAddPurchaseCurrency,
    shipmentPurchaseCurrency,
    shipmentCostCurrency,
    filteredBoxes,
    quickAddFilteredBoxes,
    uploaderCloudinaryFolder,
    dialogOpen,
    editingId,
    quickAddDialogOpen,
    isUploaderOpen,
    uploaderTarget,
    quickSubmitting,
    imageRemoveConfirmOpen,
    actionLoading,
    quickAddForm,
    quickAddBarcodeLoading,
    canSubmitQuickAdd,
    editImage,
    form,
    originUnitPrice,
    extraOriginUnitPrice,
    additionalChargesCost,
    pricing,
    onShipmentChange,
    onQuickShipmentChange,
    loadFirstAvailableBarcode,
    getBoxName,
    openAddDialog,
    openEditDialog,
    openEditUploader,
    onQuickAddDialogHide,
    onEditDialogHide,
    onImageSelected,
    removeEditImage,
    submitQuickAdd,
    onSubmit,
    buildPricingFromRow,
  };
}

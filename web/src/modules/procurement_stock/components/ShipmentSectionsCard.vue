<template>
  <q-card flat bordered class="bg-white sections-card floating-surface shadow-1">
    <!-- Header -->
    <q-card-section class="row items-center justify-between q-py-sm q-px-md border-bottom">
      <div class="row items-center q-gutter-x-sm">
        <q-icon name="ph ph-folders" size="20px" color="primary" />
        <span class="text-subtitle1 text-weight-bold text-grey-9">Sections & Invoices</span>
        <q-badge
          color="primary"
          rounded
          class="q-px-xs text-weight-bold"
        >
          {{ sectionsWithCalculations.length }}
        </q-badge>
      </div>

      <div class="row items-center q-gutter-xs">
        <q-btn
          v-if="isEditable"
          color="primary"
          unelevated
          dense
          no-caps
          size="sm"
          icon="ph ph-plus"
          label="Add Section"
          class="q-px-sm rounded-sq-btn"
          style="border-radius: 8px"
          @click="openAddSection"
        />
      </div>
    </q-card-section>

    <!-- Body / Section List -->
    <q-card-section class="q-pa-none">
      <div v-if="loading" class="q-pa-md text-center">
        <q-spinner color="primary" size="24px" />
        <div class="text-caption text-grey-6 q-mt-xs">Loading sections...</div>
      </div>

      <div v-else-if="!sectionsWithCalculations.length" class="q-pa-lg text-center text-grey-6">
        <q-icon name="ph ph-folder-dashed" size="36px" color="grey-4" />
        <div class="text-body2 text-grey-7 q-mt-xs">No vendor sections created yet</div>
        <div class="text-caption text-grey-5 q-mb-sm">Add sections to group items and invoices by vendor.</div>
        <q-btn
          v-if="isEditable"
          color="primary"
          unelevated
          dense
          no-caps
          size="sm"
          icon="ph ph-plus"
          label="Create Initial Section"
          style="border-radius: 8px"
          @click="openAddSection"
        />
      </div>

      <q-list v-else separator class="sections-list">
        <q-item
          v-for="(sec, idx) in sectionsWithCalculations"
          :key="sec.id"
          class="section-row q-py-sm q-px-md items-center"
        >
          <!-- Left: Vendor avatar + Section & invoice info -->
          <q-item-section avatar class="q-pr-sm" style="min-width: 44px">
            <q-avatar
              square
              rounded
              color="grey-3"
              text-color="grey-9"
              size="38px"
              class="text-weight-bold text-caption"
              style="border-radius: 6px"
            >
              {{ (sec.vendor?.name || 'V').slice(0, 2).toUpperCase() }}
            </q-avatar>
          </q-item-section>

          <q-item-section class="min-width-0">
            <div class="row items-center q-gutter-x-xs no-wrap">
              <span class="text-weight-bolder text-grey-9 text-subtitle2 ellipsis">
                {{ sec.title }}
              </span>
              <q-badge
                v-if="sec.vendor?.name"
                color="grey-2"
                text-color="grey-9"
                class="q-ml-xs text-weight-medium"
                style="border-radius: 4px; font-size: 11px"
              >
                {{ sec.vendor.name }}
              </q-badge>
            </div>

            <!-- Invoice & Notes Badges -->
            <div class="row items-center q-gutter-xs q-mt-2xs wrap">
              <span
                v-if="sec.metadata?.invoice_number"
                class="text-caption text-grey-7 row items-center q-gutter-x-2xs"
                style="font-size: 11px"
              >
                <q-icon name="ph ph-receipt" size="13px" color="grey-6" />
                <span>Inv: <strong class="text-grey-9">{{ sec.metadata.invoice_number }}</strong></span>
              </span>

              <span
                v-if="sec.metadata?.invoice_date"
                class="text-caption text-grey-6 row items-center q-gutter-x-2xs"
                style="font-size: 11px"
              >
                <q-icon name="ph ph-calendar" size="13px" color="grey-6" />
                <span>{{ sec.metadata.invoice_date }}</span>
              </span>

              <span
                v-if="sec.metadata?.notes"
                class="text-caption text-grey-6 ellipsis"
                style="font-size: 11px; max-width: 250px"
              >
                • {{ sec.metadata.notes }}
              </span>
            </div>
          </q-item-section>

          <!-- Middle: Items count & Weight metrics -->
          <q-item-section side class="items-end q-px-sm">
            <div class="row items-center q-gutter-x-xs">
              <q-chip
                dense
                square
                size="sm"
                color="blue-1"
                text-color="primary"
                class="text-weight-bold"
                style="border-radius: 4px"
              >
                {{ sec.item_count }} {{ sec.item_count === 1 ? 'item' : 'items' }} ({{ sec.units_count }} pcs)
              </q-chip>
              <q-chip
                dense
                square
                size="sm"
                color="grey-2"
                text-color="grey-8"
                style="border-radius: 4px"
              >
                {{ sec.weight_kg.toFixed(2) }} kg
              </q-chip>
            </div>
          </q-item-section>

          <!-- Right: Open Items CTA & Actions Menu -->
          <q-item-section side class="items-center no-wrap">
            <div class="row items-center q-gutter-x-xs">
              <q-btn
                unelevated
                dense
                no-caps
                size="sm"
                color="primary"
                class="q-px-sm rounded-sq-btn text-weight-bold"
                style="border-radius: 6px"
                @click="openSectionItems(sec.id)"
              >
                <span>Open Items</span>
                <q-icon name="ph ph-arrow-right" size="14px" class="q-ml-2xs" />
              </q-btn>

              <q-btn
                v-if="isEditable"
                flat
                round
                dense
                icon="ph ph-dots-three-vertical"
                size="sm"
                color="grey-7"
              >
                <q-menu auto-close dense>
                  <q-list style="min-width: 140px">
                    <q-item clickable @click="openEditSection(sec)">
                      <q-item-section avatar style="min-width: 28px">
                        <q-icon name="ph ph-pencil-simple" size="16px" />
                      </q-item-section>
                      <q-item-section>Edit Section</q-item-section>
                    </q-item>
                    <q-separator />
                    <q-item
                      clickable
                      class="text-negative"
                      :disable="sectionsWithCalculations.length <= 1"
                      @click="confirmDeleteSection(sec)"
                    >
                      <q-item-section avatar style="min-width: 28px">
                        <q-icon name="ph ph-trash" size="16px" />
                      </q-item-section>
                      <q-item-section>
                        Delete Section
                        <q-tooltip v-if="sectionsWithCalculations.length <= 1">
                          Shipments must have at least one section.
                        </q-tooltip>
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </div>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card-section>

    <!-- Footer: Full Review CTA -->
    <q-card-section class="bg-grey-1 q-py-sm q-px-md border-top row items-center justify-between wrap q-gutter-y-xs">
      <div class="text-caption text-grey-7">
        Total: <strong>{{ totalItemsCount }}</strong> items across <strong>{{ sectionsWithCalculations.length }}</strong> {{ sectionsWithCalculations.length === 1 ? 'vendor section' : 'vendor sections' }}
      </div>
      <q-btn
        outline
        dense
        no-caps
        size="sm"
        color="primary"
        icon="ph ph-magnifying-glass"
        label="View Full Review (All Items)"
        class="q-px-sm rounded-sq-btn text-weight-bold"
        style="border-radius: 8px"
        @click="openAllItemsReview"
      />
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuasar } from 'quasar';
import { useRouter, useRoute } from 'vue-router';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { ShipmentSection } from '../types/shipmentSection';
import ShipmentSectionFormDialog from './ShipmentSectionFormDialog.vue';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  shipmentId: number;
  loading?: boolean;
  isEditable?: boolean;
}>();

const $q = useQuasar();
const router = useRouter();
const route = useRoute();
const shipmentStore = useGlobalShipmentStore();

interface SectionWithCalculations extends ShipmentSection {
  item_count: number;
  units_count: number;
  weight_kg: number;
}

const sectionsWithCalculations = computed<SectionWithCalculations[]>(() => {
  const sections = shipmentStore.currentShipmentSections ?? [];
  const items = shipmentStore.currentShipmentItems ?? [];

  return sections.map((sec) => {
    // Match items explicitly tagged with section_id or if single section, include untagged items
    const secItems = items.filter(
      (item) => item.section_id === sec.id || (sections.length === 1 && item.section_id == null),
    );
    const units = secItems.reduce((acc, it) => acc + (Number(it.ordered_quantity) || 0), 0);
    const weight = secItems.reduce((acc, it) => {
      const pWeight = Number(it.product_weight) || 0;
      const pkgWeight = Number(it.package_weight) || 0;
      const qty = Number(it.ordered_quantity) || 0;
      const w = pkgWeight > 0 ? pkgWeight : pWeight * qty;
      return acc + w;
    }, 0);

    return {
      ...sec,
      item_count: secItems.length,
      units_count: units,
      weight_kg: weight,
    };
  });
});

const totalItemsCount = computed(() => {
  return (shipmentStore.currentShipmentItems ?? []).length;
});

const openAddSection = () => {
  $q.dialog({
    component: ShipmentSectionFormDialog,
    componentProps: {
      shipmentId: props.shipmentId,
    },
  }).onOk(() => {
    showSuccessNotification('Section created');
  });
};

const openEditSection = (section: ShipmentSection) => {
  $q.dialog({
    component: ShipmentSectionFormDialog,
    componentProps: {
      shipmentId: props.shipmentId,
      section,
    },
  }).onOk(() => {
    showSuccessNotification('Section updated');
  });
};

const confirmDeleteSection = (section: ShipmentSection) => {
  if (sectionsWithCalculations.value.length <= 1) {
    showErrorNotification('A shipment must have at least one section.');
    return;
  }

  $q.dialog({
    title: 'Delete Section',
    message: `Are you sure you want to delete section "${section.title}"? Items in this section will become unassigned.`,
    cancel: true,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: false,
      unelevated: true,
    },
  }).onOk(async () => {
    try {
      await shipmentStore.deleteSection(section.id);
      showSuccessNotification('Section deleted');
    } catch (err: unknown) {
      showErrorNotification((err as Error).message || 'Failed to delete section');
    }
  });
};

const openSectionItems = (sectionId: number) => {
  const tenantSlug = route.params.tenantSlug;
  const targetName = 'app-procurement-shipment-items';
  const query = { sectionId: String(sectionId) };

  if (tenantSlug) {
    void router.push({
      name: targetName,
      params: { tenantSlug, id: props.shipmentId },
      query,
    });
  } else {
    void router.push({
      name: targetName,
      params: { id: props.shipmentId },
      query,
    });
  }
};

const openAllItemsReview = () => {
  const tenantSlug = route.params.tenantSlug;
  const targetName = 'app-procurement-shipment-items';

  if (tenantSlug) {
    void router.push({
      name: targetName,
      params: { tenantSlug, id: props.shipmentId },
    });
  } else {
    void router.push({
      name: targetName,
      params: { id: props.shipmentId },
    });
  }
};
</script>

<style scoped>
.sections-card {
  border-radius: 12px;
}

.border-bottom {
  border-bottom: 1px solid var(--q-separator-color, #e2e8f0);
}

.border-top {
  border-top: 1px solid var(--q-separator-color, #e2e8f0);
}

.section-row {
  transition: background-color 0.15s ease;
}

.section-row:hover {
  background-color: #f8fafc;
}

.min-width-0 {
  min-width: 0;
}

.rounded-sq-btn {
  border-radius: 8px;
}
</style>

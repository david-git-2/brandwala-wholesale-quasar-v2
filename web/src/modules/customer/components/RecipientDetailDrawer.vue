<template>
  <q-drawer
    :model-value="modelValue"
    side="right"
    overlay
    bordered
    :width="560"
    class="bg-surface recipient-drawer"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div v-if="recipient" class="column full-height no-wrap">
      <!-- 1. Drawer Header -->
      <div class="q-pa-md border-bottom row items-center justify-between header-surface">
        <div class="row items-center no-wrap ellipsis">
          <q-avatar
            size="40px"
            color="grey-3"
            text-color="grey-9"
            class="q-mr-sm text-weight-bold flex-shrink-0 item-avatar"
          >
            {{ getInitials(recipient.name) }}
          </q-avatar>
          <div class="ellipsis">
            <div class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
              {{ recipient.name }}
            </div>
            <div class="text-caption text-grey-7">Recipient Details &amp; Delivery Profile</div>
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" @click="$emit('update:modelValue', false)" />
      </div>

      <!-- 2. Scrollable Read-Only Details -->
      <div class="col scroll q-pa-md column q-gutter-y-md">
        <!-- Section: Primary Contact -->
        <div class="detail-card q-pa-md column q-gutter-y-sm">
          <div class="section-heading">Contact Information</div>

          <div class="info-grid">
            <div class="info-item">
              <span class="info-label">Full Name</span>
              <span class="info-value text-weight-medium text-grey-9">{{ recipient.name }}</span>
            </div>

            <div v-if="isParentTenant && recipient.tenant_name" class="info-item">
              <span class="info-label">Issuing Brand / Tenant</span>
              <span class="info-value">
                <span class="tenant-badge">
                  <q-icon name="ph ph-buildings" size="13px" class="q-mr-xs" />
                  {{ recipient.tenant_name }}
                </span>
              </span>
            </div>

            <div class="info-item">
              <span class="info-label">Primary Phone</span>
              <div class="row items-center no-wrap q-gutter-xs">
                <span class="info-value text-weight-medium text-grey-9">{{ recipient.phone }}</span>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  @click="copyText(recipient.phone, 'Phone number copied')"
                >
                  <q-tooltip>Copy phone</q-tooltip>
                </q-btn>
              </div>
            </div>

            <div class="info-item">
              <span class="info-label">Secondary Phone</span>
              <span class="info-value text-grey-8">
                {{ recipient.secondary_phone || '—' }}
              </span>
            </div>
          </div>
        </div>

        <!-- Section: Delivery Location -->
        <div class="detail-card q-pa-md column q-gutter-y-sm">
          <div class="section-heading">Delivery Address</div>

          <div class="info-grid">
            <div class="info-item">
              <span class="info-label">District</span>
              <span class="info-value text-grey-9">{{ recipient.district || '—' }}</span>
            </div>

            <div class="info-item">
              <span class="info-label">Thana / Upazila</span>
              <span class="info-value text-grey-9">{{ recipient.thana || '—' }}</span>
            </div>
          </div>

          <div class="info-item full-width q-mt-xs">
            <span class="info-label">Full Address</span>
            <div class="address-box q-pa-sm rounded-borders text-body2 text-grey-9">
              <q-icon name="ph ph-map-pin" size="16px" class="q-mr-xs text-grey-6 flex-shrink-0" />
              <span>{{ recipient.address || '—' }}</span>
            </div>
          </div>

          <!-- Multiple Saved Addresses if available -->
          <div v-if="hasMultipleAddresses" class="column q-gutter-y-xs q-mt-sm">
            <span class="info-label">Additional Saved Addresses</span>
            <div
              v-for="(addr, idx) in formattedAddresses"
              :key="idx"
              class="address-box address-box--secondary q-pa-xs rounded-borders text-caption text-grey-8"
            >
              {{ addr }}
            </div>
          </div>
        </div>

        <!-- Section: Timestamps / Metadata -->
        <div class="detail-card q-pa-md column q-gutter-y-sm">
          <div class="section-heading">Record Info</div>

          <div class="info-grid">
            <div class="info-item">
              <span class="info-label">Created At</span>
              <span class="info-value text-caption text-grey-7">{{ formatDate(recipient.created_at) }}</span>
            </div>

            <div class="info-item">
              <span class="info-label">Last Updated</span>
              <span class="info-value text-caption text-grey-7">{{ formatDate(recipient.updated_at) }}</span>
            </div>
          </div>
        </div>

        <!-- Danger Zone -->
        <div class="danger-zone-section column q-gutter-y-sm q-mt-sm">
          <div class="section-heading text-negative">Danger zone</div>
          <div class="danger-zone-card q-pa-md row items-center justify-between no-wrap">
            <div>
              <div class="text-weight-bold text-grey-9">Delete this recipient profile</div>
              <div class="text-caption text-grey-7">
                Permanently remove this delivery profile and all associated contact records.
              </div>
            </div>
            <q-btn
              unelevated
              color="negative"
              no-caps
              label="Delete recipient"
              class="action-btn text-weight-bold q-px-md flex-shrink-0"
              @click="openDeleteDialog"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Delete Recipient Confirmation Dialog with Typed Confirmation -->
    <q-dialog v-model="deleteConfirmOpen" persistent>
      <q-card style="min-width: 400px; max-width: 480px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div class="row items-center text-negative">
            <q-icon name="ph ph-warning-octagon" size="22px" class="q-mr-xs" />
            <div class="text-subtitle1 text-weight-bold">Delete Recipient Profile</div>
          </div>
          <q-space />
          <q-btn v-close-popup icon="ph ph-x" flat round dense />
        </q-card-section>

        <q-card-section class="q-pt-md column q-gutter-y-sm">
          <div class="text-body2 text-grey-8">
            This action <strong>cannot be undone</strong>. This will permanently delete recipient
            profile <strong>{{ recipient?.name }}</strong>.
          </div>

          <div class="text-caption text-grey-7 q-mt-sm">
            Please type <strong>{{ recipient?.name }}</strong> to confirm:
          </div>

          <q-input
            v-model="deleteConfirmationInput"
            outlined
            dense
            autofocus
            :placeholder="recipient?.name"
            class="soft-input"
            @keyup.enter="isDeleteMatching && onConfirmDelete()"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md q-pt-none">
          <q-btn flat no-caps label="Cancel" v-close-popup class="action-btn" />
          <q-btn
            unelevated
            color="negative"
            no-caps
            label="I understand, delete"
            :disable="!isDeleteMatching"
            :loading="recipientStore.saving"
            class="action-btn text-weight-bold"
            @click="onConfirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import type { RecipientProfile } from 'src/types/recipientProfile';
import { useRecipientProfileStore } from 'src/modules/sales_invoice/stores/recipientProfileStore';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  recipient: RecipientProfile | null;
  isParentTenant?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'deleted', id: number): void;
}>();

const recipientStore = useRecipientProfileStore();

const deleteConfirmOpen = ref(false);
const deleteConfirmationInput = ref('');

const isDeleteMatching = computed(() => {
  if (!props.recipient?.name) return false;
  return deleteConfirmationInput.value.trim() === props.recipient.name.trim();
});

const openDeleteDialog = () => {
  deleteConfirmationInput.value = '';
  deleteConfirmOpen.value = true;
};

const onConfirmDelete = async () => {
  if (!isDeleteMatching.value || !props.recipient?.id) return;
  const id = props.recipient.id;
  const res = await recipientStore.deleteRecipientProfile(id);
  if (res.success) {
    deleteConfirmOpen.value = false;
    emit('update:modelValue', false);
    emit('deleted', id);
  }
};

const getInitials = (name?: string | null) => {
  if (!name) return 'R';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'R';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'R';
};

const formatDate = (iso?: string | null) => {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const copyText = async (text: string, successMsg: string) => {
  try {
    await navigator.clipboard.writeText(text);
    showSuccessNotification(successMsg);
  } catch {
    showErrorNotification('Failed to copy to clipboard.');
  }
};

const formattedAddresses = computed(() => {
  const addrs = props.recipient?.addresses;
  if (!addrs) return [];
  if (Array.isArray(addrs)) {
    return addrs
      .map((item) => (typeof item === 'string' ? item : item?.address || JSON.stringify(item)))
      .filter(Boolean);
  }
  return [];
});

const hasMultipleAddresses = computed(() => formattedAddresses.value.length > 0);
</script>

<style scoped>
.recipient-drawer {
  background: #ffffff;
}

.header-surface {
  background: #f8fafc;
}

.border-bottom {
  border-bottom: 1px solid rgba(226, 232, 240, 0.9);
}

.action-btn {
  border-radius: 8px !important;
}

.item-avatar {
  background: #e2e8f0;
  color: #475569;
  font-size: 13px;
  font-weight: 600;
  border-radius: 8px;
}

.section-heading {
  font-size: 11.5px;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: #64748b;
}

.detail-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.info-label {
  font-size: 11px;
  font-weight: 500;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.info-value {
  font-size: 13px;
  color: #1e293b;
  word-break: break-word;
}

.address-box {
  display: flex;
  align-items: flex-start;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  line-height: 1.4;
}

.address-box--secondary {
  background: #f1f5f9;
  border-color: #e2e8f0;
}

.tenant-badge {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 4px;
  background: #eff6ff;
  color: #1d4ed8;
  font-size: 12px;
  font-weight: 600;
}

.danger-zone-card {
  border: 1px solid #fecaca;
  background: #fef2f2;
  border-radius: 8px;
}

.soft-input :deep(.q-field__control) {
  min-height: 40px;
  border-radius: 8px;
}

/* Dark mode */
body.body--dark .recipient-drawer,
body.body--dark .header-surface {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

body.body--dark .detail-card {
  background: #242424;
  border-color: #2e2e2e;
}

body.body--dark .address-box {
  background: #1c1c1c;
  border-color: #334155;
  color: #f1f5f9;
}

body.body--dark .address-box--secondary {
  background: #262626;
  border-color: #334155;
}

body.body--dark .info-value {
  color: #f1f5f9;
}

body.body--dark .tenant-badge {
  background: #1e3a8a;
  color: #93c5fd;
}

body.body--dark .danger-zone-card {
  border-color: #7f1d1d;
  background: rgba(127, 29, 29, 0.15);
}

body.body--dark .item-avatar {
  background: #334155;
  color: #e2e8f0;
}
</style>

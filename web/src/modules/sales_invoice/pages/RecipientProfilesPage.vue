<template>
  <q-page class="q-pa-md recipient-profiles-page">
    <!-- Header Hero Card -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Recipient Profiles</div>
            <div class="text-caption text-grey-8">
              Manage saved delivery addresses and end-customer profiles for retail and dropship
              invoices
            </div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn hover-elevate"
              label="Create Recipient Profile"
              icon="add"
              @click="openCreateDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Toolbar -->
    <div class="row items-center justify-between q-mb-md">
      <div class="row items-center q-gutter-sm toolbar-left">
        <q-btn
          v-if="!showSearchInput"
          flat
          round
          dense
          icon="search"
          aria-label="Show search"
          @click="showSearchInput = true"
        />
        <q-input
          v-else
          v-model="searchText"
          filled
          dense
          clearable
          class="soft-input toolbar-search"
          label="Search by name, phone, address..."
          @clear="onClearSearch"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
          <template #append>
            <q-btn flat round dense icon="close" aria-label="Hide search" @click="onCloseSearch" />
          </template>
        </q-input>
      </div>
    </div>

    <!-- Main Table Card -->
    <q-card flat class="floating-surface shadow-1">
      <q-markup-table flat wrap-cells class="recipient-profiles-table">
        <thead>
          <tr>
            <th class="text-left">Name</th>
            <th class="text-left">Phone</th>
            <th class="text-left">Address</th>
            <th class="text-right" style="width: 80px">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="store.loading">
            <td colspan="4" class="text-center q-py-lg">
              <q-spinner color="primary" size="2em" />
              <div class="text-caption text-grey-6 q-mt-xs">Loading profiles...</div>
            </td>
          </tr>
          <tr v-else-if="!filteredItems.length">
            <td colspan="4" class="text-center text-grey-7 q-py-xl">
              <q-icon name="contacts" size="36px" class="text-grey-4 q-mb-xs" />
              <div>No recipient profiles found.</div>
            </td>
          </tr>
          <tr v-for="row in filteredItems" :key="row.id" class="hover-row">
            <td>
              <div class="row items-center no-wrap">
                <q-avatar size="28px" color="indigo-1" text-color="indigo" class="q-mr-sm">
                  {{ row.name.charAt(0).toUpperCase() }}
                </q-avatar>
                <span class="text-weight-medium">{{ row.name }}</span>
              </div>
            </td>
            <td>
              <div class="row items-center no-wrap">
                <q-icon name="phone" size="14px" class="text-grey-6 q-mr-xs" />
                <span>{{ row.phone }}</span>
              </div>
            </td>
            <td>
              <div class="row items-center">
                <q-icon name="place" size="14px" class="text-grey-6 q-mr-xs" />
                <span class="ellipsis-2-lines">{{ row.address }}</span>
              </div>
            </td>
            <td class="text-right">
              <q-btn flat round dense icon="more_vert">
                <q-menu auto-close class="menu-surface shadow-2">
                  <q-list dense style="min-width: 140px">
                    <q-item clickable class="menu-item" @click="onOpenEdit(row)">
                      <q-item-section avatar class="min-w-0-avatar">
                        <q-icon name="edit" size="16px" />
                      </q-item-section>
                      <q-item-section>Edit</q-item-section>
                    </q-item>
                    <q-item clickable class="text-negative menu-item" @click="onOpenDelete(row.id)">
                      <q-item-section avatar class="min-w-0-avatar">
                        <q-icon name="delete" size="16px" color="negative" />
                      </q-item-section>
                      <q-item-section>Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>

    <!-- Create / Edit Dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="min-width: 420px; border-radius: 16px">
        <q-card-section class="q-pb-none">
          <div class="text-h6 text-weight-bold">
            {{ isEditMode ? 'Edit Recipient Profile' : 'Create Recipient Profile' }}
          </div>
          <div class="text-caption text-grey-6">Fill in the delivery details below</div>
        </q-card-section>

        <q-form @submit="onFormSubmit">
          <q-card-section class="q-gutter-md q-pt-md">
            <q-input
              v-model="form.name"
              label="Recipient Name *"
              filled
              dense
              class="soft-input"
              lazy-rules
              :rules="[(val) => (val && val.trim().length > 0) || 'Name is required']"
            />
            <q-input
              v-model="form.phone"
              label="Phone Number *"
              filled
              dense
              class="soft-input"
              lazy-rules
              :rules="[(val) => (val && val.trim().length > 0) || 'Phone is required']"
            />
            <q-input
              v-model="form.address"
              label="Delivery Address *"
              filled
              type="textarea"
              rows="3"
              class="soft-input"
              lazy-rules
              :rules="[(val) => (val && val.trim().length > 0) || 'Address is required']"
            />
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat no-caps label="Cancel" v-close-popup class="pill-btn" />
            <q-btn
              color="primary"
              no-caps
              :label="isEditMode ? 'Save Changes' : 'Create Profile'"
              :loading="store.saving"
              type="submit"
              class="pill-btn hover-elevate px-md"
            />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>

    <!-- Delete Confirmation Dialog -->
    <q-dialog v-model="deleteOpen">
      <q-card style="min-width: 320px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Delete Recipient Profile</q-card-section>
        <q-card-section class="text-body2 text-grey-7">
          Are you sure you want to delete this recipient profile? Invoices currently using this
          profile will not be deleted, but the profile will be removed from the catalog.
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="negative"
            no-caps
            label="Delete"
            :loading="store.saving"
            @click="onDelete"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, reactive } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useRecipientProfileStore } from '../stores/recipientProfileStore';
import type { RecipientProfile } from 'src/types/recipientProfile';

const authStore = useAuthStore();
const store = useRecipientProfileStore();

const showSearchInput = ref(false);
const searchText = ref('');
const dialogOpen = ref(false);
const isEditMode = ref(false);
const deleteOpen = ref(false);
const selectedId = ref<number | null>(null);

const form = reactive({
  name: '',
  phone: '',
  address: '',
});

const filteredItems = computed(() => {
  const search = searchText.value.trim().toLowerCase();
  if (!search) return store.items;
  return store.items.filter((row) =>
    [row.name, row.phone, row.address].some((val) => val.toLowerCase().includes(search)),
  );
});

const load = async () => {
  if (!authStore.tenantId) return;
  await store.fetchRecipientProfiles(authStore.tenantId);
};

const openCreateDialog = () => {
  isEditMode.value = false;
  form.name = '';
  form.phone = '';
  form.address = '';
  dialogOpen.value = true;
};

const onOpenEdit = (row: RecipientProfile) => {
  isEditMode.value = true;
  selectedId.value = row.id;
  form.name = row.name;
  form.phone = row.phone;
  form.address = row.address;
  dialogOpen.value = true;
};

const onOpenDelete = (id: number) => {
  selectedId.value = id;
  deleteOpen.value = true;
};

const onFormSubmit = async () => {
  if (!authStore.tenantId) return;

  if (isEditMode.value && selectedId.value) {
    const res = await store.updateRecipientProfile({
      id: selectedId.value,
      patch: {
        name: form.name.trim(),
        phone: form.phone.trim(),
        address: form.address.trim(),
      },
    });
    if (res.success) {
      dialogOpen.value = false;
    }
  } else {
    const res = await store.createRecipientProfile({
      tenant_id: authStore.tenantId,
      name: form.name.trim(),
      phone: form.phone.trim(),
      address: form.address.trim(),
    });
    if (res.success) {
      dialogOpen.value = false;
    }
  }
};

const onDelete = async () => {
  if (!selectedId.value) return;
  const res = await store.deleteRecipientProfile(selectedId.value);
  if (res.success) {
    deleteOpen.value = false;
    selectedId.value = null;
  }
};

const onClearSearch = () => {
  searchText.value = '';
};

const onCloseSearch = () => {
  showSearchInput.value = false;
  searchText.value = '';
};

onMounted(load);
</script>

<style scoped>
.recipient-profiles-page {
  background: transparent;
}
.hero-surface {
  border-radius: 16px;
}
.pill-btn {
  border-radius: 999px;
}
.slim-btn {
  min-height: 32px;
  padding-left: 14px;
  padding-right: 14px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
.toolbar-left {
  min-width: 0;
}
.toolbar-search {
  width: min(320px, 75vw);
}
.recipient-profiles-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
  font-weight: 700;
  color: #2c3e50;
}
.hover-row {
  transition: background-color 0.2s ease;
}
.hover-row:hover {
  background-color: rgba(34, 56, 101, 0.02);
}
.hover-elevate {
  transition:
    transform 0.2s ease,
    box-shadow 0.2s ease;
}
.hover-elevate:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
}
.min-w-0-avatar {
  min-width: 32px !important;
}
</style>

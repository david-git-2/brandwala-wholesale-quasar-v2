<template>
  <q-card flat class="floating-surface shadow-1">
    <q-card-section class="row items-center justify-between">
      <div>
        <div class="text-subtitle1 text-weight-bold text-grey-9">Module Features</div>
        <div class="text-caption text-grey-7">
          Manage which modules are active for this workspace.
        </div>
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section v-if="isLoading" class="text-grey-7">
      Loading module features...
    </q-card-section>

    <q-card-section v-else>
      <div class="row q-col-gutter-md">
        <div v-if="canManageModules" class="col-12 col-md-6">
          <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-8">
            Available Features
          </div>
          <q-list bordered separator class="rounded-borders">
            <template v-for="feature in availableModules" :key="feature.key">
              <q-item>
                <q-item-section>
                  <q-item-label class="text-weight-medium">{{ feature.name }}</q-item-label>
                  <q-item-label caption>{{ feature.key }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-btn
                    color="primary"
                    dense
                    flat
                    no-caps
                    label="Add"
                    @click="emit('add-feature', feature.key)"
                  />
                </q-item-section>
              </q-item>
              <div
                v-if="moduleStore.submodulesOf(feature.key).length > 0"
                class="q-pl-lg q-pb-sm q-pr-md"
              >
                <div class="text-caption text-grey-7 q-mb-xs">Includes submodules:</div>
                <q-list dense bordered class="bg-grey-1 rounded-borders">
                  <q-item
                    v-for="sub in moduleStore.submodulesOf(feature.key)"
                    :key="sub.key"
                    class="q-py-xs"
                  >
                    <q-item-section>
                      <q-item-label class="text-caption text-weight-medium text-grey-8">{{
                        sub.name
                      }}</q-item-label>
                      <q-item-label caption class="text-caption">{{ sub.key }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </div>
            </template>
            <q-item v-if="availableModules.length === 0">
              <q-item-section class="text-grey-7">No available features.</q-item-section>
            </q-item>
          </q-list>
        </div>

        <div :class="canManageModules ? 'col-12 col-md-6' : 'col-12'">
          <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-8">
            Workspace Features
          </div>
          <q-list bordered separator class="rounded-borders">
            <template v-for="feature in modules" :key="feature.id">
              <q-item>
                <q-item-section>
                  <q-item-label class="text-weight-medium">{{
                    formatModuleKey(feature.module_key)
                  }}</q-item-label>
                  <q-item-label caption>
                    {{ feature.is_active ? 'Active' : 'Inactive' }}
                  </q-item-label>
                </q-item-section>
                <q-item-section side v-if="canManageModules">
                  <q-btn
                    color="negative"
                    dense
                    flat
                    no-caps
                    label="Remove"
                    @click="emit('remove-feature', feature.id)"
                  />
                </q-item-section>
              </q-item>

              <!-- Submodule panel -->
              <div v-if="tenantId" class="q-pl-md q-pr-md q-pb-xs">
                <SubmoduleAccessPanel
                  :tenant-id="tenantId"
                  :parent-module-key="feature.module_key"
                  :read-only="!canManageModules"
                />
              </div>
            </template>
            <q-item v-if="modules.length === 0">
              <q-item-section class="text-grey-7"
                >No features active for this workspace.</q-item-section
              >
            </q-item>
          </q-list>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { useModuleStore } from 'src/modules/featureCatalog/stores/moduleStore';
import SubmoduleAccessPanel from 'src/modules/tenant/components/SubmoduleAccessPanel.vue';

interface FeatureModule {
  id: number;
  module_key: string;
  is_active: boolean;
}

interface CatalogModule {
  key: string;
  name: string;
  parent_module_key?: string | null;
}

interface Props {
  tenantId: number | null;
  canManageModules: boolean;
  isLoading: boolean;
  availableModules: CatalogModule[];
  modules: FeatureModule[];
}

defineProps<Props>();

const emit = defineEmits<{
  (e: 'add-feature', moduleKey: string): void;
  (e: 'remove-feature', id: number): void;
}>();

const moduleStore = useModuleStore();

const formatModuleKey = (key: string): string => {
  return key
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};
</script>

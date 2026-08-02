<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 560px; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <div>
          <div class="text-h6 text-weight-bold">Access Overrides</div>
          <div class="text-caption text-grey-7">
            Configure explicit Allow/Deny overrides for
            <strong>{{ member?.email }}</strong>
            <span v-if="roleName">
              · Role: <strong>{{ roleName }}</strong>
            </span>.
          </div>
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-py-md">
        <div v-if="loading" class="row justify-center q-my-md">
          <q-spinner-dots size="30px" color="primary" />
        </div>
        <div v-else-if="groupedActions.length === 0" class="text-center text-grey-6 q-my-md">
          No configurable modules active for this workspace.
        </div>
        <div v-else style="max-height: 480px; overflow-y: auto">
          <div
            v-for="group in groupedActions"
            :key="group.displayKey"
            class="q-mb-md border-radius-inherit"
          >
            <div class="bg-grey-2 q-px-sm q-py-xs text-weight-bold text-subtitle2 text-grey-9 rounded-borders q-mb-xs row items-center justify-between">
              <span>{{ group.displayTitle }}</span>
              <span class="text-caption text-grey-6 font-mono">{{ group.grantModuleKey }}</span>
            </div>
            <q-list separator bordered class="rounded-borders">
              <q-item v-for="act in group.actions" :key="act.id ?? `${act.module_key}:${act.action}`" class="q-py-sm">
                <q-item-section>
                  <div class="row items-center q-gutter-xs">
                    <q-chip
                      dense
                      square
                      class="text-weight-bold text-uppercase"
                      :style="getActionChipStyle(act.action)"
                    >
                      {{ act.action }}
                    </q-chip>
                  </div>
                  <q-item-label v-if="act.description" caption class="text-grey-6 q-mt-xs">
                    {{ act.description }}
                  </q-item-label>
                  <q-item-label caption class="q-mt-xs">
                    <span class="text-grey-7">Role default: </span>
                    <q-badge
                      dense
                      class="q-px-xs"
                      :color="
                        inheritedGrants[`${act.module_key}:${act.action}`]
                          ? 'positive'
                          : 'negative'
                      "
                    >
                      {{
                        inheritedGrants[`${act.module_key}:${act.action}`]
                          ? 'Allowed'
                          : 'Denied'
                      }}
                    </q-badge>
                  </q-item-label>
                </q-item-section>

                <q-item-section side>
                  <q-btn-toggle
                    :model-value="grants[`${act.module_key}:${act.action}`] || 'inherit'"
                    toggle-color="primary"
                    color="grey-3"
                    text-color="grey-8"
                    dense
                    no-caps
                    unelevated
                    :options="overrideToggleOptions"
                    :disable="savingMap[`${act.module_key}:${act.action}`]"
                    @update:model-value="(val) => $emit('toggleOverride', act, val)"
                  />
                </q-item-section>
              </q-item>
            </q-list>
          </div>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Close" v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { groupActionsForGrantMatrix } from 'src/modules/access_control/utils/grantDisplayGroups';

const props = defineProps<{
  modelValue: boolean;
  member: any;
  roleName?: string;
  loading: boolean;
  actions: any[];
  grants: Record<string, 'allow' | 'deny' | 'inherit'>;
  inheritedGrants: Record<string, boolean>;
  savingMap: Record<string, boolean>;
}>();

defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'toggleOverride', act: any, val: 'allow' | 'deny' | 'inherit'): void;
}>();

const overrideToggleOptions = [
  { label: 'Allow', value: 'allow' },
  { label: 'Deny', value: 'deny' },
  { label: 'Default', value: 'inherit' },
];

const getActionChipStyle = (action: string) => {
  const normalized = action.toLowerCase();
  switch (normalized) {
    case 'create':
      return { backgroundColor: '#e6f4ea', color: '#137333' };
    case 'read':
    case 'view':
      return { backgroundColor: '#e8f0fe', color: '#1a73e8' };
    case 'update':
    case 'edit':
      return { backgroundColor: '#fef7e0', color: '#b06000' };
    case 'delete':
      return { backgroundColor: '#fce8e6', color: '#c5221f' };
    default:
      return { backgroundColor: '#f1f3f4', color: '#3c4043' };
  }
};

const groupedActions = computed(() => groupActionsForGrantMatrix(props.actions || []));
</script>

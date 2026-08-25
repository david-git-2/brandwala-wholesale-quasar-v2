<template>
  <q-card flat class="floating-surface shadow-1">
    <q-card-section class="row items-center justify-between">
      <div>
        <div class="text-subtitle1 text-weight-bold text-grey-9">
          Roles &amp; Permissions Matrix
        </div>
        <div class="text-caption text-grey-7">
          Create custom role templates and manage baseline feature access.
        </div>
      </div>
      <div class="row items-center q-gutter-sm">
        <q-btn-toggle
          :model-value="scopeFilter"
          toggle-color="primary"
          color="grey-3"
          text-color="grey-8"
          dense
          no-caps
          unelevated
          :options="[
            { label: 'App Internal', value: 'app' },
            { label: 'Shop / B2B', value: 'shop' },
          ]"
          @update:model-value="(val) => emit('update:scopeFilter', val)"
        />
        <q-btn
          color="primary"
          unelevated
          class="pill-btn"
          no-caps
          icon="ph ph-plus"
          label="Create Role"
          @click="emit('create-role')"
        />
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section v-if="isLoading" class="text-grey-7">
      Loading roles...
    </q-card-section>

    <q-card-section v-else>
      <div class="row q-col-gutter-md">
        <div v-for="role in filteredRoles" :key="role.id" class="col-12 col-md-6 col-lg-4">
          <q-card flat bordered class="rounded-borders">
            <q-card-section class="row items-center justify-between q-pb-xs">
              <div>
                <div class="text-subtitle1 text-weight-bold">{{ role.name }}</div>
                <div class="text-caption text-grey-6 font-mono">{{ role.slug }}</div>
              </div>
              <q-badge
                :color="role.is_admin ? 'purple' : 'grey-7'"
                dense
                class="q-px-xs"
              >
                {{ role.is_admin ? 'Admin' : 'Standard' }}
              </q-badge>
            </q-card-section>

            <q-card-actions align="right" class="q-pt-none">
              <q-btn
                flat
                dense
                no-caps
                color="primary"
                label="Grants Matrix"
                icon="ph ph-shield-check"
                @click="emit('navigate-grants', role.id)"
              />
              <q-btn
                v-if="!role.is_system"
                flat
                dense
                round
                icon="ph ph-pencil-simple"
                color="grey-7"
                @click="emit('edit-role', role)"
              />
              <q-btn
                v-if="!role.is_system"
                flat
                dense
                round
                icon="ph ph-trash"
                color="negative"
                @click="emit('delete-role', role)"
              />
            </q-card-actions>
          </q-card>
        </div>
        <div v-if="filteredRoles.length === 0" class="col-12 text-grey-7 text-center q-py-md">
          No roles defined for this scope.
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
interface Role {
  id: number;
  name: string;
  slug: string;
  is_admin: boolean;
  is_system?: boolean;
  scope?: string;
}

interface Props {
  scopeFilter: 'app' | 'shop';
  isLoading: boolean;
  filteredRoles: Role[];
}

defineProps<Props>();

const emit = defineEmits<{
  (e: 'update:scopeFilter', val: 'app' | 'shop'): void;
  (e: 'create-role'): void;
  (e: 'edit-role', role: Role): void;
  (e: 'delete-role', role: Role): void;
  (e: 'navigate-grants', roleId: number): void;
}>();
</script>

<style scoped>
.pill-btn {
  border-radius: 8px;
}
</style>

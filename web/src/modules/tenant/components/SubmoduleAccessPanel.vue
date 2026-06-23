<template>
  <div class="q-pl-md q-mt-sm">
    <div class="text-caption text-grey-7 q-mb-sm">Submodule access</div>
    <q-list dense bordered separator class="rounded-borders">
      <q-item v-for="submodule in submodules" :key="submodule.key">
        <q-item-section>
          <q-item-label>{{ submodule.name }}</q-item-label>
          <q-item-label caption>{{ submodule.key }}</q-item-label>
        </q-item-section>
        <q-item-section side>
          <q-toggle
            :model-value="isSubmoduleEnabled(submodule.key)"
            :disable="loading || readOnly"
            color="positive"
            @update:model-value="(value) => onToggle(submodule.key, value)"
          />
        </q-item-section>
      </q-item>
      <q-item v-if="submodules.length === 0">
        <q-item-section class="text-grey-7">No submodules configured.</q-item-section>
      </q-item>
    </q-list>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useModuleStore } from 'src/modules/featureCatalog/stores/moduleStore'
import { useTenantModuleStore } from '../stores/tenantModuleStore'
import type { TenantModuleSubmodule } from '../types'

const props = defineProps<{
  tenantId: number
  parentModuleKey: string
  readOnly?: boolean
}>()

const moduleStore = useModuleStore()
const tenantModuleStore = useTenantModuleStore()
const overrides = ref<TenantModuleSubmodule[]>([])
const loading = ref(false)

const submodules = computed(() => moduleStore.submodulesOf(props.parentModuleKey))

const isSubmoduleEnabled = (submoduleKey: string) => {
  const override = overrides.value.find((row) => row.submodule_key === submoduleKey)
  return override ? override.is_enabled : true
}

const loadOverrides = async () => {
  loading.value = true
  try {
    const result = await tenantModuleStore.listSubmoduleOverrides(
      props.tenantId,
      props.parentModuleKey,
    )
    overrides.value = result.success ? (result.data ?? []) : []
  } finally {
    loading.value = false
  }
}

const onToggle = async (submoduleKey: string, isEnabled: boolean) => {
  if (props.readOnly) return
  const result = await tenantModuleStore.setSubmoduleOverride({
    tenant_id: props.tenantId,
    parent_module_key: props.parentModuleKey,
    submodule_key: submoduleKey,
    is_enabled: isEnabled,
  })
  if (result.success) {
    await loadOverrides()
  }
}

onMounted(async () => {
  if (moduleStore.items.length === 0) {
    await moduleStore.fetchModules()
  }
  await loadOverrides()
})

watch(
  () => [props.tenantId, props.parentModuleKey],
  () => void loadOverrides(),
)
</script>

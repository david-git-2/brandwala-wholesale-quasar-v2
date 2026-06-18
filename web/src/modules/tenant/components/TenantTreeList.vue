<template>
  <div class="tenant-tree">
    <!-- Root Nodes -->
    <div v-for="node in treeData" :key="node.tenant.id" class="tenant-tree__root-item q-mb-md">
      <div
        class="tenant-tree__card floating-surface shadow-1 cursor-pointer q-pa-md"
        @click="$emit('click-tenant', node.tenant.id)"
      >
        <div class="row justify-between items-center q-mb-xs">
          <div class="text-overline text-primary text-weight-bold">
            Tenant #{{ node.tenant.id }}
            <span v-if="node.tenant.parent_id" class="text-grey-6 text-lowercase text-weight-regular q-ml-sm">
              (child of #{{ node.tenant.parent_id }})
            </span>
            <span v-else class="text-grey-6 text-lowercase text-weight-regular q-ml-sm">
              (parent)
            </span>
          </div>
          <q-chip
            dense
            square
            class="costing-status-chip"
            :style="node.tenant.is_active ? activeStatusStyle : inactiveStatusStyle"
          >
            <span class="status-dot" :style="{ backgroundColor: node.tenant.is_active ? '#2f8b5d' : '#66758c' }" />
            {{ node.tenant.is_active ? 'Active' : 'Inactive' }}
          </q-chip>
        </div>
        <div class="text-subtitle1 text-weight-bold text-grey-9">{{ node.tenant.name }}</div>
        <div class="text-body2 text-grey-7 q-mt-xs">
          {{ node.tenant.public_domain ? `${node.tenant.slug} | ${node.tenant.public_domain}` : node.tenant.slug }}
        </div>
      </div>

      <!-- Recursive Children list -->
      <div v-if="node.children && node.children.length" class="tenant-tree__children">
        <TenantTreeSubList
          :nodes="node.children"
          @click-tenant="$emit('click-tenant', $event)"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Tenant } from '../types'
import TenantTreeSubList from './TenantTreeSubList.vue'

interface TenantNode {
  tenant: Tenant
  children: TenantNode[]
}

const props = defineProps<{
  tenants: Tenant[]
}>()

defineEmits<{
  (e: 'click-tenant', tenantId: number): void
}>()

const activeStatusStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
  boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
}

const inactiveStatusStyle = {
  backgroundColor: '#dbe5f3',
  color: '#3b4b66',
  border: '1px solid #b9c8dd',
  boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
}

const treeData = computed(() => {
  const map = new Map<number, TenantNode>()
  
  // First pass: create nodes
  props.tenants.forEach((tenant) => {
    map.set(tenant.id, { tenant, children: [] })
  })
  
  const roots: TenantNode[] = []
  
  // Second pass: structure hierarchy
  props.tenants.forEach((tenant) => {
    const node = map.get(tenant.id)
    if (!node) return
    
    if (tenant.parent_id === null || !map.has(tenant.parent_id)) {
      roots.push(node)
    } else {
      const parentNode = map.get(tenant.parent_id)
      if (parentNode) {
        parentNode.children.push(node)
      } else {
        roots.push(node)
      }
    }
  })
  
  return roots
})
</script>

<style scoped>
.tenant-tree {
  width: 100%;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.tenant-tree__card {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.tenant-tree__card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(25, 35, 47, 0.12) !important;
}

.tenant-tree__children {
  padding-left: 28px;
  position: relative;
  border-left: 2px dashed rgba(34, 56, 101, 0.16);
  margin-left: 24px;
  margin-top: 8px;
}
</style>

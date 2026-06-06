<template>
  <q-dialog v-model="isOpen" persistent backdrop-filter="blur(4px)">
    <q-card class="form-card floating-surface shadow-2">
      <q-card-section class="q-py-md row items-center justify-between border-bottom">
        <div class="text-h6 text-weight-bold text-grey-9">
          {{ isEdit ? 'Edit Item' : 'Create New Item' }}
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-form @submit.prevent="onSave">
        <q-card-section class="q-gutter-md scroll-section">
          <!-- Type Select -->
          <q-select
            v-model="form.type"
            :options="itemTypeOptions"
            label="Item Type"
            outlined
            dense
            emit-value
            map-options
            :readonly="isEdit"
            :rules="[val => !!val || 'Type is required']"
            @update:model-value="onTypeChange"
          />

          <!-- Title -->
          <q-input
            v-model="form.title"
            label="Title"
            outlined
            dense
            :rules="[val => !!val || 'Title is required']"
          />

          <!-- Description (Markdown / Text Editor) -->
          <div>
            <div class="row items-center justify-between q-mb-xs">
              <span class="text-caption text-grey-8">Description / Details</span>
              <q-checkbox v-model="form.is_markdown" label="Use Markdown" dense />
            </div>
            <q-input
              v-if="form.is_markdown"
              v-model="form.content"
              type="textarea"
              outlined
              dense
              rows="6"
              class="bg-grey-1"
              placeholder="Write description in Markdown..."
              :input-style="{ fontFamily: 'monospace' }"
            />
            <q-editor
              v-else
              v-model="form.content"
              min-height="10rem"
              max-height="25rem"
              :toolbar="editorToolbar"
            />
          </div>

          <!-- Parent Selection -->
          <q-select
            v-if="form.type !== 'project'"
            v-model="form.parent_id"
            :options="parentOptions"
            :label="parentLabel"
            outlined
            dense
            emit-value
            map-options
            clearable
            placeholder="Select parent category"
          />

          <div class="row q-col-gutter-sm" v-if="hasStatusAndPriority">
            <!-- Status -->
            <div class="col-6">
              <q-select
                v-model="form.status"
                :options="statusOptions"
                label="Status"
                outlined
                dense
                emit-value
                map-options
              />
            </div>
            <!-- Priority -->
            <div class="col-6">
              <q-select
                v-model="form.priority"
                :options="priorityOptions"
                label="Priority"
                outlined
                emit-value
                map-options
                dense
              />
            </div>
          </div>

          <!-- Dates -->
          <div class="row q-col-gutter-sm" v-if="hasStatusAndPriority">
            <div class="col-6">
              <q-input
                v-model="form.start_date"
                label="Start Date"
                type="date"
                outlined
                dense
                stack-label
              />
            </div>
            <div class="col-6">
              <q-input
                v-model="form.due_date"
                label="Due Date"
                type="date"
                outlined
                dense
                stack-label
              />
            </div>
          </div>

          <!-- Assignees (Multi-select emails) -->
          <q-select
            v-if="hasStatusAndPriority"
            v-model="form.assigneeEmails"
            :options="memberEmails"
            label="Assignees"
            multiple
            use-chips
            outlined
            dense
          />

          <!-- Tags (Multi-select) -->
          <q-select
            v-model="form.tagIds"
            :options="tagOptions"
            label="Tags"
            multiple
            use-chips
            outlined
            dense
            emit-value
            map-options
          >
            <template v-slot:selected-item="scope">
              <q-chip
                removable
                dense
                square
                @remove="scope.removeAtIndex(scope.index)"
                :tabindex="scope.tabindex"
                :style="{ backgroundColor: getTagColor(scope.opt.value), color: '#ffffff' }"
                class="text-weight-bold text-uppercase"
              >
                {{ scope.opt.label }}
              </q-chip>
            </template>
          </q-select>

          <!-- Accessibility selection (Only shown when type is 'note') -->
          <q-select
            v-if="form.type === 'note'"
            v-model="form.accessibility"
            :options="[
              { label: 'Public - Visible to all workspace members', value: 'public' },
              { label: 'Private - Only visible to you', value: 'private' },
              { label: 'Restricted - Only visible to creator, assignees, and collaborators', value: 'restricted' }
            ]"
            label="Accessibility"
            outlined
            dense
            emit-value
            map-options
          />
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md border-top">
          <q-btn label="Cancel" color="grey" flat v-close-popup no-caps />
          <q-btn
            type="submit"
            :label="isEdit ? 'Save Changes' : 'Create'"
            color="primary"
            unelevated
            class="pill-btn"
            no-caps
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useTasksStore } from '../stores/tasksStore';
import type { Item, ItemType, ItemStatus, ItemPriority } from '../types';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const $q = useQuasar();

const props = defineProps<{
  modelValue: boolean;
  item?: Item | null;
  defaultType?: ItemType;
  defaultParentId?: number | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'saved'): void;
}>();

const tasksStore = useTasksStore();
const authStore = useAuthStore();

const editorToolbar = computed(() => {
  if ($q.screen.xs) {
    return [
      ['bold', 'italic', 'underline'],
      ['unordered', 'ordered'],
      ['undo', 'redo']
    ];
  }
  return [
    ['bold', 'italic', 'underline', 'strike'],
    ['unordered', 'ordered', 'outdent', 'indent'],
    ['quote', 'link', 'hr'],
    ['undo', 'redo'],
    ['fullscreen']
  ];
});

const isEdit = computed(() => !!props.item);
const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const form = ref({
  type: 'task' as ItemType,
  title: '',
  content: '',
  parent_id: null as number | null,
  status: 'todo' as ItemStatus,
  priority: 'medium' as ItemPriority,
  accessibility: 'public' as 'public' | 'private' | 'restricted',
  is_markdown: false,
  start_date: '',
  due_date: '',
  assigneeEmails: [] as string[],
  tagIds: [] as number[],
});

// Options Lists
const itemTypeOptions = [
  { label: 'Project', value: 'project' },
  { label: 'Module', value: 'module' },
  { label: 'Submodule', value: 'submodule' },
  { label: 'Task / Ticket', value: 'task' },
  { label: 'Feature Request', value: 'feature' },
  { label: 'Bug Report', value: 'bug' },
  { label: 'Note', value: 'note' },
  { label: 'Discussion', value: 'discussion' },
];

const statusOptions = [
  { label: 'Todo', value: 'todo' },
  { label: 'In Progress', value: 'in_progress' },
  { label: 'Review', value: 'review' },
  { label: 'Done', value: 'done' },
  { label: 'Blocked', value: 'blocked' },
  { label: 'Archived', value: 'archived' },
];

const priorityOptions = [
  { label: 'Low', value: 'low' },
  { label: 'Medium', value: 'medium' },
  { label: 'High', value: 'high' },
  { label: 'Urgent', value: 'urgent' },
];

const memberEmails = computed(() => tasksStore.members.map(m => m.email));
const tagOptions = computed(() => tasksStore.tags.map(t => ({ label: t.name, value: t.id })));

const getTagColor = (tagId: number) => {
  const tag = tasksStore.tags.find(t => t.id === tagId);
  return tag?.color || '#6366f1';
};

const hasStatusAndPriority = computed(() => {
  return ['task', 'bug', 'feature'].includes(form.value.type);
});

const parentLabel = computed(() => {
  if (form.value.type === 'module') return 'Parent Project';
  if (form.value.type === 'submodule') return 'Parent Module';
  return 'Parent Category (Project/Module/Submodule/Note)';
});

// Dynamic Parent Filtering based on hierarchy
const getDescendantIds = (rootId: number): Set<number> => {
  const seen = new Set<number>();
  const stack = [rootId];

  while (stack.length) {
    const currentId = stack.pop();
    if (currentId == null || seen.has(currentId)) continue;
    seen.add(currentId);

    tasksStore.items
      .filter((i) => i.parent_id === currentId)
      .forEach((child) => stack.push(child.id));
  }

  seen.delete(rootId);
  return seen;
};

const getHierarchyPrefix = (item: Item) => {
  if (item.type === 'project') return '[PROJECT]';
  if (item.type === 'module') return '[MODULE]';
  if (item.type === 'submodule') return '[SUBMODULE]';
  if (item.type === 'note') return '[NOTE]';
  return `[${item.type.toUpperCase()}]`;
};

const isAllowedParentType = (type: ItemType, parentType: ItemType) => {
  if (type === 'project') return false;
  if (type === 'module') return parentType === 'project';
  if (type === 'submodule') return parentType === 'module';
  if (type === 'note') return ['project', 'module', 'submodule', 'note'].includes(parentType);
  return ['project', 'module', 'submodule', 'note'].includes(parentType);
};

const parentOptions = computed(() => {
  const currentItemId = props.item?.id ?? null;
  const forbiddenIds = currentItemId ? getDescendantIds(currentItemId) : new Set<number>();
  if (currentItemId) forbiddenIds.add(currentItemId);

  const baseItems = tasksStore.items.filter((i) => !forbiddenIds.has(i.id));

  if (form.value.type === 'module') {
    return baseItems
      .filter((i) => i.type === 'project')
      .map((i) => ({ label: i.title, value: i.id }));
  }
  if (form.value.type === 'submodule') {
    return baseItems
      .filter((i) => i.type === 'module')
      .map((i) => ({ label: `${getHierarchyPrefix(i)} ${i.title}`, value: i.id }));
  }
  // Tasks, bugs, features, discussions, and notes can belong to higher-level containers.
  return baseItems
    .filter((i) => isAllowedParentType(form.value.type, i.type))
    .map((i) => ({ label: `${getHierarchyPrefix(i)} ${i.title}`, value: i.id }));
});

const onTypeChange = (type: ItemType) => {
  if (type === 'project') {
    form.value.parent_id = null;
  }
};

// Auto-select type as note if parent is a note
watch(
  () => form.value.parent_id,
  (newParentId) => {
    if (newParentId) {
      const parentItem = tasksStore.items.find(i => i.id === newParentId);
      if (parentItem?.type === 'note') {
        form.value.type = 'note';
      }
    }
  }
);

watch(
  () => form.value.type,
  (newType) => {
    if (!form.value.parent_id) return;
    const parentItem = tasksStore.items.find((i) => i.id === form.value.parent_id);
    if (!parentItem) return;

    if (!isAllowedParentType(newType, parentItem.type)) {
      form.value.parent_id = null;
    }
  }
);

// Form populate on edit
watch(
  () => isOpen.value,
  (open) => {
    if (open) {
      if (authStore.tenantId !== null && tasksStore.items.length < 1) {
        void tasksStore.fetchItemsAction(authStore.tenantId, undefined, 1, 10000);
      }

      if (props.item) {
        const i = props.item;
        // Get tags & assignees from locally cached item state
        const itemInStore = tasksStore.items.find(x => x.id === i.id);
        const linkedTags = itemInStore?.tags || [];
        const assignees = itemInStore?.assignees || [];

        form.value = {
          type: i.type,
          title: i.title,
          content: i.content || '',
          parent_id: i.parent_id,
          status: i.status,
          priority: i.priority,
          accessibility: i.accessibility || 'public',
          is_markdown: i.is_markdown || false,
          start_date: i.start_date ? i.start_date.split('T')[0]! : '',
          due_date: i.due_date ? i.due_date.split('T')[0]! : '',
          assigneeEmails: assignees.map((a) => a.user_email),
          tagIds: linkedTags.map((t) => t.id),
        };
      } else {
        // Reset for create
        form.value = {
          type: props.defaultType || 'task',
          title: '',
          content: '',
          parent_id: props.defaultParentId || null,
          status: 'todo',
          priority: 'medium',
          accessibility: 'public',
          is_markdown: false,
          start_date: '',
          due_date: '',
          assigneeEmails: [],
          tagIds: [],
        };
      }
    }
  },
);

const onSave = async () => {
  const payload: Partial<Item> = {
    tenant_id: authStore.tenantId,
    type: form.value.type,
    title: form.value.title,
    content: form.value.content || null,
    parent_id: form.value.parent_id,
    status: form.value.status,
    priority: form.value.priority,
    accessibility: form.value.type === 'note' ? form.value.accessibility : 'public',
    is_markdown: form.value.is_markdown,
    start_date: form.value.start_date ? new Date(form.value.start_date).toISOString() : null,
    due_date: form.value.due_date ? new Date(form.value.due_date).toISOString() : null,
  };

  try {
    let savedItem: Item;
    if (isEdit.value && props.item) {
      savedItem = await tasksStore.updateItem(props.item.id, payload);
    } else {
      savedItem = await tasksStore.createItem(payload);
    }

    // Sync Assignees (add/remove diff)
    const currentAssignees = props.item?.assignees || [];
    const currentEmails = currentAssignees.map(a => a.user_email);
    const newEmails = form.value.assigneeEmails;

    const toAddAssignee = newEmails.filter(e => !currentEmails.includes(e));
    const toRemoveAssignee = currentEmails.filter(e => !newEmails.includes(e));

    await Promise.all([
      ...toAddAssignee.map(email => tasksStore.addAssignee(savedItem.id, email)),
      ...toRemoveAssignee.map(email => tasksStore.removeAssignee(savedItem.id, email)),
    ]);

    // Sync Tags (add/remove diff)
    const currentTags = props.item?.tags || [];
    const currentTagIds = currentTags.map(t => t.id);
    const newTagIds = form.value.tagIds;

    const toAddTag = newTagIds.filter(id => !currentTagIds.includes(id));
    const toRemoveTag = currentTagIds.filter(id => !newTagIds.includes(id));

    await Promise.all([
      ...toAddTag.map(tagId => tasksStore.linkTag(savedItem.id, tagId)),
      ...toRemoveTag.map(tagId => tasksStore.unlinkTag(savedItem.id, tagId)),
    ]);

    emit('saved');
    isOpen.value = false;
  } catch (error) {
    console.error('Failed to save task item', error);
  }
};
</script>

<style scoped>
.form-card {
  width: 95vw;
  max-width: 580px;
  background: rgba(255, 255, 255, 0.94);
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(10px);
}

.scroll-section {
  max-height: 70vh;
  overflow-y: auto;
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.pill-btn {
  border-radius: 999px;
  font-weight: 600;
}

@media (max-width: 600px) {
  .scroll-section {
    max-height: 75vh;
    padding: 12px 8px !important;
  }
  .form-card {
    border-radius: 12px;
  }
}
</style>

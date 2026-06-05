<template>
  <q-dialog v-model="isOpen" backdrop-filter="blur(4px)" @show="onShow">
    <q-card class="details-card floating-surface shadow-2" style="min-height: 250px;">
      <div v-if="loadingDetails" class="row justify-center items-center q-pa-xl absolute-center full-width" style="height: 250px;">
        <q-spinner size="40px" color="primary" />
      </div>
      <div v-else-if="!item" class="row justify-center items-center q-pa-xl text-grey-6 absolute-center full-width text-center" style="height: 250px;">
        <div>
          <q-icon name="warning" size="40px" color="negative" class="q-mb-md" />
          <div class="text-subtitle1 text-weight-bold">Failed to Load Item</div>
          <div class="text-caption">The item may have been deleted, or you might not have permissions to view it.</div>
        </div>
      </div>
      <div v-if="item">
        <!-- Header -->
        <q-card-section class="q-py-md row items-center justify-between border-bottom bg-light">
        <div class="row items-center q-gutter-sm col">
          <q-avatar :color="getTypeColor(item.type)" text-color="white" size="32px">
            <q-icon :name="getTypeIcon(item.type)" size="18px" />
          </q-avatar>
          <div class="col">
            <q-input
              v-model="item.title"
              borderless
              dense
              input-class="text-h6 text-weight-bold text-grey-9 q-pa-none"
              class="q-pa-none full-width"
              @blur="onSaveTitle"
              @keydown.enter="onSaveTitle"
            />
            <div class="row items-center q-gutter-x-sm text-caption text-grey-7 q-mt-xs">
              <span>Type:</span>
              <q-btn-dropdown
                unelevated
                rounded
                dense
                no-caps
                class="status-chip text-weight-bold"
                :style="typeChipStyle(item.type)"
              >
                <template #label>
                  <div class="row items-center no-wrap">
                    <span class="status-chip-dot" :style="{ backgroundColor: typeDotColor(item.type) }"></span>
                    <span class="text-caption text-weight-bold">{{ item.type.toUpperCase() }}</span>
                  </div>
                </template>
                <q-list>
                  <q-item
                    v-for="opt in typeOptions"
                    :key="opt.value"
                    clickable
                    v-close-popup
                    @click="onSaveType(opt.value)"
                  >
                    <q-item-section>
                      <q-item-label>{{ opt.label }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-btn-dropdown>
            </div>
          </div>
        </div>
        <div class="row items-center q-gutter-xs">
          <q-btn flat round dense icon="delete" color="negative" size="sm" @click="onClickDelete" />
          <q-btn flat round dense icon="close" v-close-popup />
        </div>
      </q-card-section>

      <!-- Content Stack -->
      <q-card-section class="q-pa-none dialog-layout">
        <!-- Sidebar Controls -->
        <div class="dialog-sidebar border-right q-pa-md q-gutter-y-md">
          <!-- Status Selector -->
          <div>
            <div class="text-overline text-grey-8 text-weight-bold q-mb-xs">Status</div>
            <q-btn-dropdown
              unelevated
              rounded
              dense
              no-caps
              class="status-chip text-weight-bold full-width"
              :style="statusChipStyle(item.status)"
            >
              <template #label>
                <div class="row items-center no-wrap">
                  <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(item.status) }"></span>
                  <span class="text-caption text-weight-bold">{{ statusLabel.toUpperCase() }}</span>
                </div>
              </template>
              <q-list>
                <q-item
                  v-for="opt in statusOptions"
                  :key="opt.value"
                  clickable
                  v-close-popup
                  @click="onStatusUpdate(opt.value)"
                >
                  <q-item-section>
                    <q-item-label>{{ opt.label }}</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-btn-dropdown>
          </div>

          <!-- Priority Selector -->
          <div>
            <div class="text-overline text-grey-8 text-weight-bold q-mb-xs">Priority</div>
            <q-btn-dropdown
              unelevated
              rounded
              dense
              no-caps
              class="status-chip text-weight-bold full-width"
              :style="priorityChipStyle(item.priority)"
            >
              <template #label>
                <div class="row items-center no-wrap">
                  <span class="status-chip-dot" :style="{ backgroundColor: priorityDotColor(item.priority) }"></span>
                  <span class="text-caption text-weight-bold">{{ priorityLabel.toUpperCase() }}</span>
                </div>
              </template>
              <q-list>
                <q-item
                  v-for="opt in priorityOptions"
                  :key="opt.value"
                  clickable
                  v-close-popup
                  @click="onPriorityUpdate(opt.value)"
                >
                  <q-item-section>
                    <q-item-label>{{ opt.label }}</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-btn-dropdown>
          </div>

          <!-- Parent Item -->
          <div>
            <div class="text-overline text-grey-8 text-weight-bold">Parent Item</div>
            <q-select
              v-model="item.parent_id"
              :options="parentOptions"
              outlined
              dense
              emit-value
              map-options
              clearable
              placeholder="No Parent (Root)"
              @update:model-value="onParentUpdate"
            />
          </div>

          <!-- Due Date -->
          <div>
            <div class="text-overline text-grey-8 text-weight-bold">Dates</div>
            <div class="text-caption text-grey-7">Start: {{ formatDate(item.start_date) }}</div>
            <div class="text-caption text-grey-7">Due: {{ formatDate(item.due_date) }}</div>
          </div>

          <!-- Assignees list -->
          <div>
            <div class="row items-center justify-between">
              <span class="text-overline text-grey-8 text-weight-bold">Assignees</span>
              <q-btn flat round dense icon="add" size="xs" color="primary" @click="showAddAssignee = !showAddAssignee" />
            </div>

            <!-- Quick Add Assignee -->
            <q-select
              v-if="showAddAssignee"
              v-model="selectedAssigneeEmail"
              :options="memberEmails"
              label="Add Assignee"
              outlined
              dense
              emit-value
              map-options
              @update:model-value="onAddAssignee"
              class="q-mb-xs"
            />

            <div class="q-gutter-xs q-mt-xs">
              <q-chip
                v-for="a in assignees"
                :key="a.id"
                dense
                removable
                @remove="onRemoveAssignee(a.user_email)"
                color="blue-1"
                text-color="blue-8"
              >
                {{ a.user_email }}
              </q-chip>
              <div v-if="!assignees.length" class="text-caption text-grey-5">Unassigned</div>
            </div>
          </div>

          <!-- Item Tags -->
          <div>
            <div class="row items-center justify-between">
              <span class="text-overline text-grey-8 text-weight-bold">Tags</span>
              <q-btn flat round dense icon="add" size="xs" color="primary" @click="showAddTag = !showAddTag" />
            </div>

            <!-- Quick Add Tag -->
            <q-select
              v-if="showAddTag"
              v-model="selectedTagId"
              :options="tagOptions"
              label="Add Tag"
              outlined
              dense
              emit-value
              map-options
              @update:model-value="onAddTag"
              class="q-mb-xs"
            />

            <div class="q-gutter-xs q-mt-xs">
              <q-chip
                v-for="tag in itemTags"
                :key="tag.id"
                dense
                removable
                @remove="onRemoveTag(tag.id)"
                text-color="white"
                :style="{ backgroundColor: tag.color || '#6366f1' }"
              >
                {{ tag.name }}
              </q-chip>
              <div v-if="!itemTags.length" class="text-caption text-grey-5">No tags linked</div>
            </div>
          </div>

          <!-- Granular Permissions (Item Collaborators) -->
          <div>
            <div class="row items-center justify-between">
              <span class="text-overline text-grey-8 text-weight-bold">Collaborators</span>
              <q-btn flat round dense icon="add" size="xs" color="primary" @click="showAddPerm = !showAddPerm" />
            </div>

            <div v-if="showAddPerm" class="q-gutter-y-xs q-mb-sm">
              <q-select
                v-model="newPerm.email"
                :options="memberEmails"
                label="User Email"
                outlined
                dense
              />
              <q-select
                v-model="newPerm.role"
                :options="roleOptions"
                label="Role"
                outlined
                dense
                emit-value
                map-options
              />
              <q-btn label="Grant" color="primary" dense size="sm" @click="onSavePermission" class="full-width" unelevated />
            </div>

            <div class="q-mt-xs q-gutter-y-xs">
              <q-item v-for="p in permissions" :key="p.id" class="q-pa-xs border-bottom">
                <q-item-section>
                  <q-item-label class="text-caption ellipsis">{{ p.user_email }}</q-item-label>
                  <q-item-label caption class="text-overline">{{ p.role }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-btn flat round dense icon="delete" size="xs" color="red" @click="onDeletePermission(p.user_email)" />
                </q-item-section>
              </q-item>
              <div v-if="!permissions.length" class="text-caption text-grey-5">No explicit overrides</div>
            </div>
          </div>
        </div>

        <!-- Main Body -->
        <div class="dialog-body scroll-body q-pa-md">
          <!-- Description (Rich Text Editor) -->
          <div class="q-mb-lg">
            <div class="row items-center justify-between q-mb-sm">
              <div class="text-overline text-grey-8 text-weight-bold">Description</div>
              <div v-if="isDescriptionChanged" class="row q-gutter-xs">
                <q-btn label="Cancel" color="grey" flat dense size="xs" no-caps @click="onCancelDescription" />
                <q-btn label="Save Description" color="primary" unelevated dense size="xs" no-caps @click="onSaveDescription" class="q-px-sm" />
              </div>
            </div>
            <q-editor
              v-model="editedDescription"
              dense
              flat
              bordered
              content-class="bg-grey-1"
              class="description-editor"
              :toolbar="[
                ['bold', 'italic', 'strike', 'underline'],
                ['quote', 'code', 'link', 'hr'],
                ['unordered', 'ordered', 'outdent', 'indent'],
                ['undo', 'redo'],
                ['fullscreen']
              ]"
            />
          </div>

          <!-- Discussions & Comments Toggle -->
          <div class="q-mb-md border-top q-pt-md row items-center justify-between">
            <div class="text-overline text-grey-8 text-weight-bold">Discussions & Comments</div>
            <q-btn
              :label="showDiscussion ? 'Hide Discussions' : 'Show Discussions'"
              :icon="showDiscussion ? 'forum' : 'chat_bubble_outline'"
              color="primary"
              outline
              no-caps
              size="sm"
              class="pill-btn"
              @click="showDiscussion = !showDiscussion"
            />
          </div>

          <!-- Threaded Comments / Discussions Block -->
          <div v-if="showDiscussion" class="q-mb-lg">
            <!-- Comment Input -->
            <q-form @submit.prevent="onAddComment(null)" class="row q-col-gutter-xs items-start q-mb-md">
              <div class="col">
                <q-input
                  v-model="commentText"
                  placeholder="Ask a question or post an update..."
                  outlined
                  dense
                  autogrow
                />
              </div>
              <div class="col-auto">
                <q-btn type="submit" label="Post" color="primary" unelevated no-caps dense class="q-px-sm" style="min-height: 40px" />
              </div>
            </q-form>

            <!-- Comments List (Indented Threads) -->
            <div class="q-gutter-y-sm" v-if="commentsTree.length">
              <div v-for="c in commentsTree" :key="c.id" class="comment-wrapper">
                <!-- Main Comment -->
                <div class="comment-box q-pa-sm rounded-borders">
                  <div class="row justify-between items-center q-mb-xs">
                    <span class="text-caption text-weight-bold text-primary">{{ c.user_email }}</span>
                    <span class="text-caption text-grey-6">{{ formatDateShort(c.created_at) }}</span>
                  </div>
                  <div class="text-body2 text-grey-9">{{ c.body }}</div>
                  
                  <div class="row items-center justify-between q-mt-xs">
                    <q-btn flat dense no-caps label="Reply" color="grey-7" size="xs" icon="reply" @click="activeReplyId = c.id" />
                    <q-btn
                      v-if="c.user_email === authStore.user?.email"
                      flat
                      dense
                      round
                      color="red"
                      icon="delete"
                      size="xs"
                      @click="onDeleteComment(c.id)"
                    />
                  </div>
                </div>

                <!-- Reply Input -->
                <q-form v-if="activeReplyId === c.id" @submit.prevent="onAddComment(c.id)" class="row q-col-gutter-xs q-mt-xs q-ml-md items-start">
                  <div class="col">
                    <q-input v-model="replyText" placeholder="Write a reply..." outlined dense size="sm" autogrow />
                  </div>
                  <div class="col-auto">
                    <q-btn type="submit" label="Reply" color="primary" unelevated dense size="sm" class="q-px-xs" />
                    <q-btn label="Cancel" flat dense size="sm" color="grey" @click="activeReplyId = null" />
                  </div>
                </q-form>

                <!-- Replies -->
                <div v-if="c.replies?.length" class="replies-container q-ml-md q-mt-xs border-left q-pl-md q-gutter-y-sm">
                  <div v-for="r in c.replies" :key="r.id" class="reply-box q-pa-xs rounded-borders bg-grey-1">
                    <div class="row justify-between items-center">
                      <span class="text-caption text-weight-bold text-teal-8">{{ r.user_email }}</span>
                      <span class="text-caption text-grey-6">{{ formatDateShort(r.created_at) }}</span>
                    </div>
                    <div class="text-body2 text-grey-9">{{ r.body }}</div>
                    <div class="text-right" v-if="r.user_email === authStore.user?.email">
                      <q-btn flat dense round color="red" icon="delete" size="xs" @click="onDeleteComment(r.id)" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div v-else class="text-caption text-grey-5 text-center q-py-md">
              No comments posted. Start the conversation!
            </div>
          </div>

          <!-- Child Items (Sub-items) -->
          <div class="q-mb-lg border-top q-pt-md">
            <div class="row items-center justify-between q-mb-sm">
              <div class="text-overline text-grey-8 text-weight-bold">Child Items / Sub-items</div>
              <q-btn
                flat
                round
                dense
                icon="add"
                size="sm"
                color="primary"
                @click="createChildOpen = true"
              />
            </div>

            <!-- Child List -->
            <q-list dense separator v-if="childItems.length" class="bg-grey-1 rounded-borders q-pa-xs">
              <q-item
                v-for="child in childItems"
                :key="child.id"
                clickable
                @click="onNavigateToChild(child.id)"
              >
                <q-item-section avatar>
                  <q-icon :name="getTypeIcon(child.type)" :color="getTypeColor(child.type)" size="sm" />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-caption text-weight-medium">{{ child.title }}</q-item-label>
                  <q-item-label caption>{{ child.type.toUpperCase() }} • {{ child.status.toUpperCase() }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-btn flat round dense icon="open_in_new" size="xs" color="grey" />
                </q-item-section>
              </q-item>
            </q-list>
            <div v-else class="text-caption text-grey-5 q-pl-md">No child items linked.</div>
          </div>

          <!-- Activity Logs (Collapsible) -->
          <div class="border-top q-pt-md">
            <q-expansion-item
              label="Activity Log"
              icon="history"
              dense
              header-class="text-weight-bold text-grey-8 text-overline q-px-none"
            >
              <q-list dense separator v-if="activityLogs.length" class="bg-grey-1 rounded-borders q-pa-sm q-mt-sm">
                <q-item v-for="log in activityLogs" :key="log.id" class="q-px-none">
                  <q-item-section>
                    <q-item-label class="text-caption text-grey-9">
                      <span class="text-weight-bold">{{ log.user_email }}</span>
                      {{ getActionDescription(log) }}
                    </q-item-label>
                    <q-item-label caption class="text-grey-5">
                      {{ formatDateShort(log.created_at) }}
                    </q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
              <div v-else class="text-caption text-grey-5 q-mt-xs q-pl-md">No activity recorded.</div>
            </q-expansion-item>
          </div>
        </div>
      </q-card-section>
      </div>
    </q-card>
  </q-dialog>

  <!-- Create Child Item Dialog -->
  <TaskFormDialog
    v-model="createChildOpen"
    :default-parent-id="item?.id"
    :default-type="suggestedChildType"
    @saved="onChildSaved"
  />
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useTasksStore } from '../stores/tasksStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { tasksRepository } from '../repositories/tasksRepository';
import type { Item, Tag, Comment, ItemAssignee, ItemPermission, ActivityLog, ItemStatus, ItemPriority, ItemType } from '../types';
import { requestConfirmation } from 'src/utils/appFeedback';
import TaskFormDialog from './TaskFormDialog.vue';

const props = defineProps<{
  modelValue: boolean;
  itemId: number | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'update:itemId', val: number | null): void;
  (e: 'updated'): void;
}>();

const tasksStore = useTasksStore();
const authStore = useAuthStore();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const item = ref<Item | null>(null);
const loadingDetails = ref(false);
const assignees = ref<ItemAssignee[]>([]);
const itemTags = ref<Tag[]>([]);
const comments = ref<Comment[]>([]);
const permissions = ref<ItemPermission[]>([]);
const activityLogs = ref<ActivityLog[]>([]);

// UI States
const showAddAssignee = ref(false);
const selectedAssigneeEmail = ref('');
const showAddTag = ref(false);
const selectedTagId = ref<number | null>(null);
const showAddPerm = ref(false);
const newPerm = ref({ email: '', role: 'viewer' });

// Child creation states
const createChildOpen = ref(false);

// Comments discussion states
const showDiscussion = ref(false);
const commentText = ref('');
const activeReplyId = ref<number | null>(null);
const replyText = ref('');

// Rich text description states
const editedDescription = ref('');
const isDescriptionChanged = computed(() => {
  const original = item.value?.content || '';
  return editedDescription.value !== original;
});

// Child Items
const childItems = computed(() => {
  if (!item.value) return [];
  return tasksStore.items.filter((i) => i.parent_id === item.value?.id);
});

const suggestedChildType = computed<ItemType>(() => {
  if (!item.value) return 'task';
  if (item.value.type === 'project') return 'module';
  if (item.value.type === 'module') return 'submodule';
  return 'task';
});

// Dropdowns
const memberEmails = computed(() => tasksStore.members.map(m => m.email));
const tagOptions = computed(() => tasksStore.tags.map(t => ({ label: t.name, value: t.id })));

const typeOptions = [
  { label: 'Project', value: 'project' },
  { label: 'Module', value: 'module' },
  { label: 'Submodule', value: 'submodule' },
  { label: 'Task / Ticket', value: 'task' },
  { label: 'Note', value: 'note' },
  { label: 'Discussion', value: 'discussion' },
  { label: 'Bug Report', value: 'bug' },
  { label: 'Feature Request', value: 'feature' },
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

const roleOptions = [
  { label: 'Owner', value: 'owner' },
  { label: 'Manager', value: 'manager' },
  { label: 'Editor', value: 'editor' },
  { label: 'Viewer', value: 'viewer' },
  { label: 'Commenter', value: 'commenter' },
];

// Rebuild threaded replies
const commentsTree = computed(() => {
  const map: Record<number, Comment> = {};
  const roots: Comment[] = [];

  const cloned = comments.value.map((c) => ({
    ...c,
    replies: [] as Comment[],
  }));

  cloned.forEach((c) => {
    map[c.id] = c;
  });

  cloned.forEach((c) => {
    if (c.parent_comment_id) {
      const parent = map[c.parent_comment_id];
      if (parent) {
        parent.replies = parent.replies || [];
        parent.replies.push(c);
      } else {
        roots.push(c);
      }
    } else {
      roots.push(c);
    }
  });

  return roots;
});

// Load details on show
const onShow = async () => {
  if (props.itemId) {
    await loadDetails();
  }
};

const loadDetails = async () => {
  if (!props.itemId) return;
  loadingDetails.value = true;
  try {
    const details = await tasksRepository.fetchFullItemDetails(props.itemId);

    item.value = details.item;
    editedDescription.value = details.item.content || '';
    assignees.value = details.assignees;
    itemTags.value = details.tags;
    comments.value = details.comments;
    permissions.value = details.permissions;
    activityLogs.value = details.activityLogs;
  } catch (err) {
    console.error('Failed to load item details', err);
    item.value = null;
  } finally {
    loadingDetails.value = false;
  }
};

const onSaveDescription = async () => {
  if (!item.value) return;
  try {
    await tasksStore.updateItem(item.value.id, { content: editedDescription.value });
    await loadDetails();
    emit('updated');
  } catch (err) {
    console.error('Failed to save description', err);
  }
};

const onCancelDescription = () => {
  editedDescription.value = item.value?.content || '';
};

const onSaveTitle = async () => {
  if (item.value && item.value.title.trim()) {
    await tasksStore.updateItem(item.value.id, { title: item.value.title.trim() });
    await loadDetails();
    emit('updated');
  }
};

const onSaveType = async (type: string) => {
  if (item.value) {
    await tasksStore.updateItem(item.value.id, { type: type as ItemType });
    await loadDetails();
    emit('updated');
  }
};

const onParentUpdate = async (parentId: number | null) => {
  if (item.value) {
    await tasksStore.updateItem(item.value.id, { parent_id: parentId });
    await loadDetails();
    emit('updated');
  }
};

const onChildSaved = async () => {
  await loadDetails();
  emit('updated');
};

const onNavigateToChild = (childId: number) => {
  emit('update:itemId', childId);
};

const parentOptions = computed(() => {
  if (!item.value) return [];
  return tasksStore.items
    .filter((i) => i.id !== item.value?.id)
    .map((i) => ({
      label: `[${i.type.toUpperCase()}] ${i.title}`,
      value: i.id,
    }));
});

const statusLabel = computed(() => {
  const opt = statusOptions.find(o => o.value === item.value?.status);
  return opt ? opt.label : item.value?.status || '';
});

const priorityLabel = computed(() => {
  const opt = priorityOptions.find(o => o.value === item.value?.priority);
  return opt ? opt.label : item.value?.priority || '';
});

const statusChipStyle = (status: string) => {
  switch (status) {
    case 'todo':
      return { backgroundColor: '#f1f5f9', color: '#475569', border: '1px solid #cbd5e1' };
    case 'in_progress':
      return { backgroundColor: '#eff6ff', color: '#2563eb', border: '1px solid #bfdbfe' };
    case 'review':
      return { backgroundColor: '#fff7ed', color: '#ea580c', border: '1px solid #fed7aa' };
    case 'done':
      return { backgroundColor: '#f0fdf4', color: '#16a34a', border: '1px solid #bbf7d0' };
    case 'blocked':
      return { backgroundColor: '#fef2f2', color: '#dc2626', border: '1px solid #fecaca' };
    case 'archived':
      return { backgroundColor: '#fafaf9', color: '#78716c', border: '1px solid #e7e5e4' };
    default:
      return { backgroundColor: '#f4f4f5', color: '#71717a', border: '1px solid #e4e4e7' };
  }
};

const statusDotColor = (status: string) => {
  switch (status) {
    case 'todo': return '#64748b';
    case 'in_progress': return '#3b82f6';
    case 'review': return '#f97316';
    case 'done': return '#22c55e';
    case 'blocked': return '#ef4444';
    case 'archived': return '#8c857b';
    default: return '#9ca3af';
  }
};

const priorityChipStyle = (priority: string) => {
  switch (priority) {
    case 'low':
      return { backgroundColor: '#f0fdf4', color: '#16a34a', border: '1px solid #bbf7d0' };
    case 'medium':
      return { backgroundColor: '#eff6ff', color: '#2563eb', border: '1px solid #bfdbfe' };
    case 'high':
      return { backgroundColor: '#fff7ed', color: '#ea580c', border: '1px solid #fed7aa' };
    case 'urgent':
      return { backgroundColor: '#fef2f2', color: '#dc2626', border: '1px solid #fecaca' };
    default:
      return { backgroundColor: '#f4f4f5', color: '#71717a', border: '1px solid #e4e4e7' };
  }
};

const priorityDotColor = (priority: string) => {
  switch (priority) {
    case 'low': return '#22c55e';
    case 'medium': return '#3b82f6';
    case 'high': return '#f97316';
    case 'urgent': return '#ef4444';
    default: return '#9ca3af';
  }
};

const typeChipStyle = (type: string) => {
  switch (type) {
    case 'project':
      return { backgroundColor: '#f5f3ff', color: '#7c3aed', border: '1px solid #ddd6fe' };
    case 'module':
      return { backgroundColor: '#ecfdf5', color: '#059669', border: '1px solid #a7f3d0' };
    case 'submodule':
      return { backgroundColor: '#ecfeff', color: '#0891b2', border: '1px solid #c5f6fa' };
    case 'task':
      return { backgroundColor: '#eff6ff', color: '#2563eb', border: '1px solid #bfdbfe' };
    case 'note':
      return { backgroundColor: '#fffbeb', color: '#d97706', border: '1px solid #fde68a' };
    case 'discussion':
      return { backgroundColor: '#f0fdfa', color: '#0d9488', border: '1px solid #ccfbf1' };
    case 'bug':
      return { backgroundColor: '#fef2f2', color: '#dc2626', border: '1px solid #fecaca' };
    case 'feature':
      return { backgroundColor: '#fdf2f8', color: '#db2777', border: '1px solid #fbcfe8' };
    default:
      return { backgroundColor: '#f4f4f5', color: '#71717a', border: '1px solid #e4e4e7' };
  }
};

const typeDotColor = (type: string) => {
  switch (type) {
    case 'project': return '#8b5cf6';
    case 'module': return '#10b981';
    case 'submodule': return '#06b6d4';
    case 'task': return '#3b82f6';
    case 'note': return '#f59e0b';
    case 'discussion': return '#14b8a6';
    case 'bug': return '#ef4444';
    case 'feature': return '#ec4899';
    default: return '#9ca3af';
  }
};

watch(() => props.itemId, async (newId) => {
  if (newId && isOpen.value) {
    await loadDetails();
  }
});

const onStatusUpdate = async (status: ItemStatus) => {
  if (item.value) {
    await tasksStore.updateItem(item.value.id, { status });
    await loadDetails();
    emit('updated');
  }
};

const onPriorityUpdate = async (priority: ItemPriority) => {
  if (item.value) {
    await tasksStore.updateItem(item.value.id, { priority });
    await loadDetails();
    emit('updated');
  }
};

// Add / Remove Assignees
const onAddAssignee = async (email: string) => {
  if (item.value && email) {
    await tasksStore.addAssignee(item.value.id, email);
    showAddAssignee.value = false;
    selectedAssigneeEmail.value = '';
    await loadDetails();
    emit('updated');
  }
};

const onRemoveAssignee = async (email: string) => {
  if (item.value && email) {
    await tasksStore.removeAssignee(item.value.id, email);
    await loadDetails();
    emit('updated');
  }
};

// Add / Remove Tags
const onAddTag = async (tagId: number) => {
  if (item.value && tagId) {
    await tasksStore.linkTag(item.value.id, tagId);
    showAddTag.value = false;
    selectedTagId.value = null;
    await loadDetails();
    emit('updated');
  }
};

const onRemoveTag = async (tagId: number) => {
  if (item.value && tagId) {
    await tasksStore.unlinkTag(item.value.id, tagId);
    await loadDetails();
    emit('updated');
  }
};

// Add / Delete Comments
const onAddComment = async (parentId: number | null) => {
  if (!item.value) return;
  const txt = parentId ? replyText.value : commentText.value;
  if (!txt.trim()) return;

  try {
    await tasksRepository.addComment(item.value.id, txt, parentId);
    if (parentId) {
      replyText.value = '';
      activeReplyId.value = null;
    } else {
      commentText.value = '';
    }
    await loadDetails();
  } catch (err) {
    console.error('Failed to post comment', err);
  }
};

const onDeleteComment = async (commentId: number) => {
  try {
    await tasksRepository.deleteComment(commentId);
    await loadDetails();
  } catch (err) {
    console.error('Failed to delete comment', err);
  }
};

// Granular Permissions
const onSavePermission = async () => {
  if (!item.value || !newPerm.value.email) return;
  try {
    await tasksRepository.savePermission(item.value.id, newPerm.value.email, newPerm.value.role);
    showAddPerm.value = false;
    newPerm.value = { email: '', role: 'viewer' };
    await loadDetails();
  } catch (err) {
    console.error('Failed to save permissions', err);
  }
};

const onDeletePermission = async (email: string) => {
  if (!item.value) return;
  try {
    await tasksRepository.deletePermission(item.value.id, email);
    await loadDetails();
  } catch (err) {
    console.error('Failed to delete permission', err);
  }
};

// Edit / Delete Item
const onClickDelete = async () => {
  if (!item.value) return;
  const confirmed = await requestConfirmation(
    `Warning: Deleting this ${item.value.type} will permanently delete all of its nested child items (submodules, tasks, notes, discussions, etc.) along with their tags, comments, and permissions. This action cannot be undone.`,
    'Delete Item & All Children',
    'Delete All',
  );

  if (confirmed) {
    try {
      await tasksStore.deleteItem(item.value.id);
      emit('updated');
      isOpen.value = false;
    } catch (err) {
      console.error('Failed to delete item', err);
    }
  }
};

// Helpers
const formatDate = (d: string | null) => (d ? new Date(d).toLocaleDateString() : 'N/A');
const formatDateShort = (d: string) => {
  return new Date(d).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const getActionDescription = (log: ActivityLog) => {
  switch (log.action) {
    case 'created': return `created the item: "${log.new_value}"`;
    case 'assigned': return `assigned the task to ${log.new_value}`;
    case 'status_changed': return `changed status from "${log.old_value}" to "${log.new_value}"`;
    case 'priority_changed': return `updated priority from "${log.old_value}" to "${log.new_value}"`;
    case 'tag_added': return 'added a tag';
    case 'tag_removed': return 'removed a tag';
    default: return `performed action: ${log.action}`;
  }
};

const getTypeIcon = (type: string) => {
  switch (type) {
    case 'project': return 'folder';
    case 'module': return 'view_module';
    case 'submodule': return 'layers';
    case 'task': return 'assignment';
    case 'note': return 'note';
    case 'discussion': return 'forum';
    case 'bug': return 'bug_report';
    case 'feature': return 'star';
    default: return 'help_outline';
  }
};

const getTypeColor = (type: string) => {
  switch (type) {
    case 'project': return 'indigo';
    case 'module': return 'blue';
    case 'submodule': return 'cyan';
    case 'task': return 'green';
    case 'note': return 'orange';
    case 'discussion': return 'teal';
    case 'bug': return 'red';
    case 'feature': return 'purple';
    default: return 'grey';
  }
};
</script>

<style scoped>
.details-card {
  width: 95vw;
  max-width: 850px;
  background: #ffffff;
  border-radius: 16px;
}

.dialog-layout {
  display: flex;
  height: 80vh;
  min-height: 500px;
}

.dialog-sidebar {
  width: 280px;
  flex-shrink: 0;
  background: #fbfcfd;
  overflow-y: auto;
}

.dialog-body {
  flex-grow: 1;
  overflow-y: auto;
}

.content-desc {
  background: #f8fafc;
  padding: 12px;
  border-radius: 8px;
  border: 1px solid rgba(0,0,0,0.04);
  white-space: pre-wrap;
}

.comment-box {
  background: #f3f5f8;
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.replies-container {
  border-left: 2px solid #e2e8f0;
}

.reply-box {
  border: 1px solid rgba(0,0,0,0.03);
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.border-right {
  border-right: 1px solid rgba(0, 0, 0, 0.08);
}

.bg-light {
  background: #f8fafc;
}

.description-editor {
  height: 50vh;
  display: flex;
  flex-direction: column;
}
.description-editor :deep(.q-editor__content) {
  flex-grow: 1;
  overflow-y: auto;
  min-height: 250px;
}

.status-chip {
  border-radius: 4px !important;
  font-weight: 600;
  font-size: 10px !important;
  letter-spacing: 0.01em;
  padding: 2px 6px !important;
  min-height: 20px !important;
  height: auto !important;
}

.status-chip-dot {
  display: inline-block;
  width: 6px;
  height: 6px;
  border-radius: 999px;
  margin-right: 4px;
}

@media (max-width: 768px) {
  .dialog-layout {
    flex-direction: column;
    height: auto;
    max-height: 85vh;
  }
  .dialog-sidebar {
    width: 100%;
    border-right: none;
    border-bottom: 1px solid rgba(0, 0, 0, 0.08);
  }
}
</style>

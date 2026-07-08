<template>
  <q-dialog v-model="isOpen" backdrop-filter="blur(4px)">
    <q-card class="details-card floating-surface shadow-2" style="min-height: 250px">
      <PageInitialLoader v-if="loadingDetails" />
      <div
        v-else-if="!item"
        class="row justify-center items-center q-pa-xl text-grey-6 absolute-center full-width text-center"
        style="height: 250px"
      >
        <div>
          <q-icon name="warning" size="40px" color="negative" class="q-mb-md" />
          <div class="text-subtitle1 text-weight-bold">Failed to Load Item</div>
          <div class="text-caption">
            The item may have been deleted, or you might not have permissions to view it.
          </div>
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
              <!-- Parent Breadcrumb Link -->
              <div
                v-if="parentItem"
                class="row items-center q-gutter-x-xs text-caption text-primary cursor-pointer q-mb-xs hover-underline"
                @click="onNavigateToParent"
              >
                <q-icon name="arrow_back" size="14px" />
                <span>Parent: [{{ parentItem.type.toUpperCase() }}] {{ parentItem.title }}</span>
              </div>
              <div class="row items-center no-wrap full-width">
                <span
                  v-if="item.type === 'task'"
                  class="text-h6 text-weight-bold text-primary q-mr-xs"
                  >#{{ item.id }}</span
                >
                <q-input
                  v-model="item.title"
                  type="textarea"
                  autogrow
                  borderless
                  dense
                  input-class="text-h6 text-weight-bold text-grey-9 q-pa-none"
                  class="q-pa-none full-width col"
                  input-style="white-space: normal; word-break: break-word;"
                  @blur="onSaveTitle"
                  @keydown.enter.prevent="onSaveTitle"
                />
              </div>
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
                      <span
                        class="status-chip-dot"
                        :style="{ backgroundColor: typeDotColor(item.type) }"
                      ></span>
                      <span class="text-caption text-weight-bold">{{
                        item.type.toUpperCase()
                      }}</span>
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
            <q-btn
              flat
              round
              dense
              icon="o_delete"
              color="negative"
              size="sm"
              @click="onClickDelete"
            />
            <q-btn flat round dense icon="close" v-close-popup />
          </div>
        </q-card-section>

        <!-- Content Stack -->
        <q-card-section class="q-pa-none dialog-layout">
          <!-- Main Body -->
          <div class="dialog-body scroll-body q-pa-md">
            <div class="description-shell">
              <div class="row items-center justify-between q-mb-sm">
                <div>
                  <div class="text-overline text-grey-8 text-weight-bold">Description</div>
                  <div class="text-caption text-grey-5">Double click to edit</div>
                </div>
              </div>

              <div
                v-if="!isEditMode"
                @dblclick="onStartEdit"
                class="description-view-area bg-grey-1 q-pa-md rounded-borders border cursor-pointer"
              >
                <div
                  v-if="item.is_markdown"
                  v-html="parsedDescription || 'No description provided. Double click to add one.'"
                  class="markdown-body"
                ></div>
                <div
                  v-else
                  v-html="item.content || 'No description provided. Double click to add one.'"
                  class="rich-text-body text-body2 text-grey-9"
                ></div>
              </div>

              <div v-else class="q-gutter-y-sm">
                <div class="row items-center justify-between">
                  <q-checkbox v-model="isMarkdownMode" label="Use Markdown" dense />
                  <div class="row q-gutter-xs">
                    <q-btn
                      label="Cancel"
                      color="grey"
                      flat
                      dense
                      size="sm"
                      no-caps
                      @click="onCancelDescription"
                    />
                    <q-btn
                      label="Save"
                      color="primary"
                      unelevated
                      dense
                      size="sm"
                      no-caps
                      @click="onSaveDescription"
                      class="q-px-sm"
                    />
                  </div>
                </div>
                <q-input
                  v-if="isMarkdownMode"
                  v-model="editedDescription"
                  type="textarea"
                  outlined
                  dense
                  rows="18"
                  class="bg-grey-1"
                  placeholder="Write description in Markdown..."
                  :input-style="{ fontFamily: 'monospace' }"
                />
                <q-editor
                  v-else
                  v-model="editedDescription"
                  min-height="18rem"
                  max-height="40rem"
                  :toolbar="[
                    ['bold', 'italic', 'underline', 'strike'],
                    ['unordered', 'ordered', 'outdent', 'indent'],
                    ['quote', 'link', 'hr'],
                    ['undo', 'redo'],
                    ['fullscreen'],
                  ]"
                />
              </div>
            </div>

            <div class="q-mt-lg border-top q-pt-md row items-center justify-between">
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

            <div v-if="showDiscussion" class="q-mb-lg">
              <q-form
                @submit.prevent="onAddComment(null)"
                class="row q-col-gutter-xs items-start q-mt-md q-mb-md"
              >
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
                  <q-btn
                    type="submit"
                    label="Post"
                    color="primary"
                    unelevated
                    no-caps
                    dense
                    class="q-px-sm"
                    style="min-height: 40px"
                  />
                </div>
              </q-form>

              <div class="q-gutter-y-sm" v-if="commentsTree.length">
                <div v-for="c in commentsTree" :key="c.id" class="comment-wrapper">
                  <div class="comment-box q-pa-sm rounded-borders">
                    <div class="row justify-between items-center q-mb-xs">
                      <span class="text-caption text-weight-bold text-primary">{{
                        c.user_email
                      }}</span>
                      <span class="text-caption text-grey-6">{{
                        formatDateShort(c.created_at)
                      }}</span>
                    </div>
                    <div class="text-body2 text-grey-9">{{ c.body }}</div>
                    <div class="row items-center justify-between q-mt-xs">
                      <q-btn
                        flat
                        dense
                        no-caps
                        label="Reply"
                        color="grey-7"
                        size="xs"
                        icon="reply"
                        @click="activeReplyId = c.id"
                      />
                      <q-btn
                        v-if="c.user_email === authStore.user?.email"
                        flat
                        dense
                        round
                        color="red"
                        icon="o_delete"
                        size="xs"
                        @click="onDeleteComment(c.id)"
                      />
                    </div>
                  </div>

                  <q-form
                    v-if="activeReplyId === c.id"
                    @submit.prevent="onAddComment(c.id)"
                    class="row q-col-gutter-xs q-mt-xs q-ml-md items-start"
                  >
                    <div class="col">
                      <q-input
                        v-model="replyText"
                        placeholder="Write a reply…"
                        outlined
                        dense
                        autogrow
                      />
                    </div>
                    <div class="col-auto">
                      <q-btn
                        type="submit"
                        label="Reply"
                        color="primary"
                        unelevated
                        no-caps
                        dense
                        size="sm"
                        class="q-px-sm"
                        style="min-height: 40px"
                      />
                    </div>
                  </q-form>
                </div>
              </div>

              <div v-else class="text-caption text-grey-5 q-mt-sm">No discussions yet.</div>
            </div>

            <div class="q-mt-lg border-top q-pt-md">
              <div class="row items-center justify-between q-mb-sm">
                <div class="text-overline text-grey-8 text-weight-bold">
                  Child Items / Sub-items
                </div>
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

              <q-list
                dense
                separator
                v-if="childItems.length"
                class="bg-grey-1 rounded-borders q-pa-xs"
              >
                <q-item
                  v-for="child in childItems"
                  :key="child.id"
                  clickable
                  @click="onNavigateToChild(child.id)"
                >
                  <q-item-section avatar>
                    <q-icon
                      :name="getTypeIcon(child.type)"
                      :color="getTypeColor(child.type)"
                      size="sm"
                    />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-caption text-weight-medium">{{
                      child.title
                    }}</q-item-label>
                    <q-item-label caption
                      >{{ child.type.toUpperCase() }} •
                      {{ child.status.toUpperCase() }}</q-item-label
                    >
                  </q-item-section>
                  <q-item-section side>
                    <q-btn flat round dense icon="open_in_new" size="xs" color="grey" />
                  </q-item-section>
                </q-item>
              </q-list>
              <div v-else class="text-caption text-grey-5 q-pl-md">No child items linked.</div>
            </div>

            <div class="border-top q-pt-md q-mt-lg">
              <q-expansion-item
                label="Activity Log"
                icon="history"
                dense
                header-class="text-weight-bold text-grey-8 text-overline q-px-none"
              >
                <q-list
                  dense
                  separator
                  v-if="activityLogs.length"
                  class="bg-grey-1 rounded-borders q-pa-sm q-mt-sm"
                >
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
                <div v-else class="text-caption text-grey-5 q-mt-xs q-pl-md">
                  No activity recorded.
                </div>
              </q-expansion-item>
            </div>
          </div>

          <!-- Sidebar Controls -->
          <div class="dialog-sidebar border-left q-pa-md q-gutter-y-md">
            <div class="text-overline text-grey-8 text-weight-bold q-mb-xs">Quick Controls</div>
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
                    <span
                      class="status-chip-dot"
                      :style="{ backgroundColor: statusDotColor(item.status) }"
                    ></span>
                    <span class="text-caption text-weight-bold">{{
                      statusLabel.toUpperCase()
                    }}</span>
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
                    <span
                      class="status-chip-dot"
                      :style="{ backgroundColor: priorityDotColor(item.priority) }"
                    ></span>
                    <span class="text-caption text-weight-bold">{{
                      priorityLabel.toUpperCase()
                    }}</span>
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
            <div v-if="item.type === 'note'">
              <div class="text-overline text-grey-8 text-weight-bold q-mb-xs">Accessibility</div>
              <q-btn-dropdown
                unelevated
                rounded
                dense
                no-caps
                class="status-chip text-weight-bold full-width"
                :style="accessibilityChipStyle(item.accessibility)"
              >
                <template #label>
                  <div class="row items-center no-wrap">
                    <q-icon
                      :name="accessibilityIcon(item.accessibility)"
                      size="14px"
                      class="q-mr-xs"
                    />
                    <span class="text-caption text-weight-bold">{{
                      (item.accessibility || 'public').toUpperCase()
                    }}</span>
                  </div>
                </template>
                <q-list>
                  <q-item
                    v-for="opt in accessibilityOptions"
                    :key="opt.value"
                    clickable
                    v-close-popup
                    @click="onAccessibilityUpdate(opt.value)"
                  >
                    <q-item-section avatar>
                      <q-icon :name="opt.icon" size="18px" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label>{{ opt.label }}</q-item-label>
                      <q-item-label caption class="text-caption text-grey-6">{{
                        opt.caption
                      }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-btn-dropdown>
            </div>
            <q-expansion-item
              dense
              expand-separator
              icon="tune"
              label="More details"
              default-opened
              header-class="text-overline text-grey-8 text-weight-bold"
            >
              <div class="q-pt-sm q-gutter-y-md">
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
                <div>
                  <div class="text-overline text-grey-8 text-weight-bold">Dates</div>
                  <div class="row items-center justify-between q-mb-xs">
                    <span class="text-caption text-grey-7"
                      >Start: {{ formatDate(item.start_date) }}</span
                    >
                    <q-btn flat round dense icon="edit_calendar" size="xs" color="primary">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-date
                          v-model="startDateProxy"
                          mask="YYYY-MM-DD"
                          @update:model-value="onUpdateStartDate"
                        >
                          <div class="row items-center justify-end q-gutter-sm">
                            <q-btn
                              v-close-popup
                              label="Clear"
                              color="negative"
                              flat
                              @click="onClearStartDate"
                            />
                            <q-btn v-close-popup label="Close" color="primary" flat />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </q-btn>
                  </div>
                  <div class="row items-center justify-between">
                    <span class="text-caption text-grey-7"
                      >Due: {{ formatDate(item.due_date) }}</span
                    >
                    <q-btn flat round dense icon="edit_calendar" size="xs" color="primary">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-date
                          v-model="dueDateProxy"
                          mask="YYYY-MM-DD"
                          @update:model-value="onUpdateDueDate"
                        >
                          <div class="row items-center justify-end q-gutter-sm">
                            <q-btn
                              v-close-popup
                              label="Clear"
                              color="negative"
                              flat
                              @click="onClearDueDate"
                            />
                            <q-btn v-close-popup label="Close" color="primary" flat />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </q-btn>
                  </div>
                </div>
                <div>
                  <div class="row items-center justify-between">
                    <span class="text-overline text-grey-8 text-weight-bold">Assignees</span>
                    <q-btn
                      flat
                      round
                      dense
                      icon="add"
                      size="xs"
                      color="primary"
                      @click="showAddAssignee = !showAddAssignee"
                    />
                  </div>
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
                <div>
                  <div class="row items-center justify-between">
                    <span class="text-overline text-grey-8 text-weight-bold">Tags</span>
                    <q-btn
                      flat
                      round
                      dense
                      icon="add"
                      size="xs"
                      color="primary"
                      @click="showAddTag = !showAddTag"
                    />
                  </div>
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
                      square
                      removable
                      @remove="onRemoveTag(tag.id)"
                      text-color="white"
                      :style="{ backgroundColor: tag.color || '#6366f1' }"
                      class="square-chip"
                    >
                      {{ tag.name }}
                    </q-chip>
                    <div v-if="!itemTags.length" class="text-caption text-grey-5">
                      No tags linked
                    </div>
                  </div>
                </div>
                <div>
                  <div class="row items-center justify-between">
                    <span class="text-overline text-grey-8 text-weight-bold">Collaborators</span>
                    <q-btn
                      flat
                      round
                      dense
                      icon="add"
                      size="xs"
                      color="primary"
                      @click="showAddPerm = !showAddPerm"
                    />
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
                    <q-btn
                      label="Grant"
                      color="primary"
                      dense
                      size="sm"
                      @click="onSavePermission"
                      class="full-width"
                      unelevated
                    />
                  </div>
                  <div class="q-mt-xs q-gutter-y-xs">
                    <q-item v-for="p in permissions" :key="p.id" class="q-pa-xs border-bottom">
                      <q-item-section>
                        <q-item-label class="text-caption ellipsis">{{
                          p.user_email
                        }}</q-item-label>
                        <q-item-label caption class="text-overline">{{ p.role }}</q-item-label>
                      </q-item-section>
                      <q-item-section side>
                        <q-btn
                          flat
                          round
                          dense
                          icon="o_delete"
                          size="xs"
                          color="red"
                          @click="onDeletePermission(p.user_email)"
                        />
                      </q-item-section>
                    </q-item>
                    <div v-if="!permissions.length" class="text-caption text-grey-5">
                      No explicit overrides
                    </div>
                  </div>
                </div>
              </div>
            </q-expansion-item>
          </div>
        </q-card-section>
      </div>
    </q-card>
  </q-dialog>

  <!-- Create Child Item Dialog -->
  <TaskFormDialog
    v-model="createChildOpen"
    :default-parent-id="item?.id ?? null"
    :default-type="suggestedChildType"
    @saved="onChildSaved"
  />
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useTasksStore } from '../stores/tasksStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { tasksRepository } from '../repositories/tasksRepository';
import type {
  Item,
  Tag,
  Comment,
  ItemAssignee,
  ItemPermission,
  ActivityLog,
  ItemStatus,
  ItemPriority,
  ItemType,
  ItemAccessibility,
} from '../types';
import { requestConfirmation } from 'src/utils/appFeedback';
import TaskFormDialog from './TaskFormDialog.vue';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { marked } from 'src/utils/marked';

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

// Proxy Dates for Quasar Date Pickers
const startDateProxy = ref('');
const dueDateProxy = ref('');

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

// Description Edit & Markdown states
const editedDescription = ref('');
const isEditMode = ref(false);
const isMarkdownMode = ref(false);

const parsedDescription = computed(() => {
  if (!item.value || !item.value.content) return '';
  try {
    return marked.parse(item.value.content);
  } catch (err) {
    console.error('Failed to parse markdown', err);
    return item.value.content;
  }
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
const memberEmails = computed(() => tasksStore.members.map((m) => m.email));
const tagOptions = computed(() => tasksStore.tags.map((t) => ({ label: t.name, value: t.id })));

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

const statusOptions: { label: string; value: ItemStatus }[] = [
  { label: 'Todo', value: 'todo' },
  { label: 'In Progress', value: 'in_progress' },
  { label: 'Review', value: 'review' },
  { label: 'Done', value: 'done' },
  { label: 'Blocked', value: 'blocked' },
  { label: 'Archived', value: 'archived' },
];

const priorityOptions: { label: string; value: ItemPriority }[] = [
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

const loadDetails = async (silent = false) => {
  if (!props.itemId) return;
  if (!silent) {
    loadingDetails.value = true;
  }
  try {
    const details = await tasksRepository.fetchFullItemDetails(props.itemId);

    item.value = details.item;
    if (!isEditMode.value) {
      editedDescription.value = details.item.content || '';
      isMarkdownMode.value = details.item.is_markdown || false;
    }
    assignees.value = details.assignees;
    itemTags.value = details.tags;
    comments.value = details.comments;
    permissions.value = details.permissions;
    activityLogs.value = details.activityLogs;
  } catch (err) {
    console.error('Failed to load item details', err);
    if (!silent) {
      item.value = null;
    }
  } finally {
    if (!silent) {
      loadingDetails.value = false;
    }
  }
};

const onSaveDescription = async () => {
  if (!item.value) return;
  try {
    await tasksStore.updateItem(item.value.id, {
      content: editedDescription.value,
      is_markdown: isMarkdownMode.value,
    });
    isEditMode.value = false;
    await loadDetails(true);
    emit('updated');
  } catch (err) {
    console.error('Failed to save description', err);
  }
};

const onCancelDescription = () => {
  editedDescription.value = item.value?.content || '';
  isMarkdownMode.value = item.value?.is_markdown || false;
  isEditMode.value = false;
};

const onStartEdit = () => {
  if (item.value) {
    editedDescription.value = item.value.content || '';
    isMarkdownMode.value = item.value.is_markdown || false;
    isEditMode.value = true;
  }
};

const onSaveTitle = async () => {
  if (item.value && item.value.title.trim()) {
    await tasksStore.updateItem(item.value.id, { title: item.value.title.trim() });
    await loadDetails(true);
    emit('updated');
  }
};

const onSaveType = async (type: string) => {
  if (item.value) {
    item.value.type = type as ItemType;
    await tasksStore.updateItem(item.value.id, { type: type as ItemType });
    await loadDetails(true);
    emit('updated');
  }
};

const onParentUpdate = async (parentId: number | null) => {
  if (item.value) {
    item.value.parent_id = parentId;
    await tasksStore.updateItem(item.value.id, { parent_id: parentId });
    await loadDetails(true);
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

const parentItem = computed(() => {
  if (!item.value || !item.value.parent_id) return null;
  return tasksStore.items.find((i) => i.id === item.value?.parent_id) || null;
});

const onNavigateToParent = () => {
  if (item.value && item.value.parent_id) {
    emit('update:itemId', item.value.parent_id);
  }
};

const parentOptions = computed(() => {
  if (!item.value) return [];

  const descendantIds = new Set<number>();
  const stack = [item.value.id];

  while (stack.length) {
    const currentId = stack.pop();
    if (currentId == null || descendantIds.has(currentId)) continue;
    descendantIds.add(currentId);

    tasksStore.items
      .filter((i) => i.parent_id === currentId)
      .forEach((child) => stack.push(child.id));
  }

  descendantIds.delete(item.value.id);

  return tasksStore.items
    .filter((i) => !descendantIds.has(i.id) && i.id !== item.value?.id)
    .map((i) => ({
      label: `[${i.type.toUpperCase()}] ${i.title}`,
      value: i.id,
    }));
});

const statusLabel = computed(() => {
  const opt = statusOptions.find((o) => o.value === item.value?.status);
  return opt ? opt.label : item.value?.status || '';
});

const priorityLabel = computed(() => {
  const opt = priorityOptions.find((o) => o.value === item.value?.priority);
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
    case 'todo':
      return '#64748b';
    case 'in_progress':
      return '#3b82f6';
    case 'review':
      return '#f97316';
    case 'done':
      return '#22c55e';
    case 'blocked':
      return '#ef4444';
    case 'archived':
      return '#8c857b';
    default:
      return '#9ca3af';
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
    case 'low':
      return '#22c55e';
    case 'medium':
      return '#3b82f6';
    case 'high':
      return '#f97316';
    case 'urgent':
      return '#ef4444';
    default:
      return '#9ca3af';
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
    case 'project':
      return '#8b5cf6';
    case 'module':
      return '#10b981';
    case 'submodule':
      return '#06b6d4';
    case 'task':
      return '#3b82f6';
    case 'note':
      return '#f59e0b';
    case 'discussion':
      return '#14b8a6';
    case 'bug':
      return '#ef4444';
    case 'feature':
      return '#ec4899';
    default:
      return '#9ca3af';
  }
};

watch(
  () => [props.itemId, isOpen.value] as const,
  async ([newId, newIsOpen], oldVal) => {
    if (newId && newIsOpen) {
      const oldId = oldVal ? oldVal[0] : undefined;
      const oldIsOpen = oldVal ? oldVal[1] : undefined;
      if (
        oldId === undefined ||
        newId !== oldId ||
        oldIsOpen === undefined ||
        newIsOpen !== oldIsOpen
      ) {
        isEditMode.value = false;
        await loadDetails();
      }
    }
  },
);

const onStatusUpdate = async (status: ItemStatus) => {
  if (item.value) {
    await tasksStore.updateItem(item.value.id, { status });
    await loadDetails(true);
    emit('updated');
  }
};

const onPriorityUpdate = async (priority: ItemPriority) => {
  if (item.value) {
    await tasksStore.updateItem(item.value.id, { priority });
    await loadDetails(true);
    emit('updated');
  }
};

// Add / Remove Assignees
const onAddAssignee = async (email: string) => {
  if (item.value && email) {
    await tasksStore.addAssignee(item.value.id, email);
    showAddAssignee.value = false;
    selectedAssigneeEmail.value = '';
    await loadDetails(true);
    emit('updated');
  }
};

const onRemoveAssignee = async (email: string) => {
  if (item.value && email) {
    await tasksStore.removeAssignee(item.value.id, email);
    await loadDetails(true);
    emit('updated');
  }
};

// Add / Remove Tags
const onAddTag = async (tagId: number) => {
  if (item.value && tagId) {
    await tasksStore.linkTag(item.value.id, tagId);
    showAddTag.value = false;
    selectedTagId.value = null;
    await loadDetails(true);
    emit('updated');
  }
};

const onRemoveTag = async (tagId: number) => {
  if (item.value && tagId) {
    await tasksStore.unlinkTag(item.value.id, tagId);
    await loadDetails(true);
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
    await loadDetails(true);
  } catch (err) {
    console.error('Failed to post comment', err);
  }
};

const onDeleteComment = async (commentId: number) => {
  try {
    await tasksRepository.deleteComment(commentId);
    await loadDetails(true);
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
    await loadDetails(true);
  } catch (err) {
    console.error('Failed to save permissions', err);
  }
};

const onDeletePermission = async (email: string) => {
  if (!item.value) return;
  try {
    await tasksRepository.deletePermission(item.value.id, email);
    await loadDetails(true);
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

watch(
  () => item.value,
  (newItem) => {
    if (newItem) {
      startDateProxy.value = newItem.start_date ? newItem.start_date.split('T')[0]! : '';
      dueDateProxy.value = newItem.due_date ? newItem.due_date.split('T')[0]! : '';
    } else {
      startDateProxy.value = '';
      dueDateProxy.value = '';
    }
  },
  { immediate: true },
);

const onUpdateStartDate = async (val: string | null) => {
  if (item.value) {
    const isoDate = val ? new Date(val).toISOString() : null;
    await tasksStore.updateItem(item.value.id, { start_date: isoDate });
    await loadDetails(true);
    emit('updated');
  }
};

const onClearStartDate = async () => {
  startDateProxy.value = '';
  await onUpdateStartDate(null);
};

const onUpdateDueDate = async (val: string | null) => {
  if (item.value) {
    const isoDate = val ? new Date(val).toISOString() : null;
    await tasksStore.updateItem(item.value.id, { due_date: isoDate });
    await loadDetails(true);
    emit('updated');
  }
};

const onClearDueDate = async () => {
  dueDateProxy.value = '';
  await onUpdateDueDate(null);
};

// Accessibility options and helpers (only for Notes)
const accessibilityOptions: {
  label: string;
  value: ItemAccessibility;
  icon: string;
  caption: string;
}[] = [
  {
    label: 'Public',
    value: 'public',
    icon: 'lock_open',
    caption: 'Visible to all workspace members',
  },
  { label: 'Private', value: 'private', icon: 'lock', caption: 'Only visible to you (creator)' },
  {
    label: 'Restricted',
    value: 'restricted',
    icon: 'lock_person',
    caption: 'Only visible to creator, assignees, and collaborators',
  },
];

const accessibilityChipStyle = (acc: string | undefined) => {
  switch (acc || 'public') {
    case 'public':
      return { backgroundColor: '#f0fdf4', color: '#16a34a', border: '1px solid #bbf7d0' };
    case 'private':
      return { backgroundColor: '#fef2f2', color: '#dc2626', border: '1px solid #fecaca' };
    case 'restricted':
      return { backgroundColor: '#eff6ff', color: '#2563eb', border: '1px solid #bfdbfe' };
    default:
      return { backgroundColor: '#f4f4f5', color: '#71717a', border: '1px solid #e4e4e7' };
  }
};

const accessibilityIcon = (acc: string | undefined) => {
  switch (acc || 'public') {
    case 'public':
      return 'lock_open';
    case 'private':
      return 'lock';
    case 'restricted':
      return 'lock_person';
    default:
      return 'help_outline';
  }
};

const onAccessibilityUpdate = async (accessibility: 'public' | 'private' | 'restricted') => {
  if (item.value) {
    await tasksStore.updateItem(item.value.id, { accessibility });
    await loadDetails(true);
    emit('updated');
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
    case 'created':
      return `created the item: "${log.new_value}"`;
    case 'assigned':
      return `assigned the task to ${log.new_value}`;
    case 'status_changed':
      return `changed status from "${log.old_value}" to "${log.new_value}"`;
    case 'priority_changed':
      return `updated priority from "${log.old_value}" to "${log.new_value}"`;
    case 'tag_added':
      return 'added a tag';
    case 'tag_removed':
      return 'removed a tag';
    default:
      return `performed action: ${log.action}`;
  }
};

const getTypeIcon = (type: string) => {
  switch (type) {
    case 'project':
      return 'folder';
    case 'module':
      return 'view_module';
    case 'submodule':
      return 'layers';
    case 'task':
      return 'assignment';
    case 'note':
      return 'note';
    case 'discussion':
      return 'forum';
    case 'bug':
      return 'bug_report';
    case 'feature':
      return 'star';
    default:
      return 'help_outline';
  }
};

const getTypeColor = (type: string) => {
  switch (type) {
    case 'project':
      return 'indigo';
    case 'module':
      return 'blue';
    case 'submodule':
      return 'cyan';
    case 'task':
      return 'green';
    case 'note':
      return 'orange';
    case 'discussion':
      return 'teal';
    case 'bug':
      return 'red';
    case 'feature':
      return 'purple';
    default:
      return 'grey';
  }
};
</script>

<style scoped>
.details-card {
  width: 96vw;
  max-width: 1280px;
  background: #ffffff;
  border-radius: 16px;
}

.dialog-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 320px;
  gap: 0;
  height: 82vh;
  min-height: 560px;
}

.dialog-sidebar {
  width: 320px;
  background: #fbfcfd;
  overflow-y: auto;
  border-left: 1px solid rgba(0, 0, 0, 0.08);
}

.dialog-body {
  overflow-y: auto;
}

.description-shell {
  min-height: 28vh;
}

.content-desc {
  background: #f8fafc;
  padding: 12px;
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.04);
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
  border: 1px solid rgba(0, 0, 0, 0.03);
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

.description-view-area {
  min-height: 48vh;
  max-height: 56vh;
  overflow-y: auto;
  border: 1px solid rgba(0, 0, 0, 0.08);
}

.markdown-body :deep(h1),
.markdown-body :deep(h2),
.markdown-body :deep(h3) {
  margin-top: 12px;
  margin-bottom: 6px;
  font-weight: 700;
  line-height: 1.25;
}
.markdown-body :deep(h1) {
  font-size: 1.35rem;
  border-bottom: 1px solid #eaecef;
  padding-bottom: 0.2em;
}
.markdown-body :deep(h2) {
  font-size: 1.15rem;
}
.markdown-body :deep(h3) {
  font-size: 1.05rem;
}
.markdown-body :deep(p) {
  margin-top: 0;
  margin-bottom: 8px;
  line-height: 1.5;
}
.markdown-body :deep(code) {
  background-color: rgba(27, 31, 35, 0.05);
  font-family: monospace;
  padding: 0.15em 0.3em;
  border-radius: 3px;
  font-size: 85%;
}
.markdown-body :deep(pre) {
  background-color: #f6f8fa;
  padding: 12px;
  border-radius: 6px;
  overflow: auto;
}
.markdown-body :deep(pre code) {
  background-color: transparent;
  padding: 0;
}
.markdown-body :deep(ul),
.markdown-body :deep(ol) {
  padding-left: 20px;
  margin-top: 0;
  margin-bottom: 8px;
}
.markdown-body :deep(blockquote) {
  border-left: 4px solid #dfe2e5;
  color: #6a737d;
  padding: 0 1em;
  margin: 0 0 8px 0;
}

.rich-text-body :deep(p) {
  margin-top: 0;
  margin-bottom: 8px;
  line-height: 1.5;
}
.rich-text-body :deep(ul),
.rich-text-body :deep(ol) {
  padding-left: 20px;
  margin-top: 0;
  margin-bottom: 8px;
}
.rich-text-body :deep(blockquote) {
  border-left: 4px solid #dfe2e5;
  color: #6a737d;
  padding: 0 1em;
  margin: 0 0 8px 0;
}

.whitespace-pre-wrap {
  white-space: pre-wrap;
}

.hover-underline:hover {
  text-decoration: underline;
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
    grid-template-columns: 1fr;
    height: auto;
    max-height: 85vh;
  }
  .dialog-sidebar {
    width: 100%;
    border-left: none;
    border-bottom: 1px solid rgba(0, 0, 0, 0.08);
  }
  .description-view-area {
    min-height: 240px;
    max-height: 50vh;
  }
}
</style>

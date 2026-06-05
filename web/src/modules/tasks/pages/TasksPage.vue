<template>
  <q-page class="q-pa-md tasks-dashboard-page">
    <!-- Page Header Card -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold text-grey-9">Task Management</div>
            <div class="text-caption text-grey-6">Organize projects, submodules, tickets, notes, and team updates</div>
          </div>
          <div class="col-12 col-sm-auto row q-gutter-xs justify-start justify-sm-end q-mt-xs q-mt-sm-none">
            <q-btn
              color="secondary"
              outline
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="local_offer"
              label="Manage Tags"
              @click="tagManagerOpen = true"
            />
            <q-btn
              color="negative"
              outline
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="delete_sweep"
              label="Bulk Delete"
              @click="bulkDeleteOpen = true"
            />
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Create Item"
              @click="onClickCreate"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Status Summary Row -->
    <div class="row no-wrap q-col-gutter-xs q-mb-sm scroll-x">
      <div v-for="status in statusSummaryItems" :key="status.key" class="col-grow col-sm col-md status-card-wrapper">
        <q-card
          flat
          bordered
          class="status-summary-card text-center q-py-xs cursor-pointer relative-position"
          :class="{ 'active-status-card shadow-1': filters.status === status.key }"
          @click="toggleStatusFilter(status.key)"
        >
          <div class="text-caption text-grey-7 text-uppercase font-bold text-weight-medium" style="font-size: 0.65rem; line-height: 1;">
            {{ status.label }}
          </div>
          <div class="text-subtitle1 text-weight-bold text-weight-bold" :class="`text-${status.color}`" style="line-height: 1.1; margin-top: 2px;">
            {{ status.count }}
          </div>
          <div class="status-indicator-bar" :class="`bg-${status.color}`"></div>
        </q-card>
      </div>
    </div>

    <!-- Search + Filter Toolbar -->
    <div class="row items-center justify-end q-mb-sm">
      <div class="row items-center q-gutter-sm toolbar-left">
        <q-btn
          v-if="!showSearchInput"
          flat
          round
          dense
          icon="search"
          aria-label="Show search"
          @click="showSearchInput = true"
        >
          <q-tooltip>Search Tasks</q-tooltip>
        </q-btn>

        <q-input
          v-else
          v-model="filters.search"
          outlined
          dense
          class="soft-input toolbar-search"
          placeholder="Search..."
          clearable
          autofocus
        >
          <template #prepend>
            <q-icon name="search" size="18px" />
          </template>
          <template #append>
            <q-btn
              flat
              round
              dense
              icon="close"
              aria-label="Hide search"
              @click="
                () => {
                  filters.search = ''
                  showSearchInput = false
                }
              "
            >
              <q-tooltip>Hide Search</q-tooltip>
            </q-btn>
          </template>
        </q-input>

        <q-btn
          flat
          round
          dense
          icon="filter_alt"
          aria-label="Filters"
          @click="filterDrawerOpen = true"
        >
          <q-badge
            v-if="activeFilterCount > 0"
            color="primary"
            rounded
            floating
          >
            {{ activeFilterCount }}
          </q-badge>
          <q-tooltip>Open Filters</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- Loading State -->
    <PageInitialLoader v-if="loading" />

    <!-- Main Views Stack -->
    <template v-else>
      <!-- View Tabs -->
      <q-tabs
        v-model="activeTab"
        dense
        class="text-grey q-mb-md"
        active-color="primary"
        indicator-color="primary"
        align="left"
        narrow-indicator
        no-caps
      >
        <q-tab name="tree" icon="lan" label="Tree View" />
        <q-tab name="list" icon="list" label="List View" />
        <q-tab name="notes" icon="note" label="Notes" />
        <q-tab name="discussions" icon="forum" label="Discussions" />
        <q-tab name="my-tasks" icon="person" label="My Tasks" />
      </q-tabs>

      <q-tab-panels v-model="activeTab" animated class="bg-transparent">
        <!-- TREE VIEW -->
        <q-tab-panel name="tree" class="q-pa-none">
          <div class="tree-container q-gutter-y-sm" v-if="filteredTree.length">
            <div v-for="project in filteredTree" :key="project.id" class="tree-project-box floating-surface shadow-1 tree-project-padding">
              <!-- Project Header -->
              <div class="row justify-between items-center q-mb-md cursor-pointer" @click="onClickItem(project.id)">
                <div class="row items-center q-gutter-sm">
                  <q-icon :name="getTicketIcon(project.type)" :color="getTicketColor(project.type)" size="24px" />
                  <div>
                    <div class="row items-center q-gutter-x-xs">
                      <span
                        class="text-subtitle1 text-weight-bold"
                        :class="`text-${getTicketColor(project.type)}-9`"
                      >
                        {{ project.title }}
                      </span>
                      <q-icon
                        v-if="project.accessibility && project.accessibility !== 'public'"
                        :name="project.accessibility === 'private' ? 'lock' : 'lock_person'"
                        :color="project.accessibility === 'private' ? 'negative' : 'primary'"
                        size="14px"
                        class="q-ml-xs"
                      >
                        <q-tooltip>{{ project.accessibility.toUpperCase() }} Note</q-tooltip>
                      </q-icon>
                      <q-chip
                        square
                        dense
                        :style="typeChipStyle(project.type)"
                        class="status-chip text-weight-bold q-ml-sm"
                      >
                        <span class="status-chip-dot" :style="{ backgroundColor: typeDotColor(project.type) }"></span>
                        {{ project.type.toUpperCase() }}
                      </q-chip>
                      <q-chip
                        v-if="['task', 'bug', 'feature'].includes(project.type)"
                        square
                        dense
                        clickable
                        :style="statusChipStyle(project.status)"
                        class="status-chip text-weight-bold q-ml-xs"
                        @click.stop
                      >
                        <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(project.status) }"></span>
                        {{ project.status.toUpperCase() }}
                        <q-menu auto-close>
                          <q-list dense style="min-width: 120px">
                            <q-item
                              v-for="opt in statusMenuOptions"
                              :key="opt.value"
                              clickable
                              v-close-popup
                              @click="updateItemStatus(project.id, opt.value)"
                            >
                              <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                            </q-item>
                          </q-list>
                        </q-menu>
                      </q-chip>
                    </div>
                    <div v-if="project.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                      <q-chip
                        v-for="t in project.tags"
                        :key="t.id"
                        dense
                        square
                        text-color="white"
                        :style="{ backgroundColor: t.color || '#6366f1' }"
                        class="text-weight-bold text-uppercase square-chip"
                      >
                        {{ t.name }}
                      </q-chip>
                    </div>
                  </div>
                </div>
                <q-btn
                  flat
                  round
                  dense
                  icon="add"
                  size="sm"
                  :color="getTicketColor(project.type)"
                  @click.stop="onClickQuickAdd(project.id, project.type === 'project' ? 'module' : 'task')"
                >
                  <q-tooltip>{{ project.type === 'project' ? 'Add Module' : 'Add Child Item' }}</q-tooltip>
                </q-btn>
              </div>

              <!-- Modules (only for projects) -->
              <div v-if="project.type === 'project' && project.children?.length" class="modules-list tree-indent-level border-left q-gutter-y-sm">
                <template v-for="mod in project.children" :key="mod.id">
                  <!-- Render as Module if type is module -->
                  <div v-if="mod.type === 'module'" class="tree-module-box q-pa-sm rounded-borders">
                    <div class="row justify-between items-center q-mb-sm cursor-pointer" @click="onClickItem(mod.id)">
                      <div class="row items-center q-gutter-sm">
                        <q-icon name="view_module" color="blue" size="20px" />
                        <div>
                          <div class="row items-center q-gutter-x-sm">
                            <span class="text-subtitle2 text-weight-bold text-blue-9">{{ mod.title }}</span>
                            <q-icon
                              v-if="mod.accessibility && mod.accessibility !== 'public'"
                              :name="mod.accessibility === 'private' ? 'lock' : 'lock_person'"
                              :color="mod.accessibility === 'private' ? 'negative' : 'primary'"
                              size="12px"
                            >
                              <q-tooltip>{{ mod.accessibility.toUpperCase() }} Note</q-tooltip>
                            </q-icon>
                            <q-chip dense square color="blue-1" text-color="blue-8" class="text-overline">Module</q-chip>
                          </div>
                          <div v-if="mod.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                            <q-chip
                              v-for="t in mod.tags"
                              :key="t.id"
                              dense
                              square
                              text-color="white"
                              :style="{ backgroundColor: t.color || '#6366f1' }"
                              class="text-weight-bold text-uppercase square-chip"
                            >
                              {{ t.name }}
                            </q-chip>
                          </div>
                        </div>
                      </div>
                      <q-btn flat round dense icon="add" size="sm" color="blue" @click.stop="onClickQuickAdd(mod.id, 'submodule')">
                        <q-tooltip>Add Submodule</q-tooltip>
                      </q-btn>
                    </div>

                    <!-- Submodules -->
                    <div v-if="mod.children?.length" class="submodules-list tree-indent-level border-left q-gutter-y-sm">
                      <template v-for="sub in mod.children" :key="sub.id">
                        <!-- Render as Submodule if type is submodule -->
                        <div v-if="sub.type === 'submodule'" class="tree-submodule-box q-pa-sm rounded-borders">
                          <div class="row justify-between items-center q-mb-xs cursor-pointer" @click="onClickItem(sub.id)">
                            <div class="row items-center q-gutter-sm">
                              <q-icon name="layers" color="cyan" size="18px" />
                              <div>
                                <div class="row items-center q-gutter-x-sm">
                                  <span class="text-body2 text-weight-bold text-cyan-9">{{ sub.title }}</span>
                                  <q-icon
                                    v-if="sub.accessibility && sub.accessibility !== 'public'"
                                    :name="sub.accessibility === 'private' ? 'lock' : 'lock_person'"
                                    :color="sub.accessibility === 'private' ? 'negative' : 'primary'"
                                    size="12px"
                                  >
                                    <q-tooltip>{{ sub.accessibility.toUpperCase() }} Note</q-tooltip>
                                  </q-icon>
                                  <q-chip dense square color="cyan-1" text-color="cyan-8" class="text-overline">Submodule</q-chip>
                                </div>
                                <div v-if="sub.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                                  <q-chip
                                    v-for="t in sub.tags"
                                    :key="t.id"
                                    dense
                                    square
                                    text-color="white"
                                    :style="{ backgroundColor: t.color || '#6366f1' }"
                                    class="text-weight-bold text-uppercase square-chip"
                                  >
                                    {{ t.name }}
                                  </q-chip>
                                </div>
                              </div>
                            </div>
                            <q-btn flat round dense icon="add" size="xs" color="cyan" @click.stop="onClickQuickAdd(sub.id, 'task')">
                              <q-tooltip>Add Task/Bug/Feature</q-tooltip>
                            </q-btn>
                          </div>

                          <!-- Tickets / Child items -->
                          <div v-if="sub.children?.length" class="tickets-list tree-indent-level border-left q-mt-sm q-gutter-y-xs">
                            <div
                              v-for="ticket in sub.children"
                              :key="ticket.id"
                              class="ticket-row row justify-between items-center q-pa-xs rounded-borders cursor-pointer"
                              @click="onClickItem(ticket.id)"
                            >
                              <div class="row items-center q-gutter-sm">
                                <q-icon :name="getTicketIcon(ticket.type)" :color="getTicketColor(ticket.type)" size="16px" />
                                <div>
                                  <div class="row items-center q-gutter-x-sm">
                                    <span class="text-body2 text-grey-9 text-weight-medium">
                                      <span v-if="ticket.type === 'task'" class="text-primary text-weight-bold q-mr-xs">#{{ ticket.id }}</span>
                                      {{ ticket.title }}
                                    </span>
                                    <q-icon
                                      v-if="ticket.accessibility && ticket.accessibility !== 'public'"
                                      :name="ticket.accessibility === 'private' ? 'lock' : 'lock_person'"
                                      :color="ticket.accessibility === 'private' ? 'negative' : 'primary'"
                                      size="12px"
                                    >
                                      <q-tooltip>{{ ticket.accessibility.toUpperCase() }} Note</q-tooltip>
                                    </q-icon>
                                    <q-chip
                                      square
                                      dense
                                      clickable
                                      :style="statusChipStyle(ticket.status)"
                                      class="status-chip text-weight-bold"
                                      @click.stop
                                    >
                                      <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(ticket.status) }"></span>
                                      {{ ticket.status.toUpperCase() }}
                                      <q-menu auto-close>
                                        <q-list dense style="min-width: 120px">
                                          <q-item
                                            v-for="opt in statusMenuOptions"
                                            :key="opt.value"
                                            clickable
                                            v-close-popup
                                            @click="updateItemStatus(ticket.id, opt.value)"
                                          >
                                            <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                                          </q-item>
                                        </q-list>
                                      </q-menu>
                                    </q-chip>
                                    <q-chip
                                      v-if="ticket.priority"
                                      square
                                      dense
                                      clickable
                                      :style="priorityChipStyle(ticket.priority)"
                                      class="status-chip text-weight-bold"
                                      @click.stop
                                    >
                                      <span class="status-chip-dot" :style="{ backgroundColor: priorityDotColor(ticket.priority) }"></span>
                                      {{ ticket.priority.toUpperCase() }}
                                      <q-menu auto-close>
                                        <q-list dense style="min-width: 120px">
                                          <q-item
                                            v-for="opt in priorityMenuOptions"
                                            :key="opt.value"
                                            clickable
                                            v-close-popup
                                            @click="updateItemPriority(ticket.id, opt.value)"
                                          >
                                            <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                                          </q-item>
                                        </q-list>
                                      </q-menu>
                                    </q-chip>
                                  </div>
                                  <div v-if="ticket.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                                    <q-chip
                                      v-for="t in ticket.tags"
                                      :key="t.id"
                                      dense
                                      square
                                      text-color="white"
                                      :style="{ backgroundColor: t.color || '#6366f1' }"
                                      class="text-weight-bold text-uppercase square-chip"
                                    >
                                      {{ t.name }}
                                    </q-chip>
                                  </div>
                                </div>
                              </div>
                              <q-btn
                                flat
                                round
                                dense
                                icon="add"
                                size="xs"
                                :color="getTicketColor(ticket.type)"
                                @click.stop="onClickQuickAdd(ticket.id, 'task')"
                              >
                                <q-tooltip>Add Child Item</q-tooltip>
                              </q-btn>
                            </div>
                          </div>
                        </div>

                        <!-- Render as direct child of module if not submodule -->
                        <div
                          v-else
                          class="ticket-row row justify-between items-center q-pa-xs rounded-borders cursor-pointer q-mb-xs"
                          @click="onClickItem(sub.id)"
                        >
                          <div class="row items-center q-gutter-sm">
                            <q-icon :name="getTicketIcon(sub.type)" :color="getTicketColor(sub.type)" size="16px" />
                            <div>
                              <div class="row items-center q-gutter-x-sm">
                                <span class="text-body2 text-grey-9 text-weight-medium">
                                  <span v-if="sub.type === 'task'" class="text-primary text-weight-bold q-mr-xs">#{{ sub.id }}</span>
                                  {{ sub.title }}
                                </span>
                                <q-icon
                                  v-if="sub.accessibility && sub.accessibility !== 'public'"
                                  :name="sub.accessibility === 'private' ? 'lock' : 'lock_person'"
                                  :color="sub.accessibility === 'private' ? 'negative' : 'primary'"
                                  size="12px"
                                >
                                  <q-tooltip>{{ sub.accessibility.toUpperCase() }} Note</q-tooltip>
                                </q-icon>
                                <q-chip
                                  square
                                  dense
                                  clickable
                                  :style="statusChipStyle(sub.status)"
                                  class="status-chip text-weight-bold"
                                  @click.stop
                                >
                                  <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(sub.status) }"></span>
                                  {{ sub.status.toUpperCase() }}
                                  <q-menu auto-close>
                                    <q-list dense style="min-width: 120px">
                                      <q-item
                                        v-for="opt in statusMenuOptions"
                                        :key="opt.value"
                                        clickable
                                        v-close-popup
                                        @click="updateItemStatus(sub.id, opt.value)"
                                      >
                                        <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                                      </q-item>
                                    </q-list>
                                  </q-menu>
                                </q-chip>
                                <q-chip
                                  v-if="sub.priority"
                                  square
                                  dense
                                  clickable
                                  :style="priorityChipStyle(sub.priority)"
                                  class="status-chip text-weight-bold"
                                  @click.stop
                                >
                                  <span class="status-chip-dot" :style="{ backgroundColor: priorityDotColor(sub.priority) }"></span>
                                  {{ sub.priority.toUpperCase() }}
                                  <q-menu auto-close>
                                    <q-list dense style="min-width: 120px">
                                      <q-item
                                        v-for="opt in priorityMenuOptions"
                                        :key="opt.value"
                                        clickable
                                        v-close-popup
                                        @click="updateItemPriority(sub.id, opt.value)"
                                      >
                                        <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                                      </q-item>
                                    </q-list>
                                  </q-menu>
                                </q-chip>
                              </div>
                              <div v-if="sub.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                                <q-chip
                                  v-for="t in sub.tags"
                                  :key="t.id"
                                  dense
                                  square
                                  text-color="white"
                                  :style="{ backgroundColor: t.color || '#6366f1' }"
                                  class="text-weight-bold text-uppercase square-chip"
                                >
                                  {{ t.name }}
                                </q-chip>
                              </div>
                            </div>
                          </div>
                          <q-btn
                            flat
                            round
                            dense
                            icon="add"
                            size="xs"
                            :color="getTicketColor(sub.type)"
                            @click.stop="onClickQuickAdd(sub.id, 'task')"
                          >
                            <q-tooltip>Add Child Item</q-tooltip>
                          </q-btn>
                        </div>
                      </template>
                    </div>
                  </div>

                  <!-- Render as direct child of project if not module -->
                  <div
                    v-else
                    class="ticket-row row justify-between items-center q-pa-xs rounded-borders cursor-pointer q-mb-xs"
                    @click="onClickItem(mod.id)"
                  >
                    <div class="row items-center q-gutter-sm">
                      <q-icon :name="getTicketIcon(mod.type)" :color="getTicketColor(mod.type)" size="16px" />
                      <div>
                        <div class="row items-center q-gutter-x-sm">
                          <span class="text-body2 text-grey-9 text-weight-medium">{{ mod.title }}</span>
                          <q-icon
                            v-if="mod.accessibility && mod.accessibility !== 'public'"
                            :name="mod.accessibility === 'private' ? 'lock' : 'lock_person'"
                            :color="mod.accessibility === 'private' ? 'negative' : 'primary'"
                            size="12px"
                          >
                            <q-tooltip>{{ mod.accessibility.toUpperCase() }} Note</q-tooltip>
                          </q-icon>
                          <q-chip
                            square
                            dense
                            clickable
                            :style="statusChipStyle(mod.status)"
                            class="status-chip text-weight-bold"
                            @click.stop
                          >
                            <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(mod.status) }"></span>
                            {{ mod.status.toUpperCase() }}
                            <q-menu auto-close>
                              <q-list dense style="min-width: 120px">
                                <q-item
                                  v-for="opt in statusMenuOptions"
                                  :key="opt.value"
                                  clickable
                                  v-close-popup
                                  @click="updateItemStatus(mod.id, opt.value)"
                                >
                                  <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                                </q-item>
                              </q-list>
                            </q-menu>
                          </q-chip>
                          <q-chip
                            v-if="mod.priority"
                            square
                            dense
                            clickable
                            :style="priorityChipStyle(mod.priority)"
                            class="status-chip text-weight-bold"
                            @click.stop
                          >
                            <span class="status-chip-dot" :style="{ backgroundColor: priorityDotColor(mod.priority) }"></span>
                            {{ mod.priority.toUpperCase() }}
                            <q-menu auto-close>
                              <q-list dense style="min-width: 120px">
                                <q-item
                                  v-for="opt in priorityMenuOptions"
                                  :key="opt.value"
                                  clickable
                                  v-close-popup
                                  @click="updateItemPriority(mod.id, opt.value)"
                                >
                                  <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                                </q-item>
                              </q-list>
                            </q-menu>
                          </q-chip>
                        </div>
                        <div v-if="mod.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                          <q-chip
                            v-for="t in mod.tags"
                            :key="t.id"
                            dense
                            square
                            text-color="white"
                            :style="{ backgroundColor: t.color || '#6366f1' }"
                            class="text-weight-bold text-uppercase square-chip"
                          >
                            {{ t.name }}
                          </q-chip>
                        </div>
                      </div>
                    </div>
                    <q-btn
                      flat
                      round
                      dense
                      icon="add"
                      size="xs"
                      :color="getTicketColor(mod.type)"
                      @click.stop="onClickQuickAdd(mod.id, 'task')"
                    >
                      <q-tooltip>Add Child Item</q-tooltip>
                    </q-btn>
                  </div>
                </template>
              </div>

              <div v-else-if="project.type !== 'project' && project.children?.length" class="tickets-list tree-indent-level border-left q-mt-sm q-gutter-y-xs">
                <div
                  v-for="child in project.children"
                  :key="child.id"
                  class="ticket-row row justify-between items-center q-pa-xs rounded-borders cursor-pointer"
                  @click="onClickItem(child.id)"
                >
                  <div class="row items-center q-gutter-sm">
                    <q-icon :name="getTicketIcon(child.type)" :color="getTicketColor(child.type)" size="16px" />
                    <div>
                      <div class="row items-center q-gutter-x-sm">
                        <span class="text-body2 text-grey-9 text-weight-medium">
                          <span v-if="child.type === 'task'" class="text-primary text-weight-bold q-mr-xs">#{{ child.id }}</span>
                          {{ child.title }}
                        </span>
                        <q-icon
                          v-if="child.accessibility && child.accessibility !== 'public'"
                          :name="child.accessibility === 'private' ? 'lock' : 'lock_person'"
                          :color="child.accessibility === 'private' ? 'negative' : 'primary'"
                          size="12px"
                        >
                          <q-tooltip>{{ child.accessibility.toUpperCase() }} Note</q-tooltip>
                        </q-icon>
                        <q-chip
                          square
                          dense
                          clickable
                          :style="statusChipStyle(child.status)"
                          class="status-chip text-weight-bold"
                          @click.stop
                        >
                          <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(child.status) }"></span>
                          {{ child.status.toUpperCase() }}
                          <q-menu auto-close>
                            <q-list dense style="min-width: 120px">
                              <q-item
                                v-for="opt in statusMenuOptions"
                                :key="opt.value"
                                clickable
                                v-close-popup
                                @click="updateItemStatus(child.id, opt.value)"
                              >
                                <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                              </q-item>
                            </q-list>
                          </q-menu>
                        </q-chip>
                        <q-chip
                          v-if="child.priority"
                          square
                          dense
                          clickable
                          :style="priorityChipStyle(child.priority)"
                          class="status-chip text-weight-bold"
                          @click.stop
                        >
                          <span class="status-chip-dot" :style="{ backgroundColor: priorityDotColor(child.priority) }"></span>
                          {{ child.priority.toUpperCase() }}
                          <q-menu auto-close>
                            <q-list dense style="min-width: 120px">
                              <q-item
                                v-for="opt in priorityMenuOptions"
                                :key="opt.value"
                                clickable
                                v-close-popup
                                @click="updateItemPriority(child.id, opt.value)"
                              >
                                <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                              </q-item>
                            </q-list>
                          </q-menu>
                        </q-chip>
                      </div>
                      <div v-if="child.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                        <q-chip
                          v-for="t in child.tags"
                          :key="t.id"
                          dense
                          square
                          text-color="white"
                          :style="{ backgroundColor: t.color || '#6366f1' }"
                          class="text-weight-bold text-uppercase square-chip"
                        >
                          {{ t.name }}
                        </q-chip>
                      </div>
                    </div>
                  </div>
                  <q-btn
                    flat
                    round
                    dense
                    icon="add"
                    size="xs"
                    :color="getTicketColor(child.type)"
                    @click.stop="onClickQuickAdd(child.id, 'task')"
                  >
                    <q-tooltip>Add Child Item</q-tooltip>
                  </q-btn>
                </div>
              </div>
            </div>
          </div>
          <div v-else class="text-center q-pa-xl floating-surface shadow-1">
            <q-icon name="folder_open" size="48px" class="text-grey-5 q-mb-md" />
            <div class="text-subtitle1 text-grey-9 text-weight-bold">No Projects Found</div>
            <div class="text-body2 text-grey-6">Create a Project to begin building your task hierarchy.</div>
          </div>
        </q-tab-panel>


        <!-- LIST VIEW -->
        <q-tab-panel name="list" class="q-pa-none">
          <q-card flat class="floating-surface shadow-1">
            <q-card-section class="q-pa-none">
              <q-table
                :rows="filteredList"
                :columns="listColumns"
                row-key="id"
                flat
                dense
                class="tasks-list-table"
                :pagination="{ rowsPerPage: 25 }"
                hide-pagination
                @row-click="(evt, row) => onClickItem(row.id)"
              >
                <template #body-cell-id="cellProps">
                  <q-td :props="cellProps">
                    <span v-if="cellProps.row.type === 'task'" class="text-primary text-weight-bold">#{{ cellProps.value }}</span>
                    <span v-else class="text-grey-7">#{{ cellProps.value }}</span>
                  </q-td>
                </template>
                <template #body-cell-title="cellProps">
                  <q-td :props="cellProps">
                    <div>
                      <div class="row items-center no-wrap">
                        <span class="text-weight-medium">{{ cellProps.value }}</span>
                        <q-icon
                          v-if="cellProps.row.accessibility && cellProps.row.accessibility !== 'public'"
                          :name="cellProps.row.accessibility === 'private' ? 'lock' : 'lock_person'"
                          :color="cellProps.row.accessibility === 'private' ? 'negative' : 'primary'"
                          size="14px"
                          class="q-ml-xs"
                        >
                          <q-tooltip>{{ cellProps.row.accessibility.toUpperCase() }} Note</q-tooltip>
                        </q-icon>
                      </div>
                      <div v-if="cellProps.row.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                        <q-chip
                          v-for="t in cellProps.row.tags"
                          :key="t.id"
                          dense
                          square
                          text-color="white"
                          :style="{ backgroundColor: t.color || '#6366f1' }"
                          class="text-weight-bold text-uppercase square-chip"
                        >
                          {{ t.name }}
                        </q-chip>
                      </div>
                    </div>
                  </q-td>
                </template>
                <template #body-cell-type="cellProps">
                  <q-td :props="cellProps">
                    <q-chip
                      square
                      dense
                      :style="typeChipStyle(cellProps.value)"
                      class="status-chip text-weight-bold"
                    >
                      <span class="status-chip-dot" :style="{ backgroundColor: typeDotColor(cellProps.value) }"></span>
                      {{ cellProps.value.toUpperCase() }}
                    </q-chip>
                  </q-td>
                </template>

                <template #body-cell-status="cellProps">
                  <q-td :props="cellProps">
                    <q-chip
                      square
                      dense
                      clickable
                      :style="statusChipStyle(cellProps.value)"
                      class="status-chip text-weight-bold"
                      @click.stop
                    >
                      <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(cellProps.value) }"></span>
                      {{ cellProps.value.toUpperCase() }}
                      <q-menu auto-close>
                        <q-list dense style="min-width: 120px">
                          <q-item
                            v-for="opt in statusMenuOptions"
                            :key="opt.value"
                            clickable
                            v-close-popup
                            @click="updateItemStatus(cellProps.row.id, opt.value)"
                          >
                            <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                          </q-item>
                        </q-list>
                      </q-menu>
                    </q-chip>
                  </q-td>
                </template>

                <template #body-cell-priority="cellProps">
                  <q-td :props="cellProps">
                    <q-chip
                      square
                      dense
                      clickable
                      :style="priorityChipStyle(cellProps.value)"
                      class="status-chip text-weight-bold"
                      @click.stop
                    >
                      <span class="status-chip-dot" :style="{ backgroundColor: priorityDotColor(cellProps.value) }"></span>
                      {{ cellProps.value.toUpperCase() }}
                      <q-menu auto-close>
                        <q-list dense style="min-width: 120px">
                          <q-item
                            v-for="opt in priorityMenuOptions"
                            :key="opt.value"
                            clickable
                            v-close-popup
                            @click="updateItemPriority(cellProps.row.id, opt.value)"
                          >
                            <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                          </q-item>
                        </q-list>
                      </q-menu>
                    </q-chip>
                  </q-td>
                </template>

                <template #body-cell-due_date="cellProps">
                  <q-td :props="cellProps">
                    <span class="text-caption text-grey-8">{{ cellProps.value ? new Date(cellProps.value).toLocaleDateString() : 'N/A' }}</span>
                  </q-td>
                </template>
              </q-table>
            </q-card-section>
          </q-card>
        </q-tab-panel>

        <!-- NOTES VIEW -->
        <q-tab-panel name="notes" class="q-pa-none">
          <div class="row q-col-gutter-md">
            <div
              v-for="n in filteredNotes"
              :key="n.id"
              class="col-12 col-sm-6 col-md-4 cursor-pointer"
              @click="onClickItem(n.id)"
            >
              <q-card flat class="floating-surface shadow-1 card-hover">
                <q-card-section>
                  <div class="row items-center justify-between q-mb-sm">
                    <q-chip dense square color="amber-1" text-color="amber-9" class="status-chip text-weight-bold">
                      <span class="status-chip-dot" style="background-color: #d97706"></span>
                      NOTE
                    </q-chip>
                    <div class="row items-center q-gutter-x-xs">
                      <q-icon
                        v-if="n.accessibility && n.accessibility !== 'public'"
                        :name="n.accessibility === 'private' ? 'lock' : 'lock_person'"
                        :color="n.accessibility === 'private' ? 'negative' : 'primary'"
                        size="14px"
                      >
                        <q-tooltip>{{ n.accessibility.toUpperCase() }} Note</q-tooltip>
                      </q-icon>
                      <span class="text-caption text-grey-5">{{ formatDateShort(n.created_at) }}</span>
                    </div>
                  </div>
                  <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">{{ n.title }}</div>
                  <div class="text-body2 text-grey-7 ellipsis-3-lines" v-html="n.content || 'No details provided.'"></div>
                </q-card-section>
              </q-card>
            </div>
            <div v-if="!filteredNotes.length" class="col-12 text-center q-pa-xl floating-surface shadow-1">
              <q-icon name="note" size="48px" class="text-grey-5 q-mb-md" />
              <div class="text-subtitle1 text-grey-9 text-weight-bold">No Notes Found</div>
              <div class="text-body2 text-grey-6">Create a note to keep track of ideas or documentation.</div>
            </div>
          </div>
        </q-tab-panel>

        <!-- DISCUSSIONS VIEW -->
        <q-tab-panel name="discussions" class="q-pa-none">
          <div class="row q-col-gutter-md">
            <div
              v-for="d in filteredDiscussions"
              :key="d.id"
              class="col-12 col-sm-6 col-md-4 cursor-pointer"
              @click="onClickItem(d.id)"
            >
              <q-card flat class="floating-surface shadow-1 card-hover">
                <q-card-section>
                  <div class="row items-center justify-between q-mb-sm">
                    <q-chip dense square color="teal-1" text-color="teal-8" class="text-overline text-weight-bold">Discussion</q-chip>
                    <span class="text-caption text-grey-5">{{ formatDateShort(d.created_at) }}</span>
                  </div>
                  <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">{{ d.title }}</div>
                  <div class="text-body2 text-grey-7 ellipsis-3-lines">{{ d.content || 'No details provided.' }}</div>
                  <div class="row items-center q-mt-md text-primary text-weight-bold text-caption">
                    <q-icon name="comment" class="q-mr-xs" /> View Comments
                  </div>
                </q-card-section>
              </q-card>
            </div>
            <div v-if="!filteredDiscussions.length" class="col-12 text-center q-pa-xl floating-surface shadow-1">
              <q-icon name="forum" size="48px" class="text-grey-5 q-mb-md" />
              <div class="text-subtitle1 text-grey-9 text-weight-bold">No Discussions Found</div>
              <div class="text-body2 text-grey-6">Create a discussion under any project, module, or submodule.</div>
            </div>
          </div>
        </q-tab-panel>

        <!-- MY TASKS VIEW -->
        <q-tab-panel name="my-tasks" class="q-pa-none">
          <q-card flat class="floating-surface shadow-1">
            <q-card-section class="q-pa-none">
              <q-table
                :rows="myTasksList"
                :columns="listColumns"
                row-key="id"
                flat
                dense
                :pagination="{ rowsPerPage: 25 }"
                hide-pagination
                @row-click="(evt, row) => onClickItem(row.id)"
              >
                <template #body-cell-id="cellProps">
                  <q-td :props="cellProps">
                    <span v-if="cellProps.row.type === 'task'" class="text-primary text-weight-bold">#{{ cellProps.value }}</span>
                    <span v-else class="text-grey-7">#{{ cellProps.value }}</span>
                  </q-td>
                </template>
                <template #body-cell-title="cellProps">
                  <q-td :props="cellProps">
                    <div>
                      <div class="row items-center no-wrap">
                        <span class="text-weight-medium">{{ cellProps.value }}</span>
                        <q-icon
                          v-if="cellProps.row.accessibility && cellProps.row.accessibility !== 'public'"
                          :name="cellProps.row.accessibility === 'private' ? 'lock' : 'lock_person'"
                          :color="cellProps.row.accessibility === 'private' ? 'negative' : 'primary'"
                          size="14px"
                          class="q-ml-xs"
                        >
                          <q-tooltip>{{ cellProps.row.accessibility.toUpperCase() }} Note</q-tooltip>
                        </q-icon>
                      </div>
                      <div v-if="cellProps.row.tags?.length" class="row q-gutter-x-xs q-mt-xs">
                        <q-chip
                          v-for="t in cellProps.row.tags"
                          :key="t.id"
                          dense
                          square
                          text-color="white"
                          :style="{ backgroundColor: t.color || '#6366f1' }"
                          class="text-weight-bold text-uppercase square-chip"
                        >
                          {{ t.name }}
                        </q-chip>
                      </div>
                    </div>
                  </q-td>
                </template>
                <template #body-cell-type="cellProps">
                  <q-td :props="cellProps">
                    <q-chip
                      square
                      dense
                      :style="typeChipStyle(cellProps.value)"
                      class="status-chip text-weight-bold"
                    >
                      <span class="status-chip-dot" :style="{ backgroundColor: typeDotColor(cellProps.value) }"></span>
                      {{ cellProps.value.toUpperCase() }}
                    </q-chip>
                  </q-td>
                </template>

                <template #body-cell-status="cellProps">
                  <q-td :props="cellProps">
                    <q-chip
                      square
                      dense
                      clickable
                      :style="statusChipStyle(cellProps.value)"
                      class="status-chip text-weight-bold"
                      @click.stop
                    >
                      <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(cellProps.value) }"></span>
                      {{ cellProps.value.toUpperCase() }}
                      <q-menu auto-close>
                        <q-list dense style="min-width: 120px">
                          <q-item
                            v-for="opt in statusMenuOptions"
                            :key="opt.value"
                            clickable
                            v-close-popup
                            @click="updateItemStatus(cellProps.row.id, opt.value)"
                          >
                            <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                          </q-item>
                        </q-list>
                      </q-menu>
                    </q-chip>
                  </q-td>
                </template>

                <template #body-cell-priority="cellProps">
                  <q-td :props="cellProps">
                    <q-chip
                      square
                      dense
                      clickable
                      :style="priorityChipStyle(cellProps.value)"
                      class="status-chip text-weight-bold"
                      @click.stop
                    >
                      <span class="status-chip-dot" :style="{ backgroundColor: priorityDotColor(cellProps.value) }"></span>
                      {{ cellProps.value.toUpperCase() }}
                      <q-menu auto-close>
                        <q-list dense style="min-width: 120px">
                          <q-item
                            v-for="opt in priorityMenuOptions"
                            :key="opt.value"
                            clickable
                            v-close-popup
                            @click="updateItemPriority(cellProps.row.id, opt.value)"
                          >
                            <q-item-section>{{ opt.label.toUpperCase() }}</q-item-section>
                          </q-item>
                        </q-list>
                      </q-menu>
                    </q-chip>
                  </q-td>
                </template>

                <template #body-cell-due_date="cellProps">
                  <q-td :props="cellProps">
                    <span class="text-caption text-grey-8">{{ cellProps.value ? new Date(cellProps.value).toLocaleDateString() : 'N/A' }}</span>
                  </q-td>
                </template>
              </q-table>
            </q-card-section>
          </q-card>
        </q-tab-panel>
      </q-tab-panels>

      <!-- Pagination Controls (Only for non-tree views) -->
      <div v-if="activeTab !== 'tree' && totalPages > 1" class="row justify-center q-mt-md q-mb-lg">
        <q-pagination
          v-model="page"
          :max="totalPages"
          :max-pages="7"
          direction-links
          boundary-links
          color="primary"
          @update:model-value="onPageChange"
        />
      </div>
    </template>

    <!-- Filter Sidebar Drawer -->
    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <div class="q-gutter-y-md">
        <!-- Type Filter -->
        <div v-if="['tree', 'list', 'my-tasks'].includes(activeTab)">
          <q-select
            v-model="filters.type"
            :options="typeFilterOptions"
            label="Type"
            outlined
            dense
            clearable
            emit-value
            map-options
            class="soft-input"
          />
        </div>

        <!-- Status Filter -->
        <div>
          <q-select
            v-model="filters.status"
            :options="statusFilterOptions"
            label="Status"
            outlined
            dense
            clearable
            emit-value
            map-options
            class="soft-input"
          />
        </div>

        <!-- Priority Filter -->
        <div>
          <q-select
            v-model="filters.priority"
            :options="priorityFilterOptions"
            label="Priority"
            outlined
            dense
            clearable
            emit-value
            map-options
            class="soft-input"
          />
        </div>

        <!-- Assignee Filter -->
        <div v-if="activeTab !== 'my-tasks'">
          <q-select
            v-model="filters.assignee"
            :options="assigneeFilterOptions"
            label="Assignee"
            outlined
            dense
            clearable
            class="soft-input"
          />
        </div>

        <!-- Tag Filter -->
        <div>
          <q-select
            v-model="filters.tagId"
            :options="tagFilterOptions"
            label="Tag"
            outlined
            dense
            clearable
            emit-value
            map-options
            class="soft-input"
          />
        </div>

        <!-- Reset Button -->
        <div class="row q-gutter-sm justify-end">
          <q-btn flat no-caps label="Reset" @click="resetFilters" />
        </div>
      </div>
    </FilterSidebar>

    <!-- Dialog Popups -->
    <TaskFormDialog
      v-model="formOpen"
      :default-parent-id="quickAddParentId"
      :default-type="quickAddType"
    />

    <TagManagerDialog
      v-model="tagManagerOpen"
    />

    <TaskDetailsDialog
      v-model="detailsOpen"
      v-model:item-id="selectedItemId"
    />

    <BulkDeleteDialog
      v-model="bulkDeleteOpen"
      @deleted="refreshData"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useTasksStore } from '../stores/tasksStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ItemType, ItemStatus, ItemPriority } from '../types';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import TaskFormDialog from '../components/TaskFormDialog.vue';
import TagManagerDialog from '../components/TagManagerDialog.vue';
import TaskDetailsDialog from '../components/TaskDetailsDialog.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import BulkDeleteDialog from '../components/BulkDeleteDialog.vue';

const statusMenuOptions: { label: string; value: ItemStatus }[] = [
  { label: 'Todo', value: 'todo' },
  { label: 'In Progress', value: 'in_progress' },
  { label: 'Review', value: 'review' },
  { label: 'Done', value: 'done' },
  { label: 'Blocked', value: 'blocked' },
  { label: 'Archived', value: 'archived' },
];

const priorityMenuOptions: { label: string; value: ItemPriority }[] = [
  { label: 'Low', value: 'low' },
  { label: 'Medium', value: 'medium' },
  { label: 'High', value: 'high' },
  { label: 'Urgent', value: 'urgent' },
];

const updateItemStatus = async (itemId: number, nextStatus: ItemStatus) => {
  try {
    await tasksStore.updateItem(itemId, { status: nextStatus });
  } catch (err) {
    console.error('Failed to update task status from list:', err);
  }
};

const updateItemPriority = async (itemId: number, nextPriority: ItemPriority) => {
  try {
    await tasksStore.updateItem(itemId, { priority: nextPriority });
  } catch (err) {
    console.error('Failed to update task priority from list:', err);
  }
};

const tasksStore = useTasksStore();
const authStore = useAuthStore();

// Tab view states
const activeTab = ref('tree');
const loading = computed(() => tasksStore.loading);
const page = ref(1);
const pageSize = ref(25);
const totalPages = computed(() => tasksStore.totalPages);

// Filter drawer states
const filterDrawerOpen = ref(false);
const showSearchInput = ref(false);

// Filter states
const filters = ref({
  search: '',
  type: null as string | null,
  status: null as string | null,
  priority: null as string | null,
  assignee: null as string | null,
  tagId: null as number | null,
});

const resetFilters = () => {
  filters.value.search = '';
  filters.value.type = null;
  filters.value.status = null;
  filters.value.priority = null;
  filters.value.assignee = null;
  filters.value.tagId = null;
  filterDrawerOpen.value = false;
};

const activeFilterCount = computed(() => {
  let count = 0;
  if (filters.value.type) count++;
  if (filters.value.status) count++;
  if (filters.value.priority) count++;
  if (filters.value.assignee) count++;
  if (filters.value.tagId) count++;
  return count;
});

// Options Lists for Filters
const typeFilterOptions = [
  { label: 'Project', value: 'project' },
  { label: 'Module', value: 'module' },
  { label: 'Submodule', value: 'submodule' },
  { label: 'Task / Ticket', value: 'task' },
  { label: 'Feature Request', value: 'feature' },
  { label: 'Bug Report', value: 'bug' },
  { label: 'Note', value: 'note' },
  { label: 'Discussion', value: 'discussion' },
];

const statusFilterOptions = [
  { label: 'Todo', value: 'todo' },
  { label: 'In Progress', value: 'in_progress' },
  { label: 'Review', value: 'review' },
  { label: 'Done', value: 'done' },
  { label: 'Blocked', value: 'blocked' },
  { label: 'Archived', value: 'archived' },
];

const priorityFilterOptions = [
  { label: 'Low', value: 'low' },
  { label: 'Medium', value: 'medium' },
  { label: 'High', value: 'high' },
  { label: 'Urgent', value: 'urgent' },
];

const assigneeFilterOptions = computed(() => tasksStore.members.map((m) => m.email));
const tagFilterOptions = computed(() => tasksStore.tags.map((t) => ({ label: t.name, value: t.id })));

// Columns for List View Table
const listColumns = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' as const, sortable: true },
  { name: 'title', label: 'Title', field: 'title', align: 'left' as const, sortable: true },
  { name: 'type', label: 'Type', field: 'type', align: 'left' as const, sortable: true, classes: 'gt-xs', headerClasses: 'gt-xs' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const, sortable: true },
  { name: 'priority', label: 'Priority', field: 'priority', align: 'left' as const, sortable: true, classes: 'gt-xs', headerClasses: 'gt-xs' },
  { name: 'due_date', label: 'Due Date', field: 'due_date', align: 'left' as const, sortable: true, classes: 'gt-xs', headerClasses: 'gt-xs' },
];

// Dialog triggers
const formOpen = ref(false);
const tagManagerOpen = ref(false);
const detailsOpen = ref(false);
const bulkDeleteOpen = ref(false);
const selectedItemId = ref<number | null>(null);

// Quick Add states
const quickAddParentId = ref<number | null>(null);
const quickAddType = ref<ItemType>('task');

const onClickCreate = () => {
  quickAddParentId.value = null;
  quickAddType.value = 'task';
  formOpen.value = true;
};

const onClickQuickAdd = (parentId: number, type: ItemType) => {
  const parentItem = tasksStore.items.find(i => i.id === parentId);
  quickAddParentId.value = parentId;
  quickAddType.value = parentItem?.type === 'note' ? 'note' : type;
  formOpen.value = true;
};

const onClickItem = (itemId: number) => {
  selectedItemId.value = itemId;
  detailsOpen.value = true;
};

// Actions
const refreshData = () => {
  const queryFilters = {
    search: filters.value.search,
    type: filters.value.type,
    status: filters.value.status,
    priority: filters.value.priority,
    assignee: filters.value.assignee,
    tagId: filters.value.tagId,
    myTasksEmail: null as string | null,
    includeParents: activeTab.value === 'tree',
  };

  if (activeTab.value === 'tree') {
    void tasksStore.fetchItemsAction(authStore.tenantId, queryFilters, 1, 10000);
  } else {
    if (activeTab.value === 'notes') {
      queryFilters.type = 'note';
    } else if (activeTab.value === 'discussions') {
      queryFilters.type = 'discussion';
    } else if (activeTab.value === 'my-tasks') {
      queryFilters.myTasksEmail = authStore.user?.email || null;
    }

    void tasksStore.fetchItemsAction(authStore.tenantId, queryFilters, page.value, pageSize.value);
  }
};

const onPageChange = () => {
  refreshData();
};

watch(
  activeTab,
  () => {
    page.value = 1;
    refreshData();
  }
);

let searchTimeout: ReturnType<typeof setTimeout> | null = null;
watch(
  () => ({ ...filters.value }),
  (newVal, oldVal) => {
    page.value = 1;
    if (newVal.search !== oldVal?.search) {
      if (searchTimeout) clearTimeout(searchTimeout);
      searchTimeout = setTimeout(() => {
        refreshData();
      }, 300);
    } else {
      refreshData();
    }
  },
  { deep: true }
);

// Filtered Lists - simplified as server handles all filtering
const filteredList = computed(() => {
  return tasksStore.items;
});

// Filtered tree - simplified as server handles tree matching + parents recursively
const filteredTree = computed(() => {
  return tasksStore.itemsTree;
});

// Notes list
const filteredNotes = computed(() => {
  return tasksStore.items;
});

// Discussions list
const filteredDiscussions = computed(() => {
  return tasksStore.items;
});

// My Tasks list
const myTasksList = computed(() => {
  return tasksStore.items;
});

const getTicketIcon = (type: string) => {
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

const getTicketColor = (type: string) => {
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

const formatDateShort = (d: string) => new Date(d).toLocaleDateString();

const statusSummaryItems = computed(() => {
  const counts = tasksStore.statusCounts || {
    todo: 0,
    in_progress: 0,
    review: 0,
    done: 0,
    blocked: 0,
    archived: 0,
  };
  return [
    { key: 'todo', label: 'Todo', count: counts.todo, color: 'blue' },
    { key: 'in_progress', label: 'In Progress', count: counts.in_progress, color: 'amber-9' },
    { key: 'review', label: 'In Review', count: counts.review, color: 'purple' },
    { key: 'blocked', label: 'Blocked', count: counts.blocked, color: 'negative' },
    { key: 'done', label: 'Done', count: counts.done, color: 'positive' },
  ];
});

const toggleStatusFilter = (statusKey: string) => {
  if (filters.value.status === statusKey) {
    filters.value.status = null;
  } else {
    filters.value.status = statusKey;
  }
};

// Refetch metadata and list on tenant switch
watch(
  () => authStore.tenantId,
  async (newId) => {
    page.value = 1;
    await tasksStore.loadWorkspaceData(newId);
    refreshData();
  },
);

onMounted(async () => {
  await tasksStore.loadWorkspaceData(authStore.tenantId);
  refreshData();
});
</script>

<style scoped>
.tasks-dashboard-page {
  background: transparent;
}

.status-summary-card {
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(0, 0, 0, 0.08);
  transition: all 0.25s ease;
  overflow: hidden;
}

.status-summary-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.active-status-card {
  background: white;
  border-color: var(--q-primary) !important;
}

.status-indicator-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 3px;
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

.floating-surface {
  background: rgba(255, 255, 255, 0.88);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 12px;
  padding-right: 12px;
}

.kanban-board {
  gap: 1rem;
  padding-bottom: 24px;
  overflow-x: auto;
}

.kanban-column {
  min-width: 250px;
  max-width: 290px;
}

.kanban-header {
  background: #f1f5f9;
}

.kanban-list {
  min-height: 300px;
  background: rgba(0, 0, 0, 0.02);
  border-radius: 8px;
  padding: 8px;
}

.kanban-card {
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.kanban-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.08) !important;
}

.tree-project-box {
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.04);
}

.tree-module-box {
  background: #f8fafc;
  border: 1px solid rgba(0,0,0,0.03);
}

.tree-submodule-box {
  background: #ffffff;
  border: 1px solid rgba(0,0,0,0.02);
}

.ticket-row {
  background: #f8fafc;
  transition: background 0.15s ease;
}

.ticket-row:hover {
  background: #eff6ff;
}

.border-left {
  border-left: 2px solid rgba(0, 0, 0, 0.05);
}

.card-hover {
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.06) !important;
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

.scroll-x {
  overflow-x: auto;
  flex-wrap: nowrap !important;
}

.status-card-wrapper {
  min-width: 95px;
  flex: 1 0 auto;
}

.tree-indent-level {
  padding-left: 16px;
}

.tree-project-padding {
  padding: 16px;
}

@media (max-width: 600px) {
  .tree-indent-level {
    padding-left: 8px;
  }
  .tree-project-padding {
    padding: 10px;
  }
}
</style>

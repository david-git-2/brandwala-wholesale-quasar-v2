<template>
  <q-page class="design-system-page">
    <header class="ds-header">
      <div>
        <h1 class="ds-title">TradeFlow BD design tokens</h1>
        <p class="ds-subtitle">Live swatches from <code>app.scss</code> and <code>quasar.variables.scss</code></p>
      </div>
      <q-btn-toggle
        v-model="mode"
        toggle-color="primary"
        unelevated
        no-caps
        :options="[
          { label: 'Light', value: 'light' },
          { label: 'Dark', value: 'dark' },
        ]"
      />
    </header>

    <section class="ds-section">
      <h2 class="ds-section__title">Neutrals</h2>
      <div class="ds-swatch-grid">
        <Swatch
          v-for="item in neutralTokens"
          :key="item.token"
          :token="item.token"
          :label="item.label"
        />
      </div>
    </section>

    <section class="ds-section">
      <h2 class="ds-section__title">Semantic state</h2>
      <div class="ds-swatch-grid">
        <Swatch
          v-for="item in semanticTokens"
          :key="item.token"
          :token="item.token"
          :label="item.label"
        />
      </div>
    </section>

    <section class="ds-section">
      <h2 class="ds-section__title">Ops table column hues</h2>
      <div class="ds-swatch-grid">
        <Swatch
          v-for="item in opsHueTokens"
          :key="item.token"
          :token="item.token"
          :label="item.label"
        />
      </div>
    </section>

    <section class="ds-section">
      <h2 class="ds-section__title">Quasar Sass vs scoped primary</h2>
      <p class="ds-note">
        <code>$primary</code> in quasar.variables is terracotta. Each scope overrides
        <code>--q-primary</code> via <code>--bw-theme-primary</code>.
      </p>
      <div class="ds-swatch-grid">
        <div class="ds-swatch">
          <div class="ds-swatch__chip" style="background: #b85c38" />
          <div class="ds-swatch__meta">
            <span class="ds-swatch__label">quasar $primary</span>
            <code class="ds-swatch__token">#b85c38</code>
          </div>
        </div>
        <Swatch token="--q-primary" label="--q-primary (unscoped)" />
      </div>
    </section>

    <section class="ds-section">
      <h2 class="ds-section__title">Brand mark by scope</h2>
      <p class="ds-note">Tf mark tints to <code>--bw-theme-primary</code> for each place.</p>
      <div class="ds-logo-row">
        <div
          v-for="scope in scopes"
          :key="scope.id"
          class="ds-logo-card"
          :class="scope.className"
        >
          <AppLogoMark :scope="scope.id" class="ds-logo-mark" />
          <span class="ds-logo-card__label">{{ scope.label }}</span>
        </div>
      </div>
    </section>

    <section class="ds-section">
      <h2 class="ds-section__title">Scope themes</h2>
      <div class="ds-scope-grid">
        <ScopePanel
          v-for="scope in scopes"
          :key="scope.id"
          :scope="scope"
        />
      </div>
    </section>

    <section class="ds-section">
      <h2 class="ds-section__title">Typography</h2>
      <p class="ds-note">
        Ops scale: meta 11 / body 14 / title 22 / KPI 22 Plex. Shop extras: product 18, shop name 28–32.
        Caprasimo is removed.
      </p>
      <div class="ds-type-stack">
        <p class="bw-type-meta">meta — 11px / 600 — TABLE HEADER</p>
        <p class="bw-type-body">body — 14px / 400 — Tables, forms, lists</p>
        <p class="bw-type-title">title — 22px / 700 — Page title</p>
        <p class="bw-type-kpi">kpi — 22px / 600 — ৳ 12,450.00</p>
        <p class="bw-type-product">product — 18px / 600 — Shop product name</p>
        <p class="bw-type-shop-name">shop-name — 28–32px / 700</p>
        <p class="locale-bn">বাংলা পাঠ্য — Noto 400</p>
        <p class="locale-bn-label">বাংলা লেবেল — Noto 600</p>
      </div>
    </section>

    <section class="ds-section">
      <h2 class="ds-section__title">Border radius</h2>
      <p class="ds-note">Locked: <code>8px</code> controls, <code>12px</code> cards, <code>999px</code> pills only.</p>
      <div class="ds-radius-row">
        <div v-for="item in radiusSamples" :key="item.label" class="ds-radius-item">
          <div class="ds-radius-box" :style="{ borderRadius: item.value }" />
          <span>{{ item.label }}</span>
          <code>{{ item.value }}</code>
        </div>
      </div>
    </section>

    <section class="ds-section">
      <h2 class="ds-section__title">Surfaces</h2>
      <div class="ds-component-row">
        <q-card flat bordered class="ds-card-sample">
          <q-card-section>
            <div class="text-subtitle2">q-card flat bordered</div>
            <div class="bw-text-muted q-mt-xs">Default card surface</div>
          </q-card-section>
        </q-card>
        <div class="floating-surface ds-surface-sample">
          <span>.floating-surface</span>
        </div>
        <div class="hero-surface ds-surface-sample">
          <span>.hero-surface</span>
        </div>
      </div>
    </section>

    <div class="theme-app ds-kit">
      <p class="ds-note">
        Live controls below use the App (merchant desk) scope.
        One primary CTA per header. Radius 8px on controls, 12px on cards and dialogs.
      </p>

      <section class="ds-section">
        <h2 class="ds-section__title">Buttons</h2>
        <p class="ds-note">
          Primary <code>unelevated</code>. Secondary <code>flat</code> or <code>outline</code>.
          Danger <code>negative</code>. Icon-only needs <code>aria-label</code> + tooltip.
        </p>
        <div class="ds-block">
          <div class="ds-block__label">Actions</div>
          <div class="ds-component-row">
            <q-btn color="primary" unelevated no-caps label="Primary" />
            <q-btn outline no-caps label="Outline" />
            <q-btn flat no-caps label="Flat" />
            <q-btn color="negative" unelevated no-caps label="Danger" />
            <q-btn flat color="negative" no-caps label="Danger flat" />
            <q-btn color="primary" unelevated no-caps disable label="Disabled" />
            <q-btn color="primary" unelevated no-caps loading label="Saving" />
          </div>
        </div>
        <div class="ds-block">
          <div class="ds-block__label">Compact, pill, icon</div>
          <div class="ds-component-row">
            <q-btn color="primary" unelevated no-caps class="slim-btn" label="Slim" />
            <q-btn color="primary" unelevated no-caps class="pill-btn" label="Pill CTA" />
            <q-btn flat round icon="add" aria-label="Add">
              <q-tooltip>Add</q-tooltip>
            </q-btn>
            <q-btn flat round icon="more_vert" aria-label="More">
              <q-tooltip>More</q-tooltip>
            </q-btn>
            <q-chip dense color="positive" text-color="white" label="Posted" />
            <q-chip dense color="warning" text-color="white" label="Pending" />
            <q-chip dense color="negative" text-color="white" label="Voided" />
          </div>
        </div>
      </section>

      <section class="ds-section">
        <h2 class="ds-section__title">Inputs</h2>
        <p class="ds-note">
          Default <code>outlined dense</code>. Search is <code>outlined rounded dense</code>.
          Errors use field <code>error</code> + <code>error-message</code>.
        </p>
        <div class="ds-input-grid">
          <q-input
            v-model="sampleName"
            outlined
            dense
            label="Product name"
            hide-bottom-space
          />
          <q-input
            v-model="searchQuery"
            outlined
            dense
            rounded
            placeholder="Search…"
            debounce="300"
            hide-bottom-space
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
          </q-input>
          <q-select
            v-model="sampleStatus"
            outlined
            dense
            emit-value
            map-options
            :options="statusOptions"
            label="Status"
            hide-bottom-space
          />
          <q-input
            model-value=""
            outlined
            dense
            label="Required field"
            error
            error-message="This field is required"
          />
          <q-input
            v-model="sampleQty"
            outlined
            dense
            type="number"
            label="Qty"
            class="soft-input"
            hide-bottom-space
          />
          <q-input
            v-model="sampleNotes"
            outlined
            dense
            type="textarea"
            autogrow
            label="Notes"
            hide-bottom-space
          />
        </div>
        <div class="ds-component-row q-mt-md">
          <q-checkbox v-model="sampleChecked" dense label="In stock" />
          <q-toggle v-model="sampleChecked" dense label="Active" color="primary" />
        </div>
      </section>

      <section class="ds-section">
        <h2 class="ds-section__title">Tables</h2>
        <p class="ds-note">
          Dense ops tables copy <code>ShipmentLineItemsV2Page</code>: locked page height, sticky
          toolbar, <code>q-markup-table</code>, borderless Excel cells, section rows, Excel tab bar.
          Columns menu and <code>FilterSidebar</code> on lists. Gear opens the extended panel.
        </p>

        <div class="ds-ops-sheet">
          <div class="ds-ops-sheet__toolbar">
            <div class="text-weight-bolder ellipsis" style="font-size: 15px">
              Sample shipment
            </div>
            <div class="row items-center q-gutter-x-sm no-wrap">
              <q-btn
                color="primary"
                unelevated
                dense
                no-caps
                size="sm"
                icon="ph ph-pencil-simple"
                label="Edit"
                class="q-px-sm text-weight-bold"
                style="border-radius: 8px"
              />
              <q-btn
                outline
                dense
                no-caps
                color="primary"
                size="sm"
                icon="ph ph-plus"
                label="Add Items"
                class="q-px-sm text-weight-bold"
                style="border-radius: 8px"
              />
              <q-btn
                flat
                dense
                no-caps
                color="grey-8"
                size="sm"
                icon="ph ph-sliders-horizontal"
                label="Columns"
                class="q-px-sm text-weight-bold ds-ops-sheet__ghost"
              >
                <q-menu class="theme-app">
                  <q-list style="min-width: 220px" class="q-py-xs">
                    <q-item>
                      <q-item-section>
                        <div class="text-subtitle2 text-weight-bold text-primary">Table Columns</div>
                      </q-item-section>
                    </q-item>
                    <q-item clickable @click="toggleOpsColumns">
                      <q-item-section>
                        <q-checkbox :model-value="opsAllColumnsVisible" label="Select / Deselect All" />
                      </q-item-section>
                    </q-item>
                    <q-separator class="q-my-xs" />
                    <q-item
                      v-for="col in opsColumnDefs"
                      :key="col.name"
                      clickable
                      @click="opsVisible[col.name] = !opsVisible[col.name]"
                    >
                      <q-item-section>
                        <q-checkbox :model-value="opsVisible[col.name]" :label="col.label" />
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
              <q-btn
                flat
                round
                dense
                color="grey-8"
                icon="ph ph-gear"
                size="sm"
                @click="extendedDialogOpen = true"
              >
                <q-tooltip>Settings</q-tooltip>
              </q-btn>
            </div>
          </div>

          <div class="ds-ops-sheet__scroll hide-native-scrollbar">
            <q-markup-table flat class="ds-ops-table" style="min-width: 1080px; width: 100%">
              <thead>
                <tr>
                  <th class="text-center q-pa-none" style="width: 18px; min-width: 18px">
                    <q-checkbox v-model="opsAllSelected" dense size="xs" />
                  </th>
                  <th class="text-center q-pa-none" style="width: 36px">SL</th>
                  <th v-if="opsVisible.image" class="text-left" style="width: 82px">Image</th>
                  <th v-if="opsVisible.name" class="text-left" style="width: 120px; max-width: 120px">Name</th>
                  <th v-if="opsVisible.codes" class="text-left" style="width: 115px">Codes</th>
                  <th v-if="opsVisible.price" class="text-center bw-ops-col-tint--price" style="width: 56px">Price</th>
                  <th v-if="opsVisible.cost" class="text-center bw-ops-col-tint--cost" style="width: 56px">Cost</th>
                  <th v-if="opsVisible.qty" class="text-center bw-ops-col-tint--qty" style="width: 56px">Qty</th>
                  <th v-if="opsVisible.weight" class="text-center" style="width: 56px">Wt</th>
                  <th v-if="opsVisible.pkg" class="text-center bw-ops-col-tint--weight" style="width: 56px">Pkg</th>
                </tr>
              </thead>
              <tbody>
                <tr class="section-break-row">
                  <td :colspan="opsColSpan" class="q-py-xs q-px-md text-weight-bold">
                    <div class="row items-center q-gutter-x-sm">
                      <span class="text-subtitle2 text-weight-bolder">Invoice A</span>
                      <span class="text-caption text-grey-6 font-mono">• Dhaka Vendor</span>
                      <q-badge color="grey-3" text-color="grey-8" class="text-weight-bold">2</q-badge>
                    </div>
                  </td>
                </tr>
                <tr
                  v-for="item in opsRows"
                  :key="item.id"
                  class="cursor-pointer"
                  :class="{ 'row-selected': item.selected }"
                  @click="item.selected = !item.selected"
                >
                  <td class="text-center q-pa-none" @click.stop>
                    <q-checkbox v-model="item.selected" dense size="xs" />
                  </td>
                  <td class="text-center q-pa-none">
                    <q-input
                      v-model.number="item.sl"
                      type="number"
                      dense
                      outlined
                      hide-bottom-space
                      class="inline-edit-input excel-cell-input"
                      style="max-width: 32px"
                      input-class="text-center text-weight-bold font-mono"
                    />
                  </td>
                  <td v-if="opsVisible.image">
                    <q-avatar square size="82px" class="avatar-soft-sq bg-grey-2 ds-ops-sheet__ghost overflow-hidden">
                      <q-icon name="ph ph-image" size="28px" color="grey-5" />
                    </q-avatar>
                  </td>
                  <td v-if="opsVisible.name" style="max-width: 120px; white-space: normal; word-break: break-word">
                    <div class="text-weight-bold" style="font-size: 13px; line-height: 1.35">
                      {{ item.name }}
                    </div>
                  </td>
                  <td v-if="opsVisible.codes" class="font-mono text-caption">
                    <div class="ellipsis">
                      <span class="text-grey-6" style="font-size: 8px">C: </span>
                      <b style="font-size: 10px">{{ item.code }}</b>
                    </div>
                    <div class="ellipsis">
                      <span class="text-grey-6" style="font-size: 8px">B: </span>
                      <span style="font-size: 10px">{{ item.barcode }}</span>
                    </div>
                  </td>
                  <td v-if="opsVisible.price" class="text-center bw-ops-col-tint--price">
                    <q-input
                      v-model.number="item.price"
                      type="number"
                      dense
                      outlined
                      hide-bottom-space
                      class="inline-edit-input excel-cell-input"
                      style="max-width: 50px"
                      input-class="text-center text-weight-bold"
                    />
                    <div class="text-caption text-grey-7" style="font-size: 10px">
                      {{ (item.price * item.qty).toLocaleString() }}
                    </div>
                  </td>
                  <td v-if="opsVisible.cost" class="text-center bw-ops-col-tint--cost font-mono text-weight-bold text-primary" style="font-size: 12px">
                    {{ item.cost }}
                    <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px">
                      {{ (item.cost * item.qty).toLocaleString() }}
                    </div>
                  </td>
                  <td v-if="opsVisible.qty" class="text-center bw-ops-col-tint--qty">
                    <q-input
                      v-model.number="item.qty"
                      type="number"
                      dense
                      outlined
                      hide-bottom-space
                      class="inline-edit-input excel-cell-input"
                      style="max-width: 50px"
                      input-class="text-center text-weight-bold"
                    />
                  </td>
                  <td v-if="opsVisible.weight" class="text-center font-mono text-grey-8" style="font-size: 12px">
                    {{ item.productWeight.toFixed(3) }}
                  </td>
                  <td v-if="opsVisible.pkg" class="text-center bw-ops-col-tint--weight font-mono" style="font-size: 12px">
                    {{ item.packageWeight.toFixed(3) }}
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </div>

          <ShipmentExcelBottomBar
            :sheets="opsSheets"
            :active-sheet-id="opsSheetId"
            :scroll-thumb-width="42"
            :scroll-thumb-left="8"
            @update:active-sheet-id="opsSheetId = $event"
          />
        </div>

        <p class="ds-note q-mt-lg">
          Directory lists copy <code>CustomerHubPage</code>: search + create toolbar, two-line
          cells, initials avatar, status pill, overflow menu. Add Columns and the funnel
          filter panel on every list. Gear on ops tables opens the extended panel.
        </p>
        <div class="ds-hub-list">
          <div class="row items-center no-wrap q-gutter-sm q-mb-md">
            <q-input
              v-model="hubSearch"
              outlined
              dense
              placeholder="Search by name, email, or phone — press Enter"
              class="ds-hub-search col"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-5" />
              </template>
              <template v-if="hubSearch" #append>
                <q-icon
                  name="ph ph-x"
                  size="16px"
                  class="cursor-pointer text-grey-5"
                  @click="hubSearch = ''"
                />
              </template>
            </q-input>
            <q-btn flat round dense icon="ph ph-arrow-clockwise" color="grey-7">
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>
            <q-btn
              flat
              dense
              no-caps
              color="grey-8"
              icon="ph ph-sliders-horizontal"
              label="Columns"
              class="ds-hub-action text-weight-medium col-auto"
            >
              <q-menu class="theme-app">
                <q-list style="min-width: 220px" class="q-py-xs">
                  <q-item>
                    <q-item-section>
                      <div class="text-subtitle2 text-weight-bold text-primary">Table Columns</div>
                    </q-item-section>
                  </q-item>
                  <q-item clickable @click="toggleHubColumns">
                    <q-item-section>
                      <q-checkbox :model-value="hubAllColumnsVisible" label="Select / Deselect All" />
                    </q-item-section>
                  </q-item>
                  <q-separator class="q-my-xs" />
                  <q-item
                    v-for="col in hubToggleColumns"
                    :key="col.name"
                    clickable
                    @click="hubVisible[col.name] = !hubVisible[col.name]"
                  >
                    <q-item-section>
                      <q-checkbox :model-value="hubVisible[col.name]" :label="col.label" />
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
            <q-btn flat round dense icon="ph ph-funnel" color="grey-7" @click="filterPanelOpen = true">
              <q-tooltip>Filters</q-tooltip>
            </q-btn>
            <q-btn
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Create Customer"
              no-caps
              class="ds-hub-action text-weight-medium col-auto"
            />
          </div>
          <q-table
            flat
            :rows="hubRows"
            :columns="displayedHubColumns"
            row-key="id"
            class="ds-hub-table cursor-pointer"
            :pagination="{ rowsPerPage: 10 }"
            :rows-per-page-options="[10, 20, 50]"
            hide-pagination
          >
            <template #body-cell-customer="props">
              <q-td :props="props">
                <div class="row items-center no-wrap">
                  <q-avatar size="32px" class="q-mr-sm ds-hub-avatar flex-shrink-0">
                    {{ initials(props.row.group_name) }}
                  </q-avatar>
                  <div class="ds-hub-two-line ellipsis">
                    <div class="text-weight-medium ellipsis">{{ props.row.group_name }}</div>
                    <div class="ds-hub-muted ellipsis">{{ props.row.admin_name || '—' }}</div>
                  </div>
                </div>
              </q-td>
            </template>
            <template #body-cell-contact="props">
              <q-td :props="props">
                <div class="ds-hub-two-line">
                  <div class="ellipsis">{{ props.row.email || '—' }}</div>
                  <div class="ds-hub-muted ellipsis">{{ props.row.phone || '—' }}</div>
                </div>
              </q-td>
            </template>
            <template #body-cell-address="props">
              <q-td :props="props">
                <div class="ds-hub-two-line">
                  <div class="ellipsis text-grey-8">{{ props.row.address || '—' }}</div>
                  <div class="ds-hub-muted">&nbsp;</div>
                </div>
              </q-td>
            </template>
            <template #body-cell-members="props">
              <q-td :props="props" class="text-right">
                <span class="ds-hub-numeric">{{ props.row.member_count }}</span>
              </q-td>
            </template>
            <template #body-cell-wallet="props">
              <q-td :props="props" class="text-right">
                <span
                  class="ds-hub-numeric"
                  :class="props.row.wallet >= 0 ? 'text-grey-8' : 'text-negative'"
                >
                  {{ formatBdt(props.row.wallet) }}
                </span>
              </q-td>
            </template>
            <template #body-cell-status="props">
              <q-td :props="props">
                <span
                  class="ds-hub-status"
                  :class="props.row.active ? 'ds-hub-status--active' : 'ds-hub-status--inactive'"
                >
                  {{ props.row.active ? 'Active' : 'Inactive' }}
                </span>
              </q-td>
            </template>
            <template #body-cell-actions="props">
              <q-td :props="props" class="text-right" @click.stop>
                <q-btn
                  flat
                  round
                  dense
                  color="grey-7"
                  icon="ph ph-dots-three"
                  aria-label="Row actions"
                >
                  <q-menu anchor="bottom right" self="top right">
                    <q-list dense style="min-width: 148px">
                      <q-item v-close-popup clickable>
                        <q-item-section>View</q-item-section>
                      </q-item>
                      <q-item v-close-popup clickable class="text-negative">
                        <q-item-section>Delete</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </q-td>
            </template>
          </q-table>
        </div>
      </section>

      <section class="ds-section">
        <h2 class="ds-section__title">Row list</h2>
        <p class="ds-note">
          Browse pages that are not ops spreadsheets use stacked rows, not
          <code>q-table</code>. One card per record. Avatar, two-line identity, status pill,
          tabular money, overflow. Radius 12px. Hover lifts. Selected uses primary-soft.
        </p>
        <div class="ds-entity-list">
          <div class="ds-entity-list__toolbar">
            <q-input
              v-model="listSearch"
              outlined
              dense
              placeholder="Search customers"
              class="ds-hub-search col"
              debounce="300"
              data-test="entity-list-search"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" class="bw-text-muted" />
              </template>
            </q-input>
            <q-btn
              unelevated
              color="primary"
              icon="ph ph-plus"
              label="Create"
              no-caps
              class="ds-hub-action text-weight-medium col-auto"
              data-test="entity-list-create"
            />
          </div>
          <ul class="ds-entity-list__stack" role="list">
            <li v-for="row in listRows" :key="row.id">
              <div
                class="ds-entity-row"
                :class="{ 'ds-entity-row--active': listSelectedId === row.id }"
                role="button"
                tabindex="0"
                :data-test="`entity-row-${row.id}`"
                @click="listSelectedId = row.id"
                @keydown.enter="listSelectedId = row.id"
              >
                <span class="ds-entity-row__avatar" aria-hidden="true">{{ initials(row.group_name) }}</span>
                <span class="ds-entity-row__body">
                  <span class="ds-entity-row__name">{{ row.group_name }}</span>
                  <span class="ds-entity-row__meta">
                    {{
                      [row.admin_name, row.address, `${row.member_count} members`]
                        .filter(Boolean)
                        .join(' · ')
                    }}
                  </span>
                </span>
                <span class="ds-entity-row__side">
                  <span
                    class="ds-entity-row__money bw-tabular"
                    :class="{ 'ds-entity-row__money--neg': row.wallet < 0 }"
                  >
                    {{ formatBdt(row.wallet) }}
                  </span>
                  <span
                    class="ds-hub-status"
                    :class="row.active ? 'ds-hub-status--active' : 'ds-hub-status--inactive'"
                  >
                    {{ row.active ? 'Active' : 'Inactive' }}
                  </span>
                </span>
                <q-btn
                  flat
                  round
                  dense
                  icon="ph ph-dots-three"
                  class="bw-text-muted"
                  aria-label="Row actions"
                  data-test="entity-row-actions"
                  @click.stop
                >
                  <q-menu anchor="bottom right" self="top right">
                    <q-list dense style="min-width: 148px">
                      <q-item v-close-popup clickable>
                        <q-item-section>View</q-item-section>
                      </q-item>
                      <q-item v-close-popup clickable class="text-negative">
                        <q-item-section>Delete</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </div>
            </li>
          </ul>
        </div>
      </section>

      <section class="ds-section">
        <h2 class="ds-section__title">Charts</h2>
        <p class="ds-note">
          Chart.js via <code>vue-chartjs</code>. Register with
          <code>ensureDashboardChartsRegistered</code>. No legend. Doughnut cutout
          <code>72%</code>. Bars radius <code>4–6</code>. Colors from theme primary plus
          semantic hues. Source: dashboard glance, after-sales hub, procurement, shop hourly flow.
        </p>
        <div class="ds-chart-grid">
          <q-card flat bordered class="ds-chart-card">
            <div class="ds-chart-card__head">
              <div>
                <div class="ds-chart-card__title">Doughnut glance</div>
                <div class="ds-chart-card__sub">Center label. Cutout 72%.</div>
              </div>
              <div class="ds-chart-card__kpi">
                <span class="ds-chart-card__kpi-value">74%</span>
                <span class="ds-chart-card__kpi-label">in stock</span>
              </div>
            </div>
            <div class="ds-chart-card__body ds-chart-card__body--split">
              <div class="ds-donut">
                <Doughnut :data="donutChartData" :options="donutChartOptions" />
                <div class="ds-donut__center">
                  <span class="ds-donut__pct">74%</span>
                  <span class="ds-donut__caption">in stock</span>
                </div>
              </div>
              <div class="ds-donut-legend">
                <div class="ds-donut-legend__row">
                  <span class="ds-donut-legend__dot" :style="{ background: donutPrimary }" />
                  <span>Available</span>
                  <b>128</b>
                </div>
                <div class="ds-donut-legend__row">
                  <span class="ds-donut-legend__dot ds-donut-legend__dot--muted" />
                  <span>Sold</span>
                  <b>44</b>
                </div>
              </div>
            </div>
          </q-card>

          <q-card flat bordered class="ds-chart-card">
            <div class="ds-chart-card__head">
              <div>
                <div class="ds-chart-card__title">Horizontal bars</div>
                <div class="ds-chart-card__sub">Queue counts. One hue per bar.</div>
              </div>
              <div class="ds-chart-card__kpi">
                <span class="ds-chart-card__kpi-value">41</span>
                <span class="ds-chart-card__kpi-label">open</span>
              </div>
            </div>
            <div class="ds-chart-card__canvas">
              <Bar :data="hBarChartData" :options="hBarChartOptions" />
            </div>
          </q-card>

          <q-card flat bordered class="ds-chart-card">
            <div class="ds-chart-card__head">
              <div>
                <div class="ds-chart-card__title">Vertical bars</div>
                <div class="ds-chart-card__sub">Grade / category mix.</div>
              </div>
            </div>
            <div class="ds-chart-card__canvas">
              <Bar :data="vBarChartData" :options="vBarChartOptions" />
            </div>
          </q-card>

          <q-card flat bordered class="ds-chart-card theme-shop">
            <div class="ds-chart-card__head">
              <div>
                <div class="ds-chart-card__title">Area line</div>
                <div class="ds-chart-card__sub">Hourly flow. Tension 0.4, filled. Shop primary.</div>
              </div>
            </div>
            <div class="ds-chart-card__canvas">
              <Line :data="lineChartData" :options="lineChartOptions" />
            </div>
          </q-card>
        </div>

        <q-card flat bordered class="ds-chart-card q-mt-md theme-shop">
          <div class="ds-chart-card__head">
            <div>
              <div class="ds-chart-card__title">Stacked meter</div>
              <div class="ds-chart-card__sub">Share split without Chart.js. Shop settlement pattern.</div>
            </div>
          </div>
          <div class="ds-meter">
            <div class="ds-meter__seg" style="width: 58%; background: var(--bw-theme-primary)" title="COD" />
            <div class="ds-meter__seg" style="width: 28%; background: var(--bw-success)" title="Digital" />
            <div class="ds-meter__seg" style="width: 14%; background: var(--bw-warning)" title="Cash" />
          </div>
          <div class="ds-meter-legend">
            <span><i class="ds-meter-legend__swatch ds-meter-legend__swatch--shop" /> COD 58%</span>
            <span><i class="ds-meter-legend__swatch ds-meter-legend__swatch--success" /> Digital 28%</span>
            <span><i class="ds-meter-legend__swatch ds-meter-legend__swatch--warning" /> Cash 14%</span>
          </div>
        </q-card>
      </section>

      <section class="ds-section">
        <h2 class="ds-section__title">Filter panel</h2>
        <p class="ds-note">
          List filters use <code>FilterSidebar</code> — a narrow right sheet (~320px), not a
          centered modal. Funnel icon on the list toolbar. Reset is flat. Apply is primary.
        </p>
        <div class="ds-component-row">
          <q-btn
            outline
            no-caps
            icon="ph ph-funnel"
            label="Open filter panel"
            @click="filterPanelOpen = true"
          />
        </div>
      </section>

      <section class="ds-section">
        <h2 class="ds-section__title">Extended panel</h2>
        <p class="ds-note">
          Settings and record detail use a wide right <code>q-dialog</code> (~520px, full height,
          12px radius). Tabs on top. Save stays in the footer. Gear on ops tables opens this.
        </p>
        <div class="ds-component-row">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-gear"
            label="Open extended panel"
            @click="extendedDialogOpen = true"
          />
        </div>
      </section>

      <section class="ds-section">
        <h2 class="ds-section__title">Add products</h2>
        <p class="ds-note">
          Catalog picker is <code>AddCostingItemsDrawer</code>. Right sheet ~640px, primary
          header, search + bulk codes + funnel, catalog rows with Add, create-new when the name
          is missing. Done sits in the footer. Same pattern on costing files.
        </p>
        <div class="ds-component-row">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Open add products"
            @click="addProductsOpen = true"
          />
        </div>
      </section>

      <section class="ds-section">
        <h2 class="ds-section__title">Modal dialogs</h2>
        <p class="ds-note">
          Small centered cards only. Card radius 12px. Cancel is flat. Confirm is primary.
          Delete is negative. Use <code>requestConfirmation</code> in real pages.
        </p>
        <div class="ds-component-row">
          <q-btn color="primary" unelevated no-caps label="Open form dialog" @click="formDialogOpen = true" />
          <q-btn outline no-caps color="negative" label="Open confirm dialog" @click="confirmDialogOpen = true" />
        </div>
      </section>
    </div>

    <div class="theme-app">
    <FilterSidebar
      v-model="filterPanelOpen"
      title="Filters"
      :top-offset="12"
      :bottom-offset="12"
    >
      <q-select
        v-model="sidePanelStatus"
        outlined
        dense
        emit-value
        map-options
        :options="statusOptions"
        label="Status"
        class="soft-input q-mb-md"
      />
      <q-checkbox v-model="sidePanelActive" dense label="Active only" class="q-mb-md" />
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="resetSidePanel" />
        <q-btn unelevated no-caps color="primary" label="Apply" @click="filterPanelOpen = false" />
      </div>
    </FilterSidebar>
    </div>

    <q-dialog
      v-model="extendedDialogOpen"
      class="theme-app"
      position="right"
      transition-show="jump-left"
      transition-hide="jump-right"
    >
      <q-card class="ds-extended-card column no-wrap">
        <div class="bg-grey-1 border-bottom q-px-sm">
          <q-tabs
            v-model="extendedTab"
            dense
            no-caps
            active-color="primary"
            indicator-color="primary"
            align="left"
            class="text-grey-7 text-weight-medium"
          >
            <q-tab name="details" label="Details" icon="ph ph-identification-badge" />
            <q-tab name="summary" label="Summary" icon="ph ph-chart-pie-slice" />
          </q-tabs>
        </div>
        <q-tab-panels v-model="extendedTab" animated class="col overflow-auto">
          <q-tab-panel name="details" class="q-pa-md q-gutter-y-md">
            <div class="text-subtitle2 text-weight-bold">General</div>
            <q-input v-model="sampleName" outlined dense label="Name" hide-bottom-space />
            <q-input v-model="sampleQty" outlined dense type="number" label="Qty" hide-bottom-space />
            <q-select
              v-model="sampleStatus"
              outlined
              dense
              emit-value
              map-options
              :options="statusOptions"
              label="Status"
              hide-bottom-space
            />
          </q-tab-panel>
          <q-tab-panel name="summary" class="q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Totals</div>
            <div class="bw-text-muted">Qty {{ sampleQty }} · {{ sampleStatus }}</div>
            <div class="bw-type-kpi q-mt-sm">৳ 12,450.00</div>
          </q-tab-panel>
        </q-tab-panels>
        <q-card-actions align="right" class="q-pa-md border-top">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" unelevated no-caps label="Save" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog
      v-model="addProductsOpen"
      class="theme-app"
      position="right"
      full-height
      persistent
    >
      <q-card class="ds-add-products-card column no-wrap">
        <q-card-section class="row items-center q-py-sm q-px-md ds-add-products-header text-white">
          <div class="col">
            <div class="text-subtitle1 text-weight-bold">Add products</div>
            <div class="text-caption" style="opacity: 0.85">Spring quote 2026</div>
          </div>
          <q-btn icon="ph ph-x" flat round dense color="white" aria-label="Close" v-close-popup />
        </q-card-section>

        <div class="col column no-wrap">
          <div class="q-pa-md ds-add-products-toolbar column q-gutter-y-sm">
            <div class="row items-center q-col-gutter-sm">
              <div class="col">
                <q-input
                  v-model="addProductsQuery"
                  placeholder="Search name, barcode, or code"
                  outlined
                  dense
                  clearable
                  clear-value=""
                  class="full-width"
                >
                  <template #prepend>
                    <q-icon name="ph ph-magnifying-glass" />
                  </template>
                </q-input>
              </div>
              <div class="col-auto">
                <q-btn
                  flat
                  dense
                  no-caps
                  icon="ph ph-list-plus"
                  label="Bulk codes"
                  class="bw-text-muted"
                  @click="addProductsBulkOpen = !addProductsBulkOpen"
                />
                <q-btn
                  flat
                  round
                  dense
                  icon="ph ph-funnel"
                  class="bw-text-muted"
                  aria-label="Filters"
                  @click="addProductsFilterOpen = true"
                >
                  <q-badge v-if="addProductsFilterCount" color="primary" rounded floating>
                    {{ addProductsFilterCount }}
                  </q-badge>
                </q-btn>
              </div>
            </div>
            <div
              v-if="addProductsBulkOpen"
              class="column q-gutter-y-sm ds-add-products-bulk q-pa-sm rounded-borders"
            >
              <span class="text-caption text-weight-medium bw-text-muted">Bulk paste mode: Auto</span>
              <q-input
                v-model="addProductsBulkText"
                type="textarea"
                outlined
                dense
                placeholder="Paste codes, one per line"
                :input-style="{ height: '80px', maxHeight: '80px', overflowY: 'auto', resize: 'none' }"
              />
              <div class="row items-center q-col-gutter-sm">
                <div class="col-auto">
                  <q-input
                    v-model.number="addProductsBulkQty"
                    type="number"
                    outlined
                    dense
                    label="Qty"
                    style="width: 90px"
                    min="1"
                    hide-bottom-space
                  />
                </div>
                <div class="col">
                  <q-btn
                    unelevated
                    no-caps
                    color="primary"
                    icon="ph ph-plus"
                    label="Add to file"
                    class="full-width"
                    :disable="!addProductsBulkText.trim()"
                  />
                </div>
              </div>
            </div>
          </div>

          <div class="col column q-px-md q-pb-sm ds-add-products-body">
            <div class="text-subtitle2 text-weight-bold q-mb-xs">Catalog</div>
            <div class="col ds-add-products-scroll">
              <q-list
                v-if="addProductHits.length"
                dense
                bordered
                separator
                class="rounded-borders ds-add-products-list"
              >
                <q-item v-for="row in addProductHits" :key="row.id">
                  <q-item-section avatar>
                    <q-avatar square size="48px" class="ds-add-products-thumb">
                      <q-icon name="ph ph-package" size="22px" />
                    </q-avatar>
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-medium">{{ row.name }}</q-item-label>
                    <q-item-label caption>{{ row.code }} · {{ row.barcode }}</q-item-label>
                    <q-item-label caption class="text-secondary">£{{ row.price }}</q-item-label>
                    <q-item-label v-if="row.onFile" caption class="text-negative">
                      Already on file
                    </q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-btn
                      unelevated
                      dense
                      no-caps
                      color="primary"
                      icon="ph ph-plus"
                      label="Add"
                      :disable="row.onFile"
                      @click="markProductOnFile(row.id)"
                    />
                  </q-item-section>
                </q-item>
              </q-list>
              <q-list
                v-if="addProductsQuery.trim()"
                dense
                bordered
                class="rounded-borders ds-add-products-list q-mt-sm"
              >
                <q-item>
                  <q-item-section avatar>
                    <q-avatar square color="primary" text-color="white" icon="ph ph-plus" size="48px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-medium">
                      Create "{{ addProductsQuery.trim() }}" as a new product
                    </q-item-label>
                    <q-item-label caption>Can't find it? Create it as a new product.</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-btn unelevated dense no-caps color="primary" icon="ph ph-plus" label="Create" />
                  </q-item-section>
                </q-item>
              </q-list>
            </div>
          </div>

          <div class="q-pa-md ds-add-products-footer">
            <q-btn unelevated no-caps color="primary" label="Done" class="full-width" v-close-popup />
          </div>
        </div>

        <FilterSidebar
          v-model="addProductsFilterOpen"
          title="Filters"
          :z-index="7000"
          :top-offset="12"
          :bottom-offset="12"
        >
          <q-select
            v-model="addProductsVendor"
            outlined
            dense
            emit-value
            map-options
            clearable
            :options="addProductsVendorOptions"
            label="Vendor"
            class="soft-input q-mb-md"
          />
          <q-select
            v-model="addProductsBrand"
            outlined
            dense
            emit-value
            map-options
            clearable
            :options="addProductsBrandOptions"
            label="Brand"
            class="soft-input q-mb-md"
          />
          <div class="row q-gutter-sm justify-end">
            <q-btn
              flat
              no-caps
              label="Reset"
              @click="addProductsVendor = null; addProductsBrand = null"
            />
            <q-btn unelevated no-caps color="primary" label="Apply" @click="addProductsFilterOpen = false" />
          </div>
        </FilterSidebar>
      </q-card>
    </q-dialog>

    <q-dialog v-model="formDialogOpen" class="theme-app">
      <q-card class="ds-dialog-card">
        <q-card-section>
          <div class="text-subtitle1 text-weight-bold">Edit listing</div>
          <div class="bw-text-muted">Form dialog sample</div>
        </q-card-section>
        <q-card-section class="q-gutter-md q-pt-none">
          <q-input v-model="sampleName" outlined dense label="Name" hide-bottom-space />
          <q-input v-model="sampleQty" outlined dense type="number" label="Qty" hide-bottom-space />
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" unelevated no-caps label="Save" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="confirmDialogOpen" class="theme-app">
      <q-card class="ds-dialog-card">
        <q-card-section class="row items-center">
          <q-icon name="warning" color="warning" size="28px" />
          <span class="q-ml-sm text-subtitle1 text-weight-bold">Delete item?</span>
        </q-card-section>
        <q-card-section class="q-pt-none">
          This cannot be undone. Confirm dialogs keep Cancel flat and Delete negative.
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="negative" unelevated no-caps label="Delete" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, defineComponent, h, onMounted, ref, watch, type PropType } from 'vue';
import { Bar, Doughnut, Line } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import { applyDarkMode } from 'src/composables/useAppearance';
import AppLogoMark from 'src/components/brand/AppLogoMark.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import ShipmentExcelBottomBar from 'src/modules/procurement_stock/components/ShipmentExcelBottomBar.vue';
import {
  ensureDashboardChartsRegistered,
  readThemeRgb,
  rgba,
} from 'src/modules/dashboard/utils/dashboardChartSetup';

ensureDashboardChartsRegistered();

const mode = ref<'light' | 'dark'>('light');
const formDialogOpen = ref(false);
const confirmDialogOpen = ref(false);
const sampleName = ref('Cotton tee');
const sampleQty = ref(24);
const sampleNotes = ref('');
const searchQuery = ref('');
const sampleStatus = ref('posted');
const sampleChecked = ref(true);

const statusOptions = [
  { label: 'Posted', value: 'posted' },
  { label: 'Pending', value: 'pending' },
  { label: 'Voided', value: 'voided' },
];

const hubSearch = ref('');
const listSearch = ref('');
const listSelectedId = ref(1);
const filterPanelOpen = ref(false);
const extendedDialogOpen = ref(false);
const addProductsOpen = ref(false);
const addProductsQuery = ref('');
const addProductsBulkOpen = ref(false);
const addProductsBulkText = ref('');
const addProductsBulkQty = ref(1);
const addProductsFilterOpen = ref(false);
const addProductsVendor = ref<string | null>(null);
const addProductsBrand = ref<string | null>(null);
const extendedTab = ref('details');
const sidePanelStatus = ref('posted');
const sidePanelActive = ref(true);

const hubColumns = [
  { name: 'customer', label: 'Customer', field: 'group_name', align: 'left' as const },
  { name: 'contact', label: 'Contact', field: 'email', align: 'left' as const },
  { name: 'address', label: 'Address', field: 'address', align: 'left' as const },
  { name: 'members', label: 'Members', field: 'member_count', align: 'right' as const },
  { name: 'wallet', label: 'Wallet Balance', field: 'wallet', align: 'right' as const },
  { name: 'status', label: 'Status', field: 'active', align: 'left' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
];

const hubToggleColumns = [
  { name: 'contact', label: 'Contact' },
  { name: 'address', label: 'Address' },
  { name: 'members', label: 'Members' },
  { name: 'wallet', label: 'Wallet Balance' },
  { name: 'status', label: 'Status' },
];

const hubVisible = ref<Record<string, boolean>>({
  contact: true,
  address: true,
  members: true,
  wallet: true,
  status: true,
});

const hubAllColumnsVisible = computed(() =>
  hubToggleColumns.every((col) => hubVisible.value[col.name]),
);

const displayedHubColumns = computed(() =>
  hubColumns.filter((col) => col.name === 'customer' || col.name === 'actions' || hubVisible.value[col.name]),
);

function toggleHubColumns() {
  const next = !hubAllColumnsVisible.value;
  hubToggleColumns.forEach((col) => {
    hubVisible.value[col.name] = next;
  });
}

function resetSidePanel() {
  sidePanelStatus.value = 'posted';
  sidePanelActive.value = true;
}

const addProductsVendorOptions = [
  { label: 'Dhaka Knit', value: 'dhaka' },
  { label: 'Chittagong Mills', value: 'ctg' },
];

const addProductsBrandOptions = [
  { label: 'Apex', value: 'apex' },
  { label: 'Bata', value: 'bata' },
];

const addProductsFilterCount = computed(
  () => Number(Boolean(addProductsVendor.value)) + Number(Boolean(addProductsBrand.value)),
);

const addProductRows = ref([
  {
    id: 1,
    name: 'Cotton tee',
    code: 'CT-101',
    barcode: '890123456001',
    price: '4.20',
    onFile: true,
    vendor: 'dhaka',
    brand: 'apex',
  },
  {
    id: 2,
    name: 'Denim jacket',
    code: 'DJ-204',
    barcode: '890123456204',
    price: '18.50',
    onFile: false,
    vendor: 'ctg',
    brand: 'apex',
  },
  {
    id: 3,
    name: 'Canvas tote',
    code: 'TO-088',
    barcode: '890123456088',
    price: '6.00',
    onFile: false,
    vendor: 'dhaka',
    brand: 'bata',
  },
]);

const addProductHits = computed(() => {
  const q = addProductsQuery.value.trim().toLowerCase();
  return addProductRows.value.filter((row) => {
    if (addProductsVendor.value && row.vendor !== addProductsVendor.value) return false;
    if (addProductsBrand.value && row.brand !== addProductsBrand.value) return false;
    if (!q) return true;
    return (
      row.name.toLowerCase().includes(q) ||
      row.code.toLowerCase().includes(q) ||
      row.barcode.includes(q)
    );
  });
});

function markProductOnFile(id: number) {
  const row = addProductRows.value.find((item) => item.id === id);
  if (row) row.onFile = true;
}

const hubRows = [
  {
    id: 1,
    group_name: 'Dhaka Wholesale',
    admin_name: 'Rina Akter',
    email: 'rina@example.com',
    phone: '01711-000111',
    address: 'Motijheel, Dhaka',
    member_count: 4,
    wallet: 12450,
    active: true,
  },
  {
    id: 2,
    group_name: 'Chittagong Traders',
    admin_name: 'Karim Uddin',
    email: 'karim@example.com',
    phone: '01812-000222',
    address: 'Agrabad',
    member_count: 2,
    wallet: -320.5,
    active: true,
  },
  {
    id: 3,
    group_name: 'Sylhet Mart',
    admin_name: '',
    email: '',
    phone: '01913-000333',
    address: '',
    member_count: 1,
    wallet: 0,
    active: false,
  },
];

function initials(name?: string) {
  if (!name) return 'C';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'C';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'C';
}

function formatBdt(val: number) {
  return `${val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} BDT`;
}

const listRows = computed(() => {
  const q = listSearch.value.trim().toLowerCase();
  if (!q) return hubRows;
  return hubRows.filter((row) =>
    [row.group_name, row.admin_name, row.email, row.phone, row.address]
      .join(' ')
      .toLowerCase()
      .includes(q),
  );
});

const opsSheetId = ref('all');
const opsSheets = [
  { id: 'all', name: 'All Items' },
  { id: 's1', name: 'Invoice A' },
  { id: 's2', name: 'Invoice B' },
];

const opsRows = ref([
  {
    id: '1',
    sl: 1,
    name: 'Cotton tee',
    code: 'TF-1042',
    barcode: '8901234567890',
    price: 450,
    cost: 312,
    qty: 24,
    productWeight: 0.18,
    packageWeight: 0.22,
    selected: true,
  },
  {
    id: '2',
    sl: 2,
    name: 'Denim jacket',
    code: 'TF-1188',
    barcode: '8901234567891',
    price: 2150,
    cost: 1480,
    qty: 6,
    productWeight: 0.74,
    packageWeight: 0.91,
    selected: false,
  },
]);

const opsAllSelected = computed({
  get: () => opsRows.value.length > 0 && opsRows.value.every((row) => row.selected),
  set: (value: boolean | string | number | null) => {
    const selected = !!value;
    opsRows.value.forEach((row) => {
      row.selected = selected;
    });
  },
});

const opsColumnDefs = [
  { name: 'image', label: 'Image' },
  { name: 'name', label: 'Name' },
  { name: 'codes', label: 'Codes' },
  { name: 'price', label: 'Price' },
  { name: 'cost', label: 'Cost' },
  { name: 'qty', label: 'Qty' },
  { name: 'weight', label: 'Wt' },
  { name: 'pkg', label: 'Pkg' },
];

const opsVisible = ref<Record<string, boolean>>({
  image: true,
  name: true,
  codes: true,
  price: true,
  cost: true,
  qty: true,
  weight: true,
  pkg: true,
});

const opsAllColumnsVisible = computed(() =>
  opsColumnDefs.every((col) => opsVisible.value[col.name]),
);

const opsColSpan = computed(
  () => 2 + opsColumnDefs.filter((col) => opsVisible.value[col.name]).length,
);

function toggleOpsColumns() {
  const next = !opsAllColumnsVisible.value;
  opsColumnDefs.forEach((col) => {
    opsVisible.value[col.name] = next;
  });
}

const chartPrimaryRgb = computed(() => {
  void mode.value;
  const root =
    typeof document === 'undefined' ? null : document.querySelector('.ds-kit.theme-app');
  return readThemeRgb('72 139 143', root);
});

const shopChartRgb = computed(() => {
  void mode.value;
  const root =
    typeof document === 'undefined' ? null : document.querySelector('.theme-shop');
  return readThemeRgb('51 104 160', root);
});

const donutPrimary = computed(() => rgba(chartPrimaryRgb.value, 0.9));
const donutMuted = computed(() => (mode.value === 'dark' ? 'rgb(58 52 48)' : 'rgb(226 232 240)'));

const donutChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Available', 'Sold'],
  datasets: [
    {
      data: [128, 44],
      backgroundColor: [donutPrimary.value, donutMuted.value],
      borderWidth: 0,
      hoverOffset: 2,
    },
  ],
}));

const donutChartOptions: ChartOptions<'doughnut'> = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '72%',
  plugins: {
    legend: { display: false },
    tooltip: { backgroundColor: '#1c1917', padding: 8, cornerRadius: 6 },
  },
};

const hBarChartData: ChartData<'bar'> = {
  labels: ['Pending', 'Awaiting', 'Wholesale', 'Dropship', 'Closed'],
  datasets: [
    {
      data: [12, 8, 15, 6, 22],
      backgroundColor: ['#b45309', '#2563eb', '#7c3aed', '#0d9488', '#1a7f4b'],
      borderRadius: 6,
      borderSkipped: false,
      maxBarThickness: 22,
    },
  ],
};

const hBarChartOptions: ChartOptions<'bar'> = {
  indexAxis: 'y',
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: { backgroundColor: '#1c1917', padding: 8, cornerRadius: 6 },
  },
  scales: {
    x: {
      beginAtZero: true,
      grid: { color: 'rgba(148, 163, 184, 0.25)' },
      ticks: { color: 'var(--bw-theme-muted)', font: { size: 11, weight: 600 }, precision: 0 },
      border: { display: false },
    },
    y: {
      grid: { display: false },
      ticks: { color: 'var(--bw-theme-ink)', font: { size: 11, weight: 600 } },
      border: { display: false },
    },
  },
};

const vBarChartData: ChartData<'bar'> = {
  labels: ['Grade A', 'Grade B', 'Grade C'],
  datasets: [
    {
      data: [10400, 4200, 1950],
      backgroundColor: ['#1d4ed8', '#0284c7', '#475569'],
      borderRadius: 4,
      borderSkipped: false,
    },
  ],
};

const vBarChartOptions: ChartOptions<'bar'> = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: { backgroundColor: '#1c1917', padding: 6, cornerRadius: 6 },
  },
  scales: {
    x: {
      grid: { display: false },
      ticks: { color: 'var(--bw-theme-ink)', font: { size: 10, weight: 700 } },
      border: { display: false },
    },
    y: {
      grid: { color: 'rgba(148, 163, 184, 0.25)' },
      ticks: { color: 'var(--bw-theme-muted)', font: { size: 10, weight: 600 } },
      border: { display: false },
    },
  },
};

const lineChartData = computed<ChartData<'line'>>(() => ({
  labels: ['9 AM', '11 AM', '1 PM', '3 PM', '5 PM', '7 PM', '9 PM'],
  datasets: [
    {
      data: [28000, 64000, 112000, 96000, 52000, 24000, 8500],
      borderColor: rgba(shopChartRgb.value, 1),
      backgroundColor: rgba(shopChartRgb.value, 0.12),
      borderWidth: 2.5,
      tension: 0.4,
      fill: true,
      pointBackgroundColor: rgba(shopChartRgb.value, 1),
      pointBorderColor: '#ffffff',
      pointBorderWidth: 2,
      pointRadius: 4,
      pointHoverRadius: 6,
    },
  ],
}));

const lineChartOptions: ChartOptions<'line'> = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#0f172a',
      padding: 8,
      cornerRadius: 6,
      callbacks: {
        label: (item) => ` ৳${Number(item.raw).toLocaleString()}`,
      },
    },
  },
  scales: {
    x: {
      grid: { display: false },
      ticks: { color: 'var(--bw-theme-muted)', font: { size: 10, weight: 600 } },
      border: { display: false },
    },
    y: {
      grid: { color: 'rgba(226, 232, 240, 0.6)' },
      ticks: {
        color: 'var(--bw-theme-muted)',
        font: { size: 10 },
        callback: (val) => `৳${Number(val) / 1000}k`,
      },
      border: { display: false },
    },
  },
};

onMounted(() => {
  mode.value = document.body.classList.contains('body--dark') ? 'dark' : 'light';
});

const scopes = [
  { id: 'platform', label: 'Platform', className: 'theme-platform' },
  { id: 'app', label: 'App (merchant desk)', className: 'theme-app' },
  { id: 'shop', label: 'Shop (customer)', className: 'theme-shop' },
  { id: 'investor', label: 'Investor', className: 'theme-investor' },
] as const;

const neutralTokens = [
  { token: '--bw-neutral-canvas', label: 'Canvas' },
  { token: '--bw-neutral-surface', label: 'Surface' },
  { token: '--bw-neutral-border', label: 'Border' },
  { token: '--bw-neutral-ink', label: 'Ink' },
  { token: '--bw-neutral-muted', label: 'Muted' },
  { token: '--bw-neutral-chrome', label: 'Chrome' },
];

const semanticTokens = [
  { token: '--bw-success', label: 'Success' },
  { token: '--bw-success-soft', label: 'Success soft' },
  { token: '--bw-warning', label: 'Warning' },
  { token: '--bw-warning-soft', label: 'Warning soft' },
  { token: '--bw-error', label: 'Error' },
  { token: '--bw-error-soft', label: 'Error soft' },
  { token: '--bw-info', label: 'Info' },
  { token: '--bw-info-soft', label: 'Info soft' },
];

const opsHueTokens = [
  { token: '--bw-ops-hue-weight', label: 'Weight' },
  { token: '--bw-ops-hue-price', label: 'Price' },
  { token: '--bw-ops-hue-cost', label: 'Cost' },
  { token: '--bw-ops-hue-qty', label: 'Qty' },
];

const radiusSamples = [
  { label: 'sm — controls', value: '8px' },
  { label: 'md — cards', value: '12px' },
  { label: 'pill — shop CTA', value: '999px' },
];

const Swatch = defineComponent({
  name: 'Swatch',
  props: {
    token: { type: String, required: true },
    label: { type: String, required: true },
  },
  setup(props) {
    const chipRef = ref<HTMLElement | null>(null);
    const resolved = ref('');

    onMounted(() => {
      if (chipRef.value) {
        resolved.value = getComputedStyle(chipRef.value).backgroundColor;
      }
    });

    return () =>
      h('div', { class: 'ds-swatch' }, [
        h('div', {
          ref: chipRef,
          class: 'ds-swatch__chip',
          style: { background: `var(${props.token})` },
        }),
        h('div', { class: 'ds-swatch__meta' }, [
          h('span', { class: 'ds-swatch__label' }, props.label),
          h('code', { class: 'ds-swatch__token' }, props.token),
          resolved.value ? h('span', { class: 'ds-swatch__resolved' }, resolved.value) : null,
        ]),
      ]);
  },
});

const ScopePanel = defineComponent({
  name: 'ScopePanel',
  props: {
    scope: {
      type: Object as PropType<(typeof scopes)[number]>,
      required: true,
    },
  },
  setup(props) {
    const themeTokens = [
      { token: '--bw-theme-base', label: 'Base' },
      { token: '--bw-theme-surface', label: 'Surface' },
      { token: '--bw-theme-border', label: 'Border' },
      { token: '--bw-theme-ink', label: 'Ink' },
      { token: '--bw-theme-muted', label: 'Muted' },
      { token: '--bw-theme-primary', label: 'Primary' },
      { token: '--bw-theme-primary-soft', label: 'Primary soft' },
      { token: '--q-primary', label: '--q-primary' },
    ];

    return () =>
      h(
        'article',
        { class: ['ds-scope-panel', props.scope.className] },
        [
          h('div', { class: 'ds-scope-panel__head' }, [
            h(AppLogoMark, { scope: props.scope.id, class: 'ds-scope-panel__mark' }),
            h('h3', { class: 'ds-scope-panel__title' }, props.scope.label),
          ]),
          h(
            'div',
            { class: 'ds-scope-panel__swatches' },
            themeTokens.map((item) =>
              h(Swatch, { key: item.token, token: item.token, label: item.label }),
            ),
          ),
          h('div', { class: 'ds-scope-panel__demo' }, [
            h('p', { class: 'ds-scope-panel__copy' }, 'Sample controls in this scope'),
            h('div', { class: 'ds-scope-panel__controls' }, [
              h('button', {
                type: 'button',
                class: 'ds-scope-primary-btn',
                style: {
                  background: 'var(--bw-theme-primary)',
                  color: 'var(--bw-theme-surface)',
                },
              }, 'Primary'),
              h('span', {
                class: 'ds-scope-chip',
                style: {
                  background: 'var(--bw-theme-primary-soft)',
                  color: 'var(--bw-theme-primary)',
                  border: '1px solid var(--bw-theme-border)',
                },
              }, 'Chip'),
            ]),
          ]),
        ],
      );
  },
});

watch(mode, (val) => {
  applyDarkMode(val === 'dark');
});
</script>

<style scoped lang="scss">
.design-system-page {
  max-width: none !important;
  min-height: 100vh;
  padding: clamp(1rem, 2.4vw, 2rem);
  background: var(--bw-neutral-canvas);
  color: var(--bw-neutral-ink);
}

.ds-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
  margin-bottom: 2rem;
}

.ds-title {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}

.ds-subtitle {
  margin: 0.35rem 0 0;
  color: var(--bw-neutral-muted);
  font-size: 0.875rem;

  code {
    font-size: 0.8rem;
  }
}

.ds-section {
  margin-bottom: 2.5rem;
}

.ds-section__title {
  margin: 0 0 1rem;
  font-size: 1.125rem;
  font-weight: 700;
}

.ds-note {
  margin: -0.25rem 0 1rem;
  font-size: 0.8125rem;
  color: var(--bw-neutral-muted);
}

.ds-swatch-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 0.75rem;
}

:deep(.ds-swatch) {
  display: flex;
  gap: 0.65rem;
  align-items: center;
  padding: 0.5rem;
  border: 1px solid var(--bw-neutral-border);
  border-radius: 8px;
  background: var(--bw-neutral-surface);
}

:deep(.ds-swatch__chip) {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  border: 1px solid rgb(0 0 0 / 0.08);
  flex-shrink: 0;
}

:deep(.ds-swatch__meta) {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  min-width: 0;
}

:deep(.ds-swatch__label) {
  font-size: 0.8125rem;
  font-weight: 600;
}

:deep(.ds-swatch__token) {
  font-size: 0.6875rem;
  color: var(--bw-neutral-muted);
  word-break: break-all;
}

:deep(.ds-swatch__resolved) {
  font-size: 0.625rem;
  color: var(--bw-neutral-chrome);
}

.ds-logo-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 0.75rem;
}

.ds-logo-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
  padding: 1.25rem 1rem;
  border: 1px solid var(--bw-theme-border, var(--bw-neutral-border));
  border-radius: 12px;
  background: var(--bw-theme-surface, var(--bw-neutral-surface));
}

.ds-logo-mark {
  width: 56px;
  height: 56px;
}

.ds-logo-card__label {
  font-size: 0.8125rem;
  font-weight: 600;
  text-align: center;
}

.ds-scope-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}

:deep(.ds-scope-panel) {
  border: 1px solid var(--bw-theme-border, var(--bw-neutral-border));
  border-radius: 12px;
  padding: 1rem;
  background: var(--bw-theme-base, var(--bw-neutral-canvas));
  color: var(--bw-theme-ink, var(--bw-neutral-ink));
}

:deep(.ds-scope-panel__head) {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  margin-bottom: 0.75rem;
}

:deep(.ds-scope-panel__mark) {
  width: 32px;
  height: 32px;
}

:deep(.ds-scope-panel__title) {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
}

:deep(.ds-scope-panel__swatches) {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
}

:deep(.ds-scope-panel .ds-swatch) {
  background: var(--bw-theme-surface, var(--bw-neutral-surface));
  border-color: var(--bw-theme-border, var(--bw-neutral-border));
}

:deep(.ds-scope-panel__demo) {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--bw-theme-border, var(--bw-neutral-border));
}

:deep(.ds-scope-panel__copy) {
  margin: 0 0 0.65rem;
  font-size: 0.75rem;
  color: var(--bw-theme-muted, var(--bw-neutral-muted));
}

:deep(.ds-scope-panel__controls) {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

:deep(.ds-scope-primary-btn) {
  border: 0;
  border-radius: 8px;
  padding: 0.4rem 0.85rem;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: default;
}

:deep(.ds-scope-chip) {
  border-radius: var(--bw-radius-sm);
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
}

.ds-type-stack {
  display: grid;
  gap: 0.85rem;
  padding: 1rem;
  border: 1px solid var(--bw-neutral-border);
  border-radius: 12px;
  background: var(--bw-neutral-surface);

  p {
    margin: 0;
  }
}

.ds-radius-row {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
}

.ds-radius-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.75rem;

  code {
    color: var(--bw-neutral-muted);
    font-size: 0.6875rem;
  }
}

.ds-radius-box {
  width: 72px;
  height: 48px;
  background: var(--bw-neutral-surface);
  border: 1px solid var(--bw-neutral-border);
}

.ds-component-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
  align-items: center;
}

.ds-card-sample {
  min-width: 200px;
}

.ds-surface-sample {
  min-width: 160px;
  min-height: 72px;
  padding: 0.75rem 1rem;
  display: flex;
  align-items: center;
  font-size: 0.8125rem;
  font-weight: 600;
}

.ds-kit {
  padding: 1.25rem 1.25rem 0;
  margin: 0 -0.25rem 2rem;
  border-radius: 12px;
  background: var(--bw-theme-base, var(--bw-neutral-canvas));
  border: 1px solid var(--bw-theme-border, var(--bw-neutral-border));
}

.ds-block {
  padding: 0.85rem 1rem 1rem;
  margin-bottom: 0.75rem;
  border: 1px solid var(--bw-theme-border, var(--bw-neutral-border));
  border-radius: 12px;
  background: var(--bw-theme-surface, var(--bw-neutral-surface));
}

.ds-block__label {
  margin-bottom: 0.65rem;
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, var(--bw-neutral-muted));
}

.ds-input-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 0.85rem;
}

.ds-hub-list {
  padding: 12px;
  border: 1px solid var(--bw-theme-border);
  border-radius: 8px;
  background: var(--bw-theme-surface);
}

.ds-hub-action {
  border-radius: 8px !important;
}

.ds-hub-search :deep(.q-field__control) {
  border-radius: 8px;
}

.ds-hub-search :deep(.q-field--outlined .q-field__control:before) {
  border: 1px solid var(--bw-theme-border);
}

.ds-hub-table {
  background: transparent;
}

.ds-hub-table :deep(.q-table__container) {
  box-shadow: none;
  background: transparent;
}

.ds-hub-table :deep(thead tr th) {
  background: color-mix(in srgb, var(--bw-theme-surface) 92%, var(--bw-theme-base) 8%);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.05em;
  color: var(--bw-theme-muted);
  border-bottom: 1px solid var(--bw-theme-border);
}

.ds-hub-table :deep(tbody tr td) {
  padding: 12px 16px;
  vertical-align: middle;
  border-bottom: 1px solid var(--bw-theme-border);
  color: var(--bw-theme-ink);
}

.ds-hub-table :deep(tbody tr:hover) {
  background-color: var(--bw-theme-primary-soft);
}

.ds-hub-two-line {
  min-height: 36px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.ds-hub-muted {
  font-size: 12px;
  line-height: 16px;
  color: var(--bw-theme-muted);
}

.ds-hub-avatar {
  background: var(--bw-theme-primary-soft);
  color: var(--bw-theme-primary);
  font-size: 12px;
  font-weight: 600;
}

.ds-hub-numeric {
  font-variant-numeric: tabular-nums;
  font-weight: 500;
  font-size: 13px;
}

.ds-hub-status {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 500;
  line-height: 18px;
}

.ds-hub-status--active {
  background: var(--bw-success-soft);
  color: var(--bw-success);
}

.ds-hub-status--inactive {
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, var(--bw-theme-base) 12%);
  color: var(--bw-theme-muted);
}

.ds-entity-list {
  padding: 12px;
  border: 1px solid var(--bw-theme-border);
  border-radius: 12px;
  background: var(--bw-theme-surface);
}

.ds-entity-list__toolbar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 12px;
}

.ds-entity-list__stack {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.ds-entity-row {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 12px 14px;
  border: 1px solid var(--bw-theme-border);
  border-radius: 12px;
  background: var(--bw-theme-surface);
  color: var(--bw-theme-ink);
  cursor: pointer;
  text-align: left;
  transition:
    transform 0.2s cubic-bezier(0.4, 0, 0.2, 1),
    box-shadow 0.2s ease,
    border-color 0.2s ease,
    background-color 0.2s ease;
}

.ds-entity-row:hover {
  transform: translateY(-1px);
  box-shadow: var(--bw-theme-shadow);
  border-color: color-mix(in srgb, var(--bw-theme-primary) 28%, var(--bw-theme-border));
}

.ds-entity-row:focus-visible {
  outline: 2px solid var(--bw-theme-primary);
  outline-offset: 2px;
}

.ds-entity-row--active {
  background: var(--bw-theme-primary-soft);
  border-color: color-mix(in srgb, var(--bw-theme-primary) 38%, var(--bw-theme-border));
}

.ds-entity-row__avatar {
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: var(--bw-theme-primary-soft);
  color: var(--bw-theme-primary);
  font-size: 13px;
  font-weight: 700;
}

.ds-entity-row__body {
  min-width: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.ds-entity-row__name {
  font-size: 14px;
  font-weight: 600;
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ds-entity-row__meta {
  font-size: 12px;
  line-height: 1.35;
  color: var(--bw-theme-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ds-entity-row__side {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
}

.ds-entity-row__money {
  font-size: 13px;
  font-weight: 600;
  color: var(--bw-theme-ink);
}

.ds-entity-row__money--neg {
  color: var(--bw-error);
}

@media (max-width: 640px) {
  .ds-entity-row {
    flex-wrap: wrap;
  }

  .ds-entity-row__side {
    margin-left: 52px;
    align-items: flex-start;
  }
}

.ds-chart-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}

.ds-chart-card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #fff);
}

.ds-chart-card__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.85rem;
}

.ds-chart-card__title {
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, var(--bw-neutral-muted));
}

.ds-chart-card__sub {
  margin-top: 0.2rem;
  font-size: 0.78rem;
  color: var(--bw-theme-muted, var(--bw-neutral-muted));
}

.ds-chart-card__kpi {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}

.ds-chart-card__kpi-value {
  font-family: var(--bw-font-mono, inherit);
  font-size: 1.25rem;
  font-weight: 600;
  line-height: 1;
}

.ds-chart-card__kpi-label {
  margin-top: 0.2rem;
  font-size: 0.68rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, var(--bw-neutral-muted));
}

.ds-chart-card__canvas {
  height: 180px;
}

.ds-chart-card__body--split {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.ds-donut {
  position: relative;
  width: 140px;
  height: 140px;
  flex-shrink: 0;
}

.ds-donut__center {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.ds-donut__pct {
  font-family: var(--bw-font-mono, inherit);
  font-size: 1.1rem;
  font-weight: 600;
  line-height: 1;
}

.ds-donut__caption {
  margin-top: 0.15rem;
  font-size: 0.65rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, var(--bw-neutral-muted));
}

.ds-donut-legend {
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  font-size: 0.8rem;
  min-width: 0;
}

.ds-donut-legend__row {
  display: flex;
  align-items: center;
  gap: 0.45rem;
}

.ds-donut-legend__row b {
  margin-left: auto;
  font-variant-numeric: tabular-nums;
}

.ds-donut-legend__dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  flex-shrink: 0;
}

.ds-donut-legend__dot--muted {
  background: rgb(226 232 240);
}

.ds-meter {
  display: flex;
  height: 12px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--bw-neutral-border);
}

.ds-meter__seg {
  height: 100%;
}

.ds-meter-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.85rem;
  margin-top: 0.75rem;
  font-size: 0.75rem;
  color: var(--bw-theme-muted, var(--bw-neutral-muted));
}

.ds-meter-legend span {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.ds-meter-legend i {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  display: inline-block;
}

.ds-meter-legend__swatch--shop {
  background: var(--bw-theme-primary);
}

.ds-meter-legend__swatch--success {
  background: var(--bw-success);
}

.ds-meter-legend__swatch--warning {
  background: var(--bw-warning);
}

.ds-dialog-card {
  min-width: min(420px, 92vw);
  border-radius: 12px;
}

.ds-extended-card {
  width: 520px;
  max-width: 95vw;
  height: calc(100vh - 32px);
  margin: 16px;
  border-radius: 12px;
}

.ds-add-products-card {
  width: 640px;
  max-width: 95vw;
  height: calc(100vh - 24px);
  margin: 12px;
  border-radius: 12px;
  overflow: hidden;
  background: var(--bw-theme-surface);
  color: var(--bw-theme-ink);
  border: 1px solid var(--bw-theme-border);
}

.ds-add-products-header {
  background: var(--q-primary);
}

.ds-add-products-toolbar {
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, var(--bw-theme-base) 12%);
  border-bottom: 1px solid var(--bw-theme-border);
}

.ds-add-products-bulk {
  background: color-mix(in srgb, var(--bw-theme-surface) 82%, var(--bw-theme-base) 18%);
  border: 1px solid var(--bw-theme-border);
}

.ds-add-products-body {
  min-height: 0;
}

.ds-add-products-scroll {
  overflow-y: auto;
  min-height: 0;
}

.ds-add-products-list {
  border: 1px solid var(--bw-theme-border);
}

.ds-add-products-thumb {
  background: var(--bw-theme-base);
  color: var(--bw-theme-muted);
}

.ds-add-products-footer {
  border-top: 1px solid var(--bw-theme-border);
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, var(--bw-theme-base) 12%);
}

.ds-ops-sheet {
  display: flex;
  flex-direction: column;
  height: 420px;
  overflow: hidden;
  border: 1px solid var(--bw-theme-border);
  border-radius: 8px;
  background: var(--bw-theme-surface);
  color: var(--bw-theme-ink);
}

.ds-ops-sheet__toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.75rem;
  flex-shrink: 0;
  padding: 12px 16px;
  border-bottom: 1px solid var(--bw-theme-border);
  background: var(--bw-theme-surface);
}

.ds-ops-sheet__ghost {
  border: 1px solid var(--bw-theme-border);
  border-radius: 8px;
}

.ds-ops-sheet__scroll {
  flex: 1;
  min-height: 0;
  overflow: auto;
  background: var(--bw-theme-surface);
}

.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
}

.avatar-soft-sq {
  border-radius: 6px;
}

:deep(.ds-ops-table) {
  background: var(--bw-theme-surface);
  color: var(--bw-theme-ink);
}

:deep(.ds-ops-table th),
:deep(.ds-ops-table td) {
  padding: 4px !important;
  height: 48px;
  color: var(--bw-theme-ink);
}

:deep(.ds-ops-table tbody td:not([class*='bw-ops-col-tint'])) {
  background-color: var(--bw-theme-surface) !important;
}

:deep(.ds-ops-table thead th:not([class*='bw-ops-col-tint'])) {
  background: color-mix(in srgb, var(--bw-theme-surface) 92%, var(--bw-theme-base) 8%) !important;
  color: var(--bw-theme-muted) !important;
  border-bottom: 1px solid var(--bw-theme-border);
}

:deep(.ds-ops-table thead th[class*='bw-ops-col-tint']) {
  color: var(--bw-theme-muted) !important;
  border-bottom: 1px solid var(--bw-theme-border);
}

:deep(.ds-ops-table tr.row-selected td:not([class*='bw-ops-col-tint'])) {
  background-color: color-mix(in srgb, var(--bw-theme-surface) 82%, var(--bw-theme-primary) 18%) !important;
}

:deep(.ds-ops-table tr:hover td) {
  filter: brightness(0.98);
}

:deep(.ds-ops-table .section-break-row) {
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, var(--bw-theme-base) 12%) !important;
  border-top: 2px solid var(--bw-theme-border) !important;
  border-bottom: 1px solid var(--bw-theme-border) !important;
}

:deep(.ds-ops-table .section-break-row td) {
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, var(--bw-theme-base) 12%) !important;
  height: 38px !important;
  color: var(--bw-theme-ink);
}

:deep(.inline-edit-input input[type='number']::-webkit-outer-spin-button),
:deep(.inline-edit-input input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(.inline-edit-input input[type='number']) {
  appearance: textfield;
}

:deep(.inline-edit-input .q-field__control) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 4px !important;
}

:deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
}

:deep(.excel-cell-input .q-field__control:before),
:deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

:deep(.excel-cell-input:hover .q-field__control) {
  background-color: color-mix(in srgb, var(--bw-theme-ink) 6%, transparent) !important;
}

:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: var(--bw-theme-surface) !important;
  border: 1.5px solid var(--bw-theme-primary) !important;
  box-shadow: 0 0 0 1px var(--bw-theme-primary) !important;
}
</style>

<template>
  <div class="tf-vpc">
    <header v-if="showHeader" class="tf-vpc__header">
      <h2 class="tf-vpc__title">{{ labels.title || 'The Value Proposition Canvas' }}</h2>
      <div class="tf-vpc__name-row">
        <div class="tf-vpc__name-field">
          <span class="tf-vpc__name-label">Value proposition</span>
          <span class="tf-vpc__name-value">{{ labels.valueProposition || '—' }}</span>
        </div>
        <div class="tf-vpc__name-field">
          <span class="tf-vpc__name-label">Customer segment</span>
          <span class="tf-vpc__name-value">{{ labels.customerSegment || '—' }}</span>
        </div>
      </div>
    </header>

    <div class="tf-vpc__stage">
      <div class="tf-vpc-square">
        <svg class="tf-vpc-square__rules" viewBox="0 0 100 100" aria-hidden="true">
          <rect x="1.6" y="1.6" width="96.8" height="96.8" />
          <line x1="50" y1="50" x2="1.6" y2="1.6" />
          <line x1="50" y1="50" x2="1.6" y2="98.4" />
          <line x1="50" y1="50" x2="98.4" y2="50" />
        </svg>
        <div class="tf-vpc-wedge tf-vpc-wedge--products">
          <TfVpcSectionHeader icon="ph ph-package" label="Products and services" align="start" />
          <TfVpcTitleChips
            align="start"
            :items="productsAndServices"
            :active-title="active?.title"
            @select="(item, ev) => openNote(item, 'Products and services', ev)"
          />
        </div>
        <div class="tf-vpc-wedge tf-vpc-wedge--gain-creators">
          <TfVpcSectionHeader icon="ph ph-chart-line-up" label="Gain creators" />
          <TfVpcTitleChips
            :items="gainCreators"
            :active-title="active?.title"
            @select="(item, ev) => openNote(item, 'Gain creators', ev)"
          />
        </div>
        <div class="tf-vpc-wedge tf-vpc-wedge--pain-relievers">
          <TfVpcTitleChips
            :items="painRelievers"
            :active-title="active?.title"
            @select="(item, ev) => openNote(item, 'Pain relievers', ev)"
          />
          <TfVpcSectionHeader icon="ph ph-pill" label="Pain relievers" />
        </div>
        <div class="tf-vpc-square__hub" aria-hidden="true">
          <q-icon name="ph ph-gift" size="26px" />
        </div>
      </div>

      <div class="tf-vpc__connector" aria-hidden="true">
        <svg viewBox="0 0 40 24" width="40" height="24">
          <line x1="0" y1="12" x2="12" y2="12" />
          <polyline points="16,5 10,12 16,19" fill="none" />
          <polyline points="24,5 30,12 24,19" fill="none" />
          <line x1="28" y1="12" x2="40" y2="12" />
        </svg>
      </div>

      <div class="tf-vpc-circle">
        <svg class="tf-vpc-circle__rules" viewBox="0 0 100 100" aria-hidden="true">
          <circle cx="50" cy="50" r="47.8" />
          <line x1="2.2" y1="50" x2="50" y2="50" />
          <line x1="50" y1="50" x2="83.8" y2="16.2" />
          <line x1="50" y1="50" x2="83.8" y2="83.8" />
        </svg>

        <div class="tf-vpc-wedge tf-vpc-wedge--gains">
          <TfVpcSectionHeader icon="ph ph-smiley" label="Gains" />
          <TfVpcTitleChips
            :items="gains"
            :active-title="active?.title"
            @select="(item, ev) => openNote(item, 'Gains', ev)"
          />
        </div>
        <div class="tf-vpc-wedge tf-vpc-wedge--pains">
          <TfVpcTitleChips
            :items="pains"
            :active-title="active?.title"
            @select="(item, ev) => openNote(item, 'Pains', ev)"
          />
          <TfVpcSectionHeader icon="ph ph-smiley-sad" label="Pains" />
        </div>
        <div class="tf-vpc-wedge tf-vpc-wedge--jobs">
          <TfVpcSectionHeader icon="ph ph-list-checks" label="Customer jobs" />
          <TfVpcTitleChips
            :items="customerJobs"
            :active-title="active?.title"
            @select="(item, ev) => openNote(item, 'Customer jobs', ev)"
          />
        </div>
        <div class="tf-vpc-circle__hub" aria-hidden="true">
          <q-icon name="ph ph-user" size="24px" />
        </div>
      </div>
    </div>

    <q-dialog
      :model-value="noteOpen"
      transition-duration="0"
      @update:model-value="onDialogModel"
      @show="playOpenFromPin"
    >
      <div ref="noteEl" class="tf-vpc-stickynote" role="document">
        <span class="tf-vpc-stickynote__pin" aria-hidden="true" />
        <button
          type="button"
          class="tf-vpc-stickynote__close"
          aria-label="Close note"
          @click="closeNote"
        >
          <q-icon name="ph ph-x" size="16px" />
        </button>
        <p class="tf-vpc-stickynote__sector">{{ activeSector }}</p>
        <h3 class="tf-vpc-stickynote__title">{{ active?.title }}</h3>
        <p v-if="active?.note" class="tf-vpc-stickynote__body">{{ active.note }}</p>
        <p v-else class="tf-vpc-stickynote__body tf-vpc-stickynote__body--empty">
          No note for this title.
        </p>
      </div>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import type {
  ValuePropositionCanvasData,
  ValuePropositionCanvasNote,
} from './valuePropositionCanvas.types';
import TfVpcSectionHeader from './TfVpcSectionHeader.vue';
import TfVpcTitleChips from './TfVpcTitleChips.vue';

const props = withDefaults(
  defineProps<ValuePropositionCanvasData & { showHeader?: boolean }>(),
  {
    productsAndServices: () => [],
    gainCreators: () => [],
    painRelievers: () => [],
    customerJobs: () => [],
    gains: () => [],
    pains: () => [],
    fit: () => [],
    showHeader: true,
  },
);

const labels = computed(() => props.labels ?? {});

const noteOpen = ref(false);
const closing = ref(false);
const active = ref<ValuePropositionCanvasNote | null>(null);
const activeSector = ref('');
const origin = ref<DOMRect | null>(null);
const noteEl = ref<HTMLElement | null>(null);

function openNote(item: ValuePropositionCanvasNote, sector: string, event: MouseEvent) {
  const target = event.currentTarget as HTMLElement | null;
  origin.value = target?.getBoundingClientRect() ?? null;
  active.value = item;
  activeSector.value = sector;
  noteOpen.value = true;
}

function flyNote(toOrigin: boolean) {
  const el = noteEl.value;
  const src = origin.value;
  if (!el || !src) return false;
  const dest = el.getBoundingClientRect();
  const dx = src.left + src.width / 2 - (dest.left + dest.width / 2);
  const dy = src.top + src.height / 2 - (dest.top + dest.height / 2);
  const sx = Math.max(0.12, src.width / dest.width);
  const sy = Math.max(0.12, src.height / dest.height);
  if (toOrigin) {
    el.style.transition = 'transform 260ms cubic-bezier(.45,0,.7,.2), opacity 180ms ease';
    el.style.transform = `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`;
    el.style.opacity = '0';
    return true;
  }
  el.style.transition = 'none';
  el.style.transform = `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`;
  el.style.opacity = '0.45';
  void el.offsetWidth;
  requestAnimationFrame(() => {
    el.style.transition = 'transform 340ms cubic-bezier(.22,.82,.2,1), opacity 200ms ease';
    el.style.transform = 'rotate(-1.2deg)';
    el.style.opacity = '1';
  });
  return true;
}

function playOpenFromPin() {
  flyNote(false);
}

function closeNote() {
  if (!noteOpen.value || closing.value) return;
  closing.value = true;
  const animated = flyNote(true);
  window.setTimeout(
    () => {
      noteOpen.value = false;
      closing.value = false;
    },
    animated ? 260 : 0,
  );
}

function onDialogModel(open: boolean) {
  if (open) noteOpen.value = true;
  else closeNote();
}
</script>

<style scoped>
.tf-vpc {
  min-width: 0;
  max-width: 100%;
  color: var(--tf-neutral-ink);
  container-type: inline-size;
}

.tf-vpc__header {
  margin-bottom: 20px;
}

.tf-vpc__title {
  margin: 0 0 16px;
  font-size: 1.35rem;
  font-weight: 650;
  letter-spacing: -0.03em;
  line-height: 1.2;
}

.tf-vpc__name-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 28px;
}

@media (max-width: 640px) {
  .tf-vpc__name-row {
    grid-template-columns: 1fr;
    gap: 12px;
  }
}

.tf-vpc__name-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.tf-vpc__name-label {
  font-size: 10px;
  font-weight: 650;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted);
}

.tf-vpc__name-value {
  font-size: 13px;
  font-weight: 500;
  line-height: 1.35;
}

.tf-vpc__stage {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 32px minmax(0, 1fr);
  gap: 4px;
  align-items: center;
  width: 100%;
  max-width: 100%;
  min-width: 0;
}

@container (max-width: 680px) {
  .tf-vpc__stage {
    grid-template-columns: 1fr;
  }

  .tf-vpc__connector {
    justify-self: center;
    transform: rotate(90deg);
  }
}

@media (max-width: 720px) {
  .tf-vpc__stage {
    grid-template-columns: 1fr;
  }

  .tf-vpc__connector {
    justify-self: center;
    transform: rotate(90deg);
  }
}

.tf-vpc-square,
.tf-vpc-circle {
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  background: transparent;
  overflow: hidden;
}

.tf-vpc-circle {
  border-radius: 50%;
}

.tf-vpc-square__rules,
.tf-vpc-circle__rules {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  z-index: 1;
}

.tf-vpc-square__rules rect,
.tf-vpc-circle__rules circle {
  fill: var(--tf-neutral-canvas, #fff);
  stroke: var(--tf-neutral-ink);
  stroke-width: 2.4;
  vector-effect: non-scaling-stroke;
}

.tf-vpc-square__rules line,
.tf-vpc-circle__rules line,
.tf-vpc__connector line,
.tf-vpc__connector polyline {
  stroke: var(--tf-neutral-ink);
  stroke-width: 2.4;
  stroke-linecap: butt;
  stroke-linejoin: miter;
  vector-effect: non-scaling-stroke;
}

.tf-vpc-wedge {
  position: absolute;
  z-index: 2;
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
  overflow: visible;
}

.tf-vpc-wedge--products {
  left: 4%;
  top: 26%;
  width: 30%;
  height: 48%;
  justify-content: center;
  align-items: flex-start;
}

.tf-vpc-wedge--gain-creators {
  left: 38%;
  top: 6%;
  width: 48%;
  height: 34%;
  align-items: center;
}

.tf-vpc-wedge--pain-relievers {
  left: 38%;
  bottom: 6%;
  width: 48%;
  height: 34%;
  align-items: center;
  justify-content: flex-end;
}

.tf-vpc-wedge--gains {
  left: 10%;
  top: 8%;
  width: 38%;
  height: 32%;
  align-items: center;
}

.tf-vpc-wedge--pains {
  left: 10%;
  bottom: 8%;
  width: 38%;
  height: 32%;
  align-items: center;
  justify-content: flex-end;
}

.tf-vpc-wedge--jobs {
  left: 62%;
  top: 22%;
  width: 30%;
  height: 56%;
  align-items: center;
  justify-content: center;
}

.tf-vpc-square__hub,
.tf-vpc-circle__hub {
  position: absolute;
  z-index: 3;
  left: 50%;
  top: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  transform: translate(-50%, -50%);
  background: var(--tf-neutral-canvas, #fff);
  color: var(--tf-neutral-ink);
}

.tf-vpc-circle__hub {
  border-radius: 50%;
}

.tf-vpc__connector {
  display: flex;
  align-items: center;
  justify-content: center;
}

.tf-vpc__connector svg {
  overflow: visible;
}

.tf-vpc-stickynote {
  position: relative;
  width: min(340px, calc(100vw - 32px));
  padding: 28px 22px 22px;
  transform: rotate(-1.2deg);
  transform-origin: center center;
  background: color-mix(in srgb, #f6e27a 82%, var(--tf-neutral-surface));
  color: #1c1910;
  box-shadow:
    0 1px 0 color-mix(in srgb, #000 8%, transparent),
    0 18px 40px color-mix(in srgb, #000 18%, transparent);
}

.body--dark .tf-vpc-stickynote {
  background: color-mix(in srgb, #c9ae3a 55%, var(--tf-neutral-surface));
  color: var(--tf-neutral-ink);
}

.tf-vpc-stickynote__pin {
  position: absolute;
  top: -8px;
  left: 50%;
  width: 14px;
  height: 14px;
  transform: translateX(-50%);
  border-radius: 50%;
  background: color-mix(in srgb, #c23b3b 88%, #fff);
  box-shadow:
    0 0 0 2px color-mix(in srgb, #fff 50%, transparent),
    0 3px 4px color-mix(in srgb, #000 28%, transparent);
}

.tf-vpc-stickynote__close {
  position: absolute;
  top: 10px;
  right: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  border: 0;
  border-radius: 4px;
  background: transparent;
  color: inherit;
  opacity: 0.55;
  cursor: pointer;
}

.tf-vpc-stickynote__close:hover,
.tf-vpc-stickynote__close:focus-visible {
  opacity: 1;
  background: color-mix(in srgb, #000 8%, transparent);
}

.tf-vpc-stickynote__close:focus-visible {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

.tf-vpc-stickynote__sector {
  margin: 0 0 8px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  opacity: 0.62;
}

.tf-vpc-stickynote__title {
  margin: 0 0 10px;
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.25;
}

.tf-vpc-stickynote__body {
  margin: 0;
  font-size: 14px;
  line-height: 1.5;
}

.tf-vpc-stickynote__body--empty {
  opacity: 0.6;
}
</style>

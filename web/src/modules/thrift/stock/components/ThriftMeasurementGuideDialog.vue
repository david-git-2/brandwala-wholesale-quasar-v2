<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card style="width: 800px; max-width: 95vw;" class="floating-surface shadow-2">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div>
          <div class="text-h6 text-weight-bold">Measurement guide</div>
          <div class="text-caption text-grey-8">What each field means and how to measure</div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-banner dense rounded class="bg-blue-1 text-grey-9 q-mx-md q-mb-sm">
        All measurements are optional. Lay the item flat on a table. Record inches to one decimal place.
      </q-banner>

      <q-card-section class="q-pt-none scroll" style="max-height: 70vh;">
        <q-tabs
          v-model="activeTab"
          dense
          class="text-primary q-mb-md"
          active-color="primary"
          indicator-color="primary"
          align="left"
          narrow-indicator
        >
          <q-tab
            v-for="section in sections"
            :key="section.id"
            :name="section.id"
            :label="section.label"
            no-caps
          />
        </q-tabs>

        <q-tab-panels v-model="activeTab" animated>
          <q-tab-panel
            v-for="section in sections"
            :key="section.id"
            :name="section.id"
            class="q-pa-none"
          >
            <q-list separator>
              <q-expansion-item
                v-for="entry in entriesFor(section.id)"
                :key="entry.key"
                :label="entry.label"
                :caption="entry.summary"
                header-class="text-weight-medium"
                expand-separator
                @show="selectedKey = entry.key"
              >
                <q-card flat class="q-pa-md bg-grey-1">
                  <div class="row q-col-gutter-md">
                    <div :class="entry.diagram === 'none' ? 'col-12' : 'col-12 col-sm-7'">
                      <div class="text-body2 text-grey-9 q-mb-sm">{{ entry.summary }}</div>
                      <div class="text-caption text-grey-8">
                        <span class="text-weight-bold">How to measure:</span>
                        {{ entry.howToMeasure }}
                      </div>
                    </div>
                    <div
                      v-if="entry.diagram !== 'none' && entry.highlight"
                      class="col-12 col-sm-5 flex flex-center"
                    >
                      <measurement-diagram-flat
                        :highlight="entry.highlight"
                        :variant="diagramVariant(entry.diagram)"
                      />
                    </div>
                  </div>
                </q-card>
              </q-expansion-item>
            </q-list>
          </q-tab-panel>
        </q-tab-panels>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Close" color="primary" v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script lang="ts">
import { defineComponent, ref } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import {
  MEASUREMENT_GUIDE_SECTIONS,
  guideEntriesForSection,
  type MeasurementGuideSection,
  type MeasurementDiagramVariant,
} from '../../shared/constants/thriftMeasurementGuide';
import MeasurementDiagramFlat from './measurement-diagrams/MeasurementDiagramFlat.vue';

export default defineComponent({
  name: 'ThriftMeasurementGuideDialog',
  components: {
    MeasurementDiagramFlat,
  },
  emits: [...useDialogPluginComponent.emits],
  setup() {
    const { dialogRef, onDialogHide } = useDialogPluginComponent();

    const sections = MEASUREMENT_GUIDE_SECTIONS;
    const activeTab = ref<MeasurementGuideSection>('tag');
    const selectedKey = ref('');

    function entriesFor(section: MeasurementGuideSection) {
      return guideEntriesForSection(section);
    }

    function diagramVariant(diagram: MeasurementDiagramVariant): 'dress' | 'top' {
      return diagram === 'flatTop' ? 'top' : 'dress';
    }

    return {
      dialogRef,
      onDialogHide,
      sections,
      activeTab,
      selectedKey,
      entriesFor,
      diagramVariant,
    };
  },
});
</script>

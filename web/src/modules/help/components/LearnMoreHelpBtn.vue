<template>
  <q-btn
    flat
    dense
    no-caps
    :round="!label"
    :icon="icon"
    :label="label"
    :color="color"
    :size="size"
    class="learn-more-help-btn"
    @click="onClick"
  >
    <q-tooltip v-if="!label">{{ tooltip }}</q-tooltip>
  </q-btn>
</template>

<script setup lang="ts">
import type { HelpTab } from '../types';
import { useModuleHelp } from '../composables/useModuleHelp';

const props = withDefaults(
  defineProps<{
    guideId: string;
    tab?: HelpTab;
    sectionId?: string;
    label?: string;
    icon?: string;
    color?: string;
    size?: string;
    tooltip?: string;
  }>(),
  {
    tab: 'overview',
    icon: 'ph ph-question',
    color: 'primary',
    size: 'sm',
    tooltip: 'Learn more',
  },
);

const { openHelp } = useModuleHelp();

const onClick = () => {
  const opts: { guideId: string; tab?: HelpTab; sectionId?: string } = {
    guideId: props.guideId,
  };
  if (props.tab) opts.tab = props.tab;
  if (props.sectionId) opts.sectionId = props.sectionId;
  openHelp(opts);
};
</script>

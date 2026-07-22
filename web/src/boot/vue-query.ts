import { defineBoot } from '#q-app';
import { VueQueryPlugin } from '@tanstack/vue-query';
import { appQueryClient } from 'src/query/queryClient';

export default defineBoot(({ app }) => {
  app.use(VueQueryPlugin, {
    queryClient: appQueryClient,
  });
});

import { defineBoot } from '#q-app';
import CloudinaryUploaderDialog from 'src/components/CloudinaryUploaderDialog.vue';

export default defineBoot(({ app }) => {
  app.component('CloudinaryUploaderDialog', CloudinaryUploaderDialog);
});

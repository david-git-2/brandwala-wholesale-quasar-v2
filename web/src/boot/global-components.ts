import { defineBoot } from '#q-app/wrappers';
import CloudinaryUploaderDialog from 'src/components/CloudinaryUploaderDialog.vue';

export default defineBoot(({ app }) => {
  app.component('CloudinaryUploaderDialog', CloudinaryUploaderDialog);
});

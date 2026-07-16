import enUS from './en-US';
import bn from './bn';

export default {
  'en-US': enUS,
  bn: bn,
};
export type MessageLanguages = 'en-US' | 'bn';
export type MessageSchema = typeof enUS;

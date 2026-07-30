import type { ModuleGuide } from '../../types';

export const platformAdminGuide: ModuleGuide = {
  id: 'platform_admin',
  title: { en: 'Platform Admin', bn: 'প্ল্যাটফর্ম অ্যাডমিন' },
  caption: {
    en: 'Tenants, modules, and platform controls',
    bn: 'টেন্যান্ট, মডিউল এবং প্ল্যাটফর্ম নিয়ন্ত্রণ',
  },
  icon: 'ph ph-shield',
  scopes: ['platform'],
  audiences: ['superadmin'],
  routeMatchers: ['/platform/tenants', '/platform/modules', '/platform/superadmins'],
  overview: {
    en: 'Platform Admin covers tenant provisioning, feature catalog activation, and superadmin access. Content will expand as guides are added.',
    bn: 'প্ল্যাটফর্ম অ্যাডমিনে টেন্যান্ট প্রভিশনিং, ফিচার ক্যাটালগ সক্রিয়করণ এবং সুপারঅ্যাডমিন অ্যাক্সেস রয়েছে। গাইড যোগ হওয়ার সাথে সাথে বিষয়বস্তু বাড়বে।',
  },
  workflows: [
    {
      id: 'open-tenants',
      title: { en: 'Open tenants', bn: 'টেন্যান্ট খুলুন' },
      steps: [
        {
          en: 'From the sidebar, open Tenants.',
          bn: 'সাইডবার থেকে Tenants খুলুন।',
        },
        {
          en: 'Select a business to review status and access.',
          bn: 'স্ট্যাটাস ও অ্যাক্সেস দেখতে একটি ব্যবসা নির্বাচন করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Feature Catalog', bn: 'ফিচার ক্যাটালগ' },
      definition: {
        en: 'Controls which product modules a tenant can use.',
        bn: 'একটি টেন্যান্ট কোন পণ্য মডিউল ব্যবহার করতে পারবে তা নিয়ন্ত্রণ করে।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Where do I turn a module on for a tenant?',
        bn: 'একটি টেন্যান্টের জন্য মডিউল কোথায় চালু করব?',
      },
      answer: {
        en: 'Use Feature Catalog (Modules) in the platform sidebar, then assign modules to the tenant.',
        bn: 'প্ল্যাটফর্ম সাইডবারে Feature Catalog (Modules) ব্যবহার করুন, তারপর টেন্যান্টে মডিউল অ্যাসাইন করুন।',
      },
    },
  ],
};

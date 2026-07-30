import type { ModuleGuide } from '../../types';

export const investorPortalGuide: ModuleGuide = {
  id: 'investor_portal',
  title: { en: 'Investor Portal', bn: 'ইনভেস্টর পোর্টাল' },
  caption: {
    en: 'Portfolio, allocations, and profit',
    bn: 'পোর্টফোলিও, অ্যালোকেশন এবং লাভ',
  },
  icon: 'ph ph-piggy-bank',
  scopes: ['investor'],
  audiences: ['investor'],
  routeMatchers: [
    '/investor/portfolio',
    '/investor/allocations',
    '/investor/profit',
    '/investor/activity',
  ],
  overview: {
    en: 'The investor portal is read-only. Review portfolio balances, shipment allocations, profit status, and activity history.',
    bn: 'ইনভেস্টর পোর্টাল শুধুমাত্র পঠনযোগ্য। পোর্টফোলিও ব্যালেন্স, শিপমেন্ট অ্যালোকেশন, লাভের স্ট্যাটাস এবং কার্যক্রমের ইতিহাস পর্যালোচনা করুন।',
  },
  workflows: [
    {
      id: 'review-portfolio',
      title: { en: 'Review your portfolio', bn: 'আপনার পোর্টফোলিও পর্যালোচনা করুন' },
      steps: [
        {
          en: 'Open Portfolio Dashboard for balances and overview.',
          bn: 'ব্যালেন্স ও ওভারভিউয়ের জন্য Portfolio Dashboard খুলুন।',
        },
        {
          en: 'Check Capital Deployment for shipment allocations.',
          bn: 'শিপমেন্ট অ্যালোকেশনের জন্য Capital Deployment দেখুন।',
        },
        {
          en: 'Open Profit Report for earnings status.',
          bn: 'আয়ের স্ট্যাটাসের জন্য Profit Report খুলুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Allocation', bn: 'অ্যালোকেশন' },
      definition: {
        en: 'How your capital is assigned across shipments or pools.',
        bn: 'আপনার মূলধন শিপমেন্ট বা পুলে কীভাবে বরাদ্দ করা হয়।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Can I request a withdrawal here?',
        bn: 'এখান থেকে কি উত্তোলনের অনুরোধ করা যায়?',
      },
      answer: {
        en: 'Not in this portal version. Contact your administrator for withdrawal handling.',
        bn: 'এই পোর্টাল সংস্করণে নয়। উত্তোলনের জন্য আপনার অ্যাডমিনিস্ট্রেটরের সাথে যোগাযোগ করুন।',
      },
    },
  ],
};

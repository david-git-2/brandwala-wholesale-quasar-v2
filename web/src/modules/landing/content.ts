export const SIGN_IN_PATH = '/app/login';
export const HELP_PATH = '/help';
export const CONTACT_HREF = 'TODO_CONTACT_LINK';

export const landingSeo = {
  title: 'TradeFlow BD — Shipments, warehouse, billing and shop in one system',
  description:
    'TradeFlow BD tracks inbound shipments, warehouse stock, wholesale bills, shop and dropship, then records payments in a cashbook.',
};

export const landingCopy = {
  brand: 'TradeFlow BD',
  header: {
    howItWorks: 'How it works',
    help: 'Help',
    signIn: 'Sign in',
  },
  hero: {
    eyebrow: 'Operations for wholesale and import businesses',
    h1: 'From shipment to cash, in one system.',
    subhead: [
      'Track inbound shipments and landed cost. Hold stock in the warehouse.',
      'Sell with bills, a shop and dropship. Record every payment in the cashbook.',
    ],
    primaryCta: 'Sign in',
    requestCta: 'Request access',
    accessNote: 'Access is set up by your company admin. No public sign-up.',
  },
  flow: {
    h2: 'One path, from supplier to cashbook.',
    helpHint: 'How each step works is in Help.',
    steps: [
      {
        id: 'inbound',
        title: 'Inbound',
        body: 'Draft, in transit, receive. Landed cost per line.',
      },
      {
        id: 'warehouse',
        title: 'Warehouse',
        body: 'Global stock, bins, stock movements, delivery paper.',
      },
      {
        id: 'sell',
        title: 'Sell',
        body: 'Wholesale bills, online shop, dropship.',
      },
      {
        id: 'money',
        title: 'Money',
        body: 'Bills, payments, cashbook.',
      },
      {
        id: 'report',
        title: 'Report',
        body: 'Sales, cash, COD and treasury views.',
      },
    ],
  },
  who: {
    h2: 'Staff, buyers and capital partners.',
    items: [
      {
        title: 'Your staff',
        body: 'Admins, staff and viewers work in the app: stock, orders, finance, customers, shop setup.',
      },
      {
        title: 'Your buyers',
        body: 'Buyers and resellers use the shop: catalog, cart, orders, dropship.',
      },
      {
        title: 'Your capital partners',
        body: 'Investors get a read-only statement view.',
      },
    ],
  },
  cta: {
    h2: 'Bring your shipments, stock and cash into one place.',
    signIn: 'Sign in',
    request: 'Request access',
    accessNote: 'Access is set up by your company admin. No public sign-up.',
    helpHint: 'Guides for shipments, stock, shop and cash are in Help.',
  },
  footer: {
    help: 'Help',
    signIn: 'Sign in',
    copyright: `© ${new Date().getFullYear()} TradeFlow BD`,
  },
  previewCaption: 'Illustrative sample. Not live data.',
} as const;

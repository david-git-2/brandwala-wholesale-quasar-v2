import type { ModuleGuide } from '../types';

/**
 * Stub guides for Help Center scaffolding.
 * Full copy is added later via docs/OPTIMIZE_HELP_CENTER.md + attached pages.
 */
export const MODULE_GUIDE_REGISTRY: readonly ModuleGuide[] = [
  {
    id: 'getting_started',
    title: 'Getting Started',
    caption: 'Find help for the screen you are on',
    icon: 'ph ph-compass',
    scopes: ['platform', 'app', 'shop', 'investor'],
    audiences: ['superadmin', 'admin', 'staff', 'viewer', 'merchant', 'investor'],
    routeMatchers: ['/help'],
    overview:
      'Use the ? button in the header for a guide about the current page, or open Help Center to browse all guides available to your role.',
    workflows: [
      {
        id: 'open-guide',
        title: 'Open a module guide',
        steps: [
          'Click the ? icon in the top bar.',
          'Read Overview, Workflows, Key Terms, or FAQs.',
          'Open Help Center from the drawer if you need to search other topics.',
        ],
      },
    ],
    terms: [
      {
        term: 'Module Guide',
        definition: 'Short help for the area of the product you are using right now.',
      },
      {
        term: 'Help Center',
        definition: 'Searchable list of all guides you are allowed to see.',
      },
    ],
    faqs: [
      {
        question: 'Why do I see fewer guides than a coworker?',
        answer:
          'Guides are filtered by your role. Staff may see operations help that merchants or investors do not.',
      },
    ],
  },
  {
    id: 'platform_admin',
    title: 'Platform Admin',
    caption: 'Tenants, modules, and platform controls',
    icon: 'ph ph-shield',
    scopes: ['platform'],
    audiences: ['superadmin'],
    routeMatchers: ['/platform/tenants', '/platform/modules', '/platform/superadmins'],
    overview:
      'Platform Admin covers tenant provisioning, feature catalog activation, and superadmin access. Content will expand as guides are added.',
    workflows: [
      {
        id: 'open-tenants',
        title: 'Open tenants',
        steps: [
          'From the sidebar, open Tenants.',
          'Select a business to review status and access.',
        ],
      },
    ],
    terms: [
      {
        term: 'Feature Catalog',
        definition: 'Controls which product modules a tenant can use.',
      },
    ],
    faqs: [
      {
        question: 'Where do I turn a module on for a tenant?',
        answer: 'Use Feature Catalog (Modules) in the platform sidebar, then assign modules to the tenant.',
      },
    ],
  },
  {
    id: 'shop_categories',
    title: 'Shop Categories',
    caption: 'Organize tenant products into storefront categories',
    icon: 'ph ph-squares-four',
    scopes: ['app'],
    audiences: ['admin', 'staff'],
    routeMatchers: ['/app/shop/categories'],
    overview:
      'Shop Categories allow tenant administrators and staff to categorize items for display across storefronts, manage URL slugs, set visual category icons, and toggle active visibility.',
    workflows: [
      {
        id: 'create-category',
        title: 'Create a new shop category',
        steps: [
          'Click the "+ Add Category" button in the top header.',
          'Enter the category name (the URL slug will auto-generate).',
          'Select a descriptive icon and optional category description.',
          'Ensure "Active Category" toggle is enabled, then click "Create Category".',
        ],
      },
      {
        id: 'edit-category',
        title: 'Edit or disable an existing category',
        steps: [
          'Locate the category using the search toolbar.',
          'Click the pencil (Edit) icon on the category row or card.',
          'Update the category details, icon, or toggle status to inactive.',
          'Click "Save Changes" to apply updates.',
        ],
      },
      {
        id: 'delete-category',
        title: 'Delete a shop category',
        steps: [
          'Find the category you wish to remove.',
          'Click the trash (Delete) icon on the row or card.',
          'Confirm deletion in the pop-up modal dialog.',
        ],
      },
    ],
    terms: [
      {
        term: 'Slug',
        definition: 'A URL-friendly identifier used in storefront navigation links.',
      },
      {
        term: 'Active Status',
        definition: 'Controls whether a category and its grouped items are visible on public customer storefronts.',
      },
      {
        term: 'Category Icon',
        definition: 'Phosphor visual icon associated with the category on navigation menus.',
      },
    ],
    faqs: [
      {
        question: 'What happens when a category is toggled to Inactive?',
        answer: 'Inactive categories remain saved in the system but are hidden from customer storefront navigation.',
      },
      {
        question: 'Can I change a category slug after creating it?',
        answer: 'Yes, edit the category and update the slug input manually before saving.',
      },
    ],
  },
  {
    id: 'shop_order_staff',
    title: 'Shop & Orders (Staff)',
    caption: 'Process orders, dropship, and settlements',
    icon: 'ph ph-storefront',
    scopes: ['app'],
    audiences: ['admin', 'staff', 'viewer'],
    routeMatchers: [
      '/app/shop/dropship',
      '/app/shop/orders',
      '/app/shop/fulfillment',
      '/app/shop/shops',
    ],
    overview:
      'Staff use Shop & Orders to process dropship consignments, confirm costing, and settle courier remittances. Detailed page guides will be added per screen.',
    workflows: [
      {
        id: 'open-dropship-desk',
        title: 'Open the Dropship Desk',
        steps: [
          'Go to Shop → Dropship in the sidebar.',
          'Open an order to assign courier and advance status.',
          'Use Finance Hub for costing and remittance when the order is delivered.',
        ],
      },
    ],
    terms: [
      {
        term: 'Finance Hub',
        definition: 'The desk where delivered costing, courier remittance, and payouts are handled.',
      },
      {
        term: 'Remittance',
        definition: 'Recording cash the courier deposited for delivered COD orders.',
      },
    ],
    faqs: [
      {
        question: 'Why can I not remittance an order yet?',
        answer:
          'Usually delivered costing must be confirmed first. Open the order or Finance Hub and complete costing, then try remittance again.',
      },
    ],
  },
  {
    id: 'shop_order_merchant',
    title: 'Shop & Orders (Merchant)',
    caption: 'Place orders and track deliveries',
    icon: 'ph ph-shopping-bag',
    scopes: ['shop'],
    audiences: ['merchant'],
    routeMatchers: ['/shop/browse', '/shop/orders', '/shop/cart', '/shop/checkout'],
    overview:
      'As a merchant you browse the catalog, set recipient selling prices, checkout to a recipient, and track order status. Money details appear on your wallet page when enabled.',
    workflows: [
      {
        id: 'place-order',
        title: 'Place a dropship order',
        steps: [
          'Browse the shop catalog and add items to cart.',
          'Set the recipient selling price where allowed.',
          'Enter recipient shipping details and submit the order.',
          'Track progress under Orders.',
        ],
      },
    ],
    terms: [
      {
        term: 'Selling price',
        definition: 'The amount your recipient pays (COD). Your profit is selling price minus wholesale cost.',
      },
    ],
    faqs: [
      {
        question: 'Why can I not set a price below a certain amount?',
        answer: 'The shop enforces a minimum dropship price (floor) set by the supplier.',
      },
    ],
  },
  {
    id: 'universal_wallet',
    title: 'Universal Wallet',
    caption: 'Balances, ledgers, and payouts',
    icon: 'ph ph-wallet',
    scopes: ['app'],
    audiences: ['admin', 'staff', 'viewer'],
    routeMatchers: ['/app/wallet'],
    overview:
      'Universal Wallet shows balances and ledger activity for tenants, merchants, couriers, and other parties. Use it to review money movement after shop settlements.',
    workflows: [
      {
        id: 'review-balance',
        title: 'Review a balance',
        steps: [
          'Open Universal Wallet from the sidebar.',
          'Select the party type and profile you need.',
          'Scan recent ledger lines for credits and deductions.',
        ],
      },
    ],
    terms: [
      {
        term: 'Pending balance',
        definition: 'Profit or credit recorded but not yet paid out.',
      },
    ],
    faqs: [
      {
        question: 'Why does a balance look different from an order screen?',
        answer:
          'Order screens show ops status. Wallet reflects confirmed money events after costing, remittance, or payout steps.',
      },
    ],
  },
  {
    id: 'investor_portal',
    title: 'Investor Portal',
    caption: 'Portfolio, allocations, and profit',
    icon: 'ph ph-piggy-bank',
    scopes: ['investor'],
    audiences: ['investor'],
    routeMatchers: [
      '/investor/portfolio',
      '/investor/allocations',
      '/investor/profit',
      '/investor/activity',
    ],
    overview:
      'The investor portal is read-only. Review portfolio balances, shipment allocations, profit status, and activity history.',
    workflows: [
      {
        id: 'review-portfolio',
        title: 'Review your portfolio',
        steps: [
          'Open Portfolio Dashboard for balances and overview.',
          'Check Capital Deployment for shipment allocations.',
          'Open Profit Report for earnings status.',
        ],
      },
    ],
    terms: [
      {
        term: 'Allocation',
        definition: 'How your capital is assigned across shipments or pools.',
      },
    ],
    faqs: [
      {
        question: 'Can I request a withdrawal here?',
        answer: 'Not in this portal version. Contact your administrator for withdrawal handling.',
      },
    ],
  },
];

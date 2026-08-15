import type { ModuleGuide } from '../../types';

export const universalWalletGuide: ModuleGuide = {
  id: 'universal_wallet',
  title: { en: 'Universal Wallet & Pocket Ledger', bn: 'ইউনিভার্সাল ওয়ালেট এবং পকেট লেজার' },
  caption: {
    en: 'Understand your 3 money pockets, balances, and transaction history without accounting jargon.',
    bn: 'অ্যাকাউন্টিং শব্দজালাল ছাড়াই আপনার ৩টি মানি পকেট, ব্যালেন্স এবং লেনদেনের ইতিহাস সহজে বুঝুন।',
  },
  icon: 'ph ph-wallet',
  scopes: ['app'],
  audiences: ['admin', 'staff', 'viewer', 'merchant'],
  routeMatchers: ['/app/wallet'],
  overview: {
    en: 'Universal Wallet manages your money just like a personal bank passbook or digital wallet (like bKash/Nagad). Money is organized into 3 simple pockets: Available Cash, In Transit (Pending Delivery), and Security Hold (Locked).',
    bn: 'ইউনিভার্সাল ওয়ালেট আপনার ব্যাংক পাসবুক বা ডিজিটাল ওয়ালেটের (যেমন বিকাশ/নগদ) মতো অর্থ পরিচালনা করে। টাকা ৩টি সহজ পকেটে রাখা হয়: এভেইলেবল ক্যাশ, ইন ট্রানজিট (পেন্ডিং) এবং সিকিউরিটি হোল্ড (লকড)।',
  },
  workflows: [
    {
      id: 'how-money-moves',
      title: { en: 'How money moves from customer order to bank payout', bn: 'অর্ডার থেকে ব্যাংক পেআউটে অর্থ যেভাবে স্থানান্তরিত হয়' },
      steps: [
        {
          en: '1. Order Shipped: Profit margin or order money enters "In Transit (Pending)" while the parcel is on the delivery truck.',
          bn: '১. অর্ডার পাঠানো হলো: পার্সেলটি ডেলিভারি ট্রাকে থাকার সময় প্রফিট মার্জিন বা টাকা "ইন ট্রানজিট (পেন্ডিং)" পকেটে যুক্ত হয়।',
        },
        {
          en: '2. Delivery Completed & Remitted: When the courier driver collects cash and deposits it, your funds shift into "Available Cash".',
          bn: '২. ডেলিভারি সম্পন্ন ও ক্যাশ জমা: কুরিয়ার নগদ টাকা সংগ্রহ ও জমা দিলে আপনার অর্থ "এভেইলেবল ক্যাশ" পকেটে স্থানান্তরিত হয়।',
        },
        {
          en: '3. Bank Payout: Click "Request Payout" to transfer your Available Cash directly into your bank account.',
          bn: '৩. ব্যাংক পেআউট: আপনার এভেইলেবল ক্যাশ ব্যাংক অ্যাকাউন্টে পাঠাতে "রিকোয়েস্ট পেআউট" এ ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'switch-party-wallet',
      title: { en: 'Viewing different party wallets (Admins)', bn: 'বিভিন্ন পক্ষের ওয়ালেট দেখা (অ্যাডমিনদের জন্য)' },
      steps: [
        {
          en: '1. On Wallets, pick whose money (Our company, Customers, Suppliers, Cargo, Couriers, Investors).',
          bn: '১. ওয়ালেট পেজে কার টাকা দেখতে চান বেছে নিন (আওয়ার কোম্পানি, কাস্টমারস, সাপ্লায়ারস, কার্গো, কুরিয়ারস, ইনভেস্টরস)।',
        },
        {
          en: '2. Pick a name. Company skips this step.',
          bn: '২. একটি নাম বেছে নিন। কোম্পানি ওয়ালেটের ক্ষেত্রে এই ধাপের প্রয়োজন নেই।',
        },
        {
          en: '3. Cargo = inbound freight. Couriers = last-mile COD.',
          bn: '৩. কার্গো = ইনবাউন্ড ফ্রেইট agent। কুরিয়ারস = লাস্ট-মাইল COD।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: '+ Money In (Credit)', bn: '+ মানি ইন (ক্রেডিট)' },
      definition: {
        en: 'Money added to your wallet (e.g., earnings from completed orders, customer deposits, or adjustments). Increases your wallet balance.',
        bn: 'আপনার ওয়ালেটে যোগ হওয়া অর্থ (যেমন: অর্ডারের প্রফিট, পেমেন্ট জমা বা এডজাস্টমেন্ট)। এটি ওয়ালেট ব্যালেন্স বাড়ায়।',
      },
    },
    {
      term: { en: '- Money Out (Debit)', bn: '- মানি আউট (ডেবিট)' },
      definition: {
        en: 'Money paid or withdrawn from your wallet (e.g., bank payouts, delivery fees, or refunds). Reduces your wallet balance.',
        bn: 'আপনার ওয়ালেট থেকে তোলা বা দেওয়া অর্থ (যেমন: ব্যাংক পেআউট, ডেলিভারি ফি বা রিফান্ড)। এটি ওয়ালেট ব্যালেন্স কমায়।',
      },
    },
    {
      term: { en: 'Available Cash (Pocket 1)', bn: 'এভেইলেবল ক্যাশ (পকেট ১)' },
      definition: {
        en: 'Ready-to-use liquid money that you can cash out to your bank account right now.',
        bn: 'অবিলম্বে ব্যাংক অ্যাকাউন্টে ক্যাশ আউট বা তোলার জন্য প্রস্তুত নগদ অর্থ।',
      },
    },
    {
      term: { en: 'In Transit / Pending (Pocket 2)', bn: 'ইন ট্রানজিট / পেন্ডিং (পকেট ২)' },
      definition: {
        en: 'Money currently out for delivery with courier drivers. Moves to Available Cash once cash is collected.',
        bn: 'কুরিয়ার চালকের মাধ্যমে ডেলিভারিতে থাকা অর্থ। ডেলিভারি সম্পন্ন ও ক্যাশ জমা হলে এটি এভেইলেবল ক্যাশে চলে যায়।',
      },
    },
    {
      term: { en: 'Security Hold / Locked (Pocket 3)', bn: 'সিকিউরিটি হোল্ড / লকড (পকেট ৩)' },
      definition: {
        en: 'Money held temporarily in reserve for return claims, customer disputes, or safety collateral.',
        bn: 'রিটার্ন দাবি বা নিরাপত্তার জন্য সাময়িকভাবে রিজার্ভ রাখা অর্থ।',
      },
    },
    {
      term: { en: 'Wallet Balance After', bn: 'লেনদেন পরবর্তী ওয়ালেট ব্যালেন্স' },
      definition: {
        en: 'The exact cash remaining in your wallet pocket immediately after that specific transaction occurred.',
        bn: 'যেকোনো নির্দিষ্ট লেনদেনের পরপরই আপনার ওয়ালেট পকেটে থাকা অবশিষ্ট নগদ টাকা।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'What is the difference between "+ Money In" and "- Money Out"?',
        bn: '"+ মানি ইন" এবং "- মানি আউট" এর মধ্যে পার্থক্য কী?',
      },
      answer: {
        en: 'Green "+ Money In" means money entered your pocket (like getting paid). Red "- Money Out" means money left your pocket (like withdrawing cash to your bank or paying a fee).',
        bn: 'সবুজ "+ মানি ইন" মানে আপনার পকেটে টাকা ঢুকেছে। লাল "- মানি আউট" মানে পকেট থেকে টাকা বের হয়েছে (যেমন ব্যাংকে উইথড্র করা বা ফি দেয়া)।',
      },
    },
    {
      question: {
        en: 'Why is my money in "In Transit" instead of "Available Cash"?',
        bn: 'কেন আমার টাকা "এভেইলেবল ক্যাশ"-এ না থেকে "ইন ট্রানজিট"-এ আছে?',
      },
      answer: {
        en: 'Funds stay in "In Transit" while the courier driver is carrying the parcel. As soon as the courier deposits the cash with the platform, it moves into your "Available Cash".',
        bn: 'কুরিয়ার ড্রাইভারের কাছে পার্সেল থাকা অবস্থায় টাকা "ইন ট্রানজিট"-এ থাকে। কুরিয়ার নগদ টাকা প্ল্যাটফর্মে জমা দেওয়া মাত্রই তা "এভেইলেবল ক্যাশ"-এ চলে যায়।',
      },
    },
    {
      question: {
        en: 'How do I cash out my money to my bank account?',
        bn: 'আমি কীভাবে ব্যাংক অ্যাকাউন্টে টাকা তুলব (ক্যাশ আউট করব)?',
      },
      answer: {
        en: 'Check your "Available Cash" balance, click "Request Payout", enter the amount, and submit. The funds will be transferred directly to your registered bank account.',
        bn: 'আপনার "এভেইলেবল ক্যাশ" ব্যালেন্স দেখুন, "রিকোয়েস্ট পেআউট" এ ক্লিক করুন, পরিমাণ লিখুন এবং সাবমিট করুন। টাকা সরাসরি ব্যাংকে চলে যাবে।',
      },
    },
    {
      question: {
        en: 'What is Accountant View?',
        bn: 'একাউন্টেন্ট ভিউ কী?',
      },
      answer: {
        en: 'Simplified View shows clear balance cards and human-readable activity timeline. Accountant View is designed for professional accountants to inspect raw ledger journals.',
        bn: 'সিম্পলিফাইড ভিউ বড় ব্যালেন্স কার্ড এবং সাধারণ মানুষের পড়ার মতো কাজের টাইমলাইন দেখায়। একাউন্টেন্ট ভিউ প্রফেশনাল একাউন্টেন্টদের জন্য র লেজার জার্নাল দেখায়।',
      },
    },
  ],
};


import { defineStore } from 'pinia';
import { ref } from 'vue';

export interface CourierService {
  id: number;
  name: string;
  code: string;
  is_active: boolean;
  cod_mode: 'flat' | 'percentage';
  cod_rate: number;
  notes: string;
  return_fee_mode: 'flat' | 'percentage';
  return_fee_amount: number;
  inside_dhaka_fee: number;
  outside_dhaka_fee: number;
  inside_dhaka_return_fee: number;
  outside_dhaka_return_fee: number;
  max_attempts: number;
  hub_hold_days: number;
  allow_open_box: boolean;
}

export interface Consignment {
  id: number;
  order_id: number;
  order_no: string;
  middleman_name: string;
  recipient_name: string;
  recipient_phone: string;
  secondary_phone?: string;
  shipping_address: string;
  district: string;
  thana: string;
  courier_id: number | null;
  courier_name: string | null;
  awb_number: string | null;
  tracking_url: string | null;
  cod_amount: number;
  parcel_weight_kg: number;
  sender_name: string;
  sender_phone: string;
  sender_address: string;
  allow_open_box: boolean;
  driver_notes: string;
  status: 'processing' | 'ready_for_pickup' | 'shipped' | 'delivered' | 'returned';
  dual_invoice_created: boolean;
  created_at: string;
}

export interface LedgerEntry {
  id: number;
  order_id: number;
  order_no: string;
  type: 'credit_profit' | 'return_fee_uninvoiced' | 'clawback';
  amount: number;
  balance: number;
  created_at: string;
  remittance_batch_id?: string;
  payout_settled: boolean;
}

export const useDropshipDummyStore = defineStore('dropshipDummy', () => {
  const couriers = ref<CourierService[]>([
    {
      id: 1,
      name: 'Steadfast Courier',
      code: 'STEADFAST',
      is_active: true,
      cod_mode: 'percentage',
      cod_rate: 1.0,
      notes: 'Standard nationwide delivery',
      return_fee_mode: 'flat',
      return_fee_amount: 50,
      inside_dhaka_fee: 60,
      outside_dhaka_fee: 120,
      inside_dhaka_return_fee: 30,
      outside_dhaka_return_fee: 60,
      max_attempts: 2,
      hub_hold_days: 3,
      allow_open_box: true,
    },
    {
      id: 2,
      name: 'Pathao Courier',
      code: 'PATHAO',
      is_active: true,
      cod_mode: 'percentage',
      cod_rate: 0.5,
      notes: 'Fast urban delivery',
      return_fee_mode: 'flat',
      return_fee_amount: 60,
      inside_dhaka_fee: 70,
      outside_dhaka_fee: 130,
      inside_dhaka_return_fee: 35,
      outside_dhaka_return_fee: 65,
      max_attempts: 3,
      hub_hold_days: 2,
      allow_open_box: false,
    },
    {
      id: 3,
      name: 'REDX Logistics',
      code: 'REDX',
      is_active: true,
      cod_mode: 'flat',
      cod_rate: 10,
      notes: 'Wide coverage ecommerce courier',
      return_fee_mode: 'flat',
      return_fee_amount: 40,
      inside_dhaka_fee: 65,
      outside_dhaka_fee: 125,
      inside_dhaka_return_fee: 30,
      outside_dhaka_return_fee: 60,
      max_attempts: 2,
      hub_hold_days: 5,
      allow_open_box: true,
    },
  ]);

  const consignments = ref<Consignment[]>([
    {
      id: 101,
      order_id: 1001,
      order_no: 'ORD-DS-1001',
      middleman_name: 'Fashion Retailer BD',
      recipient_name: 'Tanvir Hossain',
      recipient_phone: '01711000111',
      secondary_phone: '01811000222',
      shipping_address: 'House 12, Road 4, Sector 3, Uttara',
      district: 'Dhaka',
      thana: 'Uttara',
      courier_id: 1,
      courier_name: 'Steadfast Courier',
      awb_number: 'ST-987654',
      tracking_url: 'https://steadfast.com.bd/t/ST-987654',
      cod_amount: 2500,
      parcel_weight_kg: 1.5,
      sender_name: 'Brandwala Hub',
      sender_phone: '01900000000',
      sender_address: 'Tejgaon I/A, Dhaka',
      allow_open_box: true,
      driver_notes: 'Call before delivery',
      status: 'shipped',
      dual_invoice_created: false,
      created_at: new Date().toISOString(),
    },
    {
      id: 102,
      order_id: 1002,
      order_no: 'ORD-DS-1002',
      middleman_name: 'Style Express',
      recipient_name: 'Nusrat Jahan',
      recipient_phone: '01922334455',
      shipping_address: 'GEC Circle, Chittagong',
      district: 'Chittagong',
      thana: 'Panchlaish',
      courier_id: 2,
      courier_name: 'Pathao Courier',
      awb_number: 'PTH-123456',
      tracking_url: 'https://pathao.com/t/PTH-123456',
      cod_amount: 4200,
      parcel_weight_kg: 2.0,
      sender_name: 'Brandwala Hub',
      sender_phone: '01900000000',
      sender_address: 'Tejgaon I/A, Dhaka',
      allow_open_box: false,
      driver_notes: 'Deliver afternoon only',
      status: 'delivered',
      dual_invoice_created: true,
      created_at: new Date().toISOString(),
    },
  ]);

  const ledgerEntries = ref<LedgerEntry[]>([
    {
      id: 501,
      order_id: 1002,
      order_no: 'ORD-DS-1002',
      type: 'credit_profit',
      amount: 650,
      balance: 650,
      created_at: new Date().toISOString(),
      remittance_batch_id: 'REMIT-2026-07-001',
      payout_settled: false,
    },
  ]);

  const addCourier = (courier: Omit<CourierService, 'id'>) => {
    const nextId = Math.max(...couriers.value.map((c) => c.id), 0) + 1;
    couriers.value.push({ ...courier, id: nextId });
  };

  const updateCourier = (id: number, updated: Partial<CourierService>) => {
    const idx = couriers.value.findIndex((c) => c.id === id);
    const existing = couriers.value[idx];
    if (idx !== -1 && existing) {
      couriers.value[idx] = { ...existing, ...updated };
    }
  };

  const updateConsignment = (id: number, updated: Partial<Consignment>) => {
    const idx = consignments.value.findIndex((c) => c.id === id);
    const existing = consignments.value[idx];
    if (idx !== -1 && existing) {
      consignments.value[idx] = { ...existing, ...updated };
    }
  };

  const addLedgerEntry = (entry: Omit<LedgerEntry, 'id' | 'balance' | 'created_at'>) => {
    const nextId = Math.max(...ledgerEntries.value.map((l) => l.id), 0) + 1;
    const lastEntry = ledgerEntries.value[ledgerEntries.value.length - 1];
    const lastBalance = lastEntry ? lastEntry.balance : 0;
    const newBalance = lastBalance + (entry.type === 'credit_profit' ? entry.amount : -entry.amount);
    ledgerEntries.value.push({
      ...entry,
      id: nextId,
      balance: newBalance,
      created_at: new Date().toISOString(),
    });
  };

  return {
    couriers,
    consignments,
    ledgerEntries,
    addCourier,
    updateCourier,
    updateConsignment,
    addLedgerEntry,
  };
});

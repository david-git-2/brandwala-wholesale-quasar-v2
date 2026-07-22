import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import {
  thriftStockRepository,
  type ThriftStockPricingInput,
} from '../repositories/thriftStockRepository';
import type {
  ThriftStock,
  ThriftSection,
  ThriftCondition,
  ThriftStockType,
} from '../types';

export interface CreateStockInput {
  tenantId: number;
  shipmentId: number;
  name: string;
  brandName: string;
  categoryId: number;
  typeId: number;
  section: string;
  color: string;
  size: string;
  condition: string;
  barcode: string;
  stockType: string;
  quantity: number;
  boxId?: number | undefined;
  productWeight?: number | undefined;
  extraWeight?: number | undefined;
  note: string;
  userEmail: string;
  pricing: ThriftStockPricingInput;
  imageUrl?: string | undefined;
  shelfId?: number | null | undefined;
  originUnitPrice?: number | undefined;
  extraOriginUnitPrice?: number | undefined;
  additionalChargesCost?: number | undefined;
}

export interface UpdateStockInput {
  id: number;
  stock: Partial<ThriftStock>;
  pricing: ThriftStockPricingInput;
  imageUrl?: string | null | undefined;
  driveFileId?: string | null | undefined;
}

export interface AttachStockImageInput {
  id: number;
  imageUrl: string;
  insertedBy: string;
  driveFileId?: string;
}

export interface UpdateStockStatusInput {
  id: number;
  status: string;
}

export function useCreateStockMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: CreateStockInput) =>
      thriftStockRepository.createStock(
        {
          tenant_id: input.tenantId,
          shipment_id: input.shipmentId,
          name: input.name,
          brand_name: input.brandName || '',
          category_id: input.categoryId,
          type_id: input.typeId,
          section: input.section as ThriftSection,
          shelf_id: input.shelfId ?? null,
          color: input.color,
          size: input.size,
          condition: input.condition as ThriftCondition,
          barcode: input.barcode,
          stock_type: input.stockType as ThriftStockType,
          quantity: input.quantity,
          box_id: input.boxId || undefined,
          product_weight: input.productWeight || undefined,
          extra_weight: input.extraWeight || undefined,
          origin_unit_price: input.originUnitPrice ?? undefined,
          extra_origin_unit_price: input.extraOriginUnitPrice ?? undefined,
          additional_charges_cost: input.additionalChargesCost ?? undefined,
          status: 'AVAILABLE',
          note: input.note || '',
          inserted_by: input.userEmail,
        },
        input.pricing,
        input.imageUrl,
      ),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thrift', 'stocks'] });
    },
  });
}

export function useUpdateStockMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, stock, pricing, imageUrl, driveFileId }: UpdateStockInput) =>
      thriftStockRepository.updateStock(id, stock, pricing, imageUrl, driveFileId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thrift', 'stocks'] });
    },
  });
}

export function useAttachStockImageMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, imageUrl, insertedBy, driveFileId }: AttachStockImageInput) =>
      thriftStockRepository.upsertPrimaryStockImage(id, imageUrl, insertedBy, driveFileId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thrift', 'stocks'] });
    },
  });
}

export function useUpdateStockStatusMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, status }: UpdateStockStatusInput) =>
      thriftStockRepository.updateStockStatus(id, status),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thrift', 'stocks'] });
    },
  });
}

export function useDeleteStockMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => thriftStockRepository.deleteStock(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thrift', 'stocks'] });
    },
  });
}

export function useDeleteStocksMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (ids: number[]) => thriftStockRepository.deleteStocks(ids),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['thrift', 'stocks'] });
    },
  });
}

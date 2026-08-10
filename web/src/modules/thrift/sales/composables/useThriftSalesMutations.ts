import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  thriftSalesRepository,
  type CreateSalesInvoiceInput,
  type RecordCodRemittanceInput,
  type ThriftSalesRevertReason,
} from '../repositories/thriftSalesRepository';

export function useCreateThriftSalesInvoiceMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: CreateSalesInvoiceInput) =>
      thriftSalesRepository.createSalesInvoice(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['thrift', 'sales'] });
      void queryClient.invalidateQueries({ queryKey: ['thrift', 'stocks'] });
    },
  });
}

export function useRevertThriftSalesInvoiceMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: {
      tenantId: number;
      invoiceId: number;
      reason: ThriftSalesRevertReason;
      revertedBy: string;
      notes?: string | undefined;
      force?: boolean | undefined;
    }) => thriftSalesRepository.revertSalesInvoice(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['thrift', 'sales'] });
      void queryClient.invalidateQueries({ queryKey: ['thrift', 'stocks'] });
      void queryClient.invalidateQueries({ queryKey: ['thrift', 'ledger'] });
    },
  });
}

export function useRecordThriftCodRemittanceMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: RecordCodRemittanceInput) =>
      thriftSalesRepository.recordCodRemittance(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['thrift', 'sales'] });
    },
  });
}

export function useUpdateThriftDeliveryStatusMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: {
      tenantId: number;
      invoiceId: number;
      deliveryStatus: 'PENDING' | 'READY' | 'IN_TRANSIT' | 'DELIVERED';
      actor: string;
    }) => thriftSalesRepository.updateDeliveryStatus(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['thrift', 'sales'] });
    },
  });
}

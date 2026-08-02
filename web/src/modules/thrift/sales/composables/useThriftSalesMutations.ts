import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { thriftSalesRepository, type CreateSalesInvoiceInput } from '../repositories/thriftSalesRepository';

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

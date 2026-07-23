import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { thriftBarcodeRepository } from '../repositories/thriftBarcodeRepository';

export interface GenerateBarcodesInput {
  tenantId: number;
  quantity: number;
  insertedBy: string;
}

export function useGenerateBarcodesMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: GenerateBarcodesInput) =>
      thriftBarcodeRepository.generateBarcodes(input),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['thrift', 'barcodes'] }),
  });
}

// Alias for migration spec compliance
export const useCreateBarcodeMutation = useGenerateBarcodesMutation;

export function useMarkBarcodesPrintedMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (ids: number[]) => thriftBarcodeRepository.markBarcodesPrinted(ids),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['thrift', 'barcodes'] }),
  });
}

export function useDeleteBarcodeMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => thriftBarcodeRepository.deleteBarcode(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['thrift', 'barcodes'] }),
  });
}

export function useDeleteBarcodesMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (ids: number[]) => thriftBarcodeRepository.deleteBarcodes(ids),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['thrift', 'barcodes'] }),
  });
}

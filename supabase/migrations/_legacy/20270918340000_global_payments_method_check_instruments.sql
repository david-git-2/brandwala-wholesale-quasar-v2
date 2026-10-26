-- Header method on global_payments is denormalized from instrument
-- codes (lowercase) or 'split'. The old check only allowed cash/bank/bkash.

begin;

alter table public.global_payments drop constraint if exists payments_method_check;

alter table public.global_payments add constraint payments_method_check
  check (
    method is null
    or method = any (
      array[
        'cash',
        'bank',
        'bank_transfer',
        'mobile_banking',
        'bkash',
        'nagad',
        'other',
        'cheque',
        'rocket',
        'upay',
        'tap',
        'card_pos',
        'wire_transfer',
        'paypal',
        'stripe',
        'letter_of_credit',
        'cod',
        'split'
      ]::text[]
    )
  );

commit;

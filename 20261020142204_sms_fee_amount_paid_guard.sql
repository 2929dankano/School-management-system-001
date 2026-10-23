alter table public.fees drop constraint if exists fees_amount_paid_valid;
alter table public.fees add constraint fees_amount_paid_valid check (amount_paid >= 0 and amount_paid <= amount);

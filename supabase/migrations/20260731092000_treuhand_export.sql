-- The Treuhänder export.
--
-- The chosen invoicing model is "Ventline issues, bexio receives a handoff",
-- and this is the first and by far the most-used form of that handoff: a file
-- the shop's accountant can open. Most KMU will not connect bexio on day one,
-- and every one of them has a Treuhänder who needs the MWST recapitulation
-- regardless of what software either party runs.
--
-- **One row per invoice per rate group**, not one row per invoice. Art. 26
-- Abs. 2 lit. f requires tax to be stated per rate, an invoice may carry more
-- than one rate, and the accountant's actual job is to total each rate
-- separately. A row-per-invoice shape would force them to unpick that by hand.
--
-- The consequence, and the rule the column set is built around: **every
-- numeric column is summable**. netto/mwst/brutto describe that rate group
-- alone, never the invoice they belong to, so no figure appears twice and a
-- sum over any column is the right answer. Repeating an invoice total on each
-- of its rows would be friendlier to read and would silently double-count.
--
-- Cancelled invoices are included on purpose. The numbering is gapless by
-- design, so an accountant who sees 2026-0003 missing will ask why; a
-- cancelled row answers that question before it is asked.

create or replace function public.invoice_export(p_from date, p_to date)
returns table (
  rechnungsnummer  text,
  rechnungsdatum   date,
  faelligkeit      date,
  status           text,
  kunde            text,
  kunde_plz        text,
  kunde_ort        text,
  kunde_land       text,
  kunde_id         uuid,
  bexio_kontakt_id bigint,
  projekt          text,
  rapport          text,
  referenz_typ     text,
  referenz         text,
  waehrung         text,
  mwst_satz        numeric,
  netto            numeric,
  mwst             numeric,
  brutto           numeric,
  bezahlt_am       date,
  mwst_verfahren   text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- Raised rather than returning nothing: an empty file and "you may not see
  -- this" look identical to whoever opens it, and only one of them is worth
  -- telling someone about.
  if app.current_company_id() is null or not app.is_office() then
    raise exception 'nur das Büro kann Rechnungen exportieren'
      using errcode = 'insufficient_privilege';
  end if;

  return query
  select
    i.number_text,
    i.invoice_date,
    i.due_date,
    i.status::text,
    -- The frozen snapshot from the invoice, not a join to the live customer:
    -- the export must state who was billed on the day, and a customer who
    -- has since moved must not silently restate a filed document.
    --
    -- Cast every one. These columns are varchar(70)/varchar(16)/char(2)
    -- because SIX bounds each field, and RETURNS TABLE compares types exactly:
    -- a varchar reaching a text column raises "structure of query does not
    -- match function result type", which names neither the offending column
    -- nor the type it disagreed about.
    i.debtor_name::text,
    i.debtor_post_code::text,
    i.debtor_town::text,
    i.debtor_country::text,
    -- The live id alongside it, so a later bexio push can match a contact
    -- without re-deriving it from a name that may since have changed.
    i.customer_id,
    c.bexio_contact_id,
    p.name,
    r.number_text,
    i.reference_type::text,
    i.reference,
    i.currency::text,
    -- Rappen and basis points are how this is stored; francs and percent are
    -- how it is read. Divided as numeric, never float: an export that does
    -- not reconcile to the rappen is worse than no export.
    g.rate_bp / 100.0,
    g.net_rappen / 100.0,
    g.tax_rappen / 100.0,
    (g.net_rappen + g.tax_rappen) / 100.0,
    (timezone('Europe/Zurich', i.paid_at))::date,
    i.creditor_mwst_status::text
  from public.invoices i
  join public.invoice_tax_groups g on g.invoice_id = i.id
  join public.projects p on p.id = i.project_id
  left join public.customers c on c.id = i.customer_id
  left join public.reports r on r.id = i.report_id
  where i.company_id = app.current_company_id()
    and i.status <> 'draft'
    and i.invoice_date between p_from and p_to
  order by i.number, g.rate_bp;
end; $$;

revoke execute on function public.invoice_export(date, date) from public, anon;
grant execute on function public.invoice_export(date, date) to authenticated;

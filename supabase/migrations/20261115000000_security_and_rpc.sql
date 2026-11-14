-- ============================================================================
-- TaniTernak Desa - hardening RLS + RPC server-side
--
-- Jalankan lewat Supabase SQL Editor atau:
--   supabase db push
--
-- Prinsip:
--  * Klien hanya boleh membaca katalog publik dan data miliknya sendiri.
--  * Harga, stok, status pesanan, kuota AI, dan status Pro dihitung server.
--  * Kolom privilese (role, is_pro, pro_expires_at, daily_ai_quota_used)
--    tidak bisa diubah klien, hanya service role (Edge Function/admin).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. RLS: katalog publik (baca saja untuk anon + authenticated)
-- ---------------------------------------------------------------------------
alter table public.commodities enable row level security;
alter table public.stores enable row level security;
alter table public.products enable row level security;
alter table public.knowledge_articles enable row level security;
alter table public.article_recommended_products enable row level security;

drop policy if exists commodities_public_read on public.commodities;
create policy commodities_public_read on public.commodities
  for select to anon, authenticated using (true);

drop policy if exists stores_public_read on public.stores;
create policy stores_public_read on public.stores
  for select to anon, authenticated using (true);

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products
  for select to anon, authenticated using (is_active);

drop policy if exists articles_public_read on public.knowledge_articles;
create policy articles_public_read on public.knowledge_articles
  for select to anon, authenticated using (is_published);

drop policy if exists article_products_public_read on public.article_recommended_products;
create policy article_products_public_read on public.article_recommended_products
  for select to anon, authenticated using (true);

-- ---------------------------------------------------------------------------
-- 2. RLS: profil pengguna
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Kolom privilese dikunci: klien tidak boleh menaikkan role/Pro/kuota sendiri.
create or replace function public.guard_profile_privileges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return new;
  end if;

  new.role := old.role;
  new.is_pro := old.is_pro;
  new.pro_expires_at := old.pro_expires_at;
  new.daily_ai_quota_used := old.daily_ai_quota_used;
  new.last_quota_reset := old.last_quota_reset;
  new.id := old.id;
  return new;
end;
$$;

drop trigger if exists trg_guard_profile_privileges on public.profiles;
create trigger trg_guard_profile_privileges
  before update on public.profiles
  for each row execute function public.guard_profile_privileges();

-- ---------------------------------------------------------------------------
-- 3. RLS: data milik pengguna
-- ---------------------------------------------------------------------------
alter table public.care_schedules enable row level security;
alter table public.farm_financial_logs enable row level security;
alter table public.cart_items enable row level security;
alter table public.ai_chat_sessions enable row level security;
alter table public.ai_chat_messages enable row level security;
alter table public.market_orders enable row level security;
alter table public.market_order_items enable row level security;
alter table public.market_payments enable row level security;
alter table public.subscription_transactions enable row level security;

drop policy if exists care_schedules_own on public.care_schedules;
create policy care_schedules_own on public.care_schedules
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists farm_finance_own on public.farm_financial_logs;
create policy farm_finance_own on public.farm_financial_logs
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists cart_items_own on public.cart_items;
create policy cart_items_own on public.cart_items
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists ai_sessions_own on public.ai_chat_sessions;
create policy ai_sessions_own on public.ai_chat_sessions
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists ai_messages_own on public.ai_chat_messages;
create policy ai_messages_own on public.ai_chat_messages
  for all to authenticated
  using (
    exists (
      select 1 from public.ai_chat_sessions s
      where s.id = ai_chat_messages.session_id and s.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.ai_chat_sessions s
      where s.id = ai_chat_messages.session_id and s.user_id = auth.uid()
    )
  );

-- Pesanan dibuat HANYA lewat fungsi create_market_order (security definer),
-- jadi tidak ada policy INSERT untuk authenticated.
drop policy if exists market_orders_select_own on public.market_orders;
create policy market_orders_select_own on public.market_orders
  for select to authenticated using (buyer_id = auth.uid());

drop policy if exists market_orders_cancel_own on public.market_orders;
create policy market_orders_cancel_own on public.market_orders
  for update to authenticated
  using (buyer_id = auth.uid() and order_status in ('pending', 'menunggu'))
  with check (buyer_id = auth.uid() and order_status = 'dibatalkan');

-- Hanya pembatalan yang boleh dilakukan klien; total & status lain dijaga.
create or replace function public.guard_market_order_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return new;
  end if;

  if old.buyer_id <> auth.uid()
     or new.order_status <> 'dibatalkan'
     or old.order_status not in ('pending', 'menunggu') then
    raise exception 'ORDER_UPDATE_FORBIDDEN' using errcode = '42501';
  end if;

  new.buyer_id := old.buyer_id;
  new.store_id := old.store_id;
  new.order_number := old.order_number;
  new.grand_total := old.grand_total;
  new.created_at := old.created_at;
  return new;
end;
$$;

drop trigger if exists trg_guard_market_order_update on public.market_orders;
create trigger trg_guard_market_order_update
  before update on public.market_orders
  for each row execute function public.guard_market_order_update();

drop policy if exists market_order_items_select_own on public.market_order_items;
create policy market_order_items_select_own on public.market_order_items
  for select to authenticated
  using (
    exists (
      select 1 from public.market_orders o
      where o.id = market_order_items.order_id and o.buyer_id = auth.uid()
    )
  );

drop policy if exists market_payments_select_own on public.market_payments;
create policy market_payments_select_own on public.market_payments
  for select to authenticated
  using (
    exists (
      select 1 from public.market_orders o
      where o.id = market_payments.order_id and o.buyer_id = auth.uid()
    )
  );

drop policy if exists subscriptions_select_own on public.subscription_transactions;
create policy subscriptions_select_own on public.subscription_transactions
  for select to authenticated using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4. RPC: statistik baca artikel
-- ---------------------------------------------------------------------------
create or replace function public.increment_article_view(p_article_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.knowledge_articles
     set view_count = coalesce(view_count, 0) + 1
   where id = p_article_id and is_published = true;
end;
$$;

revoke all on function public.increment_article_view(uuid) from public;
grant execute on function public.increment_article_view(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC: kuota AI (dipanggil Edge Function dengan service role)
-- ---------------------------------------------------------------------------
create or replace function public.consume_ai_quota(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_pro boolean;
  v_expires timestamptz;
  v_used int;
  v_reset timestamptz;
  v_limit constant int := 5;
begin
  select is_pro, pro_expires_at, daily_ai_quota_used, last_quota_reset
    into v_is_pro, v_expires, v_used, v_reset
    from public.profiles
   where id = p_user_id
   for update;

  if not found then
    raise exception 'PROFILE_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_is_pro and (v_expires is null or v_expires > now()) then
    return jsonb_build_object('allowed', true, 'is_pro', true, 'remaining', null);
  end if;

  if v_reset is null or v_reset::date < current_date then
    v_used := 0;
    update public.profiles
       set daily_ai_quota_used = 0, last_quota_reset = now()
     where id = p_user_id;
  end if;

  if v_used >= v_limit then
    return jsonb_build_object('allowed', false, 'is_pro', false, 'remaining', 0);
  end if;

  update public.profiles
     set daily_ai_quota_used = coalesce(daily_ai_quota_used, 0) + 1,
         last_quota_reset = coalesce(last_quota_reset, now())
   where id = p_user_id;

  return jsonb_build_object(
    'allowed', true,
    'is_pro', false,
    'remaining', v_limit - v_used - 1
  );
end;
$$;

revoke all on function public.consume_ai_quota(uuid) from public, anon, authenticated;
grant execute on function public.consume_ai_quota(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 6. RPC: checkout aman (harga & stok dihitung server)
-- ---------------------------------------------------------------------------
create or replace function public.create_market_order(
  p_store_id uuid,
  p_items jsonb,
  p_shipping_address text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_order_id uuid;
  v_order_number text;
  v_total numeric := 0;
  v_item record;
  v_price numeric;
  v_stock int;
begin
  if v_user is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;
  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'CART_EMPTY' using errcode = '22023';
  end if;
  if p_shipping_address is null or length(btrim(p_shipping_address)) < 10 then
    raise exception 'ADDRESS_INVALID' using errcode = '22023';
  end if;

  for v_item in
    select product_id, sum(quantity)::int as quantity
      from jsonb_to_recordset(p_items) as x(product_id uuid, quantity int)
     group by product_id
  loop
    if v_item.product_id is null
       or v_item.quantity is null
       or v_item.quantity < 1
       or v_item.quantity > 1000 then
      raise exception 'QUANTITY_INVALID' using errcode = '22023';
    end if;

    select coalesce(
             case when discount_price > 0 and discount_price < price
                  then discount_price end,
             price
           ), stock
      into v_price, v_stock
      from public.products
     where id = v_item.product_id
       and store_id = p_store_id
       and is_active = true
     for update;

    if not found then
      raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0002';
    end if;
    if v_stock < v_item.quantity then
      raise exception 'STOCK_INSUFFICIENT' using errcode = 'P0001';
    end if;

    v_total := v_total + (v_price * v_item.quantity);
  end loop;

  v_order_number := 'TT-' || to_char(now(), 'YYMMDD') || '-' ||
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.market_orders (
    buyer_id, store_id, order_number, order_status, grand_total,
    shipping_address
  ) values (
    v_user, p_store_id, v_order_number, 'pending', v_total,
    btrim(p_shipping_address)
  )
  returning id into v_order_id;

  for v_item in
    select product_id, sum(quantity)::int as quantity
      from jsonb_to_recordset(p_items) as x(product_id uuid, quantity int)
     group by product_id
  loop
    insert into public.market_order_items (order_id, product_id, quantity)
    values (v_order_id, v_item.product_id, v_item.quantity);

    update public.products
       set stock = stock - v_item.quantity
     where id = v_item.product_id;
  end loop;

  delete from public.cart_items
   where user_id = v_user
     and product_id in (
       select product_id
         from jsonb_to_recordset(p_items) as x(product_id uuid, quantity int)
     );

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'grand_total', v_total
  );
end;
$$;

revoke all on function public.create_market_order(uuid, jsonb, text) from public, anon;
grant execute on function public.create_market_order(uuid, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. RPC: tagihan langganan Pro (harga ditentukan server)
-- ---------------------------------------------------------------------------
create or replace function public.request_pro_subscription(
  p_plan_days int,
  p_invoice_number text,
  p_amount numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_price numeric;
  v_invoice text;
begin
  if v_user is null then
    raise exception 'AUTH_REQUIRED' using errcode = '28000';
  end if;

  -- Harga resmi; p_amount dari klien sengaja diabaikan.
  v_price := case p_plan_days
    when 30 then 25000
    when 90 then 65000
    when 365 then 200000
    else null
  end;

  if v_price is null then
    raise exception 'PLAN_INVALID' using errcode = '22023';
  end if;

  v_invoice := coalesce(
    nullif(btrim(p_invoice_number), ''),
    'PRO-' || to_char(now(), 'YYMMDDHH24MISS')
  );

  insert into public.subscription_transactions (
    user_id, amount, payment_method, payment_status, invoice_number
  ) values (
    v_user, v_price, 'transfer', 'pending', v_invoice
  );

  return jsonb_build_object(
    'invoice_number', v_invoice,
    'amount', v_price,
    'plan_days', p_plan_days
  );
end;
$$;

revoke all on function public.request_pro_subscription(int, text, numeric)
  from public, anon;
grant execute on function public.request_pro_subscription(int, text, numeric)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Storage: foto konsultasi privat per pengguna
-- ---------------------------------------------------------------------------
update storage.buckets set public = false where id = 'consultations';

drop policy if exists consultations_insert_own on storage.objects;
create policy consultations_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'consultations'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists consultations_read_own on storage.objects;
create policy consultations_read_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'consultations'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists consultations_delete_own on storage.objects;
create policy consultations_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'consultations'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

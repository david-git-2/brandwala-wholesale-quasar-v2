begin;

-- =========================================================
-- 1. Insert 'tasks' module in the master module catalog
-- =========================================================
insert into public.modules (key, name, description, is_active)
values (
  'tasks',
  'Task Management',
  'Manage projects, modules, submodules, tasks, notes, discussions, bugs, features, and collaborate with your team.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

-- =========================================================
-- 2. Create tables
-- =========================================================

-- items
create table if not exists public.items (
  id bigserial primary key,
  tenant_id bigint references public.tenants(id) on delete cascade,
  parent_id bigint references public.items(id) on delete cascade,
  type text not null,
  title text not null,
  content text,
  status text not null default 'todo',
  priority text not null default 'medium',
  created_by_email text not null default public.current_user_email(),
  due_date timestamp with time zone,
  start_date timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  archived_at timestamp with time zone,

  constraint items_type_check check (
    type in ('project', 'module', 'submodule', 'task', 'note', 'discussion', 'bug', 'feature')
  ),
  constraint items_status_check check (
    status in ('todo', 'in_progress', 'review', 'done', 'blocked', 'archived')
  ),
  constraint items_priority_check check (
    priority in ('low', 'medium', 'high', 'urgent')
  )
);

-- item_assignees
create table if not exists public.item_assignees (
  id bigserial primary key,
  item_id bigint not null references public.items(id) on delete cascade,
  user_email text not null,
  assigned_by_email text not null default public.current_user_email(),
  created_at timestamp with time zone not null default now(),

  unique (item_id, user_email)
);

-- tags
create table if not exists public.tags (
  id bigserial primary key,
  tenant_id bigint references public.tenants(id) on delete cascade,
  name text not null,
  slug text not null,
  color text not null default '#6366f1',
  type text not null default 'general',
  created_by_email text not null default public.current_user_email(),
  created_at timestamp with time zone not null default now(),

  unique (tenant_id, slug, created_by_email)
);

-- item_tags
create table if not exists public.item_tags (
  id bigserial primary key,
  item_id bigint not null references public.items(id) on delete cascade,
  tag_id bigint not null references public.tags(id) on delete cascade,
  created_at timestamp with time zone not null default now(),

  unique (item_id, tag_id)
);

-- comments
create table if not exists public.comments (
  id bigserial primary key,
  item_id bigint not null references public.items(id) on delete cascade,
  parent_comment_id bigint references public.comments(id) on delete cascade,
  user_email text not null default public.current_user_email(),
  body text not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  deleted_at timestamp with time zone
);

-- item_permissions
create table if not exists public.item_permissions (
  id bigserial primary key,
  item_id bigint not null references public.items(id) on delete cascade,
  user_email text not null,
  role text not null,
  created_at timestamp with time zone not null default now(),

  unique (item_id, user_email),
  constraint item_permissions_role_check check (
    role in ('owner', 'manager', 'editor', 'viewer', 'commenter')
  )
);

-- activity_logs
create table if not exists public.activity_logs (
  id bigserial primary key,
  item_id bigint not null references public.items(id) on delete cascade,
  user_email text not null default public.current_user_email(),
  action text not null,
  old_value text,
  new_value text,
  created_at timestamp with time zone not null default now()
);

-- =========================================================
-- 3. Triggers for updated_at
-- =========================================================
create trigger trg_items_updated_at
  before update on public.items
  for each row
  execute function public.set_updated_at();

create trigger trg_comments_updated_at
  before update on public.comments
  for each row
  execute function public.set_updated_at();

-- =========================================================
-- 4. Indexes for performance
-- =========================================================
create index if not exists items_tenant_id_idx on public.items(tenant_id);
create index if not exists items_parent_id_idx on public.items(parent_id);
create index if not exists items_created_by_email_idx on public.items(created_by_email);
create index if not exists item_assignees_item_id_idx on public.item_assignees(item_id);
create index if not exists item_assignees_user_email_idx on public.item_assignees(user_email);
create index if not exists tags_tenant_id_idx on public.tags(tenant_id);
create index if not exists tags_created_by_email_idx on public.tags(created_by_email);
create index if not exists item_tags_item_id_idx on public.item_tags(item_id);
create index if not exists item_tags_tag_id_idx on public.item_tags(tag_id);
create index if not exists comments_item_id_idx on public.comments(item_id);
create index if not exists comments_parent_comment_id_idx on public.comments(parent_comment_id);
create index if not exists item_permissions_item_id_idx on public.item_permissions(item_id);
create index if not exists item_permissions_user_email_idx on public.item_permissions(user_email);
create index if not exists activity_logs_item_id_idx on public.activity_logs(item_id);

-- =========================================================
-- 5. Helper Functions
-- =========================================================

-- Recursive item permission resolver using emails
create or replace function public.get_effective_item_role(
  p_item_id bigint,
  p_user_email text
)
returns text
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_role text;
  v_parent_id bigint;
  v_tenant_id bigint;
  v_created_by_email text;
  v_user_role_in_tenant text;
  v_is_superadmin boolean;
  v_email text;
begin
  v_email := lower(trim(p_user_email));

  -- 1. Check if user is superadmin
  select exists (
    select 1 from public.memberships m
    where lower(trim(m.email)) = v_email
      and m.role = 'superadmin'
      and m.is_active = true
  ) into v_is_superadmin;

  if v_is_superadmin then
    return 'owner';
  end if;

  -- Get item info
  select parent_id, tenant_id, created_by_email
  into v_parent_id, v_tenant_id, v_created_by_email
  from public.items
  where id = p_item_id;

  if not found then
    return null;
  end if;

  -- 2. Check if creator
  if lower(trim(v_created_by_email)) = v_email then
    return 'owner';
  end if;

  -- 3. Check explicit permission
  select role into v_role
  from public.item_permissions
  where item_id = p_item_id and lower(trim(user_email)) = v_email;

  if v_role is not null then
    return v_role;
  end if;

  -- 4. Check recursive parent permission
  if v_parent_id is not null then
    v_role := public.get_effective_item_role(v_parent_id, v_email);
    if v_role is not null then
      return v_role;
    end if;
  end if;

  -- 5. Fallback to tenant role mapping
  if v_tenant_id is not null then
    select m.role::text into v_user_role_in_tenant
    from public.memberships m
    where lower(trim(m.email)) = v_email
      and m.tenant_id = v_tenant_id
      and m.is_active = true;

    if v_user_role_in_tenant = 'admin' then
      return 'owner';
    elsif v_user_role_in_tenant = 'staff' then
      return 'editor';
    elsif v_user_role_in_tenant = 'viewer' then
      return 'viewer';
    end if;
  end if;

  return null;
end;
$$;

-- Global tasks search cross-tenants using email
create or replace function public.global_search_tasks(
  p_query text
)
returns table(
  id bigint,
  tenant_id bigint,
  tenant_name text,
  parent_id bigint,
  type text,
  title text,
  content text,
  status text,
  priority text,
  created_by_email text,
  due_date timestamp with time zone,
  start_date timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_email text;
begin
  v_email := public.current_user_email();

  return query
  select distinct
    i.id,
    i.tenant_id,
    t.name as tenant_name,
    i.parent_id,
    i.type,
    i.title,
    i.content,
    i.status,
    i.priority,
    i.created_by_email,
    i.due_date,
    i.start_date,
    i.created_at,
    i.updated_at
  from public.items i
  left join public.tenants t on t.id = i.tenant_id
  left join public.item_tags it on it.item_id = i.id
  left join public.tags tag on tag.id = it.tag_id
  left join public.comments c on c.item_id = i.id
  where
    public.get_effective_item_role(i.id, v_email) is not null
    and (
      i.title ilike '%' || p_query || '%'
      or i.content ilike '%' || p_query || '%'
      or tag.name ilike '%' || p_query || '%'
      or c.body ilike '%' || p_query || '%'
    )
  order by i.updated_at desc
  limit 50;
end;
$$;

-- =========================================================
-- 6. Enable Row Level Security (RLS)
-- =========================================================
alter table public.items enable row level security;
alter table public.item_assignees enable row level security;
alter table public.tags enable row level security;
alter table public.item_tags enable row level security;
alter table public.comments enable row level security;
alter table public.item_permissions enable row level security;
alter table public.activity_logs enable row level security;

-- =========================================================
-- 7. RLS Policies
-- =========================================================

-- items
create policy items_select on public.items
  for select to authenticated
  using (
    public.get_effective_item_role(id, public.current_user_email()) is not null
  );

create policy items_insert on public.items
  for insert to authenticated
  with check (
    (parent_id is null and (tenant_id is null or public.has_active_tenant_membership(tenant_id)))
    or
    (parent_id is not null and public.get_effective_item_role(parent_id, public.current_user_email()) in ('owner', 'manager', 'editor'))
  );

create policy items_update on public.items
  for update to authenticated
  using (
    public.get_effective_item_role(id, public.current_user_email()) in ('owner', 'manager', 'editor')
  )
  with check (
    public.get_effective_item_role(id, public.current_user_email()) in ('owner', 'manager', 'editor')
  );

create policy items_delete on public.items
  for delete to authenticated
  using (
    public.get_effective_item_role(id, public.current_user_email()) in ('owner', 'manager')
  );

-- item_assignees
create policy item_assignees_select on public.item_assignees
  for select to authenticated
  using (
    exists (select 1 from public.items where id = item_id)
  );

create policy item_assignees_all on public.item_assignees
  for all to authenticated
  using (
    public.get_effective_item_role(item_id, public.current_user_email()) in ('owner', 'manager')
  );

-- tags
create policy tags_select on public.tags
  for select to authenticated
  using (
    tenant_id is null 
    or public.has_active_tenant_membership(tenant_id)
    or created_by_email = public.current_user_email()
  );

create policy tags_all on public.tags
  for all to authenticated
  using (
    created_by_email = public.current_user_email()
    or (tenant_id is not null and public.is_tenant_admin(tenant_id))
  );

-- item_tags
create policy item_tags_select on public.item_tags
  for select to authenticated
  using (
    exists (select 1 from public.items where id = item_id)
  );

create policy item_tags_all on public.item_tags
  for all to authenticated
  using (
    public.get_effective_item_role(item_id, public.current_user_email()) in ('owner', 'manager', 'editor')
  );

-- comments
create policy comments_select on public.comments
  for select to authenticated
  using (
    exists (select 1 from public.items where id = item_id)
  );

create policy comments_insert on public.comments
  for insert to authenticated
  with check (
    public.get_effective_item_role(item_id, public.current_user_email()) in ('owner', 'manager', 'editor', 'commenter')
  );

create policy comments_update on public.comments
  for update to authenticated
  using (
    user_email = public.current_user_email()
    or public.get_effective_item_role(item_id, public.current_user_email()) in ('owner', 'manager')
  );

create policy comments_delete on public.comments
  for delete to authenticated
  using (
    user_email = public.current_user_email()
    or public.get_effective_item_role(item_id, public.current_user_email()) in ('owner', 'manager')
  );

-- item_permissions
create policy item_permissions_select on public.item_permissions
  for select to authenticated
  using (
    exists (select 1 from public.items where id = item_id)
  );

create policy item_permissions_all on public.item_permissions
  for all to authenticated
  using (
    public.get_effective_item_role(item_id, public.current_user_email()) in ('owner', 'manager')
  );

-- activity_logs
create policy activity_logs_select on public.activity_logs
  for select to authenticated
  using (
    exists (select 1 from public.items where id = item_id)
  );

create policy activity_logs_insert on public.activity_logs
  for insert to authenticated
  with check (
    exists (select 1 from public.items where id = item_id)
  );

-- =========================================================
-- 8. Grants
-- =========================================================
grant select, insert, update, delete on table public.items to authenticated;
grant select, insert, update, delete on table public.item_assignees to authenticated;
grant select, insert, update, delete on table public.tags to authenticated;
grant select, insert, update, delete on table public.item_tags to authenticated;
grant select, insert, update, delete on table public.comments to authenticated;
grant select, insert, update, delete on table public.item_permissions to authenticated;
grant select, insert on table public.activity_logs to authenticated;

grant execute on function public.get_effective_item_role(bigint, text) to authenticated;
grant execute on function public.global_search_tasks(text) to authenticated;

commit;

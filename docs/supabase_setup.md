# إعداد Supabase لتطبيق أذكاري

كل الميزات السحابية في التطبيق تعتمد على مشروع Supabase واحد، ومفاتيحه مُعرَّفة في
`lib/services/cloud_sync_service.dart`:

| الثابت | القيمة | ملاحظات |
|---|---|---|
| `kSupabaseProjectUrl` | `https://<project-ref>.supabase.co` | **رابط المشروع الأساسي فقط** — بدون أي مسار |
| `kSupabaseAnonKey` | `sb_publishable_…` | يُرسل في ترويسة `apikey` فقط |

> ⚠️ قاعدتان مهمتان:
> 1. لا تضع مسارًا في `kSupabaseProjectUrl` (مثل `/functions/v1/verify-bybit`)، لأن كل
>    الروابط تُبنى بإضافة المسار الخاص بها؛ أي مسار إضافي يجعل كل الطلبات تذهب لمكان
>    خاطئ وتُعيد 404. الكود يرفض هذا الشكل صراحةً في `isCloudConfigured`.
> 2. مفاتيح `sb_publishable_…` ليست JWT، فلا تُرسل أبدًا كـ `Authorization: Bearer …`
>    (البوابة تُعيد 401 "Invalid JWT"). تُرسل في `apikey` فقط، وهذا ما يفعله
>    `CloudSyncService.authHeaders`.

## 1) الجداول المطلوبة

```sql
-- نسخة احتياطية للسحابة (Cloud Sync)
create table if not exists public.azkari_sync (
  user_id    text primary key,
  payload    jsonb       not null,
  updated_at timestamptz not null default now()
);

-- حالة اشتراك PRO (تكتبها دالة verify-bybit بمفتاح service_role)
create table if not exists public.user_subscriptions (
  fb_user_id        text primary key,
  expires_at        timestamptz,
  plan_label        text,
  contributor_badge boolean not null default false,
  trial_used        boolean not null default false,
  device_ids        jsonb   not null default '[]'::jsonb,
  updated_at        timestamptz not null default now()
);

-- أكواد الخصم / الهدايا
create table if not exists public.pro_promo_codes (
  code             text primary key,
  active           boolean not null default true,
  max_uses         integer not null default 1,
  used_count       integer not null default 0,
  free_days        integer not null default 0,
  discount_percent integer not null default 0,
  created_at       timestamptz not null default now()
);

-- رسائل المساهمات (اختياري)
create table if not exists public.developer_contributions (
  id         bigserial primary key,
  country    text,
  method     text,
  amount     numeric,
  currency   text,
  reference  text,
  message    text,
  created_at timestamptz not null default now()
);
```

## 2) سياسات RLS

التطبيق يعمل بمفتاح `anon` (publishable)، لذا يجب تحديد ما يُسمح به بدقة:

```sql
alter table public.azkari_sync            enable row level security;
alter table public.user_subscriptions     enable row level security;
alter table public.pro_promo_codes        enable row level security;
alter table public.developer_contributions enable row level security;

-- مزامنة الأجهزة: قراءة/كتابة/تحديث صف الجهاز نفسه فقط
create policy "sync read"   on public.azkari_sync for select using (true);
create policy "sync insert" on public.azkari_sync for insert with check (true);
create policy "sync update" on public.azkari_sync for update using (true) with check (true);

-- قراءة حالة الاشتراك فقط (الكتابة من الدالة بمفتاح service_role)
create policy "subs read"   on public.user_subscriptions for select using (true);

-- أكواد البرومو: قراءة الأكواد المفعّلة + زيادة العدّاد
create policy "promo read"  on public.pro_promo_codes for select using (true);
create policy "promo count" on public.pro_promo_codes for update using (true) with check (true);

-- إرسال رسالة مساهمة
create policy "contrib insert" on public.developer_contributions for insert with check (true);
```

> ملاحظة أمنية: سياسة `promo count` تسمح للعميل بزيادة `used_count` أو تعديل أي عمود في
> الجدول. الحل الأكثر أمانًا هو نقل زيادة العدّاد إلى دالة Edge Function مع مفتاح
> `service_role`، وفتح القراءة فقط للعميل.

## 3) دالة التحقق من Bybit

- المسار المتوقع: `POST <project>/functions/v1/verify-bybit`
- المدخلات: `tx_id`, `plan` (`monthly`/`yearly`/`contribution`), `expected_amount`, `user_id`
- المخرجات عند النجاح: `{ "success": true, "days": 30 }`
- تُستدعى من التطبيق بترويسة `apikey` فقط. إذا كانت الدالة منشورة مع **Enforce JWT
  verification** فستُعيد 401 مع مفتاح publishable؛ الحل نشرها بـ
  `supabase functions deploy verify-bybit --no-verify-jwt` والتحقق من صحة المدخلات داخل
  الدالة، أو استخدام تدفق تسجيل دخول يوفّر JWT للمستخدم.
- الدالة تحتاج مفتاح `service_role` (server-side فقط، ولا يوضع في التطبيق) لكتابة صف
  الاشتراك في `user_subscriptions`.

## 4) كيف تتحقق أن كل شيء يعمل

1. `Settings → المزامنة والنسخ الاحتياطي` → «رفع النسخة للسحابة»: يجب أن تظهر رسالة
   `Synced successfully`، ويظهر صف جديد في `azkari_sync`.
2. «استعادة من السحابة» على جهاز آخر أو بعد حذف البيانات: يجب أن ترجع الأذكار والعدّاد
   والتقدم في القرآن.
3. إدخال كود برومو صحيح من شاشة PRO: يُفعّل الأيام أو الخصم.
4. لصق Transfer ID من Bybit: يُفعّل PRO تلقائيًا.

في حال الفشل يعرض التطبيق الآن رسالة عربية واضحة حسب رمز الخطأ (401 / 403 / 404)، وهذا
يشير مباشرةً إلى: مفتاح خاطئ، أو سياسة RLS ناقصة، أو جدول غير مُنشأ.

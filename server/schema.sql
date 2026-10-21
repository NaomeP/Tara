CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, slug text UNIQUE NOT NULL,
  parent_id uuid REFERENCES categories(id), display_order integer NOT NULL DEFAULT 0,
  published boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category_id uuid REFERENCES categories(id),
  name text NOT NULL, slug text UNIQUE NOT NULL, description text NOT NULL DEFAULT '',
  product_type text NOT NULL DEFAULT '', price_paise integer NOT NULL CHECK (price_paise >= 0),
  compare_at_paise integer CHECK (compare_at_paise IS NULL OR compare_at_paise >= price_paise),
  sku text NOT NULL DEFAULT '', image_url text NOT NULL DEFAULT '', image_alt text NOT NULL DEFAULT '', color text NOT NULL DEFAULT '',
  tag text NOT NULL DEFAULT '', sizes text[] NOT NULL DEFAULT '{}', gallery_images text[] NOT NULL DEFAULT '{}',
  fabric text NOT NULL DEFAULT '', care_instructions text NOT NULL DEFAULT '', occasions text[] NOT NULL DEFAULT '{}',
  print_work text NOT NULL DEFAULT '', size_guide jsonb NOT NULL DEFAULT '[]'::jsonb,
  stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
  published boolean NOT NULL DEFAULT false, featured boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE products ADD COLUMN IF NOT EXISTS sku text NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS gallery_images text[] NOT NULL DEFAULT '{}';
ALTER TABLE products ADD COLUMN IF NOT EXISTS fabric text NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS care_instructions text NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS occasions text[] NOT NULL DEFAULT '{}';
ALTER TABLE products ADD COLUMN IF NOT EXISTS print_work text NOT NULL DEFAULT '';
ALTER TABLE products ADD COLUMN IF NOT EXISTS size_guide jsonb NOT NULL DEFAULT '[]'::jsonb;
CREATE INDEX IF NOT EXISTS products_published_category ON products(published, category_id);
CREATE TABLE IF NOT EXISTS product_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku text NOT NULL UNIQUE, options jsonb NOT NULL DEFAULT '{}',
  price_paise integer CHECK (price_paise IS NULL OR price_paise >= 0),
  stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0), active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(product_id, options)
);
CREATE INDEX IF NOT EXISTS product_variants_product_active ON product_variants(product_id, active);
CREATE TABLE IF NOT EXISTS collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, slug text UNIQUE NOT NULL,
  description text NOT NULL DEFAULT '', image_url text NOT NULL DEFAULT '', destination_url text NOT NULL DEFAULT '',
  published boolean NOT NULL DEFAULT false, display_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS collection_products (
  collection_id uuid NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  display_order integer NOT NULL DEFAULT 0, PRIMARY KEY(collection_id, product_id)
);
CREATE TABLE IF NOT EXISTS banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), placement text NOT NULL, title text NOT NULL DEFAULT '',
  subtitle text NOT NULL DEFAULT '', image_url text NOT NULL DEFAULT '', image_alt text NOT NULL DEFAULT '',
  cta_label text NOT NULL DEFAULT '', cta_url text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT false, display_order integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS content_pages (
  slug text PRIMARY KEY, title text NOT NULL, body text NOT NULL DEFAULT '',
  published boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS coupons (
  code text PRIMARY KEY, discount_percent integer NOT NULL CHECK (discount_percent >= 1),
  minimum_subtotal_paise integer NOT NULL DEFAULT 0 CHECK (minimum_subtotal_paise >= 0),
  active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE coupons DROP CONSTRAINT IF EXISTS coupons_discount_percent_check;
ALTER TABLE coupons ADD CONSTRAINT coupons_discount_percent_check CHECK (discount_percent >= 1);
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, phone text NOT NULL,
  email text, auth_user_id uuid UNIQUE, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS customer_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), auth_user_id uuid NOT NULL,
  label text NOT NULL DEFAULT 'Home', recipient_name text NOT NULL, phone text NOT NULL,
  line1 text NOT NULL, line2 text NOT NULL DEFAULT '', city text NOT NULL, state text NOT NULL,
  pincode text NOT NULL, is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE customer_addresses ADD COLUMN IF NOT EXISTS is_default boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS customer_addresses_user_created ON customer_addresses(auth_user_id,created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS customer_addresses_one_default_per_user ON customer_addresses(auth_user_id) WHERE is_default=true;
CREATE TABLE IF NOT EXISTS customer_wishlists (
  auth_user_id uuid NOT NULL, product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(auth_user_id,product_id)
);
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_number text UNIQUE NOT NULL,
  idempotency_key text UNIQUE,
  customer_id uuid REFERENCES customers(id), customer_name text NOT NULL, phone text NOT NULL,
  email text, address jsonb NOT NULL, status text NOT NULL DEFAULT 'pending_payment'
    CHECK (status IN ('pending_payment','confirmed','processing','shipped','delivered','cancelled','return_requested','refunded')),
  payment_method text NOT NULL, payment_status text NOT NULL DEFAULT 'pending'
    CHECK (payment_status IN ('pending','paid','failed','refunded','cod')),
  razorpay_order_id text UNIQUE, razorpay_payment_id text,
  refunded_paise integer NOT NULL DEFAULT 0 CHECK (refunded_paise >= 0),
  payment_expires_at timestamptz,
  subtotal_paise integer NOT NULL CHECK (subtotal_paise >= 0), shipping_paise integer NOT NULL CHECK (shipping_paise >= 0),
  discount_paise integer NOT NULL DEFAULT 0 CHECK (discount_paise >= 0), coupon_code text REFERENCES coupons(code),
  total_paise integer NOT NULL CHECK (total_paise >= 0), tracking_number text, courier text,
  delivered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount_paise integer NOT NULL DEFAULT 0 CHECK (discount_paise >= 0);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS coupon_code text REFERENCES coupons(code);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS razorpay_payment_id text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS refunded_paise integer NOT NULL DEFAULT 0 CHECK (refunded_paise >= 0);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at timestamptz;
UPDATE orders SET delivered_at=updated_at WHERE status='delivered' AND delivered_at IS NULL;
CREATE INDEX IF NOT EXISTS orders_created_at ON orders(created_at DESC);
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES orders(id),
  product_id uuid REFERENCES products(id) ON DELETE SET NULL, product_name text NOT NULL,
  image_url text NOT NULL DEFAULT '', size text NOT NULL DEFAULT '', color text NOT NULL DEFAULT '',
  variant_id uuid REFERENCES product_variants(id) ON DELETE SET NULL, variant_sku text NOT NULL DEFAULT '', variant_options jsonb NOT NULL DEFAULT '{}',
  unit_price_paise integer NOT NULL CHECK (unit_price_paise >= 0), quantity integer NOT NULL CHECK(quantity > 0)
);
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS variant_id uuid REFERENCES product_variants(id) ON DELETE SET NULL;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS variant_sku text NOT NULL DEFAULT '';
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS variant_options jsonb NOT NULL DEFAULT '{}';
CREATE TABLE IF NOT EXISTS customer_order_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  order_item_id uuid REFERENCES order_items(id) ON DELETE CASCADE,
  request_type text NOT NULL CHECK(request_type IN ('cancellation','return','exchange')),
  reason text NOT NULL, comments text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'requested'
    CHECK(status IN ('requested','under_review','approved','rejected','pickup_arranged','received','refund_processing','completed')),
  decision_reason text NOT NULL DEFAULT '', requested_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS customer_order_requests_active_unique ON customer_order_requests(order_id,COALESCE(order_item_id,'00000000-0000-0000-0000-000000000000'::uuid),request_type) WHERE status IN ('requested','under_review','approved','pickup_arranged','received','refund_processing');
CREATE INDEX IF NOT EXISTS customer_order_requests_order_date ON customer_order_requests(order_id,requested_at DESC);
CREATE TABLE IF NOT EXISTS inventory_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_id uuid NOT NULL REFERENCES products(id),
  variant_id uuid REFERENCES product_variants(id) ON DELETE SET NULL,
  order_id uuid REFERENCES orders(id), delta integer NOT NULL, note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE inventory_movements ADD COLUMN IF NOT EXISTS variant_id uuid REFERENCES product_variants(id) ON DELETE SET NULL;
CREATE TABLE IF NOT EXISTS refund_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES orders(id),
  provider_refund_id text UNIQUE, amount_paise integer NOT NULL CHECK (amount_paise > 0),
  status text NOT NULL CHECK (status IN ('requested','processed','failed','unknown')),
  requested_by text NOT NULL, note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS refund_transactions_order_status ON refund_transactions(order_id,status);
CREATE TABLE IF NOT EXISTS customer_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), auth_user_id uuid NOT NULL,
  title text NOT NULL, body text NOT NULL, order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(), read_at timestamptz
);
CREATE INDEX IF NOT EXISTS customer_notifications_user_created ON customer_notifications(auth_user_id,created_at DESC);
CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_id uuid NOT NULL REFERENCES products(id),
  customer_name text NOT NULL, rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body text NOT NULL, approved boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS stock_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  email text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), notified_at timestamptz,
  UNIQUE(product_id,email)
);
CREATE TABLE IF NOT EXISTS return_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL UNIQUE REFERENCES orders(id),
  reason text NOT NULL, status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','approved','rejected','received','refunded','exchanged')),
  requested_at timestamptz NOT NULL DEFAULT now(), admin_note text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS store_settings (
  key text PRIMARY KEY, value jsonb NOT NULL DEFAULT '{}', updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), admin_email text NOT NULL, action text NOT NULL,
  entity text NOT NULL, entity_id text, details jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS newsletter_subscribers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text NOT NULL UNIQUE,
  subscribed_at timestamptz NOT NULL DEFAULT now(), consented_at timestamptz NOT NULL DEFAULT now(), unsubscribed_at timestamptz
);

INSERT INTO categories(name,slug,display_order) VALUES
  ('Sets','sets',1),('Kurtas','kurtas',2),('Dresses','dresses',3),('Tops','tops',4)
ON CONFLICT(slug) DO NOTHING;

INSERT INTO products(category_id,name,slug,description,product_type,price_paise,compare_at_paise,image_url,image_alt,color,tag,sizes,stock,published,featured)
SELECT c.id,v.name,v.slug,v.description,v.product_type,v.price,v.compare_at,v.image,v.name,v.color,v.tag,v.sizes,v.stock,v.published,v.featured
FROM (VALUES
 ('Sets','The Gulmohar Set','the-gulmohar-set','A joyful, easy three-piece cotton set for days worth remembering.','3-piece set',189000,229000,'https://images.unsplash.com/photo-1610030469983-98e550d6193c?auto=format&fit=crop&w=900&q=85','Rose clay','JUST LANDED',ARRAY['XS','S','M','L','XL'],12,true,true),
 ('Kurtas','Malli Everyday Kurta','malli-everyday-kurta','Hand-block printed cotton, made for the everyday.','Hand-block printed cotton',124000,NULL,'https://images.unsplash.com/photo-1583391733956-6c78276477e1?auto=format&fit=crop&w=900&q=85','Indigo','LOVED',ARRAY['XS','S','M','L','XL'],10,true,false),
 ('Sets','The Nila Co-ord','the-nila-co-ord','A relaxed two-piece set in a soft moss green.','2-piece co-ord',215000,NULL,'https://images.unsplash.com/photo-1617627143750-d86bc21e42bb?auto=format&fit=crop&w=900&q=85','Moss green','FEW LEFT',ARRAY['S','M','L','XL'],4,true,true),
 ('Dresses','Sundari Maxi','sundari-maxi','An easy cotton maxi dress in a sunny marigold.','Cotton maxi dress',179000,NULL,'https://images.unsplash.com/photo-1595777457583-95e059d581b8?auto=format&fit=crop&w=900&q=85','Marigold','',ARRAY['XS','S','M','L'],8,true,false),
 ('Tops','Vaanam Soft Shirt','vaanam-soft-shirt','An everyday cotton top in a lovely sky blue.','Everyday cotton top',89000,NULL,'https://images.unsplash.com/photo-1598554747436-c9293d6a588f?auto=format&fit=crop&w=900&q=85','Sky blue','NEW COLOUR',ARRAY['XS','S','M','L','XL'],14,true,false),
 ('Sets','Pavazham Festive Set','pavazham-festive-set','A three-piece occasion set for moments that matter.','3-piece occasion wear',269000,319000,'https://images.unsplash.com/photo-1583391733981-849c6f8b45a6?auto=format&fit=crop&w=900&q=85','Coral pink','',ARRAY['S','M','L','XL'],5,true,false),
 ('Tops','Kaatru Easy Tunic','kaatru-easy-tunic','A breathable linen blend tunic with a little room to move.','Linen blend tunic',109000,NULL,'https://images.unsplash.com/photo-1585487000160-6ebcfceb0d03?auto=format&fit=crop&w=900&q=85','Natural','',ARRAY['XS','S','M','L'],11,true,false),
 ('Dresses','Poovizhi Printed Dress','poovizhi-printed-dress','A garden-print midi dress to make an ordinary day.','Printed midi dress',159000,NULL,'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?auto=format&fit=crop&w=900&q=85','Garden print','JUST LANDED',ARRAY['XS','S','M','L','XL'],9,true,false)
) AS v(category,name,slug,description,product_type,price,compare_at,image,color,tag,sizes,stock,published,featured)
JOIN categories c ON lower(c.slug)=lower(v.category)
ON CONFLICT(slug) DO NOTHING;

INSERT INTO store_settings(key,value) VALUES
 ('announcement',to_jsonb('Complimentary shipping over ₹1,999'::text)),
 ('shipping',jsonb_build_object('freeThresholdPaise',199900,'flatFeePaise',9900)),
 ('content',jsonb_build_object('supportEmail','','supportPhone','','returnsDays',7))
ON CONFLICT(key) DO NOTHING;

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.4"
  }
  public: {
    Tables: {
      _bak_thrift_pricings: {
        Row: {
          cost_of_goods_sold: number | null
          created_at: string | null
          extra_expense_cost: number | null
          id: number | null
          inserted_by: string | null
          listed_price: number | null
          stock_id: number | null
          target_price: number | null
          updated_at: string | null
        }
        Insert: {
          cost_of_goods_sold?: number | null
          created_at?: string | null
          extra_expense_cost?: number | null
          id?: number | null
          inserted_by?: string | null
          listed_price?: number | null
          stock_id?: number | null
          target_price?: number | null
          updated_at?: string | null
        }
        Update: {
          cost_of_goods_sold?: number | null
          created_at?: string | null
          extra_expense_cost?: number | null
          id?: number | null
          inserted_by?: string | null
          listed_price?: number | null
          stock_id?: number | null
          target_price?: number | null
          updated_at?: string | null
        }
        Relationships: []
      }
      _bak_thrift_settings: {
        Row: {
          created_at: string | null
          default_origin_purchase_price: number | null
          tenant_id: number | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          default_origin_purchase_price?: number | null
          tenant_id?: number | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          default_origin_purchase_price?: number | null
          tenant_id?: number | null
          updated_at?: string | null
        }
        Relationships: []
      }
      _bak_thrift_shipments: {
        Row: {
          cargo_conversion_rate: number | null
          cargo_rate: number | null
          cost_currency_id: number | null
          created_at: string | null
          id: number | null
          inserted_by: string | null
          name: string | null
          product_conversion_rate: number | null
          purchase_currency_id: number | null
          tenant_id: number | null
          updated_at: string | null
        }
        Insert: {
          cargo_conversion_rate?: number | null
          cargo_rate?: number | null
          cost_currency_id?: number | null
          created_at?: string | null
          id?: number | null
          inserted_by?: string | null
          name?: string | null
          product_conversion_rate?: number | null
          purchase_currency_id?: number | null
          tenant_id?: number | null
          updated_at?: string | null
        }
        Update: {
          cargo_conversion_rate?: number | null
          cargo_rate?: number | null
          cost_currency_id?: number | null
          created_at?: string | null
          id?: number | null
          inserted_by?: string | null
          name?: string | null
          product_conversion_rate?: number | null
          purchase_currency_id?: number | null
          tenant_id?: number | null
          updated_at?: string | null
        }
        Relationships: []
      }
      _bak_thrift_stock_images: {
        Row: {
          created_at: string | null
          drive_file_id: string | null
          id: number | null
          image_url: string | null
          inserted_by: string | null
          is_primary: boolean | null
          stock_id: number | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          drive_file_id?: string | null
          id?: number | null
          image_url?: string | null
          inserted_by?: string | null
          is_primary?: boolean | null
          stock_id?: number | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          drive_file_id?: string | null
          id?: number | null
          image_url?: string | null
          inserted_by?: string | null
          is_primary?: boolean | null
          stock_id?: number | null
          updated_at?: string | null
        }
        Relationships: []
      }
      _bak_thrift_stocks: {
        Row: {
          barcode: string | null
          box_id: number | null
          brand_name: string | null
          category_id: number | null
          color: string | null
          condition: Database["public"]["Enums"]["thrift_condition"] | null
          created_at: string | null
          extra_origin_purchase_expense: number | null
          extra_weight: number | null
          id: number | null
          inserted_by: string | null
          name: string | null
          note: string | null
          origin_purchase_price: number | null
          product_weight: number | null
          quantity: number | null
          section: Database["public"]["Enums"]["thrift_section"] | null
          shelf_id: number | null
          shipment_id: number | null
          size: string | null
          status: Database["public"]["Enums"]["thrift_stock_status"] | null
          stock_type: Database["public"]["Enums"]["thrift_stock_type"] | null
          tenant_id: number | null
          type_id: number | null
          updated_at: string | null
        }
        Insert: {
          barcode?: string | null
          box_id?: number | null
          brand_name?: string | null
          category_id?: number | null
          color?: string | null
          condition?: Database["public"]["Enums"]["thrift_condition"] | null
          created_at?: string | null
          extra_origin_purchase_expense?: number | null
          extra_weight?: number | null
          id?: number | null
          inserted_by?: string | null
          name?: string | null
          note?: string | null
          origin_purchase_price?: number | null
          product_weight?: number | null
          quantity?: number | null
          section?: Database["public"]["Enums"]["thrift_section"] | null
          shelf_id?: number | null
          shipment_id?: number | null
          size?: string | null
          status?: Database["public"]["Enums"]["thrift_stock_status"] | null
          stock_type?: Database["public"]["Enums"]["thrift_stock_type"] | null
          tenant_id?: number | null
          type_id?: number | null
          updated_at?: string | null
        }
        Update: {
          barcode?: string | null
          box_id?: number | null
          brand_name?: string | null
          category_id?: number | null
          color?: string | null
          condition?: Database["public"]["Enums"]["thrift_condition"] | null
          created_at?: string | null
          extra_origin_purchase_expense?: number | null
          extra_weight?: number | null
          id?: number | null
          inserted_by?: string | null
          name?: string | null
          note?: string | null
          origin_purchase_price?: number | null
          product_weight?: number | null
          quantity?: number | null
          section?: Database["public"]["Enums"]["thrift_section"] | null
          shelf_id?: number | null
          shipment_id?: number | null
          size?: string | null
          status?: Database["public"]["Enums"]["thrift_stock_status"] | null
          stock_type?: Database["public"]["Enums"]["thrift_stock_type"] | null
          tenant_id?: number | null
          type_id?: number | null
          updated_at?: string | null
        }
        Relationships: []
      }
      activity_logs: {
        Row: {
          action: string
          created_at: string
          id: number
          item_id: number
          new_value: string | null
          old_value: string | null
          user_email: string
        }
        Insert: {
          action: string
          created_at?: string
          id?: number
          item_id: number
          new_value?: string | null
          old_value?: string | null
          user_email?: string
        }
        Update: {
          action?: string
          created_at?: string
          id?: number
          item_id?: number
          new_value?: string | null
          old_value?: string | null
          user_email?: string
        }
        Relationships: [
          {
            foreignKeyName: "activity_logs_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      batch_code_pc: {
        Row: {
          batch_id: string | null
          created_at: string
          expire_date: string | null
          id: number
          manufacturing_date: string | null
          product_code: string | null
          shipment_id: number
          shipment_item_id: number | null
          updated_at: string
        }
        Insert: {
          batch_id?: string | null
          created_at?: string
          expire_date?: string | null
          id?: number
          manufacturing_date?: string | null
          product_code?: string | null
          shipment_id: number
          shipment_item_id?: number | null
          updated_at?: string
        }
        Update: {
          batch_id?: string | null
          created_at?: string
          expire_date?: string | null
          id?: number
          manufacturing_date?: string | null
          product_code?: string | null
          shipment_id?: number
          shipment_item_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "batch_code_pc_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batch_code_pc_shipment_item_id_fkey"
            columns: ["shipment_item_id"]
            isOneToOne: false
            referencedRelation: "shipment_items"
            referencedColumns: ["id"]
          },
        ]
      }
      billing_profiles: {
        Row: {
          address: string | null
          color: string | null
          created_at: string
          customer_group_id: number | null
          email: string | null
          id: number
          name: string
          phone: string | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          address?: string | null
          color?: string | null
          created_at?: string
          customer_group_id?: number | null
          email?: string | null
          id?: number
          name: string
          phone?: string | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          address?: string | null
          color?: string | null
          created_at?: string
          customer_group_id?: number | null
          email?: string | null
          id?: number
          name?: string
          phone?: string | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "billing_profiles_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "billing_profiles_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      business_parties: {
        Row: {
          address: string | null
          created_at: string
          email: string | null
          id: number
          is_active: boolean
          name: string
          parent_tenant_id: number
          party_type: string
          phone: string | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          email?: string | null
          id?: number
          is_active?: boolean
          name: string
          parent_tenant_id: number
          party_type?: string
          phone?: string | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          email?: string | null
          id?: number
          is_active?: boolean
          name?: string
          parent_tenant_id?: number
          party_type?: string
          phone?: string | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "business_parties_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "business_parties_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      cart_items: {
        Row: {
          cart_id: number
          created_at: string
          id: number
          image_url: string | null
          minimum_quantity: number
          minimum_sell_price_bdt: number | null
          name: string
          price_bdt: number | null
          price_gbp: number | null
          product_id: number | null
          quantity: number
          updated_at: string
        }
        Insert: {
          cart_id: number
          created_at?: string
          id?: number
          image_url?: string | null
          minimum_quantity?: number
          minimum_sell_price_bdt?: number | null
          name: string
          price_bdt?: number | null
          price_gbp?: number | null
          product_id?: number | null
          quantity?: number
          updated_at?: string
        }
        Update: {
          cart_id?: number
          created_at?: string
          id?: number
          image_url?: string | null
          minimum_quantity?: number
          minimum_sell_price_bdt?: number | null
          name?: string
          price_bdt?: number | null
          price_gbp?: number | null
          product_id?: number | null
          quantity?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "cart_items_cart_id_fkey"
            columns: ["cart_id"]
            isOneToOne: false
            referencedRelation: "carts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cart_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      carts: {
        Row: {
          can_see_price: boolean
          created_at: string
          customer_group_id: number | null
          id: number
          store_id: number | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          can_see_price?: boolean
          created_at?: string
          customer_group_id?: number | null
          id?: number
          store_id?: number | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          can_see_price?: boolean
          created_at?: string
          customer_group_id?: number | null
          id?: number
          store_id?: number | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "carts_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "carts_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      comments: {
        Row: {
          body: string
          created_at: string
          deleted_at: string | null
          id: number
          item_id: number
          parent_comment_id: number | null
          updated_at: string
          user_email: string
        }
        Insert: {
          body: string
          created_at?: string
          deleted_at?: string | null
          id?: number
          item_id: number
          parent_comment_id?: number | null
          updated_at?: string
          user_email?: string
        }
        Update: {
          body?: string
          created_at?: string
          deleted_at?: string | null
          id?: number
          item_id?: number
          parent_comment_id?: number | null
          updated_at?: string
          user_email?: string
        }
        Relationships: [
          {
            foreignKeyName: "comments_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_parent_comment_id_fkey"
            columns: ["parent_comment_id"]
            isOneToOne: false
            referencedRelation: "comments"
            referencedColumns: ["id"]
          },
        ]
      }
      commerce_cart: {
        Row: {
          created_at: string
          customer_group_id: number
          global_stock_id: number | null
          id: number
          inventory_item_id: number | null
          product_id: number | null
          quantity: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          customer_group_id: number
          global_stock_id?: number | null
          id?: number
          inventory_item_id?: number | null
          product_id?: number | null
          quantity?: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          customer_group_id?: number
          global_stock_id?: number | null
          id?: number
          inventory_item_id?: number | null
          product_id?: number | null
          quantity?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "commerce_cart_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_cart_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_cart_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      commerce_inventory_product_summaries: {
        Row: {
          available_quantity: number
          damaged_quantity: number
          expired_quantity: number
          id: number
          open_box_quantity: number
          product_id: number
          reserved_quantity: number
          stolen_quantity: number
          tenant_id: number
          updated_at: string
          usable_quantity: number
        }
        Insert: {
          available_quantity?: number
          damaged_quantity?: number
          expired_quantity?: number
          id?: number
          open_box_quantity?: number
          product_id: number
          reserved_quantity?: number
          stolen_quantity?: number
          tenant_id: number
          updated_at?: string
          usable_quantity?: number
        }
        Update: {
          available_quantity?: number
          damaged_quantity?: number
          expired_quantity?: number
          id?: number
          open_box_quantity?: number
          product_id?: number
          reserved_quantity?: number
          stolen_quantity?: number
          tenant_id?: number
          updated_at?: string
          usable_quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "commerce_inventory_product_summaries_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_inventory_product_summaries_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      commerce_invoice_boxes: {
        Row: {
          box_number: string
          created_at: string
          id: number
          invoice_id: number
          tenant_id: number
          updated_at: string
          weight: number
        }
        Insert: {
          box_number: string
          created_at?: string
          id?: number
          invoice_id: number
          tenant_id: number
          updated_at?: string
          weight: number
        }
        Update: {
          box_number?: string
          created_at?: string
          id?: number
          invoice_id?: number
          tenant_id?: number
          updated_at?: string
          weight?: number
        }
        Relationships: [
          {
            foreignKeyName: "commerce_invoice_boxes_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "commerce_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_invoice_boxes_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      commerce_invoices: {
        Row: {
          advance_amount: number
          amount_due: number
          amount_paid: number
          billing_profile_id: number | null
          brand_address: string | null
          brand_name: string | null
          client_name: string | null
          client_tr: string | null
          cod: number
          created_at: string
          delivered_by: string | null
          delivery_charge: number
          discount_amount: number
          id: number
          invoice_date: string
          invoice_type: string
          is_customer_group_paid: boolean
          note: string | null
          order_id: number | null
          previous_due: number
          print_charge: number
          recipient_name: string | null
          recipient_phone: string | null
          shipping_address: string | null
          status: string
          tenant_id: number
          thank_you_message: string | null
          total_amount: number
          total_boxes: number | null
          updated_at: string
          wrapping_charge: number
        }
        Insert: {
          advance_amount?: number
          amount_due?: number
          amount_paid?: number
          billing_profile_id?: number | null
          brand_address?: string | null
          brand_name?: string | null
          client_name?: string | null
          client_tr?: string | null
          cod?: number
          created_at?: string
          delivered_by?: string | null
          delivery_charge?: number
          discount_amount?: number
          id?: number
          invoice_date?: string
          invoice_type?: string
          is_customer_group_paid?: boolean
          note?: string | null
          order_id?: number | null
          previous_due?: number
          print_charge?: number
          recipient_name?: string | null
          recipient_phone?: string | null
          shipping_address?: string | null
          status?: string
          tenant_id: number
          thank_you_message?: string | null
          total_amount?: number
          total_boxes?: number | null
          updated_at?: string
          wrapping_charge?: number
        }
        Update: {
          advance_amount?: number
          amount_due?: number
          amount_paid?: number
          billing_profile_id?: number | null
          brand_address?: string | null
          brand_name?: string | null
          client_name?: string | null
          client_tr?: string | null
          cod?: number
          created_at?: string
          delivered_by?: string | null
          delivery_charge?: number
          discount_amount?: number
          id?: number
          invoice_date?: string
          invoice_type?: string
          is_customer_group_paid?: boolean
          note?: string | null
          order_id?: number | null
          previous_due?: number
          print_charge?: number
          recipient_name?: string | null
          recipient_phone?: string | null
          shipping_address?: string | null
          status?: string
          tenant_id?: number
          thank_you_message?: string | null
          total_amount?: number
          total_boxes?: number | null
          updated_at?: string
          wrapping_charge?: number
        }
        Relationships: [
          {
            foreignKeyName: "commerce_invoices_billing_profile_id_fkey"
            columns: ["billing_profile_id"]
            isOneToOne: false
            referencedRelation: "billing_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_invoices_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "commerce_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_invoices_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      commerce_order_items: {
        Row: {
          cost_bdt: number
          created_at: string
          global_stock_id: number | null
          id: number
          image_url: string | null
          inventory_item_id: number | null
          invoice_id: number | null
          order_id: number | null
          phone_invite_id: string | null
          product_id: number
          quantity: number
          recipient_price_bdt: number
          sell_price_bdt: number
          shipment_item_id: number | null
          unit: string
          updated_at: string
        }
        Insert: {
          cost_bdt?: number
          created_at?: string
          global_stock_id?: number | null
          id?: number
          image_url?: string | null
          inventory_item_id?: number | null
          invoice_id?: number | null
          order_id?: number | null
          phone_invite_id?: string | null
          product_id: number
          quantity?: number
          recipient_price_bdt?: number
          sell_price_bdt?: number
          shipment_item_id?: number | null
          unit?: string
          updated_at?: string
        }
        Update: {
          cost_bdt?: number
          created_at?: string
          global_stock_id?: number | null
          id?: number
          image_url?: string | null
          inventory_item_id?: number | null
          invoice_id?: number | null
          order_id?: number | null
          phone_invite_id?: string | null
          product_id?: number
          quantity?: number
          recipient_price_bdt?: number
          sell_price_bdt?: number
          shipment_item_id?: number | null
          unit?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "commerce_order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "commerce_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_order_items_shipment_item_id_fkey"
            columns: ["shipment_item_id"]
            isOneToOne: false
            referencedRelation: "shipment_items"
            referencedColumns: ["id"]
          },
        ]
      }
      commerce_order_settings: {
        Row: {
          created_at: string
          default_cod_percent: number
          default_delivery_charge: number
          default_invoice_print_charge: number
          default_wrapping_charge: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          default_cod_percent?: number
          default_delivery_charge?: number
          default_invoice_print_charge?: number
          default_wrapping_charge?: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          default_cod_percent?: number
          default_delivery_charge?: number
          default_invoice_print_charge?: number
          default_wrapping_charge?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "commerce_order_settings_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: true
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      commerce_orders: {
        Row: {
          cod: number
          created_at: string
          customer_group_id: number | null
          delivery_charge: number
          id: number
          invoice_ids: number[]
          invoice_print_charge: number
          is_delivery_charge_inclusive: boolean
          order_placement_date: string
          recipient_name: string
          recipient_phone: string | null
          shipment_date: string | null
          shipment_payment: number
          shipping_address: string | null
          status: Database["public"]["Enums"]["commerce_order_status"]
          tenant_id: number
          updated_at: string
          wrapping_charge: number
        }
        Insert: {
          cod?: number
          created_at?: string
          customer_group_id?: number | null
          delivery_charge?: number
          id?: number
          invoice_ids?: number[]
          invoice_print_charge?: number
          is_delivery_charge_inclusive?: boolean
          order_placement_date?: string
          recipient_name: string
          recipient_phone?: string | null
          shipment_date?: string | null
          shipment_payment?: number
          shipping_address?: string | null
          status?: Database["public"]["Enums"]["commerce_order_status"]
          tenant_id: number
          updated_at?: string
          wrapping_charge?: number
        }
        Update: {
          cod?: number
          created_at?: string
          customer_group_id?: number | null
          delivery_charge?: number
          id?: number
          invoice_ids?: number[]
          invoice_print_charge?: number
          is_delivery_charge_inclusive?: boolean
          order_placement_date?: string
          recipient_name?: string
          recipient_phone?: string | null
          shipment_date?: string | null
          shipment_payment?: number
          shipping_address?: string | null
          status?: Database["public"]["Enums"]["commerce_order_status"]
          tenant_id?: number
          updated_at?: string
          wrapping_charge?: number
        }
        Relationships: [
          {
            foreignKeyName: "commerce_orders_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "commerce_orders_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      costing_file_items: {
        Row: {
          assigned_shipment_id: number | null
          auxiliary_price_gbp: number | null
          cargo_rate: number | null
          cargo_rate_is_manual: boolean
          color: string | null
          costing_file_id: number
          costing_price_bdt: number | null
          costing_price_gbp: number | null
          created_at: string
          created_by_email: string
          customer_profit_rate: number | null
          delivery_price_gbp: number | null
          extra_information_1: string | null
          extra_information_2: string | null
          id: number
          image_url: string | null
          item_price_gbp: number | null
          item_type: string | null
          name: string | null
          offer_price_bdt: number | null
          offer_price_override_bdt: number | null
          package_weight: number | null
          price_in_web_gbp: number | null
          product_weight: number | null
          quantity: number
          size: string | null
          status: Database["public"]["Enums"]["costing_file_item_status"]
          updated_at: string
          website_url: string
        }
        Insert: {
          assigned_shipment_id?: number | null
          auxiliary_price_gbp?: number | null
          cargo_rate?: number | null
          cargo_rate_is_manual?: boolean
          color?: string | null
          costing_file_id: number
          costing_price_bdt?: number | null
          costing_price_gbp?: number | null
          created_at?: string
          created_by_email?: string
          customer_profit_rate?: number | null
          delivery_price_gbp?: number | null
          extra_information_1?: string | null
          extra_information_2?: string | null
          id?: number
          image_url?: string | null
          item_price_gbp?: number | null
          item_type?: string | null
          name?: string | null
          offer_price_bdt?: number | null
          offer_price_override_bdt?: number | null
          package_weight?: number | null
          price_in_web_gbp?: number | null
          product_weight?: number | null
          quantity: number
          size?: string | null
          status?: Database["public"]["Enums"]["costing_file_item_status"]
          updated_at?: string
          website_url: string
        }
        Update: {
          assigned_shipment_id?: number | null
          auxiliary_price_gbp?: number | null
          cargo_rate?: number | null
          cargo_rate_is_manual?: boolean
          color?: string | null
          costing_file_id?: number
          costing_price_bdt?: number | null
          costing_price_gbp?: number | null
          created_at?: string
          created_by_email?: string
          customer_profit_rate?: number | null
          delivery_price_gbp?: number | null
          extra_information_1?: string | null
          extra_information_2?: string | null
          id?: number
          image_url?: string | null
          item_price_gbp?: number | null
          item_type?: string | null
          name?: string | null
          offer_price_bdt?: number | null
          offer_price_override_bdt?: number | null
          package_weight?: number | null
          price_in_web_gbp?: number | null
          product_weight?: number | null
          quantity?: number
          size?: string | null
          status?: Database["public"]["Enums"]["costing_file_item_status"]
          updated_at?: string
          website_url?: string
        }
        Relationships: [
          {
            foreignKeyName: "costing_file_items_assigned_shipment_id_fkey"
            columns: ["assigned_shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "costing_file_items_costing_file_id_fkey"
            columns: ["costing_file_id"]
            isOneToOne: false
            referencedRelation: "costing_files"
            referencedColumns: ["id"]
          },
        ]
      }
      costing_file_viewers: {
        Row: {
          costing_file_id: number
          created_at: string
          created_by_email: string
          id: number
          membership_id: number
          updated_at: string
        }
        Insert: {
          costing_file_id: number
          created_at?: string
          created_by_email?: string
          id?: number
          membership_id: number
          updated_at?: string
        }
        Update: {
          costing_file_id?: number
          created_at?: string
          created_by_email?: string
          id?: number
          membership_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "costing_file_viewers_costing_file_id_fkey"
            columns: ["costing_file_id"]
            isOneToOne: false
            referencedRelation: "costing_files"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "costing_file_viewers_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: false
            referencedRelation: "memberships"
            referencedColumns: ["id"]
          },
        ]
      }
      costing_files: {
        Row: {
          admin_profit_rate: number | null
          cargo_rate_1kg: number | null
          cargo_rate_2kg: number | null
          conversion_rate: number | null
          created_at: string
          created_by_email: string
          customer_group_id: number
          default_shipment_id: number | null
          id: number
          market: string | null
          name: string
          status: Database["public"]["Enums"]["costing_file_status"]
          tenant_id: number
          updated_at: string
        }
        Insert: {
          admin_profit_rate?: number | null
          cargo_rate_1kg?: number | null
          cargo_rate_2kg?: number | null
          conversion_rate?: number | null
          created_at?: string
          created_by_email?: string
          customer_group_id: number
          default_shipment_id?: number | null
          id?: number
          market?: string | null
          name: string
          status?: Database["public"]["Enums"]["costing_file_status"]
          tenant_id: number
          updated_at?: string
        }
        Update: {
          admin_profit_rate?: number | null
          cargo_rate_1kg?: number | null
          cargo_rate_2kg?: number | null
          conversion_rate?: number | null
          created_at?: string
          created_by_email?: string
          customer_group_id?: number
          default_shipment_id?: number | null
          id?: number
          market?: string | null
          name?: string
          status?: Database["public"]["Enums"]["costing_file_status"]
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "costing_files_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "costing_files_default_shipment_id_fkey"
            columns: ["default_shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "costing_files_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_group_members: {
        Row: {
          added_by: number | null
          created_at: string
          customer_group_id: number
          email: string
          id: number
          is_active: boolean
          name: string
          role: Database["public"]["Enums"]["customer_group_role"]
          updated_at: string
        }
        Insert: {
          added_by?: number | null
          created_at?: string
          customer_group_id: number
          email: string
          id?: number
          is_active?: boolean
          name: string
          role: Database["public"]["Enums"]["customer_group_role"]
          updated_at?: string
        }
        Update: {
          added_by?: number | null
          created_at?: string
          customer_group_id?: number
          email?: string
          id?: number
          is_active?: boolean
          name?: string
          role?: Database["public"]["Enums"]["customer_group_role"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_group_members_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_groups: {
        Row: {
          accent_color: string | null
          created_at: string
          id: number
          is_active: boolean
          name: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          accent_color?: string | null
          created_at?: string
          id?: number
          is_active?: boolean
          name: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          accent_color?: string | null
          created_at?: string
          id?: number
          is_active?: boolean
          name?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_groups_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      global_accounting_ledger: {
        Row: {
          charge_type: Database["public"]["Enums"]["invoice_charge_type"] | null
          cost_amount: number
          created_at: string
          created_by: string | null
          entry_date: string
          global_invoice_id: number | null
          global_invoice_item_id: number | null
          global_stock_id: number | null
          gross_profit_amount: number
          id: number
          is_charge: boolean
          note: string | null
          parent_tenant_id: number
          product_id: number | null
          quantity: number
          return_amount: number
          return_quantity: number
          sell_price_amount: number
          shipment_id: number | null
          shipment_item_id: number | null
          sold_in_tenant_id: number | null
          status: string
          tenant_id: number
          total_cost_amount: number
          total_sell_amount: number
          updated_at: string
        }
        Insert: {
          charge_type?:
            | Database["public"]["Enums"]["invoice_charge_type"]
            | null
          cost_amount?: number
          created_at?: string
          created_by?: string | null
          entry_date?: string
          global_invoice_id?: number | null
          global_invoice_item_id?: number | null
          global_stock_id?: number | null
          gross_profit_amount?: number
          id?: number
          is_charge?: boolean
          note?: string | null
          parent_tenant_id: number
          product_id?: number | null
          quantity?: number
          return_amount?: number
          return_quantity?: number
          sell_price_amount?: number
          shipment_id?: number | null
          shipment_item_id?: number | null
          sold_in_tenant_id?: number | null
          status?: string
          tenant_id: number
          total_cost_amount?: number
          total_sell_amount?: number
          updated_at?: string
        }
        Update: {
          charge_type?:
            | Database["public"]["Enums"]["invoice_charge_type"]
            | null
          cost_amount?: number
          created_at?: string
          created_by?: string | null
          entry_date?: string
          global_invoice_id?: number | null
          global_invoice_item_id?: number | null
          global_stock_id?: number | null
          gross_profit_amount?: number
          id?: number
          is_charge?: boolean
          note?: string | null
          parent_tenant_id?: number
          product_id?: number | null
          quantity?: number
          return_amount?: number
          return_quantity?: number
          sell_price_amount?: number
          shipment_id?: number | null
          shipment_item_id?: number | null
          sold_in_tenant_id?: number | null
          status?: string
          tenant_id?: number
          total_cost_amount?: number
          total_sell_amount?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_accounting_ledger_global_invoice_id_fkey"
            columns: ["global_invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_accounting_ledger_global_invoice_item_id_fkey"
            columns: ["global_invoice_item_id"]
            isOneToOne: false
            referencedRelation: "global_invoice_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_accounting_ledger_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_accounting_ledger_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_accounting_ledger_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_accounting_ledger_shipment_item_id_fkey"
            columns: ["shipment_item_id"]
            isOneToOne: false
            referencedRelation: "shipment_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_accounting_ledger_sold_in_tenant_id_fkey"
            columns: ["sold_in_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_accounting_ledger_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      global_currencies: {
        Row: {
          code: string
          country: string
          created_at: string
          id: number
          is_active: boolean
          is_system: boolean
          name: string
          symbol: string
          updated_at: string
        }
        Insert: {
          code: string
          country: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          name: string
          symbol: string
          updated_at?: string
        }
        Update: {
          code?: string
          country?: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          name?: string
          symbol?: string
          updated_at?: string
        }
        Relationships: []
      }
      global_invoice_accounting: {
        Row: {
          charge_total: number
          discount_amount: number
          global_invoice_id: number
          gross_profit_total: number
          id: number
          parent_tenant_id: number
          refreshed_at: string
          subtotal_amount: number
          tenant_id: number
          total_amount: number
        }
        Insert: {
          charge_total?: number
          discount_amount?: number
          global_invoice_id: number
          gross_profit_total?: number
          id?: number
          parent_tenant_id: number
          refreshed_at?: string
          subtotal_amount?: number
          tenant_id: number
          total_amount?: number
        }
        Update: {
          charge_total?: number
          discount_amount?: number
          global_invoice_id?: number
          gross_profit_total?: number
          id?: number
          parent_tenant_id?: number
          refreshed_at?: string
          subtotal_amount?: number
          tenant_id?: number
          total_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "global_invoice_accounting_global_invoice_id_fkey"
            columns: ["global_invoice_id"]
            isOneToOne: true
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_accounting_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_accounting_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      global_invoice_items: {
        Row: {
          barcode_snapshot: string | null
          cost_amount: number
          created_at: string
          global_stock_id: number
          id: number
          invoice_id: number
          line_discount_amount: number
          line_face_total_amount: number
          line_tax_amount: number
          line_total_amount: number
          name_snapshot: string
          parent_tenant_id: number
          product_code_snapshot: string | null
          product_id: number | null
          quantity: number
          recipient_price_amount: number | null
          sell_price_amount: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          barcode_snapshot?: string | null
          cost_amount?: number
          created_at?: string
          global_stock_id: number
          id?: number
          invoice_id: number
          line_discount_amount?: number
          line_face_total_amount?: number
          line_tax_amount?: number
          line_total_amount?: number
          name_snapshot: string
          parent_tenant_id: number
          product_code_snapshot?: string | null
          product_id?: number | null
          quantity: number
          recipient_price_amount?: number | null
          sell_price_amount?: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          barcode_snapshot?: string | null
          cost_amount?: number
          created_at?: string
          global_stock_id?: number
          id?: number
          invoice_id?: number
          line_discount_amount?: number
          line_face_total_amount?: number
          line_tax_amount?: number
          line_total_amount?: number
          name_snapshot?: string
          parent_tenant_id?: number
          product_code_snapshot?: string | null
          product_id?: number | null
          quantity?: number
          recipient_price_amount?: number | null
          sell_price_amount?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      global_invoices: {
        Row: {
          accounting_subtotal_amount: number
          billing_profile_id: number | null
          collection_source: string | null
          created_at: string
          created_by: string | null
          customer_group_id: number | null
          discount_amount: number
          due_amount: number
          due_date: string | null
          face_subtotal_amount: number
          id: number
          invoice_date: string
          invoice_no: string
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          middle_man_payout_amount: number
          middle_man_payout_status: string
          note: string | null
          ordered_by_party_id: number | null
          paid_amount: number
          parent_tenant_id: number
          payment_status: string
          recipient_address: string | null
          recipient_name: string | null
          recipient_party_id: number | null
          recipient_phone: string | null
          sold_in_tenant_id: number | null
          source_module: Database["public"]["Enums"]["global_source_module"]
          subtotal_amount: number
          tenant_id: number
          total_amount: number
          updated_at: string
        }
        Insert: {
          accounting_subtotal_amount?: number
          billing_profile_id?: number | null
          collection_source?: string | null
          created_at?: string
          created_by?: string | null
          customer_group_id?: number | null
          discount_amount?: number
          due_amount?: number
          due_date?: string | null
          face_subtotal_amount?: number
          id?: number
          invoice_date?: string
          invoice_no: string
          invoice_type?: Database["public"]["Enums"]["global_invoice_type"]
          middle_man_payout_amount?: number
          middle_man_payout_status?: string
          note?: string | null
          ordered_by_party_id?: number | null
          paid_amount?: number
          parent_tenant_id: number
          payment_status?: string
          recipient_address?: string | null
          recipient_name?: string | null
          recipient_party_id?: number | null
          recipient_phone?: string | null
          sold_in_tenant_id?: number | null
          source_module?: Database["public"]["Enums"]["global_source_module"]
          subtotal_amount?: number
          tenant_id: number
          total_amount?: number
          updated_at?: string
        }
        Update: {
          accounting_subtotal_amount?: number
          billing_profile_id?: number | null
          collection_source?: string | null
          created_at?: string
          created_by?: string | null
          customer_group_id?: number | null
          discount_amount?: number
          due_amount?: number
          due_date?: string | null
          face_subtotal_amount?: number
          id?: number
          invoice_date?: string
          invoice_no?: string
          invoice_type?: Database["public"]["Enums"]["global_invoice_type"]
          middle_man_payout_amount?: number
          middle_man_payout_status?: string
          note?: string | null
          ordered_by_party_id?: number | null
          paid_amount?: number
          parent_tenant_id?: number
          payment_status?: string
          recipient_address?: string | null
          recipient_name?: string | null
          recipient_party_id?: number | null
          recipient_phone?: string | null
          sold_in_tenant_id?: number | null
          source_module?: Database["public"]["Enums"]["global_source_module"]
          subtotal_amount?: number
          tenant_id?: number
          total_amount?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_invoices_billing_profile_id_fkey"
            columns: ["billing_profile_id"]
            isOneToOne: false
            referencedRelation: "billing_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoices_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoices_ordered_by_party_id_fkey"
            columns: ["ordered_by_party_id"]
            isOneToOne: false
            referencedRelation: "business_parties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoices_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoices_recipient_party_id_fkey"
            columns: ["recipient_party_id"]
            isOneToOne: false
            referencedRelation: "business_parties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoices_sold_in_tenant_id_fkey"
            columns: ["sold_in_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoices_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      global_return_items: {
        Row: {
          created_at: string
          global_stock_id: number
          id: number
          invoice_id: number
          invoice_item_id: number
          note: string | null
          parent_tenant_id: number
          quantity: number
          return_accounting_amount: number
          return_amount: number
          return_charge_amount: number
          return_face_amount: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          global_stock_id: number
          id?: number
          invoice_id: number
          invoice_item_id: number
          note?: string | null
          parent_tenant_id: number
          quantity: number
          return_accounting_amount?: number
          return_amount?: number
          return_charge_amount?: number
          return_face_amount?: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          global_stock_id?: number
          id?: number
          invoice_id?: number
          invoice_item_id?: number
          note?: string | null
          parent_tenant_id?: number
          quantity?: number
          return_accounting_amount?: number
          return_amount?: number
          return_charge_amount?: number
          return_face_amount?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_return_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_return_items_invoice_item_id_fkey"
            columns: ["invoice_item_id"]
            isOneToOne: false
            referencedRelation: "global_invoice_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_return_items_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_return_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      global_shipment_accounting: {
        Row: {
          buy_cost_total: number
          gross_profit_total: number
          id: number
          parent_tenant_id: number
          refreshed_at: string
          sell_total: number
          shipment_id: number
          tenant_id: number
        }
        Insert: {
          buy_cost_total?: number
          gross_profit_total?: number
          id?: number
          parent_tenant_id: number
          refreshed_at?: string
          sell_total?: number
          shipment_id: number
          tenant_id: number
        }
        Update: {
          buy_cost_total?: number
          gross_profit_total?: number
          id?: number
          parent_tenant_id?: number
          refreshed_at?: string
          sell_total?: number
          shipment_id?: number
          tenant_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "global_shipment_accounting_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_accounting_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_accounting_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      global_shipment_boxes: {
        Row: {
          box_number: string
          created_at: string
          id: number
          parent_tenant_id: number
          shipment_id: number
          updated_at: string
          weight_kg: number
        }
        Insert: {
          box_number: string
          created_at?: string
          id?: number
          parent_tenant_id: number
          shipment_id: number
          updated_at?: string
          weight_kg: number
        }
        Update: {
          box_number?: string
          created_at?: string
          id?: number
          parent_tenant_id?: number
          shipment_id?: number
          updated_at?: string
          weight_kg?: number
        }
        Relationships: [
          {
            foreignKeyName: "global_shipment_boxes_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_boxes_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "global_shipments"
            referencedColumns: ["id"]
          },
        ]
      }
      global_shipment_items: {
        Row: {
          add_method: Database["public"]["Enums"]["global_shipment_item_add_method"]
          barcode: string | null
          created_at: string
          id: number
          image_url: string | null
          name: string
          ordered_quantity: number
          package_weight: number
          product_code: string | null
          product_id: number | null
          product_weight: number
          purchase_price: number
          shipment_id: number
          sort_order: number
          source_child_tenant_id: number | null
          source_id: number | null
          source_type: string | null
          updated_at: string
          vendor_id: number | null
        }
        Insert: {
          add_method?: Database["public"]["Enums"]["global_shipment_item_add_method"]
          barcode?: string | null
          created_at?: string
          id?: number
          image_url?: string | null
          name: string
          ordered_quantity: number
          package_weight?: number
          product_code?: string | null
          product_id?: number | null
          product_weight?: number
          purchase_price?: number
          shipment_id: number
          sort_order?: number
          source_child_tenant_id?: number | null
          source_id?: number | null
          source_type?: string | null
          updated_at?: string
          vendor_id?: number | null
        }
        Update: {
          add_method?: Database["public"]["Enums"]["global_shipment_item_add_method"]
          barcode?: string | null
          created_at?: string
          id?: number
          image_url?: string | null
          name?: string
          ordered_quantity?: number
          package_weight?: number
          product_code?: string | null
          product_id?: number | null
          product_weight?: number
          purchase_price?: number
          shipment_id?: number
          sort_order?: number
          source_child_tenant_id?: number | null
          source_id?: number | null
          source_type?: string | null
          updated_at?: string
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "global_shipment_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_items_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "global_shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_items_source_child_tenant_id_fkey"
            columns: ["source_child_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_items_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      global_shipments: {
        Row: {
          cargo_conversion_rate: number
          cargo_rate: number
          created_at: string
          id: number
          name: string
          parent_tenant_id: number
          product_conversion_rate: number
          received_weight: number | null
          shipment_cost_currency_id: number | null
          shipment_purchase_currency_id: number | null
          status: string
          stock_ready: boolean
          tenant_shipment_id: number | null
          transaction_rate: number | null
          type: Database["public"]["Enums"]["global_shipment_type"]
          updated_at: string
        }
        Insert: {
          cargo_conversion_rate?: number
          cargo_rate?: number
          created_at?: string
          id?: number
          name: string
          parent_tenant_id: number
          product_conversion_rate?: number
          received_weight?: number | null
          shipment_cost_currency_id?: number | null
          shipment_purchase_currency_id?: number | null
          status?: string
          stock_ready?: boolean
          tenant_shipment_id?: number | null
          transaction_rate?: number | null
          type?: Database["public"]["Enums"]["global_shipment_type"]
          updated_at?: string
        }
        Update: {
          cargo_conversion_rate?: number
          cargo_rate?: number
          created_at?: string
          id?: number
          name?: string
          parent_tenant_id?: number
          product_conversion_rate?: number
          received_weight?: number | null
          shipment_cost_currency_id?: number | null
          shipment_purchase_currency_id?: number | null
          status?: string
          stock_ready?: boolean
          tenant_shipment_id?: number | null
          transaction_rate?: number | null
          type?: Database["public"]["Enums"]["global_shipment_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_shipments_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipments_shipment_cost_currency_id_fkey"
            columns: ["shipment_cost_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipments_shipment_purchase_currency_id_fkey"
            columns: ["shipment_purchase_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
        ]
      }
      global_stock_allocations: {
        Row: {
          child_tenant_id: number
          created_at: string
          id: number
          parent_tenant_id: number
          quantity: number
          stock_id: number
          updated_at: string
        }
        Insert: {
          child_tenant_id: number
          created_at?: string
          id?: number
          parent_tenant_id: number
          quantity?: number
          stock_id: number
          updated_at?: string
        }
        Update: {
          child_tenant_id?: number
          created_at?: string
          id?: number
          parent_tenant_id?: number
          quantity?: number
          stock_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_stock_allocations_child_tenant_id_fkey"
            columns: ["child_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_stock_allocations_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_stock_allocations_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
        ]
      }
      global_stock_types: {
        Row: {
          created_at: string
          description: string
          id: number
          is_sellable: boolean
          parent_tenant_id: number | null
          sort_order: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          description: string
          id?: number
          is_sellable?: boolean
          parent_tenant_id?: number | null
          sort_order?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string
          id?: number
          is_sellable?: boolean
          parent_tenant_id?: number | null
          sort_order?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_stock_types_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      global_stocks: {
        Row: {
          created_at: string
          id: number
          is_usable: boolean
          parent_tenant_id: number
          quantity: number
          shipment_item_id: number
          stock_type_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_usable?: boolean
          parent_tenant_id: number
          quantity?: number
          shipment_item_id: number
          stock_type_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_usable?: boolean
          parent_tenant_id?: number
          quantity?: number
          shipment_item_id?: number
          stock_type_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_stocks_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_stocks_shipment_item_id_fkey"
            columns: ["shipment_item_id"]
            isOneToOne: false
            referencedRelation: "global_shipment_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_stocks_stock_type_id_fkey"
            columns: ["stock_type_id"]
            isOneToOne: false
            referencedRelation: "global_stock_types"
            referencedColumns: ["id"]
          },
        ]
      }
      investor_accounts: {
        Row: {
          created_at: string
          email: string
          id: number
          investor_id: number
          is_active: boolean
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          email: string
          id?: number
          investor_id: number
          is_active?: boolean
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          email?: string
          id?: number
          investor_id?: number
          is_active?: boolean
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "investor_accounts_investor_id_fkey"
            columns: ["investor_id"]
            isOneToOne: true
            referencedRelation: "investors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "investor_accounts_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      investor_balances: {
        Row: {
          available_balance: number
          created_at: string
          id: number
          investor_id: number
          tenant_id: number
          total_deposit: number
          total_invested_active: number
          total_profit_payout: number
          total_withdrawal: number
          updated_at: string
        }
        Insert: {
          available_balance?: number
          created_at?: string
          id?: number
          investor_id: number
          tenant_id: number
          total_deposit?: number
          total_invested_active?: number
          total_profit_payout?: number
          total_withdrawal?: number
          updated_at?: string
        }
        Update: {
          available_balance?: number
          created_at?: string
          id?: number
          investor_id?: number
          tenant_id?: number
          total_deposit?: number
          total_invested_active?: number
          total_profit_payout?: number
          total_withdrawal?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "investor_balances_investor_id_fkey"
            columns: ["investor_id"]
            isOneToOne: false
            referencedRelation: "investors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "investor_balances_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      investor_transactions: {
        Row: {
          amount: number
          created_at: string
          date: string
          id: number
          investor_id: number
          method: Database["public"]["Enums"]["investor_payment_method"]
          note: string | null
          tenant_id: number
          type: Database["public"]["Enums"]["investor_transaction_type"]
          updated_at: string
        }
        Insert: {
          amount: number
          created_at?: string
          date?: string
          id?: number
          investor_id: number
          method: Database["public"]["Enums"]["investor_payment_method"]
          note?: string | null
          tenant_id: number
          type: Database["public"]["Enums"]["investor_transaction_type"]
          updated_at?: string
        }
        Update: {
          amount?: number
          created_at?: string
          date?: string
          id?: number
          investor_id?: number
          method?: Database["public"]["Enums"]["investor_payment_method"]
          note?: string | null
          tenant_id?: number
          type?: Database["public"]["Enums"]["investor_transaction_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "investor_transactions_investor_id_fkey"
            columns: ["investor_id"]
            isOneToOne: false
            referencedRelation: "investors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "investor_transactions_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      investors: {
        Row: {
          address: string | null
          created_at: string
          email: string | null
          id: number
          name: string
          phone: string | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          email?: string | null
          id?: number
          name: string
          phone?: string | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          email?: string | null
          id?: number
          name?: string
          phone?: string | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "investors_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_boxes: {
        Row: {
          box_number: string
          created_at: string
          id: number
          invoice_id: number
          tenant_id: number
          updated_at: string
          weight: number
        }
        Insert: {
          box_number: string
          created_at?: string
          id?: number
          invoice_id: number
          tenant_id: number
          updated_at?: string
          weight: number
        }
        Update: {
          box_number?: string
          created_at?: string
          id?: number
          invoice_id?: number
          tenant_id?: number
          updated_at?: string
          weight?: number
        }
        Relationships: [
          {
            foreignKeyName: "invoice_boxes_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_brands: {
        Row: {
          address: string
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          address: string
          created_at?: string
          id?: number
          name: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          address?: string
          created_at?: string
          id?: number
          name?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "invoice_brands_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_charge_lines: {
        Row: {
          amount: number
          charge_type: Database["public"]["Enums"]["invoice_charge_type"]
          created_at: string
          id: number
          invoice_id: number
          note: string | null
          parent_tenant_id: number
          posted_to_ledger: boolean
          tenant_id: number
          updated_at: string
        }
        Insert: {
          amount?: number
          charge_type: Database["public"]["Enums"]["invoice_charge_type"]
          created_at?: string
          id?: number
          invoice_id: number
          note?: string | null
          parent_tenant_id: number
          posted_to_ledger?: boolean
          tenant_id: number
          updated_at?: string
        }
        Update: {
          amount?: number
          charge_type?: Database["public"]["Enums"]["invoice_charge_type"]
          created_at?: string
          id?: number
          invoice_id?: number
          note?: string | null
          parent_tenant_id?: number
          posted_to_ledger?: boolean
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "invoice_charge_lines_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_charge_lines_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_charge_lines_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      item_assignees: {
        Row: {
          assigned_by_email: string
          created_at: string
          id: number
          item_id: number
          user_email: string
        }
        Insert: {
          assigned_by_email?: string
          created_at?: string
          id?: number
          item_id: number
          user_email: string
        }
        Update: {
          assigned_by_email?: string
          created_at?: string
          id?: number
          item_id?: number
          user_email?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_assignees_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      item_permissions: {
        Row: {
          created_at: string
          id: number
          item_id: number
          role: string
          user_email: string
        }
        Insert: {
          created_at?: string
          id?: number
          item_id: number
          role: string
          user_email: string
        }
        Update: {
          created_at?: string
          id?: number
          item_id?: number
          role?: string
          user_email?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_permissions_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      item_tags: {
        Row: {
          created_at: string
          id: number
          item_id: number
          tag_id: number
        }
        Insert: {
          created_at?: string
          id?: number
          item_id: number
          tag_id: number
        }
        Update: {
          created_at?: string
          id?: number
          item_id?: number
          tag_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "item_tags_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_tags_tag_id_fkey"
            columns: ["tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
        ]
      }
      items: {
        Row: {
          accessibility: string
          archived_at: string | null
          content: string | null
          created_at: string
          created_by_email: string
          due_date: string | null
          id: number
          is_markdown: boolean
          parent_id: number | null
          priority: string
          start_date: string | null
          status: string
          tenant_id: number | null
          title: string
          type: string
          updated_at: string
        }
        Insert: {
          accessibility?: string
          archived_at?: string | null
          content?: string | null
          created_at?: string
          created_by_email?: string
          due_date?: string | null
          id?: number
          is_markdown?: boolean
          parent_id?: number | null
          priority?: string
          start_date?: string | null
          status?: string
          tenant_id?: number | null
          title: string
          type: string
          updated_at?: string
        }
        Update: {
          accessibility?: string
          archived_at?: string | null
          content?: string | null
          created_at?: string
          created_by_email?: string
          due_date?: string | null
          id?: number
          is_markdown?: boolean
          parent_id?: number | null
          priority?: string
          start_date?: string | null
          status?: string
          tenant_id?: number | null
          title?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "items_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      koba_brands: {
        Row: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          name: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          name?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "koba_brands_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      koba_cart_items: {
        Row: {
          barcode: string | null
          brand: string | null
          cart_id: number
          case_size: number
          commission: number | null
          commission_percentage: number | null
          created_at: string
          custom_price_gbp: number | null
          id: number
          image_url: string | null
          koba_product_id: string | null
          name: string
          product_code: string | null
          product_id: string
          quantity: number
          unit_price_gbp: number | null
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          brand?: string | null
          cart_id: number
          case_size?: number
          commission?: number | null
          commission_percentage?: number | null
          created_at?: string
          custom_price_gbp?: number | null
          id?: number
          image_url?: string | null
          koba_product_id?: string | null
          name: string
          product_code?: string | null
          product_id: string
          quantity?: number
          unit_price_gbp?: number | null
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          brand?: string | null
          cart_id?: number
          case_size?: number
          commission?: number | null
          commission_percentage?: number | null
          created_at?: string
          custom_price_gbp?: number | null
          id?: number
          image_url?: string | null
          koba_product_id?: string | null
          name?: string
          product_code?: string | null
          product_id?: string
          quantity?: number
          unit_price_gbp?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "koba_cart_items_cart_id_fkey"
            columns: ["cart_id"]
            isOneToOne: false
            referencedRelation: "koba_carts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "koba_cart_items_koba_product_id_fkey"
            columns: ["koba_product_id"]
            isOneToOne: false
            referencedRelation: "koba_products"
            referencedColumns: ["id"]
          },
        ]
      }
      koba_carts: {
        Row: {
          created_at: string
          customer_group_id: number | null
          id: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          customer_group_id?: number | null
          id?: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          customer_group_id?: number | null
          id?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "koba_carts_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "koba_carts_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      koba_categories: {
        Row: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          name: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          name?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "koba_categories_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      koba_order_items: {
        Row: {
          barcode: string | null
          brand: string | null
          case_size: number
          commission: number | null
          commission_percentage: number | null
          confirmed_quantity: number | null
          created_at: string
          delivered_quantity: number
          id: number
          image_url: string | null
          name: string
          order_id: number
          product_code: string | null
          product_id: string
          quantity: number
          unit_price_gbp: number | null
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          brand?: string | null
          case_size?: number
          commission?: number | null
          commission_percentage?: number | null
          confirmed_quantity?: number | null
          created_at?: string
          delivered_quantity?: number
          id?: number
          image_url?: string | null
          name: string
          order_id: number
          product_code?: string | null
          product_id: string
          quantity?: number
          unit_price_gbp?: number | null
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          brand?: string | null
          case_size?: number
          commission?: number | null
          commission_percentage?: number | null
          confirmed_quantity?: number | null
          created_at?: string
          delivered_quantity?: number
          id?: number
          image_url?: string | null
          name?: string
          order_id?: number
          product_code?: string | null
          product_id?: string
          quantity?: number
          unit_price_gbp?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "koba_order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "koba_orders"
            referencedColumns: ["id"]
          },
        ]
      }
      koba_orders: {
        Row: {
          cod_charge: number | null
          created_at: string
          customer_group_id: number | null
          delivery_adjustment: number | null
          extra_profit_company: number | null
          extra_profit_user: number | null
          free_delivery: boolean
          id: number
          invoice_charge: number | null
          item_count: number
          net_order_commission: number | null
          note: string | null
          packing_charge: number | null
          shipping_address: string | null
          shipping_district: string | null
          shipping_name: string | null
          shipping_phone: string | null
          shipping_thana: string | null
          status: Database["public"]["Enums"]["koba_order_status"]
          subtotal_gbp: number | null
          tenant_id: number
          total_commission: number | null
          updated_at: string
          user_name: string | null
        }
        Insert: {
          cod_charge?: number | null
          created_at?: string
          customer_group_id?: number | null
          delivery_adjustment?: number | null
          extra_profit_company?: number | null
          extra_profit_user?: number | null
          free_delivery?: boolean
          id?: number
          invoice_charge?: number | null
          item_count?: number
          net_order_commission?: number | null
          note?: string | null
          packing_charge?: number | null
          shipping_address?: string | null
          shipping_district?: string | null
          shipping_name?: string | null
          shipping_phone?: string | null
          shipping_thana?: string | null
          status?: Database["public"]["Enums"]["koba_order_status"]
          subtotal_gbp?: number | null
          tenant_id: number
          total_commission?: number | null
          updated_at?: string
          user_name?: string | null
        }
        Update: {
          cod_charge?: number | null
          created_at?: string
          customer_group_id?: number | null
          delivery_adjustment?: number | null
          extra_profit_company?: number | null
          extra_profit_user?: number | null
          free_delivery?: boolean
          id?: number
          invoice_charge?: number | null
          item_count?: number
          net_order_commission?: number | null
          note?: string | null
          packing_charge?: number | null
          shipping_address?: string | null
          shipping_district?: string | null
          shipping_name?: string | null
          shipping_phone?: string | null
          shipping_thana?: string | null
          status?: Database["public"]["Enums"]["koba_order_status"]
          subtotal_gbp?: number | null
          tenant_id?: number
          total_commission?: number | null
          updated_at?: string
          user_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "koba_orders_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "koba_orders_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      koba_products: {
        Row: {
          barcode: string | null
          brand_id: number | null
          category_id: number | null
          commission: number | null
          commission_percentage: number | null
          created_at: string
          currency: string | null
          description: string | null
          id: string
          image_url: string | null
          in_stock: boolean
          name: string
          permalink: string | null
          price: number
          raw_data: Json
          regular_price: number | null
          sale_price: number | null
          sku: string | null
          slug: string | null
          source_id: string
          source_type: string
          stock_quantity: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          brand_id?: number | null
          category_id?: number | null
          commission?: number | null
          commission_percentage?: number | null
          created_at?: string
          currency?: string | null
          description?: string | null
          id?: string
          image_url?: string | null
          in_stock?: boolean
          name: string
          permalink?: string | null
          price?: number
          raw_data: Json
          regular_price?: number | null
          sale_price?: number | null
          sku?: string | null
          slug?: string | null
          source_id: string
          source_type: string
          stock_quantity?: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          brand_id?: number | null
          category_id?: number | null
          commission?: number | null
          commission_percentage?: number | null
          created_at?: string
          currency?: string | null
          description?: string | null
          id?: string
          image_url?: string | null
          in_stock?: boolean
          name?: string
          permalink?: string | null
          price?: number
          raw_data?: Json
          regular_price?: number | null
          sale_price?: number | null
          sku?: string | null
          slug?: string | null
          source_id?: string
          source_type?: string
          stock_quantity?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "koba_products_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "koba_brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "koba_products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "koba_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "koba_products_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      koba_retail_settings: {
        Row: {
          cod_charge_pct: number | null
          created_at: string | null
          delivery_rates: Json | null
          extra_profit_company_pct: number | null
          extra_profit_user_pct: number | null
          gateway_charge_flat: number | null
          id: number
          invoice_charge_flat: number | null
          packing_charge_flat: number | null
          tenant_id: number
          updated_at: string | null
        }
        Insert: {
          cod_charge_pct?: number | null
          created_at?: string | null
          delivery_rates?: Json | null
          extra_profit_company_pct?: number | null
          extra_profit_user_pct?: number | null
          gateway_charge_flat?: number | null
          id?: number
          invoice_charge_flat?: number | null
          packing_charge_flat?: number | null
          tenant_id: number
          updated_at?: string | null
        }
        Update: {
          cod_charge_pct?: number | null
          created_at?: string | null
          delivery_rates?: Json | null
          extra_profit_company_pct?: number | null
          extra_profit_user_pct?: number | null
          gateway_charge_flat?: number | null
          id?: number
          invoice_charge_flat?: number | null
          packing_charge_flat?: number | null
          tenant_id?: number
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "koba_retail_settings_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: true
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      markets: {
        Row: {
          code: string
          created_at: string
          id: number
          is_active: boolean
          is_system: boolean
          name: string
          region: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          name: string
          region: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          name?: string
          region?: string
          updated_at?: string
        }
        Relationships: []
      }
      memberships: {
        Row: {
          accent_color: string | null
          created_at: string
          email: string
          id: number
          is_active: boolean
          role: Database["public"]["Enums"]["app_role"]
          tenant_id: number | null
          updated_at: string
        }
        Insert: {
          accent_color?: string | null
          created_at?: string
          email: string
          id?: number
          is_active?: boolean
          role: Database["public"]["Enums"]["app_role"]
          tenant_id?: number | null
          updated_at?: string
        }
        Update: {
          accent_color?: string | null
          created_at?: string
          email?: string
          id?: number
          is_active?: boolean
          role?: Database["public"]["Enums"]["app_role"]
          tenant_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "memberships_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      modules: {
        Row: {
          created_at: string
          description: string | null
          id: number
          is_active: boolean
          key: string
          name: string
          parent_module_key: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: number
          is_active?: boolean
          key: string
          name: string
          parent_module_key?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: number
          is_active?: boolean
          key?: string
          name?: string
          parent_module_key?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "modules_parent_module_key_fkey"
            columns: ["parent_module_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
          },
        ]
      }
      order_items: {
        Row: {
          barcode: string | null
          cost_bdt: number | null
          cost_gbp: number | null
          created_at: string
          customer_offer_bdt: number | null
          delivered_quantity: number
          final_offer_bdt: number | null
          first_offer_bdt: number | null
          id: number
          image_url: string | null
          minimum_quantity: number
          name: string
          order_id: number
          ordered_quantity: number
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number | null
          product_weight: number | null
          returned_quantity: number
          shipment_id: number | null
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          cost_bdt?: number | null
          cost_gbp?: number | null
          created_at?: string
          customer_offer_bdt?: number | null
          delivered_quantity?: number
          final_offer_bdt?: number | null
          first_offer_bdt?: number | null
          id?: number
          image_url?: string | null
          minimum_quantity?: number
          name: string
          order_id: number
          ordered_quantity?: number
          package_weight?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_id?: number | null
          product_weight?: number | null
          returned_quantity?: number
          shipment_id?: number | null
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          cost_bdt?: number | null
          cost_gbp?: number | null
          created_at?: string
          customer_offer_bdt?: number | null
          delivered_quantity?: number
          final_offer_bdt?: number | null
          first_offer_bdt?: number | null
          id?: number
          image_url?: string | null
          minimum_quantity?: number
          name?: string
          order_id?: number
          ordered_quantity?: number
          package_weight?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_id?: number | null
          product_weight?: number | null
          returned_quantity?: number
          shipment_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          accent_color: string | null
          can_see_price: boolean
          cargo_rate: number | null
          conversion_rate: number | null
          created_at: string
          customer_group_id: number
          id: number
          invoice_id: number | null
          name: string
          negotiate: boolean
          parent_tenant_id: number | null
          profit_rate: number | null
          status: Database["public"]["Enums"]["order_status"]
          store_id: number | null
          tenant_id: number
          tenant_order_id: number
          updated_at: string
        }
        Insert: {
          accent_color?: string | null
          can_see_price?: boolean
          cargo_rate?: number | null
          conversion_rate?: number | null
          created_at?: string
          customer_group_id: number
          id?: number
          invoice_id?: number | null
          name: string
          negotiate?: boolean
          parent_tenant_id?: number | null
          profit_rate?: number | null
          status?: Database["public"]["Enums"]["order_status"]
          store_id?: number | null
          tenant_id: number
          tenant_order_id: number
          updated_at?: string
        }
        Update: {
          accent_color?: string | null
          can_see_price?: boolean
          cargo_rate?: number | null
          conversion_rate?: number | null
          created_at?: string
          customer_group_id?: number
          id?: number
          invoice_id?: number | null
          name?: string
          negotiate?: boolean
          parent_tenant_id?: number | null
          profit_rate?: number | null
          status?: Database["public"]["Enums"]["order_status"]
          store_id?: number | null
          tenant_id?: number
          tenant_order_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "orders_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_allocations: {
        Row: {
          amount: number
          commerce_invoice_id: number | null
          created_at: string
          global_invoice_id: number | null
          id: number
          invoice_id: number | null
          payment_id: number
          tenant_id: number
        }
        Insert: {
          amount: number
          commerce_invoice_id?: number | null
          created_at?: string
          global_invoice_id?: number | null
          id?: number
          invoice_id?: number | null
          payment_id: number
          tenant_id: number
        }
        Update: {
          amount?: number
          commerce_invoice_id?: number | null
          created_at?: string
          global_invoice_id?: number | null
          id?: number
          invoice_id?: number | null
          payment_id?: number
          tenant_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "payment_allocations_commerce_invoice_id_fkey"
            columns: ["commerce_invoice_id"]
            isOneToOne: false
            referencedRelation: "commerce_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_allocations_global_invoice_id_fkey"
            columns: ["global_invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_allocations_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_allocations_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_methods: {
        Row: {
          category: string
          code: string
          created_at: string
          id: number
          is_active: boolean
          is_system: boolean
          name: string
          scope: string
          sort_order: number
          updated_at: string
        }
        Insert: {
          category: string
          code: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          name: string
          scope: string
          sort_order?: number
          updated_at?: string
        }
        Update: {
          category?: string
          code?: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          name?: string
          scope?: string
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      payments: {
        Row: {
          amount: number
          billing_profile_id: number
          created_at: string
          id: number
          method: string | null
          note: string | null
          payment_date: string
          reference: string | null
          tenant_id: number
        }
        Insert: {
          amount: number
          billing_profile_id: number
          created_at?: string
          id?: number
          method?: string | null
          note?: string | null
          payment_date?: string
          reference?: string | null
          tenant_id: number
        }
        Update: {
          amount?: number
          billing_profile_id?: number
          created_at?: string
          id?: number
          method?: string | null
          note?: string | null
          payment_date?: string
          reference?: string | null
          tenant_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "payments_billing_profile_id_fkey"
            columns: ["billing_profile_id"]
            isOneToOne: false
            referencedRelation: "billing_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      product_based_costing_files: {
        Row: {
          cargo_rate_kg_gbp: number | null
          conversion_rate: number | null
          created_at: string
          default_shipment_id: number | null
          id: number
          invoice_id: number | null
          market_code: string | null
          name: string | null
          note: string | null
          order_for: string | null
          profit_rate: number | null
          status: string | null
          tenant_id: number | null
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
        }
        Insert: {
          cargo_rate_kg_gbp?: number | null
          conversion_rate?: number | null
          created_at?: string
          default_shipment_id?: number | null
          id?: number
          invoice_id?: number | null
          market_code?: string | null
          name?: string | null
          note?: string | null
          order_for?: string | null
          profit_rate?: number | null
          status?: string | null
          tenant_id?: number | null
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Update: {
          cargo_rate_kg_gbp?: number | null
          conversion_rate?: number | null
          created_at?: string
          default_shipment_id?: number | null
          id?: number
          invoice_id?: number | null
          market_code?: string | null
          name?: string | null
          note?: string | null
          order_for?: string | null
          profit_rate?: number | null
          status?: string | null
          tenant_id?: number | null
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "product_based_costing_files_default_shipment_id_fkey"
            columns: ["default_shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_files_market_code_fkey"
            columns: ["market_code"]
            isOneToOne: false
            referencedRelation: "markets"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "product_based_costing_files_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_files_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      product_based_costing_items: {
        Row: {
          assigned_shipment_id: number | null
          barcode: string | null
          brand: string | null
          created_at: string
          delivered_quantity: number | null
          id: number
          image_url: string | null
          input_type: string | null
          market_code: string | null
          name: string | null
          note: string | null
          offer_price: number | null
          package_weight: number | null
          price_gbp: number | null
          product_based_costing_file_id: number | null
          product_code: string | null
          product_id: number | null
          product_weight: number | null
          quantity: number | null
          status: string | null
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
          web_link: string | null
        }
        Insert: {
          assigned_shipment_id?: number | null
          barcode?: string | null
          brand?: string | null
          created_at?: string
          delivered_quantity?: number | null
          id?: number
          image_url?: string | null
          input_type?: string | null
          market_code?: string | null
          name?: string | null
          note?: string | null
          offer_price?: number | null
          package_weight?: number | null
          price_gbp?: number | null
          product_based_costing_file_id?: number | null
          product_code?: string | null
          product_id?: number | null
          product_weight?: number | null
          quantity?: number | null
          status?: string | null
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
          web_link?: string | null
        }
        Update: {
          assigned_shipment_id?: number | null
          barcode?: string | null
          brand?: string | null
          created_at?: string
          delivered_quantity?: number | null
          id?: number
          image_url?: string | null
          input_type?: string | null
          market_code?: string | null
          name?: string | null
          note?: string | null
          offer_price?: number | null
          package_weight?: number | null
          price_gbp?: number | null
          product_based_costing_file_id?: number | null
          product_code?: string | null
          product_id?: number | null
          product_weight?: number | null
          quantity?: number | null
          status?: string | null
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
          web_link?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_product_based_costing_items_product"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_items_assigned_shipment_id_fkey"
            columns: ["assigned_shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_items_product_based_costing_file_id_fkey"
            columns: ["product_based_costing_file_id"]
            isOneToOne: false
            referencedRelation: "product_based_costing_files"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_items_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      product_brands: {
        Row: {
          created_at: string
          id: number
          name: string
          parent_tenant_id: number | null
          tenant_id: number | null
          updated_at: string
          value: string | null
          vendor_code: string | null
          vendor_id: number | null
        }
        Insert: {
          created_at?: string
          id?: number
          name: string
          parent_tenant_id?: number | null
          tenant_id?: number | null
          updated_at?: string
          value?: string | null
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Update: {
          created_at?: string
          id?: number
          name?: string
          parent_tenant_id?: number | null
          tenant_id?: number | null
          updated_at?: string
          value?: string | null
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "product_brands_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_brands_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_brands_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      product_categories: {
        Row: {
          created_at: string
          id: number
          name: string
          parent_tenant_id: number | null
          tenant_id: number | null
          updated_at: string
          value: string | null
          vendor_code: string | null
          vendor_id: number | null
        }
        Insert: {
          created_at?: string
          id?: number
          name: string
          parent_tenant_id?: number | null
          tenant_id?: number | null
          updated_at?: string
          value?: string | null
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Update: {
          created_at?: string
          id?: number
          name?: string
          parent_tenant_id?: number | null
          tenant_id?: number | null
          updated_at?: string
          value?: string | null
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "product_categories_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_categories_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_categories_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      product_sync_snapshots: {
        Row: {
          barcode: string | null
          captured_at: string
          expires_at: string
          id: number
          market_code: string
          product_code: string | null
          product_id: number
          row_data: Json
          run_id: string
          tenant_id: number | null
          vendor_code: string
          vendor_id: number | null
        }
        Insert: {
          barcode?: string | null
          captured_at?: string
          expires_at: string
          id?: number
          market_code: string
          product_code?: string | null
          product_id: number
          row_data: Json
          run_id: string
          tenant_id?: number | null
          vendor_code: string
          vendor_id?: number | null
        }
        Update: {
          barcode?: string | null
          captured_at?: string
          expires_at?: string
          id?: number
          market_code?: string
          product_code?: string | null
          product_id?: number
          row_data?: Json
          run_id?: string
          tenant_id?: number | null
          vendor_code?: string
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "product_sync_snapshots_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          available_units: number | null
          barcode: string | null
          batch_code_manufacture_date: string | null
          brand: string | null
          category: string | null
          country_of_origin: string | null
          created_at: string
          expire_date: string | null
          hazardous: boolean | null
          id: number
          image_url: string | null
          is_available: boolean | null
          languages: string | null
          market_code: string | null
          minimum_order_quantity: number | null
          name: string | null
          package_weight: number | null
          parent_tenant_id: number | null
          price_gbp: number | null
          product_code: string | null
          product_weight: number | null
          source: string | null
          tariff_code: string | null
          tenant_id: number | null
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
        }
        Insert: {
          available_units?: number | null
          barcode?: string | null
          batch_code_manufacture_date?: string | null
          brand?: string | null
          category?: string | null
          country_of_origin?: string | null
          created_at?: string
          expire_date?: string | null
          hazardous?: boolean | null
          id?: number
          image_url?: string | null
          is_available?: boolean | null
          languages?: string | null
          market_code?: string | null
          minimum_order_quantity?: number | null
          name?: string | null
          package_weight?: number | null
          parent_tenant_id?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_weight?: number | null
          source?: string | null
          tariff_code?: string | null
          tenant_id?: number | null
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Update: {
          available_units?: number | null
          barcode?: string | null
          batch_code_manufacture_date?: string | null
          brand?: string | null
          category?: string | null
          country_of_origin?: string | null
          created_at?: string
          expire_date?: string | null
          hazardous?: boolean | null
          id?: number
          image_url?: string | null
          is_available?: boolean | null
          languages?: string | null
          market_code?: string | null
          minimum_order_quantity?: number | null
          name?: string | null
          package_weight?: number | null
          parent_tenant_id?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_weight?: number | null
          source?: string | null
          tariff_code?: string | null
          tenant_id?: number | null
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "products_market_code_fkey"
            columns: ["market_code"]
            isOneToOne: false
            referencedRelation: "markets"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "products_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      shipment_investments: {
        Row: {
          actual_profit: number
          allocated_cost: number
          computed_profit: number
          cost_share_pct: number | null
          created_at: string
          id: number
          invested_amount: number
          investor_id: number
          profit_status: string
          shipment_id: number
          status: Database["public"]["Enums"]["shipment_investment_status"]
          tenant_id: number
          updated_at: string
        }
        Insert: {
          actual_profit?: number
          allocated_cost?: number
          computed_profit?: number
          cost_share_pct?: number | null
          created_at?: string
          id?: number
          invested_amount?: number
          investor_id: number
          profit_status?: string
          shipment_id: number
          status?: Database["public"]["Enums"]["shipment_investment_status"]
          tenant_id: number
          updated_at?: string
        }
        Update: {
          actual_profit?: number
          allocated_cost?: number
          computed_profit?: number
          cost_share_pct?: number | null
          created_at?: string
          id?: number
          invested_amount?: number
          investor_id?: number
          profit_status?: string
          shipment_id?: number
          status?: Database["public"]["Enums"]["shipment_investment_status"]
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipment_investments_investor_id_fkey"
            columns: ["investor_id"]
            isOneToOne: false
            referencedRelation: "investors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_investments_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_investments_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      shipment_items: {
        Row: {
          barcode: string | null
          cost_bdt: number | null
          created_at: string
          id: number
          image_url: string | null
          inspected: boolean
          marker_tag: string | null
          method: string
          name: string | null
          order_id: number | null
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number | null
          product_weight: number | null
          quantity: number
          receiving_splits: Json | null
          shipment_id: number
          sort_order: number
          source_child_tenant_id: number | null
          source_id: number | null
          source_type: string | null
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          cost_bdt?: number | null
          created_at?: string
          id?: number
          image_url?: string | null
          inspected?: boolean
          marker_tag?: string | null
          method?: string
          name?: string | null
          order_id?: number | null
          package_weight?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_id?: number | null
          product_weight?: number | null
          quantity?: number
          receiving_splits?: Json | null
          shipment_id: number
          sort_order?: number
          source_child_tenant_id?: number | null
          source_id?: number | null
          source_type?: string | null
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          cost_bdt?: number | null
          created_at?: string
          id?: number
          image_url?: string | null
          inspected?: boolean
          marker_tag?: string | null
          method?: string
          name?: string | null
          order_id?: number | null
          package_weight?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_id?: number | null
          product_weight?: number | null
          quantity?: number
          receiving_splits?: Json | null
          shipment_id?: number
          sort_order?: number
          source_child_tenant_id?: number | null
          source_id?: number | null
          source_type?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipment_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_items_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_items_source_child_tenant_id_fkey"
            columns: ["source_child_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      shipments: {
        Row: {
          cargo_conversion_rate: number | null
          cargo_rate: number | null
          created_at: string
          id: number
          inventory_added: boolean
          market_code: string | null
          name: string
          product_conversion_rate: number | null
          received_weight: number | null
          shipment_type: string
          status: string
          tenant_id: number
          tenant_shipment_id: number
          transaction_rate: number | null
          updated_at: string
        }
        Insert: {
          cargo_conversion_rate?: number | null
          cargo_rate?: number | null
          created_at?: string
          id?: number
          inventory_added?: boolean
          market_code?: string | null
          name: string
          product_conversion_rate?: number | null
          received_weight?: number | null
          shipment_type?: string
          status?: string
          tenant_id: number
          tenant_shipment_id: number
          transaction_rate?: number | null
          updated_at?: string
        }
        Update: {
          cargo_conversion_rate?: number | null
          cargo_rate?: number | null
          created_at?: string
          id?: number
          inventory_added?: boolean
          market_code?: string | null
          name?: string
          product_conversion_rate?: number | null
          received_weight?: number | null
          shipment_type?: string
          status?: string
          tenant_id?: number
          tenant_shipment_id?: number
          transaction_rate?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipments_market_code_fkey"
            columns: ["market_code"]
            isOneToOne: false
            referencedRelation: "markets"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "shipments_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      store_access: {
        Row: {
          created_at: string
          customer_group_id: number
          id: number
          see_price: boolean
          status: boolean
          store_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          customer_group_id: number
          id?: number
          see_price?: boolean
          status?: boolean
          store_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          customer_group_id?: number
          id?: number
          see_price?: boolean
          status?: boolean
          store_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "store_access_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "store_access_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      store_product_prices: {
        Row: {
          created_at: string
          global_stock_id: number | null
          id: number
          inventory_item_id: number | null
          is_active: boolean
          minimum_sell_price_bdt: number
          price_bdt: number
          product_id: number | null
          stock_override: number | null
          store_id: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          global_stock_id?: number | null
          id?: number
          inventory_item_id?: number | null
          is_active?: boolean
          minimum_sell_price_bdt: number
          price_bdt: number
          product_id?: number | null
          stock_override?: number | null
          store_id: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          global_stock_id?: number | null
          id?: number
          inventory_item_id?: number | null
          is_active?: boolean
          minimum_sell_price_bdt?: number
          price_bdt?: number
          product_id?: number | null
          stock_override?: number | null
          store_id?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "store_product_prices_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "store_product_prices_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "store_product_prices_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      stores: {
        Row: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
        }
        Insert: {
          created_at?: string
          id?: number
          name: string
          tenant_id: number
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Update: {
          created_at?: string
          id?: number
          name?: string
          tenant_id?: number
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "stores_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stores_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      tags: {
        Row: {
          color: string
          created_at: string
          created_by_email: string
          id: number
          name: string
          slug: string
          tenant_id: number | null
          type: string
        }
        Insert: {
          color?: string
          created_at?: string
          created_by_email?: string
          id?: number
          name: string
          slug: string
          tenant_id?: number | null
          type?: string
        }
        Update: {
          color?: string
          created_at?: string
          created_by_email?: string
          id?: number
          name?: string
          slug?: string
          tenant_id?: number | null
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "tags_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      tenant_module_submodules: {
        Row: {
          created_at: string
          id: number
          is_enabled: boolean
          parent_module_key: string
          submodule_key: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_enabled?: boolean
          parent_module_key: string
          submodule_key: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_enabled?: boolean
          parent_module_key?: string
          submodule_key?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenant_module_submodules_parent_module_key_fkey"
            columns: ["parent_module_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "tenant_module_submodules_submodule_key_fkey"
            columns: ["submodule_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "tenant_module_submodules_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      tenant_modules: {
        Row: {
          created_at: string
          id: number
          is_active: boolean
          module_key: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_active?: boolean
          module_key: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_active?: boolean
          module_key?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenant_modules_module_key_fkey"
            columns: ["module_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "tenant_modules_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      tenant_scoped_counters: {
        Row: {
          created_at: string
          last_value: number
          scope: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          last_value?: number
          scope: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          last_value?: number
          scope?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenant_scoped_counters_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      tenants: {
        Row: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number | null
          preference: Json
          public_domain: string | null
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_active?: boolean
          name: string
          parent_id?: number | null
          preference?: Json
          public_domain?: string | null
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_active?: boolean
          name?: string
          parent_id?: number | null
          preference?: Json
          public_domain?: string | null
          slug?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenants_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_accounting_ledger: {
        Row: {
          amount: number
          created_at: string
          date: string
          id: number
          inserted_by: string
          note: string | null
          reference_id: number
          source: Database["public"]["Enums"]["thrift_ledger_source"]
          tenant_id: number
          type: Database["public"]["Enums"]["thrift_ledger_type"]
          updated_at: string
        }
        Insert: {
          amount: number
          created_at?: string
          date?: string
          id?: number
          inserted_by: string
          note?: string | null
          reference_id: number
          source: Database["public"]["Enums"]["thrift_ledger_source"]
          tenant_id: number
          type: Database["public"]["Enums"]["thrift_ledger_type"]
          updated_at?: string
        }
        Update: {
          amount?: number
          created_at?: string
          date?: string
          id?: number
          inserted_by?: string
          note?: string | null
          reference_id?: number
          source?: Database["public"]["Enums"]["thrift_ledger_source"]
          tenant_id?: number
          type?: Database["public"]["Enums"]["thrift_ledger_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_accounting_ledger_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_barcodes: {
        Row: {
          barcode_id: string
          created_at: string
          id: number
          inserted_by: string
          is_printed: number
          status: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          barcode_id: string
          created_at?: string
          id?: number
          inserted_by: string
          is_printed?: number
          status?: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          barcode_id?: string
          created_at?: string
          id?: number
          inserted_by?: string
          is_printed?: number
          status?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_barcodes_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_boxes: {
        Row: {
          created_at: string
          id: number
          inserted_by: string
          name: string
          received_weight: number | null
          shipment_id: number
          tenant_id: number
          updated_at: string
          weight: number | null
        }
        Insert: {
          created_at?: string
          id?: number
          inserted_by: string
          name: string
          received_weight?: number | null
          shipment_id: number
          tenant_id: number
          updated_at?: string
          weight?: number | null
        }
        Update: {
          created_at?: string
          id?: number
          inserted_by?: string
          name?: string
          received_weight?: number | null
          shipment_id?: number
          tenant_id?: number
          updated_at?: string
          weight?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "thrift_boxes_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "thrift_shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_boxes_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_categories: {
        Row: {
          created_at: string
          description: string | null
          id: number
          inserted_by: string
          is_global: boolean
          name: string
          tenant_id: number | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: number
          inserted_by: string
          is_global?: boolean
          name: string
          tenant_id?: number | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: number
          inserted_by?: string
          is_global?: boolean
          name?: string
          tenant_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_categories_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_invoice_items: {
        Row: {
          created_at: string
          id: number
          invoice_id: number
          item_status: Database["public"]["Enums"]["thrift_item_status"]
          net_profit: number
          platform_fees: number
          quantity: number
          return_action:
            | Database["public"]["Enums"]["thrift_return_action"]
            | null
          return_cost_charged_to_customer: number
          return_cost_paid_by_shop: number
          return_reason: string | null
          shipping_cost_paid_by_shop: number
          sold_price: number
          stock_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          invoice_id: number
          item_status?: Database["public"]["Enums"]["thrift_item_status"]
          net_profit?: number
          platform_fees?: number
          quantity: number
          return_action?:
            | Database["public"]["Enums"]["thrift_return_action"]
            | null
          return_cost_charged_to_customer?: number
          return_cost_paid_by_shop?: number
          return_reason?: string | null
          shipping_cost_paid_by_shop?: number
          sold_price?: number
          stock_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          invoice_id?: number
          item_status?: Database["public"]["Enums"]["thrift_item_status"]
          net_profit?: number
          platform_fees?: number
          quantity?: number
          return_action?:
            | Database["public"]["Enums"]["thrift_return_action"]
            | null
          return_cost_charged_to_customer?: number
          return_cost_paid_by_shop?: number
          return_reason?: string | null
          shipping_cost_paid_by_shop?: number
          sold_price?: number
          stock_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "thrift_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_invoice_items_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: false
            referencedRelation: "thrift_stocks"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_invoices: {
        Row: {
          address: string
          cod_charge: number
          created_at: string
          delivery_status: Database["public"]["Enums"]["thrift_delivery_status"]
          id: number
          inserted_by: string
          invoice_number: string
          invoice_print_charge: number
          packing_charge: number
          payment_status: Database["public"]["Enums"]["thrift_payment_status"]
          phone: string
          recipient_name: string
          shipping_charge_customer: number
          tenant_id: number
          total_invoice_amount: number
          transaction_method: Database["public"]["Enums"]["thrift_transaction_method"]
          updated_at: string
        }
        Insert: {
          address: string
          cod_charge?: number
          created_at?: string
          delivery_status?: Database["public"]["Enums"]["thrift_delivery_status"]
          id?: number
          inserted_by: string
          invoice_number: string
          invoice_print_charge?: number
          packing_charge?: number
          payment_status?: Database["public"]["Enums"]["thrift_payment_status"]
          phone: string
          recipient_name: string
          shipping_charge_customer?: number
          tenant_id: number
          total_invoice_amount?: number
          transaction_method: Database["public"]["Enums"]["thrift_transaction_method"]
          updated_at?: string
        }
        Update: {
          address?: string
          cod_charge?: number
          created_at?: string
          delivery_status?: Database["public"]["Enums"]["thrift_delivery_status"]
          id?: number
          inserted_by?: string
          invoice_number?: string
          invoice_print_charge?: number
          packing_charge?: number
          payment_status?: Database["public"]["Enums"]["thrift_payment_status"]
          phone?: string
          recipient_name?: string
          shipping_charge_customer?: number
          tenant_id?: number
          total_invoice_amount?: number
          transaction_method?: Database["public"]["Enums"]["thrift_transaction_method"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_invoices_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_pricings: {
        Row: {
          cost_of_goods_sold: number
          created_at: string
          extra_expense_cost: number
          id: number
          inserted_by: string
          is_listed_price_manual: boolean | null
          listed_unit_price: number
          stock_id: number
          target_price: number
          updated_at: string
        }
        Insert: {
          cost_of_goods_sold?: number
          created_at?: string
          extra_expense_cost?: number
          id?: number
          inserted_by: string
          is_listed_price_manual?: boolean | null
          listed_unit_price?: number
          stock_id: number
          target_price?: number
          updated_at?: string
        }
        Update: {
          cost_of_goods_sold?: number
          created_at?: string
          extra_expense_cost?: number
          id?: number
          inserted_by?: string
          is_listed_price_manual?: boolean | null
          listed_unit_price?: number
          stock_id?: number
          target_price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_pricings_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: true
            referencedRelation: "thrift_stocks"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_settings: {
        Row: {
          created_at: string
          default_origin_unit_price: number
          hand_tag_unit_cost: number | null
          hand_tag_unit_currency_id: number | null
          sticker_unit_cost: number | null
          sticker_unit_currency_id: number | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          default_origin_unit_price?: number
          hand_tag_unit_cost?: number | null
          hand_tag_unit_currency_id?: number | null
          sticker_unit_cost?: number | null
          sticker_unit_currency_id?: number | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          default_origin_unit_price?: number
          hand_tag_unit_cost?: number | null
          hand_tag_unit_currency_id?: number | null
          sticker_unit_cost?: number | null
          sticker_unit_currency_id?: number | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_settings_hand_tag_unit_currency_id_fkey"
            columns: ["hand_tag_unit_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_settings_sticker_unit_currency_id_fkey"
            columns: ["sticker_unit_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_settings_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: true
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_shelves: {
        Row: {
          created_at: string
          id: number
          inserted_by: string
          location_bay: string | null
          name: string
          shelf_code: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          inserted_by: string
          location_bay?: string | null
          name: string
          shelf_code: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          inserted_by?: string
          location_bay?: string | null
          name?: string
          shelf_code?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_shelves_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_shipments: {
        Row: {
          cargo_conversion_rate: number | null
          cargo_rate: number | null
          cost_currency_id: number
          created_at: string
          default_markup_rate: number | null
          id: number
          inserted_by: string
          labor_total_cost: number | null
          name: string
          product_conversion_rate: number | null
          purchase_currency_id: number
          tenant_id: number
          total_cargo_weight_kg: number | null
          transportation_total_cost: number | null
          updated_at: string
        }
        Insert: {
          cargo_conversion_rate?: number | null
          cargo_rate?: number | null
          cost_currency_id: number
          created_at?: string
          default_markup_rate?: number | null
          id?: number
          inserted_by: string
          labor_total_cost?: number | null
          name: string
          product_conversion_rate?: number | null
          purchase_currency_id: number
          tenant_id: number
          total_cargo_weight_kg?: number | null
          transportation_total_cost?: number | null
          updated_at?: string
        }
        Update: {
          cargo_conversion_rate?: number | null
          cargo_rate?: number | null
          cost_currency_id?: number
          created_at?: string
          default_markup_rate?: number | null
          id?: number
          inserted_by?: string
          labor_total_cost?: number | null
          name?: string
          product_conversion_rate?: number | null
          purchase_currency_id?: number
          tenant_id?: number
          total_cargo_weight_kg?: number | null
          transportation_total_cost?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_shipments_cost_currency_id_fkey"
            columns: ["cost_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_shipments_purchase_currency_id_fkey"
            columns: ["purchase_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_shipments_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_stock_images: {
        Row: {
          created_at: string
          drive_file_id: string | null
          id: number
          image_url: string
          inserted_by: string
          is_primary: boolean
          stock_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          drive_file_id?: string | null
          id?: number
          image_url: string
          inserted_by: string
          is_primary?: boolean
          stock_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          drive_file_id?: string | null
          id?: number
          image_url?: string
          inserted_by?: string
          is_primary?: boolean
          stock_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_stock_images_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: false
            referencedRelation: "thrift_stocks"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_stock_measurements: {
        Row: {
          arm_circumference_in: number | null
          bust_in: number | null
          closure_type: string | null
          created_at: string
          dress_style: string | null
          fabric_stretch: string | null
          hem_width_in: number | null
          hips_in: number | null
          inserted_by: string
          length_in: number | null
          lining: boolean | null
          measurement_notes: string | null
          neck_opening_in: number | null
          neckline: string | null
          shoulder_width_in: number | null
          sleeve_length_in: number | null
          sleeve_type: string | null
          stock_id: number
          tenant_id: number
          updated_at: string
          waist_in: number | null
        }
        Insert: {
          arm_circumference_in?: number | null
          bust_in?: number | null
          closure_type?: string | null
          created_at?: string
          dress_style?: string | null
          fabric_stretch?: string | null
          hem_width_in?: number | null
          hips_in?: number | null
          inserted_by?: string
          length_in?: number | null
          lining?: boolean | null
          measurement_notes?: string | null
          neck_opening_in?: number | null
          neckline?: string | null
          shoulder_width_in?: number | null
          sleeve_length_in?: number | null
          sleeve_type?: string | null
          stock_id: number
          tenant_id: number
          updated_at?: string
          waist_in?: number | null
        }
        Update: {
          arm_circumference_in?: number | null
          bust_in?: number | null
          closure_type?: string | null
          created_at?: string
          dress_style?: string | null
          fabric_stretch?: string | null
          hem_width_in?: number | null
          hips_in?: number | null
          inserted_by?: string
          length_in?: number | null
          lining?: boolean | null
          measurement_notes?: string | null
          neck_opening_in?: number | null
          neckline?: string | null
          shoulder_width_in?: number | null
          sleeve_length_in?: number | null
          sleeve_type?: string | null
          stock_id?: number
          tenant_id?: number
          updated_at?: string
          waist_in?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "thrift_stock_measurements_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: true
            referencedRelation: "thrift_stocks"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_stocks: {
        Row: {
          additional_charges_cost: number | null
          barcode: string | null
          box_id: number | null
          brand_name: string | null
          category_id: number | null
          color: string | null
          condition: Database["public"]["Enums"]["thrift_condition"] | null
          created_at: string
          extra_origin_unit_price: number | null
          extra_weight: number | null
          id: number
          inserted_by: string
          name: string | null
          note: string | null
          origin_unit_price: number | null
          product_weight: number | null
          quantity: number
          section: Database["public"]["Enums"]["thrift_section"] | null
          shelf_id: number | null
          shipment_id: number
          size: string | null
          status: Database["public"]["Enums"]["thrift_stock_status"]
          stock_type: Database["public"]["Enums"]["thrift_stock_type"]
          tenant_id: number
          type_id: number | null
          updated_at: string
        }
        Insert: {
          additional_charges_cost?: number | null
          barcode?: string | null
          box_id?: number | null
          brand_name?: string | null
          category_id?: number | null
          color?: string | null
          condition?: Database["public"]["Enums"]["thrift_condition"] | null
          created_at?: string
          extra_origin_unit_price?: number | null
          extra_weight?: number | null
          id?: number
          inserted_by: string
          name?: string | null
          note?: string | null
          origin_unit_price?: number | null
          product_weight?: number | null
          quantity?: number
          section?: Database["public"]["Enums"]["thrift_section"] | null
          shelf_id?: number | null
          shipment_id: number
          size?: string | null
          status?: Database["public"]["Enums"]["thrift_stock_status"]
          stock_type?: Database["public"]["Enums"]["thrift_stock_type"]
          tenant_id: number
          type_id?: number | null
          updated_at?: string
        }
        Update: {
          additional_charges_cost?: number | null
          barcode?: string | null
          box_id?: number | null
          brand_name?: string | null
          category_id?: number | null
          color?: string | null
          condition?: Database["public"]["Enums"]["thrift_condition"] | null
          created_at?: string
          extra_origin_unit_price?: number | null
          extra_weight?: number | null
          id?: number
          inserted_by?: string
          name?: string | null
          note?: string | null
          origin_unit_price?: number | null
          product_weight?: number | null
          quantity?: number
          section?: Database["public"]["Enums"]["thrift_section"] | null
          shelf_id?: number | null
          shipment_id?: number
          size?: string | null
          status?: Database["public"]["Enums"]["thrift_stock_status"]
          stock_type?: Database["public"]["Enums"]["thrift_stock_type"]
          tenant_id?: number
          type_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_stocks_box_id_fkey"
            columns: ["box_id"]
            isOneToOne: false
            referencedRelation: "thrift_boxes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_stocks_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "thrift_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_stocks_shelf_id_fkey"
            columns: ["shelf_id"]
            isOneToOne: false
            referencedRelation: "thrift_shelves"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_stocks_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "thrift_shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_stocks_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_stocks_type_id_fkey"
            columns: ["type_id"]
            isOneToOne: false
            referencedRelation: "thrift_types"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_types: {
        Row: {
          created_at: string
          description: string | null
          icon: string | null
          id: number
          inserted_by: string
          is_global: boolean
          name: string
          tenant_id: number | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: number
          inserted_by: string
          is_global?: boolean
          name: string
          tenant_id?: number | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: number
          inserted_by?: string
          is_global?: boolean
          name?: string
          tenant_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_types_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      units_of_measure: {
        Row: {
          code: string
          created_at: string
          id: number
          is_active: boolean
          is_system: boolean
          name: string
          sort_order: number
          symbol: string | null
          unit_type: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          name: string
          sort_order?: number
          symbol?: string | null
          unit_type: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          name?: string
          sort_order?: number
          symbol?: string | null
          unit_type?: string
          updated_at?: string
        }
        Relationships: []
      }
      vendors: {
        Row: {
          address: string | null
          code: string
          created_at: string
          email: string | null
          id: number
          market_code: string
          name: string
          parent_tenant_id: number | null
          phone: string | null
          tenant_id: number | null
          updated_at: string
          website: string | null
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          email?: string | null
          id?: number
          market_code: string
          name: string
          parent_tenant_id?: number | null
          phone?: string | null
          tenant_id?: number | null
          updated_at?: string
          website?: string | null
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          email?: string | null
          id?: number
          market_code?: string
          name?: string
          parent_tenant_id?: number | null
          phone?: string | null
          tenant_id?: number | null
          updated_at?: string
          website?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "vendors_market_code_fkey"
            columns: ["market_code"]
            isOneToOne: false
            referencedRelation: "markets"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "vendors_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vendors_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      add_child_line_to_parent_shipment: {
        Args: {
          p_parent_shipment_id: number
          p_source_id: number
          p_source_type: string
        }
        Returns: {
          barcode: string | null
          cost_bdt: number | null
          created_at: string
          id: number
          image_url: string | null
          inspected: boolean
          marker_tag: string | null
          method: string
          name: string | null
          order_id: number | null
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number | null
          product_weight: number | null
          quantity: number
          receiving_splits: Json | null
          shipment_id: number
          sort_order: number
          source_child_tenant_id: number | null
          source_id: number | null
          source_type: string | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "shipment_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_commerce_invoice_item: {
        Args: {
          p_cost_bdt: number
          p_image_url: string
          p_inventory_item_id: number
          p_invoice_id: number
          p_order_id: number
          p_product_id: number
          p_quantity: number
          p_recipient_price_bdt: number
          p_sell_price_bdt: number
        }
        Returns: undefined
      }
      add_global_invoice_item:
        | {
            Args: {
              p_global_stock_id: number
              p_invoice_id: number
              p_line_discount_amount?: number
              p_quantity: number
              p_sell_price_amount: number
            }
            Returns: {
              barcode_snapshot: string | null
              cost_amount: number
              created_at: string
              global_stock_id: number
              id: number
              invoice_id: number
              line_discount_amount: number
              line_face_total_amount: number
              line_tax_amount: number
              line_total_amount: number
              name_snapshot: string
              parent_tenant_id: number
              product_code_snapshot: string | null
              product_id: number | null
              quantity: number
              recipient_price_amount: number | null
              sell_price_amount: number
              tenant_id: number
              updated_at: string
            }
            SetofOptions: {
              from: "*"
              to: "global_invoice_items"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
            Args: {
              p_global_stock_id: number
              p_invoice_id: number
              p_line_discount_amount?: number
              p_quantity: number
              p_recipient_price_amount?: number
              p_sell_price_amount: number
            }
            Returns: {
              barcode_snapshot: string | null
              cost_amount: number
              created_at: string
              global_stock_id: number
              id: number
              invoice_id: number
              line_discount_amount: number
              line_face_total_amount: number
              line_tax_amount: number
              line_total_amount: number
              name_snapshot: string
              parent_tenant_id: number
              product_code_snapshot: string | null
              product_id: number | null
              quantity: number
              recipient_price_amount: number | null
              sell_price_amount: number
              tenant_id: number
              updated_at: string
            }
            SetofOptions: {
              from: "*"
              to: "global_invoice_items"
              isOneToOne: true
              isSetofReturn: false
            }
          }
      add_global_return_item: {
        Args: {
          p_invoice_id: number
          p_invoice_item_id: number
          p_note?: string
          p_quantity: number
          p_return_charge_amount?: number
        }
        Returns: {
          created_at: string
          global_stock_id: number
          id: number
          invoice_id: number
          invoice_item_id: number
          note: string | null
          parent_tenant_id: number
          quantity: number
          return_accounting_amount: number
          return_amount: number
          return_charge_amount: number
          return_face_amount: number
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "global_return_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_invoice_item_transactional: {
        Args: {
          p_barcode_snapshot: string
          p_cost_amount: number
          p_created_by: string
          p_inventory_item_id: number
          p_invoice_id: number
          p_line_discount_amount: number
          p_line_tax_amount: number
          p_name_snapshot: string
          p_product_code_snapshot: string
          p_quantity: number
          p_sell_price_amount: number
          p_source_item_id: number
          p_source_item_type: string
          p_tenant_id: number
        }
        Returns: Json
      }
      add_item_to_cart: {
        Args: {
          p_can_see_price?: boolean
          p_customer_group_id?: number
          p_image_url?: string
          p_minimum_quantity?: number
          p_minimum_sell_price_bdt?: number
          p_name?: string
          p_price_bdt?: number
          p_product_id?: number
          p_quantity?: number
          p_store_id?: number
          p_tenant_id: number
        }
        Returns: Json
      }
      add_item_to_commerce_cart: {
        Args: {
          p_customer_group_id: number
          p_global_stock_id: number
          p_quantity?: number
          p_tenant_id: number
        }
        Returns: Json
      }
      add_payment_allocation: {
        Args: {
          p_amount: number
          p_invoice_id: number
          p_payment_id: number
          p_tenant_id: number
        }
        Returns: {
          amount: number
          commerce_invoice_id: number | null
          created_at: string
          global_invoice_id: number | null
          id: number
          invoice_id: number | null
          payment_id: number
          tenant_id: number
        }
        SetofOptions: {
          from: "*"
          to: "payment_allocations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_shipment_item_from_product: {
        Args: {
          p_product_id: number
          p_quantity: number
          p_shipment_id: number
        }
        Returns: {
          barcode: string | null
          cost_bdt: number | null
          created_at: string
          id: number
          image_url: string | null
          inspected: boolean
          marker_tag: string | null
          method: string
          name: string | null
          order_id: number | null
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number | null
          product_weight: number | null
          quantity: number
          receiving_splits: Json | null
          shipment_id: number
          sort_order: number
          source_child_tenant_id: number | null
          source_id: number | null
          source_type: string | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "shipment_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_shipment_item_manual:
        | {
            Args: {
              p_barcode?: string
              p_damaged_quantity?: number
              p_image_url?: string
              p_name?: string
              p_package_weight?: number
              p_price_gbp?: number
              p_product_code?: string
              p_product_id?: number
              p_product_weight?: number
              p_quantity?: number
              p_received_quantity?: number
              p_shipment_id: number
              p_stolen_quantity?: number
            }
            Returns: {
              barcode: string | null
              cost_bdt: number | null
              created_at: string
              id: number
              image_url: string | null
              inspected: boolean
              marker_tag: string | null
              method: string
              name: string | null
              order_id: number | null
              package_weight: number | null
              price_gbp: number | null
              product_code: string | null
              product_id: number | null
              product_weight: number | null
              quantity: number
              receiving_splits: Json | null
              shipment_id: number
              sort_order: number
              source_child_tenant_id: number | null
              source_id: number | null
              source_type: string | null
              updated_at: string
            }
            SetofOptions: {
              from: "*"
              to: "shipment_items"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
            Args: {
              p_barcode?: string
              p_cost_bdt?: number
              p_image_url?: string
              p_name?: string
              p_package_weight?: number
              p_price_gbp?: number
              p_product_code?: string
              p_product_id?: number
              p_product_weight?: number
              p_quantity?: number
              p_receiving_splits?: Json
              p_shipment_id: number
            }
            Returns: {
              barcode: string | null
              cost_bdt: number | null
              created_at: string
              id: number
              image_url: string | null
              inspected: boolean
              marker_tag: string | null
              method: string
              name: string | null
              order_id: number | null
              package_weight: number | null
              price_gbp: number | null
              product_code: string | null
              product_id: number | null
              product_weight: number | null
              quantity: number
              receiving_splits: Json | null
              shipment_id: number
              sort_order: number
              source_child_tenant_id: number | null
              source_id: number | null
              source_type: string | null
              updated_at: string
            }
            SetofOptions: {
              from: "*"
              to: "shipment_items"
              isOneToOne: true
              isSetofReturn: false
            }
          }
      adjust_inventory_reserved_for_product: {
        Args: { p_delta: number; p_product_id: number; p_tenant_id: number }
        Returns: undefined
      }
      apply_global_shipment_weight_balance: {
        Args: {
          p_adjustments: Json
          p_shipment_id: number
          p_transaction_rate?: number
        }
        Returns: Json
      }
      apply_invoice_item_return: {
        Args: {
          p_actor?: string
          p_invoice_item_id: number
          p_note?: string
          p_return_amount: number
          p_return_damaged_quantity: number
          p_return_normal_quantity: number
          p_return_open_box_quantity: number
          p_return_to_new_batch?: boolean
          p_tenant_id: number
        }
        Returns: Json
      }
      assign_commerce_order_item_inventory_transactional: {
        Args: {
          p_inventory_item_id: number
          p_invoice_id: number
          p_order_item_id: number
        }
        Returns: undefined
      }
      bulk_add_shipment_items_from_product_ids: {
        Args: { p_items: Json; p_shipment_id: number }
        Returns: {
          barcode: string | null
          cost_bdt: number | null
          created_at: string
          id: number
          image_url: string | null
          inspected: boolean
          marker_tag: string | null
          method: string
          name: string | null
          order_id: number | null
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number | null
          product_weight: number | null
          quantity: number
          receiving_splits: Json | null
          shipment_id: number
          sort_order: number
          source_child_tenant_id: number | null
          source_id: number | null
          source_type: string | null
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "shipment_items"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      bulk_delete_shipment_items_by_product_id: {
        Args: { p_items: Json; p_shipment_id: number }
        Returns: number
      }
      bulk_update_order_item_offers: {
        Args: { p_items: Json }
        Returns: {
          barcode: string | null
          cost_bdt: number | null
          cost_gbp: number | null
          created_at: string
          customer_offer_bdt: number | null
          delivered_quantity: number
          final_offer_bdt: number | null
          first_offer_bdt: number | null
          id: number
          image_url: string | null
          minimum_quantity: number
          name: string
          order_id: number
          ordered_quantity: number
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number | null
          product_weight: number | null
          returned_quantity: number
          shipment_id: number | null
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "order_items"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      bulk_update_order_items: {
        Args: { p_items: Json }
        Returns: {
          barcode: string | null
          cost_bdt: number | null
          cost_gbp: number | null
          created_at: string
          customer_offer_bdt: number | null
          delivered_quantity: number
          final_offer_bdt: number | null
          first_offer_bdt: number | null
          id: number
          image_url: string | null
          minimum_quantity: number
          name: string
          order_id: number
          ordered_quantity: number
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number | null
          product_weight: number | null
          returned_quantity: number
          shipment_id: number | null
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "order_items"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      calculate_costing_auxiliary_price_gbp: {
        Args: { p_delivery_price_gbp: number; p_price_in_web_gbp: number }
        Returns: number
      }
      calculate_costing_item_type_surcharge_gbp: {
        Args: { p_item_type: string }
        Returns: number
      }
      can_access_cart: { Args: { p_cart_id: number }; Returns: boolean }
      can_access_cart_item: {
        Args: { p_cart_item_id: number }
        Returns: boolean
      }
      can_admin_manage_costing_file: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      can_assign_membership_role: {
        Args: {
          p_target_role: Database["public"]["Enums"]["app_role"]
          p_target_tenant_id: number
        }
        Returns: boolean
      }
      can_customer_access_costing_file: {
        Args: { p_customer_group_id: number }
        Returns: boolean
      }
      can_customer_access_store: {
        Args: { p_store_id: number }
        Returns: boolean
      }
      can_customer_see_store_price: {
        Args: { p_store_id: number }
        Returns: boolean
      }
      can_insert_cart:
        | {
            Args: { p_customer_group_id: number; p_tenant_id: number }
            Returns: boolean
          }
        | {
            Args: {
              p_customer_group_id: number
              p_store_id?: number
              p_tenant_id: number
            }
            Returns: boolean
          }
      can_insert_cart_item: { Args: { p_cart_id: number }; Returns: boolean }
      can_manage_costing: { Args: { p_tenant_id: number }; Returns: boolean }
      can_manage_costing_file_viewers: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      can_manage_costing_item: { Args: { p_file_id: number }; Returns: boolean }
      can_manage_customer_group: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      can_manage_customer_group_member: {
        Args: { p_customer_group_id: number }
        Returns: boolean
      }
      can_manage_membership: {
        Args: {
          p_target_role: Database["public"]["Enums"]["app_role"]
          p_target_tenant_id: number
        }
        Returns: boolean
      }
      can_manage_products: { Args: { p_tenant_id: number }; Returns: boolean }
      can_manage_shipment: { Args: { p_tenant_id: number }; Returns: boolean }
      can_manage_shipment_by_id: {
        Args: { p_shipment_id: number }
        Returns: boolean
      }
      can_manage_store: { Args: { p_tenant_id: number }; Returns: boolean }
      can_staff_access_costing_file: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      can_tenant_view_costing_file_viewer: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      can_update_membership_row: {
        Args: {
          p_existing_role: Database["public"]["Enums"]["app_role"]
          p_existing_tenant_id: number
        }
        Returns: boolean
      }
      can_view_costing_file: {
        Args: { p_costing_file_id: number }
        Returns: boolean
      }
      can_view_costing_file_items: {
        Args: { p_costing_file_id: number }
        Returns: boolean
      }
      can_view_costing_internal: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      can_view_costing_item: { Args: { p_file_id: number }; Returns: boolean }
      can_view_products_customer: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      can_view_products_internal: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      can_view_tenant_modules: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      cart_exists: { Args: { p_cart_id: number }; Returns: boolean }
      check_login_membership: {
        Args: { p_email: string; p_scope: string }
        Returns: {
          has_match: boolean
          matched_role: Database["public"]["Enums"]["app_role"]
          member_created_at: string
          member_email: string
          member_id: number
          member_is_active: boolean
          member_tenant_id: number
          member_updated_at: string
        }[]
      }
      check_shop_login_access: {
        Args: { p_email: string; p_tenant_id?: number }
        Returns: {
          customer_group_id: number
          customer_group_is_active: boolean
          customer_group_name: string
          has_match: boolean
          matched_role: Database["public"]["Enums"]["customer_group_role"]
          member_created_at: string
          member_email: string
          member_id: number
          member_is_active: boolean
          member_name: string
          member_tenant_id: number
          member_updated_at: string
        }[]
      }
      check_store_access: { Args: { p_store_id: number }; Returns: boolean }
      check_store_price_access: {
        Args: { p_store_id: number }
        Returns: boolean
      }
      count_costing_files_for_actor: {
        Args: { p_customer_group_id?: number; p_tenant_id?: number }
        Returns: number
      }
      count_search_stock_network: {
        Args: {
          p_context_tenant_id: number
          p_exclude_zero_qty?: boolean
          p_mode?: string
          p_product_id?: number
          p_search?: string
          p_search_field?: string
          p_shipment_id?: number
          p_status?: string
        }
        Returns: number
      }
      create_billing_profile_payment_with_allocations: {
        Args: {
          p_allocations: Json
          p_amount: number
          p_billing_profile_id: number
          p_method: string
          p_note: string
          p_payment_date: string
          p_reference: string
          p_tenant_id: number
        }
        Returns: {
          amount: number
          billing_profile_id: number
          created_at: string
          id: number
          method: string | null
          note: string | null
          payment_date: string
          reference: string | null
          tenant_id: number
        }
        SetofOptions: {
          from: "*"
          to: "payments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_commerce_invoice:
        | {
            Args: {
              p_amount_paid: number
              p_billing_profile_id?: number
              p_cod: number
              p_delivered_by: string
              p_delivery_charge: number
              p_order_id: number
              p_tenant_id: number
              p_total_amount: number
              p_wrapping_charge: number
            }
            Returns: number
          }
        | {
            Args: {
              p_amount_paid: number
              p_billing_profile_id?: number
              p_cod: number
              p_delivered_by: string
              p_delivery_charge: number
              p_invoice_date?: string
              p_order_id: number
              p_tenant_id: number
              p_total_amount: number
              p_wrapping_charge: number
            }
            Returns: number
          }
        | {
            Args: {
              p_amount_paid: number
              p_billing_profile_id?: number
              p_cod: number
              p_delivered_by: string
              p_delivery_charge: number
              p_invoice_date?: string
              p_order_id: number
              p_print_charge?: number
              p_tenant_id: number
              p_total_amount: number
              p_wrapping_charge: number
            }
            Returns: number
          }
      create_costing_file:
        | {
            Args: {
              p_customer_group_id: number
              p_market: string
              p_name: string
              p_status?: Database["public"]["Enums"]["costing_file_status"]
              p_tenant_id?: number
            }
            Returns: {
              created_at: string
              created_by_email: string
              customer_group_id: number
              default_shipment_id: number
              id: number
              market: string
              name: string
              status: Database["public"]["Enums"]["costing_file_status"]
              tenant_id: number
              updated_at: string
            }[]
          }
        | {
            Args: {
              p_customer_group_id: number
              p_market: string
              p_name: string
              p_tenant_id: number
            }
            Returns: {
              created_at: string
              created_by_email: string
              customer_group_id: number
              id: number
              market: string
              name: string
              status: Database["public"]["Enums"]["costing_file_status"]
              tenant_id: number
              updated_at: string
            }[]
          }
      create_costing_file_item_request:
        | {
            Args: {
              p_costing_file_id: number
              p_quantity: number
              p_website_url: string
            }
            Returns: {
              costing_file_id: number
              created_at: string
              created_by_email: string
              id: number
              quantity: number
              status: Database["public"]["Enums"]["costing_file_item_status"]
              updated_at: string
              website_url: string
            }[]
          }
        | {
            Args: {
              p_costing_file_id: number
              p_item_type?: string
              p_quantity: number
              p_website_url: string
            }
            Returns: {
              costing_file_id: number
              created_at: string
              created_by_email: string
              id: number
              item_type: string
              quantity: number
              status: Database["public"]["Enums"]["costing_file_item_status"]
              updated_at: string
              website_url: string
            }[]
          }
      create_global_invoice: {
        Args: {
          p_billing_profile_id: number
          p_invoice_no: string
          p_invoice_type?: Database["public"]["Enums"]["global_invoice_type"]
          p_middle_man_payout_amount?: number
          p_note?: string
          p_recipient_address?: string
          p_recipient_name?: string
          p_recipient_party_id?: number
          p_recipient_phone?: string
          p_source_module?: Database["public"]["Enums"]["global_source_module"]
          p_tenant_id: number
        }
        Returns: {
          accounting_subtotal_amount: number
          billing_profile_id: number | null
          collection_source: string | null
          created_at: string
          created_by: string | null
          customer_group_id: number | null
          discount_amount: number
          due_amount: number
          due_date: string | null
          face_subtotal_amount: number
          id: number
          invoice_date: string
          invoice_no: string
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          middle_man_payout_amount: number
          middle_man_payout_status: string
          note: string | null
          ordered_by_party_id: number | null
          paid_amount: number
          parent_tenant_id: number
          payment_status: string
          recipient_address: string | null
          recipient_name: string | null
          recipient_party_id: number | null
          recipient_phone: string | null
          sold_in_tenant_id: number | null
          source_module: Database["public"]["Enums"]["global_source_module"]
          subtotal_amount: number
          tenant_id: number
          total_amount: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "global_invoices"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_middle_man_payout: {
        Args: {
          p_amount: number
          p_billing_profile_id: number
          p_global_invoice_id: number
          p_note?: string
          p_tenant_id: number
        }
        Returns: {
          accounting_subtotal_amount: number
          billing_profile_id: number | null
          collection_source: string | null
          created_at: string
          created_by: string | null
          customer_group_id: number | null
          discount_amount: number
          due_amount: number
          due_date: string | null
          face_subtotal_amount: number
          id: number
          invoice_date: string
          invoice_no: string
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          middle_man_payout_amount: number
          middle_man_payout_status: string
          note: string | null
          ordered_by_party_id: number | null
          paid_amount: number
          parent_tenant_id: number
          payment_status: string
          recipient_address: string | null
          recipient_name: string | null
          recipient_party_id: number | null
          recipient_phone: string | null
          sold_in_tenant_id: number | null
          source_module: Database["public"]["Enums"]["global_source_module"]
          subtotal_amount: number
          tenant_id: number
          total_amount: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "global_invoices"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_shipment: {
        Args: { p_name: string; p_shipment_type?: string; p_tenant_id: number }
        Returns: {
          cargo_conversion_rate: number | null
          cargo_rate: number | null
          created_at: string
          id: number
          inventory_added: boolean
          market_code: string | null
          name: string
          product_conversion_rate: number | null
          received_weight: number | null
          shipment_type: string
          status: string
          tenant_id: number
          tenant_shipment_id: number
          transaction_rate: number | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "shipments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_store: {
        Args: { p_name: string; p_tenant_id: number; p_vendor_code: string }
        Returns: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
        }
        SetofOptions: {
          from: "*"
          to: "stores"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_store_access:
        | {
            Args: {
              p_customer_group_id: number
              p_status?: boolean
              p_store_id: number
            }
            Returns: {
              created_at: string
              customer_group_id: number
              id: number
              see_price: boolean
              status: boolean
              store_id: number
              updated_at: string
            }
            SetofOptions: {
              from: "*"
              to: "store_access"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
            Args: {
              p_customer_group_id: number
              p_see_price?: boolean
              p_status?: boolean
              p_store_id: number
            }
            Returns: {
              created_at: string
              customer_group_id: number
              id: number
              see_price: boolean
              status: boolean
              store_id: number
              updated_at: string
            }
            SetofOptions: {
              from: "*"
              to: "store_access"
              isOneToOne: true
              isSetofReturn: false
            }
          }
      create_tenant_for_superadmin: {
        Args: {
          p_is_active?: boolean
          p_name: string
          p_parent_id?: number
          p_public_domain?: string
          p_slug: string
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number
          preference: Json
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      create_tenant_module_for_superadmin: {
        Args: {
          p_is_active?: boolean
          p_module_key: string
          p_tenant_id: number
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          module_key: string
          tenant_id: number
          updated_at: string
        }[]
      }
      current_authenticated_email: { Args: never; Returns: string }
      current_costing_item_actor_role: {
        Args: { p_costing_file_id: number }
        Returns: string
      }
      current_tenant_id: { Args: never; Returns: number }
      current_user_email: { Args: never; Returns: string }
      delete_commerce_invoice_transactional: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      delete_global_stock_allocation: {
        Args: { p_allocation_id: number }
        Returns: undefined
      }
      delete_invoice_item_transactional: {
        Args: { p_invoice_item_id: number }
        Returns: undefined
      }
      delete_invoice_transactional: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      delete_shipment: { Args: { p_id: number }; Returns: undefined }
      delete_shipment_item_quantity: {
        Args: { p_id: number; p_quantity: number }
        Returns: boolean
      }
      delete_shipment_order: { Args: { p_id: number }; Returns: undefined }
      delete_store: { Args: { p_id: number }; Returns: undefined }
      delete_store_access: { Args: { p_id: number }; Returns: undefined }
      delete_tenant_for_superadmin: {
        Args: { p_tenant_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number
          preference: Json
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      delete_tenant_module_for_superadmin: {
        Args: { p_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          module_key: string
          tenant_id: number
          updated_at: string
        }[]
      }
      find_active_tenant_by_public_domain: {
        Args: { p_public_domain: string }
        Returns: {
          id: number
          name: string
          public_domain: string
          slug: string
        }[]
      }
      find_active_tenant_by_slug: {
        Args: { p_slug: string }
        Returns: {
          id: number
          name: string
          public_domain: string
          slug: string
        }[]
      }
      fn_recalculate_normal_invoice_totals: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      generate_thrift_barcodes: {
        Args: { p_inserted_by: string; p_quantity: number; p_tenant_id: number }
        Returns: string[]
      }
      get_active_module_keys_for_tenant: {
        Args: { p_tenant_id: number }
        Returns: string[]
      }
      get_allocation_reconciliation: {
        Args: { p_stock_id: number }
        Returns: {
          allocated_qty: number
          global_qty: number
          is_reconciled: boolean
          stock_id: number
          unallocated_qty: number
        }[]
      }
      get_app_bootstrap_context: {
        Args: {
          p_email?: string
          p_membership_id?: number
          p_tenant_id?: number
        }
        Returns: {
          active_module_keys: string[]
          member_email: string
          member_id: number
          member_is_active: boolean
          member_role: Database["public"]["Enums"]["app_role"]
          tenant_id: number
          tenant_is_active: boolean
          tenant_name: string
          tenant_preference: Json
          tenant_slug: string
        }[]
      }
      get_cart: { Args: { p_cart_id: number }; Returns: Json }
      get_cart_details: { Args: { p_cart_id: number }; Returns: Json }
      get_costing_file_by_id: {
        Args: { p_id: number }
        Returns: {
          admin_profit_rate: number
          cargo_rate_1kg: number
          cargo_rate_2kg: number
          conversion_rate: number
          created_at: string
          created_by_email: string
          customer_group_id: number
          default_shipment_id: number
          id: number
          market: string
          name: string
          status: Database["public"]["Enums"]["costing_file_status"]
          tenant_id: number
          updated_at: string
        }[]
      }
      get_effective_item_role: {
        Args: { p_item_id: number; p_user_email: string }
        Returns: string
      }
      get_investor_bootstrap_context: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      get_investor_portfolio_summary: {
        Args: { p_investor_id: number }
        Returns: Json
      }
      get_item_details: { Args: { p_item_id: number }; Returns: Json }
      get_koba_cart: {
        Args: { p_customer_group_id?: number; p_tenant_id: number }
        Returns: Json
      }
      get_koba_customer_profile: {
        Args: { p_phone: string; p_tenant_id: number }
        Returns: Json
      }
      get_koba_customers_list: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_tenant_id: number
        }
        Returns: {
          address: string
          district: string
          last_order_date: string
          name: string
          phone: string
          thana: string
          total_orders: number
          total_spent: number
        }[]
      }
      get_parent_cash_circulation: {
        Args: { p_parent_tenant_id: number }
        Returns: Json
      }
      get_product_for_tenant: {
        Args: { p_id: number; p_tenant_id: number }
        Returns: {
          available_units: number | null
          barcode: string | null
          batch_code_manufacture_date: string | null
          brand: string | null
          category: string | null
          country_of_origin: string | null
          created_at: string
          expire_date: string | null
          hazardous: boolean | null
          id: number
          image_url: string | null
          is_available: boolean | null
          languages: string | null
          market_code: string | null
          minimum_order_quantity: number | null
          name: string | null
          package_weight: number | null
          parent_tenant_id: number | null
          price_gbp: number | null
          product_code: string | null
          product_weight: number | null
          source: string | null
          tariff_code: string | null
          tenant_id: number | null
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
        }
        SetofOptions: {
          from: "*"
          to: "products"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_shop_bootstrap_context: {
        Args: {
          p_customer_group_member_id?: number
          p_email?: string
          p_tenant_id?: number
        }
        Returns: {
          active_module_keys: string[]
          customer_group_accent_color: string
          customer_group_id: number
          customer_group_is_active: boolean
          customer_group_name: string
          member_email: string
          member_id: number
          member_is_active: boolean
          member_name: string
          member_role: Database["public"]["Enums"]["customer_group_role"]
          tenant_id: number
          tenant_is_active: boolean
          tenant_name: string
          tenant_slug: string
        }[]
      }
      get_store_access_admin: {
        Args: { p_store_id?: number; p_tenant_id?: number }
        Returns: {
          created_at: string
          customer_group_id: number
          id: number
          see_price: boolean
          status: boolean
          store_id: number
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "store_access"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_store_access_admin_v2: {
        Args: { p_store_id?: number; p_tenant_id?: number }
        Returns: {
          created_at: string
          customer_group_id: number
          id: number
          see_price: boolean
          status: boolean
          store_id: number
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "store_access"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_store_product_brands: {
        Args: { p_store_id: number }
        Returns: {
          brand: string
        }[]
      }
      get_store_product_categories: {
        Args: { p_store_id: number }
        Returns: {
          category: string
        }[]
      }
      get_stores_admin: {
        Args: { p_tenant_id: number }
        Returns: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
        }[]
        SetofOptions: {
          from: "*"
          to: "stores"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_stores_for_customer: {
        Args: never
        Returns: {
          created_at: string
          id: number
          name: string
          see_price: boolean
          tenant_id: number
          updated_at: string
          vendor_code: string
        }[]
      }
      get_stores_for_customer_v2: {
        Args: { p_tenant_id?: number }
        Returns: {
          created_at: string
          id: number
          name: string
          see_price: boolean
          tenant_id: number
          updated_at: string
          vendor_code: string
        }[]
      }
      get_tenant_details_by_membership: {
        Args: {
          p_email?: string
          p_role?: Database["public"]["Enums"]["app_role"]
          p_tenant_id: number
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number
          preference: Json
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      get_tenant_module_by_id: {
        Args: { p_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          module_key: string
          tenant_id: number
          updated_at: string
        }[]
      }
      get_vendor_for_tenant: {
        Args: { p_id: number; p_tenant_id: number }
        Returns: {
          address: string | null
          code: string
          created_at: string
          email: string | null
          id: number
          market_code: string
          name: string
          parent_tenant_id: number | null
          phone: string | null
          tenant_id: number | null
          updated_at: string
          website: string | null
        }
        SetofOptions: {
          from: "*"
          to: "vendors"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      global_search_tasks: {
        Args: { p_query: string }
        Returns: {
          content: string
          created_at: string
          created_by_email: string
          due_date: string
          id: number
          parent_id: number
          priority: string
          start_date: string
          status: string
          tenant_id: number
          tenant_name: string
          title: string
          type: string
          updated_at: string
        }[]
      }
      grant_costing_file_viewer: {
        Args: { p_costing_file_id: number; p_membership_id: number }
        Returns: {
          costing_file_id: number
          costing_file_viewer_id: number
          created_at: string
          email: string
          is_active: boolean
          membership_id: number
          name: string
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
        }[]
      }
      has_active_tenant_membership: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      is_assigned_costing_file_viewer: {
        Args: { p_costing_file_id: number }
        Returns: boolean
      }
      is_child_tenant: { Args: { p_tenant_id: number }; Returns: boolean }
      is_customer_group_admin_or_negotiator: {
        Args: { p_customer_group_id: number }
        Returns: boolean
      }
      is_customer_group_member: {
        Args: { p_customer_group_id: number }
        Returns: boolean
      }
      is_internal_costing_file_creator: {
        Args: { p_email: string; p_tenant_id: number }
        Returns: boolean
      }
      is_parent_company: { Args: { p_tenant_id: number }; Returns: boolean }
      is_superadmin: { Args: never; Returns: boolean }
      is_tenant_admin: { Args: { p_tenant_id: number }; Returns: boolean }
      is_tenant_staff: { Args: { p_tenant_id: number }; Returns: boolean }
      is_vendor_code_available: {
        Args: { p_code: string; p_exclude_id?: number }
        Returns: boolean
      }
      koba_cart_allowed: { Args: { p_cart_id: number }; Returns: boolean }
      koba_context_access_allowed: {
        Args: { p_customer_group_id: number; p_tenant_id: number }
        Returns: boolean
      }
      koba_order_allowed: { Args: { p_order_id: number }; Returns: boolean }
      list_allocatable_stock_paginated: {
        Args: {
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_shipment_id?: number
          p_stock_type_id?: number
          p_tenant_id: number
        }
        Returns: Json
      }
      list_child_allocation_summary: {
        Args: { p_stock_id: number }
        Returns: {
          allocated_qty: number
          allocation_id: number
          child_tenant_id: number
          child_tenant_name: string
        }[]
      }
      list_child_procurement_lines: {
        Args: {
          p_child_tenant_id?: number
          p_limit?: number
          p_offset?: number
          p_parent_tenant_id: number
          p_search?: string
        }
        Returns: {
          barcode: string
          child_tenant_id: number
          child_tenant_name: string
          cost_bdt: number
          image_url: string
          name: string
          price_gbp: number
          product_code: string
          product_id: number
          quantity: number
          reference_label: string
          source_id: number
          source_type: string
        }[]
      }
      list_child_tenant_ids: {
        Args: { p_parent_tenant_id: number }
        Returns: number[]
      }
      list_commerce_global_stock_for_store: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_store_id: number
          p_tenant_id: number
        }
        Returns: Json
      }
      list_costing_file_items: {
        Args: { p_costing_file_id: number }
        Returns: {
          assigned_shipment_id: number
          auxiliary_price_gbp: number
          cargo_rate: number
          costing_file_id: number
          costing_price_bdt: number
          costing_price_gbp: number
          created_at: string
          created_by_email: string
          customer_profit_rate: number
          delivery_price_gbp: number
          id: number
          image_url: string
          item_price_gbp: number
          name: string
          offer_price_bdt: number
          package_weight: number
          price_in_web_gbp: number
          product_weight: number
          quantity: number
          status: Database["public"]["Enums"]["costing_file_item_status"]
          updated_at: string
          website_url: string
        }[]
      }
      list_costing_file_viewers: {
        Args: { p_costing_file_id: number }
        Returns: {
          costing_file_id: number
          costing_file_viewer_id: number
          created_at: string
          email: string
          is_active: boolean
          membership_id: number
          name: string
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
        }[]
      }
      list_costing_files_for_actor:
        | {
            Args: { p_customer_group_id?: number; p_tenant_id?: number }
            Returns: {
              created_at: string
              created_by_email: string
              customer_group_id: number
              id: number
              market: string
              name: string
              status: Database["public"]["Enums"]["costing_file_status"]
              tenant_id: number
              updated_at: string
            }[]
          }
        | {
            Args: {
              p_customer_group_id?: number
              p_page?: number
              p_page_size?: number
              p_tenant_id?: number
            }
            Returns: Json
          }
      list_global_accounting_ledger: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_parent_tenant_id: number
          p_tenant_id?: number
        }
        Returns: {
          charge_type: Database["public"]["Enums"]["invoice_charge_type"] | null
          cost_amount: number
          created_at: string
          created_by: string | null
          entry_date: string
          global_invoice_id: number | null
          global_invoice_item_id: number | null
          global_stock_id: number | null
          gross_profit_amount: number
          id: number
          is_charge: boolean
          note: string | null
          parent_tenant_id: number
          product_id: number | null
          quantity: number
          return_amount: number
          return_quantity: number
          sell_price_amount: number
          shipment_id: number | null
          shipment_item_id: number | null
          sold_in_tenant_id: number | null
          status: string
          tenant_id: number
          total_cost_amount: number
          total_sell_amount: number
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "global_accounting_ledger"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      list_global_accounting_ledger_by_shipment: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_parent_tenant_id: number
          p_shipment_id: number
        }
        Returns: {
          charge_type: Database["public"]["Enums"]["invoice_charge_type"] | null
          cost_amount: number
          created_at: string
          created_by: string | null
          entry_date: string
          global_invoice_id: number | null
          global_invoice_item_id: number | null
          global_stock_id: number | null
          gross_profit_amount: number
          id: number
          is_charge: boolean
          note: string | null
          parent_tenant_id: number
          product_id: number | null
          quantity: number
          return_amount: number
          return_quantity: number
          sell_price_amount: number
          shipment_id: number | null
          shipment_item_id: number | null
          sold_in_tenant_id: number | null
          status: string
          tenant_id: number
          total_cost_amount: number
          total_sell_amount: number
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "global_accounting_ledger"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      list_global_currencies: {
        Args: never
        Returns: {
          code: string
          country: string
          id: number
          name: string
          symbol: string
        }[]
      }
      list_global_inventory_items_with_stock: {
        Args: {
          p_filters?: Json
          p_page?: number
          p_page_size?: number
          p_sort_by?: string
          p_sort_order?: string
        }
        Returns: Json
      }
      list_global_shipments_paginated: {
        Args: {
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_status?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_global_stock_allocations_paginated: {
        Args: {
          p_child_tenant_id?: number
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_stock_type_id?: number
          p_tenant_id: number
        }
        Returns: Json
      }
      list_global_stocks_paginated: {
        Args: {
          p_is_sellable?: boolean
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_shipment_status?: string
          p_stock_type_id?: number
          p_tenant_id: number
        }
        Returns: Json
      }
      list_inventory_items_with_stock: {
        Args: {
          p_filters?: Json
          p_page?: number
          p_page_size?: number
          p_sort_by?: string
          p_sort_order?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_invoices_paginated: {
        Args: {
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_status?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_items_paginated: {
        Args: {
          p_assignee?: string
          p_date_field?: string
          p_date_from?: string
          p_date_to?: string
          p_include_parents?: boolean
          p_my_tasks_email?: string
          p_page?: number
          p_page_size?: number
          p_priority?: string
          p_search?: string
          p_status?: string
          p_tag_id?: number
          p_tenant_id?: number
          p_type?: string
        }
        Returns: Json
      }
      list_koba_brands_for_tenant: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      list_koba_categories_for_tenant: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      list_koba_orders: {
        Args: {
          p_customer_group_id?: number
          p_page?: number
          p_page_size?: number
          p_status?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_koba_retail_products: {
        Args: {
          p_brand_id?: number
          p_category_id?: number
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_my_admin_tenants: {
        Args: never
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number
          preference: Json
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      list_payment_methods: {
        Args: never
        Returns: {
          category: string
          code: string
          name: string
          scope: string
          sort_order: number
        }[]
      }
      list_product_based_costing_files: {
        Args: {
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_status?: string
          p_tenant_id?: number
        }
        Returns: Json
      }
      list_product_brands_for_tenant: {
        Args: {
          p_tenant_id: number
          p_vendor_code?: string
          p_vendor_id?: number
        }
        Returns: {
          created_at: string
          id: number
          name: string
          parent_tenant_id: number | null
          tenant_id: number | null
          updated_at: string
          value: string | null
          vendor_code: string | null
          vendor_id: number | null
        }[]
        SetofOptions: {
          from: "*"
          to: "product_brands"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      list_product_categories_for_tenant: {
        Args: {
          p_tenant_id: number
          p_vendor_code?: string
          p_vendor_id?: number
        }
        Returns: {
          created_at: string
          id: number
          name: string
          parent_tenant_id: number | null
          tenant_id: number | null
          updated_at: string
          value: string | null
          vendor_code: string | null
          vendor_id: number | null
        }[]
        SetofOptions: {
          from: "*"
          to: "product_categories"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      list_products_paginated: {
        Args: {
          p_brand?: string
          p_category?: string
          p_is_available?: boolean
          p_limit?: number
          p_market_code?: string
          p_offset?: number
          p_search?: string
          p_search_field?: string
          p_sort_by?: string
          p_sort_dir?: string
          p_tenant_id?: number
          p_vendor_code?: string
        }
        Returns: Json
      }
      list_shipments_paginated: {
        Args: {
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_status?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_store_product_pricing: {
        Args: {
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_shipment_id?: number
          p_store_id: number
          p_tenant_id: number
        }
        Returns: Json
      }
      list_store_products: {
        Args: {
          p_brand?: string
          p_category?: string
          p_fields?: string[]
          p_is_available?: boolean
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_sort_by?: string
          p_sort_dir?: string
          p_store_id: number
        }
        Returns: Json
      }
      list_store_products_inventory_aggregated: {
        Args: {
          p_brand?: string
          p_category?: string
          p_fields?: string[]
          p_is_available?: boolean
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_sort_by?: string
          p_sort_dir?: string
          p_store_id: number
        }
        Returns: Json
      }
      list_tenant_module_submodules_for_superadmin: {
        Args: { p_parent_module_key: string; p_tenant_id: number }
        Returns: {
          created_at: string
          id: number
          is_enabled: boolean
          parent_module_key: string
          submodule_key: string
          tenant_id: number
          updated_at: string
        }[]
      }
      list_tenant_modules_by_tenant: {
        Args: { p_tenant_id?: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          module_key: string
          tenant_id: number
          updated_at: string
        }[]
      }
      list_tenant_viewers: {
        Args: { p_tenant_id: number }
        Returns: {
          created_at: string
          email: string
          is_active: boolean
          membership_id: number
          name: string
          role: Database["public"]["Enums"]["app_role"]
          tenant_id: number
          updated_at: string
        }[]
      }
      list_tenants_by_membership: {
        Args: {
          p_email?: string
          p_role?: Database["public"]["Enums"]["app_role"]
          p_tenant_id?: number
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number
          preference: Json
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      list_tenants_for_superadmin: {
        Args: never
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number
          preference: Json
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      list_thrift_barcodes_paginated: {
        Args: {
          p_is_printed?: number
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_status?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_thrift_stocks_paginated: {
        Args: {
          p_condition?: string
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_status?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_units_of_measure: {
        Args: never
        Returns: {
          code: string
          name: string
          sort_order: number
          symbol: string
          unit_type: string
        }[]
      }
      list_vendor_markets: {
        Args: never
        Returns: {
          code: string
          name: string
          region: string
        }[]
      }
      list_vendors_for_tenant: {
        Args: { p_tenant_id: number }
        Returns: {
          address: string | null
          code: string
          created_at: string
          email: string | null
          id: number
          market_code: string
          name: string
          parent_tenant_id: number | null
          phone: string | null
          tenant_id: number | null
          updated_at: string
          website: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "vendors"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      mark_thrift_items_as_sold: {
        Args: {
          p_address: string
          p_cod_charge: number
          p_inserted_by: string
          p_invoice_number: string
          p_invoice_print_charge: number
          p_items: Json
          p_packing_charge: number
          p_phone: string
          p_recipient_name: string
          p_shipping_charge_customer: number
          p_tenant_id: number
          p_transaction_method: Database["public"]["Enums"]["thrift_transaction_method"]
        }
        Returns: number
      }
      migrate_legacy_inventory_to_global_stock: {
        Args: { p_tenant_id?: number }
        Returns: Json
      }
      next_tenant_scoped_counter: {
        Args: { p_scope: string; p_tenant_id: number }
        Returns: number
      }
      place_commerce_order: {
        Args: {
          p_cod: number
          p_customer_group_id: number
          p_delivery_charge: number
          p_invoice_print_charge: number
          p_is_delivery_charge_inclusive: boolean
          p_items: Json
          p_recipient_name: string
          p_recipient_phone: string
          p_shipment_payment: number
          p_shipping_address: string
          p_tenant_id: number
          p_wrapping_charge: number
        }
        Returns: number
      }
      place_koba_order: {
        Args: {
          p_cod_charge?: number
          p_customer_group_id?: number
          p_delivery_adjustment?: number
          p_extra_profit_company?: number
          p_extra_profit_user?: number
          p_free_delivery?: boolean
          p_invoice_charge?: number
          p_net_order_commission?: number
          p_packing_charge?: number
          p_shipping_address?: string
          p_shipping_district?: string
          p_shipping_name?: string
          p_shipping_phone?: string
          p_shipping_thana?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      post_global_invoice_item_to_ledger: {
        Args: { p_invoice_item_id: number }
        Returns: {
          charge_type: Database["public"]["Enums"]["invoice_charge_type"] | null
          cost_amount: number
          created_at: string
          created_by: string | null
          entry_date: string
          global_invoice_id: number | null
          global_invoice_item_id: number | null
          global_stock_id: number | null
          gross_profit_amount: number
          id: number
          is_charge: boolean
          note: string | null
          parent_tenant_id: number
          product_id: number | null
          quantity: number
          return_amount: number
          return_quantity: number
          sell_price_amount: number
          shipment_id: number | null
          shipment_item_id: number | null
          sold_in_tenant_id: number | null
          status: string
          tenant_id: number
          total_cost_amount: number
          total_sell_amount: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "global_accounting_ledger"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      recalculate_shipment_transaction_rate: {
        Args: { p_shipment_id: number }
        Returns: number
      }
      recompute_global_invoice_payment_status: {
        Args: { p_global_invoice_id: number }
        Returns: undefined
      }
      recompute_global_invoice_totals: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      recompute_invoice_payment_status: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      record_recipient_invoice_collection: {
        Args: { p_amount: number; p_global_invoice_id: number; p_note?: string }
        Returns: {
          accounting_subtotal_amount: number
          billing_profile_id: number | null
          collection_source: string | null
          created_at: string
          created_by: string | null
          customer_group_id: number | null
          discount_amount: number
          due_amount: number
          due_date: string | null
          face_subtotal_amount: number
          id: number
          invoice_date: string
          invoice_no: string
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          middle_man_payout_amount: number
          middle_man_payout_status: string
          note: string | null
          ordered_by_party_id: number | null
          paid_amount: number
          parent_tenant_id: number
          payment_status: string
          recipient_address: string | null
          recipient_name: string | null
          recipient_party_id: number | null
          recipient_phone: string | null
          sold_in_tenant_id: number | null
          source_module: Database["public"]["Enums"]["global_source_module"]
          subtotal_amount: number
          tenant_id: number
          total_amount: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "global_invoices"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      refresh_commerce_inventory_product_summaries: {
        Args: { p_tenant_id?: number }
        Returns: undefined
      }
      refresh_commerce_inventory_product_summary_single: {
        Args: { p_product_id: number; p_tenant_id: number }
        Returns: undefined
      }
      refresh_global_invoice_accounting: {
        Args: { p_global_invoice_id: number }
        Returns: {
          charge_total: number
          discount_amount: number
          global_invoice_id: number
          gross_profit_total: number
          id: number
          parent_tenant_id: number
          refreshed_at: string
          subtotal_amount: number
          tenant_id: number
          total_amount: number
        }
        SetofOptions: {
          from: "*"
          to: "global_invoice_accounting"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      refresh_global_shipment_accounting: {
        Args: { p_parent_tenant_id: number; p_shipment_id: number }
        Returns: {
          buy_cost_total: number
          gross_profit_total: number
          id: number
          parent_tenant_id: number
          refreshed_at: string
          sell_total: number
          shipment_id: number
          tenant_id: number
        }
        SetofOptions: {
          from: "*"
          to: "global_shipment_accounting"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      refresh_investor_balance: {
        Args: { p_investor_id: number; p_tenant_id: number }
        Returns: undefined
      }
      refresh_shipment_inventory_accounting: {
        Args: { p_shipment_id?: number; p_tenant_id: number }
        Returns: number
      }
      refresh_shipment_investor_profits: {
        Args: { p_shipment_id: number }
        Returns: Json
      }
      register_thrift_stock_from_app:
        | {
            Args: {
              p_barcode: string
              p_box_id?: number
              p_brand_name?: string
              p_category_id?: number
              p_color?: string
              p_condition?: string
              p_cost_of_goods_sold?: number
              p_extra_expense_cost?: number
              p_extra_origin_purchase_expense?: number
              p_extra_weight?: number
              p_image_url: string
              p_inserted_by?: string
              p_listed_price?: number
              p_note?: string
              p_origin_purchase_price?: number
              p_product_weight?: number
              p_section?: string
              p_shelf_id?: number
              p_shipment_id: number
              p_size?: string
              p_target_price?: number
              p_tenant_id: number
              p_type_id?: number
            }
            Returns: number
          }
        | {
            Args: {
              p_barcode: string
              p_box_id?: number
              p_brand_name: string
              p_category_id: number
              p_color: string
              p_condition: string
              p_cost_of_goods_sold?: number
              p_extra_origin_unit_price?: number
              p_extra_weight?: number
              p_image_url: string
              p_inserted_by?: string
              p_listed_price?: number
              p_listed_unit_price?: number
              p_note?: string
              p_origin_purchase_price?: number
              p_origin_unit_price?: number
              p_product_weight?: number
              p_section: string
              p_shelf_id: number
              p_shipment_id: number
              p_size: string
              p_target_price?: number
              p_tenant_id: number
              p_type_id: number
            }
            Returns: number
          }
      remove_commerce_invoice_item_transactional: {
        Args: { p_invoice_id: number; p_order_item_id: number }
        Returns: undefined
      }
      resolve_costing_file_creator_label: {
        Args: {
          p_created_by_email: string
          p_customer_group_id: number
          p_tenant_id: number
        }
        Returns: string
      }
      resolve_parent_tenant_id: {
        Args: { p_tenant_id: number }
        Returns: number
      }
      resolve_tenant_for_entry: {
        Args: { p_hostname?: string; p_slug?: string }
        Returns: {
          id: number
          name: string
          public_domain: string
          slug: string
        }[]
      }
      resolve_thrift_barcode: {
        Args: { p_scanned_value: string; p_tenant_id: number }
        Returns: {
          barcode_id: string
          status: string
        }[]
      }
      resolve_thrift_barcode_id_internal: {
        Args: { p_scanned_value: string; p_tenant_id: number }
        Returns: string
      }
      revoke_costing_file_viewer: {
        Args: { p_costing_file_id: number; p_membership_id: number }
        Returns: {
          costing_file_id: number
          costing_file_viewer_id: number
          created_at: string
          membership_id: number
          updated_at: string
        }[]
      }
      round_bdt_up_to_zero_or_five: {
        Args: { p_value: number }
        Returns: number
      }
      search_stock_network: {
        Args: {
          p_context_tenant_id: number
          p_exclude_zero_qty?: boolean
          p_limit?: number
          p_mode?: string
          p_offset?: number
          p_product_id?: number
          p_search?: string
          p_search_field?: string
          p_shipment_id?: number
          p_status?: string
        }
        Returns: {
          allocated_qty: number
          barcode: string
          box_damage_qty: number
          box_less_qty: number
          cost: number
          excellent_qty: number
          expired_qty: number
          global_qty: number
          global_stock_id: number
          holding_tenant_id: number
          holding_tenant_name: string
          image_url: string
          is_own_tenant: boolean
          is_pickable: boolean
          name: string
          parent_tenant_id: number
          product_code: string
          product_group_key: string
          product_id: number
          reserved_qty: number
          shipment_id: number
          sort_rank: number
          stolen_qty: number
          total_qty: number
        }[]
      }
      set_tenant_module_submodule_for_superadmin: {
        Args: {
          p_is_enabled: boolean
          p_parent_module_key: string
          p_submodule_key: string
          p_tenant_id: number
        }
        Returns: {
          created_at: string
          id: number
          is_enabled: boolean
          parent_module_key: string
          submodule_key: string
          tenant_id: number
          updated_at: string
        }[]
      }
      show_limit: { Args: never; Returns: number }
      show_trgm: { Args: { "": string }; Returns: string[] }
      thrift_barcode_sequence_sort_key: {
        Args: { p_barcode_id: string }
        Returns: {
          sort_prefix: string
          sort_seq: number
          sort_year: string
        }[]
      }
      unassign_commerce_order_item_inventory_transactional: {
        Args: { p_invoice_id: number; p_order_item_id: number }
        Returns: undefined
      }
      update_commerce_invoice_charges: {
        Args: {
          p_advance_amount?: number
          p_amount_paid?: number
          p_brand_address?: string
          p_brand_name?: string
          p_client_name?: string
          p_client_tr?: string
          p_cod?: number
          p_delivered_by?: string
          p_delivery_charge?: number
          p_discount_amount?: number
          p_invoice_date?: string
          p_invoice_id: number
          p_note?: string
          p_previous_due?: number
          p_print_charge?: number
          p_status?: string
          p_thank_you_message?: string
          p_total_boxes?: number
          p_wrapping_charge?: number
        }
        Returns: Json
      }
      update_commerce_invoice_item_transactional: {
        Args: {
          p_invoice_id: number
          p_order_item_id: number
          p_quantity: number
          p_recipient_price_bdt: number
          p_sell_price_bdt: number
          p_unit: string
        }
        Returns: undefined
      }
      update_costing_file: {
        Args: {
          p_customer_group_id?: number
          p_id: number
          p_market?: string
          p_name?: string
        }
        Returns: {
          admin_profit_rate: number
          cargo_rate_1kg: number
          cargo_rate_2kg: number
          conversion_rate: number
          created_at: string
          created_by_email: string
          customer_group_id: number
          default_shipment_id: number
          id: number
          market: string
          name: string
          status: Database["public"]["Enums"]["costing_file_status"]
          tenant_id: number
          updated_at: string
        }[]
      }
      update_costing_file_item_customer_profit: {
        Args: { p_customer_profit_rate: number; p_id: number }
        Returns: {
          customer_profit_rate: number
          id: number
          updated_at: string
        }[]
      }
      update_costing_file_item_enrichment:
        | {
            Args: {
              p_delivery_price_gbp?: number
              p_id: number
              p_image_url?: string
              p_name?: string
              p_package_weight?: number
              p_price_in_web_gbp?: number
              p_product_weight?: number
            }
            Returns: {
              costing_file_id: number
              delivery_price_gbp: number
              id: number
              image_url: string
              name: string
              package_weight: number
              price_in_web_gbp: number
              product_weight: number
              updated_at: string
            }[]
          }
        | {
            Args: {
              p_delivery_price_gbp: number
              p_id: number
              p_image_url: string
              p_item_type: string
              p_name: string
              p_package_weight: number
              p_price_in_web_gbp: number
              p_product_weight: number
            }
            Returns: {
              assigned_shipment_id: number
              auxiliary_price_gbp: number
              cargo_rate: number
              costing_file_id: number
              costing_price_bdt: number
              costing_price_gbp: number
              created_at: string
              created_by_email: string
              customer_profit_rate: number
              delivery_price_gbp: number
              id: number
              image_url: string
              item_price_gbp: number
              name: string
              offer_price_bdt: number
              package_weight: number
              price_in_web_gbp: number
              product_weight: number
              quantity: number
              status: Database["public"]["Enums"]["costing_file_item_status"]
              updated_at: string
              website_url: string
            }[]
          }
      update_costing_file_item_offer: {
        Args: {
          p_auxiliary_price_gbp?: number
          p_cargo_rate?: number
          p_costing_price_bdt?: number
          p_costing_price_gbp?: number
          p_id: number
          p_item_price_gbp?: number
          p_offer_price_override_bdt?: number
        }
        Returns: {
          auxiliary_price_gbp: number
          cargo_rate: number
          costing_price_bdt: number
          costing_price_gbp: number
          id: number
          item_price_gbp: number
          offer_price_bdt: number
          offer_price_override_bdt: number
          updated_at: string
        }[]
      }
      update_costing_file_item_status: {
        Args: {
          p_id: number
          p_status: Database["public"]["Enums"]["costing_file_item_status"]
        }
        Returns: {
          id: number
          status: Database["public"]["Enums"]["costing_file_item_status"]
          updated_at: string
        }[]
      }
      update_costing_file_items_customer_profit: {
        Args: { p_costing_file_id: number; p_customer_profit_rate: number }
        Returns: {
          customer_profit_rate: number
          id: number
          updated_at: string
        }[]
      }
      update_costing_file_pricing: {
        Args: {
          p_admin_profit_rate?: number
          p_cargo_rate_1kg?: number
          p_cargo_rate_2kg?: number
          p_conversion_rate?: number
          p_id: number
        }
        Returns: {
          admin_profit_rate: number
          cargo_rate_1kg: number
          cargo_rate_2kg: number
          conversion_rate: number
          id: number
          updated_at: string
        }[]
      }
      update_costing_file_status: {
        Args: {
          p_id: number
          p_status: Database["public"]["Enums"]["costing_file_status"]
        }
        Returns: {
          id: number
          status: Database["public"]["Enums"]["costing_file_status"]
          updated_at: string
        }[]
      }
      update_global_shipment_items_order: {
        Args: { p_items: Json }
        Returns: undefined
      }
      update_invoice_item_transactional: {
        Args: {
          p_invoice_item_id: number
          p_quantity: number
          p_sell_price_amount: number
          p_unit: string
        }
        Returns: Json
      }
      update_payment_allocation_amount: {
        Args: { p_allocation_id: number; p_amount: number; p_tenant_id: number }
        Returns: {
          amount: number
          commerce_invoice_id: number | null
          created_at: string
          global_invoice_id: number | null
          id: number
          invoice_id: number | null
          payment_id: number
          tenant_id: number
        }
        SetofOptions: {
          from: "*"
          to: "payment_allocations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_shipment: {
        Args: { p_field: string; p_id: number; p_value: string }
        Returns: {
          cargo_conversion_rate: number | null
          cargo_rate: number | null
          created_at: string
          id: number
          inventory_added: boolean
          market_code: string | null
          name: string
          product_conversion_rate: number | null
          received_weight: number | null
          shipment_type: string
          status: string
          tenant_id: number
          tenant_shipment_id: number
          transaction_rate: number | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "shipments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_shipment_investment_cost_share: {
        Args: { p_cost_share_pct: number; p_shipment_investment_id: number }
        Returns: {
          actual_profit: number
          allocated_cost: number
          computed_profit: number
          cost_share_pct: number | null
          created_at: string
          id: number
          invested_amount: number
          investor_id: number
          profit_status: string
          shipment_id: number
          status: Database["public"]["Enums"]["shipment_investment_status"]
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "shipment_investments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_store: {
        Args: { p_id: number; p_name: string; p_vendor_code: string }
        Returns: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
        }
        SetofOptions: {
          from: "*"
          to: "stores"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_store_access: {
        Args: { p_id: number; p_status: boolean }
        Returns: {
          created_at: string
          customer_group_id: number
          id: number
          see_price: boolean
          status: boolean
          store_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "store_access"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_store_access_fields: {
        Args: { p_id: number; p_see_price?: boolean; p_status?: boolean }
        Returns: {
          created_at: string
          customer_group_id: number
          id: number
          see_price: boolean
          status: boolean
          store_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "store_access"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_tenant_for_superadmin: {
        Args: {
          p_is_active: boolean
          p_name: string
          p_parent_id?: number
          p_public_domain?: string
          p_slug: string
          p_tenant_id: number
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number
          preference: Json
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      update_tenant_module_for_superadmin: {
        Args: {
          p_id: number
          p_is_active?: boolean
          p_module_key?: string
          p_tenant_id?: number
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          module_key: string
          tenant_id: number
          updated_at: string
        }[]
      }
      update_tenant_preference_for_admin: {
        Args: { p_preference: Json; p_tenant_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          parent_id: number
          preference: Json
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      upsert_global_stock_allocation: {
        Args: {
          p_child_tenant_id: number
          p_parent_tenant_id: number
          p_quantity: number
          p_stock_id: number
        }
        Returns: Json
      }
      upsert_invoice_charge_line: {
        Args: {
          p_amount: number
          p_charge_type: Database["public"]["Enums"]["invoice_charge_type"]
          p_invoice_id: number
          p_note?: string
        }
        Returns: {
          amount: number
          charge_type: Database["public"]["Enums"]["invoice_charge_type"]
          created_at: string
          id: number
          invoice_id: number
          note: string | null
          parent_tenant_id: number
          posted_to_ledger: boolean
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "invoice_charge_lines"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      user_can_access_tenant_fetch: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      user_can_manage_parent_tenant: {
        Args: { p_parent_tenant_id: number }
        Returns: boolean
      }
    }
    Enums: {
      app_role: "superadmin" | "admin" | "staff" | "viewer" | "investor"
      commerce_order_status:
        | "placed"
        | "reviewing"
        | "shipping"
        | "delivered"
        | "cancelled"
      costing_file_item_status: "pending" | "accepted" | "rejected"
      costing_file_status:
        | "draft"
        | "customer_submitted"
        | "in_review"
        | "priced"
        | "offered"
        | "accepted"
        | "po_placed"
        | "cancelled"
        | "completed"
      customer_group_role: "admin" | "negotiator" | "staff"
      global_invoice_type: "retail" | "wholesale" | "dropship"
      global_shipment_item_add_method: "order" | "costing" | "manual"
      global_shipment_type: "domestic" | "international"
      global_source_module: "wholesale" | "retail" | "commerce"
      investor_payment_method: "cash" | "bank" | "mobile_banking" | "other"
      investor_transaction_type: "deposit" | "withdrawal" | "profit_payout"
      invoice_charge_type: "cod" | "packing" | "print" | "delivery" | "other"
      koba_order_status:
        | "pending"
        | "confirmed"
        | "processing"
        | "shipped"
        | "delivered"
        | "cancelled"
      order_status:
        | "customer_submit"
        | "direct_priced"
        | "priced"
        | "negotiate"
        | "final_offered"
        | "ordered"
        | "processing"
        | "invoicing"
        | "invoiced"
      shipment_investment_status: "active" | "closed" | "cancelled"
      thrift_condition: "NEW_WITH_TAGS" | "EXCELLENT" | "GOOD" | "FAIR"
      thrift_delivery_status:
        | "PENDING"
        | "SHIPPED"
        | "DELIVERED"
        | "RETURNED"
        | "PARTIALLY_RETURNED"
      thrift_item_status: "SOLD" | "RETURNED"
      thrift_ledger_source: "INVOICE" | "SHIPMENT" | "OPERATIONAL"
      thrift_ledger_type: "REVENUE" | "EXPENSE" | "REFUND" | "LOSS"
      thrift_payment_status: "UNPAID" | "PAID" | "REFUNDED"
      thrift_return_action: "RESTOCK" | "WRITE_OFF"
      thrift_section: "MALE" | "FEMALE" | "UNISEX" | "KIDS" | "HOME"
      thrift_stock_status: "AVAILABLE" | "OUT_OF_STOCK" | "DAMAGED" | "STOLEN"
      thrift_stock_type: "SINGLE" | "BULK"
      thrift_transaction_method: "CASH" | "CARD" | "MOBILE_BANKING" | "COD"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["superadmin", "admin", "staff", "viewer", "investor"],
      commerce_order_status: [
        "placed",
        "reviewing",
        "shipping",
        "delivered",
        "cancelled",
      ],
      costing_file_item_status: ["pending", "accepted", "rejected"],
      costing_file_status: [
        "draft",
        "customer_submitted",
        "in_review",
        "priced",
        "offered",
        "accepted",
        "po_placed",
        "cancelled",
        "completed",
      ],
      customer_group_role: ["admin", "negotiator", "staff"],
      global_invoice_type: ["retail", "wholesale", "dropship"],
      global_shipment_item_add_method: ["order", "costing", "manual"],
      global_shipment_type: ["domestic", "international"],
      global_source_module: ["wholesale", "retail", "commerce"],
      investor_payment_method: ["cash", "bank", "mobile_banking", "other"],
      investor_transaction_type: ["deposit", "withdrawal", "profit_payout"],
      invoice_charge_type: ["cod", "packing", "print", "delivery", "other"],
      koba_order_status: [
        "pending",
        "confirmed",
        "processing",
        "shipped",
        "delivered",
        "cancelled",
      ],
      order_status: [
        "customer_submit",
        "direct_priced",
        "priced",
        "negotiate",
        "final_offered",
        "ordered",
        "processing",
        "invoicing",
        "invoiced",
      ],
      shipment_investment_status: ["active", "closed", "cancelled"],
      thrift_condition: ["NEW_WITH_TAGS", "EXCELLENT", "GOOD", "FAIR"],
      thrift_delivery_status: [
        "PENDING",
        "SHIPPED",
        "DELIVERED",
        "RETURNED",
        "PARTIALLY_RETURNED",
      ],
      thrift_item_status: ["SOLD", "RETURNED"],
      thrift_ledger_source: ["INVOICE", "SHIPMENT", "OPERATIONAL"],
      thrift_ledger_type: ["REVENUE", "EXPENSE", "REFUND", "LOSS"],
      thrift_payment_status: ["UNPAID", "PAID", "REFUNDED"],
      thrift_return_action: ["RESTOCK", "WRITE_OFF"],
      thrift_section: ["MALE", "FEMALE", "UNISEX", "KIDS", "HOME"],
      thrift_stock_status: ["AVAILABLE", "OUT_OF_STOCK", "DAMAGED", "STOLEN"],
      thrift_stock_type: ["SINGLE", "BULK"],
      thrift_transaction_method: ["CASH", "CARD", "MOBILE_BANKING", "COD"],
    },
  },
} as const

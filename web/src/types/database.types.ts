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
          parent_tenant_id: number | null
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
          parent_tenant_id?: number | null
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
          parent_tenant_id?: number | null
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
            foreignKeyName: "billing_profiles_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
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
      cargo_companies: {
        Row: {
          address: string | null
          code: string
          created_at: string
          email: string | null
          id: number
          is_active: boolean
          is_default: boolean
          name: string
          notes: string | null
          parent_tenant_id: number | null
          phone: string | null
          tenant_id: number | null
          updated_at: string
          wallet_entity_id: number | null
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          email?: string | null
          id?: number
          is_active?: boolean
          is_default?: boolean
          name: string
          notes?: string | null
          parent_tenant_id?: number | null
          phone?: string | null
          tenant_id?: number | null
          updated_at?: string
          wallet_entity_id?: number | null
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          email?: string | null
          id?: number
          is_active?: boolean
          is_default?: boolean
          name?: string
          notes?: string | null
          parent_tenant_id?: number | null
          phone?: string | null
          tenant_id?: number | null
          updated_at?: string
          wallet_entity_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "cargo_companies_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cargo_companies_tenant_id_fkey"
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
      courier_remittance_batches: {
        Row: {
          allocated_amount: number
          bank_trx_id: string | null
          batch_no: string
          courier_charges_amount: number
          courier_service_id: string
          created_at: string
          created_by: string | null
          gross_cod_amount: number
          id: number
          net_deposited_amount: number
          note: string | null
          payment_date: string
          posted_at: string | null
          posted_by: string | null
          status: string
          tenant_id: number
          updated_at: string
          variance_amount: number
        }
        Insert: {
          allocated_amount?: number
          bank_trx_id?: string | null
          batch_no: string
          courier_charges_amount?: number
          courier_service_id: string
          created_at?: string
          created_by?: string | null
          gross_cod_amount?: number
          id?: never
          net_deposited_amount?: number
          note?: string | null
          payment_date?: string
          posted_at?: string | null
          posted_by?: string | null
          status?: string
          tenant_id: number
          updated_at?: string
          variance_amount?: number
        }
        Update: {
          allocated_amount?: number
          bank_trx_id?: string | null
          batch_no?: string
          courier_charges_amount?: number
          courier_service_id?: string
          created_at?: string
          created_by?: string | null
          gross_cod_amount?: number
          id?: never
          net_deposited_amount?: number
          note?: string | null
          payment_date?: string
          posted_at?: string | null
          posted_by?: string | null
          status?: string
          tenant_id?: number
          updated_at?: string
          variance_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "courier_remittance_batches_courier_service_id_fkey"
            columns: ["courier_service_id"]
            isOneToOne: false
            referencedRelation: "courier_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_remittance_batches_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      courier_remittance_items: {
        Row: {
          awb_number: string | null
          batch_id: number
          cod_collected_amount: number
          courier_charge_amount: number
          created_at: string
          error_message: string | null
          global_invoice_id: number | null
          id: number
          net_remitted_amount: number
          shop_order_id: number | null
          status: string
          tenant_id: number
          tracking_number: string | null
        }
        Insert: {
          awb_number?: string | null
          batch_id: number
          cod_collected_amount?: number
          courier_charge_amount?: number
          created_at?: string
          error_message?: string | null
          global_invoice_id?: number | null
          id?: never
          net_remitted_amount?: number
          shop_order_id?: number | null
          status?: string
          tenant_id: number
          tracking_number?: string | null
        }
        Update: {
          awb_number?: string | null
          batch_id?: number
          cod_collected_amount?: number
          courier_charge_amount?: number
          created_at?: string
          error_message?: string | null
          global_invoice_id?: number | null
          id?: never
          net_remitted_amount?: number
          shop_order_id?: number | null
          status?: string
          tenant_id?: number
          tracking_number?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "courier_remittance_items_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "courier_remittance_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_remittance_items_global_invoice_id_fkey"
            columns: ["global_invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_remittance_items_global_invoice_id_fkey"
            columns: ["global_invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_remittance_items_shop_order_id_fkey"
            columns: ["shop_order_id"]
            isOneToOne: false
            referencedRelation: "shop_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_remittance_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      courier_services: {
        Row: {
          cod_fee_flat_amount: number | null
          cod_fee_mode: string
          cod_fee_notes: string | null
          cod_fee_percent: number | null
          code: string
          created_at: string
          deduct_cod_from_margin_default: boolean
          delivery_attempt_count: number
          hub_hold_days: number
          id: string
          inside_dhaka_fee: number
          inside_dhaka_return_fee: number | null
          is_active: boolean
          name: string
          notes: string | null
          open_box_default_allowed: boolean
          outside_dhaka_fee: number
          outside_dhaka_return_fee: number | null
          return_fee_mode: string
          return_fee_percent: number | null
          tenant_id: number | null
          tracking_url_template: string | null
          updated_at: string
          wallet_entity_id: number
        }
        Insert: {
          cod_fee_flat_amount?: number | null
          cod_fee_mode?: string
          cod_fee_notes?: string | null
          cod_fee_percent?: number | null
          code: string
          created_at?: string
          deduct_cod_from_margin_default?: boolean
          delivery_attempt_count?: number
          hub_hold_days?: number
          id?: string
          inside_dhaka_fee?: number
          inside_dhaka_return_fee?: number | null
          is_active?: boolean
          name: string
          notes?: string | null
          open_box_default_allowed?: boolean
          outside_dhaka_fee?: number
          outside_dhaka_return_fee?: number | null
          return_fee_mode?: string
          return_fee_percent?: number | null
          tenant_id?: number | null
          tracking_url_template?: string | null
          updated_at?: string
          wallet_entity_id?: number
        }
        Update: {
          cod_fee_flat_amount?: number | null
          cod_fee_mode?: string
          cod_fee_notes?: string | null
          cod_fee_percent?: number | null
          code?: string
          created_at?: string
          deduct_cod_from_margin_default?: boolean
          delivery_attempt_count?: number
          hub_hold_days?: number
          id?: string
          inside_dhaka_fee?: number
          inside_dhaka_return_fee?: number | null
          is_active?: boolean
          name?: string
          notes?: string | null
          open_box_default_allowed?: boolean
          outside_dhaka_fee?: number
          outside_dhaka_return_fee?: number | null
          return_fee_mode?: string
          return_fee_percent?: number | null
          tenant_id?: number | null
          tracking_url_template?: string | null
          updated_at?: string
          wallet_entity_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "courier_services_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_demand_bucket_items: {
        Row: {
          barcode: string | null
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string | null
          name: string
          note: string | null
          popped_at: string | null
          popped_into_id: number | null
          popped_into_type: string | null
          product_code: string | null
          product_id: number
          quantity: number
          source_id: number | null
          source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          status: Database["public"]["Enums"]["demand_bucket_status"]
          tenant_id: number
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          billing_profile_id: number
          created_at?: string
          id?: never
          image_url?: string | null
          name: string
          note?: string | null
          popped_at?: string | null
          popped_into_id?: number | null
          popped_into_type?: string | null
          product_code?: string | null
          product_id: number
          quantity?: number
          source_id?: number | null
          source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          status?: Database["public"]["Enums"]["demand_bucket_status"]
          tenant_id: number
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          billing_profile_id?: number
          created_at?: string
          id?: never
          image_url?: string | null
          name?: string
          note?: string | null
          popped_at?: string | null
          popped_into_id?: number | null
          popped_into_type?: string | null
          product_code?: string | null
          product_id?: number
          quantity?: number
          source_id?: number | null
          source_type?: Database["public"]["Enums"]["demand_bucket_source_type"]
          status?: Database["public"]["Enums"]["demand_bucket_status"]
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_demand_bucket_items_billing_profile_id_fkey"
            columns: ["billing_profile_id"]
            isOneToOne: false
            referencedRelation: "billing_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_demand_bucket_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_demand_bucket_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_group_member_grants: {
        Row: {
          action: string
          created_at: string
          customer_group_member_id: number
          effect: string
          id: number
          module_key: string
          updated_at: string
        }
        Insert: {
          action: string
          created_at?: string
          customer_group_member_id: number
          effect: string
          id?: number
          module_key: string
          updated_at?: string
        }
        Update: {
          action?: string
          created_at?: string
          customer_group_member_id?: number
          effect?: string
          id?: number
          module_key?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_group_member_grants_customer_group_member_id_fkey"
            columns: ["customer_group_member_id"]
            isOneToOne: false
            referencedRelation: "customer_group_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_group_member_grants_module_key_fkey"
            columns: ["module_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
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
          tenant_role_id: number | null
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
          tenant_role_id?: number | null
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
          tenant_role_id?: number | null
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
          {
            foreignKeyName: "customer_group_members_tenant_role_id_fkey"
            columns: ["tenant_role_id"]
            isOneToOne: false
            referencedRelation: "tenant_roles"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_group_shop_profiles: {
        Row: {
          created_at: string
          customer_group_id: number
          default_can_add_to_cart: boolean
          default_can_browse: boolean
          default_can_negotiate: boolean
          default_can_place_order: boolean
          default_can_see_buy_price: boolean
          default_can_see_resell_minimum_price: boolean
          default_can_see_sell_price: boolean
          default_can_set_dropship_price: boolean
          default_can_view_quantity: boolean
          id: number
          is_active: boolean
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          customer_group_id: number
          default_can_add_to_cart?: boolean
          default_can_browse?: boolean
          default_can_negotiate?: boolean
          default_can_place_order?: boolean
          default_can_see_buy_price?: boolean
          default_can_see_resell_minimum_price?: boolean
          default_can_see_sell_price?: boolean
          default_can_set_dropship_price?: boolean
          default_can_view_quantity?: boolean
          id?: never
          is_active?: boolean
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          customer_group_id?: number
          default_can_add_to_cart?: boolean
          default_can_browse?: boolean
          default_can_negotiate?: boolean
          default_can_place_order?: boolean
          default_can_see_buy_price?: boolean
          default_can_see_resell_minimum_price?: boolean
          default_can_see_sell_price?: boolean
          default_can_set_dropship_price?: boolean
          default_can_view_quantity?: boolean
          id?: never
          is_active?: boolean
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_group_shop_profiles_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_group_shop_profiles_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
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
      customer_order_backlog_items: {
        Row: {
          backlog_status: string
          billing_profile_id: number
          created_at: string
          fulfilled_quantity: number
          id: number
          order_id: number | null
          order_item_id: number | null
          product_id: number
          requested_quantity: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          backlog_status?: string
          billing_profile_id: number
          created_at?: string
          fulfilled_quantity?: number
          id?: never
          order_id?: number | null
          order_item_id?: number | null
          product_id: number
          requested_quantity: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          backlog_status?: string
          billing_profile_id?: number
          created_at?: string
          fulfilled_quantity?: number
          id?: never
          order_id?: number | null
          order_item_id?: number | null
          product_id?: number
          requested_quantity?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_order_backlog_items_billing_profile_id_fkey"
            columns: ["billing_profile_id"]
            isOneToOne: false
            referencedRelation: "billing_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_order_backlog_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "shop_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_order_backlog_items_order_item_id_fkey"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "shop_order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_order_backlog_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_order_backlog_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      entity_tags: {
        Row: {
          created_at: string
          entity_id: string
          entity_type: string
          id: number
          tag_id: number
          tenant_id: number
        }
        Insert: {
          created_at?: string
          entity_id: string
          entity_type: string
          id?: number
          tag_id: number
          tenant_id: number
        }
        Update: {
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: number
          tag_id?: number
          tenant_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "entity_tags_tag_id_fkey"
            columns: ["tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entity_tags_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      gift_rule_items: {
        Row: {
          created_at: string
          id: number
          product_id: number
          quantity: number
          rule_id: number
        }
        Insert: {
          created_at?: string
          id?: never
          product_id: number
          quantity?: number
          rule_id: number
        }
        Update: {
          created_at?: string
          id?: never
          product_id?: number
          quantity?: number
          rule_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "gift_rule_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "gift_rule_items_rule_id_fkey"
            columns: ["rule_id"]
            isOneToOne: false
            referencedRelation: "gift_rules"
            referencedColumns: ["id"]
          },
        ]
      }
      gift_rule_redemptions: {
        Row: {
          id: number
          order_id: number
          redeemed_at: string
          rule_id: number
        }
        Insert: {
          id?: never
          order_id: number
          redeemed_at?: string
          rule_id: number
        }
        Update: {
          id?: never
          order_id?: number
          redeemed_at?: string
          rule_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "gift_rule_redemptions_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "shop_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "gift_rule_redemptions_rule_id_fkey"
            columns: ["rule_id"]
            isOneToOne: false
            referencedRelation: "gift_rules"
            referencedColumns: ["id"]
          },
        ]
      }
      gift_rules: {
        Row: {
          cost_ownership: string
          created_at: string
          customer_group_id: number | null
          id: number
          is_active: boolean
          name: string
          priority: number
          updated_at: string
        }
        Insert: {
          cost_ownership?: string
          created_at?: string
          customer_group_id?: number | null
          id?: never
          is_active?: boolean
          name: string
          priority?: number
          updated_at?: string
        }
        Update: {
          cost_ownership?: string
          created_at?: string
          customer_group_id?: number | null
          id?: never
          is_active?: boolean
          name?: string
          priority?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "gift_rules_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
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
      global_payments: {
        Row: {
          amount: number
          billing_profile_id: number | null
          collection_source: Database["public"]["Enums"]["collection_source_type"]
          created_at: string
          id: number
          method: string | null
          note: string | null
          payment_date: string
          reference: string | null
          tenant_id: number
          unallocated_amount: number
        }
        Insert: {
          amount: number
          billing_profile_id?: number | null
          collection_source?: Database["public"]["Enums"]["collection_source_type"]
          created_at?: string
          id?: number
          method?: string | null
          note?: string | null
          payment_date?: string
          reference?: string | null
          tenant_id: number
          unallocated_amount?: number
        }
        Update: {
          amount?: number
          billing_profile_id?: number | null
          collection_source?: Database["public"]["Enums"]["collection_source_type"]
          created_at?: string
          id?: number
          method?: string | null
          note?: string | null
          payment_date?: string
          reference?: string | null
          tenant_id?: number
          unallocated_amount?: number
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
      global_shipment_cost_entries: {
        Row: {
          allocation: string | null
          amount: number
          cost_type: Database["public"]["Enums"]["global_shipment_cost_type"]
          created_at: string
          currency_id: number | null
          entity_id: number | null
          entity_type: string | null
          exchange_rate: number
          id: number
          metadata: Json
          parent_tenant_id: number
          payment_source: string | null
          section_id: number | null
          settled_at: string | null
          settlement_ledger_id: string | null
          shipment_id: number
          updated_at: string
        }
        Insert: {
          allocation?: string | null
          amount: number
          cost_type: Database["public"]["Enums"]["global_shipment_cost_type"]
          created_at?: string
          currency_id?: number | null
          entity_id?: number | null
          entity_type?: string | null
          exchange_rate?: number
          id?: never
          metadata?: Json
          parent_tenant_id: number
          payment_source?: string | null
          section_id?: number | null
          settled_at?: string | null
          settlement_ledger_id?: string | null
          shipment_id: number
          updated_at?: string
        }
        Update: {
          allocation?: string | null
          amount?: number
          cost_type?: Database["public"]["Enums"]["global_shipment_cost_type"]
          created_at?: string
          currency_id?: number | null
          entity_id?: number | null
          entity_type?: string | null
          exchange_rate?: number
          id?: never
          metadata?: Json
          parent_tenant_id?: number
          payment_source?: string | null
          section_id?: number | null
          settled_at?: string | null
          settlement_ledger_id?: string | null
          shipment_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_shipment_cost_entries_currency_id_fkey"
            columns: ["currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_cost_entries_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_cost_entries_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "global_shipment_sections"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_cost_entries_shipment_id_fkey"
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
          landed_cost_bdt: number | null
          name: string
          ordered_quantity: number
          package_weight: number
          product_code: string | null
          product_id: number | null
          product_weight: number
          purchase_price: number
          received_quantity: number | null
          section_id: number | null
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
          landed_cost_bdt?: number | null
          name: string
          ordered_quantity: number
          package_weight?: number
          product_code?: string | null
          product_id?: number | null
          product_weight?: number
          purchase_price?: number
          received_quantity?: number | null
          section_id?: number | null
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
          landed_cost_bdt?: number | null
          name?: string
          ordered_quantity?: number
          package_weight?: number
          product_code?: string | null
          product_id?: number | null
          product_weight?: number
          purchase_price?: number
          received_quantity?: number | null
          section_id?: number | null
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
            foreignKeyName: "global_shipment_items_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "global_shipment_sections"
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
      global_shipment_sections: {
        Row: {
          created_at: string
          id: number
          metadata: Json
          parent_tenant_id: number
          shipment_id: number
          sort_order: number
          title: string
          updated_at: string
          vendor_id: number
        }
        Insert: {
          created_at?: string
          id?: number
          metadata?: Json
          parent_tenant_id: number
          shipment_id: number
          sort_order?: number
          title: string
          updated_at?: string
          vendor_id: number
        }
        Update: {
          created_at?: string
          id?: number
          metadata?: Json
          parent_tenant_id?: number
          shipment_id?: number
          sort_order?: number
          title?: string
          updated_at?: string
          vendor_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "global_shipment_sections_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_sections_shipment_id_fkey"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "global_shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipment_sections_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      global_shipments: {
        Row: {
          assigned_child_tenant_id: number | null
          cargo_company_id: number | null
          cargo_invoice_total: number | null
          created_at: string
          id: number
          inventory_added: boolean
          name: string
          parent_tenant_id: number
          progress_flow_id: number | null
          progress_tag_id: number | null
          public_tracking_token: string | null
          purchase_invoice_total: number | null
          received_date: string | null
          received_weight: number | null
          shipment_cost_currency_id: number | null
          shipment_purchase_currency_id: number | null
          status: string
          stock_ready: boolean
          tenant_shipment_id: number | null
          total_weight_kg: number | null
          type: Database["public"]["Enums"]["global_shipment_type"]
          updated_at: string
          vendor_id: number | null
        }
        Insert: {
          assigned_child_tenant_id?: number | null
          cargo_company_id?: number | null
          cargo_invoice_total?: number | null
          created_at?: string
          id?: number
          inventory_added?: boolean
          name: string
          parent_tenant_id: number
          progress_flow_id?: number | null
          progress_tag_id?: number | null
          public_tracking_token?: string | null
          purchase_invoice_total?: number | null
          received_date?: string | null
          received_weight?: number | null
          shipment_cost_currency_id?: number | null
          shipment_purchase_currency_id?: number | null
          status?: string
          stock_ready?: boolean
          tenant_shipment_id?: number | null
          total_weight_kg?: number | null
          type?: Database["public"]["Enums"]["global_shipment_type"]
          updated_at?: string
          vendor_id?: number | null
        }
        Update: {
          assigned_child_tenant_id?: number | null
          cargo_company_id?: number | null
          cargo_invoice_total?: number | null
          created_at?: string
          id?: number
          inventory_added?: boolean
          name?: string
          parent_tenant_id?: number
          progress_flow_id?: number | null
          progress_tag_id?: number | null
          public_tracking_token?: string | null
          purchase_invoice_total?: number | null
          received_date?: string | null
          received_weight?: number | null
          shipment_cost_currency_id?: number | null
          shipment_purchase_currency_id?: number | null
          status?: string
          stock_ready?: boolean
          tenant_shipment_id?: number | null
          total_weight_kg?: number | null
          type?: Database["public"]["Enums"]["global_shipment_type"]
          updated_at?: string
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "global_shipments_assigned_child_tenant_id_fkey"
            columns: ["assigned_child_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipments_cargo_company_id_fkey"
            columns: ["cargo_company_id"]
            isOneToOne: false
            referencedRelation: "cargo_companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipments_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipments_progress_flow_id_fkey"
            columns: ["progress_flow_id"]
            isOneToOne: false
            referencedRelation: "shipment_progress_flows"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_shipments_progress_tag_id_fkey"
            columns: ["progress_tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
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
          {
            foreignKeyName: "global_shipments_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
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
          availability: Database["public"]["Enums"]["stock_availability"]
          created_at: string
          grade_tag_id: number | null
          id: number
          is_usable: boolean
          location_id: number | null
          parent_tenant_id: number
          quantity: number
          shipment_item_id: number
          stock_type_id: number | null
          updated_at: string
        }
        Insert: {
          availability?: Database["public"]["Enums"]["stock_availability"]
          created_at?: string
          grade_tag_id?: number | null
          id?: number
          is_usable?: boolean
          location_id?: number | null
          parent_tenant_id: number
          quantity?: number
          shipment_item_id: number
          stock_type_id?: number | null
          updated_at?: string
        }
        Update: {
          availability?: Database["public"]["Enums"]["stock_availability"]
          created_at?: string
          grade_tag_id?: number | null
          id?: number
          is_usable?: boolean
          location_id?: number | null
          parent_tenant_id?: number
          quantity?: number
          shipment_item_id?: number
          stock_type_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_stocks_grade_tag_id_fkey"
            columns: ["grade_tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_stocks_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "stock_locations"
            referencedColumns: ["id"]
          },
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
          currency_code: string
          email: string | null
          id: number
          is_active: boolean
          name: string
          notes: string | null
          phone: string | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          currency_code?: string
          email?: string | null
          id?: number
          is_active?: boolean
          name: string
          notes?: string | null
          phone?: string | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          currency_code?: string
          email?: string | null
          id?: number
          is_active?: boolean
          name?: string
          notes?: string | null
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
      invoice_payments: {
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
            foreignKeyName: "payment_allocations_global_invoice_id_fkey"
            columns: ["global_invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_allocations_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "global_payments"
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
      membership_grants: {
        Row: {
          action: string
          created_at: string
          created_by_email: string | null
          effect: string
          id: number
          membership_id: number
          module_key: string
          updated_at: string
        }
        Insert: {
          action: string
          created_at?: string
          created_by_email?: string | null
          effect: string
          id?: number
          membership_id: number
          module_key: string
          updated_at?: string
        }
        Update: {
          action?: string
          created_at?: string
          created_by_email?: string | null
          effect?: string
          id?: number
          membership_id?: number
          module_key?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "membership_grants_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: false
            referencedRelation: "memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "membership_grants_module_key_fkey"
            columns: ["module_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
          },
        ]
      }
      memberships: {
        Row: {
          accent_color: string | null
          created_at: string
          email: string
          id: number
          investor_id: number | null
          is_active: boolean
          preference: Json
          role: Database["public"]["Enums"]["app_role"]
          tenant_id: number | null
          tenant_role_id: number | null
          updated_at: string
        }
        Insert: {
          accent_color?: string | null
          created_at?: string
          email: string
          id?: number
          investor_id?: number | null
          is_active?: boolean
          preference?: Json
          role: Database["public"]["Enums"]["app_role"]
          tenant_id?: number | null
          tenant_role_id?: number | null
          updated_at?: string
        }
        Update: {
          accent_color?: string | null
          created_at?: string
          email?: string
          id?: number
          investor_id?: number | null
          is_active?: boolean
          preference?: Json
          role?: Database["public"]["Enums"]["app_role"]
          tenant_id?: number | null
          tenant_role_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "memberships_investor_id_fkey"
            columns: ["investor_id"]
            isOneToOne: false
            referencedRelation: "investors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memberships_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memberships_tenant_role_id_fkey"
            columns: ["tenant_role_id"]
            isOneToOne: false
            referencedRelation: "tenant_roles"
            referencedColumns: ["id"]
          },
        ]
      }
      merchant_profiles: {
        Row: {
          created_at: string
          district: string
          id: string
          is_active: boolean
          merchant_name: string
          notes: string | null
          phone_primary: string
          phone_secondary: string | null
          pickup_address: string
          store_name: string | null
          tenant_id: number
          thana: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          district?: string
          id?: string
          is_active?: boolean
          merchant_name: string
          notes?: string | null
          phone_primary: string
          phone_secondary?: string | null
          pickup_address: string
          store_name?: string | null
          tenant_id: number
          thana: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          district?: string
          id?: string
          is_active?: boolean
          merchant_name?: string
          notes?: string | null
          phone_primary?: string
          phone_secondary?: string | null
          pickup_address?: string
          store_name?: string | null
          tenant_id?: number
          thana?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "merchant_profiles_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      module_actions: {
        Row: {
          action: string
          created_at: string
          description: string | null
          id: number
          is_active: boolean
          module_key: string
          scope: string
          tenant_configurable: boolean
          updated_at: string
        }
        Insert: {
          action: string
          created_at?: string
          description?: string | null
          id?: number
          is_active?: boolean
          module_key: string
          scope: string
          tenant_configurable?: boolean
          updated_at?: string
        }
        Update: {
          action?: string
          created_at?: string
          description?: string | null
          id?: number
          is_active?: boolean
          module_key?: string
          scope?: string
          tenant_configurable?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "module_actions_module_key_fkey"
            columns: ["module_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
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
      product_based_costing_backlog_items: {
        Row: {
          barcode: string | null
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string | null
          last_costing_file_id: number | null
          last_costing_item_id: number | null
          name: string
          note: string | null
          open_quantity: number
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number
          product_weight: number | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          barcode?: string | null
          billing_profile_id: number
          created_at?: string
          id?: never
          image_url?: string | null
          last_costing_file_id?: number | null
          last_costing_item_id?: number | null
          name: string
          note?: string | null
          open_quantity: number
          package_weight?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_id: number
          product_weight?: number | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          barcode?: string | null
          billing_profile_id?: number
          created_at?: string
          id?: never
          image_url?: string | null
          last_costing_file_id?: number | null
          last_costing_item_id?: number | null
          name?: string
          note?: string | null
          open_quantity?: number
          package_weight?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_id?: number
          product_weight?: number | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_based_costing_backlog_items_billing_profile_id_fkey"
            columns: ["billing_profile_id"]
            isOneToOne: false
            referencedRelation: "billing_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_backlog_items_last_costing_file_id_fkey"
            columns: ["last_costing_file_id"]
            isOneToOne: false
            referencedRelation: "product_based_costing_files"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_backlog_items_last_costing_item_id_fkey"
            columns: ["last_costing_item_id"]
            isOneToOne: false
            referencedRelation: "product_based_costing_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_backlog_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_backlog_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      product_based_costing_files: {
        Row: {
          billing_profile_id: number | null
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
          billing_profile_id?: number | null
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
          billing_profile_id?: number | null
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
            foreignKeyName: "product_based_costing_files_billing_profile_id_fkey"
            columns: ["billing_profile_id"]
            isOneToOne: false
            referencedRelation: "billing_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_based_costing_files_default_shipment_id_fkey"
            columns: ["default_shipment_id"]
            isOneToOne: false
            referencedRelation: "global_shipments"
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
          confirmed_quantity: number | null
          created_at: string
          id: number
          image_url: string | null
          input_type: string | null
          is_offer_price_manual: boolean
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
          updated_at: string
          vendor_code: string | null
          vendor_id: number | null
          web_link: string | null
        }
        Insert: {
          assigned_shipment_id?: number | null
          barcode?: string | null
          brand?: string | null
          confirmed_quantity?: number | null
          created_at?: string
          id?: number
          image_url?: string | null
          input_type?: string | null
          is_offer_price_manual?: boolean
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
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
          web_link?: string | null
        }
        Update: {
          assigned_shipment_id?: number | null
          barcode?: string | null
          brand?: string | null
          confirmed_quantity?: number | null
          created_at?: string
          id?: number
          image_url?: string | null
          input_type?: string | null
          is_offer_price_manual?: boolean
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
            referencedRelation: "global_shipments"
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
          inserted_by_tenant_id: number | null
          is_available: boolean | null
          languages: string | null
          list_price_amount: number | null
          list_price_currency_id: number | null
          market_code: string | null
          minimum_order_quantity: number | null
          name: string | null
          package_weight: number | null
          parent_tenant_id: number | null
          product_code: string | null
          product_weight: number | null
          reference_cost_amount: number | null
          reference_cost_currency_id: number | null
          source: string | null
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
          inserted_by_tenant_id?: number | null
          is_available?: boolean | null
          languages?: string | null
          list_price_amount?: number | null
          list_price_currency_id?: number | null
          market_code?: string | null
          minimum_order_quantity?: number | null
          name?: string | null
          package_weight?: number | null
          parent_tenant_id?: number | null
          product_code?: string | null
          product_weight?: number | null
          reference_cost_amount?: number | null
          reference_cost_currency_id?: number | null
          source?: string | null
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
          inserted_by_tenant_id?: number | null
          is_available?: boolean | null
          languages?: string | null
          list_price_amount?: number | null
          list_price_currency_id?: number | null
          market_code?: string | null
          minimum_order_quantity?: number | null
          name?: string | null
          package_weight?: number | null
          parent_tenant_id?: number | null
          product_code?: string | null
          product_weight?: number | null
          reference_cost_amount?: number | null
          reference_cost_currency_id?: number | null
          source?: string | null
          updated_at?: string
          vendor_code?: string | null
          vendor_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "products_inserted_by_tenant_id_fkey"
            columns: ["inserted_by_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_list_price_currency_id_fkey"
            columns: ["list_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
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
            foreignKeyName: "products_reference_cost_currency_id_fkey"
            columns: ["reference_cost_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
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
      recipient_profiles: {
        Row: {
          address: string
          addresses: Json
          created_at: string
          district: string | null
          id: number
          name: string
          parent_tenant_id: number | null
          phone: string
          secondary_phone: string | null
          tenant_id: number
          thana: string | null
          updated_at: string
        }
        Insert: {
          address: string
          addresses?: Json
          created_at?: string
          district?: string | null
          id?: number
          name: string
          parent_tenant_id?: number | null
          phone: string
          secondary_phone?: string | null
          tenant_id: number
          thana?: string | null
          updated_at?: string
        }
        Update: {
          address?: string
          addresses?: Json
          created_at?: string
          district?: string | null
          id?: number
          name?: string
          parent_tenant_id?: number | null
          phone?: string
          secondary_phone?: string | null
          tenant_id?: number
          thana?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "recipient_profiles_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipient_profiles_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      sales_invoice_counters: {
        Row: {
          created_at: string
          date_key: string
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          last_value: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          date_key: string
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          last_value?: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          date_key?: string
          invoice_type?: Database["public"]["Enums"]["global_invoice_type"]
          last_value?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "sales_invoice_counters_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      sales_invoice_items: {
        Row: {
          assigned_child_tenant_id: number | null
          barcode_snapshot: string | null
          created_at: string
          global_stock_id: number
          id: number
          invoice_id: number
          line_discount_amount: number
          line_total_amount: number
          name_snapshot: string
          parent_tenant_id: number
          product_code_snapshot: string | null
          product_id: number | null
          quantity: number
          return_quantity: number
          sell_price_amount: number
          shipment_item_id: number | null
          unit_cost_price: number
          updated_at: string
        }
        Insert: {
          assigned_child_tenant_id?: number | null
          barcode_snapshot?: string | null
          created_at?: string
          global_stock_id: number
          id?: number
          invoice_id: number
          line_discount_amount?: number
          line_total_amount?: number
          name_snapshot: string
          parent_tenant_id: number
          product_code_snapshot?: string | null
          product_id?: number | null
          quantity: number
          return_quantity?: number
          sell_price_amount?: number
          shipment_item_id?: number | null
          unit_cost_price?: number
          updated_at?: string
        }
        Update: {
          assigned_child_tenant_id?: number | null
          barcode_snapshot?: string | null
          created_at?: string
          global_stock_id?: number
          id?: number
          invoice_id?: number
          line_discount_amount?: number
          line_total_amount?: number
          name_snapshot?: string
          parent_tenant_id?: number
          product_code_snapshot?: string | null
          product_id?: number | null
          quantity?: number
          return_quantity?: number
          sell_price_amount?: number
          shipment_item_id?: number | null
          unit_cost_price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_invoice_items_assigned_child_tenant_id_fkey"
            columns: ["assigned_child_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_global_stock_id_fkey"
            columns: ["global_stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
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
            foreignKeyName: "global_invoice_items_shipment_item_id_fkey"
            columns: ["shipment_item_id"]
            isOneToOne: false
            referencedRelation: "global_shipment_items"
            referencedColumns: ["id"]
          },
        ]
      }
      sales_invoices: {
        Row: {
          billing_profile_id: number | null
          collection_source: Database["public"]["Enums"]["collection_source_type"]
          created_at: string
          created_by: string | null
          discount_amount: number
          due_amount: number
          due_date: string | null
          fulfillment_status: Database["public"]["Enums"]["global_fulfillment_status"]
          id: number
          invoice_date: string
          invoice_no: string
          invoice_status: Database["public"]["Enums"]["global_invoice_status"]
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          issued_by_tenant_id: number
          note: string | null
          paid_amount: number
          parent_tenant_id: number
          payment_status: string
          print_charge: number
          recipient_address: string | null
          recipient_name: string | null
          recipient_phone: string | null
          recipient_profile_id: number | null
          retail_billing_mode:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount: number
          shipping_charge: number
          subtotal_amount: number
          total_amount: number
          updated_at: string
          wrapping_charge: number
        }
        Insert: {
          billing_profile_id?: number | null
          collection_source: Database["public"]["Enums"]["collection_source_type"]
          created_at?: string
          created_by?: string | null
          discount_amount?: number
          due_amount?: number
          due_date?: string | null
          fulfillment_status?: Database["public"]["Enums"]["global_fulfillment_status"]
          id?: number
          invoice_date?: string
          invoice_no: string
          invoice_status?: Database["public"]["Enums"]["global_invoice_status"]
          invoice_type?: Database["public"]["Enums"]["global_invoice_type"]
          issued_by_tenant_id: number
          note?: string | null
          paid_amount?: number
          parent_tenant_id: number
          payment_status?: string
          print_charge?: number
          recipient_address?: string | null
          recipient_name?: string | null
          recipient_phone?: string | null
          recipient_profile_id?: number | null
          retail_billing_mode?:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount?: number
          shipping_charge?: number
          subtotal_amount?: number
          total_amount?: number
          updated_at?: string
          wrapping_charge?: number
        }
        Update: {
          billing_profile_id?: number | null
          collection_source?: Database["public"]["Enums"]["collection_source_type"]
          created_at?: string
          created_by?: string | null
          discount_amount?: number
          due_amount?: number
          due_date?: string | null
          fulfillment_status?: Database["public"]["Enums"]["global_fulfillment_status"]
          id?: number
          invoice_date?: string
          invoice_no?: string
          invoice_status?: Database["public"]["Enums"]["global_invoice_status"]
          invoice_type?: Database["public"]["Enums"]["global_invoice_type"]
          issued_by_tenant_id?: number
          note?: string | null
          paid_amount?: number
          parent_tenant_id?: number
          payment_status?: string
          print_charge?: number
          recipient_address?: string | null
          recipient_name?: string | null
          recipient_phone?: string | null
          recipient_profile_id?: number | null
          retail_billing_mode?:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount?: number
          shipping_charge?: number
          subtotal_amount?: number
          total_amount?: number
          updated_at?: string
          wrapping_charge?: number
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
            foreignKeyName: "global_invoices_issued_by_tenant_id_fkey"
            columns: ["issued_by_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
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
            foreignKeyName: "global_invoices_recipient_profile_id_fkey"
            columns: ["recipient_profile_id"]
            isOneToOne: false
            referencedRelation: "recipient_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      sales_return_items: {
        Row: {
          created_at: string
          global_stock_id: number
          id: number
          invoice_id: number
          invoice_item_id: number
          note: string | null
          parent_tenant_id: number
          quantity: number
          return_charge_amount: number
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
          return_charge_amount?: number
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
          return_charge_amount?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "global_return_items_global_stock_id_fkey"
            columns: ["global_stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_return_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_return_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
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
            foreignKeyName: "global_return_items_invoice_item_id_fkey"
            columns: ["invoice_item_id"]
            isOneToOne: false
            referencedRelation: "sales_invoice_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_return_items_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
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
          global_shipment_id: number | null
          id: number
          invested_amount: number
          investor_id: number
          profit_status: string
          shipment_id: number | null
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
          global_shipment_id?: number | null
          id?: number
          invested_amount?: number
          investor_id: number
          profit_status?: string
          shipment_id?: number | null
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
          global_shipment_id?: number | null
          id?: number
          invested_amount?: number
          investor_id?: number
          profit_status?: string
          shipment_id?: number | null
          status?: Database["public"]["Enums"]["shipment_investment_status"]
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipment_investments_global_shipment_id_fkey"
            columns: ["global_shipment_id"]
            isOneToOne: false
            referencedRelation: "global_shipments"
            referencedColumns: ["id"]
          },
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
      shipment_progress_flow_stages: {
        Row: {
          created_at: string
          flow_id: number
          id: number
          sort_order: number
          tag_id: number
        }
        Insert: {
          created_at?: string
          flow_id: number
          id?: number
          sort_order?: number
          tag_id: number
        }
        Update: {
          created_at?: string
          flow_id?: number
          id?: number
          sort_order?: number
          tag_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "shipment_progress_flow_stages_flow_id_fkey"
            columns: ["flow_id"]
            isOneToOne: false
            referencedRelation: "shipment_progress_flows"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_progress_flow_stages_tag_id_fkey"
            columns: ["tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
        ]
      }
      shipment_progress_flows: {
        Row: {
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          name: string
          slug: string
          tenant_id: number
        }
        Insert: {
          created_at?: string
          id?: number
          is_active?: boolean
          is_default?: boolean
          name: string
          slug: string
          tenant_id: number
        }
        Update: {
          created_at?: string
          id?: number
          is_active?: boolean
          is_default?: boolean
          name?: string
          slug?: string
          tenant_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "shipment_progress_flows_tenant_id_fkey"
            columns: ["tenant_id"]
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
      shop_cart_items: {
        Row: {
          cart_id: number
          created_at: string
          customer_sell_price_amount: number | null
          customer_sell_price_currency_id: number | null
          global_stock_allocation_id: number | null
          global_stock_id: number | null
          id: number
          image_url: string | null
          minimum_quantity: number
          name: string
          product_id: number
          quantity: number
          unit_list_price_amount: number | null
          unit_list_price_currency_id: number | null
          unit_minimum_sell_price_amount: number | null
          unit_minimum_sell_price_currency_id: number | null
          unit_sell_price_amount: number | null
          unit_sell_price_currency_id: number | null
          updated_at: string
        }
        Insert: {
          cart_id: number
          created_at?: string
          customer_sell_price_amount?: number | null
          customer_sell_price_currency_id?: number | null
          global_stock_allocation_id?: number | null
          global_stock_id?: number | null
          id?: never
          image_url?: string | null
          minimum_quantity?: number
          name: string
          product_id: number
          quantity: number
          unit_list_price_amount?: number | null
          unit_list_price_currency_id?: number | null
          unit_minimum_sell_price_amount?: number | null
          unit_minimum_sell_price_currency_id?: number | null
          unit_sell_price_amount?: number | null
          unit_sell_price_currency_id?: number | null
          updated_at?: string
        }
        Update: {
          cart_id?: number
          created_at?: string
          customer_sell_price_amount?: number | null
          customer_sell_price_currency_id?: number | null
          global_stock_allocation_id?: number | null
          global_stock_id?: number | null
          id?: never
          image_url?: string | null
          minimum_quantity?: number
          name?: string
          product_id?: number
          quantity?: number
          unit_list_price_amount?: number | null
          unit_list_price_currency_id?: number | null
          unit_minimum_sell_price_amount?: number | null
          unit_minimum_sell_price_currency_id?: number | null
          unit_sell_price_amount?: number | null
          unit_sell_price_currency_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_cart_items_cart_id_fkey"
            columns: ["cart_id"]
            isOneToOne: false
            referencedRelation: "shop_carts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_cart_items_customer_sell_price_currency_id_fkey"
            columns: ["customer_sell_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_cart_items_global_stock_id_fkey"
            columns: ["global_stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_cart_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_cart_items_unit_list_price_currency_id_fkey"
            columns: ["unit_list_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_cart_items_unit_minimum_sell_price_currency_id_fkey"
            columns: ["unit_minimum_sell_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_cart_items_unit_sell_price_currency_id_fkey"
            columns: ["unit_sell_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_carts: {
        Row: {
          can_see_buy_price_snapshot: boolean
          can_see_sell_price_snapshot: boolean
          cod_charge_amount: number
          created_at: string
          customer_group_id: number
          deduct_charges_from_margin: boolean
          deduct_cod_from_margin: boolean
          deduct_delivery_from_margin: boolean
          deduct_packing_from_margin: boolean
          deduct_print_from_margin: boolean
          delivery_charge_amount: number
          delivery_instructions: string | null
          discount_amount: number
          id: number
          is_prepaid: boolean
          packing_charge_amount: number
          print_charge_amount: number
          shop_id: number
          status: Database["public"]["Enums"]["shop_cart_status"]
          tenant_id: number
          updated_at: string
        }
        Insert: {
          can_see_buy_price_snapshot?: boolean
          can_see_sell_price_snapshot?: boolean
          cod_charge_amount?: number
          created_at?: string
          customer_group_id: number
          deduct_charges_from_margin?: boolean
          deduct_cod_from_margin?: boolean
          deduct_delivery_from_margin?: boolean
          deduct_packing_from_margin?: boolean
          deduct_print_from_margin?: boolean
          delivery_charge_amount?: number
          delivery_instructions?: string | null
          discount_amount?: number
          id?: never
          is_prepaid?: boolean
          packing_charge_amount?: number
          print_charge_amount?: number
          shop_id: number
          status?: Database["public"]["Enums"]["shop_cart_status"]
          tenant_id: number
          updated_at?: string
        }
        Update: {
          can_see_buy_price_snapshot?: boolean
          can_see_sell_price_snapshot?: boolean
          cod_charge_amount?: number
          created_at?: string
          customer_group_id?: number
          deduct_charges_from_margin?: boolean
          deduct_cod_from_margin?: boolean
          deduct_delivery_from_margin?: boolean
          deduct_packing_from_margin?: boolean
          deduct_print_from_margin?: boolean
          delivery_charge_amount?: number
          delivery_instructions?: string | null
          discount_amount?: number
          id?: never
          is_prepaid?: boolean
          packing_charge_amount?: number
          print_charge_amount?: number
          shop_id?: number
          status?: Database["public"]["Enums"]["shop_cart_status"]
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_carts_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_carts_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_carts_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_categories: {
        Row: {
          created_at: string
          description: string | null
          icon: string | null
          id: number
          is_active: boolean
          name: string
          slug: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: never
          is_active?: boolean
          name: string
          slug: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: never
          is_active?: boolean
          name?: string
          slug?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_categories_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_customer_group_access: {
        Row: {
          can_add_to_cart: boolean | null
          can_browse: boolean | null
          can_negotiate: boolean | null
          can_place_order: boolean | null
          can_see_buy_price: boolean | null
          can_see_resell_minimum_price: boolean | null
          can_see_sell_price: boolean | null
          can_set_dropship_price: boolean | null
          can_view_quantity: boolean | null
          created_at: string
          credit_limit_amount: number | null
          credit_limit_currency_id: number | null
          customer_group_id: number
          id: number
          price_tier_code: string | null
          shop_id: number
          status: boolean
          updated_at: string
        }
        Insert: {
          can_add_to_cart?: boolean | null
          can_browse?: boolean | null
          can_negotiate?: boolean | null
          can_place_order?: boolean | null
          can_see_buy_price?: boolean | null
          can_see_resell_minimum_price?: boolean | null
          can_see_sell_price?: boolean | null
          can_set_dropship_price?: boolean | null
          can_view_quantity?: boolean | null
          created_at?: string
          credit_limit_amount?: number | null
          credit_limit_currency_id?: number | null
          customer_group_id: number
          id?: never
          price_tier_code?: string | null
          shop_id: number
          status?: boolean
          updated_at?: string
        }
        Update: {
          can_add_to_cart?: boolean | null
          can_browse?: boolean | null
          can_negotiate?: boolean | null
          can_place_order?: boolean | null
          can_see_buy_price?: boolean | null
          can_see_resell_minimum_price?: boolean | null
          can_see_sell_price?: boolean | null
          can_set_dropship_price?: boolean | null
          can_view_quantity?: boolean | null
          created_at?: string
          credit_limit_amount?: number | null
          credit_limit_currency_id?: number | null
          customer_group_id?: number
          id?: never
          price_tier_code?: string | null
          shop_id?: number
          status?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_customer_group_access_credit_limit_currency_id_fkey"
            columns: ["credit_limit_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_customer_group_access_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_customer_group_access_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_order_items: {
        Row: {
          confirmed_quantity: number | null
          cost_price_amount: number | null
          cost_price_currency_id: number | null
          created_at: string
          customer_counter_at: string | null
          customer_decision_at: string | null
          customer_decision_status: string | null
          customer_offer_amount: number | null
          customer_offer_currency_id: number | null
          customer_sell_price_amount: number | null
          customer_sell_price_currency_id: number | null
          final_offer_at: string | null
          final_price_amount: number | null
          final_price_currency_id: number | null
          global_stock_allocation_id: number | null
          global_stock_id: number | null
          id: number
          image_url: string | null
          is_final_offer_manual: boolean
          is_first_offer_manual: boolean
          name: string
          negotiation_status: string | null
          order_id: number
          procurement_pulled: boolean
          product_id: number
          quantity: number
          returned_quantity: number
          staff_offer_amount: number | null
          staff_offer_at: string | null
          staff_offer_currency_id: number | null
          unit_list_price_amount: number | null
          unit_list_price_currency_id: number | null
          unit_minimum_sell_price_amount: number | null
          unit_minimum_sell_price_currency_id: number | null
          unit_sell_price_amount: number | null
          unit_sell_price_currency_id: number | null
          updated_at: string
          weight_kg: number | null
        }
        Insert: {
          confirmed_quantity?: number | null
          cost_price_amount?: number | null
          cost_price_currency_id?: number | null
          created_at?: string
          customer_counter_at?: string | null
          customer_decision_at?: string | null
          customer_decision_status?: string | null
          customer_offer_amount?: number | null
          customer_offer_currency_id?: number | null
          customer_sell_price_amount?: number | null
          customer_sell_price_currency_id?: number | null
          final_offer_at?: string | null
          final_price_amount?: number | null
          final_price_currency_id?: number | null
          global_stock_allocation_id?: number | null
          global_stock_id?: number | null
          id?: never
          image_url?: string | null
          is_final_offer_manual?: boolean
          is_first_offer_manual?: boolean
          name: string
          negotiation_status?: string | null
          order_id: number
          procurement_pulled?: boolean
          product_id: number
          quantity: number
          returned_quantity?: number
          staff_offer_amount?: number | null
          staff_offer_at?: string | null
          staff_offer_currency_id?: number | null
          unit_list_price_amount?: number | null
          unit_list_price_currency_id?: number | null
          unit_minimum_sell_price_amount?: number | null
          unit_minimum_sell_price_currency_id?: number | null
          unit_sell_price_amount?: number | null
          unit_sell_price_currency_id?: number | null
          updated_at?: string
          weight_kg?: number | null
        }
        Update: {
          confirmed_quantity?: number | null
          cost_price_amount?: number | null
          cost_price_currency_id?: number | null
          created_at?: string
          customer_counter_at?: string | null
          customer_decision_at?: string | null
          customer_decision_status?: string | null
          customer_offer_amount?: number | null
          customer_offer_currency_id?: number | null
          customer_sell_price_amount?: number | null
          customer_sell_price_currency_id?: number | null
          final_offer_at?: string | null
          final_price_amount?: number | null
          final_price_currency_id?: number | null
          global_stock_allocation_id?: number | null
          global_stock_id?: number | null
          id?: never
          image_url?: string | null
          is_final_offer_manual?: boolean
          is_first_offer_manual?: boolean
          name?: string
          negotiation_status?: string | null
          order_id?: number
          procurement_pulled?: boolean
          product_id?: number
          quantity?: number
          returned_quantity?: number
          staff_offer_amount?: number | null
          staff_offer_at?: string | null
          staff_offer_currency_id?: number | null
          unit_list_price_amount?: number | null
          unit_list_price_currency_id?: number | null
          unit_minimum_sell_price_amount?: number | null
          unit_minimum_sell_price_currency_id?: number | null
          unit_sell_price_amount?: number | null
          unit_sell_price_currency_id?: number | null
          updated_at?: string
          weight_kg?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "shop_order_items_cost_price_currency_id_fkey"
            columns: ["cost_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_customer_offer_currency_id_fkey"
            columns: ["customer_offer_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_customer_sell_price_currency_id_fkey"
            columns: ["customer_sell_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_final_price_currency_id_fkey"
            columns: ["final_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_global_stock_id_fkey"
            columns: ["global_stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "shop_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_staff_offer_currency_id_fkey"
            columns: ["staff_offer_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_unit_list_price_currency_id_fkey"
            columns: ["unit_list_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_unit_minimum_sell_price_currency_id_fkey"
            columns: ["unit_minimum_sell_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_order_items_unit_sell_price_currency_id_fkey"
            columns: ["unit_sell_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_orders: {
        Row: {
          allow_open_box: boolean | null
          billing_profile_id: number | null
          cargo_rate: number | null
          cart_id: number | null
          cod_charge_amount: number
          cod_collect_amount: number | null
          collection_source:
            | Database["public"]["Enums"]["collection_source_type"]
            | null
          conversion_rate: number | null
          courier_awb_number: string | null
          courier_bank_trx_id: string | null
          courier_consignment_id: string | null
          courier_cost_amount: number | null
          courier_name: string | null
          courier_order_ref: string | null
          courier_remittance_ref: string | null
          courier_service_id: string | null
          courier_tracking_number: string | null
          created_at: string
          created_by_email: string
          customer_group_id: number
          deduct_charges_from_margin: boolean
          deduct_cod_from_margin: boolean
          deduct_delivery_from_margin: boolean
          deduct_packing_from_margin: boolean
          deduct_print_from_margin: boolean
          deduct_return_charge_from_middle_man: boolean | null
          default_payout_account_info: string | null
          default_payout_account_type: string | null
          default_pickup_address: string | null
          default_pickup_phone: string | null
          default_sender_name: string | null
          delivered_at: string | null
          delivery_charge_amount: number
          delivery_instruction_notes: string | null
          delivery_instructions: string | null
          delivery_zone: string | null
          discount_amount: number
          driver_notes: string | null
          final_offer_rate: number | null
          first_offer_rate: number | null
          fulfilled_at: string | null
          global_invoice_id: number | null
          id: number
          is_negotiable_snapshot: boolean
          is_prepaid_snapshot: boolean
          item_category: string | null
          middle_man_reference: string | null
          name: string
          negotiate_round: number
          order_mode_snapshot: Database["public"]["Enums"]["shop_order_mode_enum"]
          order_no: string
          package_weight_band: string | null
          package_weight_kg: number | null
          packing_charge_amount: number
          parcel_description: string | null
          payout_account_info: string | null
          payout_account_type: string | null
          payout_settlement_status: string | null
          pickup_address: string | null
          pickup_phone: string | null
          placed_at: string | null
          print_charge_amount: number
          profit_basis: string | null
          profit_rate: number | null
          recipient_name: string | null
          recipient_phone: string | null
          recipient_phone_secondary: string | null
          recipient_profile_id: number | null
          replacement_of_order_id: number | null
          return_charge_amount: number | null
          return_override_reason: string | null
          return_ref: string | null
          return_sub_state: string | null
          returned_at: string | null
          sender_name: string | null
          shipping_address: string | null
          shipping_district: string | null
          shipping_thana: string | null
          shop_id: number
          shop_type_snapshot: Database["public"]["Enums"]["shop_type_enum"]
          status: Database["public"]["Enums"]["shop_order_status"]
          tenant_id: number
          tracking_url: string | null
          updated_at: string
        }
        Insert: {
          allow_open_box?: boolean | null
          billing_profile_id?: number | null
          cargo_rate?: number | null
          cart_id?: number | null
          cod_charge_amount?: number
          cod_collect_amount?: number | null
          collection_source?:
            | Database["public"]["Enums"]["collection_source_type"]
            | null
          conversion_rate?: number | null
          courier_awb_number?: string | null
          courier_bank_trx_id?: string | null
          courier_consignment_id?: string | null
          courier_cost_amount?: number | null
          courier_name?: string | null
          courier_order_ref?: string | null
          courier_remittance_ref?: string | null
          courier_service_id?: string | null
          courier_tracking_number?: string | null
          created_at?: string
          created_by_email: string
          customer_group_id: number
          deduct_charges_from_margin?: boolean
          deduct_cod_from_margin?: boolean
          deduct_delivery_from_margin?: boolean
          deduct_packing_from_margin?: boolean
          deduct_print_from_margin?: boolean
          deduct_return_charge_from_middle_man?: boolean | null
          default_payout_account_info?: string | null
          default_payout_account_type?: string | null
          default_pickup_address?: string | null
          default_pickup_phone?: string | null
          default_sender_name?: string | null
          delivered_at?: string | null
          delivery_charge_amount?: number
          delivery_instruction_notes?: string | null
          delivery_instructions?: string | null
          delivery_zone?: string | null
          discount_amount?: number
          driver_notes?: string | null
          final_offer_rate?: number | null
          first_offer_rate?: number | null
          fulfilled_at?: string | null
          global_invoice_id?: number | null
          id?: never
          is_negotiable_snapshot?: boolean
          is_prepaid_snapshot?: boolean
          item_category?: string | null
          middle_man_reference?: string | null
          name: string
          negotiate_round?: number
          order_mode_snapshot: Database["public"]["Enums"]["shop_order_mode_enum"]
          order_no: string
          package_weight_band?: string | null
          package_weight_kg?: number | null
          packing_charge_amount?: number
          parcel_description?: string | null
          payout_account_info?: string | null
          payout_account_type?: string | null
          payout_settlement_status?: string | null
          pickup_address?: string | null
          pickup_phone?: string | null
          placed_at?: string | null
          print_charge_amount?: number
          profit_basis?: string | null
          profit_rate?: number | null
          recipient_name?: string | null
          recipient_phone?: string | null
          recipient_phone_secondary?: string | null
          recipient_profile_id?: number | null
          replacement_of_order_id?: number | null
          return_charge_amount?: number | null
          return_override_reason?: string | null
          return_ref?: string | null
          return_sub_state?: string | null
          returned_at?: string | null
          sender_name?: string | null
          shipping_address?: string | null
          shipping_district?: string | null
          shipping_thana?: string | null
          shop_id: number
          shop_type_snapshot: Database["public"]["Enums"]["shop_type_enum"]
          status?: Database["public"]["Enums"]["shop_order_status"]
          tenant_id: number
          tracking_url?: string | null
          updated_at?: string
        }
        Update: {
          allow_open_box?: boolean | null
          billing_profile_id?: number | null
          cargo_rate?: number | null
          cart_id?: number | null
          cod_charge_amount?: number
          cod_collect_amount?: number | null
          collection_source?:
            | Database["public"]["Enums"]["collection_source_type"]
            | null
          conversion_rate?: number | null
          courier_awb_number?: string | null
          courier_bank_trx_id?: string | null
          courier_consignment_id?: string | null
          courier_cost_amount?: number | null
          courier_name?: string | null
          courier_order_ref?: string | null
          courier_remittance_ref?: string | null
          courier_service_id?: string | null
          courier_tracking_number?: string | null
          created_at?: string
          created_by_email?: string
          customer_group_id?: number
          deduct_charges_from_margin?: boolean
          deduct_cod_from_margin?: boolean
          deduct_delivery_from_margin?: boolean
          deduct_packing_from_margin?: boolean
          deduct_print_from_margin?: boolean
          deduct_return_charge_from_middle_man?: boolean | null
          default_payout_account_info?: string | null
          default_payout_account_type?: string | null
          default_pickup_address?: string | null
          default_pickup_phone?: string | null
          default_sender_name?: string | null
          delivered_at?: string | null
          delivery_charge_amount?: number
          delivery_instruction_notes?: string | null
          delivery_instructions?: string | null
          delivery_zone?: string | null
          discount_amount?: number
          driver_notes?: string | null
          final_offer_rate?: number | null
          first_offer_rate?: number | null
          fulfilled_at?: string | null
          global_invoice_id?: number | null
          id?: never
          is_negotiable_snapshot?: boolean
          is_prepaid_snapshot?: boolean
          item_category?: string | null
          middle_man_reference?: string | null
          name?: string
          negotiate_round?: number
          order_mode_snapshot?: Database["public"]["Enums"]["shop_order_mode_enum"]
          order_no?: string
          package_weight_band?: string | null
          package_weight_kg?: number | null
          packing_charge_amount?: number
          parcel_description?: string | null
          payout_account_info?: string | null
          payout_account_type?: string | null
          payout_settlement_status?: string | null
          pickup_address?: string | null
          pickup_phone?: string | null
          placed_at?: string | null
          print_charge_amount?: number
          profit_basis?: string | null
          profit_rate?: number | null
          recipient_name?: string | null
          recipient_phone?: string | null
          recipient_phone_secondary?: string | null
          recipient_profile_id?: number | null
          replacement_of_order_id?: number | null
          return_charge_amount?: number | null
          return_override_reason?: string | null
          return_ref?: string | null
          return_sub_state?: string | null
          returned_at?: string | null
          sender_name?: string | null
          shipping_address?: string | null
          shipping_district?: string | null
          shipping_thana?: string | null
          shop_id?: number
          shop_type_snapshot?: Database["public"]["Enums"]["shop_type_enum"]
          status?: Database["public"]["Enums"]["shop_order_status"]
          tenant_id?: number
          tracking_url?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_shop_orders_courier_service"
            columns: ["courier_service_id"]
            isOneToOne: false
            referencedRelation: "courier_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_billing_profile_id_fkey"
            columns: ["billing_profile_id"]
            isOneToOne: false
            referencedRelation: "billing_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_cart_id_fkey"
            columns: ["cart_id"]
            isOneToOne: false
            referencedRelation: "shop_carts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_customer_group_id_fkey"
            columns: ["customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_global_invoice_id_fkey"
            columns: ["global_invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_global_invoice_id_fkey"
            columns: ["global_invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_recipient_profile_id_fkey"
            columns: ["recipient_profile_id"]
            isOneToOne: false
            referencedRelation: "recipient_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_replacement_of_order_id_fkey"
            columns: ["replacement_of_order_id"]
            isOneToOne: false
            referencedRelation: "shop_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_orders_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_pricing_rules: {
        Row: {
          created_at: string
          default_add_quantity: number
          default_show_quantity: boolean
          dropship_markup_percentage: number
          id: number
          is_auto_publish: boolean
          markup_percentage: number
          shop_id: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          default_add_quantity?: number
          default_show_quantity?: boolean
          dropship_markup_percentage?: number
          id?: never
          is_auto_publish?: boolean
          markup_percentage?: number
          shop_id: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          default_add_quantity?: number
          default_show_quantity?: boolean
          dropship_markup_percentage?: number
          id?: never
          is_auto_publish?: boolean
          markup_percentage?: number
          shop_id?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_pricing_rules_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: true
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_pricing_rules_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_product_listings: {
        Row: {
          created_at: string
          display_quantity_override: number | null
          global_stock_allocation_id: number | null
          global_stock_id: number
          id: number
          is_active: boolean
          is_price_locked: boolean
          is_quantity_locked: boolean
          minimum_sell_price_amount: number | null
          minimum_sell_price_currency_id: number | null
          product_id: number
          quantity_override_type: string
          sell_price_amount: number
          sell_price_currency_id: number
          shop_id: number
          show_quantity: boolean | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_quantity_override?: number | null
          global_stock_allocation_id?: number | null
          global_stock_id: number
          id?: never
          is_active?: boolean
          is_price_locked?: boolean
          is_quantity_locked?: boolean
          minimum_sell_price_amount?: number | null
          minimum_sell_price_currency_id?: number | null
          product_id: number
          quantity_override_type?: string
          sell_price_amount: number
          sell_price_currency_id: number
          shop_id: number
          show_quantity?: boolean | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_quantity_override?: number | null
          global_stock_allocation_id?: number | null
          global_stock_id?: number
          id?: never
          is_active?: boolean
          is_price_locked?: boolean
          is_quantity_locked?: boolean
          minimum_sell_price_amount?: number | null
          minimum_sell_price_currency_id?: number | null
          product_id?: number
          quantity_override_type?: string
          sell_price_amount?: number
          sell_price_currency_id?: number
          shop_id?: number
          show_quantity?: boolean | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_product_listings_global_stock_id_fkey"
            columns: ["global_stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_product_listings_minimum_sell_price_currency_id_fkey"
            columns: ["minimum_sell_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_product_listings_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_product_listings_sell_price_currency_id_fkey"
            columns: ["sell_price_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_product_listings_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_product_listings_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_product_offers: {
        Row: {
          condition_bucket: string
          created_at: string
          id: number
          is_active: boolean
          price: number
          product_id: number
          shop_id: number
          updated_at: string
        }
        Insert: {
          condition_bucket?: string
          created_at?: string
          id?: never
          is_active?: boolean
          price: number
          product_id: number
          shop_id: number
          updated_at?: string
        }
        Update: {
          condition_bucket?: string
          created_at?: string
          id?: never
          is_active?: boolean
          price?: number
          product_id?: number
          shop_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_product_offers_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_product_offers_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_stock_reservations: {
        Row: {
          cart_item_id: number
          created_at: string
          global_stock_allocation_id: number | null
          global_stock_id: number | null
          quantity: number
          updated_at: string
        }
        Insert: {
          cart_item_id: number
          created_at?: string
          global_stock_allocation_id?: number | null
          global_stock_id?: number | null
          quantity: number
          updated_at?: string
        }
        Update: {
          cart_item_id?: number
          created_at?: string
          global_stock_allocation_id?: number | null
          global_stock_id?: number | null
          quantity?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_stock_reservations_cart_item_id_fkey"
            columns: ["cart_item_id"]
            isOneToOne: true
            referencedRelation: "shop_cart_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_stock_reservations_global_stock_id_fkey"
            columns: ["global_stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
        ]
      }
      shops: {
        Row: {
          allow_delivery: boolean
          buy_currency_id: number
          category_ids: number[] | null
          created_at: string
          deduct_charges_from_margin: boolean
          deduct_cod_from_margin: boolean
          deduct_delivery_from_margin: boolean
          deduct_packing_from_margin: boolean
          deduct_print_from_margin: boolean
          deduct_return_charge_from_middle_man: boolean | null
          default_currency_id: number | null
          default_packing_charge_amount: number
          default_print_charge_amount: number
          deleted_at: string | null
          deleted_by: string | null
          description: string | null
          global_stock_type_id: number | null
          id: number
          is_active: boolean
          is_negotiable: boolean
          markup_percentage: number
          name: string
          order_mode: Database["public"]["Enums"]["shop_order_mode_enum"]
          pricing_method: string
          quantity_display_mode: string
          sell_currency_id: number
          shop_type: Database["public"]["Enums"]["shop_type_enum"]
          show_stock_quantity: boolean
          slug: string
          tenant_id: number
          updated_at: string
          vendor_code: string | null
          vendor_filters: Json | null
        }
        Insert: {
          allow_delivery?: boolean
          buy_currency_id: number
          category_ids?: number[] | null
          created_at?: string
          deduct_charges_from_margin?: boolean
          deduct_cod_from_margin?: boolean
          deduct_delivery_from_margin?: boolean
          deduct_packing_from_margin?: boolean
          deduct_print_from_margin?: boolean
          deduct_return_charge_from_middle_man?: boolean | null
          default_currency_id?: number | null
          default_packing_charge_amount?: number
          default_print_charge_amount?: number
          deleted_at?: string | null
          deleted_by?: string | null
          description?: string | null
          global_stock_type_id?: number | null
          id?: never
          is_active?: boolean
          is_negotiable?: boolean
          markup_percentage?: number
          name: string
          order_mode: Database["public"]["Enums"]["shop_order_mode_enum"]
          pricing_method: string
          quantity_display_mode: string
          sell_currency_id: number
          shop_type: Database["public"]["Enums"]["shop_type_enum"]
          show_stock_quantity?: boolean
          slug: string
          tenant_id: number
          updated_at?: string
          vendor_code?: string | null
          vendor_filters?: Json | null
        }
        Update: {
          allow_delivery?: boolean
          buy_currency_id?: number
          category_ids?: number[] | null
          created_at?: string
          deduct_charges_from_margin?: boolean
          deduct_cod_from_margin?: boolean
          deduct_delivery_from_margin?: boolean
          deduct_packing_from_margin?: boolean
          deduct_print_from_margin?: boolean
          deduct_return_charge_from_middle_man?: boolean | null
          default_currency_id?: number | null
          default_packing_charge_amount?: number
          default_print_charge_amount?: number
          deleted_at?: string | null
          deleted_by?: string | null
          description?: string | null
          global_stock_type_id?: number | null
          id?: never
          is_active?: boolean
          is_negotiable?: boolean
          markup_percentage?: number
          name?: string
          order_mode?: Database["public"]["Enums"]["shop_order_mode_enum"]
          pricing_method?: string
          quantity_display_mode?: string
          sell_currency_id?: number
          shop_type?: Database["public"]["Enums"]["shop_type_enum"]
          show_stock_quantity?: boolean
          slug?: string
          tenant_id?: number
          updated_at?: string
          vendor_code?: string | null
          vendor_filters?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "shops_buy_currency_id_fkey"
            columns: ["buy_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shops_default_currency_id_fkey"
            columns: ["default_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shops_sell_currency_id_fkey"
            columns: ["sell_currency_id"]
            isOneToOne: false
            referencedRelation: "global_currencies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shops_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_locations: {
        Row: {
          code: string
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          is_pickable: boolean
          kind: Database["public"]["Enums"]["stock_location_kind"]
          name: string
          parent_location_id: number | null
          parent_tenant_id: number
          sort_order: number
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_default?: boolean
          is_pickable?: boolean
          kind?: Database["public"]["Enums"]["stock_location_kind"]
          name: string
          parent_location_id?: number | null
          parent_tenant_id: number
          sort_order?: number
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_default?: boolean
          is_pickable?: boolean
          kind?: Database["public"]["Enums"]["stock_location_kind"]
          name?: string
          parent_location_id?: number | null
          parent_tenant_id?: number
          sort_order?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_locations_parent_location_id_fkey"
            columns: ["parent_location_id"]
            isOneToOne: false
            referencedRelation: "stock_locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_locations_parent_tenant_id_fkey"
            columns: ["parent_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_movement_lines: {
        Row: {
          created_at: string
          from_availability:
            | Database["public"]["Enums"]["stock_availability"]
            | null
          from_grade_tag_id: number | null
          from_location_id: number | null
          id: number
          movement_id: number
          quantity: number
          stock_id: number | null
          to_availability:
            | Database["public"]["Enums"]["stock_availability"]
            | null
          to_grade_tag_id: number | null
          to_location_id: number | null
        }
        Insert: {
          created_at?: string
          from_availability?:
            | Database["public"]["Enums"]["stock_availability"]
            | null
          from_grade_tag_id?: number | null
          from_location_id?: number | null
          id?: number
          movement_id: number
          quantity: number
          stock_id?: number | null
          to_availability?:
            | Database["public"]["Enums"]["stock_availability"]
            | null
          to_grade_tag_id?: number | null
          to_location_id?: number | null
        }
        Update: {
          created_at?: string
          from_availability?:
            | Database["public"]["Enums"]["stock_availability"]
            | null
          from_grade_tag_id?: number | null
          from_location_id?: number | null
          id?: number
          movement_id?: number
          quantity?: number
          stock_id?: number | null
          to_availability?:
            | Database["public"]["Enums"]["stock_availability"]
            | null
          to_grade_tag_id?: number | null
          to_location_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_movement_lines_from_grade_tag_id_fkey"
            columns: ["from_grade_tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movement_lines_from_location_id_fkey"
            columns: ["from_location_id"]
            isOneToOne: false
            referencedRelation: "stock_locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movement_lines_movement_id_fkey"
            columns: ["movement_id"]
            isOneToOne: false
            referencedRelation: "stock_movements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movement_lines_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movement_lines_to_grade_tag_id_fkey"
            columns: ["to_grade_tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movement_lines_to_location_id_fkey"
            columns: ["to_location_id"]
            isOneToOne: false
            referencedRelation: "stock_locations"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_movements: {
        Row: {
          created_at: string
          created_by_email: string | null
          id: number
          is_posted: boolean
          movement_no: string
          movement_type: Database["public"]["Enums"]["stock_movement_type"]
          notes: string | null
          posted_at: string | null
          reference_id: string | null
          reference_type: string | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by_email?: string | null
          id?: number
          is_posted?: boolean
          movement_no: string
          movement_type: Database["public"]["Enums"]["stock_movement_type"]
          notes?: string | null
          posted_at?: string | null
          reference_id?: string | null
          reference_type?: string | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by_email?: string | null
          id?: number
          is_posted?: boolean
          movement_no?: string
          movement_type?: Database["public"]["Enums"]["stock_movement_type"]
          notes?: string | null
          posted_at?: string | null
          reference_id?: string | null
          reference_type?: string | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_tenant_id_fkey"
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
      system_role_templates: {
        Row: {
          action: string
          allowed: boolean
          created_at: string
          id: number
          module_key: string
          role_slug: string
          scope: string
          updated_at: string
        }
        Insert: {
          action: string
          allowed: boolean
          created_at?: string
          id?: number
          module_key: string
          role_slug: string
          scope: string
          updated_at?: string
        }
        Update: {
          action?: string
          allowed?: boolean
          created_at?: string
          id?: number
          module_key?: string
          role_slug?: string
          scope?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "system_role_templates_module_key_fkey"
            columns: ["module_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
          },
        ]
      }
      tag_categories: {
        Row: {
          cardinality: string
          code: string
          created_at: string
          id: number
          is_active: boolean
          is_system: boolean
          module_key: string
          name: string
          sort_order: number | null
          tenant_id: number | null
        }
        Insert: {
          cardinality: string
          code: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          module_key: string
          name: string
          sort_order?: number | null
          tenant_id?: number | null
        }
        Update: {
          cardinality?: string
          code?: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          module_key?: string
          name?: string
          sort_order?: number | null
          tenant_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "tag_categories_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      tags: {
        Row: {
          category_id: number | null
          color: string
          created_at: string
          created_by_email: string
          group_name: string | null
          id: number
          is_active: boolean
          is_system: boolean
          metadata: Json
          name: string
          slug: string
          sort_order: number | null
          tenant_id: number | null
          type: string
        }
        Insert: {
          category_id?: number | null
          color?: string
          created_at?: string
          created_by_email?: string
          group_name?: string | null
          id?: number
          is_active?: boolean
          is_system?: boolean
          metadata?: Json
          name: string
          slug: string
          sort_order?: number | null
          tenant_id?: number | null
          type?: string
        }
        Update: {
          category_id?: number | null
          color?: string
          created_at?: string
          created_by_email?: string
          group_name?: string | null
          id?: number
          is_active?: boolean
          is_system?: boolean
          metadata?: Json
          name?: string
          slug?: string
          sort_order?: number | null
          tenant_id?: number | null
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "tags_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "tag_categories"
            referencedColumns: ["id"]
          },
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
      tenant_permission_versions: {
        Row: {
          tenant_id: number
          updated_at: string
          version: number
        }
        Insert: {
          tenant_id: number
          updated_at?: string
          version?: number
        }
        Update: {
          tenant_id?: number
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "tenant_permission_versions_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: true
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      tenant_role_grants: {
        Row: {
          action: string
          allowed: boolean
          created_at: string
          id: number
          module_key: string
          tenant_role_id: number
          updated_at: string
          updated_by_email: string | null
        }
        Insert: {
          action: string
          allowed: boolean
          created_at?: string
          id?: number
          module_key: string
          tenant_role_id: number
          updated_at?: string
          updated_by_email?: string | null
        }
        Update: {
          action?: string
          allowed?: boolean
          created_at?: string
          id?: number
          module_key?: string
          tenant_role_id?: number
          updated_at?: string
          updated_by_email?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "tenant_role_grants_module_key_fkey"
            columns: ["module_key"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "tenant_role_grants_tenant_role_id_fkey"
            columns: ["tenant_role_id"]
            isOneToOne: false
            referencedRelation: "tenant_roles"
            referencedColumns: ["id"]
          },
        ]
      }
      tenant_roles: {
        Row: {
          created_at: string
          id: number
          is_active: boolean
          is_admin: boolean
          is_system: boolean
          name: string
          scope: string
          slug: string
          source_app_role: Database["public"]["Enums"]["app_role"] | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_active?: boolean
          is_admin?: boolean
          is_system?: boolean
          name: string
          scope: string
          slug: string
          source_app_role?: Database["public"]["Enums"]["app_role"] | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_active?: boolean
          is_admin?: boolean
          is_system?: boolean
          name?: string
          scope?: string
          slug?: string
          source_app_role?: Database["public"]["Enums"]["app_role"] | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenant_roles_tenant_id_fkey"
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
      thrift_courier_providers: {
        Row: {
          code: string
          country_code: string
          created_at: string
          id: number
          is_active: boolean
          is_system: boolean
          meta: Json
          name: string
          sort_order: number
          tenant_id: number | null
          updated_at: string
        }
        Insert: {
          code: string
          country_code?: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          meta?: Json
          name: string
          sort_order?: number
          tenant_id?: number | null
          updated_at?: string
        }
        Update: {
          code?: string
          country_code?: string
          created_at?: string
          id?: number
          is_active?: boolean
          is_system?: boolean
          meta?: Json
          name?: string
          sort_order?: number
          tenant_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_courier_providers_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_customers: {
        Row: {
          address: string | null
          address_parts: Json
          created_at: string
          id: number
          inserted_by: string
          name: string
          notes: string | null
          phone: string
          phone_normalized: string
          secondary_phone: string | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          address?: string | null
          address_parts?: Json
          created_at?: string
          id?: number
          inserted_by: string
          name: string
          notes?: string | null
          phone: string
          phone_normalized: string
          secondary_phone?: string | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          address?: string | null
          address_parts?: Json
          created_at?: string
          id?: number
          inserted_by?: string
          name?: string
          notes?: string | null
          phone?: string
          phone_normalized?: string
          secondary_phone?: string | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_customers_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_invoice_counters: {
        Row: {
          created_at: string
          last_value: number
          tenant_id: number
          updated_at: string
          year_month: string
        }
        Insert: {
          created_at?: string
          last_value?: number
          tenant_id: number
          updated_at?: string
          year_month: string
        }
        Update: {
          created_at?: string
          last_value?: number
          tenant_id?: number
          updated_at?: string
          year_month?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_invoice_counters_tenant_id_fkey"
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
          landed_unit_cost_at_sale: number
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
          landed_unit_cost_at_sale?: number
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
          landed_unit_cost_at_sale?: number
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
          markup_rate_override: number | null
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
          markup_rate_override?: number | null
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
          markup_rate_override?: number | null
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
      thrift_return_counters: {
        Row: {
          created_at: string
          last_value: number
          tenant_id: number
          updated_at: string
          year_month: string
        }
        Insert: {
          created_at?: string
          last_value?: number
          tenant_id: number
          updated_at?: string
          year_month: string
        }
        Update: {
          created_at?: string
          last_value?: number
          tenant_id?: number
          updated_at?: string
          year_month?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_return_counters_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_sales_invoice_items: {
        Row: {
          created_at: string
          discount_amount: number
          final_price: number
          id: number
          invoice_id: number
          landed_unit_cost_at_sale: number
          net_profit: number
          quantity: number
          sell_price: number
          stock_id: number | null
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          discount_amount?: number
          final_price?: number
          id?: number
          invoice_id: number
          landed_unit_cost_at_sale?: number
          net_profit?: number
          quantity?: number
          sell_price?: number
          stock_id?: number | null
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          discount_amount?: number
          final_price?: number
          id?: number
          invoice_id?: number
          landed_unit_cost_at_sale?: number
          net_profit?: number
          quantity?: number
          sell_price?: number
          stock_id?: number | null
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_sales_invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "thrift_sales_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_invoice_items_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: false
            referencedRelation: "thrift_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_invoice_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_sales_invoices: {
        Row: {
          advance_amount: number
          advance_note: string | null
          close_reason: string | null
          cod_expected: number | null
          cod_fee_amount: number
          cod_fee_paid_by: string | null
          cod_remittance_ref: string | null
          cod_remitted_amount: number | null
          cod_remitted_at: string | null
          courier_amount: number
          courier_cod_amount: number
          courier_paid_by: string | null
          courier_provider: string | null
          courier_provider_id: number | null
          created_at: string
          created_by: string
          customer_address: string | null
          customer_address_parts: Json
          customer_id: number | null
          customer_name: string | null
          customer_phone: string | null
          customer_secondary_phone: string | null
          date: string
          delivery_status: string | null
          economics_closed_at: string | null
          id: number
          invoice_number: string
          meta: Json
          notes: string | null
          other_expense_amount: number
          packing_amount: number
          packing_paid_by: string | null
          payment_method: string
          payment_status: string
          return_courier_amount: number
          revert_notes: string | null
          revert_reason: string | null
          reverted_at: string | null
          reverted_by: string | null
          sale_channel: string
          status: string
          tenant_id: number
          total_invoice_amount: number
          updated_at: string
        }
        Insert: {
          advance_amount?: number
          advance_note?: string | null
          close_reason?: string | null
          cod_expected?: number | null
          cod_fee_amount?: number
          cod_fee_paid_by?: string | null
          cod_remittance_ref?: string | null
          cod_remitted_amount?: number | null
          cod_remitted_at?: string | null
          courier_amount?: number
          courier_cod_amount?: number
          courier_paid_by?: string | null
          courier_provider?: string | null
          courier_provider_id?: number | null
          created_at?: string
          created_by?: string
          customer_address?: string | null
          customer_address_parts?: Json
          customer_id?: number | null
          customer_name?: string | null
          customer_phone?: string | null
          customer_secondary_phone?: string | null
          date?: string
          delivery_status?: string | null
          economics_closed_at?: string | null
          id?: number
          invoice_number: string
          meta?: Json
          notes?: string | null
          other_expense_amount?: number
          packing_amount?: number
          packing_paid_by?: string | null
          payment_method?: string
          payment_status?: string
          return_courier_amount?: number
          revert_notes?: string | null
          revert_reason?: string | null
          reverted_at?: string | null
          reverted_by?: string | null
          sale_channel?: string
          status?: string
          tenant_id: number
          total_invoice_amount?: number
          updated_at?: string
        }
        Update: {
          advance_amount?: number
          advance_note?: string | null
          close_reason?: string | null
          cod_expected?: number | null
          cod_fee_amount?: number
          cod_fee_paid_by?: string | null
          cod_remittance_ref?: string | null
          cod_remitted_amount?: number | null
          cod_remitted_at?: string | null
          courier_amount?: number
          courier_cod_amount?: number
          courier_paid_by?: string | null
          courier_provider?: string | null
          courier_provider_id?: number | null
          created_at?: string
          created_by?: string
          customer_address?: string | null
          customer_address_parts?: Json
          customer_id?: number | null
          customer_name?: string | null
          customer_phone?: string | null
          customer_secondary_phone?: string | null
          date?: string
          delivery_status?: string | null
          economics_closed_at?: string | null
          id?: number
          invoice_number?: string
          meta?: Json
          notes?: string | null
          other_expense_amount?: number
          packing_amount?: number
          packing_paid_by?: string | null
          payment_method?: string
          payment_status?: string
          return_courier_amount?: number
          revert_notes?: string | null
          revert_reason?: string | null
          reverted_at?: string | null
          reverted_by?: string | null
          sale_channel?: string
          status?: string
          tenant_id?: number
          total_invoice_amount?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_sales_invoices_courier_provider_id_fkey"
            columns: ["courier_provider_id"]
            isOneToOne: false
            referencedRelation: "thrift_courier_providers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_invoices_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "thrift_customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_invoices_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_sales_pnl_lines: {
        Row: {
          allocated_fees_total: number
          allocated_return_courier: number
          allocated_shop_cod_fee: number
          allocated_shop_delivery: number
          allocated_shop_packing: number
          cogs_is_loss: boolean
          created_at: string
          event_at: string
          event_date: string
          id: number
          inbound_shipment_id: number
          invoice_id: number
          invoice_item_id: number
          outcome: string
          quantity: number
          return_id: number | null
          sell_amount: number
          stock_id: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          allocated_fees_total?: number
          allocated_return_courier?: number
          allocated_shop_cod_fee?: number
          allocated_shop_delivery?: number
          allocated_shop_packing?: number
          cogs_is_loss?: boolean
          created_at?: string
          event_at?: string
          event_date?: string
          id?: number
          inbound_shipment_id: number
          invoice_id: number
          invoice_item_id: number
          outcome: string
          quantity?: number
          return_id?: number | null
          sell_amount?: number
          stock_id: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          allocated_fees_total?: number
          allocated_return_courier?: number
          allocated_shop_cod_fee?: number
          allocated_shop_delivery?: number
          allocated_shop_packing?: number
          cogs_is_loss?: boolean
          created_at?: string
          event_at?: string
          event_date?: string
          id?: number
          inbound_shipment_id?: number
          invoice_id?: number
          invoice_item_id?: number
          outcome?: string
          quantity?: number
          return_id?: number | null
          sell_amount?: number
          stock_id?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_sales_pnl_lines_inbound_shipment_id_fkey"
            columns: ["inbound_shipment_id"]
            isOneToOne: false
            referencedRelation: "thrift_shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_pnl_lines_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "thrift_sales_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_pnl_lines_invoice_item_id_fkey"
            columns: ["invoice_item_id"]
            isOneToOne: true
            referencedRelation: "thrift_sales_invoice_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_pnl_lines_return_id_fkey"
            columns: ["return_id"]
            isOneToOne: false
            referencedRelation: "thrift_sales_returns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_pnl_lines_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: false
            referencedRelation: "thrift_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_pnl_lines_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_sales_return_items: {
        Row: {
          condition: string
          created_at: string
          id: number
          invoice_item_id: number
          quantity: number
          refund_amount: number
          return_id: number
          stock_id: number
          tenant_id: number
        }
        Insert: {
          condition: string
          created_at?: string
          id?: number
          invoice_item_id: number
          quantity?: number
          refund_amount?: number
          return_id: number
          stock_id: number
          tenant_id: number
        }
        Update: {
          condition?: string
          created_at?: string
          id?: number
          invoice_item_id?: number
          quantity?: number
          refund_amount?: number
          return_id?: number
          stock_id?: number
          tenant_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "thrift_sales_return_items_invoice_item_id_fkey"
            columns: ["invoice_item_id"]
            isOneToOne: true
            referencedRelation: "thrift_sales_invoice_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_return_items_return_id_fkey"
            columns: ["return_id"]
            isOneToOne: false
            referencedRelation: "thrift_sales_returns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_return_items_stock_id_fkey"
            columns: ["stock_id"]
            isOneToOne: false
            referencedRelation: "thrift_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_return_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      thrift_sales_returns: {
        Row: {
          created_at: string
          created_by: string
          id: number
          invoice_id: number
          notes: string | null
          refund_amount: number
          return_courier_amount: number
          return_number: string
          status: string
          tenant_id: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string
          id?: number
          invoice_id: number
          notes?: string | null
          refund_amount?: number
          return_courier_amount?: number
          return_number: string
          status?: string
          tenant_id: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: number
          invoice_id?: number
          notes?: string | null
          refund_amount?: number
          return_courier_amount?: number
          return_number?: string
          status?: string
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thrift_sales_returns_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "thrift_sales_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thrift_sales_returns_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
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
          marketing_tag_config: Json
          return_window_days: number
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
          marketing_tag_config?: Json
          return_window_days?: number
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
          marketing_tag_config?: Json
          return_window_days?: number
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
          marketing_tag_config: Json
          name: string
          product_conversion_rate: number | null
          purchase_currency_id: number
          tenant_id: number
          total_cargo_weight_kg: number | null
          transportation_total_cost: number | null
          updated_at: string
          washing_total_cost: number | null
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
          marketing_tag_config?: Json
          name: string
          product_conversion_rate?: number | null
          purchase_currency_id: number
          tenant_id: number
          total_cargo_weight_kg?: number | null
          transportation_total_cost?: number | null
          updated_at?: string
          washing_total_cost?: number | null
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
          marketing_tag_config?: Json
          name?: string
          product_conversion_rate?: number | null
          purchase_currency_id?: number
          tenant_id?: number
          total_cargo_weight_kg?: number | null
          transportation_total_cost?: number | null
          updated_at?: string
          washing_total_cost?: number | null
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
          deleted_at: string | null
          deleted_by: string | null
          extra_origin_unit_price: number | null
          extra_weight: number | null
          held_at: string | null
          held_by: string | null
          held_for_name: string | null
          held_for_phone: string | null
          held_for_phone_normalized: string | null
          hold_expires_at: string | null
          hold_note: string | null
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
          deleted_at?: string | null
          deleted_by?: string | null
          extra_origin_unit_price?: number | null
          extra_weight?: number | null
          held_at?: string | null
          held_by?: string | null
          held_for_name?: string | null
          held_for_phone?: string | null
          held_for_phone_normalized?: string | null
          hold_expires_at?: string | null
          hold_note?: string | null
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
          deleted_at?: string | null
          deleted_by?: string | null
          extra_origin_unit_price?: number | null
          extra_weight?: number | null
          held_at?: string | null
          held_by?: string | null
          held_for_name?: string | null
          held_for_phone?: string | null
          held_for_phone_normalized?: string | null
          hold_expires_at?: string | null
          hold_note?: string | null
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
      universal_wallet_ledger: {
        Row: {
          amount: number
          balance_after: number
          base_amount: number
          created_at: string
          currency_code: string
          entity_id: number
          entity_type: string
          exchange_rate: number
          id: string
          metadata: Json
          source_id: string | null
          source_type: string
          tenant_id: number
          type: string
        }
        Insert: {
          amount: number
          balance_after: number
          base_amount: number
          created_at?: string
          currency_code?: string
          entity_id: number
          entity_type: string
          exchange_rate?: number
          id?: string
          metadata?: Json
          source_id?: string | null
          source_type: string
          tenant_id: number
          type: string
        }
        Update: {
          amount?: number
          balance_after?: number
          base_amount?: number
          created_at?: string
          currency_code?: string
          entity_id?: number
          entity_type?: string
          exchange_rate?: number
          id?: string
          metadata?: Json
          source_id?: string | null
          source_type?: string
          tenant_id?: number
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "universal_wallet_ledger_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      vendors: {
        Row: {
          address: string | null
          code: string
          created_at: string
          email: string | null
          id: number
          is_default: boolean
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
          is_default?: boolean
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
          is_default?: boolean
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
      wallet_accounts: {
        Row: {
          available_balance: number
          created_at: string
          currency_code: string
          entity_id: number
          entity_type: string
          id: number
          locked_balance: number
          pending_balance: number
          tenant_id: number
          updated_at: string
        }
        Insert: {
          available_balance?: number
          created_at?: string
          currency_code?: string
          entity_id: number
          entity_type: string
          id?: never
          locked_balance?: number
          pending_balance?: number
          tenant_id: number
          updated_at?: string
        }
        Update: {
          available_balance?: number
          created_at?: string
          currency_code?: string
          entity_id?: number
          entity_type?: string
          id?: never
          locked_balance?: number
          pending_balance?: number
          tenant_id?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_accounts_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      global_invoice_items: {
        Row: {
          assigned_child_tenant_id: number | null
          barcode_snapshot: string | null
          created_at: string | null
          global_stock_id: number | null
          id: number | null
          invoice_id: number | null
          line_discount_amount: number | null
          line_total_amount: number | null
          name_snapshot: string | null
          parent_tenant_id: number | null
          product_code_snapshot: string | null
          product_id: number | null
          quantity: number | null
          return_quantity: number | null
          sell_price_amount: number | null
          shipment_item_id: number | null
          tenant_id: number | null
          unit_cost_price: number | null
          updated_at: string | null
        }
        Insert: {
          assigned_child_tenant_id?: number | null
          barcode_snapshot?: string | null
          created_at?: string | null
          global_stock_id?: number | null
          id?: number | null
          invoice_id?: number | null
          line_discount_amount?: number | null
          line_total_amount?: number | null
          name_snapshot?: string | null
          parent_tenant_id?: number | null
          product_code_snapshot?: string | null
          product_id?: number | null
          quantity?: number | null
          return_quantity?: number | null
          sell_price_amount?: number | null
          shipment_item_id?: number | null
          tenant_id?: number | null
          unit_cost_price?: number | null
          updated_at?: string | null
        }
        Update: {
          assigned_child_tenant_id?: number | null
          barcode_snapshot?: string | null
          created_at?: string | null
          global_stock_id?: number | null
          id?: number | null
          invoice_id?: number | null
          line_discount_amount?: number | null
          line_total_amount?: number | null
          name_snapshot?: string | null
          parent_tenant_id?: number | null
          product_code_snapshot?: string | null
          product_id?: number | null
          quantity?: number | null
          return_quantity?: number | null
          sell_price_amount?: number | null
          shipment_item_id?: number | null
          tenant_id?: number | null
          unit_cost_price?: number | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "global_invoice_items_assigned_child_tenant_id_fkey"
            columns: ["assigned_child_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_global_stock_id_fkey"
            columns: ["global_stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
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
            foreignKeyName: "global_invoice_items_parent_tenant_id_fkey"
            columns: ["tenant_id"]
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
            foreignKeyName: "global_invoice_items_shipment_item_id_fkey"
            columns: ["shipment_item_id"]
            isOneToOne: false
            referencedRelation: "global_shipment_items"
            referencedColumns: ["id"]
          },
        ]
      }
      global_invoices: {
        Row: {
          billing_profile_id: number | null
          collection_source:
            | Database["public"]["Enums"]["collection_source_type"]
            | null
          created_at: string | null
          created_by: string | null
          discount_amount: number | null
          due_amount: number | null
          due_date: string | null
          fulfillment_status:
            | Database["public"]["Enums"]["global_fulfillment_status"]
            | null
          id: number | null
          invoice_date: string | null
          invoice_no: string | null
          invoice_status:
            | Database["public"]["Enums"]["global_invoice_status"]
            | null
          invoice_type:
            | Database["public"]["Enums"]["global_invoice_type"]
            | null
          issued_by_tenant_id: number | null
          note: string | null
          paid_amount: number | null
          parent_tenant_id: number | null
          payment_status: string | null
          print_charge: number | null
          recipient_address: string | null
          recipient_name: string | null
          recipient_phone: string | null
          recipient_profile_id: number | null
          retail_billing_mode:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount: number | null
          shipping_charge: number | null
          subtotal_amount: number | null
          tenant_id: number | null
          total_amount: number | null
          updated_at: string | null
          wrapping_charge: number | null
        }
        Insert: {
          billing_profile_id?: number | null
          collection_source?:
            | Database["public"]["Enums"]["collection_source_type"]
            | null
          created_at?: string | null
          created_by?: string | null
          discount_amount?: number | null
          due_amount?: number | null
          due_date?: string | null
          fulfillment_status?:
            | Database["public"]["Enums"]["global_fulfillment_status"]
            | null
          id?: number | null
          invoice_date?: string | null
          invoice_no?: string | null
          invoice_status?:
            | Database["public"]["Enums"]["global_invoice_status"]
            | null
          invoice_type?:
            | Database["public"]["Enums"]["global_invoice_type"]
            | null
          issued_by_tenant_id?: number | null
          note?: string | null
          paid_amount?: number | null
          parent_tenant_id?: number | null
          payment_status?: string | null
          print_charge?: number | null
          recipient_address?: string | null
          recipient_name?: string | null
          recipient_phone?: string | null
          recipient_profile_id?: number | null
          retail_billing_mode?:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount?: number | null
          shipping_charge?: number | null
          subtotal_amount?: number | null
          tenant_id?: number | null
          total_amount?: number | null
          updated_at?: string | null
          wrapping_charge?: number | null
        }
        Update: {
          billing_profile_id?: number | null
          collection_source?:
            | Database["public"]["Enums"]["collection_source_type"]
            | null
          created_at?: string | null
          created_by?: string | null
          discount_amount?: number | null
          due_amount?: number | null
          due_date?: string | null
          fulfillment_status?:
            | Database["public"]["Enums"]["global_fulfillment_status"]
            | null
          id?: number | null
          invoice_date?: string | null
          invoice_no?: string | null
          invoice_status?:
            | Database["public"]["Enums"]["global_invoice_status"]
            | null
          invoice_type?:
            | Database["public"]["Enums"]["global_invoice_type"]
            | null
          issued_by_tenant_id?: number | null
          note?: string | null
          paid_amount?: number | null
          parent_tenant_id?: number | null
          payment_status?: string | null
          print_charge?: number | null
          recipient_address?: string | null
          recipient_name?: string | null
          recipient_phone?: string | null
          recipient_profile_id?: number | null
          retail_billing_mode?:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount?: number | null
          shipping_charge?: number | null
          subtotal_amount?: number | null
          tenant_id?: number | null
          total_amount?: number | null
          updated_at?: string | null
          wrapping_charge?: number | null
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
            foreignKeyName: "global_invoices_issued_by_tenant_id_fkey"
            columns: ["issued_by_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
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
            foreignKeyName: "global_invoices_parent_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_invoices_recipient_profile_id_fkey"
            columns: ["recipient_profile_id"]
            isOneToOne: false
            referencedRelation: "recipient_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      global_return_items: {
        Row: {
          created_at: string | null
          global_stock_id: number | null
          id: number | null
          invoice_id: number | null
          invoice_item_id: number | null
          note: string | null
          parent_tenant_id: number | null
          quantity: number | null
          return_charge_amount: number | null
          tenant_id: number | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          global_stock_id?: number | null
          id?: number | null
          invoice_id?: number | null
          invoice_item_id?: number | null
          note?: string | null
          parent_tenant_id?: number | null
          quantity?: number | null
          return_charge_amount?: number | null
          tenant_id?: number | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          global_stock_id?: number | null
          id?: number | null
          invoice_id?: number | null
          invoice_item_id?: number | null
          note?: string | null
          parent_tenant_id?: number | null
          quantity?: number | null
          return_charge_amount?: number | null
          tenant_id?: number | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "global_return_items_global_stock_id_fkey"
            columns: ["global_stock_id"]
            isOneToOne: false
            referencedRelation: "global_stocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_return_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "global_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_return_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "sales_invoices"
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
            foreignKeyName: "global_return_items_invoice_item_id_fkey"
            columns: ["invoice_item_id"]
            isOneToOne: false
            referencedRelation: "sales_invoice_items"
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
            foreignKeyName: "global_return_items_parent_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      _assert_parent_warehouse_tenant: {
        Args: { p_parent_tenant_id: number }
        Returns: undefined
      }
      _can_view_stock_locations: {
        Args: { p_parent_tenant_id: number }
        Returns: boolean
      }
      _stock_location_is_leaf: { Args: { p_id: number }; Returns: boolean }
      _validate_stock_location_nesting: {
        Args: {
          p_kind: Database["public"]["Enums"]["stock_location_kind"]
          p_parent_location_id: number
          p_parent_tenant_id: number
        }
        Returns: undefined
      }
      add_child_line_to_parent_shipment: {
        Args: {
          p_parent_shipment_id: number
          p_source_id: number
          p_source_type: string
        }
        Returns: {
          add_method: Database["public"]["Enums"]["global_shipment_item_add_method"]
          barcode: string | null
          created_at: string
          id: number
          image_url: string | null
          landed_cost_bdt: number | null
          name: string
          ordered_quantity: number
          package_weight: number
          product_code: string | null
          product_id: number | null
          product_weight: number
          purchase_price: number
          received_quantity: number | null
          section_id: number | null
          shipment_id: number
          sort_order: number
          source_child_tenant_id: number | null
          source_id: number | null
          source_type: string | null
          updated_at: string
          vendor_id: number | null
        }
        SetofOptions: {
          from: "*"
          to: "global_shipment_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_demand_bucket_item: {
        Args: {
          p_billing_profile_id: number
          p_product_id: number
          p_quantity?: number
          p_snapshot?: Json
          p_source_id?: number
          p_source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          p_tenant_id: number
        }
        Returns: {
          barcode: string | null
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string | null
          name: string
          note: string | null
          popped_at: string | null
          popped_into_id: number | null
          popped_into_type: string | null
          product_code: string | null
          product_id: number
          quantity: number
          source_id: number | null
          source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          status: Database["public"]["Enums"]["demand_bucket_status"]
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "customer_demand_bucket_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_demand_bucket_item_internal: {
        Args: {
          p_billing_profile_id: number
          p_product_id: number
          p_quantity?: number
          p_snapshot?: Json
          p_source_id?: number
          p_source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          p_tenant_id: number
        }
        Returns: {
          barcode: string | null
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string | null
          name: string
          note: string | null
          popped_at: string | null
          popped_into_id: number | null
          popped_into_type: string | null
          product_code: string | null
          product_id: number
          quantity: number
          source_id: number | null
          source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          status: Database["public"]["Enums"]["demand_bucket_status"]
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "customer_demand_bucket_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_global_invoice_item: {
        Args: {
          p_global_stock_id: number
          p_invoice_id: number
          p_line_discount_amount?: number
          p_quantity: number
          p_recipient_price_amount?: number
          p_sell_price_amount: number
        }
        Returns: {
          assigned_child_tenant_id: number | null
          barcode_snapshot: string | null
          created_at: string
          global_stock_id: number
          id: number
          invoice_id: number
          line_discount_amount: number
          line_total_amount: number
          name_snapshot: string
          parent_tenant_id: number
          product_code_snapshot: string | null
          product_id: number | null
          quantity: number
          return_quantity: number
          sell_price_amount: number
          shipment_item_id: number | null
          unit_cost_price: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "sales_invoice_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_global_return_item:
        | {
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
              return_charge_amount: number
              updated_at: string
            }
            SetofOptions: {
              from: "*"
              to: "sales_return_items"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
            Args: {
              p_invoice_id: number
              p_invoice_item_id: number
              p_note?: string
              p_quantity: number
              p_return_accounting_amount: number
              p_return_charge_amount?: number
              p_return_face_amount: number
              p_to_availability?: Database["public"]["Enums"]["stock_availability"]
              p_to_grade_tag_id?: number
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
              return_charge_amount: number
              updated_at: string
            }
            SetofOptions: {
              from: "*"
              to: "sales_return_items"
              isOneToOne: true
              isSetofReturn: false
            }
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
          to: "invoice_payments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_pbc_backlog_to_costing_file: {
        Args: { p_backlog_ids: number[]; p_file_id: number }
        Returns: number[]
      }
      add_pbc_backlog_to_file: {
        Args: { p_backlog_ids: number[]; p_file_id: number }
        Returns: number[]
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
      add_stock_movement_line: {
        Args: {
          p_from_availability?: Database["public"]["Enums"]["stock_availability"]
          p_from_grade_tag_id?: number
          p_from_location_id?: number
          p_movement_id: number
          p_quantity: number
          p_stock_id: number
          p_to_availability?: Database["public"]["Enums"]["stock_availability"]
          p_to_grade_tag_id?: number
          p_to_location_id?: number
        }
        Returns: Json
      }
      add_to_shop_cart: {
        Args: {
          p_customer_sell_price_amount?: number
          p_customer_sell_price_currency_id?: number
          p_global_stock_allocation_id?: number
          p_global_stock_id?: number
          p_product_id: number
          p_quantity?: number
          p_shop_id: number
        }
        Returns: Json
      }
      adjust_inventory_reserved_for_product: {
        Args: { p_delta: number; p_product_id: number; p_tenant_id: number }
        Returns: undefined
      }
      advance_dropship_order_status: {
        Args: {
          p_bank_trx_id?: string
          p_order_id: number
          p_remittance_ref?: string
          p_target_status: Database["public"]["Enums"]["shop_order_status"]
        }
        Returns: Json
      }
      allocate_payment_to_global_invoice: {
        Args: {
          p_amount: number
          p_global_invoice_id: number
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
          to: "invoice_payments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      apply_dropship_payout_settlement_fifo: {
        Args: {
          p_amount: number
          p_billing_profile_id: number
          p_tenant_id: number
        }
        Returns: undefined
      }
      apply_global_invoice_settlement_discount: {
        Args: { p_amount: number; p_invoice_id: number; p_note?: string }
        Returns: {
          billing_profile_id: number | null
          collection_source: Database["public"]["Enums"]["collection_source_type"]
          created_at: string
          created_by: string | null
          discount_amount: number
          due_amount: number
          due_date: string | null
          fulfillment_status: Database["public"]["Enums"]["global_fulfillment_status"]
          id: number
          invoice_date: string
          invoice_no: string
          invoice_status: Database["public"]["Enums"]["global_invoice_status"]
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          issued_by_tenant_id: number
          note: string | null
          paid_amount: number
          parent_tenant_id: number
          payment_status: string
          print_charge: number
          recipient_address: string | null
          recipient_name: string | null
          recipient_phone: string | null
          recipient_profile_id: number | null
          retail_billing_mode:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount: number
          shipping_charge: number
          subtotal_amount: number
          total_amount: number
          updated_at: string
          wrapping_charge: number
        }
        SetofOptions: {
          from: "*"
          to: "sales_invoices"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      apply_global_invoice_target_total: {
        Args: {
          p_dry_run?: boolean
          p_invoice_id: number
          p_target_total: number
        }
        Returns: Json
      }
      apply_global_shipment_purchase_balance: {
        Args: {
          p_adjustments: Json
          p_shipment_id: number
          p_transaction_rate?: number
        }
        Returns: Json
      }
      apply_global_shipment_weight_balance: {
        Args: {
          p_adjustments: Json
          p_shipment_id: number
          p_transaction_rate?: number
        }
        Returns: Json
      }
      archive_shipment_progress_flow: {
        Args: { p_archive?: boolean; p_flow_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          name: string
          slug: string
          tenant_id: number
        }
        SetofOptions: {
          from: "*"
          to: "shipment_progress_flows"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      archive_shipment_progress_flow_stage: {
        Args: { p_archive?: boolean; p_flow_stage_id: number }
        Returns: {
          color: string
          flow_id: number
          flow_stage_id: number
          is_active: boolean
          name: string
          slug: string
          sort_order: number
          tag_id: number
        }[]
      }
      archive_shipment_progress_tag: {
        Args: { p_archive?: boolean; p_tag_id: number }
        Returns: {
          category_id: number | null
          color: string
          created_at: string
          created_by_email: string
          group_name: string | null
          id: number
          is_active: boolean
          is_system: boolean
          metadata: Json
          name: string
          slug: string
          sort_order: number | null
          tenant_id: number | null
          type: string
        }
        SetofOptions: {
          from: "*"
          to: "tags"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      assign_customer_group_member_role: {
        Args: { p_cgm_id: number; p_tenant_role_id: number }
        Returns: {
          added_by: number | null
          created_at: string
          customer_group_id: number
          email: string
          id: number
          is_active: boolean
          name: string
          role: Database["public"]["Enums"]["customer_group_role"]
          tenant_role_id: number | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "customer_group_members"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      assign_membership_role: {
        Args: { p_membership_id: number; p_tenant_role_id: number }
        Returns: {
          accent_color: string | null
          created_at: string
          email: string
          id: number
          investor_id: number | null
          is_active: boolean
          preference: Json
          role: Database["public"]["Enums"]["app_role"]
          tenant_id: number | null
          tenant_role_id: number | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "memberships"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      assign_shipment_to_child: {
        Args: {
          p_child_tenant_id: number
          p_parent_tenant_id: number
          p_shipment_id: number
        }
        Returns: Json
      }
      auth_investor_id: { Args: never; Returns: number }
      browse_shop_catalog_for_customer: {
        Args: {
          p_brand?: string
          p_category?: string
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_shop_slug: string
          p_tenant_id: number
        }
        Returns: Json
      }
      bulk_add_global_shipment_items: {
        Args: { p_items: Json; p_shipment_id: number }
        Returns: {
          add_method: Database["public"]["Enums"]["global_shipment_item_add_method"]
          barcode: string | null
          created_at: string
          id: number
          image_url: string | null
          landed_cost_bdt: number | null
          name: string
          ordered_quantity: number
          package_weight: number
          product_code: string | null
          product_id: number | null
          product_weight: number
          purchase_price: number
          received_quantity: number | null
          section_id: number | null
          shipment_id: number
          sort_order: number
          source_child_tenant_id: number | null
          source_id: number | null
          source_type: string | null
          updated_at: string
          vendor_id: number | null
        }[]
        SetofOptions: {
          from: "*"
          to: "global_shipment_items"
          isOneToOne: false
          isSetofReturn: true
        }
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
      bulk_allocate_shipment_stock:
        | {
            Args: {
              p_child_tenant_id: number
              p_parent_tenant_id: number
              p_shipment_id: number
            }
            Returns: number
          }
        | {
            Args: {
              p_allocations?: Json
              p_child_tenant_id: number
              p_shipment_id: number
            }
            Returns: Json
          }
      bulk_apply_shop_markup:
        | {
            Args: {
              p_listing_ids?: number[]
              p_markup_amount?: number
              p_markup_type?: string
              p_shop_id: number
              p_target_price?: string
            }
            Returns: number
          }
        | {
            Args: {
              p_listing_ids?: number[]
              p_markup_percentage?: number
              p_shop_id: number
            }
            Returns: number
          }
      bulk_delete_global_shipment_items: {
        Args: { p_item_ids: number[]; p_shipment_id: number }
        Returns: number
      }
      bulk_delete_shipment_items_by_product_id: {
        Args: { p_items: Json; p_shipment_id: number }
        Returns: number
      }
      bulk_update_global_shipment_items: {
        Args: { p_shipment_id: number; p_updates: Json }
        Returns: {
          add_method: Database["public"]["Enums"]["global_shipment_item_add_method"]
          barcode: string | null
          created_at: string
          id: number
          image_url: string | null
          landed_cost_bdt: number | null
          name: string
          ordered_quantity: number
          package_weight: number
          product_code: string | null
          product_id: number | null
          product_weight: number
          purchase_price: number
          received_quantity: number | null
          section_id: number | null
          shipment_id: number
          sort_order: number
          source_child_tenant_id: number | null
          source_id: number | null
          source_type: string | null
          updated_at: string
          vendor_id: number | null
        }[]
        SetofOptions: {
          from: "*"
          to: "global_shipment_items"
          isOneToOne: false
          isSetofReturn: true
        }
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
      bulk_update_thrift_stock_locations: {
        Args: {
          p_box_id?: number
          p_shelf_id?: number
          p_stock_ids: number[]
          p_tenant_id: number
        }
        Returns: undefined
      }
      bulk_update_thrift_stock_statuses: {
        Args: { p_status: string; p_stock_ids: number[]; p_tenant_id: number }
        Returns: undefined
      }
      bump_tenant_permission_version: {
        Args: { p_tenant_id: number }
        Returns: undefined
      }
      calculate_costing_auxiliary_price_gbp: {
        Args: { p_delivery_price_gbp: number; p_price_in_web_gbp: number }
        Returns: number
      }
      calculate_costing_item_type_surcharge_gbp: {
        Args: { p_item_type: string }
        Returns: number
      }
      calculate_landed_unit_cost: {
        Args: { p_shipment_item_id: number }
        Returns: number
      }
      can_access_cart: { Args: { p_cart_id: number }; Returns: boolean }
      can_access_cart_item: {
        Args: { p_cart_item_id: number }
        Returns: boolean
      }
      can_access_demand_bucket_profile: {
        Args: {
          p_billing_profile_id: number
          p_staff_only?: boolean
          p_tenant_id: number
        }
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
      can_customer_access_shop: {
        Args: { p_shop_id: number }
        Returns: boolean
      }
      can_customer_access_store: {
        Args: { p_store_id: number }
        Returns: boolean
      }
      can_customer_negotiate_on_shop: {
        Args: { p_shop_id: number }
        Returns: boolean
      }
      can_customer_see_shop_price: {
        Args: { p_shop_id: number }
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
      can_manage_products_for_parent: {
        Args: { p_parent_tenant_id: number }
        Returns: boolean
      }
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
      can_view_products_for_parent: {
        Args: { p_parent_tenant_id: number }
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
      cancel_demand_bucket_item: {
        Args: { p_bucket_item_id: number }
        Returns: {
          barcode: string | null
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string | null
          name: string
          note: string | null
          popped_at: string | null
          popped_into_id: number | null
          popped_into_type: string | null
          product_code: string | null
          product_id: number
          quantity: number
          source_id: number | null
          source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          status: Database["public"]["Enums"]["demand_bucket_status"]
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "customer_demand_bucket_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      cart_exists: { Args: { p_cart_id: number }; Returns: boolean }
      ceil_thrift_retail_price: { Args: { p_price: number }; Returns: number }
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
      collect_wholesale_invoice_payment: {
        Args: {
          p_cash_amount?: number
          p_cash_method?: string
          p_invoice_id: number
          p_settlement_amount?: number
          p_wallet_amount?: number
        }
        Returns: Json
      }
      compute_thrift_landed_unit_cost: {
        Args: { p_stock_id: number }
        Returns: number
      }
      confirm_courier_remittance_to_tenant: {
        Args: {
          p_bank_trx_id?: string
          p_courier_charge?: number
          p_order_id: number
          p_remittance_ref?: string
        }
        Returns: Json
      }
      confirm_dropship_delivered_costing: {
        Args: {
          p_cod_amount?: number
          p_courier_notes?: string
          p_delivery_charge?: number
          p_order_id: number
        }
        Returns: Json
      }
      confirm_shop_order: { Args: { p_order_id: number }; Returns: undefined }
      convert_wholesale_draft_to_retail: {
        Args: { p_invoice_id: number }
        Returns: undefined
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
      create_and_post_stock_movement: {
        Args: {
          p_movement_type?: Database["public"]["Enums"]["stock_movement_type"]
          p_notes?: string
          p_quantity: number
          p_reference_id?: string
          p_reference_type?: string
          p_stock_id: number
          p_tenant_id: number
          p_to_availability?: Database["public"]["Enums"]["stock_availability"]
          p_to_grade_tag_id?: number
          p_to_location_id?: number
        }
        Returns: Json
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
          billing_profile_id: number | null
          collection_source: Database["public"]["Enums"]["collection_source_type"]
          created_at: string
          id: number
          method: string | null
          note: string | null
          payment_date: string
          reference: string | null
          tenant_id: number
          unallocated_amount: number
        }
        SetofOptions: {
          from: "*"
          to: "global_payments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_cargo_company_with_wallet: {
        Args: {
          p_address?: string
          p_code: string
          p_email?: string
          p_name: string
          p_notes?: string
          p_phone?: string
          p_tenant_id: number
        }
        Returns: Json
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
      create_customer_account: {
        Args: {
          p_accent_color?: string
          p_address?: string
          p_admin_email?: string
          p_admin_name: string
          p_group_name: string
          p_phone?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      create_dropship_invoice: {
        Args: {
          p_billing_profile_id?: number
          p_invoice_no?: string
          p_note?: string
          p_order_id: number
        }
        Returns: Json
      }
      create_dual_invoice_from_dropship_order: {
        Args: {
          p_billing_profile_id?: number
          p_invoice_no?: string
          p_note?: string
          p_order_id: number
        }
        Returns: Json
      }
      create_global_invoice:
        | {
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
              billing_profile_id: number | null
              collection_source: Database["public"]["Enums"]["collection_source_type"]
              created_at: string
              created_by: string | null
              discount_amount: number
              due_amount: number
              due_date: string | null
              fulfillment_status: Database["public"]["Enums"]["global_fulfillment_status"]
              id: number
              invoice_date: string
              invoice_no: string
              invoice_status: Database["public"]["Enums"]["global_invoice_status"]
              invoice_type: Database["public"]["Enums"]["global_invoice_type"]
              issued_by_tenant_id: number
              note: string | null
              paid_amount: number
              parent_tenant_id: number
              payment_status: string
              print_charge: number
              recipient_address: string | null
              recipient_name: string | null
              recipient_phone: string | null
              recipient_profile_id: number | null
              retail_billing_mode:
                | Database["public"]["Enums"]["retail_billing_mode"]
                | null
              settlement_discount_amount: number
              shipping_charge: number
              subtotal_amount: number
              total_amount: number
              updated_at: string
              wrapping_charge: number
            }
            SetofOptions: {
              from: "*"
              to: "sales_invoices"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
            Args: {
              p_billing_profile_id?: number
              p_due_date?: string
              p_invoice_date?: string
              p_invoice_no: string
              p_invoice_type: Database["public"]["Enums"]["global_invoice_type"]
              p_note?: string
              p_recipient_address?: string
              p_recipient_name?: string
              p_recipient_phone?: string
              p_recipient_profile_id?: number
              p_retail_billing_mode?: Database["public"]["Enums"]["retail_billing_mode"]
              p_tenant_id: number
            }
            Returns: {
              billing_profile_id: number | null
              collection_source: Database["public"]["Enums"]["collection_source_type"]
              created_at: string
              created_by: string | null
              discount_amount: number
              due_amount: number
              due_date: string | null
              fulfillment_status: Database["public"]["Enums"]["global_fulfillment_status"]
              id: number
              invoice_date: string
              invoice_no: string
              invoice_status: Database["public"]["Enums"]["global_invoice_status"]
              invoice_type: Database["public"]["Enums"]["global_invoice_type"]
              issued_by_tenant_id: number
              note: string | null
              paid_amount: number
              parent_tenant_id: number
              payment_status: string
              print_charge: number
              recipient_address: string | null
              recipient_name: string | null
              recipient_phone: string | null
              recipient_profile_id: number | null
              retail_billing_mode:
                | Database["public"]["Enums"]["retail_billing_mode"]
                | null
              settlement_discount_amount: number
              shipping_charge: number
              subtotal_amount: number
              total_amount: number
              updated_at: string
              wrapping_charge: number
            }
            SetofOptions: {
              from: "*"
              to: "sales_invoices"
              isOneToOne: true
              isSetofReturn: false
            }
          }
      create_or_update_courier_remittance_batch: {
        Args: {
          p_bank_trx_id?: string
          p_batch_id?: number
          p_batch_no?: string
          p_courier_charges_amount?: number
          p_courier_service_id?: string
          p_gross_cod_amount?: number
          p_items?: Json
          p_net_deposited_amount?: number
          p_note?: string
          p_payment_date?: string
          p_tenant_id?: number
        }
        Returns: Json
      }
      create_sales_invoice:
        | {
            Args: {
              p_billing_profile_id?: number
              p_due_date?: string
              p_invoice_date?: string
              p_invoice_no?: string
              p_invoice_type?: Database["public"]["Enums"]["global_invoice_type"]
              p_note?: string
              p_recipient_address?: string
              p_recipient_name?: string
              p_recipient_phone?: string
              p_recipient_profile_id?: number
              p_retail_billing_mode?: Database["public"]["Enums"]["retail_billing_mode"]
              p_tenant_id: number
            }
            Returns: {
              billing_profile_id: number | null
              collection_source: Database["public"]["Enums"]["collection_source_type"]
              created_at: string
              created_by: string | null
              discount_amount: number
              due_amount: number
              due_date: string | null
              fulfillment_status: Database["public"]["Enums"]["global_fulfillment_status"]
              id: number
              invoice_date: string
              invoice_no: string
              invoice_status: Database["public"]["Enums"]["global_invoice_status"]
              invoice_type: Database["public"]["Enums"]["global_invoice_type"]
              issued_by_tenant_id: number
              note: string | null
              paid_amount: number
              parent_tenant_id: number
              payment_status: string
              print_charge: number
              recipient_address: string | null
              recipient_name: string | null
              recipient_phone: string | null
              recipient_profile_id: number | null
              retail_billing_mode:
                | Database["public"]["Enums"]["retail_billing_mode"]
                | null
              settlement_discount_amount: number
              shipping_charge: number
              subtotal_amount: number
              total_amount: number
              updated_at: string
              wrapping_charge: number
            }
            SetofOptions: {
              from: "*"
              to: "sales_invoices"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
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
              billing_profile_id: number | null
              collection_source: Database["public"]["Enums"]["collection_source_type"]
              created_at: string
              created_by: string | null
              discount_amount: number
              due_amount: number
              due_date: string | null
              fulfillment_status: Database["public"]["Enums"]["global_fulfillment_status"]
              id: number
              invoice_date: string
              invoice_no: string
              invoice_status: Database["public"]["Enums"]["global_invoice_status"]
              invoice_type: Database["public"]["Enums"]["global_invoice_type"]
              issued_by_tenant_id: number
              note: string | null
              paid_amount: number
              parent_tenant_id: number
              payment_status: string
              print_charge: number
              recipient_address: string | null
              recipient_name: string | null
              recipient_phone: string | null
              recipient_profile_id: number | null
              retail_billing_mode:
                | Database["public"]["Enums"]["retail_billing_mode"]
                | null
              settlement_discount_amount: number
              shipping_charge: number
              subtotal_amount: number
              total_amount: number
              updated_at: string
              wrapping_charge: number
            }
            SetofOptions: {
              from: "*"
              to: "sales_invoices"
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
      create_shipment_draft: {
        Args: {
          p_cargo_company_id?: number
          p_name: string
          p_parent_tenant_id: number
          p_type: Database["public"]["Enums"]["global_shipment_type"]
          p_vendor_id?: number
        }
        Returns: {
          assigned_child_tenant_id: number | null
          cargo_company_id: number | null
          cargo_invoice_total: number | null
          created_at: string
          id: number
          inventory_added: boolean
          name: string
          parent_tenant_id: number
          progress_flow_id: number | null
          progress_tag_id: number | null
          public_tracking_token: string | null
          purchase_invoice_total: number | null
          received_date: string | null
          received_weight: number | null
          shipment_cost_currency_id: number | null
          shipment_purchase_currency_id: number | null
          status: string
          stock_ready: boolean
          tenant_shipment_id: number | null
          total_weight_kg: number | null
          type: Database["public"]["Enums"]["global_shipment_type"]
          updated_at: string
          vendor_id: number | null
        }
        SetofOptions: {
          from: "*"
          to: "global_shipments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_shipment_progress_flow: {
        Args: { p_name: string; p_tenant_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          name: string
          slug: string
          tenant_id: number
        }
        SetofOptions: {
          from: "*"
          to: "shipment_progress_flows"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_shipment_progress_flow_stage: {
        Args: {
          p_color?: string
          p_flow_id: number
          p_name: string
          p_sort_order?: number
        }
        Returns: {
          color: string
          flow_id: number
          flow_stage_id: number
          is_active: boolean
          name: string
          slug: string
          sort_order: number
          tag_id: number
        }[]
      }
      create_shipment_progress_tag: {
        Args: {
          p_color?: string
          p_name: string
          p_sort_order?: number
          p_tenant_id: number
        }
        Returns: {
          category_id: number | null
          color: string
          created_at: string
          created_by_email: string
          group_name: string | null
          id: number
          is_active: boolean
          is_system: boolean
          metadata: Json
          name: string
          slug: string
          sort_order: number | null
          tenant_id: number | null
          type: string
        }
        SetofOptions: {
          from: "*"
          to: "tags"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_stock_movement: {
        Args: {
          p_movement_type: Database["public"]["Enums"]["stock_movement_type"]
          p_notes?: string
          p_reference_id?: string
          p_reference_type?: string
          p_tenant_id: number
        }
        Returns: Json
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
      create_tenant_role: {
        Args: {
          p_is_admin?: boolean
          p_name: string
          p_scope: string
          p_slug: string
          p_tenant_id: number
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          is_admin: boolean
          is_system: boolean
          name: string
          scope: string
          slug: string
          source_app_role: Database["public"]["Enums"]["app_role"] | null
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "tenant_roles"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_thrift_sales_invoice: {
        Args: {
          p_advance_amount?: number
          p_advance_note?: string
          p_cod_fee_amount?: number
          p_cod_fee_paid_by?: string
          p_courier_amount?: number
          p_courier_paid_by?: string
          p_courier_provider?: string
          p_courier_provider_id?: number
          p_created_by?: string
          p_customer_address?: string
          p_customer_address_parts?: Json
          p_customer_name?: string
          p_customer_notes?: string
          p_customer_phone?: string
          p_customer_secondary_phone?: string
          p_date?: string
          p_invoice_number?: string
          p_items?: Json
          p_meta?: Json
          p_notes?: string
          p_packing_amount?: number
          p_packing_paid_by?: string
          p_payment_method?: string
          p_payment_status?: string
          p_sale_channel?: string
          p_tenant_id: number
          p_total_invoice_amount?: number
        }
        Returns: Json
      }
      create_thrift_sales_return: {
        Args: {
          p_created_by?: string
          p_invoice_id: number
          p_items: Json
          p_notes?: string
          p_return_courier_amount?: number
          p_tenant_id: number
        }
        Returns: Json
      }
      create_vendor_with_wallet: {
        Args: {
          p_address?: string
          p_code: string
          p_email?: string
          p_market_code: string
          p_name: string
          p_phone?: string
          p_tenant_id: number
          p_website?: string
        }
        Returns: Json
      }
      current_authenticated_email: { Args: never; Returns: string }
      current_costing_item_actor_role: {
        Args: { p_costing_file_id: number }
        Returns: string
      }
      current_customer_group_id: {
        Args: { p_tenant_id: number }
        Returns: number
      }
      current_tenant_id: { Args: never; Returns: number }
      current_user_email: { Args: never; Returns: string }
      customer_can_select_shop: {
        Args: { p_shop_id: number; p_tenant_id: number }
        Returns: boolean
      }
      customer_confirm_shop_order: {
        Args: { p_order_id: number }
        Returns: undefined
      }
      customer_counter_offer: {
        Args: { p_items: Json; p_order_id: number }
        Returns: undefined
      }
      default_pickable_stock_location_id: {
        Args: { p_tenant_id: number }
        Returns: number
      }
      default_putaway_stock_location_id: {
        Args: { p_tenant_id: number }
        Returns: number
      }
      default_returns_stock_location_id: {
        Args: { p_tenant_id: number }
        Returns: number
      }
      default_stock_grade_tag_id: { Args: never; Returns: number }
      delete_customer_group_member_grant: {
        Args: { p_action: string; p_cgm_id: number; p_module_key: string }
        Returns: undefined
      }
      delete_global_shipment_cost_entry: {
        Args: { p_id: number }
        Returns: undefined
      }
      delete_global_stock_allocation: {
        Args: { p_allocation_id: number }
        Returns: undefined
      }
      delete_membership_grant: {
        Args: {
          p_action: string
          p_membership_id: number
          p_module_key: string
        }
        Returns: undefined
      }
      delete_shipment: { Args: { p_id: number }; Returns: undefined }
      delete_shipment_item_quantity: {
        Args: { p_id: number; p_quantity: number }
        Returns: boolean
      }
      delete_shipment_order: { Args: { p_id: number }; Returns: undefined }
      delete_shop: {
        Args: { p_shop_id: number; p_tenant_id: number }
        Returns: undefined
      }
      delete_shop_order: { Args: { p_order_id: number }; Returns: undefined }
      delete_shop_product_listing: {
        Args: { p_listing_id: number; p_tenant_id: number }
        Returns: boolean
      }
      delete_stock_location: { Args: { p_id: number }; Returns: undefined }
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
      delete_tenant_role: { Args: { p_role_id: number }; Returns: undefined }
      delete_thrift_stocks: {
        Args: { p_stock_ids: number[]; p_tenant_id: number }
        Returns: Json
      }
      dispense_middleman_payout: {
        Args: {
          p_amount: number
          p_billing_profile_id: number
          p_method?: string
          p_trx_id?: string
        }
        Returns: Json
      }
      dispense_middleman_payout_from_tenant: {
        Args: {
          p_amount: number
          p_billing_profile_id: number
          p_payout_method?: string
          p_reference_notes?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      ensure_default_cargo_company: {
        Args: { p_tenant_id: number }
        Returns: number
      }
      ensure_default_stock_location: {
        Args: { p_tenant_id: number }
        Returns: number
      }
      ensure_default_vendor: { Args: { p_tenant_id: number }; Returns: number }
      ensure_dropship_invoice_billed_entry: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      ensure_global_shipment_cost_entries_from_header: {
        Args: { p_shipment_id: number }
        Returns: undefined
      }
      ensure_shipment_progress_tags: {
        Args: { p_tenant_id: number }
        Returns: {
          category_id: number | null
          color: string
          created_at: string
          created_by_email: string
          group_name: string | null
          id: number
          is_active: boolean
          is_system: boolean
          metadata: Json
          name: string
          slug: string
          sort_order: number | null
          tenant_id: number | null
          type: string
        }[]
        SetofOptions: {
          from: "*"
          to: "tags"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      fetch_customer_shop_categories: {
        Args: { p_tenant_id: number }
        Returns: {
          count: number
          name: string
        }[]
      }
      finalize_dropship_return: {
        Args: {
          p_actual_return_charge?: number
          p_deduct_from_middle_man?: boolean
          p_items: Json
          p_order_id: number
          p_override_reason?: string
          p_return_ref?: string
        }
        Returns: Json
      }
      finalize_global_shipment: {
        Args: { p_shipment_id: number; p_stock_rows?: Json }
        Returns: Json
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
      fulfill_shop_order_to_invoice: {
        Args: { p_order_id: number }
        Returns: undefined
      }
      generate_sales_invoice_number: {
        Args: {
          p_date?: string
          p_invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          p_tenant_id: number
        }
        Returns: string
      }
      generate_shipment_tracking_token: {
        Args: { p_shipment_id: number }
        Returns: string
      }
      generate_shop_order_number: {
        Args: { p_shop_id: number; p_tenant_id: number }
        Returns: string
      }
      generate_thrift_barcodes: {
        Args: { p_inserted_by: string; p_quantity: number; p_tenant_id: number }
        Returns: string[]
      }
      generate_thrift_invoice_number: {
        Args: { p_date?: string; p_tenant_id: number }
        Returns: string
      }
      generate_thrift_return_number: {
        Args: { p_date?: string; p_tenant_id: number }
        Returns: string
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
          effective_grants: Json
          is_admin: boolean
          member_email: string
          member_id: number
          member_is_active: boolean
          member_preference: Json
          member_role: Database["public"]["Enums"]["app_role"]
          permission_version: number
          tenant_id: number
          tenant_is_active: boolean
          tenant_name: string
          tenant_preference: Json
          tenant_role_id: number
          tenant_slug: string
        }[]
      }
      get_available_stock: {
        Args: { p_stock_id: number; p_tenant_id: number }
        Returns: number
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
      get_courier_unremitted_financial_summary: {
        Args: { p_tenant_id: number }
        Returns: {
          company_wholesale_total: number
          courier_name: string
          courier_service_id: string
          gross_cod_total: number
          middleman_margin_total: number
          order_count: number
        }[]
      }
      get_customer_dashboard_summary: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      get_customer_shop_order: {
        Args: { p_order_id: number; p_tenant_id: number }
        Returns: Json
      }
      get_customer_dashboard_summary: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      get_dropship_finance_hub_data: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      get_dropship_shop_readiness: {
        Args: { p_shop_id: number }
        Returns: {
          has_access_group_with_price: boolean
          has_active_courier: boolean
          has_billing_profile_linked: boolean
          has_customer_group_with_members: boolean
          has_listing_with_floor: boolean
          ready: boolean
          shop_id: number
        }[]
      }
      get_dropship_wallet_reconciliation_report: {
        Args: { p_tenant_id?: number }
        Returns: Json
      }
      get_effective_grants: {
        Args: { p_tenant_id: number }
        Returns: {
          action: string
          module_key: string
        }[]
      }
      get_effective_item_role: {
        Args: { p_item_id: number; p_user_email: string }
        Returns: string
      }
      get_investor_allocation_detail: {
        Args: {
          p_global_shipment_id: number
          p_investor_id: number
          p_tenant_id: number
        }
        Returns: Json
      }
      get_investor_bootstrap_context: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      get_investor_capital_report: {
        Args: {
          p_end_date: string
          p_investor_id: number
          p_start_date: string
          p_tenant_id: number
        }
        Returns: Json
      }
      get_investor_dashboard_summary: {
        Args: { p_investor_id: number; p_tenant_id: number }
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
      get_my_dropship_wallet_summary: {
        Args: never
        Returns: {
          available_balance: number
          billing_profile_id: number
          currency: string
          locked_balance: number
          pending_balance: number
        }[]
      }
      get_or_create_shop_cart: { Args: { p_shop_id: number }; Returns: Json }
      get_parent_cash_circulation: {
        Args: { p_parent_tenant_id: number }
        Returns: Json
      }
      get_payee_settlement_summary: {
        Args: {
          p_entity_id: number
          p_entity_type: string
          p_shipment_id: number
          p_tenant_id: number
        }
        Returns: Json
      }
      get_pending_order_qty: {
        Args: { p_allocation_id: number }
        Returns: number
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
          inserted_by_tenant_id: number | null
          is_available: boolean | null
          languages: string | null
          list_price_amount: number | null
          list_price_currency_id: number | null
          market_code: string | null
          minimum_order_quantity: number | null
          name: string | null
          package_weight: number | null
          parent_tenant_id: number | null
          product_code: string | null
          product_weight: number | null
          reference_cost_amount: number | null
          reference_cost_currency_id: number | null
          source: string | null
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
      get_recipient_profile_by_phone: {
        Args: { p_phone: string; p_tenant_id: number }
        Returns: Json
      }
      get_shipment_overview_details: {
        Args: { p_shipment_id: number }
        Returns: Json
      }
      get_shipment_pnl: {
        Args: { p_shipment_id: number; p_tenant_id: number }
        Returns: Json
      }
      get_shipment_public_status: { Args: { p_token: string }; Returns: Json }
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
          effective_grants: Json
          is_admin: boolean
          member_email: string
          member_id: number
          member_is_active: boolean
          member_name: string
          member_role: Database["public"]["Enums"]["customer_group_role"]
          permission_version: number
          tenant_id: number
          tenant_is_active: boolean
          tenant_name: string
          tenant_role_id: number
          tenant_slug: string
        }[]
      }
      get_shop_catalog_product_for_customer: {
        Args: { p_product_id: number; p_shop_slug: string; p_tenant_id: number }
        Returns: Json
      }
      get_shop_effective_grants: {
        Args: { p_customer_group_member_id: number; p_tenant_id: number }
        Returns: {
          action: string
          module_key: string
        }[]
      }
      get_shop_order_for_staff: {
        Args: { p_order_id: number; p_tenant_id: number }
        Returns: Json
      }
      get_shop_permissions_for_customer: {
        Args: { p_shop_id: number }
        Returns: {
          can_add_to_cart: boolean
          can_browse: boolean
          can_negotiate: boolean
          can_place_order: boolean
          can_see_buy_price: boolean
          can_see_resell_minimum_price: boolean
          can_see_sell_price: boolean
          can_set_dropship_price: boolean
          can_view_quantity: boolean
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
      get_tag_by_slug: {
        Args: {
          p_category_id?: number
          p_code?: string
          p_module_key?: string
          p_slug?: string
        }
        Returns: Json
      }
      get_tenant_cash_in_report: {
        Args: {
          p_end_date?: string
          p_start_date?: string
          p_tenant_id: number
        }
        Returns: Json
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
      get_tenant_permission_version: {
        Args: { p_tenant_id: number }
        Returns: number
      }
      get_tenant_role_detail: { Args: { p_role_id: number }; Returns: Json }
      get_thrift_customer_sales_risk: {
        Args: { p_phone: string; p_tenant_id: number }
        Returns: Json
      }
      get_thrift_dashboard_metrics: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      get_thrift_sales_report: {
        Args: {
          p_date_from: string
          p_date_to: string
          p_outcome?: string
          p_sale_channel?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      get_thrift_shipment_sales_report: {
        Args: { p_shipment_id: number; p_tenant_id: number }
        Returns: Json
      }
      get_vendor_for_tenant: {
        Args: { p_id: number; p_tenant_id: number }
        Returns: {
          address: string | null
          code: string
          created_at: string
          email: string | null
          id: number
          is_default: boolean
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
      get_wallet_account_balances: {
        Args: {
          p_currency_code?: string
          p_entity_id: number
          p_entity_type: string
          p_tenant_id: number
        }
        Returns: Json
      }
      get_wallet_dashboard_summary: {
        Args: { p_tenant_id: number }
        Returns: Json
      }
      get_wallet_entity_statement: {
        Args: {
          p_end_date?: string
          p_entity_id: number
          p_entity_type: string
          p_start_date?: string
          p_tenant_id: number
        }
        Returns: Json
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
      global_stock_atp_qty: {
        Args: { p_global_stock_id: number }
        Returns: number
      }
      global_stock_hold_qty: {
        Args: { p_global_stock_id: number }
        Returns: number
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
      has_module_action: {
        Args: { p_action: string; p_module_key: string; p_tenant_id: number }
        Returns: boolean
      }
      hold_thrift_stock: {
        Args: {
          p_held_by?: string
          p_held_for_name?: string
          p_held_for_phone: string
          p_hold_expires_at?: string
          p_hold_note?: string
          p_stock_id: number
          p_tenant_id: number
        }
        Returns: Json
      }
      investor_tenant_can_view: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      is_assigned_costing_file_viewer: {
        Args: { p_costing_file_id: number }
        Returns: boolean
      }
      is_cart_owner: {
        Args: { p_customer_group_id: number; p_tenant_id: number }
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
      issue_wholesale_invoice: {
        Args: { p_invoice_id: number; p_items?: Json }
        Returns: {
          billing_profile_id: number | null
          collection_source: Database["public"]["Enums"]["collection_source_type"]
          created_at: string
          created_by: string | null
          discount_amount: number
          due_amount: number
          due_date: string | null
          fulfillment_status: Database["public"]["Enums"]["global_fulfillment_status"]
          id: number
          invoice_date: string
          invoice_no: string
          invoice_status: Database["public"]["Enums"]["global_invoice_status"]
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          issued_by_tenant_id: number
          note: string | null
          paid_amount: number
          parent_tenant_id: number
          payment_status: string
          print_charge: number
          recipient_address: string | null
          recipient_name: string | null
          recipient_phone: string | null
          recipient_profile_id: number | null
          retail_billing_mode:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount: number
          shipping_charge: number
          subtotal_amount: number
          total_amount: number
          updated_at: string
          wrapping_charge: number
        }
        SetofOptions: {
          from: "*"
          to: "sales_invoices"
          isOneToOne: true
          isSetofReturn: false
        }
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
      list_allocations_for_shop_pick:
        | { Args: { p_search?: string; p_shop_id: number }; Returns: Json }
        | {
            Args: { p_shop_id: number; p_tenant_id: number }
            Returns: {
              allocated_quantity: number
              allocation_id: number
              minimum_sell_price_amount: number
              minimum_sell_price_currency_id: number
              product_barcode: string
              product_brand: string
              product_category: string
              product_code: string
              product_id: number
              product_image_url: string
              product_name: string
              shipment_id: number
              shipment_item_id: number
              stock_id: number
              unit_cost_amount: number
            }[]
          }
      list_cgm_ids_with_overrides: {
        Args: { p_customer_group_id: number }
        Returns: {
          customer_group_member_id: number
        }[]
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
      list_child_stock_atp: {
        Args: {
          p_child_tenant_id: number
          p_limit?: number
          p_offset?: number
          p_search?: string
        }
        Returns: Json
      }
      list_child_tenant_ids: {
        Args: { p_parent_tenant_id: number }
        Returns: number[]
      }
      list_child_tenant_refs: {
        Args: { p_parent_tenant_ids: number[] }
        Returns: {
          id: number
          parent_id: number
        }[]
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
      list_configurable_module_actions: {
        Args: { p_scope: string; p_tenant_id: number }
        Returns: {
          action: string
          description: string
          id: number
          is_active: boolean
          module_key: string
          scope: string
          tenant_configurable: boolean
        }[]
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
      list_customer_accounts: {
        Args: { p_search?: string; p_tenant_id: number }
        Returns: {
          accent_color: string
          address: string
          admin_name: string
          billing_profile_id: number
          created_at: string
          customer_group_id: number
          email: string
          group_name: string
          id: number
          is_active: boolean
          member_count: number
          phone: string
          wallet_available_balance: number
        }[]
      }
      list_customer_active_carts: {
        Args: { p_tenant_id: number }
        Returns: {
          can_see_buy_price: boolean
          can_see_sell_price: boolean
          cart_id: number
          cart_total: number
          currency_code: string
          currency_id: number
          currency_symbol: string
          item_count: number
          shop_id: number
          shop_logo_url: string
          shop_name: string
          shop_slug: string
          shop_type: string
          updated_at: string
        }[]
      }
      list_customer_group_member_grants: {
        Args: { p_cgm_id: number }
        Returns: {
          action: string
          customer_group_member_id: number
          effect: string
          id: number
          module_key: string
        }[]
      }
      list_customer_order_backlog_items: {
        Args: { p_billing_profile_id: number; p_tenant_id: number }
        Returns: {
          backlog_status: string
          barcode: string
          billing_profile_id: number
          created_at: string
          fulfilled_quantity: number
          id: number
          image_url: string
          name: string
          open_quantity: number
          order_id: number
          order_item_id: number
          product_code: string
          product_id: number
          requested_quantity: number
          tenant_id: number
        }[]
      }
      list_customer_shop_orders: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_status_bucket?: string
          p_tenant_id: number
        }
        Returns: {
          can_see_buy_price: boolean
          can_see_sell_price: boolean
          created_at: string
          currency_symbol: string
          id: number
          item_count: number
          order_no: string
          sell_currency_id: number
          shop_id: number
          shop_name: string
          shop_slug: string
          shop_type_snapshot: Database["public"]["Enums"]["shop_type_enum"]
          status: Database["public"]["Enums"]["shop_order_status"]
          total_amount: number
        }[]
      }
      list_customer_shops: {
        Args: { p_tenant_id: number }
        Returns: {
          can_see_buy_price: boolean
          can_see_sell_price: boolean
          categories: Json
          category_ids: number[]
          description: string
          id: number
          is_negotiable: boolean
          name: string
          order_mode: Database["public"]["Enums"]["shop_order_mode_enum"]
          sell_currency_code: string
          sell_currency_id: number
          sell_currency_symbol: string
          shop_type: Database["public"]["Enums"]["shop_type_enum"]
          slug: string
          tenant_id: number
        }[]
      }
      list_demand_bucket_items: {
        Args: {
          p_billing_profile_id: number
          p_limit?: number
          p_offset?: number
          p_status?: Database["public"]["Enums"]["demand_bucket_status"]
          p_tenant_id: number
        }
        Returns: {
          barcode: string
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string
          name: string
          note: string
          popped_at: string
          popped_into_id: number
          popped_into_type: string
          product_code: string
          product_id: number
          quantity: number
          source_id: number
          source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          status: Database["public"]["Enums"]["demand_bucket_status"]
          tenant_id: number
          updated_at: string
        }[]
      }
      list_dropship_shop_orders_for_staff: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_status?: string
          p_tenant_id: number
        }
        Returns: {
          cod_collect_amount: number
          collection_source: Database["public"]["Enums"]["collection_source_type"]
          courier_awb_number: string
          courier_name: string
          courier_remittance_ref: string
          created_at: string
          created_by_email: string
          customer_group_name: string
          global_invoice_id: number
          id: number
          order_no: string
          payout_settlement_status: string
          recipient_name: string
          recipient_phone: string
          status: Database["public"]["Enums"]["shop_order_status"]
          total_amount: number
        }[]
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
      list_global_invoice_items: {
        Args: { p_invoice_id: number }
        Returns: {
          available_atp: number
          cargo_conversion_rate: number
          cargo_rate: number
          global_stock_id: number
          id: number
          image_url: string
          invoice_id: number
          line_discount_amount: number
          line_face_total_amount: number
          line_total_amount: number
          name_snapshot: string
          ordered_quantity: number
          package_weight: number
          product_conversion_rate: number
          product_weight: number
          purchase_price: number
          quantity: number
          received_weight: number
          recipient_price_amount: number
          return_quantity: number
          sell_price_amount: number
          shipment_id: number
          shipment_item_id: number
          shipment_type: string
          transaction_rate: number
          unit_cost_price: number
        }[]
      }
      list_global_shipment_cost_entries: {
        Args: { p_shipment_id: number }
        Returns: {
          allocation: string | null
          amount: number
          cost_type: Database["public"]["Enums"]["global_shipment_cost_type"]
          created_at: string
          currency_id: number | null
          entity_id: number | null
          entity_type: string | null
          exchange_rate: number
          id: number
          metadata: Json
          parent_tenant_id: number
          payment_source: string | null
          section_id: number | null
          settled_at: string | null
          settlement_ledger_id: string | null
          shipment_id: number
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "global_shipment_cost_entries"
          isOneToOne: false
          isSetofReturn: true
        }
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
      list_global_stocks_paginated:
        | {
            Args: {
              p_availability?: Database["public"]["Enums"]["stock_availability"]
              p_hide_zero_stock?: boolean
              p_is_sellable?: boolean
              p_location_id?: number
              p_page?: number
              p_page_size?: number
              p_search?: string
              p_shipment_status?: string
              p_stock_type_id?: number
              p_tenant_id: number
            }
            Returns: Json
          }
        | {
            Args: {
              p_availability?: Database["public"]["Enums"]["stock_availability"]
              p_hide_zero_stock?: boolean
              p_is_sellable?: boolean
              p_location_id?: number
              p_page?: number
              p_page_size?: number
              p_search?: string
              p_shipment_id?: number
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
      list_investor_allocations: {
        Args: {
          p_investor_id: number
          p_limit?: number
          p_offset?: number
          p_tenant_id: number
        }
        Returns: {
          allocated_cost: number
          computed_profit: number
          cost_share_pct: number
          created_at: string
          global_shipment_id: number
          id: number
          profit_status: string
          shipment_name: string
          shipment_status: string
          total_count: number
        }[]
      }
      list_investor_profiles: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_tenant_id: number
        }
        Returns: {
          address: string
          available_balance: number
          created_at: string
          currency_code: string
          deployed_capital: number
          email: string
          id: number
          is_active: boolean
          name: string
          notes: string
          phone: string
          tenant_id: number
          total_capital_in: number
          total_count: number
          total_withdrawn: number
          updated_at: string
        }[]
      }
      list_investor_transactions: {
        Args: {
          p_investor_id: number
          p_limit?: number
          p_offset?: number
          p_tenant_id: number
        }
        Returns: {
          amount: number
          created_at: string
          date: string
          id: number
          method: Database["public"]["Enums"]["investor_payment_method"]
          note: string
          total_count: number
          type: Database["public"]["Enums"]["investor_transaction_type"]
        }[]
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
      list_listable_stock_for_shop: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_shop_id: number
        }
        Returns: Json
      }
      list_membership_grants: {
        Args: { p_membership_id: number }
        Returns: {
          action: string
          created_at: string
          created_by_email: string
          effect: string
          id: number
          membership_id: number
          module_key: string
          updated_at: string
        }[]
      }
      list_membership_ids_with_overrides: {
        Args: { p_tenant_id: number }
        Returns: {
          membership_id: number
        }[]
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
      list_my_dropship_wallet_ledger: {
        Args: { p_limit?: number; p_offset?: number }
        Returns: {
          amount: number
          balance_after: number
          created_at: string
          id: string
          note: string
          order_id: number
          source_id: string
          transaction_type: string
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
      list_pbc_backlog_items: {
        Args: { p_billing_profile_id: number; p_tenant_id: number }
        Returns: {
          barcode: string
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string
          last_costing_file_id: number
          last_costing_item_id: number
          name: string
          note: string
          open_quantity: number
          package_weight: number
          price_gbp: number
          product_code: string
          product_id: number
          product_weight: number
          tenant_id: number
          updated_at: string
        }[]
      }
      list_procurement_demand_groups: {
        Args: {
          p_child_tenant_id?: number
          p_limit?: number
          p_offset?: number
          p_procurement_status?: string
          p_search?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_procurement_shop_order_lines: {
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
      list_related_shop_catalog_products_for_customer: {
        Args: {
          p_limit?: number
          p_product_id: number
          p_shop_slug: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_shipment_items_for_shipments: {
        Args: { p_shipment_ids: number[] }
        Returns: {
          ordered_quantity: number
          package_weight: number
          product_weight: number
          purchase_price: number
          shipment_id: number
        }[]
      }
      list_shipment_payee_settlements: {
        Args: { p_shipment_id: number }
        Returns: Json
      }
      list_shipment_progress_flow_stages: {
        Args: { p_flow_id: number; p_include_archived?: boolean }
        Returns: {
          color: string
          flow_id: number
          flow_stage_id: number
          is_active: boolean
          name: string
          slug: string
          sort_order: number
          tag_id: number
        }[]
      }
      list_shipment_progress_flows: {
        Args: { p_include_archived?: boolean; p_tenant_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          name: string
          slug: string
          stage_count: number
          tenant_id: number
        }[]
      }
      list_shipment_progress_tags: {
        Args: { p_include_archived?: boolean; p_tenant_id: number }
        Returns: {
          category_id: number | null
          color: string
          created_at: string
          created_by_email: string
          group_name: string | null
          id: number
          is_active: boolean
          is_system: boolean
          metadata: Json
          name: string
          slug: string
          sort_order: number | null
          tenant_id: number | null
          type: string
        }[]
        SetofOptions: {
          from: "*"
          to: "tags"
          isOneToOne: false
          isSetofReturn: true
        }
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
      list_shop_orders_for_staff: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_shop_id?: number
          p_status?: string
          p_tenant_id: number
        }
        Returns: {
          created_at: string
          customer_group_id: number
          customer_group_name: string
          id: number
          item_count: number
          name: string
          order_no: string
          shop_id: number
          shop_name: string
          status: Database["public"]["Enums"]["shop_order_status"]
          tenant_id: number
          updated_at: string
        }[]
      }
      list_shop_product_listings: {
        Args: { p_shop_id: number }
        Returns: {
          allocated_quantity: number
          available_to_sell: number
          created_at: string
          display_quantity_override: number
          global_stock_allocation_id: number
          global_stock_id: number
          id: number
          is_active: boolean
          minimum_sell_price_amount: number
          minimum_sell_price_currency_id: number
          product_barcode: string
          product_brand: string
          product_category: string
          product_code: string
          product_id: number
          product_image_url: string
          product_name: string
          sell_price_amount: number
          sell_price_currency_id: number
          shipment_id: number
          shipment_item_id: number
          shop_id: number
          show_quantity: boolean
          tenant_id: number
          unit_cost_amount: number
          updated_at: string
        }[]
      }
      list_shops: {
        Args: {
          p_active?: boolean
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_tenant_id: number
        }
        Returns: {
          allow_delivery: boolean
          buy_currency_id: number
          category_ids: number[]
          created_at: string
          deduct_charges_from_margin: boolean
          deduct_packing_from_margin: boolean
          deduct_print_from_margin: boolean
          default_currency_id: number
          default_packing_charge_amount: number
          default_print_charge_amount: number
          description: string
          global_stock_type_id: number
          id: number
          is_active: boolean
          is_negotiable: boolean
          markup_percentage: number
          name: string
          order_mode: Database["public"]["Enums"]["shop_order_mode_enum"]
          pricing_method: string
          quantity_display_mode: string
          sell_currency_id: number
          shop_type: Database["public"]["Enums"]["shop_type_enum"]
          show_stock_quantity: boolean
          slug: string
          tenant_id: number
          total_count: number
          updated_at: string
          vendor_code: string
          vendor_filters: Json
        }[]
      }
      list_stock_locations: {
        Args: { p_include_inactive?: boolean; p_parent_tenant_id: number }
        Returns: {
          code: string
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          is_pickable: boolean
          kind: Database["public"]["Enums"]["stock_location_kind"]
          name: string
          parent_location_id: number | null
          parent_tenant_id: number
          sort_order: number
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "stock_locations"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      list_stock_movements: {
        Args: { p_limit?: number; p_offset?: number; p_tenant_id: number }
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
      list_tag_categories: { Args: { p_module_key?: string }; Returns: Json }
      list_tags_for_category: {
        Args: { p_category_id?: number; p_code?: string; p_module_key?: string }
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
      list_tenant_role_grants: {
        Args: { p_tenant_role_id: number }
        Returns: {
          action: string
          allowed: boolean
          created_at: string
          id: number
          module_key: string
          tenant_role_id: number
          updated_at: string
          updated_by_email: string
        }[]
      }
      list_tenant_roles: {
        Args: { p_scope: string; p_tenant_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          is_admin: boolean
          is_system: boolean
          name: string
          scope: string
          slug: string
          source_app_role: Database["public"]["Enums"]["app_role"]
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
      list_thrift_sales_invoices_paginated: {
        Args: {
          p_delivery_status?: string
          p_page?: number
          p_page_size?: number
          p_payment_status?: string
          p_search?: string
          p_status?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      list_thrift_sales_returns_paginated: {
        Args: {
          p_date_from?: string
          p_date_to?: string
          p_has_damaged?: boolean
          p_invoice_id?: number
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_skip_count?: boolean
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
          is_default: boolean
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
      mark_dropship_order_returned: {
        Args: {
          p_actual_return_charge: number
          p_deduct_from_middle_man: boolean
          p_order_id: number
          p_reason?: string
        }
        Returns: Json
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
      membership_has_module_action: {
        Args: { p_action: string; p_module_key: string; p_tenant_id: number }
        Returns: boolean
      }
      migrate_legacy_inventory_to_global_stock: {
        Args: { p_tenant_id?: number }
        Returns: Json
      }
      next_tenant_scoped_counter: {
        Args: { p_scope: string; p_tenant_id: number }
        Returns: number
      }
      normalize_bd_mobile: { Args: { p_phone: string }; Returns: string }
      normalize_thrift_phone: { Args: { p_phone: string }; Returns: string }
      parent_tenant_has_module_action: {
        Args: {
          p_action: string
          p_module_key: string
          p_parent_tenant_id: number
        }
        Returns: boolean
      }
      pay_settle_shipment_costs: {
        Args: { p_cost_entry_ids?: number[]; p_shipment_id: number }
        Returns: Json
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
      place_shop_order_for_procurement: {
        Args: { p_order_id: number }
        Returns: undefined
      }
      pop_demand_bucket_item: {
        Args: {
          p_bucket_item_id: number
          p_popped_into_id: number
          p_popped_into_type: string
        }
        Returns: {
          barcode: string | null
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string | null
          name: string
          note: string | null
          popped_at: string | null
          popped_into_id: number | null
          popped_into_type: string | null
          product_code: string | null
          product_id: number
          quantity: number
          source_id: number | null
          source_type: Database["public"]["Enums"]["demand_bucket_source_type"]
          status: Database["public"]["Enums"]["demand_bucket_status"]
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "customer_demand_bucket_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      pop_demand_bucket_items: {
        Args: {
          p_bucket_item_ids: number[]
          p_popped_into_id: number
          p_popped_into_type: string
        }
        Returns: Json
      }
      post_global_invoice: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      post_sales_invoice: { Args: { p_invoice_id: number }; Returns: undefined }
      post_stock_movement: { Args: { p_movement_id: number }; Returns: Json }
      process_courier_bulk_remittance_batch: {
        Args: { p_batch_id: number }
        Returns: Json
      }
      process_dropship_courier_remittance_uwl: {
        Args: {
          p_courier_charge?: number
          p_net_amount: number
          p_order_id: number
          p_remittance_ref?: string
        }
        Returns: undefined
      }
      process_dropship_shop_order: {
        Args: { p_order_id: number }
        Returns: Json
      }
      process_wholesale_invoice_return: {
        Args: {
          p_invoice_id: number
          p_items: Json
          p_note?: string
          p_payout_account_id?: number
          p_refund_method?: string
          p_return_charge_amount?: number
        }
        Returns: Json
      }
      purge_popped_demand_bucket_items: {
        Args: { p_retention_days?: number; p_tenant_id: number }
        Returns: Json
      }
      recalculate_product_based_costing_file_offer_prices: {
        Args: { p_file_id: number }
        Returns: undefined
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
      reconcile_single_order_remittance: {
        Args: { p_courier_charge?: number; p_order_id: number }
        Returns: Json
      }
      record_dropship_courier_remittance:
        | {
            Args: {
              p_bank_trx_id?: string
              p_method?: string
              p_net_amount: number
              p_note?: string
              p_order_id: number
              p_payment_date?: string
              p_remittance_ref: string
            }
            Returns: Json
          }
        | {
            Args: {
              p_bank_trx_id?: string
              p_courier_charge?: number
              p_method?: string
              p_net_amount: number
              p_note?: string
              p_order_id: number
              p_payment_date?: string
              p_remittance_ref: string
            }
            Returns: Json
          }
      record_investor_capital_adjustment: {
        Args: {
          p_amount: number
          p_date: string
          p_investor_id: number
          p_method: Database["public"]["Enums"]["investor_payment_method"]
          p_note: string
          p_tenant_id: number
        }
        Returns: {
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
        SetofOptions: {
          from: "*"
          to: "investor_transactions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      record_investor_capital_in: {
        Args: {
          p_amount: number
          p_date: string
          p_investor_id: number
          p_method: Database["public"]["Enums"]["investor_payment_method"]
          p_note: string
          p_tenant_id: number
        }
        Returns: {
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
        SetofOptions: {
          from: "*"
          to: "investor_transactions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      record_investor_withdrawal_paid: {
        Args: {
          p_amount: number
          p_date: string
          p_investor_id: number
          p_method: Database["public"]["Enums"]["investor_payment_method"]
          p_note: string
          p_tenant_id: number
        }
        Returns: {
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
        SetofOptions: {
          from: "*"
          to: "investor_transactions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      record_ledger_transaction: {
        Args: {
          p_allow_overdraft?: boolean
          p_amount: number
          p_currency_code?: string
          p_entity_id: number
          p_entity_type: string
          p_exchange_rate?: number
          p_metadata?: Json
          p_source_id?: string
          p_source_type?: string
          p_target_bucket?: string
          p_tenant_id: number
          p_type: string
        }
        Returns: Json
      }
      record_recipient_invoice_collection: {
        Args: {
          p_amount: number
          p_global_invoice_id: number
          p_method?: string
          p_note?: string
          p_payment_date?: string
          p_reference?: string
        }
        Returns: {
          billing_profile_id: number | null
          collection_source: Database["public"]["Enums"]["collection_source_type"]
          created_at: string
          created_by: string | null
          discount_amount: number
          due_amount: number
          due_date: string | null
          fulfillment_status: Database["public"]["Enums"]["global_fulfillment_status"]
          id: number
          invoice_date: string
          invoice_no: string
          invoice_status: Database["public"]["Enums"]["global_invoice_status"]
          invoice_type: Database["public"]["Enums"]["global_invoice_type"]
          issued_by_tenant_id: number
          note: string | null
          paid_amount: number
          parent_tenant_id: number
          payment_status: string
          print_charge: number
          recipient_address: string | null
          recipient_name: string | null
          recipient_phone: string | null
          recipient_profile_id: number | null
          retail_billing_mode:
            | Database["public"]["Enums"]["retail_billing_mode"]
            | null
          settlement_discount_amount: number
          shipping_charge: number
          subtotal_amount: number
          total_amount: number
          updated_at: string
          wrapping_charge: number
        }
        SetofOptions: {
          from: "*"
          to: "sales_invoices"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      record_thrift_cod_remittance: {
        Args: {
          p_actor: string
          p_invoice_id: number
          p_notes?: string
          p_outcome?: string
          p_remittance_ref?: string
          p_remitted_amount: number
          p_remitted_at?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      record_vendor_grn_payable: {
        Args: {
          p_amount: number
          p_metadata?: Json
          p_source_id: string
          p_tenant_id: number
          p_vendor_id: number
        }
        Returns: Json
      }
      record_vendor_payment_outflow: {
        Args: {
          p_amount: number
          p_note?: string
          p_payment_method?: string
          p_reference?: string
          p_tenant_id: number
          p_vendor_id: number
        }
        Returns: Json
      }
      refresh_commerce_inventory_product_summaries: {
        Args: { p_tenant_id?: number }
        Returns: undefined
      }
      refresh_commerce_inventory_product_summary_single: {
        Args: { p_product_id: number; p_tenant_id: number }
        Returns: undefined
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
        Args: { p_global_shipment_id: number }
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
              p_extra_origin_purchase_expense?: number
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
      release_thrift_stock_hold: {
        Args: { p_stock_id: number; p_tenant_id: number }
        Returns: Json
      }
      remove_global_invoice_item: {
        Args: { p_invoice_item_id: number }
        Returns: undefined
      }
      remove_shop_cart_item: { Args: { p_cart_item_id: number }; Returns: Json }
      reorder_shipment_progress_flow_stages: {
        Args: { p_flow_id: number; p_flow_stage_ids: number[] }
        Returns: undefined
      }
      reorder_shipment_progress_tags: {
        Args: { p_tag_ids: number[]; p_tenant_id: number }
        Returns: undefined
      }
      reorder_shipment_sections: {
        Args: { p_section_ids: number[]; p_shipment_id: number }
        Returns: undefined
      }
      resolve_billing_profile_for_customer_group: {
        Args: { p_customer_group_id: number; p_tenant_id: number }
        Returns: number
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
      return_shipment_to_vendor: {
        Args: { p_items_qty: Json; p_outcome: string; p_shipment_id: number }
        Returns: Json
      }
      revert_thrift_sales_invoice: {
        Args: {
          p_force?: boolean
          p_invoice_id: number
          p_notes?: string
          p_reason: string
          p_return_courier_amount?: number
          p_reverted_by?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      revise_global_shipment_costs: {
        Args: { p_entries: Json; p_shipment_id: number }
        Returns: Json
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
      revoke_shipment_tracking_token: {
        Args: { p_shipment_id: number }
        Returns: undefined
      }
      round_bdt_up_to_zero_or_five: {
        Args: { p_value: number }
        Returns: number
      }
      search_sales_invoice_stock: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_tenant_id: number
        }
        Returns: {
          allocation_rank: number
          available_atp: number
          barcode: string
          global_stock_id: number
          holding_tenant_id: number
          holding_tenant_name: string
          image_url: string
          is_allocated_to_tenant: boolean
          location_id: number
          location_name: string
          name: string
          product_code: string
          product_id: number
          quantity: number
          shipment_id: number
          shipment_item_id: number
          shipment_name: string
          stock_created_at: string
          suggested_sell_price: number
          unit_cost_price: number
        }[]
      }
      search_shop_catalog_for_customer: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_tenant_id: number
        }
        Returns: Json
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
          available_atp: number
          barcode: string
          box_damage_qty: number
          box_less_qty: number
          cargo_conversion_rate: number
          cargo_rate: number
          excellent_qty: number
          expired_qty: number
          global_qty: number
          global_stock_id: number
          holding_tenant_id: number
          holding_tenant_name: string
          image_url: string
          is_own_tenant: boolean
          is_pickable: boolean
          location_id: number
          location_name: string
          name: string
          ordered_quantity: number
          package_weight: number
          parent_tenant_id: number
          product_code: string
          product_conversion_rate: number
          product_group_key: string
          product_id: number
          product_weight: number
          purchase_price: number
          received_weight: number
          reserved_qty: number
          shipment_id: number
          shipment_item_id: number
          shipment_name: string
          shipment_type: string
          sort_rank: number
          stolen_qty: number
          total_qty: number
          transaction_rate: number
        }[]
      }
      search_thrift_available_stocks_for_sale: {
        Args: {
          p_customer_phone?: string
          p_limit?: number
          p_search?: string
          p_tenant_id: number
        }
        Returns: Json
      }
      seed_tenant_roles_and_grants: {
        Args: { p_tenant_id: number }
        Returns: undefined
      }
      set_default_shipment_progress_flow: {
        Args: { p_flow_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          name: string
          slug: string
          tenant_id: number
        }
        SetofOptions: {
          from: "*"
          to: "shipment_progress_flows"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      set_default_stock_location: {
        Args: { p_id: number }
        Returns: {
          code: string
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          is_pickable: boolean
          kind: Database["public"]["Enums"]["stock_location_kind"]
          name: string
          parent_location_id: number | null
          parent_tenant_id: number
          sort_order: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "stock_locations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      set_global_shipment_progress_tag: {
        Args: { p_shipment_id: number; p_tag_id?: number }
        Returns: Json
      }
      set_shipment_progress_flow: {
        Args: { p_flow_id: number; p_shipment_id: number }
        Returns: Json
      }
      set_shipment_progress_stage: {
        Args: { p_shipment_id: number; p_tag_id?: number }
        Returns: Json
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
      settle_shipment_payee: {
        Args: {
          p_action: string
          p_amount: number
          p_entity_id: number
          p_entity_type: string
          p_exchange_rate?: number
          p_shipment_id: number
        }
        Returns: Json
      }
      show_limit: { Args: never; Returns: number }
      show_trgm: { Args: { "": string }; Returns: string[] }
      staff_counter_offer: {
        Args: { p_items: Json; p_order_id: number }
        Returns: undefined
      }
      staff_finalize_catalog_prices: {
        Args: { p_items: Json; p_order_id: number }
        Returns: Json
      }
      staff_price_shop_order: {
        Args: {
          p_cargo_rate?: number
          p_fx_rate?: number
          p_items: Json
          p_order_id: number
          p_profit_basis?: string
          p_profit_pct?: number
        }
        Returns: Json
      }
      staff_set_catalog_delivered_qty: {
        Args: { p_items?: Json; p_order_id: number }
        Returns: Json
      }
      staff_set_catalog_ordered_qty: {
        Args: { p_items: Json; p_order_id: number }
        Returns: Json
      }
      staff_start_catalog_procurement: {
        Args: { p_order_id: number }
        Returns: Json
      }
      staff_update_catalog_order_item_for_staff: {
        Args: {
          p_item_id: number
          p_order_id: number
          p_payload: Json
          p_tenant_id: number
        }
        Returns: Json
      }
      stamp_global_shipment_landed_costs: {
        Args: { p_shipment_id: number }
        Returns: number
      }
      stock_grade_tag_id_for_slug: { Args: { p_slug: string }; Returns: number }
      submit_shop_order_from_cart:
        | {
            Args: {
              p_billing_profile_id?: number
              p_cart_id: number
              p_cod_charge_amount?: number
              p_delivery_charge_amount?: number
              p_delivery_instructions?: string
              p_discount_amount?: number
              p_is_prepaid?: boolean
              p_packing_charge_amount?: number
              p_print_charge_amount?: number
              p_recipient_name: string
              p_recipient_phone: string
              p_shipping_address: string
            }
            Returns: Json
          }
        | {
            Args: {
              p_billing_profile_id?: number
              p_cart_id: number
              p_cod_charge_amount?: number
              p_delivery_charge_amount?: number
              p_delivery_instructions?: string
              p_discount_amount?: number
              p_is_prepaid?: boolean
              p_packing_charge_amount?: number
              p_print_charge_amount?: number
              p_recipient_name: string
              p_recipient_phone: string
              p_recipient_phone_secondary?: string
              p_shipping_address: string
              p_shipping_district?: string
              p_shipping_thana?: string
            }
            Returns: Json
          }
      thrift_barcode_sequence_sort_key: {
        Args: { p_barcode_id: string }
        Returns: {
          sort_prefix: string
          sort_seq: number
          sort_year: string
        }[]
      }
      transfer_wallet_balance: {
        Args: {
          p_amount: number
          p_currency_code?: string
          p_entity_id: number
          p_entity_type: string
          p_from_bucket: string
          p_metadata?: Json
          p_notes?: string
          p_tenant_id: number
          p_to_bucket: string
        }
        Returns: Json
      }
      unpost_global_invoice: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      unpost_sales_invoice: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      update_catalog_order_item_for_staff: {
        Args: {
          p_item_id: number
          p_order_id: number
          p_payload: Json
          p_tenant_id: number
        }
        Returns: Json
      }
      update_catalog_order_rates_for_staff: {
        Args: { p_order_id: number; p_payload: Json; p_tenant_id: number }
        Returns: Json
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
      update_dropship_consignment: {
        Args: {
          p_allow_open_box?: boolean
          p_cod_charge_amount?: number
          p_cod_collect_amount?: number
          p_courier_awb_number?: string
          p_courier_consignment_id?: string
          p_courier_cost_amount?: number
          p_courier_order_ref?: string
          p_courier_service_id?: string
          p_courier_tracking_number?: string
          p_delivery_charge_amount?: number
          p_delivery_instruction_notes?: string
          p_delivery_zone?: string
          p_item_category?: string
          p_order_id: number
          p_package_weight_band?: string
          p_parcel_description?: string
          p_payout_account_info?: string
          p_payout_account_type?: string
          p_pickup_address?: string
          p_pickup_phone?: string
          p_recipient_name?: string
          p_recipient_phone?: string
          p_recipient_phone_secondary?: string
          p_sender_name?: string
          p_shipping_address?: string
          p_shipping_district?: string
          p_shipping_thana?: string
          p_tracking_url?: string
        }
        Returns: Json
      }
      update_global_invoice_header: {
        Args: {
          p_cod_charge?: number
          p_discount_amount?: number
          p_invoice_date?: string
          p_invoice_id: number
          p_invoice_no?: string
          p_note?: string
          p_print_charge?: number
          p_recipient_address?: string
          p_recipient_name?: string
          p_recipient_phone?: string
          p_shipping_charge?: number
          p_wrapping_charge?: number
        }
        Returns: undefined
      }
      update_global_invoice_item: {
        Args: {
          p_item_id: number
          p_quantity: number
          p_recipient_price_amount?: number
          p_sell_price_amount: number
        }
        Returns: {
          assigned_child_tenant_id: number | null
          barcode_snapshot: string | null
          created_at: string
          global_stock_id: number
          id: number
          invoice_id: number
          line_discount_amount: number
          line_total_amount: number
          name_snapshot: string
          parent_tenant_id: number
          product_code_snapshot: string | null
          product_id: number | null
          quantity: number
          return_quantity: number
          sell_price_amount: number
          shipment_item_id: number | null
          unit_cost_price: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "sales_invoice_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_global_shipment_items_order: {
        Args: { p_items: Json }
        Returns: undefined
      }
      update_membership_preference_for_self: {
        Args: { p_membership_id: number; p_preference: Json }
        Returns: {
          created_at: string
          email: string
          id: number
          is_active: boolean
          preference: Json
          role: Database["public"]["Enums"]["app_role"]
          tenant_id: number
          updated_at: string
        }[]
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
          to: "invoice_payments"
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
          global_shipment_id: number | null
          id: number
          invested_amount: number
          investor_id: number
          profit_status: string
          shipment_id: number | null
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
      update_shipment_progress_flow: {
        Args: { p_flow_id: number; p_name?: string }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          name: string
          slug: string
          tenant_id: number
        }
        SetofOptions: {
          from: "*"
          to: "shipment_progress_flows"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_shipment_progress_flow_stage: {
        Args: { p_color?: string; p_flow_stage_id: number; p_name?: string }
        Returns: {
          color: string
          flow_id: number
          flow_stage_id: number
          is_active: boolean
          name: string
          slug: string
          sort_order: number
          tag_id: number
        }[]
      }
      update_shipment_progress_tag: {
        Args: {
          p_color?: string
          p_name?: string
          p_sort_order?: number
          p_tag_id: number
        }
        Returns: {
          category_id: number | null
          color: string
          created_at: string
          created_by_email: string
          group_name: string | null
          id: number
          is_active: boolean
          is_system: boolean
          metadata: Json
          name: string
          slug: string
          sort_order: number | null
          tenant_id: number | null
          type: string
        }
        SetofOptions: {
          from: "*"
          to: "tags"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_shop_cart_item_price: {
        Args: { p_cart_item_id: number; p_price: number }
        Returns: Json
      }
      update_shop_cart_item_qty: {
        Args: { p_cart_item_id: number; p_quantity: number }
        Returns: Json
      }
      update_shop_order_charges_for_staff: {
        Args: { p_order_id: number; p_payload: Json; p_tenant_id: number }
        Returns: Json
      }
      update_shop_order_status_for_staff: {
        Args: { p_order_id: number; p_status: string; p_tenant_id: number }
        Returns: Json
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
      update_tenant_role: {
        Args: { p_is_admin: boolean; p_name: string; p_role_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          is_admin: boolean
          is_system: boolean
          name: string
          scope: string
          slug: string
          source_app_role: Database["public"]["Enums"]["app_role"] | null
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "tenant_roles"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_thrift_sales_delivery_status: {
        Args: {
          p_actor?: string
          p_delivery_status: string
          p_invoice_id: number
          p_tenant_id: number
        }
        Returns: Json
      }
      upsert_customer_group_member_grant: {
        Args: {
          p_action: string
          p_cgm_id: number
          p_effect: string
          p_module_key: string
        }
        Returns: {
          action: string
          created_at: string
          customer_group_member_id: number
          effect: string
          id: number
          module_key: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "customer_group_member_grants"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_customer_group_shop_profile: {
        Args: {
          p_customer_group_id: number
          p_default_can_add_to_cart: boolean
          p_default_can_browse: boolean
          p_default_can_negotiate: boolean
          p_default_can_place_order: boolean
          p_default_can_see_buy_price: boolean
          p_default_can_see_sell_price: boolean
          p_default_can_set_dropship_price: boolean
          p_default_can_view_quantity: boolean
          p_is_active: boolean
          p_tenant_id: number
        }
        Returns: {
          created_at: string
          customer_group_id: number
          default_can_add_to_cart: boolean
          default_can_browse: boolean
          default_can_negotiate: boolean
          default_can_place_order: boolean
          default_can_see_buy_price: boolean
          default_can_see_resell_minimum_price: boolean
          default_can_see_sell_price: boolean
          default_can_set_dropship_price: boolean
          default_can_view_quantity: boolean
          id: number
          is_active: boolean
          tenant_id: number
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "customer_group_shop_profiles"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      upsert_global_shipment_cost_entry: {
        Args: {
          p_allocation?: string
          p_amount: number
          p_cost_type: Database["public"]["Enums"]["global_shipment_cost_type"]
          p_currency_id?: number
          p_entity_id?: number
          p_entity_type?: string
          p_exchange_rate?: number
          p_id?: number
          p_metadata?: Json
          p_payment_source?: string
          p_shipment_id: number
        }
        Returns: {
          allocation: string | null
          amount: number
          cost_type: Database["public"]["Enums"]["global_shipment_cost_type"]
          created_at: string
          currency_id: number | null
          entity_id: number | null
          entity_type: string | null
          exchange_rate: number
          id: number
          metadata: Json
          parent_tenant_id: number
          payment_source: string | null
          section_id: number | null
          settled_at: string | null
          settlement_ledger_id: string | null
          shipment_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "global_shipment_cost_entries"
          isOneToOne: true
          isSetofReturn: false
        }
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
      upsert_investor_profile: {
        Args: {
          p_address: string
          p_currency_code: string
          p_email: string
          p_id: number
          p_is_active: boolean
          p_name: string
          p_notes: string
          p_phone: string
          p_tenant_id: number
        }
        Returns: {
          address: string | null
          created_at: string
          currency_code: string
          email: string | null
          id: number
          is_active: boolean
          name: string
          notes: string | null
          phone: string | null
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "investors"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_membership_grant: {
        Args: {
          p_action: string
          p_effect: string
          p_membership_id: number
          p_module_key: string
        }
        Returns: {
          action: string
          created_at: string
          created_by_email: string | null
          effect: string
          id: number
          membership_id: number
          module_key: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "membership_grants"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_pbc_backlog_from_item: {
        Args: { p_costing_item_id: number }
        Returns: {
          barcode: string | null
          billing_profile_id: number
          created_at: string
          id: number
          image_url: string | null
          last_costing_file_id: number | null
          last_costing_item_id: number | null
          name: string
          note: string | null
          open_quantity: number
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_id: number
          product_weight: number | null
          tenant_id: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "product_based_costing_backlog_items"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_recipient_profile_and_address: {
        Args: {
          p_address?: string
          p_district?: string
          p_name: string
          p_phone: string
          p_phone_secondary?: string
          p_tenant_id: number
          p_thana?: string
        }
        Returns: Json
      }
      upsert_recipient_profile_by_phone: {
        Args: {
          p_address?: string
          p_district?: string
          p_name: string
          p_phone: string
          p_secondary_phone?: string
          p_tenant_id: number
          p_thana?: string
        }
        Returns: Json
      }
      upsert_shipment_investment: {
        Args: {
          p_cost_share_pct: number
          p_global_shipment_id: number
          p_id: number
          p_investor_id: number
          p_tenant_id: number
        }
        Returns: {
          actual_profit: number
          allocated_cost: number
          computed_profit: number
          cost_share_pct: number | null
          created_at: string
          global_shipment_id: number | null
          id: number
          invested_amount: number
          investor_id: number
          profit_status: string
          shipment_id: number | null
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
      upsert_shop:
        | {
            Args: {
              p_allow_delivery?: boolean
              p_buy_currency_id?: number
              p_deduct_charges_from_margin?: boolean
              p_deduct_cod_from_margin?: boolean
              p_deduct_delivery_from_margin?: boolean
              p_deduct_packing_from_margin?: boolean
              p_deduct_print_from_margin?: boolean
              p_default_cod_charge_pct?: number
              p_default_currency_id?: number
              p_default_delivery_charge_amount?: number
              p_default_packing_charge_amount?: number
              p_default_print_charge_amount?: number
              p_global_stock_type_id?: number
              p_id?: number
              p_is_active: boolean
              p_is_negotiable: boolean
              p_markup_percentage?: number
              p_name: string
              p_order_mode: Database["public"]["Enums"]["shop_order_mode_enum"]
              p_pricing_method?: string
              p_quantity_display_mode?: string
              p_sell_currency_id?: number
              p_shop_type?: Database["public"]["Enums"]["shop_type_enum"]
              p_show_stock_quantity: boolean
              p_slug: string
              p_tenant_id: number
              p_vendor_code?: string
              p_vendor_filters?: Json
            }
            Returns: {
              allow_delivery: boolean
              buy_currency_id: number
              category_ids: number[] | null
              created_at: string
              deduct_charges_from_margin: boolean
              deduct_cod_from_margin: boolean
              deduct_delivery_from_margin: boolean
              deduct_packing_from_margin: boolean
              deduct_print_from_margin: boolean
              deduct_return_charge_from_middle_man: boolean | null
              default_currency_id: number | null
              default_packing_charge_amount: number
              default_print_charge_amount: number
              deleted_at: string | null
              deleted_by: string | null
              description: string | null
              global_stock_type_id: number | null
              id: number
              is_active: boolean
              is_negotiable: boolean
              markup_percentage: number
              name: string
              order_mode: Database["public"]["Enums"]["shop_order_mode_enum"]
              pricing_method: string
              quantity_display_mode: string
              sell_currency_id: number
              shop_type: Database["public"]["Enums"]["shop_type_enum"]
              show_stock_quantity: boolean
              slug: string
              tenant_id: number
              updated_at: string
              vendor_code: string | null
              vendor_filters: Json | null
            }[]
            SetofOptions: {
              from: "*"
              to: "shops"
              isOneToOne: false
              isSetofReturn: true
            }
          }
        | {
            Args: {
              p_allow_delivery?: boolean
              p_buy_currency_id?: number
              p_category_ids?: number[]
              p_deduct_charges_from_margin?: boolean
              p_deduct_packing_from_margin?: boolean
              p_deduct_print_from_margin?: boolean
              p_default_currency_id?: number
              p_default_packing_charge_amount?: number
              p_default_print_charge_amount?: number
              p_description?: string
              p_global_stock_type_id?: number
              p_id?: number
              p_is_active: boolean
              p_is_negotiable: boolean
              p_markup_percentage?: number
              p_name: string
              p_order_mode: Database["public"]["Enums"]["shop_order_mode_enum"]
              p_pricing_method?: string
              p_quantity_display_mode?: string
              p_sell_currency_id?: number
              p_shop_type?: Database["public"]["Enums"]["shop_type_enum"]
              p_show_stock_quantity: boolean
              p_slug: string
              p_tenant_id: number
              p_vendor_code?: string
              p_vendor_filters?: Json
            }
            Returns: {
              allow_delivery: boolean
              buy_currency_id: number
              category_ids: number[] | null
              created_at: string
              deduct_charges_from_margin: boolean
              deduct_cod_from_margin: boolean
              deduct_delivery_from_margin: boolean
              deduct_packing_from_margin: boolean
              deduct_print_from_margin: boolean
              deduct_return_charge_from_middle_man: boolean | null
              default_currency_id: number | null
              default_packing_charge_amount: number
              default_print_charge_amount: number
              deleted_at: string | null
              deleted_by: string | null
              description: string | null
              global_stock_type_id: number | null
              id: number
              is_active: boolean
              is_negotiable: boolean
              markup_percentage: number
              name: string
              order_mode: Database["public"]["Enums"]["shop_order_mode_enum"]
              pricing_method: string
              quantity_display_mode: string
              sell_currency_id: number
              shop_type: Database["public"]["Enums"]["shop_type_enum"]
              show_stock_quantity: boolean
              slug: string
              tenant_id: number
              updated_at: string
              vendor_code: string | null
              vendor_filters: Json | null
            }[]
            SetofOptions: {
              from: "*"
              to: "shops"
              isOneToOne: false
              isSetofReturn: true
            }
          }
      upsert_shop_customer_group_access: {
        Args: {
          p_can_add_to_cart?: boolean
          p_can_browse?: boolean
          p_can_negotiate?: boolean
          p_can_place_order?: boolean
          p_can_see_buy_price?: boolean
          p_can_see_resell_minimum_price?: boolean
          p_can_see_sell_price?: boolean
          p_can_set_dropship_price?: boolean
          p_can_view_quantity?: boolean
          p_credit_limit_amount?: number
          p_credit_limit_currency_id?: number
          p_customer_group_id: number
          p_price_tier_code?: string
          p_shop_id: number
          p_status: boolean
        }
        Returns: {
          can_add_to_cart: boolean | null
          can_browse: boolean | null
          can_negotiate: boolean | null
          can_place_order: boolean | null
          can_see_buy_price: boolean | null
          can_see_resell_minimum_price: boolean | null
          can_see_sell_price: boolean | null
          can_set_dropship_price: boolean | null
          can_view_quantity: boolean | null
          created_at: string
          credit_limit_amount: number | null
          credit_limit_currency_id: number | null
          customer_group_id: number
          id: number
          price_tier_code: string | null
          shop_id: number
          status: boolean
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "shop_customer_group_access"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      upsert_shop_pricing_rule:
        | {
            Args: {
              p_is_auto_publish: boolean
              p_markup_percentage: number
              p_shop_id: number
            }
            Returns: {
              created_at: string
              default_add_quantity: number
              default_show_quantity: boolean
              dropship_markup_percentage: number
              id: number
              is_auto_publish: boolean
              markup_percentage: number
              shop_id: number
              tenant_id: number
              updated_at: string
            }[]
            SetofOptions: {
              from: "*"
              to: "shop_pricing_rules"
              isOneToOne: false
              isSetofReturn: true
            }
          }
        | {
            Args: {
              p_default_show_quantity?: boolean
              p_is_auto_publish: boolean
              p_markup_percentage: number
              p_shop_id: number
            }
            Returns: {
              created_at: string
              default_add_quantity: number
              default_show_quantity: boolean
              dropship_markup_percentage: number
              id: number
              is_auto_publish: boolean
              markup_percentage: number
              shop_id: number
              tenant_id: number
              updated_at: string
            }[]
            SetofOptions: {
              from: "*"
              to: "shop_pricing_rules"
              isOneToOne: false
              isSetofReturn: true
            }
          }
        | {
            Args: {
              p_default_add_quantity?: number
              p_default_show_quantity?: boolean
              p_is_auto_publish: boolean
              p_markup_percentage: number
              p_shop_id: number
            }
            Returns: {
              created_at: string
              default_add_quantity: number
              default_show_quantity: boolean
              dropship_markup_percentage: number
              id: number
              is_auto_publish: boolean
              markup_percentage: number
              shop_id: number
              tenant_id: number
              updated_at: string
            }[]
            SetofOptions: {
              from: "*"
              to: "shop_pricing_rules"
              isOneToOne: false
              isSetofReturn: true
            }
          }
        | {
            Args: {
              p_default_add_quantity?: number
              p_default_show_quantity?: boolean
              p_dropship_markup_percentage?: number
              p_is_auto_publish: boolean
              p_markup_percentage: number
              p_shop_id: number
            }
            Returns: {
              created_at: string
              default_add_quantity: number
              default_show_quantity: boolean
              dropship_markup_percentage: number
              id: number
              is_auto_publish: boolean
              markup_percentage: number
              shop_id: number
              tenant_id: number
              updated_at: string
            }[]
            SetofOptions: {
              from: "*"
              to: "shop_pricing_rules"
              isOneToOne: false
              isSetofReturn: true
            }
          }
      upsert_shop_product_listing:
        | {
            Args: {
              p_display_quantity_override?: number
              p_global_stock_allocation_id?: number
              p_global_stock_id?: number
              p_id?: number
              p_is_active?: boolean
              p_is_price_locked?: boolean
              p_is_quantity_locked?: boolean
              p_minimum_sell_price_amount?: number
              p_minimum_sell_price_currency_id?: number
              p_quantity_override_type?: string
              p_sell_price_amount?: number
              p_sell_price_currency_id?: number
              p_shop_id: number
              p_show_quantity?: boolean
              p_tenant_id: number
            }
            Returns: {
              created_at: string
              display_quantity_override: number | null
              global_stock_allocation_id: number | null
              global_stock_id: number
              id: number
              is_active: boolean
              is_price_locked: boolean
              is_quantity_locked: boolean
              minimum_sell_price_amount: number | null
              minimum_sell_price_currency_id: number | null
              product_id: number
              quantity_override_type: string
              sell_price_amount: number
              sell_price_currency_id: number
              shop_id: number
              show_quantity: boolean | null
              tenant_id: number
              updated_at: string
            }[]
            SetofOptions: {
              from: "*"
              to: "shop_product_listings"
              isOneToOne: false
              isSetofReturn: true
            }
          }
        | {
            Args: {
              p_display_quantity_override?: number
              p_global_stock_allocation_id: number
              p_id?: number
              p_is_active?: boolean
              p_minimum_sell_price_amount?: number
              p_minimum_sell_price_currency_id?: number
              p_sell_price_amount: number
              p_sell_price_currency_id: number
              p_shop_id: number
              p_show_quantity?: boolean
              p_tenant_id: number
            }
            Returns: {
              created_at: string
              display_quantity_override: number | null
              global_stock_allocation_id: number | null
              global_stock_id: number
              id: number
              is_active: boolean
              is_price_locked: boolean
              is_quantity_locked: boolean
              minimum_sell_price_amount: number | null
              minimum_sell_price_currency_id: number | null
              product_id: number
              quantity_override_type: string
              sell_price_amount: number
              sell_price_currency_id: number
              shop_id: number
              show_quantity: boolean | null
              tenant_id: number
              updated_at: string
            }[]
            SetofOptions: {
              from: "*"
              to: "shop_product_listings"
              isOneToOne: false
              isSetofReturn: true
            }
          }
        | {
            Args: {
              p_display_quantity_override?: number
              p_global_stock_allocation_id: number
              p_id?: number
              p_is_active?: boolean
              p_is_price_locked?: boolean
              p_is_quantity_locked?: boolean
              p_minimum_sell_price_amount?: number
              p_minimum_sell_price_currency_id?: number
              p_quantity_override_type?: string
              p_sell_price_amount: number
              p_sell_price_currency_id: number
              p_shop_id: number
              p_show_quantity?: boolean
              p_tenant_id: number
            }
            Returns: {
              created_at: string
              display_quantity_override: number | null
              global_stock_allocation_id: number | null
              global_stock_id: number
              id: number
              is_active: boolean
              is_price_locked: boolean
              is_quantity_locked: boolean
              minimum_sell_price_amount: number | null
              minimum_sell_price_currency_id: number | null
              product_id: number
              quantity_override_type: string
              sell_price_amount: number
              sell_price_currency_id: number
              shop_id: number
              show_quantity: boolean | null
              tenant_id: number
              updated_at: string
            }[]
            SetofOptions: {
              from: "*"
              to: "shop_product_listings"
              isOneToOne: false
              isSetofReturn: true
            }
          }
      upsert_stock_location: {
        Args: {
          p_code: string
          p_id?: number
          p_is_active?: boolean
          p_is_default?: boolean
          p_is_pickable?: boolean
          p_kind?: Database["public"]["Enums"]["stock_location_kind"]
          p_name: string
          p_parent_location_id?: number
          p_parent_tenant_id: number
          p_sort_order?: number
        }
        Returns: {
          code: string
          created_at: string
          id: number
          is_active: boolean
          is_default: boolean
          is_pickable: boolean
          kind: Database["public"]["Enums"]["stock_location_kind"]
          name: string
          parent_location_id: number | null
          parent_tenant_id: number
          sort_order: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "stock_locations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_tenant_role_grant: {
        Args: {
          p_action: string
          p_allowed: boolean
          p_module_key: string
          p_tenant_role_id: number
        }
        Returns: {
          action: string
          allowed: boolean
          created_at: string
          id: number
          module_key: string
          tenant_role_id: number
          updated_at: string
          updated_by_email: string | null
        }
        SetofOptions: {
          from: "*"
          to: "tenant_role_grants"
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
      user_can_manage_shop_tenant: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
      user_is_tenant_admin: { Args: { p_tenant_id: number }; Returns: boolean }
      void_global_invoice: {
        Args: { p_invoice_id: number }
        Returns: undefined
      }
      void_sales_invoice: { Args: { p_invoice_id: number }; Returns: undefined }
    }
    Enums: {
      app_role:
        | "superadmin"
        | "admin"
        | "staff"
        | "viewer"
        | "investor"
        | "manager"
        | "cashier"
      collection_source_type: "billing_profile" | "recipient"
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
      customer_group_role: "admin" | "manager" | "staff"
      demand_bucket_source_type:
        | "shop_order_item"
        | "pbc_costing_item"
        | "manual"
      demand_bucket_status: "open" | "popped" | "cancelled"
      global_fulfillment_status: "pending" | "packed" | "shipped" | "delivered"
      global_invoice_status:
        | "draft"
        | "proforma_generated"
        | "issued"
        | "voided"
      global_invoice_type: "wholesale" | "retail" | "dropship"
      global_shipment_cost_type:
        | "product"
        | "cargo"
        | "duty"
        | "insurance"
        | "labor"
        | "washing"
        | "transport"
        | "handling"
      global_shipment_item_add_method: "order" | "costing" | "manual"
      global_shipment_type: "local" | "international" | "transfer" | "thrift"
      global_source_module: "wholesale" | "retail" | "commerce"
      investor_payment_method: "cash" | "bank" | "mobile_banking" | "other"
      investor_transaction_type:
        | "deposit"
        | "withdrawal"
        | "profit_payout"
        | "capital_in"
        | "capital_adjustment"
        | "withdrawal_paid"
        | "profit_reinvest"
        | "manual_adjustment"
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
      retail_billing_mode: "account" | "direct"
      shipment_investment_status: "active" | "closed" | "cancelled"
      shop_cart_status: "active" | "converted" | "abandoned"
      shop_order_mode_enum:
        | "procurement_intent"
        | "checkout_fixed"
        | "checkout_wholesale"
      shop_order_status:
        | "draft"
        | "submitted"
        | "cancelled"
        | "priced"
        | "negotiating"
        | "confirmed"
        | "placed"
        | "fulfilled"
        | "processing"
        | "shipped"
        | "delivered"
        | "payment_received"
        | "ready_for_pickup"
        | "returned"
        | "costing_pending"
        | "countered"
        | "final_offered"
        | "procuring"
        | "ordered"
        | "ready_for_shipment"
      shop_type_enum: "vendor_catalog" | "fixed_price" | "dropship"
      stock_availability: "sellable" | "held" | "unsellable"
      stock_location_kind: "shelf" | "slot" | "box" | "returns"
      stock_movement_type:
        | "receive_putaway"
        | "location_transfer"
        | "availability_transfer"
        | "adjustment"
        | "return_inbound"
        | "receive_rollback"
        | "grade_change"
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
      thrift_stock_status:
        | "AVAILABLE"
        | "OUT_OF_STOCK"
        | "DAMAGED"
        | "STOLEN"
        | "SOLD"
        | "RESERVED"
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
      app_role: [
        "superadmin",
        "admin",
        "staff",
        "viewer",
        "investor",
        "manager",
        "cashier",
      ],
      collection_source_type: ["billing_profile", "recipient"],
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
      customer_group_role: ["admin", "manager", "staff"],
      demand_bucket_source_type: [
        "shop_order_item",
        "pbc_costing_item",
        "manual",
      ],
      demand_bucket_status: ["open", "popped", "cancelled"],
      global_fulfillment_status: ["pending", "packed", "shipped", "delivered"],
      global_invoice_status: [
        "draft",
        "proforma_generated",
        "issued",
        "voided",
      ],
      global_invoice_type: ["wholesale", "retail", "dropship"],
      global_shipment_cost_type: [
        "product",
        "cargo",
        "duty",
        "insurance",
        "labor",
        "washing",
        "transport",
        "handling",
      ],
      global_shipment_item_add_method: ["order", "costing", "manual"],
      global_shipment_type: ["local", "international", "transfer", "thrift"],
      global_source_module: ["wholesale", "retail", "commerce"],
      investor_payment_method: ["cash", "bank", "mobile_banking", "other"],
      investor_transaction_type: [
        "deposit",
        "withdrawal",
        "profit_payout",
        "capital_in",
        "capital_adjustment",
        "withdrawal_paid",
        "profit_reinvest",
        "manual_adjustment",
      ],
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
      retail_billing_mode: ["account", "direct"],
      shipment_investment_status: ["active", "closed", "cancelled"],
      shop_cart_status: ["active", "converted", "abandoned"],
      shop_order_mode_enum: [
        "procurement_intent",
        "checkout_fixed",
        "checkout_wholesale",
      ],
      shop_order_status: [
        "draft",
        "submitted",
        "cancelled",
        "priced",
        "negotiating",
        "confirmed",
        "placed",
        "fulfilled",
        "processing",
        "shipped",
        "delivered",
        "payment_received",
        "ready_for_pickup",
        "returned",
        "costing_pending",
        "countered",
        "final_offered",
        "procuring",
        "ordered",
        "ready_for_shipment",
      ],
      shop_type_enum: ["vendor_catalog", "fixed_price", "dropship"],
      stock_availability: ["sellable", "held", "unsellable"],
      stock_location_kind: ["shelf", "slot", "box", "returns"],
      stock_movement_type: [
        "receive_putaway",
        "location_transfer",
        "availability_transfer",
        "adjustment",
        "return_inbound",
        "receive_rollback",
        "grade_change",
      ],
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
      thrift_stock_status: [
        "AVAILABLE",
        "OUT_OF_STOCK",
        "DAMAGED",
        "STOLEN",
        "SOLD",
        "RESERVED",
      ],
      thrift_stock_type: ["SINGLE", "BULK"],
      thrift_transaction_method: ["CASH", "CARD", "MOBILE_BANKING", "COD"],
    },
  },
} as const

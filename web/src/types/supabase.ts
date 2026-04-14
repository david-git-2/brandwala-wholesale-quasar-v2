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
      cart_items: {
        Row: {
          cart_id: number
          created_at: string
          id: number
          image_url: string | null
          minimum_quantity: number
          name: string
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
          name: string
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
          name?: string
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
      costing_file_items: {
        Row: {
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
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: number
          is_active?: boolean
          key: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: number
          is_active?: boolean
          key?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      product_based_costing_files: {
        Row: {
          cargo_rate_kg_gbp: number | null
          conversion_rate: number | null
          created_at: string
          id: number
          name: string | null
          note: string | null
          order_for: string | null
          profit_rate: number | null
          status: string | null
          tenant_id: number | null
          updated_at: string
        }
        Insert: {
          cargo_rate_kg_gbp?: number | null
          conversion_rate?: number | null
          created_at?: string
          id?: number
          name?: string | null
          note?: string | null
          order_for?: string | null
          profit_rate?: number | null
          status?: string | null
          tenant_id?: number | null
          updated_at?: string
        }
        Update: {
          cargo_rate_kg_gbp?: number | null
          conversion_rate?: number | null
          created_at?: string
          id?: number
          name?: string | null
          note?: string | null
          order_for?: string | null
          profit_rate?: number | null
          status?: string | null
          tenant_id?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_based_costing_files_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      product_based_costing_items: {
        Row: {
          barcode: string | null
          created_at: string
          id: number
          image_url: string | null
          name: string | null
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
          web_link: string | null
        }
        Insert: {
          barcode?: string | null
          created_at?: string
          id?: number
          image_url?: string | null
          name?: string | null
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
          web_link?: string | null
        }
        Update: {
          barcode?: string | null
          created_at?: string
          id?: number
          image_url?: string | null
          name?: string | null
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
            foreignKeyName: "product_based_costing_items_product_based_costing_file_id_fkey"
            columns: ["product_based_costing_file_id"]
            isOneToOne: false
            referencedRelation: "product_based_costing_files"
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
          id: number
          image_url: string | null
          is_available: boolean | null
          languages: string | null
          market_code: string | null
          minimum_order_quantity: number | null
          name: string | null
          package_weight: number | null
          price_gbp: number | null
          product_code: string | null
          product_weight: number | null
          tariff_code: string | null
          tenant_id: number | null
          updated_at: string
          vendor_code: string | null
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
          id?: number
          image_url?: string | null
          is_available?: boolean | null
          languages?: string | null
          market_code?: string | null
          minimum_order_quantity?: number | null
          name?: string | null
          package_weight?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_weight?: number | null
          tariff_code?: string | null
          tenant_id?: number | null
          updated_at?: string
          vendor_code?: string | null
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
          id?: number
          image_url?: string | null
          is_available?: boolean | null
          languages?: string | null
          market_code?: string | null
          minimum_order_quantity?: number | null
          name?: string | null
          package_weight?: number | null
          price_gbp?: number | null
          product_code?: string | null
          product_weight?: number | null
          tariff_code?: string | null
          tenant_id?: number | null
          updated_at?: string
          vendor_code?: string | null
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
            foreignKeyName: "products_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_vendor_code_fkey"
            columns: ["vendor_code"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["code"]
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
      stores: {
        Row: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
          vendor_code: string | null
        }
        Insert: {
          created_at?: string
          id?: number
          name: string
          tenant_id: number
          updated_at?: string
          vendor_code?: string | null
        }
        Update: {
          created_at?: string
          id?: number
          name?: string
          tenant_id?: number
          updated_at?: string
          vendor_code?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stores_tenant_id_fkey"
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
      tenants: {
        Row: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          public_domain: string | null
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: number
          is_active?: boolean
          name: string
          public_domain?: string | null
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: number
          is_active?: boolean
          name?: string
          public_domain?: string | null
          slug?: string
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
      add_item_to_cart: {
        Args: {
          p_can_see_price?: boolean
          p_customer_group_id?: number
          p_image_url?: string
          p_minimum_quantity?: number
          p_name?: string
          p_price_gbp?: number
          p_product_id?: number
          p_quantity?: number
          p_store_id?: number
          p_tenant_id: number
        }
        Returns: Json
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
      create_store: {
        Args: { p_name: string; p_tenant_id: number; p_vendor_code: string }
        Returns: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
          vendor_code: string | null
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
          p_public_domain?: string
          p_slug: string
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
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
      current_user_email: { Args: never; Returns: string }
      delete_store: { Args: { p_id: number }; Returns: undefined }
      delete_store_access: { Args: { p_id: number }; Returns: undefined }
      delete_tenant_for_superadmin: {
        Args: { p_tenant_id: number }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
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
      get_active_module_keys_for_tenant: {
        Args: { p_tenant_id: number }
        Returns: string[]
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
          id: number
          market: string
          name: string
          status: Database["public"]["Enums"]["costing_file_status"]
          tenant_id: number
          updated_at: string
        }[]
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
        Args: { p_store_id?: number }
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
      is_customer_group_member: {
        Args: { p_customer_group_id: number }
        Returns: boolean
      }
      is_internal_costing_file_creator: {
        Args: { p_email: string; p_tenant_id: number }
        Returns: boolean
      }
      is_superadmin: { Args: never; Returns: boolean }
      is_tenant_admin: { Args: { p_tenant_id: number }; Returns: boolean }
      is_tenant_staff: { Args: { p_tenant_id: number }; Returns: boolean }
      is_vendor_code_available: {
        Args: { p_code: string; p_exclude_id?: number }
        Returns: boolean
      }
      list_costing_file_items: {
        Args: { p_costing_file_id: number }
        Returns: {
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
          item_type: string
          name: string
          offer_price_bdt: number
          offer_price_override_bdt: number
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
              p_limit?: number
              p_offset?: number
              p_tenant_id?: number
            }
            Returns: {
              created_at: string
              created_by_email: string
              created_by_label: string
              customer_group_id: number
              id: number
              market: string
              name: string
              status: Database["public"]["Enums"]["costing_file_status"]
              tenant_id: number
              total_count: number
              updated_at: string
            }[]
          }
      list_my_admin_tenants: {
        Args: never
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
          public_domain: string
          slug: string
          updated_at: string
        }[]
      }
      list_store_products: {
        Args: {
          p_brand?: string
          p_category?: string
          p_fields?: string[]
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_sort_by?: string
          p_sort_dir?: string
          p_store_id: number
        }
        Returns: Json
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
          public_domain: string
          slug: string
          updated_at: string
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
      resolve_costing_file_creator_label: {
        Args: {
          p_created_by_email: string
          p_customer_group_id: number
          p_tenant_id: number
        }
        Returns: string
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
              p_delivery_price_gbp?: number
              p_id: number
              p_image_url?: string
              p_item_type?: string
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
              item_type: string
              name: string
              package_weight: number
              price_in_web_gbp: number
              product_weight: number
              updated_at: string
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
      update_store: {
        Args: { p_id: number; p_name: string; p_vendor_code: string }
        Returns: {
          created_at: string
          id: number
          name: string
          tenant_id: number
          updated_at: string
          vendor_code: string | null
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
          p_public_domain?: string
          p_slug: string
          p_tenant_id: number
        }
        Returns: {
          created_at: string
          id: number
          is_active: boolean
          name: string
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
    }
    Enums: {
      app_role: "superadmin" | "admin" | "staff" | "viewer"
      costing_file_item_status: "pending" | "accepted" | "rejected"
      costing_file_status:
        | "draft"
        | "customer_submitted"
        | "in_review"
        | "priced"
        | "offered"
        | "po_placed"
        | "cancelled"
        | "completed"
      customer_group_role: "admin" | "negotiator" | "staff"
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
      app_role: ["superadmin", "admin", "staff", "viewer"],
      costing_file_item_status: ["pending", "accepted", "rejected"],
      costing_file_status: [
        "draft",
        "customer_submitted",
        "in_review",
        "priced",
        "offered",
        "po_placed",
        "cancelled",
        "completed",
      ],
      customer_group_role: ["admin", "negotiator", "staff"],
    },
  },
} as const

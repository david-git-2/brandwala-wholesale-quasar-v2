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
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
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
      can_view_tenant_modules: {
        Args: { p_tenant_id: number }
        Returns: boolean
      }
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
      current_user_email: { Args: never; Returns: string }
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
      get_shop_bootstrap_context: {
        Args: {
          p_customer_group_member_id?: number
          p_email?: string
          p_tenant_id?: number
        }
        Returns: {
          active_module_keys: string[]
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
      is_superadmin: { Args: never; Returns: boolean }
      is_tenant_admin: { Args: { p_tenant_id: number }; Returns: boolean }
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
          public_domain: string
          slug: string
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
      resolve_tenant_for_entry: {
        Args: { p_hostname?: string; p_slug?: string }
        Returns: {
          id: number
          name: string
          public_domain: string
          slug: string
        }[]
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
      app_role: "superadmin" | "admin" | "staff"
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
      app_role: ["superadmin", "admin", "staff"],
      customer_group_role: ["admin", "negotiator", "staff"],
    },
  },
} as const

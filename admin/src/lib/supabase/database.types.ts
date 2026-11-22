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
    PostgrestVersion: "14.18"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      admin_audit_log: {
        Row: {
          action: string
          actor_id: string
          cluster_id: string | null
          created_at: string
          details: Json
          id: number
          target_user_id: string | null
        }
        Insert: {
          action: string
          actor_id: string
          cluster_id?: string | null
          created_at?: string
          details?: Json
          id?: never
          target_user_id?: string | null
        }
        Update: {
          action?: string
          actor_id?: string
          cluster_id?: string | null
          created_at?: string
          details?: Json
          id?: never
          target_user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "admin_audit_log_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_audit_log_cluster_id_fkey"
            columns: ["cluster_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_audit_log_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      balances: {
        Row: {
          sp_balance: number
          ssp_balance: number
          updated_at: string
          user_id: string
        }
        Insert: {
          sp_balance?: number
          ssp_balance?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          sp_balance?: number
          ssp_balance?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "balances_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bet_options: {
        Row: {
          bet_id: string
          id: string
          is_winner: boolean | null
          label: string
          odds: number | null
          pool_amount: number
          position: number
        }
        Insert: {
          bet_id: string
          id?: string
          is_winner?: boolean | null
          label: string
          odds?: number | null
          pool_amount?: number
          position: number
        }
        Update: {
          bet_id?: string
          id?: string
          is_winner?: boolean | null
          label?: string
          odds?: number | null
          pool_amount?: number
          position?: number
        }
        Relationships: [
          {
            foreignKeyName: "bet_options_bet_id_fkey"
            columns: ["bet_id"]
            isOneToOne: false
            referencedRelation: "bets"
            referencedColumns: ["id"]
          },
        ]
      }
      bets: {
        Row: {
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          cluster_id: string
          created_at: string
          creator_id: string
          currency: Database["public"]["Enums"]["currency"]
          description: string | null
          id: string
          locks_at: string
          max_stake: number | null
          min_stake: number
          odds_mode: Database["public"]["Enums"]["odds_mode"]
          opens_at: string
          pool_total: number
          referee_id: string | null
          scope: Database["public"]["Enums"]["bet_scope"]
          settled_at: string | null
          settled_by: string | null
          settlement_mode: Database["public"]["Enums"]["settlement_mode"]
          status: Database["public"]["Enums"]["bet_status"]
          title: string
          type: Database["public"]["Enums"]["bet_type"]
        }
        Insert: {
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cluster_id: string
          created_at?: string
          creator_id: string
          currency: Database["public"]["Enums"]["currency"]
          description?: string | null
          id?: string
          locks_at: string
          max_stake?: number | null
          min_stake?: number
          odds_mode?: Database["public"]["Enums"]["odds_mode"]
          opens_at?: string
          pool_total?: number
          referee_id?: string | null
          scope: Database["public"]["Enums"]["bet_scope"]
          settled_at?: string | null
          settled_by?: string | null
          settlement_mode: Database["public"]["Enums"]["settlement_mode"]
          status?: Database["public"]["Enums"]["bet_status"]
          title: string
          type: Database["public"]["Enums"]["bet_type"]
        }
        Update: {
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cluster_id?: string
          created_at?: string
          creator_id?: string
          currency?: Database["public"]["Enums"]["currency"]
          description?: string | null
          id?: string
          locks_at?: string
          max_stake?: number | null
          min_stake?: number
          odds_mode?: Database["public"]["Enums"]["odds_mode"]
          opens_at?: string
          pool_total?: number
          referee_id?: string | null
          scope?: Database["public"]["Enums"]["bet_scope"]
          settled_at?: string | null
          settled_by?: string | null
          settlement_mode?: Database["public"]["Enums"]["settlement_mode"]
          status?: Database["public"]["Enums"]["bet_status"]
          title?: string
          type?: Database["public"]["Enums"]["bet_type"]
        }
        Relationships: [
          {
            foreignKeyName: "bets_cancelled_by_fkey"
            columns: ["cancelled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bets_cluster_id_fkey"
            columns: ["cluster_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bets_creator_id_fkey"
            columns: ["creator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bets_referee_id_fkey"
            columns: ["referee_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bets_settled_by_fkey"
            columns: ["settled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      clusters: {
        Row: {
          created_at: string
          id: string
          name: string
          parent_cluster_id: string | null
          school_id: string
          type: Database["public"]["Enums"]["cluster_type"]
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          parent_cluster_id?: string | null
          school_id: string
          type: Database["public"]["Enums"]["cluster_type"]
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          parent_cluster_id?: string | null
          school_id?: string
          type?: Database["public"]["Enums"]["cluster_type"]
        }
        Relationships: [
          {
            foreignKeyName: "clusters_parent_cluster_id_fkey"
            columns: ["parent_cluster_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "clusters_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
        ]
      }
      economy_settings: {
        Row: {
          daily_base_sp: number
          daily_max_sp: number
          daily_step_sp: number
          day_timezone: string
          id: boolean
          signup_bonus_sp: number
          streak_milestones: Json
          updated_at: string
        }
        Insert: {
          daily_base_sp: number
          daily_max_sp: number
          daily_step_sp: number
          day_timezone?: string
          id?: boolean
          signup_bonus_sp: number
          streak_milestones?: Json
          updated_at?: string
        }
        Update: {
          daily_base_sp?: number
          daily_max_sp?: number
          daily_step_sp?: number
          day_timezone?: string
          id?: boolean
          signup_bonus_sp?: number
          streak_milestones?: Json
          updated_at?: string
        }
        Relationships: []
      }
      ledger_entries: {
        Row: {
          actor_id: string | null
          amount: number
          balance_after: number
          created_at: string
          currency: Database["public"]["Enums"]["currency"]
          id: number
          note: string | null
          reason: Database["public"]["Enums"]["ledger_reason"]
          ref_id: string | null
          ref_type: Database["public"]["Enums"]["ledger_ref_type"] | null
          user_id: string
        }
        Insert: {
          actor_id?: string | null
          amount: number
          balance_after: number
          created_at?: string
          currency: Database["public"]["Enums"]["currency"]
          id?: never
          note?: string | null
          reason: Database["public"]["Enums"]["ledger_reason"]
          ref_id?: string | null
          ref_type?: Database["public"]["Enums"]["ledger_ref_type"] | null
          user_id: string
        }
        Update: {
          actor_id?: string | null
          amount?: number
          balance_after?: number
          created_at?: string
          currency?: Database["public"]["Enums"]["currency"]
          id?: never
          note?: string | null
          reason?: Database["public"]["Enums"]["ledger_reason"]
          ref_id?: string | null
          ref_type?: Database["public"]["Enums"]["ledger_ref_type"] | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ledger_entries_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      login_streaks: {
        Row: {
          current_streak: number
          last_login_date: string | null
          longest_streak: number
          user_id: string
        }
        Insert: {
          current_streak?: number
          last_login_date?: string | null
          longest_streak?: number
          user_id: string
        }
        Update: {
          current_streak?: number
          last_login_date?: string | null
          longest_streak?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "login_streaks_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          cluster_id: string
          granted_at: string
          granted_by: string
          permission_key: Database["public"]["Enums"]["permission_key"]
          user_id: string
        }
        Insert: {
          cluster_id: string
          granted_at?: string
          granted_by: string
          permission_key: Database["public"]["Enums"]["permission_key"]
          user_id: string
        }
        Update: {
          cluster_id?: string
          granted_at?: string
          granted_by?: string
          permission_key?: Database["public"]["Enums"]["permission_key"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "permissions_cluster_id_fkey"
            columns: ["cluster_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "permissions_granted_by_fkey"
            columns: ["granted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "permissions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_private: {
        Row: {
          student_email: string | null
          student_email_verified_at: string | null
          user_id: string
        }
        Insert: {
          student_email?: string | null
          student_email_verified_at?: string | null
          user_id: string
        }
        Update: {
          student_email?: string | null
          student_email_verified_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_private_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          department: string | null
          first_name: string
          id: string
          last_name: string
          level: number
          role: Database["public"]["Enums"]["user_role"]
          school_id: string
          updated_at: string
          xp: number
        }
        Insert: {
          created_at?: string
          department?: string | null
          first_name: string
          id: string
          last_name: string
          level?: number
          role?: Database["public"]["Enums"]["user_role"]
          school_id: string
          updated_at?: string
          xp?: number
        }
        Update: {
          created_at?: string
          department?: string | null
          first_name?: string
          id?: string
          last_name?: string
          level?: number
          role?: Database["public"]["Enums"]["user_role"]
          school_id?: string
          updated_at?: string
          xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "profiles_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
        ]
      }
      school_email_domains: {
        Row: {
          created_at: string
          domain: string
          school_id: string
        }
        Insert: {
          created_at?: string
          domain: string
          school_id: string
        }
        Update: {
          created_at?: string
          domain?: string
          school_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "school_email_domains_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
        ]
      }
      user_clusters: {
        Row: {
          cluster_id: string
          joined_at: string
          role_in_cluster: Database["public"]["Enums"]["membership_role"]
          user_id: string
        }
        Insert: {
          cluster_id: string
          joined_at?: string
          role_in_cluster?: Database["public"]["Enums"]["membership_role"]
          user_id: string
        }
        Update: {
          cluster_id?: string
          joined_at?: string
          role_in_cluster?: Database["public"]["Enums"]["membership_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_clusters_cluster_id_fkey"
            columns: ["cluster_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_clusters_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      wagers: {
        Row: {
          amount: number
          bet_id: string
          created_at: string
          currency: Database["public"]["Enums"]["currency"]
          id: string
          odds: number | null
          option_id: string
          payout: number | null
          user_id: string
        }
        Insert: {
          amount: number
          bet_id: string
          created_at?: string
          currency: Database["public"]["Enums"]["currency"]
          id?: string
          odds?: number | null
          option_id: string
          payout?: number | null
          user_id: string
        }
        Update: {
          amount?: number
          bet_id?: string
          created_at?: string
          currency?: Database["public"]["Enums"]["currency"]
          id?: string
          odds?: number | null
          option_id?: string
          payout?: number | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wagers_bet_id_fkey"
            columns: ["bet_id"]
            isOneToOne: false
            referencedRelation: "bets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wagers_option_id_bet_id_fkey"
            columns: ["option_id", "bet_id"]
            isOneToOne: false
            referencedRelation: "bet_options"
            referencedColumns: ["id", "bet_id"]
          },
          {
            foreignKeyName: "wagers_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_adjust: {
        Args: {
          p_amount: number
          p_currency: Database["public"]["Enums"]["currency"]
          p_note: string
          p_user_id: string
        }
        Returns: number
      }
      admin_grant: {
        Args: {
          p_amount: number
          p_currency: Database["public"]["Enums"]["currency"]
          p_note: string
          p_user_id: string
        }
        Returns: number
      }
      cancel_official_bet: {
        Args: { p_bet_id: string; p_reason: string }
        Returns: undefined
      }
      claim_daily_login: {
        Args: never
        Returns: {
          amount: number
          claimed: boolean
          current_streak: number
          sp_balance: number
        }[]
      }
      confirm_student_email: {
        Args: { p_code: string }
        Returns: {
          attempts_left: number
          verified: boolean
        }[]
      }
      create_official_bet: {
        Args: {
          p_description: string
          p_locks_at: string
          p_max_stake?: number
          p_odds: number[]
          p_options: string[]
          p_school_id: string
          p_title: string
        }
        Returns: string
      }
      create_profile: {
        Args: {
          p_department?: string
          p_first_name: string
          p_last_name: string
          p_school_id: string
        }
        Returns: {
          created_at: string
          department: string | null
          first_name: string
          id: string
          last_name: string
          level: number
          role: Database["public"]["Enums"]["user_role"]
          school_id: string
          updated_at: string
          xp: number
        }
        SetofOptions: {
          from: "*"
          to: "profiles"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      grant_permission: {
        Args: {
          p_key: Database["public"]["Enums"]["permission_key"]
          p_school_id: string
          p_user_id: string
        }
        Returns: undefined
      }
      lock_official_bet: { Args: { p_bet_id: string }; Returns: undefined }
      place_wager: {
        Args: { p_amount: number; p_bet_id: string; p_option_id: string }
        Returns: {
          amount: number
          bet_id: string
          created_at: string
          currency: Database["public"]["Enums"]["currency"]
          id: string
          odds: number | null
          option_id: string
          payout: number | null
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "wagers"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      request_student_email_code: {
        Args: { p_email: string }
        Returns: {
          email: string
          expires_at: string
        }[]
      }
      revoke_permission: {
        Args: {
          p_key: Database["public"]["Enums"]["permission_key"]
          p_school_id: string
          p_user_id: string
        }
        Returns: undefined
      }
      settle_official_bet: {
        Args: { p_bet_id: string; p_winning_option_id: string }
        Returns: undefined
      }
    }
    Enums: {
      bet_scope: "private" | "school" | "cross_school" | "global"
      bet_status: "open" | "locked" | "settling" | "settled" | "cancelled"
      bet_type: "ssp_official" | "sp_minigame" | "sp_social"
      cluster_type: "school" | "department" | "club" | "group"
      currency: "SP" | "SSP"
      ledger_reason:
        | "signup_bonus"
        | "daily_login"
        | "quest_reward"
        | "bet_stake"
        | "bet_payout"
        | "bet_refund"
        | "market_purchase"
        | "admin_grant"
        | "admin_adjust"
      ledger_ref_type: "bet" | "wager" | "quest" | "market_item"
      membership_role: "member" | "owner"
      odds_mode: "pool" | "fixed"
      permission_key:
        | "resmi_bahis_ac"
        | "resmi_bahis_kapat"
        | "kullanici_bahsi_denetle"
        | "market_yonet"
        | "gorev_yonet"
        | "kullanici_yonet"
        | "analitik_gor"
      settlement_mode: "auto" | "admin" | "referee"
      user_role: "student" | "yetkili" | "superadmin"
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
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
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      bet_scope: ["private", "school", "cross_school", "global"],
      bet_status: ["open", "locked", "settling", "settled", "cancelled"],
      bet_type: ["ssp_official", "sp_minigame", "sp_social"],
      cluster_type: ["school", "department", "club", "group"],
      currency: ["SP", "SSP"],
      ledger_reason: [
        "signup_bonus",
        "daily_login",
        "quest_reward",
        "bet_stake",
        "bet_payout",
        "bet_refund",
        "market_purchase",
        "admin_grant",
        "admin_adjust",
      ],
      ledger_ref_type: ["bet", "wager", "quest", "market_item"],
      membership_role: ["member", "owner"],
      odds_mode: ["pool", "fixed"],
      permission_key: [
        "resmi_bahis_ac",
        "resmi_bahis_kapat",
        "kullanici_bahsi_denetle",
        "market_yonet",
        "gorev_yonet",
        "kullanici_yonet",
        "analitik_gor",
      ],
      settlement_mode: ["auto", "admin", "referee"],
      user_role: ["student", "yetkili", "superadmin"],
    },
  },
} as const

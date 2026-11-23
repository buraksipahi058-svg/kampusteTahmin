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
      achievement_unlocks: {
        Row: {
          achievement_id: string
          reward_sp: number
          reward_xp: number
          unlocked_at: string
          user_id: string
        }
        Insert: {
          achievement_id: string
          reward_sp: number
          reward_xp: number
          unlocked_at?: string
          user_id: string
        }
        Update: {
          achievement_id?: string
          reward_sp?: number
          reward_xp?: number
          unlocked_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "achievement_unlocks_achievement_id_fkey"
            columns: ["achievement_id"]
            isOneToOne: false
            referencedRelation: "achievements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_unlocks_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      achievements: {
        Row: {
          active: boolean
          category: Database["public"]["Enums"]["achievement_category"]
          created_at: string
          description: string
          hidden: boolean
          icon: string
          id: string
          key: string
          metric: string
          reward_sp: number
          reward_xp: number
          sort: number
          target: number
          tier: number
          title: string
        }
        Insert: {
          active?: boolean
          category: Database["public"]["Enums"]["achievement_category"]
          created_at?: string
          description: string
          hidden?: boolean
          icon: string
          id?: string
          key: string
          metric: string
          reward_sp: number
          reward_xp?: number
          sort?: number
          target: number
          tier?: number
          title: string
        }
        Update: {
          active?: boolean
          category?: Database["public"]["Enums"]["achievement_category"]
          created_at?: string
          description?: string
          hidden?: boolean
          icon?: string
          id?: string
          key?: string
          metric?: string
          reward_sp?: number
          reward_xp?: number
          sort?: number
          target?: number
          tier?: number
          title?: string
        }
        Relationships: []
      }
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
      bet_disputes: {
        Row: {
          bet_id: string
          created_at: string
          decision: Database["public"]["Enums"]["dispute_decision"] | null
          id: string
          raised_by: string
          reason: string
          resolution_note: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: Database["public"]["Enums"]["dispute_status"]
        }
        Insert: {
          bet_id: string
          created_at?: string
          decision?: Database["public"]["Enums"]["dispute_decision"] | null
          id?: string
          raised_by: string
          reason: string
          resolution_note?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: Database["public"]["Enums"]["dispute_status"]
        }
        Update: {
          bet_id?: string
          created_at?: string
          decision?: Database["public"]["Enums"]["dispute_decision"] | null
          id?: string
          raised_by?: string
          reason?: string
          resolution_note?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: Database["public"]["Enums"]["dispute_status"]
        }
        Relationships: [
          {
            foreignKeyName: "bet_disputes_bet_id_fkey"
            columns: ["bet_id"]
            isOneToOne: false
            referencedRelation: "bets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bet_disputes_raised_by_fkey"
            columns: ["raised_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bet_disputes_resolved_by_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
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
          dispute_until: string | null
          id: string
          locks_at: string
          max_stake: number | null
          min_stake: number
          odds_mode: Database["public"]["Enums"]["odds_mode"]
          opens_at: string
          pool_total: number
          proposed_option_id: string | null
          referee_id: string | null
          result_submitted_at: string | null
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
          dispute_until?: string | null
          id?: string
          locks_at: string
          max_stake?: number | null
          min_stake?: number
          odds_mode?: Database["public"]["Enums"]["odds_mode"]
          opens_at?: string
          pool_total?: number
          proposed_option_id?: string | null
          referee_id?: string | null
          result_submitted_at?: string | null
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
          dispute_until?: string | null
          id?: string
          locks_at?: string
          max_stake?: number | null
          min_stake?: number
          odds_mode?: Database["public"]["Enums"]["odds_mode"]
          opens_at?: string
          pool_total?: number
          proposed_option_id?: string | null
          referee_id?: string | null
          result_submitted_at?: string | null
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
          api_write_limit_per_minute: number
          daily_base_sp: number
          daily_max_sp: number
          daily_max_stake_sp: number
          daily_result_deadline_days: number
          daily_step_sp: number
          day_timezone: string
          duel_accept_hours: number
          duel_max_stake_sp: number
          duel_play_hours: number
          id: boolean
          leaderboard_min_predictions_all: number
          leaderboard_min_predictions_week: number
          referee_strike_limit: number
          signup_bonus_sp: number
          social_dispute_hours: number
          social_max_stake_sp: number
          social_result_deadline_days: number
          streak_milestones: Json
          trivia_question_count: number
          trivia_seconds_per_question: number
          updated_at: string
          xp_correct_pick: number
          xp_daily_login: number
          xp_daily_pick_cap: number
          xp_level_step: number
        }
        Insert: {
          api_write_limit_per_minute?: number
          daily_base_sp: number
          daily_max_sp: number
          daily_max_stake_sp?: number
          daily_result_deadline_days?: number
          daily_step_sp: number
          day_timezone?: string
          duel_accept_hours?: number
          duel_max_stake_sp?: number
          duel_play_hours?: number
          id?: boolean
          leaderboard_min_predictions_all?: number
          leaderboard_min_predictions_week?: number
          referee_strike_limit?: number
          signup_bonus_sp: number
          social_dispute_hours?: number
          social_max_stake_sp?: number
          social_result_deadline_days?: number
          streak_milestones?: Json
          trivia_question_count?: number
          trivia_seconds_per_question?: number
          updated_at?: string
          xp_correct_pick?: number
          xp_daily_login?: number
          xp_daily_pick_cap?: number
          xp_level_step?: number
        }
        Update: {
          api_write_limit_per_minute?: number
          daily_base_sp?: number
          daily_max_sp?: number
          daily_max_stake_sp?: number
          daily_result_deadline_days?: number
          daily_step_sp?: number
          day_timezone?: string
          duel_accept_hours?: number
          duel_max_stake_sp?: number
          duel_play_hours?: number
          id?: boolean
          leaderboard_min_predictions_all?: number
          leaderboard_min_predictions_week?: number
          referee_strike_limit?: number
          signup_bonus_sp?: number
          social_dispute_hours?: number
          social_max_stake_sp?: number
          social_result_deadline_days?: number
          streak_milestones?: Json
          trivia_question_count?: number
          trivia_seconds_per_question?: number
          updated_at?: string
          xp_correct_pick?: number
          xp_daily_login?: number
          xp_daily_pick_cap?: number
          xp_level_step?: number
        }
        Relationships: []
      }
      leaderboard_snapshots: {
        Row: {
          computed_at: string
          metric: Database["public"]["Enums"]["leaderboard_metric"]
          period: Database["public"]["Enums"]["leaderboard_period"]
          period_start: string | null
          rank: number
          sample: number
          school_id: string
          user_id: string
          value: number
        }
        Insert: {
          computed_at: string
          metric: Database["public"]["Enums"]["leaderboard_metric"]
          period: Database["public"]["Enums"]["leaderboard_period"]
          period_start?: string | null
          rank: number
          sample: number
          school_id: string
          user_id: string
          value: number
        }
        Update: {
          computed_at?: string
          metric?: Database["public"]["Enums"]["leaderboard_metric"]
          period?: Database["public"]["Enums"]["leaderboard_period"]
          period_start?: string | null
          rank?: number
          sample?: number
          school_id?: string
          user_id?: string
          value?: number
        }
        Relationships: [
          {
            foreignKeyName: "leaderboard_snapshots_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leaderboard_snapshots_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
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
      market_items: {
        Row: {
          active: boolean
          available_from: string | null
          available_until: string | null
          category: Database["public"]["Enums"]["market_category"]
          color: string | null
          created_at: string
          created_by: string | null
          currency: Database["public"]["Enums"]["currency"]
          description: string | null
          icon: string | null
          id: string
          min_level: number
          name: string
          price: number
          school_id: string | null
          updated_at: string
        }
        Insert: {
          active?: boolean
          available_from?: string | null
          available_until?: string | null
          category: Database["public"]["Enums"]["market_category"]
          color?: string | null
          created_at?: string
          created_by?: string | null
          currency?: Database["public"]["Enums"]["currency"]
          description?: string | null
          icon?: string | null
          id?: string
          min_level?: number
          name: string
          price: number
          school_id?: string | null
          updated_at?: string
        }
        Update: {
          active?: boolean
          available_from?: string | null
          available_until?: string | null
          category?: Database["public"]["Enums"]["market_category"]
          color?: string | null
          created_at?: string
          created_by?: string | null
          currency?: Database["public"]["Enums"]["currency"]
          description?: string | null
          icon?: string | null
          id?: string
          min_level?: number
          name?: string
          price?: number
          school_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "market_items_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "market_items_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "clusters"
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
          leaderboard_hidden: boolean
          student_email: string | null
          student_email_verified_at: string | null
          user_id: string
        }
        Insert: {
          leaderboard_hidden?: boolean
          student_email?: string | null
          student_email_verified_at?: string | null
          user_id: string
        }
        Update: {
          leaderboard_hidden?: boolean
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
          banned_at: string | null
          created_at: string
          deleted_at: string | null
          department: string | null
          first_name: string
          id: string
          last_name: string
          level: number
          referee_strikes: number
          role: Database["public"]["Enums"]["user_role"]
          school_id: string
          updated_at: string
          xp: number
        }
        Insert: {
          banned_at?: string | null
          created_at?: string
          deleted_at?: string | null
          department?: string | null
          first_name: string
          id: string
          last_name: string
          level?: number
          referee_strikes?: number
          role?: Database["public"]["Enums"]["user_role"]
          school_id: string
          updated_at?: string
          xp?: number
        }
        Update: {
          banned_at?: string | null
          created_at?: string
          deleted_at?: string | null
          department?: string | null
          first_name?: string
          id?: string
          last_name?: string
          level?: number
          referee_strikes?: number
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
      quest_claims: {
        Row: {
          claimed_at: string
          period_start: string
          quest_id: string
          reward_amount: number
          reward_currency: Database["public"]["Enums"]["currency"]
          user_id: string
        }
        Insert: {
          claimed_at?: string
          period_start: string
          quest_id: string
          reward_amount: number
          reward_currency: Database["public"]["Enums"]["currency"]
          user_id: string
        }
        Update: {
          claimed_at?: string
          period_start?: string
          quest_id?: string
          reward_amount?: number
          reward_currency?: Database["public"]["Enums"]["currency"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "quest_claims_quest_id_fkey"
            columns: ["quest_id"]
            isOneToOne: false
            referencedRelation: "quests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quest_claims_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      quests: {
        Row: {
          action: Database["public"]["Enums"]["quest_action"]
          active: boolean
          created_at: string
          created_by: string | null
          description: string | null
          ends_at: string | null
          id: string
          period: Database["public"]["Enums"]["quest_period"]
          reward_amount: number
          reward_currency: Database["public"]["Enums"]["currency"]
          reward_xp: number
          school_id: string | null
          starts_at: string | null
          target: number
          title: string
          updated_at: string
        }
        Insert: {
          action: Database["public"]["Enums"]["quest_action"]
          active?: boolean
          created_at?: string
          created_by?: string | null
          description?: string | null
          ends_at?: string | null
          id?: string
          period: Database["public"]["Enums"]["quest_period"]
          reward_amount: number
          reward_currency?: Database["public"]["Enums"]["currency"]
          reward_xp?: number
          school_id?: string | null
          starts_at?: string | null
          target: number
          title: string
          updated_at?: string
        }
        Update: {
          action?: Database["public"]["Enums"]["quest_action"]
          active?: boolean
          created_at?: string
          created_by?: string | null
          description?: string | null
          ends_at?: string | null
          id?: string
          period?: Database["public"]["Enums"]["quest_period"]
          reward_amount?: number
          reward_currency?: Database["public"]["Enums"]["currency"]
          reward_xp?: number
          school_id?: string | null
          starts_at?: string | null
          target?: number
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "quests_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quests_school_id_fkey"
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
      trivia_duel_plays: {
        Row: {
          answers: number[] | null
          bet_id: string
          elapsed_ms: number | null
          player_id: string
          score: number | null
          started_at: string
          submitted_at: string | null
        }
        Insert: {
          answers?: number[] | null
          bet_id: string
          elapsed_ms?: number | null
          player_id: string
          score?: number | null
          started_at?: string
          submitted_at?: string | null
        }
        Update: {
          answers?: number[] | null
          bet_id?: string
          elapsed_ms?: number | null
          player_id?: string
          score?: number | null
          started_at?: string
          submitted_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "trivia_duel_plays_bet_id_fkey"
            columns: ["bet_id"]
            isOneToOne: false
            referencedRelation: "trivia_duels"
            referencedColumns: ["bet_id"]
          },
          {
            foreignKeyName: "trivia_duel_plays_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      trivia_duels: {
        Row: {
          accept_deadline: string
          bet_id: string
          challenger_id: string
          created_at: string
          invited_id: string | null
          opponent_id: string | null
          play_deadline: string | null
          question_ids: string[]
          school_id: string
          stake: number
        }
        Insert: {
          accept_deadline: string
          bet_id: string
          challenger_id: string
          created_at?: string
          invited_id?: string | null
          opponent_id?: string | null
          play_deadline?: string | null
          question_ids: string[]
          school_id: string
          stake: number
        }
        Update: {
          accept_deadline?: string
          bet_id?: string
          challenger_id?: string
          created_at?: string
          invited_id?: string | null
          opponent_id?: string | null
          play_deadline?: string | null
          question_ids?: string[]
          school_id?: string
          stake?: number
        }
        Relationships: [
          {
            foreignKeyName: "trivia_duels_bet_id_fkey"
            columns: ["bet_id"]
            isOneToOne: true
            referencedRelation: "bets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trivia_duels_challenger_id_fkey"
            columns: ["challenger_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trivia_duels_invited_id_fkey"
            columns: ["invited_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trivia_duels_opponent_id_fkey"
            columns: ["opponent_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trivia_duels_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "clusters"
            referencedColumns: ["id"]
          },
        ]
      }
      trivia_questions: {
        Row: {
          active: boolean
          category: string | null
          correct_index: number
          created_at: string
          created_by: string | null
          id: string
          options: string[]
          question: string
          school_id: string | null
          updated_at: string
        }
        Insert: {
          active?: boolean
          category?: string | null
          correct_index: number
          created_at?: string
          created_by?: string | null
          id?: string
          options: string[]
          question: string
          school_id?: string | null
          updated_at?: string
        }
        Update: {
          active?: boolean
          category?: string | null
          correct_index?: number
          created_at?: string
          created_by?: string | null
          id?: string
          options?: string[]
          question?: string
          school_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivia_questions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trivia_questions_school_id_fkey"
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
      user_inventory: {
        Row: {
          acquired_at: string
          category: Database["public"]["Enums"]["market_category"]
          currency: Database["public"]["Enums"]["currency"]
          equipped: boolean
          item_id: string
          price_paid: number
          user_id: string
        }
        Insert: {
          acquired_at?: string
          category: Database["public"]["Enums"]["market_category"]
          currency: Database["public"]["Enums"]["currency"]
          equipped?: boolean
          item_id: string
          price_paid: number
          user_id: string
        }
        Update: {
          acquired_at?: string
          category?: Database["public"]["Enums"]["market_category"]
          currency?: Database["public"]["Enums"]["currency"]
          equipped?: boolean
          item_id?: string
          price_paid?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_inventory_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "market_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_inventory_user_id_fkey"
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
      xp_events: {
        Row: {
          amount: number
          created_at: string
          id: number
          ledger_entry_id: number | null
          reason: Database["public"]["Enums"]["xp_reason"]
          user_id: string
          wager_id: string | null
          xp_after: number
        }
        Insert: {
          amount: number
          created_at?: string
          id?: never
          ledger_entry_id?: number | null
          reason: Database["public"]["Enums"]["xp_reason"]
          user_id: string
          wager_id?: string | null
          xp_after: number
        }
        Update: {
          amount?: number
          created_at?: string
          id?: never
          ledger_entry_id?: number | null
          reason?: Database["public"]["Enums"]["xp_reason"]
          user_id?: string
          wager_id?: string | null
          xp_after?: number
        }
        Relationships: [
          {
            foreignKeyName: "xp_events_ledger_entry_id_fkey"
            columns: ["ledger_entry_id"]
            isOneToOne: false
            referencedRelation: "ledger_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "xp_events_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "xp_events_wager_id_fkey"
            columns: ["wager_id"]
            isOneToOne: false
            referencedRelation: "wagers"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_trivia_duel: { Args: { p_bet_id: string }; Returns: undefined }
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
      cancel_daily_prediction: {
        Args: { p_bet_id: string; p_reason: string }
        Returns: undefined
      }
      cancel_official_bet: {
        Args: { p_bet_id: string; p_reason: string }
        Returns: undefined
      }
      cancel_social_bet: {
        Args: { p_bet_id: string; p_reason: string }
        Returns: undefined
      }
      claim_achievement: {
        Args: { p_key: string }
        Returns: {
          balance: number
          reward_sp: number
          reward_xp: number
        }[]
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
      claim_quest_reward: {
        Args: { p_quest_id: string }
        Returns: {
          balance: number
          reward_amount: number
          reward_currency: Database["public"]["Enums"]["currency"]
        }[]
      }
      confirm_student_email: {
        Args: { p_code: string }
        Returns: {
          attempts_left: number
          verified: boolean
        }[]
      }
      create_daily_prediction: {
        Args: {
          p_description?: string
          p_locks_at: string
          p_question: string
          p_school_id: string
        }
        Returns: string
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
          banned_at: string | null
          created_at: string
          deleted_at: string | null
          department: string | null
          first_name: string
          id: string
          last_name: string
          level: number
          referee_strikes: number
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
      create_social_bet: {
        Args: {
          p_cluster_id: string
          p_description: string
          p_locks_at: string
          p_max_stake?: number
          p_options: string[]
          p_referee_id?: string
          p_title: string
        }
        Returns: string
      }
      create_trivia_duel: {
        Args: { p_invited_id?: string; p_stake: number }
        Returns: string
      }
      daily_login_calendar: {
        Args: never
        Returns: {
          amount: number
          bonus: number
          claimed: boolean
          day: number
          is_today: boolean
        }[]
      }
      delete_my_account: { Args: never; Returns: undefined }
      dispute_social_result: {
        Args: { p_bet_id: string; p_reason: string }
        Returns: string
      }
      export_my_data: { Args: never; Returns: Json }
      get_leaderboard: {
        Args: {
          p_limit?: number
          p_metric: Database["public"]["Enums"]["leaderboard_metric"]
          p_period: Database["public"]["Enums"]["leaderboard_period"]
          p_school_id?: string
          p_weeks_ago?: number
        }
        Returns: {
          badge: string
          badge_name: string
          computed_at: string
          first_name: string
          frame_color: string
          is_me: boolean
          last_name: string
          level: number
          name_color: string
          period_start: string
          rank: number
          sample: number
          title: string
          title_icon: string
          user_id: string
          value: number
        }[]
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
      my_achievements: {
        Args: never
        Returns: {
          category: Database["public"]["Enums"]["achievement_category"]
          claimable: boolean
          description: string
          hidden: boolean
          icon: string
          key: string
          metric: string
          progress: number
          reward_sp: number
          reward_xp: number
          school_rate: number
          target: number
          tier: number
          title: string
          unlocked_at: string
        }[]
      }
      my_progress: {
        Args: never
        Returns: {
          level: number
          level_xp: number
          next_level_xp: number
          pick_xp_today: number
          xp: number
        }[]
      }
      my_quests: {
        Args: never
        Returns: {
          action: Database["public"]["Enums"]["quest_action"]
          claimed: boolean
          description: string
          period: Database["public"]["Enums"]["quest_period"]
          period_ends_at: string
          progress: number
          quest_id: string
          reward_amount: number
          reward_currency: Database["public"]["Enums"]["currency"]
          reward_xp: number
          target: number
          title: string
        }[]
      }
      my_stats: {
        Args: never
        Returns: {
          best_streak: number
          correct: number
          current_streak: number
          duels_played: number
          duels_won: number
          open_wagers: number
          predictions: number
          sp_profit: number
          ssp_profit: number
          week_rank_best_streak: number
          week_rank_hit_rate: number
          week_rank_sp_profit: number
        }[]
      }
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
      purchase_market_item: { Args: { p_item_id: string }; Returns: number }
      request_student_email_code: {
        Args: { p_email: string }
        Returns: {
          email: string
          expires_at: string
        }[]
      }
      reset_referee_strikes: {
        Args: { p_note: string; p_user_id: string }
        Returns: undefined
      }
      resolve_social_dispute: {
        Args: {
          p_bet_id: string
          p_decision: Database["public"]["Enums"]["dispute_decision"]
          p_note: string
          p_option_id?: string
        }
        Returns: undefined
      }
      revoke_permission: {
        Args: {
          p_key: Database["public"]["Enums"]["permission_key"]
          p_school_id: string
          p_user_id: string
        }
        Returns: undefined
      }
      save_achievement: {
        Args: {
          p_active: boolean
          p_category: Database["public"]["Enums"]["achievement_category"]
          p_description: string
          p_hidden: boolean
          p_icon: string
          p_id: string
          p_key: string
          p_metric: string
          p_reward_sp: number
          p_reward_xp: number
          p_sort: number
          p_target: number
          p_tier: number
          p_title: string
        }
        Returns: string
      }
      save_market_item: {
        Args: {
          p_active?: boolean
          p_available_from?: string
          p_available_until?: string
          p_category: Database["public"]["Enums"]["market_category"]
          p_color?: string
          p_currency: Database["public"]["Enums"]["currency"]
          p_description: string
          p_icon?: string
          p_id: string
          p_min_level?: number
          p_name: string
          p_price: number
          p_school_id: string
        }
        Returns: string
      }
      save_quest: {
        Args: {
          p_action: Database["public"]["Enums"]["quest_action"]
          p_active?: boolean
          p_description: string
          p_ends_at?: string
          p_id: string
          p_period: Database["public"]["Enums"]["quest_period"]
          p_reward_amount: number
          p_reward_currency: Database["public"]["Enums"]["currency"]
          p_reward_xp?: number
          p_school_id: string
          p_starts_at?: string
          p_target: number
          p_title: string
        }
        Returns: string
      }
      save_trivia_question: {
        Args: {
          p_active?: boolean
          p_category?: string
          p_correct_index: number
          p_id: string
          p_options: string[]
          p_question: string
          p_school_id: string
        }
        Returns: string
      }
      school_stats: {
        Args: { p_school_id: string }
        Returns: {
          active_this_week: number
          market_purchases_this_week: number
          members: number
          open_bets: number
          open_disputes: number
          quest_claims_this_week: number
          sp_staked_this_week: number
          ssp_staked_this_week: number
          verified_members: number
          wagers_this_week: number
          week_start: string
        }[]
      }
      search_schoolmates: {
        Args: { p_query: string }
        Returns: {
          can_referee: boolean
          department: string
          first_name: string
          last_name: string
          level: number
          user_id: string
        }[]
      }
      set_item_equipped: {
        Args: { p_equipped: boolean; p_item_id: string }
        Returns: undefined
      }
      set_leaderboard_hidden: {
        Args: { p_hidden: boolean }
        Returns: undefined
      }
      set_user_ban: {
        Args: { p_banned: boolean; p_reason?: string; p_user_id: string }
        Returns: undefined
      }
      settle_daily_prediction: {
        Args: { p_bet_id: string; p_winning_option_id: string }
        Returns: undefined
      }
      settle_official_bet: {
        Args: { p_bet_id: string; p_winning_option_id: string }
        Returns: undefined
      }
      start_trivia_duel: {
        Args: { p_bet_id: string }
        Returns: {
          options: string[]
          question: string
          question_no: number
          seconds_left: number
        }[]
      }
      submit_social_result: {
        Args: { p_bet_id: string; p_option_id: string }
        Returns: string
      }
      submit_trivia_answers: {
        Args: { p_answers: number[]; p_bet_id: string }
        Returns: {
          late: boolean
          score: number
        }[]
      }
      trivia_duel_review: {
        Args: { p_bet_id: string }
        Returns: {
          correct_index: number
          my_answer: number
          opponent_answer: number
          options: string[]
          question: string
          question_no: number
        }[]
      }
      update_official_bet_odds: {
        Args: { p_bet_id: string; p_odds: number[] }
        Returns: undefined
      }
    }
    Enums: {
      achievement_category:
        | "prediction"
        | "streak"
        | "duel"
        | "social"
        | "loyalty"
        | "progress"
        | "secret"
      bet_scope: "private" | "school" | "cross_school" | "global"
      bet_status: "open" | "locked" | "settling" | "settled" | "cancelled"
      bet_type: "ssp_official" | "sp_minigame" | "sp_social"
      cluster_type: "school" | "department" | "club" | "group"
      currency: "SP" | "SSP"
      dispute_decision: "confirmed" | "changed" | "cancelled"
      dispute_status: "open" | "resolved"
      leaderboard_metric:
        | "hit_rate"
        | "sp_profit"
        | "ssp_profit"
        | "best_streak"
      leaderboard_period: "week" | "all_time"
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
        | "achievement_reward"
      ledger_ref_type:
        | "bet"
        | "wager"
        | "quest"
        | "market_item"
        | "achievement"
      market_category: "title" | "badge" | "frame" | "name_color"
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
        | "trivia_yonet"
      quest_action: "wager" | "prediction" | "duel" | "social_bet" | "win"
      quest_period: "daily" | "weekly" | "seasonal"
      settlement_mode: "auto" | "admin" | "referee"
      user_role: "student" | "yetkili" | "superadmin"
      xp_reason:
        | "daily_login"
        | "quest"
        | "correct_pick"
        | "achievement"
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
      achievement_category: [
        "prediction",
        "streak",
        "duel",
        "social",
        "loyalty",
        "progress",
        "secret",
      ],
      bet_scope: ["private", "school", "cross_school", "global"],
      bet_status: ["open", "locked", "settling", "settled", "cancelled"],
      bet_type: ["ssp_official", "sp_minigame", "sp_social"],
      cluster_type: ["school", "department", "club", "group"],
      currency: ["SP", "SSP"],
      dispute_decision: ["confirmed", "changed", "cancelled"],
      dispute_status: ["open", "resolved"],
      leaderboard_metric: [
        "hit_rate",
        "sp_profit",
        "ssp_profit",
        "best_streak",
      ],
      leaderboard_period: ["week", "all_time"],
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
        "achievement_reward",
      ],
      ledger_ref_type: [
        "bet",
        "wager",
        "quest",
        "market_item",
        "achievement",
      ],
      market_category: ["title", "badge", "frame", "name_color"],
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
        "trivia_yonet",
      ],
      quest_action: ["wager", "prediction", "duel", "social_bet", "win"],
      quest_period: ["daily", "weekly", "seasonal"],
      settlement_mode: ["auto", "admin", "referee"],
      user_role: ["student", "yetkili", "superadmin"],
      xp_reason: [
        "daily_login",
        "quest",
        "correct_pick",
        "achievement",
      ],
    },
  },
} as const

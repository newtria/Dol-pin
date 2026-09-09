export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
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
      chat_messages: {
        Row: {
          created_at: string | null
          id: string
          image_url: string | null
          location: Json | null
          message: string | null
          read_at: string | null
          receiver_id: string
          reservation_id: string | null
          room_id: string | null
          sender_id: string
          source_lang: string | null
          translated_message: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          image_url?: string | null
          location?: Json | null
          message?: string | null
          read_at?: string | null
          receiver_id: string
          reservation_id?: string | null
          room_id?: string | null
          sender_id: string
          source_lang?: string | null
          translated_message?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          image_url?: string | null
          location?: Json | null
          message?: string | null
          read_at?: string | null
          receiver_id?: string
          reservation_id?: string | null
          room_id?: string | null
          sender_id?: string
          source_lang?: string | null
          translated_message?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_messages_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_reservation_id_fkey"
            columns: ["reservation_id"]
            isOneToOne: false
            referencedRelation: "reservations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "chat_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_rooms: {
        Row: {
          created_at: string | null
          id: string
          item_id: string | null
          last_message: string | null
          last_message_at: string | null
          participant_1: string
          participant_2: string
          reservation_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          item_id?: string | null
          last_message?: string | null
          last_message_at?: string | null
          participant_1: string
          participant_2: string
          reservation_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          item_id?: string | null
          last_message?: string | null
          last_message_at?: string | null
          participant_1?: string
          participant_2?: string
          reservation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_rooms_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "rental_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_rooms_participant_1_fkey"
            columns: ["participant_1"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_rooms_participant_1_fkey"
            columns: ["participant_1"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_rooms_participant_2_fkey"
            columns: ["participant_2"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_rooms_participant_2_fkey"
            columns: ["participant_2"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_rooms_reservation_id_fkey"
            columns: ["reservation_id"]
            isOneToOne: false
            referencedRelation: "reservations"
            referencedColumns: ["id"]
          },
        ]
      }
      concerts: {
        Row: {
          artist: string
          city: string
          concert_date: string
          country: string
          created_at: string | null
          id: string
          poster_url: string | null
          title: string
          venue: string
        }
        Insert: {
          artist: string
          city: string
          concert_date: string
          country: string
          created_at?: string | null
          id?: string
          poster_url?: string | null
          title: string
          venue: string
        }
        Update: {
          artist?: string
          city?: string
          concert_date?: string
          country?: string
          created_at?: string | null
          id?: string
          poster_url?: string | null
          title?: string
          venue?: string
        }
        Relationships: []
      }
      fraud_flags: {
        Row: {
          created_at: string | null
          details: Json | null
          flag_type: string
          id: string
          severity: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          details?: Json | null
          flag_type: string
          id?: string
          severity?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          details?: Json | null
          flag_type?: string
          id?: string
          severity?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fraud_flags_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fraud_flags_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      rental_events: {
        Row: {
          actor_id: string | null
          command: string
          created_at: string
          from_status: Database["public"]["Enums"]["reservation_status"] | null
          id: number
          reservation_id: string
          to_status: Database["public"]["Enums"]["reservation_status"]
        }
        Insert: {
          actor_id?: string | null
          command: string
          created_at?: string
          from_status?: Database["public"]["Enums"]["reservation_status"] | null
          id?: never
          reservation_id: string
          to_status: Database["public"]["Enums"]["reservation_status"]
        }
        Update: {
          actor_id?: string | null
          command?: string
          created_at?: string
          from_status?: Database["public"]["Enums"]["reservation_status"] | null
          id?: never
          reservation_id?: string
          to_status?: Database["public"]["Enums"]["reservation_status"]
        }
        Relationships: [
          {
            foreignKeyName: "rental_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rental_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rental_events_reservation_id_fkey"
            columns: ["reservation_id"]
            isOneToOne: false
            referencedRelation: "reservations"
            referencedColumns: ["id"]
          },
        ]
      }
      rental_items: {
        Row: {
          available_from: string | null
          available_to: string | null
          bt_verified: boolean | null
          category: string
          concert_id: string | null
          condition_grade: string | null
          created_at: string | null
          currency: string
          daily_price: number
          deposit: number
          description: string | null
          id: string
          imei: string | null
          imei_verified: boolean | null
          lender_id: string
          photos: string[]
          pickup_location: Json | null
          pickup_method: string
          status: string | null
          title: string
          updated_at: string | null
          vlm_tag: string | null
        }
        Insert: {
          available_from?: string | null
          available_to?: string | null
          bt_verified?: boolean | null
          category: string
          concert_id?: string | null
          condition_grade?: string | null
          created_at?: string | null
          currency: string
          daily_price: number
          deposit: number
          description?: string | null
          id?: string
          imei?: string | null
          imei_verified?: boolean | null
          lender_id: string
          photos: string[]
          pickup_location?: Json | null
          pickup_method: string
          status?: string | null
          title: string
          updated_at?: string | null
          vlm_tag?: string | null
        }
        Update: {
          available_from?: string | null
          available_to?: string | null
          bt_verified?: boolean | null
          category?: string
          concert_id?: string | null
          condition_grade?: string | null
          created_at?: string | null
          currency?: string
          daily_price?: number
          deposit?: number
          description?: string | null
          id?: string
          imei?: string | null
          imei_verified?: boolean | null
          lender_id?: string
          photos?: string[]
          pickup_location?: Json | null
          pickup_method?: string
          status?: string | null
          title?: string
          updated_at?: string | null
          vlm_tag?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "rental_items_concert_id_fkey"
            columns: ["concert_id"]
            isOneToOne: false
            referencedRelation: "concerts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rental_items_lender_id_fkey"
            columns: ["lender_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rental_items_lender_id_fkey"
            columns: ["lender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          reason: string
          reported_item_id: string | null
          reported_user_id: string | null
          reporter_id: string
          resolved_at: string | null
          status: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          reason: string
          reported_item_id?: string | null
          reported_user_id?: string | null
          reporter_id: string
          resolved_at?: string | null
          status?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          reason?: string
          reported_item_id?: string | null
          reported_user_id?: string | null
          reporter_id?: string
          resolved_at?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reports_reported_item_id_fkey"
            columns: ["reported_item_id"]
            isOneToOne: false
            referencedRelation: "rental_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_reported_user_id_fkey"
            columns: ["reported_user_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_reported_user_id_fkey"
            columns: ["reported_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      reservation_dispute_resolutions: {
        Row: {
          actor_id: string | null
          created_at: string | null
          id: string
          idempotency_key: string
          provider_refund_id: string | null
          reason: string
          refund_amount: number
          reservation_id: string
        }
        Insert: {
          actor_id?: string | null
          created_at?: string | null
          id?: string
          idempotency_key: string
          provider_refund_id?: string | null
          reason: string
          refund_amount: number
          reservation_id: string
        }
        Update: {
          actor_id?: string | null
          created_at?: string | null
          id?: string
          idempotency_key?: string
          provider_refund_id?: string | null
          reason?: string
          refund_amount?: number
          reservation_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reservation_dispute_resolutions_reservation_id_fkey"
            columns: ["reservation_id"]
            isOneToOne: false
            referencedRelation: "reservations"
            referencedColumns: ["id"]
          },
        ]
      }
      reservation_transitions: {
        Row: {
          actor_kind: string
          from_status: Database["public"]["Enums"]["reservation_status"]
          to_status: Database["public"]["Enums"]["reservation_status"]
        }
        Insert: {
          actor_kind: string
          from_status: Database["public"]["Enums"]["reservation_status"]
          to_status: Database["public"]["Enums"]["reservation_status"]
        }
        Update: {
          actor_kind?: string
          from_status?: Database["public"]["Enums"]["reservation_status"]
          to_status?: Database["public"]["Enums"]["reservation_status"]
        }
        Relationships: []
      }
      reservations: {
        Row: {
          accepted_at: string | null
          borrower_id: string
          client_request_id: string | null
          created_at: string | null
          currency: string
          deposit: number
          ends_at: string | null
          id: string
          item_id: string
          lender_id: string
          payment_action: string | null
          payment_action_started_at: string | null
          payment_attempt_merchant_uid: string | null
          payment_attempt_started_at: string | null
          payment_due_at: string | null
          payment_id: string | null
          payment_provider: string | null
          pickup_confirmed_at: string | null
          quoted_item_version: string | null
          rental_date: string
          rental_fee: number
          return_confirmed_at: string | null
          return_date: string
          return_photo: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["reservation_status"] | null
          terms_snapshot: Json | null
          total_paid: number
          updated_at: string | null
        }
        Insert: {
          accepted_at?: string | null
          borrower_id: string
          client_request_id?: string | null
          created_at?: string | null
          currency: string
          deposit: number
          ends_at?: string | null
          id?: string
          item_id: string
          lender_id: string
          payment_action?: string | null
          payment_action_started_at?: string | null
          payment_attempt_merchant_uid?: string | null
          payment_attempt_started_at?: string | null
          payment_due_at?: string | null
          payment_id?: string | null
          payment_provider?: string | null
          pickup_confirmed_at?: string | null
          quoted_item_version?: string | null
          rental_date: string
          rental_fee: number
          return_confirmed_at?: string | null
          return_date: string
          return_photo?: string | null
          starts_at?: string | null
          status?: Database["public"]["Enums"]["reservation_status"] | null
          terms_snapshot?: Json | null
          total_paid: number
          updated_at?: string | null
        }
        Update: {
          accepted_at?: string | null
          borrower_id?: string
          client_request_id?: string | null
          created_at?: string | null
          currency?: string
          deposit?: number
          ends_at?: string | null
          id?: string
          item_id?: string
          lender_id?: string
          payment_action?: string | null
          payment_action_started_at?: string | null
          payment_attempt_merchant_uid?: string | null
          payment_attempt_started_at?: string | null
          payment_due_at?: string | null
          payment_id?: string | null
          payment_provider?: string | null
          pickup_confirmed_at?: string | null
          quoted_item_version?: string | null
          rental_date?: string
          rental_fee?: number
          return_confirmed_at?: string | null
          return_date?: string
          return_photo?: string | null
          starts_at?: string | null
          status?: Database["public"]["Enums"]["reservation_status"] | null
          terms_snapshot?: Json | null
          total_paid?: number
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reservations_borrower_id_fkey"
            columns: ["borrower_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reservations_borrower_id_fkey"
            columns: ["borrower_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reservations_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "rental_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reservations_lender_id_fkey"
            columns: ["lender_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reservations_lender_id_fkey"
            columns: ["lender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      reviews: {
        Row: {
          content: string | null
          created_at: string | null
          id: string
          rating: number
          reservation_id: string
          review_type: string
          reviewee_id: string
          reviewer_id: string
        }
        Insert: {
          content?: string | null
          created_at?: string | null
          id?: string
          rating: number
          reservation_id: string
          review_type: string
          reviewee_id: string
          reviewer_id: string
        }
        Update: {
          content?: string | null
          created_at?: string | null
          id?: string
          rating?: number
          reservation_id?: string
          review_type?: string
          reviewee_id?: string
          reviewer_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reviews_reservation_id_fkey"
            columns: ["reservation_id"]
            isOneToOne: false
            referencedRelation: "reservations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_reviewee_id_fkey"
            columns: ["reviewee_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_reviewee_id_fkey"
            columns: ["reviewee_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_reviewer_id_fkey"
            columns: ["reviewer_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_reviewer_id_fkey"
            columns: ["reviewer_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_blocks: {
        Row: {
          blocked_id: string
          blocker_id: string
          created_at: string | null
          id: string
        }
        Insert: {
          blocked_id: string
          blocker_id: string
          created_at?: string | null
          id?: string
        }
        Update: {
          blocked_id?: string
          blocker_id?: string
          created_at?: string | null
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "public_user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          country: string
          created_at: string | null
          currency: string | null
          deleted_at: string | null
          fav_groups: string[] | null
          fcm_token: string | null
          id: string
          identity_verified: boolean | null
          is_lender: boolean | null
          lender_grade: string | null
          locale: string | null
          nickname: string
          phone: string | null
          profile_image: string | null
          region: string | null
          response_rate: number | null
        }
        Insert: {
          country: string
          created_at?: string | null
          currency?: string | null
          deleted_at?: string | null
          fav_groups?: string[] | null
          fcm_token?: string | null
          id?: string
          identity_verified?: boolean | null
          is_lender?: boolean | null
          lender_grade?: string | null
          locale?: string | null
          nickname: string
          phone?: string | null
          profile_image?: string | null
          region?: string | null
          response_rate?: number | null
        }
        Update: {
          country?: string
          created_at?: string | null
          currency?: string | null
          deleted_at?: string | null
          fav_groups?: string[] | null
          fcm_token?: string | null
          id?: string
          identity_verified?: boolean | null
          is_lender?: boolean | null
          lender_grade?: string | null
          locale?: string | null
          nickname?: string
          phone?: string | null
          profile_image?: string | null
          region?: string | null
          response_rate?: number | null
        }
        Relationships: []
      }
    }
    Views: {
      public_user_profiles: {
        Row: {
          created_at: string | null
          id: string | null
          is_lender: boolean | null
          lender_grade: string | null
          nickname: string | null
          profile_image: string | null
          response_rate: number | null
        }
        Insert: {
          created_at?: string | null
          id?: string | null
          is_lender?: boolean | null
          lender_grade?: string | null
          nickname?: string | null
          profile_image?: string | null
          response_rate?: number | null
        }
        Update: {
          created_at?: string | null
          id?: string | null
          is_lender?: boolean | null
          lender_grade?: string | null
          nickname?: string | null
          profile_image?: string | null
          response_rate?: number | null
        }
        Relationships: []
      }
    }
    Functions: {
      begin_reservation_payment_action: {
        Args: {
          p_action: string
          p_actor_id: string
          p_payment_id: string
          p_reservation_id: string
        }
        Returns: Json
      }
      clear_reservation_payment_action: {
        Args: { p_action: string; p_reservation_id: string }
        Returns: Json
      }
      confirm_reservation_return: {
        Args: { p_reservation_id: string; p_return_photo: string }
        Returns: Json
      }
      create_reservation_intent: {
        Args: {
          p_item_id: string
          p_rental_date: string
          p_return_date: string
        }
        Returns: {
          accepted_at: string | null
          borrower_id: string
          client_request_id: string | null
          created_at: string | null
          currency: string
          deposit: number
          ends_at: string | null
          id: string
          item_id: string
          lender_id: string
          payment_action: string | null
          payment_action_started_at: string | null
          payment_attempt_merchant_uid: string | null
          payment_attempt_started_at: string | null
          payment_due_at: string | null
          payment_id: string | null
          payment_provider: string | null
          pickup_confirmed_at: string | null
          quoted_item_version: string | null
          rental_date: string
          rental_fee: number
          return_confirmed_at: string | null
          return_date: string
          return_photo: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["reservation_status"] | null
          terms_snapshot: Json | null
          total_paid: number
          updated_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "reservations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      ensure_profile: {
        Args: { p_nickname: string }
        Returns: {
          country: string
          created_at: string | null
          currency: string | null
          deleted_at: string | null
          fav_groups: string[] | null
          fcm_token: string | null
          id: string
          identity_verified: boolean | null
          is_lender: boolean | null
          lender_grade: string | null
          locale: string | null
          nickname: string
          phone: string | null
          profile_image: string | null
          region: string | null
          response_rate: number | null
        }
        SetofOptions: {
          from: "*"
          to: "users"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      expire_stale_pending_reservations: { Args: never; Returns: number }
      expire_unpaid_rentals: { Args: never; Returns: number }
      get_chat_list: {
        Args: { p_user_id: string }
        Returns: {
          last_message: string
          last_message_at: string
          partner_id: string
          partner_image: string
          partner_nickname: string
          room_id: string
          unread_count: number
        }[]
      }
      get_or_create_room: {
        Args: {
          p_item_id?: string
          p_reservation_id?: string
          user_a: string
          user_b: string
        }
        Returns: string
      }
      mark_reservation_paid: {
        Args: {
          p_payment_id: string
          p_provider?: string
          p_reservation_id: string
        }
        Returns: Json
      }
      request_rental: {
        Args: {
          p_ends_at: string
          p_item_id: string
          p_item_version: string
          p_request_id: string
          p_starts_at: string
        }
        Returns: {
          accepted_at: string | null
          borrower_id: string
          client_request_id: string | null
          created_at: string | null
          currency: string
          deposit: number
          ends_at: string | null
          id: string
          item_id: string
          lender_id: string
          payment_action: string | null
          payment_action_started_at: string | null
          payment_attempt_merchant_uid: string | null
          payment_attempt_started_at: string | null
          payment_due_at: string | null
          payment_id: string | null
          payment_provider: string | null
          pickup_confirmed_at: string | null
          quoted_item_version: string | null
          rental_date: string
          rental_fee: number
          return_confirmed_at: string | null
          return_date: string
          return_photo: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["reservation_status"] | null
          terms_snapshot: Json | null
          total_paid: number
          updated_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "reservations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      respond_to_rental: {
        Args: { p_action: string; p_reservation_id: string }
        Returns: {
          accepted_at: string | null
          borrower_id: string
          client_request_id: string | null
          created_at: string | null
          currency: string
          deposit: number
          ends_at: string | null
          id: string
          item_id: string
          lender_id: string
          payment_action: string | null
          payment_action_started_at: string | null
          payment_attempt_merchant_uid: string | null
          payment_attempt_started_at: string | null
          payment_due_at: string | null
          payment_id: string | null
          payment_provider: string | null
          pickup_confirmed_at: string | null
          quoted_item_version: string | null
          rental_date: string
          rental_fee: number
          return_confirmed_at: string | null
          return_date: string
          return_photo: string | null
          starts_at: string | null
          status: Database["public"]["Enums"]["reservation_status"] | null
          terms_snapshot: Json | null
          total_paid: number
          updated_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "reservations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      start_reservation_payment_attempt: {
        Args: { p_merchant_uid: string; p_reservation_id: string }
        Returns: Json
      }
      transition_reservation_status: {
        Args: {
          p_actor_id?: string
          p_actor_kind?: string
          p_reason?: string
          p_reservation_id: string
          p_target: Database["public"]["Enums"]["reservation_status"]
        }
        Returns: Json
      }
    }
    Enums: {
      reservation_status:
        | "pending"
        | "paid"
        | "picked_up"
        | "returned"
        | "settled"
        | "cancelled"
        | "disputed"
        | "resolved"
        | "requested"
        | "accepted"
        | "rejected"
        | "expired"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  storage: {
    Tables: {
      buckets: {
        Row: {
          allowed_mime_types: string[] | null
          avif_autodetection: boolean | null
          created_at: string | null
          file_size_limit: number | null
          id: string
          name: string
          owner: string | null
          owner_id: string | null
          public: boolean | null
          type: Database["storage"]["Enums"]["buckettype"]
          updated_at: string | null
        }
        Insert: {
          allowed_mime_types?: string[] | null
          avif_autodetection?: boolean | null
          created_at?: string | null
          file_size_limit?: number | null
          id: string
          name: string
          owner?: string | null
          owner_id?: string | null
          public?: boolean | null
          type?: Database["storage"]["Enums"]["buckettype"]
          updated_at?: string | null
        }
        Update: {
          allowed_mime_types?: string[] | null
          avif_autodetection?: boolean | null
          created_at?: string | null
          file_size_limit?: number | null
          id?: string
          name?: string
          owner?: string | null
          owner_id?: string | null
          public?: boolean | null
          type?: Database["storage"]["Enums"]["buckettype"]
          updated_at?: string | null
        }
        Relationships: []
      }
      buckets_analytics: {
        Row: {
          created_at: string
          deleted_at: string | null
          format: string
          id: string
          name: string
          type: Database["storage"]["Enums"]["buckettype"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          format?: string
          id?: string
          name: string
          type?: Database["storage"]["Enums"]["buckettype"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          format?: string
          id?: string
          name?: string
          type?: Database["storage"]["Enums"]["buckettype"]
          updated_at?: string
        }
        Relationships: []
      }
      buckets_vectors: {
        Row: {
          created_at: string
          id: string
          type: Database["storage"]["Enums"]["buckettype"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          id: string
          type?: Database["storage"]["Enums"]["buckettype"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          type?: Database["storage"]["Enums"]["buckettype"]
          updated_at?: string
        }
        Relationships: []
      }
      iceberg_namespaces: {
        Row: {
          bucket_name: string
          catalog_id: string
          created_at: string
          id: string
          metadata: Json
          name: string
          updated_at: string
        }
        Insert: {
          bucket_name: string
          catalog_id: string
          created_at?: string
          id?: string
          metadata?: Json
          name: string
          updated_at?: string
        }
        Update: {
          bucket_name?: string
          catalog_id?: string
          created_at?: string
          id?: string
          metadata?: Json
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "iceberg_namespaces_catalog_id_fkey"
            columns: ["catalog_id"]
            isOneToOne: false
            referencedRelation: "buckets_analytics"
            referencedColumns: ["id"]
          },
        ]
      }
      iceberg_tables: {
        Row: {
          bucket_name: string
          catalog_id: string
          created_at: string
          id: string
          location: string
          name: string
          namespace_id: string
          remote_table_id: string | null
          shard_id: string | null
          shard_key: string | null
          updated_at: string
        }
        Insert: {
          bucket_name: string
          catalog_id: string
          created_at?: string
          id?: string
          location: string
          name: string
          namespace_id: string
          remote_table_id?: string | null
          shard_id?: string | null
          shard_key?: string | null
          updated_at?: string
        }
        Update: {
          bucket_name?: string
          catalog_id?: string
          created_at?: string
          id?: string
          location?: string
          name?: string
          namespace_id?: string
          remote_table_id?: string | null
          shard_id?: string | null
          shard_key?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "iceberg_tables_catalog_id_fkey"
            columns: ["catalog_id"]
            isOneToOne: false
            referencedRelation: "buckets_analytics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "iceberg_tables_namespace_id_fkey"
            columns: ["namespace_id"]
            isOneToOne: false
            referencedRelation: "iceberg_namespaces"
            referencedColumns: ["id"]
          },
        ]
      }
      migrations: {
        Row: {
          executed_at: string | null
          hash: string
          id: number
          name: string
        }
        Insert: {
          executed_at?: string | null
          hash: string
          id: number
          name: string
        }
        Update: {
          executed_at?: string | null
          hash?: string
          id?: number
          name?: string
        }
        Relationships: []
      }
      objects: {
        Row: {
          bucket_id: string | null
          created_at: string | null
          id: string
          last_accessed_at: string | null
          metadata: Json | null
          name: string | null
          owner: string | null
          owner_id: string | null
          path_tokens: string[] | null
          updated_at: string | null
          user_metadata: Json | null
          version: string | null
        }
        Insert: {
          bucket_id?: string | null
          created_at?: string | null
          id?: string
          last_accessed_at?: string | null
          metadata?: Json | null
          name?: string | null
          owner?: string | null
          owner_id?: string | null
          path_tokens?: string[] | null
          updated_at?: string | null
          user_metadata?: Json | null
          version?: string | null
        }
        Update: {
          bucket_id?: string | null
          created_at?: string | null
          id?: string
          last_accessed_at?: string | null
          metadata?: Json | null
          name?: string | null
          owner?: string | null
          owner_id?: string | null
          path_tokens?: string[] | null
          updated_at?: string | null
          user_metadata?: Json | null
          version?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "objects_bucketId_fkey"
            columns: ["bucket_id"]
            isOneToOne: false
            referencedRelation: "buckets"
            referencedColumns: ["id"]
          },
        ]
      }
      s3_multipart_uploads: {
        Row: {
          bucket_id: string
          created_at: string
          id: string
          in_progress_size: number
          key: string
          metadata: Json | null
          owner_id: string | null
          upload_signature: string
          user_metadata: Json | null
          version: string
        }
        Insert: {
          bucket_id: string
          created_at?: string
          id: string
          in_progress_size?: number
          key: string
          metadata?: Json | null
          owner_id?: string | null
          upload_signature: string
          user_metadata?: Json | null
          version: string
        }
        Update: {
          bucket_id?: string
          created_at?: string
          id?: string
          in_progress_size?: number
          key?: string
          metadata?: Json | null
          owner_id?: string | null
          upload_signature?: string
          user_metadata?: Json | null
          version?: string
        }
        Relationships: [
          {
            foreignKeyName: "s3_multipart_uploads_bucket_id_fkey"
            columns: ["bucket_id"]
            isOneToOne: false
            referencedRelation: "buckets"
            referencedColumns: ["id"]
          },
        ]
      }
      s3_multipart_uploads_parts: {
        Row: {
          bucket_id: string
          created_at: string
          etag: string
          id: string
          key: string
          owner_id: string | null
          part_number: number
          size: number
          upload_id: string
          version: string
        }
        Insert: {
          bucket_id: string
          created_at?: string
          etag: string
          id?: string
          key: string
          owner_id?: string | null
          part_number: number
          size?: number
          upload_id: string
          version: string
        }
        Update: {
          bucket_id?: string
          created_at?: string
          etag?: string
          id?: string
          key?: string
          owner_id?: string | null
          part_number?: number
          size?: number
          upload_id?: string
          version?: string
        }
        Relationships: [
          {
            foreignKeyName: "s3_multipart_uploads_parts_bucket_id_fkey"
            columns: ["bucket_id"]
            isOneToOne: false
            referencedRelation: "buckets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "s3_multipart_uploads_parts_upload_id_fkey"
            columns: ["upload_id"]
            isOneToOne: false
            referencedRelation: "s3_multipart_uploads"
            referencedColumns: ["id"]
          },
        ]
      }
      vector_indexes: {
        Row: {
          bucket_id: string
          created_at: string
          data_type: string
          dimension: number
          distance_metric: string
          id: string
          metadata_configuration: Json | null
          name: string
          updated_at: string
        }
        Insert: {
          bucket_id: string
          created_at?: string
          data_type: string
          dimension: number
          distance_metric: string
          id?: string
          metadata_configuration?: Json | null
          name: string
          updated_at?: string
        }
        Update: {
          bucket_id?: string
          created_at?: string
          data_type?: string
          dimension?: number
          distance_metric?: string
          id?: string
          metadata_configuration?: Json | null
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "vector_indexes_bucket_id_fkey"
            columns: ["bucket_id"]
            isOneToOne: false
            referencedRelation: "buckets_vectors"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      allow_any_operation: {
        Args: { expected_operations: string[] }
        Returns: boolean
      }
      allow_only_operation: {
        Args: { expected_operation: string }
        Returns: boolean
      }
      can_insert_object: {
        Args: { bucketid: string; metadata: Json; name: string; owner: string }
        Returns: undefined
      }
      extension: { Args: { name: string }; Returns: string }
      filename: { Args: { name: string }; Returns: string }
      foldername: { Args: { name: string }; Returns: string[] }
      get_common_prefix: {
        Args: { p_delimiter: string; p_key: string; p_prefix: string }
        Returns: string
      }
      get_size_by_bucket: {
        Args: never
        Returns: {
          bucket_id: string
          size: number
        }[]
      }
      list_multipart_uploads_with_delimiter: {
        Args: {
          bucket_id: string
          delimiter_param: string
          max_keys?: number
          next_key_token?: string
          next_upload_token?: string
          prefix_param: string
        }
        Returns: {
          created_at: string
          id: string
          key: string
        }[]
      }
      list_objects_with_delimiter: {
        Args: {
          _bucket_id: string
          delimiter_param: string
          max_keys?: number
          next_token?: string
          prefix_param: string
          sort_order?: string
          start_after?: string
        }
        Returns: {
          created_at: string
          id: string
          last_accessed_at: string
          metadata: Json
          name: string
          updated_at: string
        }[]
      }
      operation: { Args: never; Returns: string }
      search: {
        Args: {
          bucketname: string
          levels?: number
          limits?: number
          offsets?: number
          prefix: string
          search?: string
          sortcolumn?: string
          sortorder?: string
        }
        Returns: {
          created_at: string
          id: string
          last_accessed_at: string
          metadata: Json
          name: string
          updated_at: string
        }[]
      }
      search_by_timestamp: {
        Args: {
          p_bucket_id: string
          p_level: number
          p_limit: number
          p_prefix: string
          p_sort_column: string
          p_sort_column_after: string
          p_sort_order: string
          p_start_after: string
        }
        Returns: {
          created_at: string
          id: string
          key: string
          last_accessed_at: string
          metadata: Json
          name: string
          updated_at: string
        }[]
      }
      search_v2: {
        Args: {
          bucket_name: string
          levels?: number
          limits?: number
          prefix: string
          sort_column?: string
          sort_column_after?: string
          sort_order?: string
          start_after?: string
        }
        Returns: {
          created_at: string
          id: string
          key: string
          last_accessed_at: string
          metadata: Json
          name: string
          updated_at: string
        }[]
      }
    }
    Enums: {
      buckettype: "STANDARD" | "ANALYTICS" | "VECTOR"
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
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      reservation_status: [
        "pending",
        "paid",
        "picked_up",
        "returned",
        "settled",
        "cancelled",
        "disputed",
        "resolved",
        "requested",
        "accepted",
        "rejected",
        "expired",
      ],
    },
  },
  storage: {
    Enums: {
      buckettype: ["STANDARD", "ANALYTICS", "VECTOR"],
    },
  },
} as const

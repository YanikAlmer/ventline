export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      attachments: {
        Row: {
          byte_size: number | null
          created_at: string
          duration_seconds: number | null
          height: number | null
          id: string
          kind: Database["public"]["Enums"]["attachment_kind"]
          message_id: string
          mime_type: string
          storage_bucket: string
          storage_path: string
          waveform: Json | null
          width: number | null
        }
        Insert: {
          byte_size?: number | null
          created_at?: string
          duration_seconds?: number | null
          height?: number | null
          id?: string
          kind: Database["public"]["Enums"]["attachment_kind"]
          message_id: string
          mime_type: string
          storage_bucket: string
          storage_path: string
          waveform?: Json | null
          width?: number | null
        }
        Update: {
          byte_size?: number | null
          created_at?: string
          duration_seconds?: number | null
          height?: number | null
          id?: string
          kind?: Database["public"]["Enums"]["attachment_kind"]
          message_id?: string
          mime_type?: string
          storage_bucket?: string
          storage_path?: string
          waveform?: Json | null
          width?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "attachments_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      companies: {
        Row: {
          created_at: string
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
      devices: {
        Row: {
          apns_token: string
          id: string
          platform: Database["public"]["Enums"]["device_platform"]
          profile_id: string
          updated_at: string
        }
        Insert: {
          apns_token: string
          id?: string
          platform: Database["public"]["Enums"]["device_platform"]
          profile_id: string
          updated_at?: string
        }
        Update: {
          apns_token?: string
          id?: string
          platform?: Database["public"]["Enums"]["device_platform"]
          profile_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "devices_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      invites: {
        Row: {
          code: string
          company_id: string
          created_at: string
          expires_at: string
          full_name: string | null
          id: string
          invited_by: string | null
          project_ids: string[]
          redeemed_at: string | null
          redeemed_by: string | null
          role: Database["public"]["Enums"]["app_role"]
        }
        Insert: {
          code: string
          company_id: string
          created_at?: string
          expires_at?: string
          full_name?: string | null
          id?: string
          invited_by?: string | null
          project_ids?: string[]
          redeemed_at?: string | null
          redeemed_by?: string | null
          role?: Database["public"]["Enums"]["app_role"]
        }
        Update: {
          code?: string
          company_id?: string
          created_at?: string
          expires_at?: string
          full_name?: string | null
          id?: string
          invited_by?: string | null
          project_ids?: string[]
          redeemed_at?: string | null
          redeemed_by?: string | null
          role?: Database["public"]["Enums"]["app_role"]
        }
        Relationships: [
          {
            foreignKeyName: "invites_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invites_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invites_redeemed_by_fkey"
            columns: ["redeemed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      media_deletion_queue: {
        Row: {
          enqueued_at: string
          id: number
          storage_bucket: string
          storage_path: string
        }
        Insert: {
          enqueued_at?: string
          id?: never
          storage_bucket: string
          storage_path: string
        }
        Update: {
          enqueued_at?: string
          id?: never
          storage_bucket?: string
          storage_path?: string
        }
        Relationships: []
      }
      message_mentions: {
        Row: {
          acknowledged_at: string | null
          company_id: string
          created_at: string
          length: number | null
          mentioned_profile_id: string
          message_id: string
          project_id: string
          start_offset: number | null
        }
        Insert: {
          acknowledged_at?: string | null
          company_id: string
          created_at?: string
          length?: number | null
          mentioned_profile_id: string
          message_id: string
          project_id: string
          start_offset?: number | null
        }
        Update: {
          acknowledged_at?: string | null
          company_id?: string
          created_at?: string
          length?: number | null
          mentioned_profile_id?: string
          message_id?: string
          project_id?: string
          start_offset?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "message_mentions_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_mentions_mentioned_profile_id_fkey"
            columns: ["mentioned_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_mentions_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_mentions_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_mentions_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      message_reads: {
        Row: {
          message_id: string
          profile_id: string
          read_at: string
        }
        Insert: {
          message_id: string
          profile_id: string
          read_at?: string
        }
        Update: {
          message_id?: string
          profile_id?: string
          read_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_reads_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_reads_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      message_refs: {
        Row: {
          attachment_id: string | null
          company_id: string
          created_at: string
          id: string
          kind: Database["public"]["Enums"]["message_ref_kind"]
          length: number | null
          message_id: string
          project_id: string
          start_offset: number | null
          task_id: string | null
        }
        Insert: {
          attachment_id?: string | null
          company_id: string
          created_at?: string
          id?: string
          kind: Database["public"]["Enums"]["message_ref_kind"]
          length?: number | null
          message_id: string
          project_id: string
          start_offset?: number | null
          task_id?: string | null
        }
        Update: {
          attachment_id?: string | null
          company_id?: string
          created_at?: string
          id?: string
          kind?: Database["public"]["Enums"]["message_ref_kind"]
          length?: number | null
          message_id?: string
          project_id?: string
          start_offset?: number | null
          task_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "message_refs_attachment_id_fkey"
            columns: ["attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_refs_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_refs_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_refs_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_refs_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_refs_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          body: string | null
          company_id: string
          created_at: string
          deleted_at: string | null
          edited_at: string | null
          expires_at: string | null
          has_photo: boolean
          has_video: boolean
          has_voice: boolean
          id: string
          kind: Database["public"]["Enums"]["message_kind"]
          project_id: string
          reply_to_message_id: string | null
          search_tsv: unknown
          sender_id: string
          shared_with_customer: boolean
          task_id: string | null
          thread_id: string | null
        }
        Insert: {
          body?: string | null
          company_id: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          expires_at?: string | null
          has_photo?: boolean
          has_video?: boolean
          has_voice?: boolean
          id?: string
          kind?: Database["public"]["Enums"]["message_kind"]
          project_id: string
          reply_to_message_id?: string | null
          search_tsv?: unknown
          sender_id: string
          shared_with_customer?: boolean
          task_id?: string | null
          thread_id?: string | null
        }
        Update: {
          body?: string | null
          company_id?: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          expires_at?: string | null
          has_photo?: boolean
          has_video?: boolean
          has_voice?: boolean
          id?: string
          kind?: Database["public"]["Enums"]["message_kind"]
          project_id?: string
          reply_to_message_id?: string | null
          search_tsv?: unknown
          sender_id?: string
          shared_with_customer?: boolean
          task_id?: string | null
          thread_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "messages_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_reply_to_message_id_fkey"
            columns: ["reply_to_message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      photo_annotations: {
        Row: {
          attachment_id: string
          author_id: string
          created_at: string
          drawing_data: Json
          id: string
          rendered_path: string
        }
        Insert: {
          attachment_id: string
          author_id: string
          created_at?: string
          drawing_data: Json
          id?: string
          rendered_path: string
        }
        Update: {
          attachment_id?: string
          author_id?: string
          created_at?: string
          drawing_data?: Json
          id?: string
          rendered_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "photo_annotations_attachment_id_fkey"
            columns: ["attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "photo_annotations_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_path: string | null
          company_id: string
          created_at: string
          full_name: string
          id: string
          phone: string | null
          role: Database["public"]["Enums"]["app_role"]
          updated_at: string
        }
        Insert: {
          avatar_path?: string | null
          company_id: string
          created_at?: string
          full_name: string
          id: string
          phone?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
        }
        Update: {
          avatar_path?: string | null
          company_id?: string
          created_at?: string
          full_name?: string
          id?: string
          phone?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      project_members: {
        Row: {
          added_by: string | null
          created_at: string
          profile_id: string
          project_id: string
        }
        Insert: {
          added_by?: string | null
          created_at?: string
          profile_id: string
          project_id: string
        }
        Update: {
          added_by?: string | null
          created_at?: string
          profile_id?: string
          project_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_members_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_members_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_members_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_members_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      projects: {
        Row: {
          address: string | null
          company_id: string
          cover_photo_path: string | null
          created_at: string
          created_by: string | null
          customer_display_name: string | null
          description: string | null
          id: string
          name: string
          status: Database["public"]["Enums"]["project_status"]
          updated_at: string
        }
        Insert: {
          address?: string | null
          company_id: string
          cover_photo_path?: string | null
          created_at?: string
          created_by?: string | null
          customer_display_name?: string | null
          description?: string | null
          id?: string
          name: string
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string
        }
        Update: {
          address?: string | null
          company_id?: string
          cover_photo_path?: string | null
          created_at?: string
          created_by?: string | null
          customer_display_name?: string | null
          description?: string | null
          id?: string
          name?: string
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "projects_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "projects_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      task_assignments: {
        Row: {
          assigned_by: string | null
          created_at: string
          profile_id: string
          task_id: string
        }
        Insert: {
          assigned_by?: string | null
          created_at?: string
          profile_id: string
          task_id: string
        }
        Update: {
          assigned_by?: string | null
          created_at?: string
          profile_id?: string
          task_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_assignments_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_assignments_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_assignments_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          company_id: string
          completed_at: string | null
          completed_by: string | null
          created_at: string
          created_by: string | null
          description: string | null
          due_date: string | null
          id: string
          project_id: string
          sort_order: number
          status: Database["public"]["Enums"]["task_status"]
          title: string
          updated_at: string
          visible_to_customer: boolean
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          company_id: string
          completed_at?: string | null
          completed_by?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          due_date?: string | null
          id?: string
          project_id: string
          sort_order?: number
          status?: Database["public"]["Enums"]["task_status"]
          title: string
          updated_at?: string
          visible_to_customer?: boolean
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          company_id?: string
          completed_at?: string | null
          completed_by?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          due_date?: string | null
          id?: string
          project_id?: string
          sort_order?: number
          status?: Database["public"]["Enums"]["task_status"]
          title?: string
          updated_at?: string
          visible_to_customer?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "tasks_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_completed_by_fkey"
            columns: ["completed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      thread_read_state: {
        Row: {
          last_read_at: string
          last_read_message_id: string | null
          muted: boolean
          profile_id: string
          thread_id: string
          updated_at: string
        }
        Insert: {
          last_read_at?: string
          last_read_message_id?: string | null
          muted?: boolean
          profile_id: string
          thread_id: string
          updated_at?: string
        }
        Update: {
          last_read_at?: string
          last_read_message_id?: string | null
          muted?: boolean
          profile_id?: string
          thread_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "thread_read_state_last_read_message_id_fkey"
            columns: ["last_read_message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_read_state_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      thread_state: {
        Row: {
          company_id: string
          created_at: string
          last_expires_at: string | null
          last_kind: Database["public"]["Enums"]["message_kind"] | null
          last_message_at: string | null
          last_message_id: string | null
          last_preview: string | null
          last_sender_id: string | null
          message_count: number
          project_id: string
          task_id: string | null
          thread_id: string
        }
        Insert: {
          company_id: string
          created_at?: string
          last_expires_at?: string | null
          last_kind?: Database["public"]["Enums"]["message_kind"] | null
          last_message_at?: string | null
          last_message_id?: string | null
          last_preview?: string | null
          last_sender_id?: string | null
          message_count?: number
          project_id: string
          task_id?: string | null
          thread_id: string
        }
        Update: {
          company_id?: string
          created_at?: string
          last_expires_at?: string | null
          last_kind?: Database["public"]["Enums"]["message_kind"] | null
          last_message_at?: string | null
          last_message_id?: string | null
          last_preview?: string | null
          last_sender_id?: string | null
          message_count?: number
          project_id?: string
          task_id?: string | null
          thread_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thread_state_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_last_message_id_fkey"
            columns: ["last_message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_last_sender_id_fkey"
            columns: ["last_sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      inbox_threads: {
        Row: {
          has_unread: boolean | null
          last_kind: Database["public"]["Enums"]["message_kind"] | null
          last_message_at: string | null
          last_message_id: string | null
          last_preview: string | null
          last_read_at: string | null
          last_sender_id: string | null
          message_count: number | null
          muted: boolean | null
          project_id: string | null
          project_name: string | null
          project_status: Database["public"]["Enums"]["project_status"] | null
          task_id: string | null
          task_status: Database["public"]["Enums"]["task_status"] | null
          task_title: string | null
          thread_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "thread_state_last_message_id_fkey"
            columns: ["last_message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_last_sender_id_fkey"
            columns: ["last_sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_state_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      person_activity: {
        Row: {
          last_message_at: string | null
          message_count: number | null
          profile_id: string | null
          project_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "messages_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_overview: {
        Row: {
          address: string | null
          approved_count: number | null
          blocked_count: number | null
          company_id: string | null
          cover_photo_path: string | null
          created_at: string | null
          customer_display_name: string | null
          done_count: number | null
          id: string | null
          in_progress_count: number | null
          last_activity_at: string | null
          latest_photo_path: string | null
          member_count: number | null
          name: string | null
          status: Database["public"]["Enums"]["project_status"] | null
          task_count: number | null
          todo_count: number | null
          updated_at: string | null
        }
        Relationships: [
          {
            foreignKeyName: "projects_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      create_company: {
        Args: { p_full_name: string; p_name: string }
        Returns: string
      }
      create_invite: {
        Args: {
          p_full_name?: string
          p_project_ids?: string[]
          p_role: Database["public"]["Enums"]["app_role"]
        }
        Returns: {
          code: string
          invite_id: string
        }[]
      }
      delete_message: { Args: { p_message_id: string }; Returns: undefined }
      inbox_attention: {
        Args: { p_limit?: number }
        Returns: {
          body: string
          created_at: string
          kind: Database["public"]["Enums"]["message_kind"]
          message_id: string
          project_id: string
          reason: string
          sender_id: string
          task_id: string
          thread_id: string
        }[]
      }
      inbox_page: {
        Args: { p_before?: string; p_limit?: number; p_project_id?: string }
        Returns: {
          last_kind: Database["public"]["Enums"]["message_kind"]
          last_message_at: string
          last_message_id: string
          last_preview: string
          last_read_at: string
          last_sender_id: string
          last_sender_name: string
          muted: boolean
          project_id: string
          project_name: string
          project_status: Database["public"]["Enums"]["project_status"]
          task_id: string
          task_status: Database["public"]["Enums"]["task_status"]
          task_title: string
          thread_id: string
          unread_count: number
          unread_mention_count: number
        }[]
      }
      mark_thread_read: {
        Args: { p_thread_id: string; p_up_to?: string }
        Returns: undefined
      }
      messages_around: {
        Args: { p_message_id: string; p_radius?: number }
        Returns: {
          body: string | null
          company_id: string
          created_at: string
          deleted_at: string | null
          edited_at: string | null
          expires_at: string | null
          has_photo: boolean
          has_video: boolean
          has_voice: boolean
          id: string
          kind: Database["public"]["Enums"]["message_kind"]
          project_id: string
          reply_to_message_id: string | null
          search_tsv: unknown
          sender_id: string
          shared_with_customer: boolean
          task_id: string | null
          thread_id: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "messages"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      person_messages: {
        Args: {
          p_before_created_at?: string
          p_before_id?: string
          p_direction?: string
          p_limit?: number
          p_profile_id: string
          p_project_id?: string
        }
        Returns: {
          body: string
          created_at: string
          direction: string
          has_photo: boolean
          has_voice: boolean
          id: string
          kind: Database["public"]["Enums"]["message_kind"]
          project_id: string
          sender_id: string
          task_id: string
          thread_id: string
        }[]
      }
      purge_expired_messages: { Args: never; Returns: number }
      redeem_invite: {
        Args: { p_code: string; p_full_name?: string }
        Returns: boolean
      }
      search_messages: {
        Args: {
          p_before_created_at?: string
          p_before_id?: string
          p_from?: string
          p_has_photo?: boolean
          p_has_voice?: boolean
          p_limit?: number
          p_mentions_profile_id?: string
          p_project_ids?: string[]
          p_query?: string
          p_sender_ids?: string[]
          p_to?: string
        }
        Returns: {
          body: string
          created_at: string
          has_photo: boolean
          has_voice: boolean
          headline: string
          id: string
          kind: Database["public"]["Enums"]["message_kind"]
          project_id: string
          rank: number
          sender_id: string
          task_id: string
          thread_id: string
        }[]
      }
      send_message: {
        Args: {
          p_attachments?: Json
          p_body?: string
          p_expires_at?: string
          p_kind?: Database["public"]["Enums"]["message_kind"]
          p_mentions?: Json
          p_project_id: string
          p_refs?: Json
          p_shared_with_customer?: boolean
          p_task_id?: string
        }
        Returns: string
      }
    }
    Enums: {
      app_role: "owner" | "manager" | "foreman" | "worker" | "customer"
      attachment_kind: "photo" | "voice" | "video"
      device_platform: "ios" | "web"
      message_kind: "text" | "photo" | "voice" | "video" | "system"
      message_ref_kind: "task" | "attachment"
      project_status:
        "planning" | "active" | "on_hold" | "completed" | "archived"
      task_status: "todo" | "in_progress" | "blocked" | "done" | "approved"
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
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
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
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
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
    keyof DefaultSchema["Enums"] | { schema: keyof DatabaseWithoutInternals },
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
  public: {
    Enums: {
      app_role: ["owner", "manager", "foreman", "worker", "customer"],
      attachment_kind: ["photo", "voice", "video"],
      device_platform: ["ios", "web"],
      message_kind: ["text", "photo", "voice", "video", "system"],
      message_ref_kind: ["task", "attachment"],
      project_status: [
        "planning",
        "active",
        "on_hold",
        "completed",
        "archived",
      ],
      task_status: ["todo", "in_progress", "blocked", "done", "approved"],
    },
  },
} as const

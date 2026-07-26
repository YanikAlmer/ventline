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
          caption: string | null
          created_at: string
          duration_seconds: number | null
          height: number | null
          id: string
          kind: Database["public"]["Enums"]["attachment_kind"]
          message_id: string | null
          mime_type: string
          report_id: string | null
          storage_bucket: string
          storage_path: string
          task_id: string | null
          uploaded_by: string | null
          waveform: Json | null
          width: number | null
        }
        Insert: {
          byte_size?: number | null
          caption?: string | null
          created_at?: string
          duration_seconds?: number | null
          height?: number | null
          id?: string
          kind: Database["public"]["Enums"]["attachment_kind"]
          message_id?: string | null
          mime_type: string
          report_id?: string | null
          storage_bucket: string
          storage_path: string
          task_id?: string | null
          uploaded_by?: string | null
          waveform?: Json | null
          width?: number | null
        }
        Update: {
          byte_size?: number | null
          caption?: string | null
          created_at?: string
          duration_seconds?: number | null
          height?: number | null
          id?: string
          kind?: Database["public"]["Enums"]["attachment_kind"]
          message_id?: string | null
          mime_type?: string
          report_id?: string | null
          storage_bucket?: string
          storage_path?: string
          task_id?: string | null
          uploaded_by?: string | null
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
          {
            foreignKeyName: "attachments_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "report_divergences"
            referencedColumns: ["report_id"]
          },
          {
            foreignKeyName: "attachments_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "reports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attachments_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attachments_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
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
      company_billing_settings: {
        Row: {
          company_id: string
          created_at: string
          creditor_building_no: string | null
          creditor_country: string
          creditor_name: string
          creditor_post_code: string
          creditor_street: string | null
          creditor_town: string
          default_hourly_rate_rappen: number
          default_mwst_rate_bp: number
          iban: string | null
          logo_path: string | null
          mwst_status: Database["public"]["Enums"]["mwst_status"]
          payment_terms_days: number
          saldo_rate_bp: number | null
          show_prices_on_rapport: boolean
          uid_digits: string | null
          updated_at: string
        }
        Insert: {
          company_id: string
          created_at?: string
          creditor_building_no?: string | null
          creditor_country?: string
          creditor_name: string
          creditor_post_code: string
          creditor_street?: string | null
          creditor_town: string
          default_hourly_rate_rappen?: number
          default_mwst_rate_bp?: number
          iban?: string | null
          logo_path?: string | null
          mwst_status?: Database["public"]["Enums"]["mwst_status"]
          payment_terms_days?: number
          saldo_rate_bp?: number | null
          show_prices_on_rapport?: boolean
          uid_digits?: string | null
          updated_at?: string
        }
        Update: {
          company_id?: string
          created_at?: string
          creditor_building_no?: string | null
          creditor_country?: string
          creditor_name?: string
          creditor_post_code?: string
          creditor_street?: string | null
          creditor_town?: string
          default_hourly_rate_rappen?: number
          default_mwst_rate_bp?: number
          iban?: string | null
          logo_path?: string | null
          mwst_status?: Database["public"]["Enums"]["mwst_status"]
          payment_terms_days?: number
          saldo_rate_bp?: number | null
          show_prices_on_rapport?: boolean
          uid_digits?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "company_billing_settings_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: true
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      customers: {
        Row: {
          bexio_contact_id: number | null
          building_no: string | null
          company_id: string
          country: string | null
          created_at: string
          created_by: string | null
          email: string | null
          id: string
          name: string
          notes: string | null
          phone: string | null
          post_code: string | null
          street: string | null
          town: string | null
          updated_at: string
        }
        Insert: {
          bexio_contact_id?: number | null
          building_no?: string | null
          company_id: string
          country?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          name: string
          notes?: string | null
          phone?: string | null
          post_code?: string | null
          street?: string | null
          town?: string | null
          updated_at?: string
        }
        Update: {
          bexio_contact_id?: number | null
          building_no?: string | null
          company_id?: string
          country?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          name?: string
          notes?: string | null
          phone?: string | null
          post_code?: string | null
          street?: string | null
          town?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customers_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customers_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      devices: {
        Row: {
          apns_environment: string
          app_version: string | null
          created_at: string
          id: string
          install_id: string
          last_seen_at: string
          locale: string
          platform: Database["public"]["Enums"]["device_platform"]
          profile_id: string
          push_token: string
          updated_at: string
        }
        Insert: {
          apns_environment?: string
          app_version?: string | null
          created_at?: string
          id?: string
          install_id: string
          last_seen_at?: string
          locale?: string
          platform: Database["public"]["Enums"]["device_platform"]
          profile_id: string
          push_token: string
          updated_at?: string
        }
        Update: {
          apns_environment?: string
          app_version?: string | null
          created_at?: string
          id?: string
          install_id?: string
          last_seen_at?: string
          locale?: string
          platform?: Database["public"]["Enums"]["device_platform"]
          profile_id?: string
          push_token?: string
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
      document_link_views: {
        Row: {
          id: number
          link_id: string
          user_agent_family: string | null
          viewed_at: string
        }
        Insert: {
          id?: number
          link_id: string
          user_agent_family?: string | null
          viewed_at?: string
        }
        Update: {
          id?: number
          link_id?: string
          user_agent_family?: string | null
          viewed_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "document_link_views_link_id_fkey"
            columns: ["link_id"]
            isOneToOne: false
            referencedRelation: "document_links"
            referencedColumns: ["id"]
          },
        ]
      }
      document_links: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          expires_at: string
          id: string
          invoice_id: string | null
          kind: Database["public"]["Enums"]["document_link_kind"]
          last_viewed_at: string | null
          report_id: string | null
          revoked_at: string | null
          token_hash: string
          view_count: number
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          expires_at: string
          id?: string
          invoice_id?: string | null
          kind: Database["public"]["Enums"]["document_link_kind"]
          last_viewed_at?: string | null
          report_id?: string | null
          revoked_at?: string | null
          token_hash: string
          view_count?: number
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          expires_at?: string
          id?: string
          invoice_id?: string | null
          kind?: Database["public"]["Enums"]["document_link_kind"]
          last_viewed_at?: string | null
          report_id?: string | null
          revoked_at?: string | null
          token_hash?: string
          view_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "document_links_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "document_links_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "document_links_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "document_links_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "report_divergences"
            referencedColumns: ["report_id"]
          },
          {
            foreignKeyName: "document_links_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "reports"
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
      invoice_lines: {
        Row: {
          description: string
          id: string
          invoice_id: string
          mwst_rate_bp: number
          net_rappen: number
          quantity_milli: number
          service_date: string | null
          sort_order: number
          unit: string
          unit_price_rappen: number
        }
        Insert: {
          description: string
          id?: string
          invoice_id: string
          mwst_rate_bp?: number
          net_rappen?: number
          quantity_milli?: number
          service_date?: string | null
          sort_order?: number
          unit?: string
          unit_price_rappen?: number
        }
        Update: {
          description?: string
          id?: string
          invoice_id?: string
          mwst_rate_bp?: number
          net_rappen?: number
          quantity_milli?: number
          service_date?: string | null
          sort_order?: number
          unit?: string
          unit_price_rappen?: number
        }
        Relationships: [
          {
            foreignKeyName: "invoice_lines_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_tax_groups: {
        Row: {
          invoice_id: string
          net_rappen: number
          rate_bp: number
          tax_rappen: number
        }
        Insert: {
          invoice_id: string
          net_rappen: number
          rate_bp: number
          tax_rappen: number
        }
        Update: {
          invoice_id?: string
          net_rappen?: number
          rate_bp?: number
          tax_rappen?: number
        }
        Relationships: [
          {
            foreignKeyName: "invoice_tax_groups_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      invoices: {
        Row: {
          bexio_invoice_id: number | null
          bexio_sync_error: string | null
          bexio_synced_at: string | null
          company_id: string
          created_at: string
          created_by: string | null
          creditor_building_no: string | null
          creditor_country: string | null
          creditor_iban: string | null
          creditor_mwst_status:
            Database["public"]["Enums"]["mwst_status"] | null
          creditor_name: string | null
          creditor_post_code: string | null
          creditor_street: string | null
          creditor_town: string | null
          creditor_uid_digits: string | null
          currency: string
          customer_id: string
          debtor_building_no: string | null
          debtor_country: string | null
          debtor_name: string | null
          debtor_post_code: string | null
          debtor_street: string | null
          debtor_town: string | null
          due_date: string | null
          id: string
          invoice_date: string | null
          number: number | null
          number_text: string | null
          paid_at: string | null
          pdf_generated_at: string | null
          pdf_path: string | null
          pdf_sha256: string | null
          period_key: string | null
          project_id: string
          qr_payload: string | null
          qr_spec_version: string
          reference: string | null
          reference_type:
            Database["public"]["Enums"]["qr_reference_type"] | null
          report_id: string | null
          sent_at: string | null
          service_date_from: string | null
          service_date_to: string | null
          status: Database["public"]["Enums"]["invoice_status"]
          total_gross_rappen: number
          total_net_rappen: number
          total_tax_rappen: number
          updated_at: string
        }
        Insert: {
          bexio_invoice_id?: number | null
          bexio_sync_error?: string | null
          bexio_synced_at?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          creditor_building_no?: string | null
          creditor_country?: string | null
          creditor_iban?: string | null
          creditor_mwst_status?:
            Database["public"]["Enums"]["mwst_status"] | null
          creditor_name?: string | null
          creditor_post_code?: string | null
          creditor_street?: string | null
          creditor_town?: string | null
          creditor_uid_digits?: string | null
          currency?: string
          customer_id: string
          debtor_building_no?: string | null
          debtor_country?: string | null
          debtor_name?: string | null
          debtor_post_code?: string | null
          debtor_street?: string | null
          debtor_town?: string | null
          due_date?: string | null
          id?: string
          invoice_date?: string | null
          number?: number | null
          number_text?: string | null
          paid_at?: string | null
          pdf_generated_at?: string | null
          pdf_path?: string | null
          pdf_sha256?: string | null
          period_key?: string | null
          project_id: string
          qr_payload?: string | null
          qr_spec_version?: string
          reference?: string | null
          reference_type?:
            Database["public"]["Enums"]["qr_reference_type"] | null
          report_id?: string | null
          sent_at?: string | null
          service_date_from?: string | null
          service_date_to?: string | null
          status?: Database["public"]["Enums"]["invoice_status"]
          total_gross_rappen?: number
          total_net_rappen?: number
          total_tax_rappen?: number
          updated_at?: string
        }
        Update: {
          bexio_invoice_id?: number | null
          bexio_sync_error?: string | null
          bexio_synced_at?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          creditor_building_no?: string | null
          creditor_country?: string | null
          creditor_iban?: string | null
          creditor_mwst_status?:
            Database["public"]["Enums"]["mwst_status"] | null
          creditor_name?: string | null
          creditor_post_code?: string | null
          creditor_street?: string | null
          creditor_town?: string | null
          creditor_uid_digits?: string | null
          currency?: string
          customer_id?: string
          debtor_building_no?: string | null
          debtor_country?: string | null
          debtor_name?: string | null
          debtor_post_code?: string | null
          debtor_street?: string | null
          debtor_town?: string | null
          due_date?: string | null
          id?: string
          invoice_date?: string | null
          number?: number | null
          number_text?: string | null
          paid_at?: string | null
          pdf_generated_at?: string | null
          pdf_path?: string | null
          pdf_sha256?: string | null
          period_key?: string | null
          project_id?: string
          qr_payload?: string | null
          qr_spec_version?: string
          reference?: string | null
          reference_type?:
            Database["public"]["Enums"]["qr_reference_type"] | null
          report_id?: string | null
          sent_at?: string | null
          service_date_from?: string | null
          service_date_to?: string | null
          status?: Database["public"]["Enums"]["invoice_status"]
          total_gross_rappen?: number
          total_net_rappen?: number
          total_tax_rappen?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "invoices_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "report_divergences"
            referencedColumns: ["report_id"]
          },
          {
            foreignKeyName: "invoices_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "reports"
            referencedColumns: ["id"]
          },
        ]
      }
      material_lines: {
        Row: {
          company_id: string
          created_at: string
          description: string
          id: string
          project_id: string
          quantity_milli: number
          recorded_by: string | null
          task_id: string | null
          unit: string
          unit_price_rappen: number
          updated_at: string
        }
        Insert: {
          company_id: string
          created_at?: string
          description: string
          id?: string
          project_id: string
          quantity_milli: number
          recorded_by?: string | null
          task_id?: string | null
          unit?: string
          unit_price_rappen?: number
          updated_at?: string
        }
        Update: {
          company_id?: string
          created_at?: string
          description?: string
          id?: string
          project_id?: string
          quantity_milli?: number
          recorded_by?: string | null
          task_id?: string | null
          unit?: string
          unit_price_rappen?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "material_lines_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_lines_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_lines_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_lines_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_lines_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
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
      notification_deliveries: {
        Row: {
          delivered_at: string
          device_id: string
          outbox_id: string
        }
        Insert: {
          delivered_at?: string
          device_id: string
          outbox_id: string
        }
        Update: {
          delivered_at?: string
          device_id?: string
          outbox_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_deliveries_outbox_id_fkey"
            columns: ["outbox_id"]
            isOneToOne: false
            referencedRelation: "notification_outbox"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_outbox: {
        Row: {
          actor_id: string | null
          attempts: number
          company_id: string
          created_at: string
          dedupe_key: string
          id: string
          kind: Database["public"]["Enums"]["notification_kind"]
          last_error: string | null
          message_id: string | null
          next_attempt_at: string
          payload: Json
          processed_at: string | null
          project_id: string
          status: Database["public"]["Enums"]["notification_status"]
          target_id: string | null
          task_id: string | null
        }
        Insert: {
          actor_id?: string | null
          attempts?: number
          company_id: string
          created_at?: string
          dedupe_key: string
          id?: string
          kind: Database["public"]["Enums"]["notification_kind"]
          last_error?: string | null
          message_id?: string | null
          next_attempt_at?: string
          payload?: Json
          processed_at?: string | null
          project_id: string
          status?: Database["public"]["Enums"]["notification_status"]
          target_id?: string | null
          task_id?: string | null
        }
        Update: {
          actor_id?: string | null
          attempts?: number
          company_id?: string
          created_at?: string
          dedupe_key?: string
          id?: string
          kind?: Database["public"]["Enums"]["notification_kind"]
          last_error?: string | null
          message_id?: string | null
          next_attempt_at?: string
          payload?: Json
          processed_at?: string | null
          project_id?: string
          status?: Database["public"]["Enums"]["notification_status"]
          target_id?: string | null
          task_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notification_outbox_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_outbox_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_outbox_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_outbox_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_outbox_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_outbox_target_id_fkey"
            columns: ["target_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_outbox_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_prefs: {
        Row: {
          chat_enabled: boolean
          created_at: string
          deadlines_enabled: boolean
          mentions_enabled: boolean
          profile_id: string
          push_enabled: boolean
          quiet_hours_enabled: boolean
          quiet_hours_end: string
          quiet_hours_start: string
          task_assigned_enabled: boolean
          task_status_enabled: boolean
          time_zone: string
          updated_at: string
          watch_all_projects: boolean
        }
        Insert: {
          chat_enabled?: boolean
          created_at?: string
          deadlines_enabled?: boolean
          mentions_enabled?: boolean
          profile_id: string
          push_enabled?: boolean
          quiet_hours_enabled?: boolean
          quiet_hours_end?: string
          quiet_hours_start?: string
          task_assigned_enabled?: boolean
          task_status_enabled?: boolean
          time_zone?: string
          updated_at?: string
          watch_all_projects?: boolean
        }
        Update: {
          chat_enabled?: boolean
          created_at?: string
          deadlines_enabled?: boolean
          mentions_enabled?: boolean
          profile_id?: string
          push_enabled?: boolean
          quiet_hours_enabled?: boolean
          quiet_hours_end?: string
          quiet_hours_start?: string
          task_assigned_enabled?: boolean
          task_status_enabled?: boolean
          time_zone?: string
          updated_at?: string
          watch_all_projects?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "notification_prefs_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
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
      project_notification_mutes: {
        Row: {
          created_at: string
          muted_until: string | null
          profile_id: string
          project_id: string
        }
        Insert: {
          created_at?: string
          muted_until?: string | null
          profile_id: string
          project_id: string
        }
        Update: {
          created_at?: string
          muted_until?: string | null
          profile_id?: string
          project_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_notification_mutes_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_notification_mutes_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_notification_mutes_project_id_fkey"
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
          billing_mode: Database["public"]["Enums"]["billing_mode"]
          company_id: string
          cover_photo_path: string | null
          created_at: string
          created_by: string | null
          customer_display_name: string | null
          customer_id: string | null
          description: string | null
          id: string
          name: string
          status: Database["public"]["Enums"]["project_status"]
          updated_at: string
        }
        Insert: {
          address?: string | null
          billing_mode?: Database["public"]["Enums"]["billing_mode"]
          company_id: string
          cover_photo_path?: string | null
          created_at?: string
          created_by?: string | null
          customer_display_name?: string | null
          customer_id?: string | null
          description?: string | null
          id?: string
          name: string
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string
        }
        Update: {
          address?: string | null
          billing_mode?: Database["public"]["Enums"]["billing_mode"]
          company_id?: string
          cover_photo_path?: string | null
          created_at?: string
          created_by?: string | null
          customer_display_name?: string | null
          customer_id?: string | null
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
          {
            foreignKeyName: "projects_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
        ]
      }
      render_runs: {
        Row: {
          id: number
          nudged: number
          ran_at: string
          stuck: number
        }
        Insert: {
          id?: never
          nudged: number
          ran_at?: string
          stuck: number
        }
        Update: {
          id?: never
          nudged?: number
          ran_at?: string
          stuck?: number
        }
        Relationships: []
      }
      report_material_lines: {
        Row: {
          description: string
          id: string
          material_line_id: string | null
          quantity_milli: number
          report_id: string
          sort_order: number
          unit: string
          unit_price_rappen: number
        }
        Insert: {
          description: string
          id?: string
          material_line_id?: string | null
          quantity_milli: number
          report_id: string
          sort_order?: number
          unit?: string
          unit_price_rappen?: number
        }
        Update: {
          description?: string
          id?: string
          material_line_id?: string | null
          quantity_milli?: number
          report_id?: string
          sort_order?: number
          unit?: string
          unit_price_rappen?: number
        }
        Relationships: [
          {
            foreignKeyName: "report_material_lines_material_line_id_fkey"
            columns: ["material_line_id"]
            isOneToOne: false
            referencedRelation: "material_lines"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "report_material_lines_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "report_divergences"
            referencedColumns: ["report_id"]
          },
          {
            foreignKeyName: "report_material_lines_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "reports"
            referencedColumns: ["id"]
          },
        ]
      }
      report_photos: {
        Row: {
          attachment_id: string
          report_id: string
          sort_order: number
        }
        Insert: {
          attachment_id: string
          report_id: string
          sort_order?: number
        }
        Update: {
          attachment_id?: string
          report_id?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "report_photos_attachment_id_fkey"
            columns: ["attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "report_photos_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "report_divergences"
            referencedColumns: ["report_id"]
          },
          {
            foreignKeyName: "report_photos_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "reports"
            referencedColumns: ["id"]
          },
        ]
      }
      report_time_lines: {
        Row: {
          description: string | null
          id: string
          minutes: number
          performed_by_name: string | null
          performed_on: string
          profile_id: string | null
          rate_rappen: number
          report_id: string
          sort_order: number
          source_revision: number | null
          time_entry_id: string | null
        }
        Insert: {
          description?: string | null
          id?: string
          minutes: number
          performed_by_name?: string | null
          performed_on: string
          profile_id?: string | null
          rate_rappen?: number
          report_id: string
          sort_order?: number
          source_revision?: number | null
          time_entry_id?: string | null
        }
        Update: {
          description?: string | null
          id?: string
          minutes?: number
          performed_by_name?: string | null
          performed_on?: string
          profile_id?: string | null
          rate_rappen?: number
          report_id?: string
          sort_order?: number
          source_revision?: number | null
          time_entry_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "report_time_lines_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "report_time_lines_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "report_divergences"
            referencedColumns: ["report_id"]
          },
          {
            foreignKeyName: "report_time_lines_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "reports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "report_time_lines_time_entry_id_fkey"
            columns: ["time_entry_id"]
            isOneToOne: false
            referencedRelation: "time_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          client_content_hash: string | null
          company_id: string
          content_hash: string | null
          corrects_report_id: string | null
          created_at: string
          created_by: string | null
          customer_id: string | null
          doc_type: Database["public"]["Enums"]["document_type"]
          id: string
          number: number | null
          number_text: string | null
          pdf_generated_at: string | null
          pdf_path: string | null
          pdf_sha256: string | null
          period_from: string | null
          period_key: string | null
          period_to: string | null
          project_id: string
          sent_at: string | null
          signature_path: string | null
          signed_at: string | null
          signed_at_device: string | null
          signed_offline: boolean
          signer_name: string | null
          snapshot: Json | null
          status: Database["public"]["Enums"]["report_status"]
          summary: string | null
          title: string | null
          total_net_rappen: number | null
          updated_at: string
        }
        Insert: {
          client_content_hash?: string | null
          company_id: string
          content_hash?: string | null
          corrects_report_id?: string | null
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          doc_type?: Database["public"]["Enums"]["document_type"]
          id?: string
          number?: number | null
          number_text?: string | null
          pdf_generated_at?: string | null
          pdf_path?: string | null
          pdf_sha256?: string | null
          period_from?: string | null
          period_key?: string | null
          period_to?: string | null
          project_id: string
          sent_at?: string | null
          signature_path?: string | null
          signed_at?: string | null
          signed_at_device?: string | null
          signed_offline?: boolean
          signer_name?: string | null
          snapshot?: Json | null
          status?: Database["public"]["Enums"]["report_status"]
          summary?: string | null
          title?: string | null
          total_net_rappen?: number | null
          updated_at?: string
        }
        Update: {
          client_content_hash?: string | null
          company_id?: string
          content_hash?: string | null
          corrects_report_id?: string | null
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          doc_type?: Database["public"]["Enums"]["document_type"]
          id?: string
          number?: number | null
          number_text?: string | null
          pdf_generated_at?: string | null
          pdf_path?: string | null
          pdf_sha256?: string | null
          period_from?: string | null
          period_key?: string | null
          period_to?: string | null
          project_id?: string
          sent_at?: string | null
          signature_path?: string | null
          signed_at?: string | null
          signed_at_device?: string | null
          signed_offline?: boolean
          signer_name?: string | null
          snapshot?: Json | null
          status?: Database["public"]["Enums"]["report_status"]
          summary?: string | null
          title?: string | null
          total_net_rappen?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "reports_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_corrects_report_id_fkey"
            columns: ["corrects_report_id"]
            isOneToOne: false
            referencedRelation: "report_divergences"
            referencedColumns: ["report_id"]
          },
          {
            foreignKeyName: "reports_corrects_report_id_fkey"
            columns: ["corrects_report_id"]
            isOneToOne: false
            referencedRelation: "reports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      retention_runs: {
        Row: {
          cutoff: string
          entries_deleted: number
          id: number
          ran_at: string
          report_lines_detached: number
          revisions_deleted: number
        }
        Insert: {
          cutoff: string
          entries_deleted: number
          id?: number
          ran_at?: string
          report_lines_detached: number
          revisions_deleted: number
        }
        Update: {
          cutoff?: string
          entries_deleted?: number
          id?: number
          ran_at?: string
          report_lines_detached?: number
          revisions_deleted?: number
        }
        Relationships: []
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
          due_time: string | null
          id: string
          parent_id: string | null
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
          due_time?: string | null
          id?: string
          parent_id?: string | null
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
          due_time?: string | null
          id?: string
          parent_id?: string | null
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
            foreignKeyName: "tasks_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "tasks"
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
      time_entries: {
        Row: {
          break_minutes: number
          company_id: string
          created_at: string
          ended_at: string | null
          id: string
          kind: Database["public"]["Enums"]["time_entry_kind"]
          note: string | null
          profile_id: string
          project_id: string
          recorded_by: string | null
          retain_until: string | null
          revision: number
          started_at: string
          task_id: string | null
          updated_at: string
          voided_at: string | null
          voided_reason: string | null
          work_date: string
          worked_minutes: number | null
        }
        Insert: {
          break_minutes?: number
          company_id: string
          created_at?: string
          ended_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["time_entry_kind"]
          note?: string | null
          profile_id: string
          project_id: string
          recorded_by?: string | null
          retain_until?: string | null
          revision?: number
          started_at: string
          task_id?: string | null
          updated_at?: string
          voided_at?: string | null
          voided_reason?: string | null
          work_date: string
          worked_minutes?: number | null
        }
        Update: {
          break_minutes?: number
          company_id?: string
          created_at?: string
          ended_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["time_entry_kind"]
          note?: string | null
          profile_id?: string
          project_id?: string
          recorded_by?: string | null
          retain_until?: string | null
          revision?: number
          started_at?: string
          task_id?: string | null
          updated_at?: string
          voided_at?: string | null
          voided_reason?: string | null
          work_date?: string
          worked_minutes?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "time_entries_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entries_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entries_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entries_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entries_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entries_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      time_entry_revisions: {
        Row: {
          after: Json | null
          before: Json | null
          changed_at: string
          changed_by: string | null
          company_id: string
          id: number
          op: string
          reason: string | null
          revision: number
          time_entry_id: string
        }
        Insert: {
          after?: Json | null
          before?: Json | null
          changed_at?: string
          changed_by?: string | null
          company_id: string
          id?: number
          op: string
          reason?: string | null
          revision: number
          time_entry_id: string
        }
        Update: {
          after?: Json | null
          before?: Json | null
          changed_at?: string
          changed_by?: string | null
          company_id?: string
          id?: number
          op?: string
          reason?: string | null
          revision?: number
          time_entry_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "time_entry_revisions_changed_by_fkey"
            columns: ["changed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entry_revisions_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entry_revisions_time_entry_id_fkey"
            columns: ["time_entry_id"]
            isOneToOne: false
            referencedRelation: "time_entries"
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
      number_series_audit: {
        Row: {
          company_id: string | null
          doc_type: Database["public"]["Enums"]["document_type"] | null
          highest: number | null
          issued: number | null
          lowest: number | null
          missing: number | null
          period_key: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reports_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
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
      report_divergences: {
        Row: {
          delta_minutes: number | null
          has_correction: boolean | null
          is_already_a_correction: boolean | null
          minutes_now: number | null
          minutes_on_paper: number | null
          number_text: string | null
          project_id: string | null
          report_id: string | null
          source_was_voided: boolean | null
          time_entry_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "report_time_lines_time_entry_id_fkey"
            columns: ["time_entry_id"]
            isOneToOne: false
            referencedRelation: "time_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "project_overview"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      attach_time_to_report: {
        Args: { p_report_id: string; p_time_entry_ids: string[] }
        Returns: number
      }
      claim_notification_batch: { Args: { p_limit?: number }; Returns: Json }
      create_company: {
        Args: { p_full_name: string; p_name: string }
        Returns: string
      }
      create_document_link: {
        Args: {
          p_document_id: string
          p_kind: Database["public"]["Enums"]["document_link_kind"]
          p_valid_days?: number
        }
        Returns: {
          expires_at: string
          link_id: string
          token: string
        }[]
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
      drain_notification_outbox: { Args: never; Returns: undefined }
      enqueue_due_reminders: { Args: never; Returns: number }
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
      invoice_export: {
        Args: { p_from: string; p_to: string }
        Returns: {
          bexio_kontakt_id: number
          bezahlt_am: string
          brutto: number
          faelligkeit: string
          kunde: string
          kunde_id: string
          kunde_land: string
          kunde_ort: string
          kunde_plz: string
          mwst: number
          mwst_satz: number
          mwst_verfahren: string
          netto: number
          projekt: string
          rapport: string
          rechnungsdatum: string
          rechnungsnummer: string
          referenz: string
          referenz_typ: string
          status: string
          waehrung: string
        }[]
      }
      invoice_render_payload: { Args: { p_invoice_id: string }; Returns: Json }
      issue_invoice: {
        Args: { p_invoice_id: string }
        Returns: {
          bexio_invoice_id: number | null
          bexio_sync_error: string | null
          bexio_synced_at: string | null
          company_id: string
          created_at: string
          created_by: string | null
          creditor_building_no: string | null
          creditor_country: string | null
          creditor_iban: string | null
          creditor_mwst_status:
            Database["public"]["Enums"]["mwst_status"] | null
          creditor_name: string | null
          creditor_post_code: string | null
          creditor_street: string | null
          creditor_town: string | null
          creditor_uid_digits: string | null
          currency: string
          customer_id: string
          debtor_building_no: string | null
          debtor_country: string | null
          debtor_name: string | null
          debtor_post_code: string | null
          debtor_street: string | null
          debtor_town: string | null
          due_date: string | null
          id: string
          invoice_date: string | null
          number: number | null
          number_text: string | null
          paid_at: string | null
          pdf_generated_at: string | null
          pdf_path: string | null
          pdf_sha256: string | null
          period_key: string | null
          project_id: string
          qr_payload: string | null
          qr_spec_version: string
          reference: string | null
          reference_type:
            Database["public"]["Enums"]["qr_reference_type"] | null
          report_id: string | null
          sent_at: string | null
          service_date_from: string | null
          service_date_to: string | null
          status: Database["public"]["Enums"]["invoice_status"]
          total_gross_rappen: number
          total_net_rappen: number
          total_tax_rappen: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "invoices"
          isOneToOne: true
          isSetofReturn: false
        }
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
      purge_expired_time_entries: { Args: never; Returns: number }
      qr_bill_payload: { Args: { p_invoice_id: string }; Returns: string }
      record_rendered_pdf: {
        Args: { p_id: string; p_kind: string; p_path: string; p_sha256: string }
        Returns: undefined
      }
      redeem_invite: {
        Args: { p_code: string; p_full_name?: string }
        Returns: boolean
      }
      register_device: {
        Args: {
          p_apns_environment?: string
          p_app_version?: string
          p_install_id: string
          p_locale?: string
          p_platform: Database["public"]["Enums"]["device_platform"]
          p_push_token: string
        }
        Returns: string
      }
      render_pending_documents: { Args: { p_limit?: number }; Returns: number }
      report_canonical_text: { Args: { p_report_id: string }; Returns: string }
      report_render_payload: { Args: { p_report_id: string }; Returns: Json }
      resolve_document_link: {
        Args: { p_token: string; p_user_agent_family?: string }
        Returns: Json
      }
      revoke_document_link: { Args: { p_link_id: string }; Returns: undefined }
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
      set_correction_reason: { Args: { p_reason: string }; Returns: undefined }
      settle_notification_batch: {
        Args: { p_results: Json }
        Returns: undefined
      }
      sign_report: {
        Args: {
          p_client_content_hash?: string
          p_report_id: string
          p_signature_path?: string
          p_signed_at_device?: string
          p_signer_name: string
        }
        Returns: {
          client_content_hash: string | null
          company_id: string
          content_hash: string | null
          corrects_report_id: string | null
          created_at: string
          created_by: string | null
          customer_id: string | null
          doc_type: Database["public"]["Enums"]["document_type"]
          id: string
          number: number | null
          number_text: string | null
          pdf_generated_at: string | null
          pdf_path: string | null
          pdf_sha256: string | null
          period_from: string | null
          period_key: string | null
          period_to: string | null
          project_id: string
          sent_at: string | null
          signature_path: string | null
          signed_at: string | null
          signed_at_device: string | null
          signed_offline: boolean
          signer_name: string | null
          snapshot: Json | null
          status: Database["public"]["Enums"]["report_status"]
          summary: string | null
          title: string | null
          total_net_rappen: number | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "reports"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      sync_material_line: {
        Args: {
          p_description: string
          p_id: string
          p_project_id: string
          p_quantity_milli: number
          p_task_id?: string
          p_unit?: string
          p_unit_price_rappen?: number
        }
        Returns: {
          company_id: string
          created_at: string
          description: string
          id: string
          project_id: string
          quantity_milli: number
          recorded_by: string | null
          task_id: string | null
          unit: string
          unit_price_rappen: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "material_lines"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      sync_report_draft: {
        Args: {
          p_id: string
          p_project_id: string
          p_summary?: string
          p_title?: string
        }
        Returns: {
          client_content_hash: string | null
          company_id: string
          content_hash: string | null
          corrects_report_id: string | null
          created_at: string
          created_by: string | null
          customer_id: string | null
          doc_type: Database["public"]["Enums"]["document_type"]
          id: string
          number: number | null
          number_text: string | null
          pdf_generated_at: string | null
          pdf_path: string | null
          pdf_sha256: string | null
          period_from: string | null
          period_key: string | null
          period_to: string | null
          project_id: string
          sent_at: string | null
          signature_path: string | null
          signed_at: string | null
          signed_at_device: string | null
          signed_offline: boolean
          signer_name: string | null
          snapshot: Json | null
          status: Database["public"]["Enums"]["report_status"]
          summary: string | null
          title: string | null
          total_net_rappen: number | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "reports"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      sync_time_entry: {
        Args: {
          p_break_minutes?: number
          p_ended_at?: string
          p_id: string
          p_kind?: Database["public"]["Enums"]["time_entry_kind"]
          p_note?: string
          p_profile_id: string
          p_project_id: string
          p_started_at: string
          p_task_id?: string
        }
        Returns: {
          break_minutes: number
          company_id: string
          created_at: string
          ended_at: string | null
          id: string
          kind: Database["public"]["Enums"]["time_entry_kind"]
          note: string | null
          profile_id: string
          project_id: string
          recorded_by: string | null
          retain_until: string | null
          revision: number
          started_at: string
          task_id: string | null
          updated_at: string
          voided_at: string | null
          voided_reason: string | null
          work_date: string
          worked_minutes: number | null
        }
        SetofOptions: {
          from: "*"
          to: "time_entries"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      verify_render_secret: { Args: { p_secret: string }; Returns: boolean }
      verify_report_hash: { Args: { p_report_id: string }; Returns: boolean }
    }
    Enums: {
      app_role: "owner" | "manager" | "foreman" | "worker" | "customer"
      attachment_kind: "photo" | "voice" | "video"
      billing_mode: "regie" | "pauschal"
      device_platform: "ios" | "web"
      document_link_kind: "report" | "invoice"
      document_type: "rapport" | "invoice"
      invoice_status: "draft" | "issued" | "sent" | "paid" | "cancelled"
      message_kind: "text" | "photo" | "voice" | "video" | "system"
      message_ref_kind: "task" | "attachment"
      mwst_status:
        "registered_effective" | "registered_saldo" | "not_registered"
      notification_kind:
        | "chat_message"
        | "mention"
        | "task_assigned"
        | "task_status"
        | "task_due_soon"
        | "task_overdue"
      notification_status:
        "pending" | "sending" | "sent" | "failed" | "skipped" | "expired"
      project_status:
        "planning" | "active" | "on_hold" | "completed" | "archived"
      qr_reference_type: "QRR" | "SCOR" | "NON"
      report_status: "draft" | "signed" | "sent" | "cancelled"
      task_status: "todo" | "in_progress" | "blocked" | "done" | "approved"
      time_entry_kind: "work" | "travel" | "standby"
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
      billing_mode: ["regie", "pauschal"],
      device_platform: ["ios", "web"],
      document_link_kind: ["report", "invoice"],
      document_type: ["rapport", "invoice"],
      invoice_status: ["draft", "issued", "sent", "paid", "cancelled"],
      message_kind: ["text", "photo", "voice", "video", "system"],
      message_ref_kind: ["task", "attachment"],
      mwst_status: [
        "registered_effective",
        "registered_saldo",
        "not_registered",
      ],
      notification_kind: [
        "chat_message",
        "mention",
        "task_assigned",
        "task_status",
        "task_due_soon",
        "task_overdue",
      ],
      notification_status: [
        "pending",
        "sending",
        "sent",
        "failed",
        "skipped",
        "expired",
      ],
      project_status: [
        "planning",
        "active",
        "on_hold",
        "completed",
        "archived",
      ],
      qr_reference_type: ["QRR", "SCOR", "NON"],
      report_status: ["draft", "signed", "sent", "cancelled"],
      task_status: ["todo", "in_progress", "blocked", "done", "approved"],
      time_entry_kind: ["work", "travel", "standby"],
    },
  },
} as const

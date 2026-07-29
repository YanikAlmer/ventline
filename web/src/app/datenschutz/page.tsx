import type { Metadata } from "next";

import { PolicyPage } from "@/components/legal/policy-page";
import { PRIVACY_DE } from "@/content/privacy";

export const metadata: Metadata = {
  // The root layout already appends "· Ventline".
  title: "Datenschutzerklärung",
  // Indexable on purpose, unlike /r/[token]: App Store Connect fetches this
  // URL, and a policy nobody can find is not published.
  alternates: { languages: { en: "/privacy" } },
};

export default function DatenschutzPage() {
  return <PolicyPage policy={PRIVACY_DE} />;
}

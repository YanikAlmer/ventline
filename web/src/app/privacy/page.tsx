import type { Metadata } from "next";

import { PolicyPage } from "@/components/legal/policy-page";
import { PRIVACY_EN } from "@/content/privacy";

export const metadata: Metadata = {
  // The root layout already appends "· Ventline".
  title: "Privacy Policy",
  alternates: { languages: { de: "/datenschutz" } },
};

export default function PrivacyPage() {
  return <PolicyPage policy={PRIVACY_EN} />;
}

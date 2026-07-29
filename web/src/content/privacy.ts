/**
 * The privacy policy, in German and English.
 *
 * Written against what the app actually does, not against a template. Every
 * retention period below is the one the code enforces, and the two absences —
 * no location and no analytics — are absences in the code, not aspirations.
 *
 * The structure follows the one thing a Ventline policy has to get right:
 * **there are two controllers, not one.** For the account itself Ventline is
 * the controller. For everything a trades company puts into it — messages,
 * photos, hours, their own customers' addresses — the trades company is the
 * controller and Ventline is its processor. Collapsing those two into a single
 * "we process your data" section is the usual mistake and it makes the whole
 * document wrong about who a data subject should actually write to.
 */

/**
 * Values only the operator can supply. Deliberately left as obvious
 * placeholders rather than plausible guesses: a wrong legal entity or a
 * wrong supervisory authority in a published policy is worse than a visible
 * gap, and `isConfigured` below turns the gap into a banner on the page so it
 * cannot go live unnoticed.
 */
export const OPERATOR = {
  legalName: "TODO_LEGAL_ENTITY",
  address: "TODO_STREET, TODO_POSTCODE TODO_TOWN, Schweiz",
  email: "TODO_CONTACT_EMAIL",
  /** Where Supabase actually hosts this project. Check the dashboard. */
  hostingRegion: "TODO_SUPABASE_REGION",
  /** ISO date. Bump whenever the text below changes materially. */
  lastUpdated: "TODO_DATE",
} as const;

export const isConfigured = !Object.values(OPERATOR).some((v) =>
  v.includes("TODO_"),
);

export type Section = { heading: string; body: string[] };

export type Policy = {
  title: string;
  intro: string[];
  lastUpdatedLabel: string;
  sections: Section[];
  otherLanguage: { href: string; label: string };
};

export const PRIVACY_DE: Policy = {
  title: "Datenschutzerklärung",
  lastUpdatedLabel: "Letzte Aktualisierung",
  otherLanguage: { href: "/privacy", label: "English" },
  intro: [
    `Ventline ist ein Werkzeug für die Baustellenkommunikation von Handwerksbetrieben. ` +
      `Diese Erklärung beschreibt, welche Personendaten dabei bearbeitet werden, zu welchem ` +
      `Zweck und wie lange. Sie richtet sich nach dem revidierten Schweizer ` +
      `Datenschutzgesetz (revDSG) und, soweit anwendbar, nach der DSGVO.`,
  ],
  sections: [
    {
      heading: "1. Zwei Verantwortliche, nicht einer",
      body: [
        `Für dein **Benutzerkonto** — Name, E-Mail-Adresse, Rolle, Betriebszugehörigkeit — ist ` +
          `${OPERATOR.legalName} verantwortlich.`,
        `Für alles, was ein Betrieb **in** Ventline erfasst — Nachrichten, Fotos, Videos, ` +
          `Sprachnachrichten, Arbeitszeiten, Rapporte, Unterschriften und die Adressdaten seiner ` +
          `eigenen Kundinnen und Kunden — ist der **Betrieb** verantwortlich. Ventline bearbeitet ` +
          `diese Daten ausschliesslich in dessen Auftrag.`,
        `Praktisch heisst das: Fragen zum Konto gehen an uns, Fragen zu den Inhalten einer ` +
          `Baustelle an den Betrieb, der sie erfasst hat.`,
      ],
    },
    {
      heading: "2. Welche Daten bearbeitet werden",
      body: [
        `**Konto** — Name, E-Mail, optional Telefonnummer, Rolle, Betrieb.`,
        `**Baustelleninhalte** — Nachrichten, Fotos, Videos, Sprachnachrichten, ` +
          `Aufgaben und Notizen, samt Markierungen auf Fotos.`,
        `**Arbeitszeiten** — Beginn, Ende und Pausen pro Person und Auftrag. Die Erfassung ` +
          `erfüllt die Aufzeichnungspflicht nach ArG Art. 46 und ArGV 1 Art. 73.`,
        `**Rapporte und Rechnungen** — die erfassten Leistungen, der Name der ` +
          `unterzeichnenden Person, Zeitpunkt der Unterschrift und das Unterschriftsbild ` +
          `sowie Rechnungs- und Adressdaten.`,
        `**Geräte** — der Push-Token für Benachrichtigungen und eine vom Gerät erzeugte ` +
          `Kennung, damit dasselbe Gerät nicht mehrfach registriert wird.`,
        `**Dokumentlinks** — wird ein Rapport oder eine Rechnung über einen Link geöffnet, ` +
          `werden Zeitpunkt und Browserfamilie (z. B. „Safari") festgehalten, damit ` +
          `nachvollziehbar bleibt, ob das Dokument abgerufen wurde. Die vollständige ` +
          `User-Agent-Zeichenkette wird bewusst nicht gespeichert.`,
      ],
    },
    {
      heading: "3. Was ausdrücklich nicht bearbeitet wird",
      body: [
        `**Kein Standort.** Ventline erhebt zu keinem Zeitpunkt und in keiner Genauigkeit ` +
          `Standortdaten. Ein Rapport hält fest, wer wann gearbeitet hat, und bewusst nicht wo. ` +
          `ArGV 3 Art. 26 und OR 328b beschränken die Überwachung von Mitarbeitenden, und eine ` +
          `Einwilligung heilt das nicht.`,
        `**Kein Tracking.** Keine Analyse-Software, keine Werbenetzwerke, keine Weitergabe an ` +
          `Datenhändler, keine Profilbildung.`,
        `**Keine Cookies ausser dem Login.** Die Webanwendung setzt ausschliesslich das ` +
          `technisch notwendige Sitzungscookie.`,
      ],
    },
    {
      heading: "4. Empfänger und Auftragsbearbeiter",
      body: [
        `**Supabase** — Datenbank, Dateiablage und Authentifizierung. Hostingregion: ` +
          `${OPERATOR.hostingRegion}.`,
        `**Apple (APNs)** — Zustellung von Push-Benachrichtigungen an iPhones. An Apple geht ` +
          `nur der Push-Token und der anzuzeigende Text.`,
        `Werden Daten ausserhalb der Schweiz oder des EWR bearbeitet, geschieht dies auf ` +
          `Grundlage der Standardvertragsklauseln beziehungsweise eines Angemessenheitsbeschlusses.`,
      ],
    },
    {
      heading: "5. Aufbewahrung",
      body: [
        `**Arbeitszeiten: fünf Jahre.** Danach werden sie automatisch gelöscht (ArG Art. 46, ` +
          `ArGV 1 Art. 73). Der eingefrorene Auszug auf einem unterzeichneten Rapport bleibt ` +
          `bestehen, weil er zugleich Buchungsbeleg ist.`,
        `**Rapporte und Rechnungen: zehn Jahre** als Buchungsbelege nach OR 958f. Bei ` +
          `Leistungen an Grundstücken verlängert MWSTG Art. 70 Abs. 3 die Frist auf zwanzig Jahre.`,
        `**Chatnachrichten** mit gesetzter Ablauffrist werden zum eingestellten Zeitpunkt ` +
          `gelöscht, einschliesslich ihrer Anhänge.`,
        `**Geräte** werden nach 90 Tagen ohne Kontakt entfernt, Dokumentlinks mit ihrem Ablauf.`,
      ],
    },
    {
      heading: "6. Sicherheit",
      body: [
        `Der Zugriff wird in der Datenbank selbst durchgesetzt (Row Level Security), nicht ` +
          `erst in der App — eine Person sieht ausschliesslich, was ihre Rolle und ihre ` +
          `Projektzugehörigkeit erlauben.`,
        `Fotos, Videos und Unterschriften liegen in privaten Ablagen und werden nur über ` +
          `kurzlebige signierte Links ausgeliefert.`,
        `Dokumentlinks werden nur als Hash gespeichert; aus der Datenbank lässt sich ein ` +
          `gültiger Link nicht rekonstruieren. Wiederholte Fehlversuche werden begrenzt.`,
        `Die Übertragung erfolgt ausschliesslich verschlüsselt (TLS).`,
      ],
    },
    {
      heading: "7. Deine Rechte",
      body: [
        `Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der ` +
          `Bearbeitung, Widerspruch und Datenherausgabe beziehungsweise -übertragung.`,
        `Betrifft dein Anliegen Baustelleninhalte, wende dich an den Betrieb, der sie erfasst ` +
          `hat — er ist dafür verantwortlich. Betrifft es dein Konto, schreib an ` +
          `${OPERATOR.email}.`,
        `Du kannst dich ausserdem beim Eidgenössischen Datenschutz- und ` +
          `Öffentlichkeitsbeauftragten (EDÖB) beschweren.`,
      ],
    },
    {
      heading: "8. Änderungen",
      body: [
        `Diese Erklärung wird angepasst, wenn sich die Bearbeitung ändert. Massgeblich ist ` +
          `die jeweils hier veröffentlichte Fassung.`,
      ],
    },
    {
      heading: "9. Kontakt",
      body: [`${OPERATOR.legalName}`, `${OPERATOR.address}`, `${OPERATOR.email}`],
    },
  ],
};

export const PRIVACY_EN: Policy = {
  title: "Privacy Policy",
  lastUpdatedLabel: "Last updated",
  otherLanguage: { href: "/datenschutz", label: "Deutsch" },
  intro: [
    `Ventline is a jobsite communication tool for trades companies. This policy sets out ` +
      `what personal data is processed, why, and for how long. It follows the revised Swiss ` +
      `Data Protection Act (revDSG) and, where applicable, the GDPR.`,
  ],
  sections: [
    {
      heading: "1. Two controllers, not one",
      body: [
        `For your **user account** — name, email address, role, company membership — ` +
          `${OPERATOR.legalName} is the controller.`,
        `For everything a company records **in** Ventline — messages, photos, videos, voice ` +
          `notes, working hours, reports, signatures and the address details of its own ` +
          `customers — the **company** is the controller. Ventline processes that data solely ` +
          `on its instructions.`,
        `In practice: questions about the account come to us, questions about the contents of ` +
          `a job go to the company that recorded them.`,
      ],
    },
    {
      heading: "2. What is processed",
      body: [
        `**Account** — name, email, optional phone number, role, company.`,
        `**Jobsite content** — messages, photos, videos, voice notes, tasks and notes, ` +
          `including markup drawn on photos.`,
        `**Working hours** — start, end and breaks per person and job. Recording them ` +
          `satisfies the obligation under ArG Art. 46 and ArGV 1 Art. 73.`,
        `**Reports and invoices** — the work recorded, the name of the person signing, the ` +
          `time of signature and the signature image, along with invoice and address details.`,
        `**Devices** — the push token for notifications and a device-generated identifier, so ` +
          `the same handset is not registered twice.`,
        `**Document links** — when a report or invoice is opened through a link, the time and ` +
          `the browser family (e.g. "Safari") are recorded so it is possible to tell whether the ` +
          `document was retrieved. The full user-agent string is deliberately not stored.`,
      ],
    },
    {
      heading: "3. What is deliberately not processed",
      body: [
        `**No location, ever, at any precision.** A report records who worked and when, and ` +
          `deliberately not where. ArGV 3 Art. 26 and OR 328b limit monitoring of employees, and ` +
          `consent does not cure it.`,
        `**No tracking.** No analytics software, no ad networks, nothing shared with data ` +
          `brokers, no profiling.`,
        `**No cookies beyond the login.** The web application sets only the strictly necessary ` +
          `session cookie.`,
      ],
    },
    {
      heading: "4. Recipients and processors",
      body: [
        `**Supabase** — database, file storage and authentication. Hosting region: ` +
          `${OPERATOR.hostingRegion}.`,
        `**Apple (APNs)** — delivery of push notifications to iPhones. Apple receives only the ` +
          `push token and the text to display.`,
        `Where data is processed outside Switzerland or the EEA, this is done on the basis of ` +
          `the Standard Contractual Clauses or an adequacy decision.`,
      ],
    },
    {
      heading: "5. Retention",
      body: [
        `**Working hours: five years,** then deleted automatically (ArG Art. 46, ArGV 1 ` +
          `Art. 73). The frozen extract on a signed report remains, because it is also an ` +
          `accounting record.`,
        `**Reports and invoices: ten years** as accounting records under OR 958f. For work on ` +
          `immovable property, MWSTG Art. 70 para. 3 extends this to twenty years.`,
        `**Chat messages** with an expiry set are deleted at that time, together with their ` +
          `attachments.`,
        `**Devices** are removed after 90 days without contact; document links expire with ` +
          `their own validity.`,
      ],
    },
    {
      heading: "6. Security",
      body: [
        `Access is enforced in the database itself (Row Level Security) rather than in the app ` +
          `— a person sees only what their role and project membership allow.`,
        `Photos, videos and signatures live in private storage and are served only through ` +
          `short-lived signed links.`,
        `Document link tokens are stored only as a hash; a working link cannot be reconstructed ` +
          `from the database. Repeated failed attempts are rate-limited.`,
        `All transport is encrypted (TLS).`,
      ],
    },
    {
      heading: "7. Your rights",
      body: [
        `You have the right of access, rectification, erasure, restriction of processing, ` +
          `objection, and data portability.`,
        `If your request concerns jobsite content, contact the company that recorded it — they ` +
          `are the controller. If it concerns your account, write to ${OPERATOR.email}.`,
        `You may also lodge a complaint with the Federal Data Protection and Information ` +
          `Commissioner (FDPIC).`,
      ],
    },
    {
      heading: "8. Changes",
      body: [
        `This policy is updated when the processing changes. The version published here is the ` +
          `one that applies.`,
      ],
    },
    {
      heading: "9. Contact",
      body: [`${OPERATOR.legalName}`, `${OPERATOR.address}`, `${OPERATOR.email}`],
    },
  ],
};

// Generate TypeScript + Swift model types from a live database, using the
// same @supabase/postgres-meta generators the Supabase CLI runs — but in
// plain Node, so it works without Docker.
//
// Usage: node scripts/gen-types.mjs <db-url>

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { PostgresMeta } from "@supabase/postgres-meta";
import { getGeneratorMetadata } from "@supabase/postgres-meta/dist/lib/generators.js";
import { apply as applyTypescript } from "@supabase/postgres-meta/dist/server/templates/typescript.js";
import { apply as applySwift } from "@supabase/postgres-meta/dist/server/templates/swift.js";

const dbUrl = process.argv[2];
if (!dbUrl) {
  console.error("usage: node scripts/gen-types.mjs <db-url>");
  process.exit(1);
}

const repo = join(dirname(fileURLToPath(import.meta.url)), "..");
const pgMeta = new PostgresMeta({ connectionString: dbUrl, max: 1 });

const { data, error } = await getGeneratorMetadata(pgMeta, {
  includedSchemas: ["public"],
});
if (error) {
  console.error("postgres-meta error:", error.message ?? error);
  process.exit(1);
}

const tsOut = join(repo, "web/src/lib/database.types.ts");
mkdirSync(dirname(tsOut), { recursive: true });
writeFileSync(tsOut, await applyTypescript({ ...data, detectOneToOneRelationships: true }));
console.log(`wrote ${tsOut}`);

// postgres-meta's Swift template only knows the common Postgres types; for
// anything else it emits a reference to "<TypeName>Select", which then does not
// exist and breaks the build. Map those to the Swift type PostgREST actually
// serialises them as. tsvector arrived with the message search column; it is an
// index artefact no client reads, but the model still has to compile.
const SWIFT_TYPE_FALLBACKS = {
  TsvectorSelect: "String",
};

let swift = await applySwift({ ...data, accessControl: "public" });
for (const [from, to] of Object.entries(SWIFT_TYPE_FALLBACKS)) {
  const before = swift;
  swift = swift.replaceAll(from, to);
  if (before !== swift) console.log(`  mapped ${from} -> ${to}`);
}

const swiftOut = join(repo, "ios/Ventline/Core/Models/GeneratedModels.swift");
mkdirSync(dirname(swiftOut), { recursive: true });
writeFileSync(swiftOut, swift);
console.log(`wrote ${swiftOut}`);

await pgMeta.end();

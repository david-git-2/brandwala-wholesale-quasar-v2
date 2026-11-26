#!/usr/bin/env node
/**
 * Generates docs/datamodel/schema.sql, docs/datamodel/groups.json, and docs/datamodel/groups.md
 * from supabase/migrations/*.sql.
 *
 * - Maintains docs/datamodel/groups.json as the editable grouping source of truth:
 *   existing group/subgroup assignments are preserved across runs; newly added tables are
 *   auto-assigned by domain prefix, and dropped tables are pruned.
 * - Outputs schema.sql and groups.md in the exact format accepted by The Commons ER Study importer.
 */

import fs from 'node:fs';
import path from 'node:path';

const ROOT_DIR = process.cwd();
const MIGRATIONS_DIR = path.join(ROOT_DIR, 'supabase', 'migrations');
const DB_TYPES_PATH = path.join(ROOT_DIR, 'web', 'src', 'types', 'database.types.ts');
const OUT_DIR = path.join(ROOT_DIR, 'docs', 'datamodel');
const SCHEMA_OUT = path.join(OUT_DIR, 'schema.sql');
const GROUPS_JSON_OUT = path.join(OUT_DIR, 'groups.json');
const GROUPS_MD_OUT = path.join(OUT_DIR, 'groups.md');

function normalizeIdent(raw) {
	return raw.trim().replace(/^"+|"+$/g, '').toLowerCase();
}

function stripSchema(raw) {
	const cleaned = raw.trim().replace(/"/g, '');
	const parts = cleaned.split('.');
	return normalizeIdent(parts[parts.length - 1]);
}

function splitSqlStatements(sql) {
	const statements = [];
	let current = '';
	let i = 0;
	let inSingleQuote = false;
	let dollarTag = null;

	while (i < sql.length) {
		const ch = sql[i];
		const next = sql[i + 1];

		if (!inSingleQuote && !dollarTag) {
			if (ch === '-' && next === '-') {
				while (i < sql.length && sql[i] !== '\n') i++;
				current += '\n';
				continue;
			}
			if (ch === '/' && next === '*') {
				i += 2;
				while (i < sql.length && !(sql[i] === '*' && sql[i + 1] === '/')) i++;
				i += 2;
				current += ' ';
				continue;
			}
		}

		if (!dollarTag && ch === "'") {
			current += ch;
			if (inSingleQuote && next === "'") {
				current += next;
				i += 2;
				continue;
			}
			inSingleQuote = !inSingleQuote;
			i++;
			continue;
		}

		if (!inSingleQuote && ch === '$') {
			const rest = sql.slice(i);
			const tagMatch = rest.match(/^(\$[a-zA-Z_0-9]*\$)/);
			if (tagMatch) {
				const tag = tagMatch[1];
				if (!dollarTag) {
					dollarTag = tag;
				} else if (dollarTag === tag) {
					dollarTag = null;
				}
				current += tag;
				i += tag.length;
				continue;
			}
		}

		if (!inSingleQuote && !dollarTag && ch === ';') {
			const trimmed = current.trim();
			if (trimmed) statements.push(trimmed);
			current = '';
			i++;
			continue;
		}

		current += ch;
		i++;
	}

	const tail = current.trim();
	if (tail) statements.push(tail);
	return statements;
}

function splitTopLevelCommas(body) {
	const parts = [];
	let current = '';
	let depth = 0;
	let inSingleQuote = false;

	for (let i = 0; i < body.length; i++) {
		const ch = body[i];
		const next = body[i + 1];

		if (ch === "'") {
			current += ch;
			if (inSingleQuote && next === "'") {
				current += next;
				i++;
				continue;
			}
			inSingleQuote = !inSingleQuote;
			continue;
		}

		if (!inSingleQuote) {
			if (ch === '(') depth++;
			else if (ch === ')') depth = Math.max(0, depth - 1);
			else if (ch === ',' && depth === 0) {
				const trimmed = current.trim();
				if (trimmed) parts.push(trimmed);
				current = '';
				continue;
			}
		}

		current += ch;
	}

	const tail = current.trim();
	if (tail) parts.push(tail);
	return parts;
}

function extractParenBody(str, openIdx) {
	let depth = 0;
	let inSingleQuote = false;
	for (let i = openIdx; i < str.length; i++) {
		const ch = str[i];
		const next = str[i + 1];
		if (ch === "'") {
			if (inSingleQuote && next === "'") {
				i++;
				continue;
			}
			inSingleQuote = !inSingleQuote;
			continue;
		}
		if (!inSingleQuote) {
			if (ch === '(') depth++;
			else if (ch === ')') {
				depth--;
				if (depth === 0) {
					return { body: str.slice(openIdx + 1, i), closeIdx: i };
				}
			}
		}
	}
	return null;
}

function parseColumnDef(def) {
	const trimmed = def.trim().replace(/\s+/g, ' ');
	const nameMatch = trimmed.match(/^("?[a-zA-Z_][a-zA-Z0-9_$]*"?)\s+(.+)$/);
	if (!nameMatch) return null;

	const name = normalizeIdent(nameMatch[1]);
	let rest = nameMatch[2];

	// Extract REFERENCES if inline
	let fk = null;
	const refMatch = rest.match(
		/\bREFERENCES\s+((?:[a-zA-Z_][a-zA-Z0-9_"]*\.)?[a-zA-Z_][a-zA-Z0-9_"]*)\s*(?:\(\s*("?[a-zA-Z_][a-zA-Z0-9_"]*"?)\s*\))?/i
	);
	if (refMatch) {
		fk = {
			toTable: stripSchema(refMatch[1]),
			toColumn: refMatch[2] ? normalizeIdent(refMatch[2]) : 'id'
		};
	}

	const isPrimary = /\bPRIMARY\s+KEY\b/i.test(rest);
	const isNotNull = /\bNOT\s+NULL\b/i.test(rest) || isPrimary;

	// Extract data type up to first constraint keyword
	const typePart = rest
		.replace(
			/\b(NOT\s+NULL|NULL|PRIMARY\s+KEY|UNIQUE|DEFAULT|REFERENCES|CHECK|GENERATED|CONSTRAINT|COLLATE)\b.*$/i,
			''
		)
		.trim();

	return {
		name,
		type: typePart || 'text',
		notNull: isNotNull,
		primary: isPrimary,
		fk
	};
}

function inferSqlTypeFromTs(colName, tsType) {
	const clean = tsType.replace(/\|\s*null/g, '').trim();
	if (clean === 'boolean') return 'boolean';
	if (clean === 'Json' || clean.endsWith('[]')) return 'jsonb';
	if (clean === 'number') {
		if (colName === 'id' || colName.endsWith('_id') || colName.endsWith('_count') || colName === 'qty') {
			return 'bigint';
		}
		return 'numeric';
	}
	if (clean.includes('Enums[')) {
		const enumMatch = clean.match(/Enums\["([^"]+)"\]/);
		return enumMatch ? enumMatch[1] : 'text';
	}
	if (colName.endsWith('_at')) return 'timestamptz';
	if (colName.endsWith('_date')) return 'date';
	if (colName === 'uuid' || colName.endsWith('_uuid')) return 'uuid';
	return 'text';
}

function parseSchemaFromDatabaseTypes(tables) {
	if (!fs.existsSync(DB_TYPES_PATH)) return;
	const src = fs.readFileSync(DB_TYPES_PATH, 'utf8');

	const publicIdx = src.indexOf('"public":');
	const tablesIdx = src.indexOf('Tables:', publicIdx);
	const viewsIdx = src.indexOf('Views:', tablesIdx);
	if (publicIdx === -1 || tablesIdx === -1 || viewsIdx === -1) return;

	const tablesSection = src.slice(tablesIdx, viewsIdx);
	const tableHeaderRe = /"([a-zA-Z_][a-zA-Z0-9_]*)":\s*\{\s*Row:\s*\{/g;
	let match;

	while ((match = tableHeaderRe.exec(tablesSection)) !== null) {
		const tableName = normalizeIdent(match[1]);
		const rowStart = match.index + match[0].length - 1;
		const rowBlock = extractBraceBody(tablesSection, rowStart);
		if (!rowBlock) continue;

		const tableBlockStart = tablesSection.indexOf('{', match.index);
		const fullTableBlock = extractBraceBody(tablesSection, tableBlockStart);

		const table = {
			name: tableName,
			columns: new Map(),
			primaryKeys: new Set(),
			fks: []
		};

		// Parse Row fields: "col": type
		const rowText = rowBlock.body.replace(/\n/g, ' ');
		const fieldRe = /"([a-zA-Z_][a-zA-Z0-9_$]*)":\s*([^,"]+(?:\s*\|\s*null)?(?:\[\])?)/g;
		let fMatch;
		while ((fMatch = fieldRe.exec(rowText)) !== null) {
			const colName = normalizeIdent(fMatch[1]);
			const tsType = fMatch[2].trim();
			const notNull = !/\|\s*null\b/.test(tsType);
			const isPrimary = colName === 'id';
			table.columns.set(colName, {
				name: colName,
				type: inferSqlTypeFromTs(colName, tsType),
				notNull: notNull || isPrimary,
				primary: isPrimary,
				fk: null
			});
			if (isPrimary) table.primaryKeys.add(colName);
		}

		// Parse Relationships
		if (fullTableBlock) {
			const relIdx = fullTableBlock.body.indexOf('Relationships:');
			if (relIdx !== -1) {
				const relSection = fullTableBlock.body.slice(relIdx);
				const relRe =
					/columns:\s*\["([^"]+)"\][\s\S]*?referencedRelation:\s*"([^"]+)"[\s\S]*?referencedColumns:\s*\["([^"]+)"\]/g;
				let rMatch;
				while ((rMatch = relRe.exec(relSection)) !== null) {
					table.fks.push({
						fromCol: normalizeIdent(rMatch[1]),
						toTable: normalizeIdent(rMatch[2]),
						toCol: normalizeIdent(rMatch[3])
					});
				}
			}
		}

		tables.set(tableName, table);
	}
}

function extractBraceBody(str, openIdx) {
	let depth = 0;
	let inQuote = false;
	for (let i = openIdx; i < str.length; i++) {
		const ch = str[i];
		if (ch === '"' && str[i - 1] !== '\\') {
			inQuote = !inQuote;
			continue;
		}
		if (!inQuote) {
			if (ch === '{') depth++;
			else if (ch === '}') {
				depth--;
				if (depth === 0) return { body: str.slice(openIdx + 1, i), closeIdx: i };
			}
		}
	}
	return null;
}

function parseSchemaFromMigrations() {
	if (!fs.existsSync(MIGRATIONS_DIR)) {
		throw new Error(`Migrations directory not found: ${MIGRATIONS_DIR}`);
	}

	const files = fs
		.readdirSync(MIGRATIONS_DIR)
		.filter((f) => f.endsWith('.sql'))
		.sort();

	/** @type {Map<string, { name: string, columns: Map<string, any>, primaryKeys: Set<string>, fks: Array<{ fromCol: string, toTable: string, toCol: string }> }>} */
	const tables = new Map();
	console.log(`[1/4] Parsing baseline schema from ${path.relative(ROOT_DIR, DB_TYPES_PATH)}...`);
	parseSchemaFromDatabaseTypes(tables);
	console.log(`      Found ${tables.size} baseline tables.`);
	console.log(`[2/4] Applying ${files.length} migration file(s) from supabase/migrations/...`);

	const getOrCreateTable = (tableName) => {
		if (!tables.has(tableName)) {
			tables.set(tableName, {
				name: tableName,
				columns: new Map(),
				primaryKeys: new Set(),
				fks: []
			});
		}
		return tables.get(tableName);
	};

	for (const file of files) {
		const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
		const statements = splitSqlStatements(sql);

		for (const stmt of statements) {
			const normalized = stmt.replace(/\s+/g, ' ').trim();

			// CREATE TABLE
			const createMatch = normalized.match(
				/^CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?((?:[a-zA-Z_][a-zA-Z0-9_"]*\.)?[a-zA-Z_][a-zA-Z0-9_"]*)\s*\(/i
			);
			if (createMatch) {
				const rawTarget = createMatch[1].replace(/"/g, '').toLowerCase();
				if (rawTarget.includes('.') && !rawTarget.startsWith('public.')) continue;

				const tableName = stripSchema(createMatch[1]);
				const openIdx = stmt.indexOf('(');
				const extracted = openIdx !== -1 ? extractParenBody(stmt, openIdx) : null;
				if (!extracted) continue;

				const table = {
					name: tableName,
					columns: new Map(),
					primaryKeys: new Set(),
					fks: []
				};
				tables.set(tableName, table);

				const items = splitTopLevelCommas(extracted.body);
				for (const item of items) {
					const cleanItem = item.replace(/\s+/g, ' ').trim();

					// Table-level PRIMARY KEY
					const pkMatch = cleanItem.match(/^(?:CONSTRAINT\s+\S+\s+)?PRIMARY\s+KEY\s*\(([^)]+)\)/i);
					if (pkMatch) {
						for (const col of pkMatch[1].split(',')) {
							const cName = normalizeIdent(col);
							table.primaryKeys.add(cName);
							const existing = table.columns.get(cName);
							if (existing) existing.notNull = true;
						}
						continue;
					}

					// Table-level FOREIGN KEY
					const fkMatch = cleanItem.match(
						/^(?:CONSTRAINT\s+\S+\s+)?FOREIGN\s+KEY\s*\(([^)]+)\)\s+REFERENCES\s+((?:[a-zA-Z_][a-zA-Z0-9_"]*\.)?[a-zA-Z_][a-zA-Z0-9_"]*)\s*(?:\(\s*([^)]+)\s*\))?/i
					);
					if (fkMatch) {
						const fromCols = fkMatch[1].split(',').map(normalizeIdent);
						const toTable = stripSchema(fkMatch[2]);
						const toCols = fkMatch[3]
							? fkMatch[3].split(',').map(normalizeIdent)
							: ['id'];
						fromCols.forEach((fc, idx) => {
							table.fks.push({
								fromCol: fc,
								toTable,
								toCol: toCols[idx] ?? toCols[0] ?? 'id'
							});
						});
						continue;
					}

					// Skip CHECK / UNIQUE / EXCLUDE constraints
					if (/^(?:CONSTRAINT|CHECK|UNIQUE|EXCLUDE)\b/i.test(cleanItem)) continue;

					const col = parseColumnDef(cleanItem);
					if (!col) continue;
					table.columns.set(col.name, col);
					if (col.primary) table.primaryKeys.add(col.name);
					if (col.fk) {
						table.fks.push({
							fromCol: col.name,
							toTable: col.fk.toTable,
							toCol: col.fk.toColumn
						});
					}
				}
				continue;
			}

			// DROP TABLE
			const dropMatch = normalized.match(
				/^DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?((?:[a-zA-Z_][a-zA-Z0-9_"]*\.)?[a-zA-Z_][a-zA-Z0-9_"]*)/i
			);
			if (dropMatch) {
				const rawTarget = dropMatch[1].replace(/"/g, '').toLowerCase();
				if (rawTarget.includes('.') && !rawTarget.startsWith('public.')) continue;
				tables.delete(stripSchema(dropMatch[1]));
				continue;
			}

			// ALTER TABLE
			const alterMatch = normalized.match(
				/^ALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?(?:ONLY\s+)?((?:[a-zA-Z_][a-zA-Z0-9_"]*\.)?[a-zA-Z_][a-zA-Z0-9_"]*)\s+(.+)$/i
			);
			if (alterMatch) {
				const rawTarget = alterMatch[1].replace(/"/g, '').toLowerCase();
				if (rawTarget.includes('.') && !rawTarget.startsWith('public.')) continue;
				const tableName = stripSchema(alterMatch[1]);
				const table = tables.get(tableName);
				if (!table) continue;

				const clauses = splitTopLevelCommas(alterMatch[2]);
				for (const clause of clauses) {
					const c = clause.trim();

					const renameTableMatch = c.match(/^RENAME\s+TO\s+("?[a-zA-Z_][a-zA-Z0-9_"]*"?)$/i);
					if (renameTableMatch) {
						const nextName = stripSchema(renameTableMatch[1]);
						tables.delete(tableName);
						table.name = nextName;
						tables.set(nextName, table);
						break;
					}

					const addColMatch = c.match(/^ADD\s+(?:COLUMN\s+)?(?:IF\s+NOT\s+EXISTS\s+)?(.+)$/i);
					if (addColMatch && !/^(?:CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK)\b/i.test(addColMatch[1])) {
						const col = parseColumnDef(addColMatch[1]);
						if (col) {
							table.columns.set(col.name, col);
							if (col.primary) table.primaryKeys.add(col.name);
							if (col.fk) {
								table.fks.push({
									fromCol: col.name,
									toTable: col.fk.toTable,
									toCol: col.fk.toColumn
								});
							}
						}
						continue;
					}

					const dropColMatch = c.match(
						/^DROP\s+(?:COLUMN\s+)?(?:IF\s+EXISTS\s+)?("?[a-zA-Z_][a-zA-Z0-9_"]*"?)/i
					);
					if (dropColMatch && !/^CONSTRAINT\b/i.test(dropColMatch[1])) {
						const colName = normalizeIdent(dropColMatch[1]);
						table.columns.delete(colName);
						table.primaryKeys.delete(colName);
						table.fks = table.fks.filter((fk) => fk.fromCol !== colName);
						continue;
					}

					const renameColMatch = c.match(
						/^RENAME\s+(?:COLUMN\s+)?("?[a-zA-Z_][a-zA-Z0-9_"]*"?)\s+TO\s+("?[a-zA-Z_][a-zA-Z0-9_"]*"?)/i
					);
					if (renameColMatch) {
						const oldCol = normalizeIdent(renameColMatch[1]);
						const newCol = normalizeIdent(renameColMatch[2]);
						const existing = table.columns.get(oldCol);
						if (existing) {
							table.columns.delete(oldCol);
							existing.name = newCol;
							table.columns.set(newCol, existing);
						}
						if (table.primaryKeys.has(oldCol)) {
							table.primaryKeys.delete(oldCol);
							table.primaryKeys.add(newCol);
						}
						table.fks.forEach((fk) => {
							if (fk.fromCol === oldCol) fk.fromCol = newCol;
						});
						continue;
					}

					const addFkMatch = c.match(
						/^ADD\s+(?:CONSTRAINT\s+\S+\s+)?FOREIGN\s+KEY\s*\(([^)]+)\)\s+REFERENCES\s+((?:[a-zA-Z_][a-zA-Z0-9_"]*\.)?[a-zA-Z_][a-zA-Z0-9_"]*)\s*(?:\(\s*([^)]+)\s*\))?/i
					);
					if (addFkMatch) {
						const fromCols = addFkMatch[1].split(',').map(normalizeIdent);
						const toTable = stripSchema(addFkMatch[2]);
						const toCols = addFkMatch[3]
							? addFkMatch[3].split(',').map(normalizeIdent)
							: ['id'];
						fromCols.forEach((fc, idx) => {
							table.fks.push({
								fromCol: fc,
								toTable,
								toCol: toCols[idx] ?? toCols[0] ?? 'id'
							});
						});
						continue;
					}

					const addPkMatch = c.match(
						/^ADD\s+(?:CONSTRAINT\s+\S+\s+)?PRIMARY\s+KEY\s*\(([^)]+)\)/i
					);
					if (addPkMatch) {
						for (const col of addPkMatch[1].split(',')) {
							const colName = normalizeIdent(col);
							table.primaryKeys.add(colName);
							const existing = table.columns.get(colName);
							if (existing) existing.notNull = true;
						}
					}
				}
			}
		}
	}

	return tables;
}

function renderSchemaSql(tables) {
	const sorted = Array.from(tables.values()).sort((a, b) => a.name.localeCompare(b.name));
	const blocks = sorted.map((t) => {
		const lines = [];
		for (const col of t.columns.values()) {
			const nullability = col.notNull ? 'NOT NULL' : 'NULL';
			lines.push(`  ${col.name} ${col.type} ${nullability}`);
		}
		if (t.primaryKeys.size > 0) {
			lines.push(`  PRIMARY KEY (${Array.from(t.primaryKeys).join(', ')})`);
		}
		const seenFk = new Set();
		for (const fk of t.fks) {
			const key = `${fk.fromCol}->${fk.toTable}.${fk.toCol}`;
			if (seenFk.has(key)) continue;
			seenFk.add(key);
			lines.push(`  FOREIGN KEY (${fk.fromCol}) REFERENCES public.${fk.toTable}(${fk.toCol})`);
		}
		return `CREATE TABLE public.${t.name} (\n${lines.join(',\n')}\n);`;
	});

	return `-- Auto-generated by pnpm datamodel (${new Date().toISOString()})\n-- Source: supabase/migrations/*.sql\n\n${blocks.join('\n\n')}\n`;
}

function inferGroupPath(tableName) {
	if (/^(tenant|user|profile|role|permission|auth|session|member|whitelist|invite)/.test(tableName)) {
		return { group: 'Core & Auth', subgroup: null };
	}
	if (/^pp_/.test(tableName)) {
		return { group: 'People & Portal', subgroup: null };
	}
	if (/^(product|catalog|brand|category|categories|variant|sku|price|pricing|attribute|tag|collection)/.test(tableName) || /_products?$/.test(tableName)) {
		return { group: 'Catalog & Products', subgroup: null };
	}
	if (/^(inv_|inventory|stock|warehouse|bin|location|batch|lot|pick|transfer)/.test(tableName)) {
		return { group: 'Inventory & Warehouse', subgroup: null };
	}
	if (/^(sales_|order|bill|invoice|cart|quote|customer|shop_order|shipment|delivery|return)/.test(tableName)) {
		return { group: 'Sales & Orders', subgroup: null };
	}
	if (/^(purchase|po_|vendor|supplier|grn|receiving)/.test(tableName)) {
		return { group: 'Purchasing & Vendors', subgroup: null };
	}
	if (/^(fin_|finance|ledger|account|payment|transaction|journal|tax|credit|refund|wallet)/.test(tableName)) {
		return { group: 'Finance & Accounting', subgroup: null };
	}
	if (/^(comment|activity|audit|log|notification|webhook|job|queue|sync|scrape|import|export)/.test(tableName)) {
		return { group: 'System & Activity', subgroup: null };
	}
	return { group: 'Other', subgroup: null };
}

function syncGroupsJson(tables) {
	const existingTableNames = new Set(tables.keys());

	/** @type {Array<{ name: string, tables: string[], subgroups: Array<{ name: string, tables: string[] }> }>} */
	let groups = [];
	if (fs.existsSync(GROUPS_JSON_OUT)) {
		try {
			const raw = JSON.parse(fs.readFileSync(GROUPS_JSON_OUT, 'utf8'));
			if (Array.isArray(raw)) {
				groups = raw.map((g) => ({
					name: String(g.name),
					tables: Array.isArray(g.tables)
						? g.tables.map(String).filter((t) => existingTableNames.has(t))
						: [],
					subgroups: Array.isArray(g.subgroups)
						? g.subgroups.map((sg) => ({
								name: String(sg.name),
								tables: Array.isArray(sg.tables)
									? sg.tables.map(String).filter((t) => existingTableNames.has(t))
									: []
							}))
						: []
				}));
			}
		} catch {
			groups = [];
		}
	}

	const assigned = new Set();
	for (const g of groups) {
		for (const t of g.tables) assigned.add(t);
		for (const sg of g.subgroups) {
			for (const t of sg.tables) assigned.add(t);
		}
	}

	const newTables = Array.from(existingTableNames)
		.filter((t) => !assigned.has(t))
		.sort();

	for (const t of newTables) {
		const { group: groupName, subgroup: subName } = inferGroupPath(t);
		let grp = groups.find((g) => g.name.toLowerCase() === groupName.toLowerCase());
		if (!grp) {
			grp = { name: groupName, tables: [], subgroups: [] };
			groups.push(grp);
		}
		if (subName) {
			let sub = grp.subgroups.find((s) => s.name.toLowerCase() === subName.toLowerCase());
			if (!sub) {
				sub = { name: subName, tables: [] };
				grp.subgroups.push(sub);
			}
			sub.tables.push(t);
		} else {
			grp.tables.push(t);
		}
	}

	for (const g of groups) {
		g.tables = Array.from(new Set(g.tables)).sort();
		for (const sg of g.subgroups) {
			sg.tables = Array.from(new Set(sg.tables)).sort();
		}
	}

	return { groups, addedCount: newTables.length };
}

function renderGroupsMd(groups) {
	const lines = [
		'<!-- Auto-generated from docs/datamodel/groups.json by pnpm datamodel -->',
		''
	];
	for (const g of groups) {
		lines.push(`# ${g.name}`);
		for (const t of g.tables) {
			lines.push(`- ${t}`);
		}
		for (const sg of g.subgroups) {
			lines.push(`## ${sg.name}`);
			for (const t of sg.tables) {
				lines.push(`- ${t}`);
			}
		}
		lines.push('');
	}
	return lines.join('\n');
}

function main() {
	const tables = parseSchemaFromMigrations();
	console.log(`[3/4] Syncing groups with ${path.relative(ROOT_DIR, GROUPS_JSON_OUT)}...`);
	const { groups, addedCount } = syncGroupsJson(tables);

	console.log(`[4/4] Writing datamodel files to ${path.relative(ROOT_DIR, OUT_DIR)}/...`);
	fs.mkdirSync(OUT_DIR, { recursive: true });
	fs.writeFileSync(SCHEMA_OUT, renderSchemaSql(tables), 'utf8');
	fs.writeFileSync(GROUPS_JSON_OUT, JSON.stringify(groups, null, 2) + '\n', 'utf8');
	fs.writeFileSync(GROUPS_MD_OUT, renderGroupsMd(groups), 'utf8');

	console.log(
		`\nDone: ${tables.size} tables, ${groups.length} groups (${addedCount} newly assigned)`
	);
	console.log('Generated files:');
	console.log(`  - ${SCHEMA_OUT}`);
	console.log(`  - ${GROUPS_JSON_OUT}`);
	console.log(`  - ${GROUPS_MD_OUT}`);
}

main();

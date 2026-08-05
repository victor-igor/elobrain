#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bun run install:codex-skills [--dry-run]

Installs elobrain skills into the user-level Codex skill directory so they are
available from every local project. This does not delete unrelated Codex skills.
Restart Codex after installation, then invoke a skill with `$skill-name` or
natural language (for example, `$salve`), not `/skill-name`.
EOF
}

dry_run=false
case "${1:-}" in
  "") ;;
  --dry-run) dry_run=true ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_skills="$repo_dir/skills"
target_skills="${CODEX_HOME:-$HOME/.codex}/skills"

if [[ ! -d "$source_skills" ]]; then
  echo "Skills source not found: $source_skills" >&2
  exit 1
fi

if ! $dry_run; then
  mkdir -p "$target_skills"

  # Shared references used by the imported skills. They do not contain SKILL.md,
  # so Codex will not discover them as separate skills.
  for shared_path in _brain-filing-rules.json _brain-filing-rules.md _friction-protocol.md _output-rules.md conventions migrations; do
    if [[ -e "$source_skills/$shared_path" ]]; then
      rsync -a "$source_skills/$shared_path" "$target_skills/"
    fi
  done
fi

installed=0
while IFS= read -r source_dir; do
  source_name=$(basename "$source_dir")
  destination_name=$source_name

  # Keep Codex's bundled skill-creator unambiguous.
  if [[ "$source_name" == "skill-creator" ]]; then
    destination_name=elo-skill-creator
  fi

  destination_dir="$target_skills/$destination_name"
  if $dry_run; then
    printf 'Would install %s -> %s\n' "$source_name" "$destination_dir"
    installed=$((installed + 1))
    continue
  fi

  mkdir -p "$destination_dir"
  rsync -a "$source_dir/" "$destination_dir/"

  # Claude allows extra frontmatter fields; Codex only accepts name and
  # description. Preserve the body and bundled resources unchanged.
  temporary_skill=$(mktemp "$destination_dir/.SKILL.md.XXXXXX")
  awk -v destination_name="$destination_name" '
    function clean_description(line) {
      gsub(/</, "(", line)
      gsub(/>/, ")", line)
      return line
    }
    NR == 1 {
      if ($0 != "---") {
        print "---"
        print "name: " destination_name
        print "description: Legacy elobrain workflow. Use when the user requests " destination_name "."
        print "---"
        print
        in_frontmatter = 0
        next
      }
      print
      in_frontmatter = 1
      next
    }
    in_frontmatter && $0 == "---" {
      print
      in_frontmatter = 0
      keep_description = 0
      skip_description = 0
      next
    }
    !in_frontmatter { print; next }
    /^name:/ {
      print "name: " destination_name
      keep_description = 0
      skip_description = 0
      next
    }
    /^description:/ {
      if (destination_name == "elo-configurar-openclaw") {
        print "description: Configura ou audita instâncias OpenClaw locais, Docker ou remotas por SSH. Use para setup, melhorias ou diagnóstico de OpenClaw."
        keep_description = 0
        skip_description = 1
      } else if ($0 ~ /^description:[[:space:]]*[>|][[:space:]]*$/) {
        print
        keep_description = 1
        skip_description = 0
      } else {
        print clean_description($0)
        keep_description = 1
        skip_description = 0
      }
      next
    }
    skip_description && /^[[:space:]]+/ { next }
    keep_description && /^[[:space:]]+/ {
      print clean_description($0)
      next
    }
    {
      keep_description = 0
      skip_description = 0
    }
  ' "$source_dir/SKILL.md" > "$temporary_skill"
  mv "$temporary_skill" "$destination_dir/SKILL.md"

  printf 'Installed %s\n' "$destination_name"
  installed=$((installed + 1))
done < <(find "$source_skills" -mindepth 1 -maxdepth 1 -type d -exec sh -c 'test -f "$1/SKILL.md" && printf "%s\n" "$1"' _ {} \; | sort)

printf 'Installed %s elobrain skills in %s\n' "$installed" "$target_skills"
printf 'Restart Codex, then use $salve (or “salve a sessão”). /salve is a Claude-style alias, not a Codex custom command.\n'

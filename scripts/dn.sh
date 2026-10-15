#!/usr/bin/env bash
# dn: friendly menus for the dotnet CLI.
#
#   dn             open the menu (run it in your solution or project folder)
#   dn <words>     jump straight to an action: dn run, dn add package, dn ef scaffold …
#
# Every action prints the real `dotnet …` command before running it,
# so you pick up the actual commands along the way.
#
# Needs bash 4.4+, a .NET 8+ SDK, gum (v2) and jq. Plain Linux tools otherwise,
# so it also works without Nix. With Nix, dn.nix provides gum and jq.
set -euo pipefail
shopt -s nullglob

if (( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 404 )); then
  echo "dn needs bash 4.4 or newer, this is $BASH_VERSION (on macOS: brew install bash)" >&2
  exit 1
fi

# Without a height, `gum filter` takes over the whole screen (like `less`),
# which hid the output of the previous action whenever the menu came back.
export GUM_FILTER_HEIGHT=${GUM_FILTER_HEIGHT:-16}

# ── state ─────────────────────────────────────────────────────────────
# Bash functions can't return strings without a subshell, and a subshell
# can't quit dn on Ctrl+C, so the pickers below store results in these.
answer=""                  # result of the last `ask`
proj="" sln="" target=""   # results of the pick_* helpers
version=""                 # result of pick_version
pkg_list=""                # result of search_packages
ef_project="" ef_startup="" ef_ready=false
ef_args=()
printed=false              # did the last action print output worth reading?
sdk_version="?" sdk_major=0
answer_file=$(mktemp)
trap 'rm -f "$answer_file"' EXIT

menu=(
  "New project"
  "New solution"
  "New file from template (.gitignore, global.json, …)"
  "Add package (NuGet)"
  "Remove package"
  "Update packages"
  "Add project reference"
  "Remove project reference"
  "Add projects to solution"
  "Remove projects from solution"
  "Run"
  "Watch (hot reload)"
  "Build"
  "Test"
  "Clean"
  "Restore"
  "Format code"
  "EF Core: add migration"
  "EF Core: update database"
  "EF Core: remove last migration"
  "EF Core: list migrations"
  "EF Core: scaffold from existing database"
  "EF Core: choose projects"
  "Overview"
  "Quit"
)

# ── output ────────────────────────────────────────────────────────────
title() { echo; gum style --bold --foreground 212 "▸ $*"; }
note()  { gum style --faint "$*"; }
fail()  { gum style --foreground 9 "✗ $*" >&2; }

# quote <arg>: quote an argument the way you'd type it (for printing commands)
quote() {
  if [[ $1 =~ ^[A-Za-z0-9_./:=@%+,-]+$ ]]; then printf '%s' "$1"
  else printf "'%s'" "${1//\'/\'\\\'\'}"; fi
}

# run <command…>: print the command, then run it. Ctrl+C stops the command, not dn.
run() {
  local line="" arg status=0
  printed=true
  for arg in "$@"; do line+=" $(quote "$arg")"; done
  gum style --foreground 212 "\$${line}"
  trap ':' INT
  "$@" || status=$?
  trap - INT
  if (( status == 130 )); then echo; note "stopped (ctrl+c)"
  elif (( status != 0 )); then fail "exited with code $status"; fi
  return "$status"
}

# pause: keep the last action's output on screen until a key is pressed
pause() {
  [[ -t 0 ]] || return 0
  read -rsn1 -p "$(gum style --faint 'press any key to go back to the menu')" || true
  while read -rsn1 -t 0.05; do :; done   # swallow the rest of keys like ↑ that send several bytes
  echo
}

# ask <gum command> [flags…]: show a gum prompt, the result lands in $answer.
# Returns non-zero on Esc (and on "No" in a confirm) so callers can go back.
# Ctrl+C makes gum exit with 130, which quits dn.
ask() {
  local status=0
  gum "$@" >"$answer_file" || status=$?
  if (( status == 130 )); then exit 130; fi
  answer=$(<"$answer_file")
  return "$status"
}

# ── finding things ────────────────────────────────────────────────────
# Project files below the current folder (skips bin/, obj/ and hidden folders).
projects() {
  { find . -maxdepth 5 -type d \( -name bin -o -name obj -o -name node_modules -o -name '.?*' \) -prune \
      -o -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -print 2>/dev/null || true; } |
    sed 's|^\./||' | sort
}

# Projects that look runnable (Exe, web, worker), without test projects.
# Falls back to all projects if the guess finds nothing.
runnable_projects() {
  local f found=""
  while IFS= read -r f; do
    if grep -qE 'Microsoft\.NET\.Test\.Sdk|<IsTestProject>[[:space:]]*true|Sdk="MSTest\.Sdk' "$f"; then continue; fi
    if grep -qE '<OutputType>[[:space:]]*(Win)?Exe|Sdk="Microsoft\.NET\.Sdk\.(Web|Worker|BlazorWebAssembly)"' "$f"; then
      found+="$f"$'\n'
    fi
  done < <(projects)
  if [[ -n $found ]]; then printf '%s' "$found"; else projects; fi
}

# pick_from <header> <lines>: pick one project (no prompt if there's only one). Sets $proj.
pick_from() {
  if [[ -z $2 ]]; then
    fail "No project found below ${PWD/#"$HOME"/\~}. Create one with 'New project'."
    return 1
  fi
  if [[ $2 != *$'\n'* ]]; then proj=$2; note "Project: $proj"; return 0; fi
  ask filter --header "$1" --placeholder "type to filter" <<<"$2" || return 1
  [[ -n $answer ]] || return 1
  proj=$answer
}
pick_project()  { pick_from "$1" "$(projects)"; }
pick_runnable() { pick_from "$1" "$(runnable_projects)"; }

# pick_solution: sets $sln to the .sln/.slnx in this folder (asks if there are several).
pick_solution() {
  local sols=(*.sln *.slnx)
  case ${#sols[@]} in
    0) return 1 ;;
    1) sln=${sols[0]} ;;
    *) ask choose --header "Which solution?" "${sols[@]}" || return 1; sln=$answer ;;
  esac
}

# pick_target <header>: the solution if there is one, otherwise a project. Sets $target.
pick_target() {
  if pick_solution; then target=$sln; else pick_project "$1" || return 1; target=$proj; fi
}

# ── reading projects (msbuild evaluation, nothing gets built) ────────
# dotnet's output is localized (German with a German locale), so anything
# we parse runs with DOTNET_CLI_UI_LANGUAGE=en.
evaluate() {
  local out
  out=$(DOTNET_CLI_UI_LANGUAGE=en dotnet msbuild "$@" 2>/dev/null) || {
    fail "Couldn't read $1:"; printf '%s\n' "$out" >&2; return 1
  }
  printf '%s\n' "$out"
}

package_refs() {   # "Id Version" for each direct package reference
  evaluate "$1" -getItem:PackageReference |
    jq -r '.Items.PackageReference[] | select(.IsImplicitlyDefined != "true") | "\(.Identity) \(.Version // "")"'
}

project_refs() {   # referenced projects, as paths relative to this folder
  evaluate "$1" -getItem:ProjectReference |
    jq -r --arg here "$PWD/" '.Items.ProjectReference[].FullPath | ltrimstr($here)'
}

target_framework() {   # e.g. net8.0 (the first one if the project multi-targets)
  evaluate "$1" -getProperty:TargetFramework -getProperty:TargetFrameworks |
    jq -r '.Properties | if .TargetFramework != "" then .TargetFramework else (.TargetFrameworks | split(";")[0]) end'
}

sln_projects() {   # projects in a solution (the lines after the dashed header line)
  DOTNET_CLI_UI_LANGUAGE=en dotnet sln "$1" list | sed '1,/^--*$/d'
}

# templates <project|item>: "shortname  Template Name  [languages]" lines.
# `dotnet new list` only prints a table; the dashed line under its header
# tells us where each column starts and how wide it is.
templates() {
  DOTNET_CLI_UI_LANGUAGE=en dotnet new list --type "$1" | awk '
    function trim(s) { gsub(/^ +| +$/, "", s); return s }
    /^-+( +-+)+ *$/ {
      n = 0; rest = $0; off = 0
      while (match(rest, /-+/)) {
        n++; start[n] = off + RSTART; width[n] = RLENGTH
        off += RSTART + RLENGTH - 1; rest = substr(rest, RSTART + RLENGTH)
      }
      table = 1; next
    }
    table && NF {
      short = trim(substr($0, start[2], width[2])); sub(/,.*/, "", short)   # "webapp,razor" -> "webapp"
      name = trim(substr($0, start[1], width[1])); lang = trim(substr($0, start[3], width[3]))
      printf "%-22s %s%s\n", short, name, (lang == "" ? "" : "  " lang)
    }'
}

# ── actions ───────────────────────────────────────────────────────────
# run_new <args…>: dotnet new, offering --force if it refuses to overwrite files (exit code 73)
run_new() {
  local status=0
  run dotnet new "$@" || status=$?
  if (( status == 73 )) && ask confirm --default=false "Overwrite the existing files?"; then
    status=0
    run dotnet new "$@" --force || status=$?
  fi
  return "$status"
}

new_project() {
  title "New project"
  local list tpl name dir
  local -a extra=()
  list=$(templates project) || return 0
  ask filter --header "Template" --placeholder "e.g. console, classlib, webapi, xunit" <<<"$list" || return 0
  [[ -n $answer ]] || return 0
  tpl=${answer%% *}

  ask input --header "Project name" --placeholder "e.g. Shop or Shop.Data" || return 0
  name=$answer
  [[ -n $name ]] || return 0
  dir=$name
  if [[ -d src ]]; then dir=src/$name; fi
  ask input --header "Folder" --value "$dir" || return 0
  dir=${answer:-$dir}

  while true; do
    ask input --header "Extra options for $tpl (optional, ? lists them)" \
      --placeholder "e.g. --use-program-main" || return 0
    if [[ $answer != "?" ]]; then break; fi
    DOTNET_CLI_UI_LANGUAGE=en dotnet new "$tpl" --help | sed -n '/^Template options:/,$p' || true
  done
  read -r -a extra <<<"$answer"

  run_new "$tpl" -n "$name" -o "$dir" "${extra[@]}" || return 0
  if pick_solution && ask confirm "Add $dir to $sln?"; then
    run dotnet sln "$sln" add "$dir" || true
  fi
}

new_solution() {
  title "New solution"
  local name ext=sln list
  local -a fmt=() picked=()
  ask input --header "Solution name" --value "${PWD##*/}" || return 0
  name=${answer:-${PWD##*/}}
  if (( sdk_major >= 10 )); then   # --format exists since .NET 10, which defaults to .slnx
    ask choose --header "Format" \
      ".slnx (new XML format, default since .NET 10)" \
      ".sln (classic format, for older tools)" || return 0
    if [[ $answer == .slnx* ]]; then ext=slnx; fi
    fmt=(--format "$ext")
  fi
  run_new sln -n "$name" "${fmt[@]}" || return 0
  sln=$name.$ext

  list=$(projects)
  [[ -n $list ]] || return 0
  ask choose --no-limit --selected='*' --header "Add these projects to $sln? (space toggles)" <<<"$list" || return 0
  [[ -n $answer ]] || return 0
  mapfile -t picked <<<"$answer"
  run dotnet sln "$sln" add "${picked[@]}" || true
}

new_item() {
  title "New file from template"
  local list tpl
  local -a args=()
  list=$(templates item) || return 0
  ask filter --header "Template" --placeholder "e.g. gitignore, globaljson, editorconfig" <<<"$list" || return 0
  [[ -n $answer ]] || return 0
  tpl=${answer%% *}
  if [[ $answer == *"["* ]]; then   # code templates (they list a language) need a name
    ask input --header "Name" --placeholder "e.g. CustomersController" || return 0
    [[ -n $answer ]] || return 0
    args=(-n "$answer")
    ask input --header "Folder" --value "." || return 0
    if [[ -n $answer && $answer != "." ]]; then args+=(-o "$answer"); fi
  fi
  run_new "$tpl" "${args[@]}" || true
}

sln_add() {
  title "Add projects to solution"
  if ! pick_solution; then fail "No .sln/.slnx in this folder. Use 'New solution' first."; return 0; fi
  local inside missing
  local -a picked=()
  inside=$(sln_projects "$sln") || return 0
  missing=$(grep -vxF -f <(printf '%s\n' "$inside") <<<"$(projects)" || true)
  [[ -n $missing ]] || { note "Every project below here is already in $sln."; return 0; }
  ask filter --no-limit --header "Add which projects to $sln? (tab marks several)" <<<"$missing" || return 0
  [[ -n $answer ]] || return 0
  mapfile -t picked <<<"$answer"
  run dotnet sln "$sln" add "${picked[@]}" || true
}

sln_remove() {
  title "Remove projects from solution"
  if ! pick_solution; then fail "No .sln/.slnx in this folder."; return 0; fi
  local inside
  local -a picked=()
  inside=$(sln_projects "$sln") || return 0
  [[ -n $inside ]] || { note "$sln has no projects."; return 0; }
  ask filter --no-limit --header "Remove which projects from $sln? (tab marks several)" <<<"$inside" || return 0
  [[ -n $answer ]] || return 0
  mapfile -t picked <<<"$answer"
  run dotnet sln "$sln" remove "${picked[@]}" || true
}

# search_packages <term>: NuGet search, sets $pkg_list to "Id  latest  downloads" lines
search_packages() {
  local json problems
  json=$(gum spin --title "Searching NuGet for '$1'…" -- dotnet package search "$1" --take 30 --format json) || {
    printf '%s\n' "$json" >&2; fail "Search failed."; return 1
  }
  problems=$(jq -r '(.problems[]?, .searchResult[]?.problems[]?) | if type == "object" then (.text // tostring) else tostring end' <<<"$json")
  if [[ -n $problems ]]; then fail "$problems"; fi
  # Local feeds list a package once per version, so keep the highest version per id.
  pkg_list=$(jq -r '
    def vkey: split("-")[0] | split(".") | map(tonumber? // 0);
    def pad($n): tostring | . + (" " * ($n - length));
    def human: if . == null then ""
      elif . >= 1e9 then "\((. / 1e8 | floor) / 10)B"
      elif . >= 1e6 then "\((. / 1e5 | floor) / 10)M"
      elif . >= 1e3 then "\(. / 1e3 | floor)K"
      else tostring end;
    [.searchResult[].packages[]?]
    | reduce .[] as $p ({order: [], best: {}};
        if .best[$p.id] == null then .order += [$p.id] | .best[$p.id] = $p
        elif ($p.latestVersion | vkey) > (.best[$p.id].latestVersion | vkey) then .best[$p.id] = $p
        else . end)
    | .best[.order[]]
    | "\(.id | pad(50)) \(.latestVersion | pad(14)) \(.totalDownloads | human)"' <<<"$json")
  if [[ -z $pkg_list ]]; then fail "Nothing found for '$1'."; return 1; fi
}

# pick_version <project> <package>: choose a version, sets $version ("" = let dotnet decide).
# EF Core and ASP.NET Core versions follow .NET (EF Core 10 needs net10.0), so for
# those we put the newest version matching the project's target framework first.
pick_version() {
  local json versions latest v tag tfm="" suggested="" header="Version of $2" list=""
  local -a order=()
  version=""
  json=$(gum spin --title "Fetching versions of $2…" -- dotnet package search "$2" --exact-match --format json) || return 0
  versions=$(jq -r '[.searchResult[].packages[]?.version] | unique
    | sort_by(split(".") | map(tonumber? // 0)) | reverse | .[]' <<<"$json")
  [[ -n $versions ]] || return 0
  latest=${versions%%$'\n'*}
  if [[ $2 =~ EntityFrameworkCore|^Microsoft\.AspNetCore\. ]]; then
    tfm=$(target_framework "$1") || tfm=""
    if [[ $tfm =~ ^net([0-9]+)\. ]]; then
      suggested=$(grep -m1 "^${BASH_REMATCH[1]}\." <<<"$versions" || true)
      header+=" ($1 targets $tfm)"
    fi
  fi
  if [[ -n $suggested ]]; then order+=("$suggested"); fi
  while IFS= read -r v; do
    if [[ $v != "$suggested" ]]; then order+=("$v"); fi
  done <<<"$versions"
  for v in "${order[@]}"; do
    tag=""
    if [[ $v == "$latest" ]]; then tag+="  ← latest"; fi
    if [[ -n $suggested && $v == "$suggested" ]]; then tag+="  ← matches $tfm"; fi
    list+="$v$tag"$'\n'
  done
  ask filter --header "$header" --placeholder "type to filter" <<<"${list%$'\n'}" || return 1
  [[ -n $answer ]] || return 1
  version=${answer%% *}
}

add_package() {
  title "Add package (NuGet)"
  pick_project "Add a package to which project?" || return 0
  local p=$proj id added
  local -a ver=()
  while true; do
    ask input --header "Search NuGet" \
      --placeholder "e.g. EntityFrameworkCore.Sqlite, CommunityToolkit.Mvvm, Serilog" || return 0
    [[ -n $answer ]] || return 0
    search_packages "$answer" || continue
    ask filter --header "Pick a package for $p" --placeholder "type to filter" <<<"$pkg_list" || continue
    [[ -n $answer ]] || continue
    id=${answer%% *}

    added=false
    while pick_version "$p" "$id"; do
      ver=()
      if [[ -n $version ]]; then ver=(--version "$version"); fi
      if run dotnet add "$p" package "$id" "${ver[@]}"; then added=true; break; fi
      ask confirm "Pick a different version?" || break
    done
    $added || continue
    ask confirm --default=false "Add another package to $p?" || return 0
  done
}

remove_package() {
  title "Remove package"
  pick_project "Remove a package from which project?" || return 0
  local p=$proj refs line
  local -a picked=()
  refs=$(package_refs "$p") || return 0
  [[ -n $refs ]] || { note "$p has no package references."; return 0; }
  ask filter --no-limit --header "Remove which packages from $p? (tab marks several)" <<<"$refs" || return 0
  [[ -n $answer ]] || return 0
  mapfile -t picked <<<"$answer"
  for line in "${picked[@]}"; do run dotnet remove "$p" package "${line%% *}" || true; done
}

update_packages() {
  title "Update packages"
  pick_target "Check which project?" || return 0
  local json path id from to label
  local -a mode=() picked=()
  local -A updates=()
  ask choose --header "Which updates?" \
    "Safe: newest version within the same major version" \
    "Latest: newest version, even a new major (may break or need a newer .NET)" || return 0
  if [[ $answer == Safe* ]]; then mode=(--highest-minor); fi

  json=$(gum spin --title "Checking for updates…" -- \
    dotnet list "$target" package --outdated "${mode[@]}" --format json) || {
    printf '%s\n' "$json" >&2; fail "Couldn't check for updates."; return 0
  }
  while IFS=$'\t' read -r path id from to; do
    updates["$id  $from → $to  ($path)"]="$path"$'\t'"$id"$'\t'"$to"
  done < <(jq -r --arg here "$PWD/" '.projects[] | (.path | ltrimstr($here)) as $path
    | .frameworks[]?.topLevelPackages[]? | [$path, .id, .resolvedVersion, .latestVersion] | @tsv' <<<"$json")
  (( ${#updates[@]} > 0 )) || { note "Everything is up to date."; return 0; }

  ask choose --no-limit --selected='*' --header "Update which? (space toggles)" \
    < <(printf '%s\n' "${!updates[@]}" | sort) || return 0
  [[ -n $answer ]] || return 0
  mapfile -t picked <<<"$answer"
  for label in "${picked[@]}"; do
    IFS=$'\t' read -r path id to <<<"${updates[$label]}"
    run dotnet add "$path" package "$id" --version "$to" || true
  done
}

add_reference() {
  title "Add project reference"
  pick_project "Which project gets the reference?" || return 0
  local p=$proj have candidates
  local -a picked=()
  have=$(project_refs "$p") || return 0
  # every other project that isn't referenced yet
  candidates=$(grep -vxF -f <(printf '%s\n' "$p" "$have") <<<"$(projects)" || true)
  [[ -n $candidates ]] || { note "No other projects to reference."; return 0; }
  ask filter --no-limit --header "$p should reference… (tab marks several)" <<<"$candidates" || return 0
  [[ -n $answer ]] || return 0
  mapfile -t picked <<<"$answer"
  run dotnet add "$p" reference "${picked[@]}" || true
}

remove_reference() {
  title "Remove project reference"
  pick_project "Remove a reference from which project?" || return 0
  local p=$proj refs
  local -a picked=()
  refs=$(project_refs "$p") || return 0
  [[ -n $refs ]] || { note "$p has no project references."; return 0; }
  ask filter --no-limit --header "Remove which references from $p? (tab marks several)" <<<"$refs" || return 0
  [[ -n $answer ]] || return 0
  mapfile -t picked <<<"$answer"
  run dotnet remove "$p" reference "${picked[@]}" || true
}

run_app() {
  title "Run"
  pick_runnable "Run which project?" || return 0
  run dotnet run --project "$proj" || true
}

watch_app() {
  title "Watch (hot reload)"
  pick_runnable "Watch which project?" || return 0
  run dotnet watch --project "$proj" || true
}

# whole_target <verb>: dotnet build/test/clean/restore/format on the solution (or a project)
whole_target() {
  title "${1^}"
  pick_target "${1^} which project?" || return 0
  run dotnet "$1" "$target" || true
}

overview() {
  title "Overview"
  printed=true
  local p json
  local -a all=()
  mapfile -t all < <(projects)
  (( ${#all[@]} > 0 )) || { note "No projects below here."; return 0; }
  for p in "${all[@]}"; do
    json=$(evaluate "$p" -getProperty:TargetFramework -getProperty:TargetFrameworks -getProperty:OutputType \
      -getItem:PackageReference -getItem:ProjectReference) || continue
    jq -r --arg p "$p" --arg here "$PWD/" '
      (.Properties | "\($p)  (\(if .TargetFramework != "" then .TargetFramework else .TargetFrameworks end), \(.OutputType))"),
      (.Items.ProjectReference[]? | "  → \(.FullPath | ltrimstr($here))"),
      (.Items.PackageReference[]? | select(.IsImplicitlyDefined != "true") | "  • \(.Identity) \(.Version // "")")' <<<"$json"
  done
}

# ── EF Core ───────────────────────────────────────────────────────────
ensure_ef() {
  if $ef_ready || dotnet ef --version >/dev/null 2>&1; then ef_ready=true; return 0; fi
  fail "dotnet ef isn't available."
  note "With Nix: keep pkgs.dotnet-ef in dn's runtimeInputs (see dn.nix)."
  ask confirm "Install it as a local tool for this repo instead?" || return 1
  if [[ ! -f .config/dotnet-tools.json ]]; then run dotnet new tool-manifest || return 1; fi
  run dotnet tool install dotnet-ef || return 1
  ef_ready=true
}

# ef_setup [again]: pick (once per session) the project with the DbContext and the startup project
ef_setup() {
  ensure_ef || return 1
  if [[ -n $ef_project && ${1:-} != again ]]; then
    note "Using DbContext project $ef_project and startup project $ef_startup (change: 'EF Core: choose projects')."
  else
    pick_project "Which project has your DbContext? (migrations go there)" || return 1
    ef_project=$proj
    pick_runnable "Which project starts your app? (the startup project)" || return 1
    ef_startup=$proj
  fi
  ef_args=(--project "$(dirname "$ef_project")" --startup-project "$(dirname "$ef_startup")")
}

# dotnet ef needs Microsoft.EntityFrameworkCore.Design in the startup project.
# If it's missing, offer it in the same version as the EF Core packages already used.
ensure_design() {
  local refs ef_version
  local -a ver=()
  refs=$(package_refs "$ef_startup") || return 0
  if grep -q '^Microsoft\.EntityFrameworkCore\.Design ' <<<"$refs"; then return 0; fi
  ef_version=$({ package_refs "$ef_project" || true; printf '%s\n' "$refs"; } |
    awk '$1 ~ /^Microsoft\.EntityFrameworkCore/ && $2 != "" && !found { print $2; found = 1 }')
  if [[ -n $ef_version ]]; then ver=(--version "$ef_version"); fi
  ask confirm "$ef_startup doesn't reference Microsoft.EntityFrameworkCore.Design, which dotnet ef needs. Add it${ef_version:+ ($ef_version)}?" || return 0
  run dotnet add "$ef_startup" package Microsoft.EntityFrameworkCore.Design "${ver[@]}" || true
}

ef_migration_add() {
  title "EF Core: add migration"
  ef_setup || return 0
  ensure_design
  ask input --header "Migration name" --placeholder "e.g. InitialCreate, AddCustomerEmail" || return 0
  [[ -n $answer ]] || return 0
  run dotnet ef migrations add "$answer" "${ef_args[@]}" || true
}

ef_update() {
  title "EF Core: update database"
  ef_setup || return 0
  ensure_design
  run dotnet ef database update "${ef_args[@]}" || true
}

ef_remove() {
  title "EF Core: remove last migration"
  ef_setup || return 0
  ask confirm --default=false "Remove the last migration? (if it's already applied, EF tells you to revert it first)" || return 0
  run dotnet ef migrations remove "${ef_args[@]}" || true
}

ef_list() {
  title "EF Core: list migrations"
  ef_setup || return 0
  run dotnet ef migrations list "${ef_args[@]}" || true
}

ef_scaffold() {
  title "EF Core: scaffold from existing database"
  ef_setup || return 0
  ensure_design
  local conn provider out refs k list=""
  local -a force=()
  local -a known=(Microsoft.EntityFrameworkCore.Sqlite Microsoft.EntityFrameworkCore.SqlServer
    Npgsql.EntityFrameworkCore.PostgreSQL Pomelo.EntityFrameworkCore.MySql Oracle.EntityFrameworkCore)
  ask input --header "Connection string" \
    --placeholder "e.g. Data Source=app.db  or  User Id=…;Password=…;Data Source=localhost:1521/FREEPDB1" || return 0
  conn=$answer
  [[ -n $conn ]] || return 0
  refs=$(package_refs "$ef_project") || refs=""
  for k in "${known[@]}"; do   # providers the project already references come first
    if grep -q "^$k " <<<"$refs"; then list+="$k  (referenced)"$'\n'; fi
  done
  for k in "${known[@]}"; do
    if ! grep -q "^$k " <<<"$refs"; then list+="$k"$'\n'; fi
  done
  ask filter --header "Database provider (its package must be referenced by $ef_project)" <<<"${list%$'\n'}" || return 0
  [[ -n $answer ]] || return 0
  provider=${answer%% *}
  ask input --header "Folder for the generated classes" --value "Models" || return 0
  out=${answer:-Models}
  if ask confirm --default=false "Overwrite existing files (--force)?"; then force=(--force); fi
  run dotnet ef dbcontext scaffold "$conn" "$provider" --output-dir "$out" "${force[@]}" "${ef_args[@]}" || true
}

# ── main ──────────────────────────────────────────────────────────────
do_action() {
  case $1 in
    "New project")                    new_project ;;
    "New solution")                   new_solution ;;
    "New file from template"*)        new_item ;;
    "Add package"*)                   add_package ;;
    "Remove package")                 remove_package ;;
    "Update packages")                update_packages ;;
    "Add project reference")          add_reference ;;
    "Remove project reference")       remove_reference ;;
    "Add projects to solution")       sln_add ;;
    "Remove projects from solution")  sln_remove ;;
    "Run")                            run_app ;;
    "Watch"*)                         watch_app ;;
    "Build")                          whole_target build ;;
    "Test")                           whole_target test ;;
    "Clean")                          whole_target clean ;;
    "Restore")                        whole_target restore ;;
    "Format code")                    whole_target format ;;
    "EF Core: add migration")         ef_migration_add ;;
    "EF Core: update database")       ef_update ;;
    "EF Core: remove last migration") ef_remove ;;
    "EF Core: list migrations")       ef_list ;;
    "EF Core: scaffold"*)             ef_scaffold ;;
    "EF Core: choose projects")       title "EF Core: choose projects"; ef_setup again || true ;;
    "Overview")                       overview ;;
    "Quit")                           exit 0 ;;
  esac
}

# find_action <words>: print the menu entry the words point to, if exactly one does.
# Tries "starts with" first (dn update), then "every word starts a word of the
# entry" (dn ef scaffold, dn remove ref).
find_action() {
  local q=${1,,} label l w x found
  local -a hits=() words=() label_words=()
  for label in "${menu[@]}"; do
    if [[ ${label,,} == "$q"* ]]; then hits+=("$label"); fi
  done
  if (( ${#hits[@]} != 1 )); then
    hits=()
    read -r -a words <<<"$q"
    for label in "${menu[@]}"; do
      l=${label,,}
      read -r -a label_words <<<"${l//[^a-z0-9]/ }"
      found=0
      for w in "${words[@]}"; do
        for x in "${label_words[@]}"; do
          if [[ $x == "$w"* ]]; then found=$((found + 1)); break; fi
        done
      done
      if (( found == ${#words[@]} )); then hits+=("$label"); fi
    done
  fi
  if (( ${#hits[@]} == 1 )); then printf '%s\n' "${hits[0]}"; fi
}

context() {
  local sols=(*.sln *.slnx) count
  count=$(projects | grep -c . || true)
  note "${PWD/#"$HOME"/\~}  ·  ${sols[*]:-no solution}  ·  $count project(s)  ·  .NET SDK $sdk_version"
}

usage() {
  cat <<'EOF'
dn: friendly menus for the dotnet CLI

  dn               open the menu (run it in your solution or project folder)
  dn <words>       jump straight to the action those words point to,
                   e.g. dn run · dn build · dn add package · dn ef scaffold
                   (several matches open the menu, already filtered)

Every action prints the real dotnet command before running it.
Keys: type to filter · ↑↓ + enter to pick · tab/space to mark several
      esc to go back · ctrl+c to quit
EOF
}

main() {
  case ${1:-} in -h|--help) usage; return 0 ;; esac
  local tool
  for tool in dotnet gum jq; do
    if ! command -v "$tool" >/dev/null; then echo "dn: '$tool' isn't on your PATH." >&2; return 1; fi
  done
  if [[ $(gum --version 2>/dev/null || true) =~ version\ v?([0-9]+)\. ]] && (( BASH_REMATCH[1] < 2 )); then
    note "dn was written for gum v2, with your older gum some prompts may not work."
  fi
  sdk_version=$(dotnet --version 2>/dev/null) || sdk_version="?"
  sdk_major=${sdk_version%%.*}
  if [[ ! $sdk_major =~ ^[0-9]+$ ]]; then sdk_major=0; fi

  local query="$*" match
  if [[ -n $query ]]; then
    match=$(find_action "$query")
    if [[ -n $match ]]; then do_action "$match"; return 0; fi
  fi

  while true; do
    echo
    context
    ask filter --header "What do you want to do?" --placeholder "type to search" --value "$query" \
      < <(printf '%s\n' "${menu[@]}") || break
    query=""
    [[ -n $answer ]] || continue
    printed=false
    do_action "$answer"
    if $printed; then pause; fi
  done
}

main "$@"

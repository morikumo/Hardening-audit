#!/usr/bin/env bash
# ============================================================
#  hardening-audit.sh — Audit CIS Benchmark Ubuntu/Debian
#  Usage : ./hardening-audit.sh [--format json] [--output <fichier>]
#  Exemple : ./hardening-audit.sh --format json --output rapport.json
# ============================================================

set -uo pipefail

# ── Couleurs terminal ──────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Valeurs par défaut ─────────────────────────────────────
#FORMAT="html"
FORMAT="json"
OUTPUT=""
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "Unknown")

# ── Parsing des arguments ──────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--format json] [--output <fichier>]"
      echo "  --format  Format de sortie : json (défaut: html)"
      echo "  --output  Fichier de sortie (défaut: audit-report.<format>)"
      exit 0 ;;
    *) echo "Option inconnue: $1"; exit 1 ;;
  esac
done

# Nom de fichier par défaut
[[ -z "$OUTPUT" ]] && OUTPUT="audit-report.${FORMAT}"

# Validation du format
if [[ "$FORMAT" != "json" ]]; then
  echo -e "${RED}Format invalide : '$FORMAT'. Utiliser 'json'.${NC}"
  exit 1
fi

# ── Stockage des résultats ─────────────────────────────────
declare -a RESULTS=()
PASS=0; FAIL=0; WARN=0

# ── Fonction d'évaluation d'un contrôle ───────────────────
# check <id> <description> <catégorie> <commande_test> <recommandation>
check() {
  local id="$1" desc="$2" category="$3" cmd="$4" reco="$5"
  local status details

  if eval "$cmd" &>/dev/null; then
    status="PASS"; ((PASS++))
    details="Contrôle validé"
    echo -e "  ${GREEN}✔ PASS${NC} [$id] $desc"
  else
    status="FAIL"; ((FAIL++))
    details="$reco"
    echo -e "  ${RED}✘ FAIL${NC} [$id] $desc"
  fi

  RESULTS+=("$(printf '%s|%s|%s|%s|%s' "$id" "$category" "$desc" "$status" "$details")")
}

# Variante warn : échouer sans bloquer le score critique
check_warn() {
  local id="$1" desc="$2" category="$3" cmd="$4" reco="$5"
  local status details

  if eval "$cmd" &>/dev/null; then
    status="PASS"; ((PASS++))
    details="Contrôle validé"
    echo -e "  ${GREEN}✔ PASS${NC} [$id] $desc"
  else
    status="WARN"; ((WARN++))
    details="$reco"
    echo -e "  ${YELLOW}⚠ WARN${NC} [$id] $desc"
  fi

  RESULTS+=("$(printf '%s|%s|%s|%s|%s' "$id" "$category" "$desc" "$status" "$details")")
}

# ══════════════════════════════════════════════════════════
#  CONTRÔLES CIS BENCHMARK 
# ══════════════════════════════════════════════════════════

echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║             hardening-audit                  ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo -e "  Hôte    : ${BOLD}$HOSTNAME${NC}"
echo -e "  Système : ${BOLD}$OS${NC}"
echo -e "  Date    : ${BOLD}$TIMESTAMP${NC}\n"

# ── 1. Mises à jour système ────────────────────────────────
echo -e "${BOLD}[1] Mises à jour système${NC}"

check "1.1" "apt est disponible" "Updates" \
  "command -v apt-get" \
  "Installer apt-get sur le système"

check_warn "1.2" "Pas de paquets en attente de mise à jour" "Updates" \
  "[ \$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst') -eq 0 ]" \
  "Lancer : apt-get upgrade -y"

check "1.3" "unattended-upgrades est installé" "Updates" \
  "dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'" \
  "Installer : apt-get install unattended-upgrades"

check "1.4" "dpkg est fonctionnel" "Updates" \
  "dpkg --audit 2>/dev/null | wc -l | grep -q '^0$'" \
  "Réparer : dpkg --configure -a"

check_warn "1.5" "apt-transport-https est installé" "Updates" \
  "dpkg -l apt-transport-https 2>/dev/null | grep -q '^ii'" \
  "Installer : apt-get install apt-transport-https"

check_warn "1.6" "ca-certificates est installé" "Updates" \
  "dpkg -l ca-certificates 2>/dev/null | grep -q '^ii'" \
  "Installer : apt-get install ca-certificates"

check "1.7" "Les sources apt utilisent HTTPS" "Updates" \
  "grep -rE '^deb https://' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -q ." \
  "Remplacer les sources http:// par https:// dans /etc/apt/sources.list"

check_warn "1.8" "Pas de paquets en état 'rc' (résidus)" "Updates" \
  "[ \$(dpkg -l 2>/dev/null | grep '^rc' | wc -l) -eq 0 ]" \
  "Purger les résidus : dpkg --purge \$(dpkg -l | grep '^rc' | awk '{print \$2}')"

check "1.9" "La date de dernière mise à jour est récente (< 7 jours)" "Updates" \
  "find /var/cache/apt/pkgcache.bin -mtime -7 2>/dev/null | grep -q ." \
  "Mettre à jour : apt-get update"

check_warn "1.10" "needrestart est installé (détecte services à redémarrer)" "Updates" \
  "command -v needrestart" \
  "Installer : apt-get install needrestart"

# ── 2. Système de fichiers ─────────────────────────────────
echo -e "\n${BOLD}[2] Système de fichiers${NC}"

check "2.1" "nodev sur /tmp" "Filesystem" \
  "mount | grep ' /tmp ' | grep -q nodev" \
  "Ajouter l'option nodev à /tmp dans /etc/fstab"

check "2.2" "nosuid sur /tmp" "Filesystem" \
  "mount | grep ' /tmp ' | grep -q nosuid" \
  "Ajouter l'option nosuid à /tmp dans /etc/fstab"

check "2.3" "noexec sur /tmp" "Filesystem" \
  "mount | grep ' /tmp ' | grep -q noexec" \
  "Ajouter l'option noexec à /tmp dans /etc/fstab"

check_warn "2.4" "/var est une partition séparée" "Filesystem" \
  "mount | grep -q ' /var '" \
  "Monter /var sur une partition dédiée"

check_warn "2.5" "/home est une partition séparée" "Filesystem" \
  "mount | grep -q ' /home '" \
  "Monter /home sur une partition dédiée"


# ══════════════════════════════════════════════════════════
#  CALCUL DU SCORE
# ══════════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL + WARN))
SCORE=$(( (PASS * 100) / TOTAL ))

echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════════${NC}"
echo -e "${BOLD}  RÉSULTATS${NC}"
echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}✔ PASS : $PASS${NC}"
echo -e "  ${RED}✘ FAIL : $FAIL${NC}"
echo -e "  ${YELLOW}⚠ WARN : $WARN${NC}"
echo -e "  Total  : $TOTAL contrôles"
echo -e "  ${BOLD}Score  : $SCORE / 100${NC}"

if   [ "$SCORE" -ge 80 ]; then echo -e "  ${GREEN}${BOLD}Niveau : BON ✔${NC}"
elif [ "$SCORE" -ge 60 ]; then echo -e "  ${YELLOW}${BOLD}Niveau : MOYEN ⚠${NC}"
else                           echo -e "  ${RED}${BOLD}Niveau : CRITIQUE ✘${NC}"
fi

# ══════════════════════════════════════════════════════════
#  GÉNÉRATION DU RAPPORT
# ══════════════════════════════════════════════════════════

generate_json() {
  echo "{"
  echo "  \"meta\": {"
  echo "    \"hostname\": \"$HOSTNAME\","
  echo "    \"os\": \"$OS\","
  echo "    \"timestamp\": \"$TIMESTAMP\","
  echo "    \"score\": $SCORE,"
  echo "    \"pass\": $PASS,"
  echo "    \"fail\": $FAIL,"
  echo "    \"warn\": $WARN,"
  echo "    \"total\": $TOTAL"
  echo "  },"
  echo "  \"controls\": ["
  local first=true
  for entry in "${RESULTS[@]}"; do
    IFS='|' read -r id category desc status details <<< "$entry"
    [[ "$first" == true ]] && first=false || echo "    ,"
    echo "    {"
    echo "      \"id\": \"$id\","
    echo "      \"category\": \"$category\","
    echo "      \"description\": \"$desc\","
    echo "      \"status\": \"$status\","
    echo "      \"details\": \"$details\""
    echo -n "    }"
  done
  echo ""
  echo "  ]"
  echo "}"
}


# ── Écriture du rapport ────────────────────────────────────
echo -e "\n${BOLD}Génération du rapport ${FORMAT^^}...${NC}"

if [ "$FORMAT" = "json" ]; then
  generate_json > "$OUTPUT"
fi

echo -e "${GREEN}${BOLD}✔ Rapport généré : $OUTPUT${NC}\n"

#!/usr/bin/env bash
# ============================================================
#  hardening-audit.sh — Audit CIS Benchmark Ubuntu/Debian
#  Usage : ./hardening-audit.sh [--format json|html] [--output <fichier>]
#  Exemple : ./hardening-audit.sh --format json --output rapport.json
#            ./hardening-audit.sh --format html --output rapport.html
# ============================================================

set -uo pipefail

# ── Couleurs terminal ──────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Valeurs par défaut ─────────────────────────────────────
FORMAT="html"
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
if [[ "$FORMAT" != "html" && "$FORMAT" != "json" ]]; then
  echo -e "${RED}Format invalide : '$FORMAT'. Utiliser 'json' ou 'html'.${NC}"
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

check_warn "2.6" "/var/log est une partition séparée" "Filesystem" \
  "mount | grep -q ' /var/log '" \
  "Monter /var/log sur une partition dédiée"

check_warn "2.7" "/var/log/audit est une partition séparée" "Filesystem" \
  "mount | grep -q ' /var/log/audit '" \
  "Monter /var/log/audit sur une partition dédiée"

check "2.8" "nodev sur /home" "Filesystem" \
  "mount | grep ' /home ' | grep -q nodev" \
  "Ajouter l'option nodev à /home dans /etc/fstab"

check "2.9" "nodev sur /dev/shm" "Filesystem" \
  "mount | grep ' /dev/shm ' | grep -q nodev" \
  "Ajouter l'option nodev à /dev/shm dans /etc/fstab"

check "2.10" "nosuid sur /dev/shm" "Filesystem" \
  "mount | grep ' /dev/shm ' | grep -q nosuid" \
  "Ajouter l'option nosuid à /dev/shm dans /etc/fstab"

check "2.11" "noexec sur /dev/shm" "Filesystem" \
  "mount | grep ' /dev/shm ' | grep -q noexec" \
  "Ajouter l'option noexec à /dev/shm dans /etc/fstab"

check_warn "2.12" "Le module cramfs est désactivé" "Filesystem" \
  "! lsmod 2>/dev/null | grep -q cramfs && grep -rq 'install cramfs /bin/false' /etc/modprobe.d/ 2>/dev/null" \
  "Ajouter dans /etc/modprobe.d/blacklist.conf : install cramfs /bin/false"

check_warn "2.13" "Le module freevxfs est désactivé" "Filesystem" \
  "! lsmod 2>/dev/null | grep -q freevxfs && grep -rq 'install freevxfs /bin/false' /etc/modprobe.d/ 2>/dev/null" \
  "Ajouter dans /etc/modprobe.d/blacklist.conf : install freevxfs /bin/false"

check_warn "2.14" "Le module jffs2 est désactivé" "Filesystem" \
  "! lsmod 2>/dev/null | grep -q jffs2 && grep -rq 'install jffs2 /bin/false' /etc/modprobe.d/ 2>/dev/null" \
  "Ajouter dans /etc/modprobe.d/blacklist.conf : install jffs2 /bin/false"

check_warn "2.15" "Le module hfs est désactivé" "Filesystem" \
  "! lsmod 2>/dev/null | grep -q '^hfs ' && grep -rq 'install hfs /bin/false' /etc/modprobe.d/ 2>/dev/null" \
  "Ajouter dans /etc/modprobe.d/blacklist.conf : install hfs /bin/false"

check_warn "2.16" "Le module hfsplus est désactivé" "Filesystem" \
  "! lsmod 2>/dev/null | grep -q hfsplus && grep -rq 'install hfsplus /bin/false' /etc/modprobe.d/ 2>/dev/null" \
  "Ajouter dans /etc/modprobe.d/blacklist.conf : install hfsplus /bin/false"

check_warn "2.17" "Le module udf est désactivé" "Filesystem" \
  "! lsmod 2>/dev/null | grep -q '^udf ' && grep -rq 'install udf /bin/false' /etc/modprobe.d/ 2>/dev/null" \
  "Ajouter dans /etc/modprobe.d/blacklist.conf : install udf /bin/false"

check "2.18" "Sticky bit activé sur les répertoires world-writable" "Filesystem" \
  "[ \$(find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | wc -l) -eq 0 ]" \
  "Corriger : find / -xdev -type d -perm -0002 ! -perm -1000 -exec chmod +t {} +"

check_warn "2.19" "Pas de fichiers sans propriétaire" "Filesystem" \
  "[ \$(find / -xdev -nouser 2>/dev/null | wc -l) -eq 0 ]" \
  "Identifier : find / -xdev -nouser et assigner un propriétaire"

check_warn "2.20" "Pas de fichiers sans groupe" "Filesystem" \
  "[ \$(find / -xdev -nogroup 2>/dev/null | wc -l) -eq 0 ]" \
  "Identifier : find / -xdev -nogroup et assigner un groupe"

check "2.21" "Pas de fichiers SUID non autorisés" "Filesystem" \
  "[ \$(find / -xdev -type f -perm -4000 2>/dev/null | wc -l) -le 10 ]" \
  "Auditer : find / -xdev -type f -perm -4000 et retirer le bit SUID si inutile"

check "2.22" "Pas de fichiers SGID non autorisés" "Filesystem" \
  "[ \$(find / -xdev -type f -perm -2000 2>/dev/null | wc -l) -le 10 ]" \
  "Auditer : find / -xdev -type f -perm -2000 et retirer le bit SGID si inutile"

# ── 3. Permissions fichiers critiques ─────────────────────
echo -e "\n${BOLD}[3] Permissions fichiers critiques${NC}"

check "3.1" "Permissions /etc/passwd : 644" "Permissions" \
  "[ \$(stat -c %a /etc/passwd) = '644' ]" \
  "Corriger : chmod 644 /etc/passwd"

check "3.2" "Propriétaire /etc/passwd : root" "Permissions" \
  "[ \$(stat -c %U /etc/passwd) = 'root' ]" \
  "Corriger : chown root:root /etc/passwd"

check "3.3" "Permissions /etc/shadow : 640 ou 000" "Permissions" \
  "stat -c %a /etc/shadow | grep -qE '^(640|000|600)$'" \
  "Corriger : chmod 640 /etc/shadow"

check "3.4" "Propriétaire /etc/shadow : root" "Permissions" \
  "[ \$(stat -c %U /etc/shadow) = 'root' ]" \
  "Corriger : chown root:root /etc/shadow"

check "3.5" "Permissions /etc/sudoers : 440" "Permissions" \
  "[ \$(stat -c %a /etc/sudoers) = '440' ]" \
  "Corriger : chmod 440 /etc/sudoers"

check "3.6" "Permissions /etc/crontab : 600" "Permissions" \
  "[ \$(stat -c %a /etc/crontab) = '600' ]" \
  "Corriger : chmod 600 /etc/crontab"

check "3.7" "Permissions /etc/ssh/sshd_config : 600" "Permissions" \
  "[ \$(stat -c %a /etc/ssh/sshd_config 2>/dev/null) = '600' ]" \
  "Corriger : chmod 600 /etc/ssh/sshd_config"

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

generate_html() {
  # Couleur du score
  local color_score
  if   [ "$SCORE" -ge 80 ]; then color_score="#22c55e"
  elif [ "$SCORE" -ge 60 ]; then color_score="#f59e0b"
  else                           color_score="#ef4444"
  fi

  cat <<HTML
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Audit CIS — $HOSTNAME</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; }
    h1 { font-size: 1.8rem; color: #f8fafc; margin-bottom: 0.3rem; }
    .subtitle { color: #94a3b8; font-size: 0.95rem; margin-bottom: 2rem; }
    .meta { display: flex; gap: 2rem; flex-wrap: wrap; margin-bottom: 2rem; }
    .meta-item { background: #1e293b; border-radius: 8px; padding: 1rem 1.5rem; }
    .meta-item .label { font-size: 0.75rem; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; }
    .meta-item .value { font-size: 1.1rem; font-weight: 600; color: #f1f5f9; margin-top: 0.2rem; }
    .score-card { background: #1e293b; border-radius: 12px; padding: 2rem; margin-bottom: 2rem; display: flex; align-items: center; gap: 2rem; }
    .score-circle { width: 100px; height: 100px; border-radius: 50%; border: 6px solid ${color_score}; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
    .score-number { font-size: 2rem; font-weight: 700; color: ${color_score}; }
    .score-details { display: flex; gap: 1.5rem; flex-wrap: wrap; }
    .score-stat { text-align: center; }
    .score-stat .num { font-size: 1.5rem; font-weight: 700; }
    .score-stat .lbl { font-size: 0.8rem; color: #94a3b8; }
    .pass-num { color: #22c55e; } .fail-num { color: #ef4444; } .warn-num { color: #f59e0b; }
    table { width: 100%; border-collapse: collapse; background: #1e293b; border-radius: 12px; overflow: hidden; }
    th { background: #0f172a; padding: 0.9rem 1rem; text-align: left; font-size: 0.8rem; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; }
    td { padding: 0.85rem 1rem; border-top: 1px solid #0f172a; font-size: 0.9rem; vertical-align: top; }
    tr:hover td { background: #263347; }
    .badge { display: inline-block; padding: 0.2rem 0.7rem; border-radius: 999px; font-size: 0.75rem; font-weight: 700; }
    .badge-PASS { background: #14532d; color: #86efac; }
    .badge-FAIL { background: #450a0a; color: #fca5a5; }
    .badge-WARN { background: #451a03; color: #fcd34d; }
    .cat { background: #1e3a5f; color: #93c5fd; padding: 0.2rem 0.6rem; border-radius: 4px; font-size: 0.75rem; }
    .reco { color: #94a3b8; font-size: 0.82rem; margin-top: 0.3rem; font-style: italic; }
    .filter-bar { display: flex; gap: 0.5rem; margin-bottom: 1rem; flex-wrap: wrap; }
    .filter-btn { padding: 0.4rem 1rem; border-radius: 999px; border: none; cursor: pointer; font-size: 0.85rem; font-weight: 600; }
    .filter-btn.active, .filter-btn:hover { opacity: 1; }
    .filter-btn { opacity: 0.6; background: #1e293b; color: #e2e8f0; }
    .filter-btn.f-all.active  { background: #334155; color: #f1f5f9; opacity: 1; }
    .filter-btn.f-pass.active { background: #14532d; color: #86efac; opacity: 1; }
    .filter-btn.f-fail.active { background: #450a0a; color: #fca5a5; opacity: 1; }
    .filter-btn.f-warn.active { background: #451a03; color: #fcd34d; opacity: 1; }
    footer { margin-top: 2rem; text-align: center; color: #475569; font-size: 0.8rem; }
  </style>
</head>
<body>
  <h1>🔒 Rapport d'audit basé sur le CIS Benchmark et Open-Scap </h1>
  <p class="subtitle">Généré par hardening-audit.sh — Référence : CIS Ubuntu Linux Benchmark</p>

  <div class="meta">
    <div class="meta-item"><div class="label">Hôte</div><div class="value">$HOSTNAME</div></div>
    <div class="meta-item"><div class="label">Système</div><div class="value">$OS</div></div>
    <div class="meta-item"><div class="label">Date</div><div class="value">$TIMESTAMP</div></div>
    <div class="meta-item"><div class="label">Contrôles</div><div class="value">$TOTAL vérifiés</div></div>
  </div>

  <div class="score-card">
    <div class="score-circle"><span class="score-number">$SCORE</span></div>
    <div>
      <div style="font-size:1.2rem;font-weight:700;margin-bottom:1rem;">Score de conformité CIS</div>
      <div class="score-details">
        <div class="score-stat"><div class="num pass-num">$PASS</div><div class="lbl">PASS</div></div>
        <div class="score-stat"><div class="num fail-num">$FAIL</div><div class="lbl">FAIL</div></div>
        <div class="score-stat"><div class="num warn-num">$WARN</div><div class="lbl">WARN</div></div>
      </div>
    </div>
  </div>

  <div class="filter-bar">
    <button class="filter-btn f-all active"  onclick="filter('all')">Tous ($TOTAL)</button>
    <button class="filter-btn f-pass"         onclick="filter('PASS')">✔ PASS ($PASS)</button>
    <button class="filter-btn f-fail"         onclick="filter('FAIL')">✘ FAIL ($FAIL)</button>
    <button class="filter-btn f-warn"         onclick="filter('WARN')">⚠ WARN ($WARN)</button>
  </div>

  <table id="results-table">
    <thead>
      <tr><th>ID</th><th>Catégorie</th><th>Contrôle</th><th>Statut</th><th>Recommandation</th></tr>
    </thead>
    <tbody>
HTML

  for entry in "${RESULTS[@]}"; do
    IFS='|' read -r id category desc status details <<< "$entry"
    cat <<ROW
      <tr data-status="$status">
        <td><code>$id</code></td>
        <td><span class="cat">$category</span></td>
        <td>$desc</td>
        <td><span class="badge badge-$status">$status</span></td>
        <td><span class="reco">$details</span></td>
      </tr>
ROW
  done

  cat <<HTML
    </tbody>
  </table>

  <footer>
    hardening-audit.sh — Basé sur le <a href="https://www.cisecurity.org/benchmark/ubuntu_linux" style="color:#60a5fa">CIS Linux Benchmark</a> et <a href="https://static.open-scap.org/openscap-1.3/oscap_user_manual.html" style="color:#60a5fa">Open-Scap</a>
  </footer>

  <script>
    function filter(status) {
      document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      const map = { all: 'f-all', PASS: 'f-pass', FAIL: 'f-fail', WARN: 'f-warn' };
      document.querySelector('.' + map[status]).classList.add('active');
      document.querySelectorAll('#results-table tbody tr').forEach(row => {
        row.style.display = (status === 'all' || row.dataset.status === status) ? '' : 'none';
      });
    }
  </script>
</body>
</html>
HTML
}

# ── Écriture du rapport ────────────────────────────────────
echo -e "\n${BOLD}Génération du rapport ${FORMAT^^}...${NC}"

if [ "$FORMAT" = "json" ]; then
  generate_json > "$OUTPUT"
else
  generate_html > "$OUTPUT"
fi

echo -e "${GREEN}${BOLD}✔ Rapport généré : $OUTPUT${NC}\n"

# Hardening-audit

![CIS Benchmark](https://img.shields.io/badge/CIS-%20Benchmark-blue)
![Bash](https://img.shields.io/badge/Bash-Script-green)

Votre serveur est-il vraiment sécurisé ? Conforme aux bonnes pratiques ?

**hardening-audit** est un script Bash qui audite votre machine Ubuntu/Debian et vous donne une réponse claire : un score de conformité, la liste des points à corriger, et les commandes pour y remédier.

---

## 🚀 Utilisation

```bash
chmod +x hardening-audit.sh

# Rapport JSON
./hardening-audit.sh --format json --output rapport.json

# Rapport HTML
./hardening-audit.sh --format html --output rapport.html
```

> Vous pouvez maintenant choisir entre l'un ou l'autre

---

## 📊 Domaines audités

| # | Domaine | Contrôles |
|---|---|---|
| 1 | **Mises à jour système** | apt, unattended-upgrades, etc... |
| 2 | **Système de fichiers** | /tmp nodev/nosuid/noexec, partitions séparées, etc... |
| 3 | **Permissions fichiers** | /etc/passwd, /etc/shadow, /etc/sudoers, sshd_config |
| 4 | **Configuration SSH** | Root login, password auth, timeout, MaxAuthTries, X11 |
| 5 | **Firewall** | ufw installé et actif, iptables |
| 6 | **Services** | Telnet, FTP, RSH, NFS, Samba désactivés |
| 7 | **Mots de passe** | pwquality, longueur minimale, expiration, PASS_MIN_DAYS |
| 8 | **Logging & Audit** | rsyslog, auditd, auth.log |
| 9 | **Réseau** | IP forward, SYN cookies, ICMP redirects, source routing |
| 10 | **Comptes utilisateurs** | Comptes sans mdp, UID 0, permissions /root |

---

## 📈 Interprétation du score (pour le moment)

| Score | Niveau |
|---|---|
| 80 — 100 | ✅ Bon |
| 60 — 79 | ⚠️ Moyen |
| < 60 | ❌ Critique |

---

## Methode avec Ansible pour audit sur parc de machine

Control node
├── inventory.ini
├── audit.yml
└── hardening-audit.sh
        │
        │  SSH
        ▼
   ┌────────────┐     ┌────────────┐
   │ target-01  │     │ target-02  │
   │ 172.17.0.2 │     │ 172.17.0.3 │
   └─────┬──────┘     └─────┬──────┘
         │                  │
         └────────┬─────────┘
                  │  fetch
                  ▼
           rapports/
           ├── target-01_audit.json
           └── target-02_audit.json

## 📚 Référence

Basé sur le [CIS Ubuntu Linux Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux), la référence mondiale pour le durcissement des serveurs Linux.

Mais on va aussi ce concentrer sur la version open-source [Open-Scap](https://static.open-scap.org/openscap-1.3/oscap_user_manual.html)

Merci [Stephane Robert](https://blog.stephane-robert.info/docs/securiser/durcissement/cis-benchmarks/)

---

## 📄 Licence

MIT

# Hardening-audit

![CIS Benchmark](https://img.shields.io/badge/CIS-Ubuntu%20Benchmark-blue)
![Bash](https://img.shields.io/badge/Bash-Script-green)

Votre serveur est-il vraiment sécurisé ? Conforme aux bonnes pratiques ?

**hardening-audit** est un script Bash qui audite votre machine Ubuntu/Debian et vous donne une réponse claire : un score de conformité, la liste des points à corriger, et les commandes pour y remédier.

---

## 🚀 Utilisation

```bash
chmod +x hardening-audit.sh

# Rapport JSON
./hardening-audit.sh --format json --output rapport.json
```

> Le rapport HTML est en cours d'intégration et sera disponible prochainement.

---

## 📊 Domaines audités

| # | Domaine | Contrôles |
|---|---|---|
| 1 | **Mises à jour système** | apt, unattended-upgrades, etc... |
| 2 | **Système de fichiers** | /tmp nodev/nosuid/noexec, partitions séparées, etc... |

---

## 📈 Interprétation du score (pour le moment)

| Score | Niveau |
|---|---|
| 80 — 100 | ✅ Bon |
| 60 — 79 | ⚠️ Moyen |
| < 60 | ❌ Critique |

---

## 📚 Référence

Basé sur le [CIS Ubuntu Linux Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux), la référence mondiale pour le durcissement des serveurs Linux.

Mais on va aussi ce concentrer sur la version open-source [Open-Scap]()

Merci [Stephane Robert](https://blog.stephane-robert.info/docs/securiser/durcissement/cis-benchmarks/)

---

## 📄 Licence

MIT

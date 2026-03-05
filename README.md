# ECN Planning Manager 🩺📚

Une application Flutter moderne pour aider les étudiants en médecine français à planifier et gérer leurs révisions pour l'ECN (Examen Classant National).

## 🌟 Fonctionnalités

### 📅 Planning Intelligent
- Vue calendrier interactive pour visualiser toutes vos révisions
- Navigation facile entre les jours
- Visualisation des créneaux horaires avec codes couleur
- Marquage des révisions complétées

### 📖 Gestion des Items ECN
- Base de données de 367 items ECN
- Import automatique depuis CSV (https://univ-edt.fr/item.csv)
- Organisation par collèges (Santé pub, Psy, Med int, etc.)
- Suivi de progression pour chaque item × collège


### ⚙️ Configuration Personnalisable
- Horaires de travail configurables par jour de la semaine
- Par défaut : 7j/7 de 14h à 22h
- Adapté aux journées avec cours (le matin)
- Réservation automatique des 2 premières heures pour les nouveaux items (jours > 4h)

### 📊 Suivi des Révisions
- Liste des révisions non complétées
- Organisation par priorité : En retard / Aujourd'hui / À venir
- Compteurs et indicateurs visuels
- Possibilité de marquer les révisions comme complétées

## 🛠 Structure du Projet

```
lib/
├── main.dart                      # Point d'entrée de l'application
├── theme/
│   └── app_theme.dart            # Thème avec couleurs roses douces
├── models/
│   ├── college.dart              # Modèle Collège
│   ├── item.dart                 # Modèle Item ECN
│   ├── item_college.dart         # Relation Item × Collège
│   ├── revision_slot.dart        # Créneaux de révision
│   ├── work_schedule.dart        # Horaires de travail
│   └── difficulty.dart           # Enum difficulté
├── database/
│   └── database_helper.dart      # Gestion SQLite + import CSV
├── services/
│   └── revision_scheduler.dart   # Logique de planification automatique
└── screens/
    ├── home_screen.dart          # Navigation principale
    ├── calendar_screen.dart      # Vue calendrier
    ├── revisions_screen.dart     # Liste des révisions
    ├── items_screen.dart         # Gestion des items
    ├── settings_screen.dart      # Configuration horaires
    └── add_first_seen_screen.dart # Enregistrer un item vu
```

## 📦 Dépendances Principales

- `sqflite`: Base de données SQLite locale
- `http` & `csv`: Import des items depuis CSV
- `intl`: Formatage des dates en français
- `provider`: Gestion d'état (si nécessaire)




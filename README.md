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

### 🔄 Système de Révision Automatique
Le système planifie automatiquement 5 types de révisions avec des durées adaptées selon la difficulté :

1. **Première vue** : 2h (lors de la découverte de l'item)
2. **Révision de groupe** : 2h (optionnelle, planifiable manuellement)
3. **Révision 1** : J+1 (1h à 2h30 selon difficulté)
4. **Révision 2 QCM** : J+7 (30min à 1h30 selon difficulté)
5. **Révision 3** : J+21 (0 à 2h selon difficulté)
6. **Révision 4** : J+35 (0 à 2h selon difficulté)
7. **Révision 5** : J+49 (0 à 1h selon difficulté)

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

### 🎨 Interface Moderne
- Design Material 3
- Tons roses doux et élégants
- Navigation intuitive avec barre de navigation inférieure
- Animations fluides

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

## 🚀 Installation

1. Cloner le projet
```bash
git clone <votre-repo>
cd projet_gros_cerveau
```

2. Installer les dépendances
```bash
flutter pub get
```

3. Lancer l'application
```bash
flutter run
```

## 💡 Utilisation

### Premier Lancement
1. Allez dans l'onglet **Items ECN**
2. Cliquez sur **Importer les items** pour télécharger les 367 items depuis le CSV
3. Attendez que l'importation se termine

### Configuration des Horaires
1. Allez dans l'onglet **Paramètres**
2. Ajustez vos horaires de travail pour chaque jour
3. Les horaires par défaut sont 14h-22h (8h de travail)

### Enregistrer un Item Vu
1. Dans l'onglet **Planning**, cliquez sur le bouton **+**
2. Sélectionnez l'item que vous venez de voir
3. Indiquez la difficulté (Facile, Moyen, Difficile, Très difficile)
4. Optionnel : cochez "Révision de groupe" et choisissez une date
5. Cliquez sur **Enregistrer**
6. L'app planifie automatiquement toutes les révisions futures !

### Suivre vos Révisions
1. Onglet **Révisions** : voir toutes les révisions à faire
2. Les révisions sont triées par priorité
3. Cochez une révision quand elle est terminée
4. Onglet **Planning** : vue quotidienne de votre planning

## 🎯 Logique de Planification

### Durées par Difficulté et Type de Révision

| Type | Facile | Moyen | Difficile | Très difficile |
|------|--------|-------|-----------|----------------|
| Première vue | 2h | 2h | 2h | 2h |
| Groupe | 2h | 2h | 2h | 2h |
| Révision 1 | 1h | 1h30 | 2h | 2h30 |
| Révision 2 QCM | 30min | 1h | 1h30 | 1h30 |
| Révision 3 | 0min | 1h | 1h30 | 2h |
| Révision 4 | 0min | 1h | 1h30 | 2h |
| Révision 5 | 1h | 0min | 0min | 0min |

### Intervalles de Révision
- **Révision 1** : Lendemain (J+1)
- **Révision 2** : 7 jours après (J+7)
- **Révision 3** : 21 jours après (J+21)
- **Révision 4** : 35 jours après (J+35)
- **Révision 5** : 49 jours après (J+49)

### Allocation des Créneaux
- Pour les jours avec > 4h de travail : les 2 premières heures sont réservées pour voir de nouveaux items
- Les révisions sont placées automatiquement dans les créneaux disponibles
- Pas de chevauchement possible
- Si pas de créneau disponible, recherche jusqu'à 30 jours en avant

## 🎨 Palette de Couleurs

- **Rose principal** : `#F8BBD0`
- **Rose foncé** : `#F06292`
- **Rose clair** : `#FCE4EC`
- **Rose accent** : `#EC407A`
- **Fond** : `#FFF0F5`

## 📱 Plateformes Supportées

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

## 🔮 Améliorations Futures

- [ ] Statistiques de progression
- [ ] Graphiques de performance
- [ ] Notifications pour les révisions
- [ ] Export des données
- [ ] Synchronisation cloud
- [ ] Mode hors ligne optimisé
- [ ] Ajout manuel d'items personnalisés
- [ ] Filtres et recherche avancée
- [ ] Mode sombre

## 📝 Licence

Ce projet est destiné à un usage éducatif pour les étudiants en médecine.

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

---

Bon courage pour vos révisions ! 💪📚🩺

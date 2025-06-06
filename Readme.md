# Network Address Collector

Extension de navigateur minimaliste pour collecter automatiquement les adresses réseau (domaines) contactées lors de la navigation web. Utile pour créer des listes blanches de domaines de confiance ou analyser le trafic réseau.

## Fonctionnalités

- **Collecte automatique** : Intercepte toutes les requêtes HTTP/HTTPS
- **Filtrage intelligent** : Exclut les adresses locales et système
- **Métadonnées détaillées** : Compteur d'accès, dates de première/dernière visite
- **Interface intuitive** : Popup avec recherche, tri et statistiques
- **Export de données** : Sauvegarde au format JSON
- **Nettoyage automatique** : Suppression des données anciennes (30 jours)
- **Multi-navigateur** : Compatible Firefox et Chrome (Manifest V3)

## Structure du projet

```
network-address-collector/
├── src/
│   ├── manifest.yaml          # Configuration de l'extension
│   ├── background.coffee      # Script de collecte principal
│   ├── popup.pug             # Interface utilisateur
│   └── popup.coffee          # Logique de l'interface
├── package.json
└── README.md
```

## Installation

### Prérequis

Installez Node.js et les dépendances de développement :

```bash
npm install
```

### Transpilation des sources

L'extension utilise des langages de préprocessing qui doivent être transpilés :

#### 1. YAML vers JSON (Manifest)
```bash
# Installation globale du transpileur YAML
npm install -g js-yaml

# Transpilation du manifest
js-yaml manifest.yaml > manifest.json
```

#### 2. Pug vers HTML (Interface)
```bash
# Installation globale de Pug CLI
npm install -g pug-cli

# Transpilation du template
pug popup.pug
# Génère: popup.html
```

#### 3. CoffeeScript vers JavaScript
```bash
# Installation globale de CoffeeScript
npm install -g coffeescript

# Transpilation des scripts
coffee -c background.coffee    # Génère: background.js
coffee -c popup.coffee         # Génère: popup.js
```

### Build automatisé

Utilisez les scripts npm pour automatiser la transpilation :

```bash
# Build complet (une fois)
npm run build

# Watch mode (surveillance des changements)
npm run watch

# Nettoyage des fichiers générés
npm run clean
```

### Installation dans le navigateur

1. **Transpiler tous les fichiers** avec `npm run build`

2. **Chrome/Chromium** :
   - Aller à `chrome://extensions/`
   - Activer le "Mode développeur"
   - Cliquer "Charger l'extension non empaquetée"
   - Sélectionner le dossier du projet

3. **Firefox** :
   - Aller à `about:debugging`
   - Cliquer "Ce Firefox"
   - Cliquer "Charger un module temporaire"
   - Sélectionner le fichier `manifest.json`

## Usage

### Collecte automatique

L'extension commence à collecter automatiquement dès son installation :

1. **Navigation normale** : Surfez comme d'habitude
2. **Collecte transparente** : Les domaines sont enregistrés en arrière-plan
3. **Pas d'impact performance** : Traitement asynchrone minimal

### Interface utilisateur

Cliquez sur l'icône de l'extension pour ouvrir le popup :

#### Statistiques
- **Compteur total** d'adresses uniques collectées
- **Dernière mise à jour** avec horodatage
- **Fréquence d'accès** pour chaque domaine

#### Fonctionnalités
- **Recherche** : Filtrer les adresses par nom de domaine
- **Tri automatique** : Par fréquence d'accès (plus utilisées en premier)
- **Export JSON** : Sauvegarder toutes les données collectées
- **Effacement** : Réinitialiser complètement les données

### Export et analyse

Le fichier JSON exporté contient :

```json
{
  "addresses": ["example.com", "api.service.com", ...],
  "addressData": {
    "example.com": {
      "firstSeen": 1640995200000,
      "lastSeen": 1641081600000,
      "count": 25
    }
  },
  "exportDate": "2024-01-01T12:00:00.000Z"
}
```

### Création de listes blanches

Les données exportées peuvent être utilisées pour :

1. **Filtrer par fréquence** : Domaines visités > X fois
2. **Filtrer par récence** : Domaines vus dans les X derniers jours  
3. **Analyse de confiance** : Domaines régulièrement utilisés
4. **Integration** : Import dans des outils de sécurité réseau

### Gestion automatique

L'extension gère automatiquement :

- **Déduplication** : Pas de doublons dans la liste
- **Nettoyage** : Suppression des entrées > 30 jours
- **Filtrage** : Exclusion des domaines locaux/système
- **Performance** : Traitement asynchrone en arrière-plan

## Configuration

### Personnalisation du filtrage

Modifiez `background.coffee` pour ajuster les critères :

```coffeescript
isValidAddress: (address) ->
  excluded = [
    'localhost'
    '127.0.0.1'
    'votre-domaine-interne.local'  # Ajout personnalisé
  ]
  # Logique de filtrage...
```

### Durée de rétention

Changez la période de nettoyage dans `background.coffee` :

```coffeescript
cleanup: ->
  # 30 jours par défaut, modifiable
  retentionDays = 30
  cutoffTime = Date.now() - (retentionDays * 24 * 60 * 60 * 1000)
```

## Développement

### Architecture

- **Manifest V3** : Compatibilité moderne navigateurs
- **Service Worker** : Script background persistant
- **Storage API** : Stockage local sécurisé navigateur
- **WebRequest API** : Interception requêtes réseau

### Debug

1. **Console background** : `chrome://extensions/` → Détails → Inspecter les vues
2. **Console popup** : Clic-droit sur popup → Inspecter
3. **Logs** : `console.log` dans les scripts CoffeeScript

### Tests

```bash
# Vérification syntaxe
coffee --check background.coffee popup.coffee

# Validation YAML
js-yaml --version manifest.yaml

# Validation HTML
pug --check popup.pug
```

## Sécurité et confidentialité

### Données collectées
- **Domaines uniquement** : Pas d'URLs complètes
- **Pas de contenu** : Aucune donnée de page
- **Stockage local** : Pas de transmission externe
- **Nettoyage automatique** : Suppression périodique

### Permissions requises
- `webRequest` : Interception requêtes réseau
- `storage` : Sauvegarde locale données
- `activeTab` : Information onglet actif
- `<all_urls>` : Accès tous domaines (lecture seule)

## Licence

MIT License - Libre d'utilisation et modification.
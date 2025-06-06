# Network Address Collector

Extension de navigateur pour collecter les domaines contactés par chaque onglet et obtenir des descriptions générées par IA pour ces domaines.

## Fonctionnalités

- **Collecte de domaines par onglet** : Enregistre les domaines visités pour chaque onglet actif.
- **Description par IA** : Utilise les APIs Gemini ou Groq pour générer des descriptions et des classifications (nécessaire, utile, optionnel, publicitaire, suivi, dangereux) pour les domaines externes.
- **Interface Popup** : Affiche la liste des domaines collectés pour l'onglet actif avec leurs descriptions. Permet de copier les domaines sélectionnés, de vider la liste pour l'onglet actif, d'afficher la réponse JSON brute de l'API, et d'afficher la sortie de la console.
- **Page d'Options** : Permet de configurer les clés API pour Gemini et Groq.
- **Gestion des clés API** : Utilise les clés API configurées. Invite l'utilisateur à ajouter une clé si aucune n'est définie.
- **Mise en cache des descriptions** : Stocke les descriptions générées par l'IA pour éviter les appels répétés pour les mêmes domaines pour l'onglet actif.

## Structure du projet

```
network-address-collector/
├── src/
│   ├── manifest.yaml          # Configuration de l'extension
│   ├── background.coffee      # Script de collecte principal
│   ├── popup.pug             # Modèle d'interface utilisateur
│   └── popup.coffee          # Logique de l'interface utilisateur
├── package.json
└── README.md
```

## Installation

### Prérequis

Installez Node.js et les dépendances de développement :

```bash
npm install
```

### Transpilation des fichiers source

L'extension utilise des langages de préprocesseur qui doivent être transpilés :

#### 1. YAML vers JSON (Manifest)
```bash
# Installer le transpileur YAML globalement
npm install -g js-yaml

# Transpiler le manifest
js-yaml src/manifest.yaml > src/manifest.json
```

#### 2. Pug vers HTML (Interface)
```bash
# Installer Pug CLI globalement
npm install -g pug-cli

# Transpiler les modèles
pug src/popup.pug -o src/
pug src/options.pug -o src/
# Génère : src/popup.html, src/options.html
```

#### 3. CoffeeScript vers JavaScript
```bash
# Installer CoffeeScript globalement
npm install -g coffeescript

# Transpiler les scripts
coffee -c src/background.coffee src/popup.coffee src/options.coffee src/content.coffee
# Génère : src/background.js, src/popup.js, src/options.js, src/content.js
```

### Build automatisé

Utilisez les scripts npm pour automatiser la transpilation :

```bash
# Build complet (une fois)
npm run build

# Mode surveillance (surveille les changements)
npm run watch

# Nettoyer les fichiers générés
npm run clean
```

### Installation dans le navigateur

1. **Transpiler tous les fichiers** en utilisant `npm run build`.

2. **Chrome/Chromium** :
   - Allez à `chrome://extensions/`
   - Activez le "Mode développeur"
   - Cliquez sur "Charger l'extension non empaquetée"
   - Sélectionnez le dossier `src` du projet.

3. **Firefox** :
   - Allez à `about:debugging`
   - Cliquez sur "Ce Firefox"
   - Cliquez sur "Charger un module temporaire..."
   - Sélectionnez le fichier `src/manifest.json`.

## Utilisation

### Collecte automatique

L'extension commence à collecter automatiquement dès son installation :

1. **Navigation normale** : Naviguez comme d'habitude.
2. **Collecte transparente** : Les domaines sont enregistrés en arrière-plan pour l'onglet actif.
3. **Impact minimal sur les performances** : Traitement asynchrone en arrière-plan.

### Interface utilisateur

Cliquez sur l'icône de l'extension pour ouvrir le popup :

- Affiche une liste des domaines contactés par l'onglet actif.
- Montre les descriptions et classifications générées par l'IA pour les domaines externes.
- Permet de sélectionner des domaines via des cases à cocher.
- **Bouton Copier** : Copie les domaines sélectionnés dans le presse-papiers.
- **Bouton Effacer** : Efface les domaines collectés pour l'onglet actif.
- **Bouton Afficher la réponse JSON** : Bascule la visibilité de la réponse JSON brute de l'API IA.
- **Bouton Afficher la console** : Bascule la visibilité de la sortie de la console dans le popup.

## Gestion automatique

L'extension gère automatiquement :

- **Déduplication** : Empêche les domaines en double dans la liste pour un onglet.
- **Nettoyage** : Supprime les domaines collectés pour un onglet lorsque cet onglet est fermé.

## Sécurité et confidentialité

### Données collectées

- **Domaines uniquement** : Aucune URL complète ou contenu de page n'est collecté.
- **Pas de contenu** : Aucune donnée de page n'est collectée.
- **Requête IA** : Lorsque le popup est ouvert et qu'une clé API est configurée, l'extension envoie une requête à l'API (Gemini ou Groq) contenant la liste des domaines externes contactés par l'onglet actif. Cette requête demande à l'IA de fournir une courte explication ("why") et une classification ("brief" : nécessaire, utile, optionnel, publicitaire, suivi, dangereux) pour chaque domaine, au format JSON.
- **Stockage local** : Les données sont stockées localement dans le stockage du navigateur et ne sont pas transmises à l'extérieur.
- **Nettoyage automatique** : Les données pour un onglet sont supprimées lorsque l'onglet est fermé.

### Permissions requises
- `webRequest` : Intercepter les requêtes réseau.
- `storage` : Stocker les données localement.
- `activeTab** : Obtenir des informations sur l'onglet actif.
- `<all_urls>` : Accès à tous les domaines (lecture seule pour les requêtes web).

## Développement

### Architecture

- **Manifest V3** : Compatibilité moderne des extensions de navigateur.
- **Service Worker** : Script d'arrière-plan persistant.
- **Storage API** : Stockage local sécurisé du navigateur.
- **WebRequest API** : Intercepter les requêtes réseau.

## Licence

Licence MIT - Libre d'utilisation et de modification.

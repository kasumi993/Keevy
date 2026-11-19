# Keevy — mise en route et déploiement

Ce guide va du repo à une app qui tourne sur ton téléphone, puis en ligne.
Compte environ 30 minutes la première fois, sans compter la validation des stores.

---

## 0. Prérequis sur ton Mac

```bash
# Flutter (stable). Le projet est testé en CI avec Flutter 3.50
brew install --cask flutter
# CLI Supabase
brew install supabase/tap/supabase
# Xcode (App Store) et Android Studio pour les builds natifs
```

---

## 1. Créer le projet Supabase

1. Connecte-toi sur [supabase.com](https://supabase.com) avec le compte que tu veux utiliser, puis **New project** :
   - nom : `keevy`
   - région : `eu-west-3` (Paris), pour le RGPD et la latence
   - note le mot de passe de la base.
2. Lie le repo au projet et pousse le schéma :

```bash
cd keevy
supabase login
supabase link --project-ref <TON_PROJECT_REF>     # visible dans l'URL du dashboard
supabase db push                                  # tables, sécurité RLS, bucket images, règles freemium
supabase config push                              # connexion par code à 6 chiffres + modèle d'email
supabase functions deploy link-preview shared-board revenuecat-webhook delete-account
```

3. Dans **Authentication → URL Configuration**, mets `https://keevy.app` (ou l'URL de ta PWA) comme Site URL.
4. **Emails** : le serveur SMTP intégré de Supabase est limité à quelques emails par heure. Avant le lancement,
   branche un SMTP gratuit (Resend ou Brevo) dans **Authentication → SMTP Settings**.

> Si `config push` n'est pas disponible, colle `supabase/templates/otp.html` dans
> **Authentication → Email Templates → Magic Link** et **Confirm signup**.
> Il doit contenir `{{ .Token }}` : c'est le code à 6 chiffres que l'app demande.

### Vérifier la sécurité (optionnel mais conseillé)

```bash
supabase start          # Postgres local avec Docker
supabase db reset       # applique la migration
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/rls_smoke.sql
# → KEEVY RLS SMOKE TEST: ALL PASSED
```

---

## 2. Lancer l'app

```bash
cp dart_defines.example.json dart_defines.json   # jamais commité (.gitignore)
# Remplis SUPABASE_URL et SUPABASE_ANON_KEY (Dashboard → Project Settings → API).
# La clé "publishable" (sb_publishable_…) ou l'ancienne "anon" marchent toutes les deux.

flutter pub get
flutter run --dart-define-from-file=dart_defines.json            # iOS / Android
flutter run -d chrome --dart-define-from-file=dart_defines.json  # PWA
```

Sans ces clés, l'app affiche un écran « Configuration manquante » au lieu de planter.

---

## 3. Partage depuis Instagram / TikTok (share sheet)

### Android
Rien à faire : Keevy apparaît dans le menu « Partager ». Les liens, textes et images arrivent dans l'app,
puis on revient à l'app d'origine après l'enregistrement.

### iOS (extension « KeevyShare », déjà dans le projet Xcode)
1. Ouvre `ios/Runner.xcworkspace` dans Xcode.
2. Pour les cibles **Runner** et **KeevyShare** : *Signing & Capabilities*, choisis ton équipe Apple Developer.
3. Vérifie que la capability **App Groups** contient `group.app.keevy.keevy` dans les deux cibles
   (crée le groupe sur developer.apple.com s'il n'existe pas).
4. Lance sur un vrai iPhone, puis dans Instagram : Partager → Plus → active Keevy.

Comment ça marche : l'extension affiche une fenêtre native par-dessus Instagram (choix du board, de la section
et d'une note) et dépose l'élément dans l'App Group. Keevy l'importe automatiquement à sa prochaine ouverture.

> Les identifiants `app.keevy.keevy` et `app.keevy.keevy.share` sont des valeurs par défaut.
> Si tu veux les changer, fais-le partout : Xcode, `KeevySharePlugin.swift` et `ShareViewController.swift`
> (constante `appGroup`), et `android/app/build.gradle.kts`.

---

## 4. Abonnements (RevenueCat)

1. Crée les produits dans App Store Connect et Google Play Console :
   `keevy_premium_monthly` à 4,99 $ et `keevy_premium_yearly` à 39,99 $.
2. Dans RevenueCat : crée le projet, ajoute les deux apps, crée l'entitlement **`premium`** et une offering
   *default* avec les packages *Monthly* et *Annual*.
3. Mets les clés publiques dans `dart_defines.json` : `REVENUECAT_APPLE_KEY` et `REVENUECAT_GOOGLE_KEY`.
4. Configure le webhook RevenueCat (Integrations → Webhooks) :
   - URL : `https://<ref>.supabase.co/functions/v1/revenuecat-webhook`
   - Authorization header : `Bearer <un secret long>`
   ```bash
   supabase secrets set REVENUECAT_WEBHOOK_SECRET=<le même secret>
   ```

C'est le serveur qui fait respecter les limites, pas l'app : 3 boards Projet actifs en gratuit, et les liens
collaboratifs réservés à Premium. Le webhook met à jour `profiles.is_premium`.

---

## 5. Mettre la PWA en ligne

```bash
flutter build web --release --dart-define-from-file=dart_defines.json
# Déploie build/web sur Vercel, Netlify ou Cloudflare Pages.
# Règle de réécriture SPA indispensable : toutes les routes → /index.html (les liens /s/<token> et /join/<token> en dépendent).
```

`WEB_BASE_URL` doit pointer vers cette URL : c'est la base des liens de partage.
Les pages `/privacy` et `/terms` servent d'URL de confidentialité pour l'App Store et Google Play.
Fais relire leur texte : c'est un modèle.

---

## 6. Publier

- **Icônes** : remplace les icônes Flutter par défaut (`flutter_launcher_icons` ou Xcode / Android Studio).
- **Android** : crée une clé d'upload, configure `signingConfigs` dans `android/app/build.gradle.kts`, puis
  `flutter build appbundle --dart-define-from-file=dart_defines.json`.
- **iOS** : `flutter build ipa --dart-define-from-file=dart_defines.json`, puis upload avec Transporter.
- Fiches store : la suppression de compte est intégrée (Réglages → Supprimer mon compte), comme l'exige Apple.

---

## Architecture en bref

| Dossier | Contenu |
|---|---|
| `lib/core` | config, thème (tokens des maquettes), textes FR/EN, router, widgets communs |
| `lib/features/*` | `domain` (modèles), `data` (accès Supabase), `application` (providers Riverpod), `presentation` (écrans) |
| `supabase/migrations` | schéma, RLS, règles freemium, bucket `card-images` |
| `supabase/functions` | `link-preview`, `shared-board`, `revenuecat-webhook`, `delete-account` |
| `ios/KeevyShare` | extension de partage iOS (SwiftUI) |
| `android/.../MainActivity.kt` | réception des partages Android |

Choix techniques : Riverpod 2 **sans génération de code** (pas de `build_runner`, donc moins d'entretien),
go_router, connexion sans mot de passe par code email, images de galerie privées (URLs signées),
images Instagram/TikTok jamais copiées (on garde l'URL et l'aperçu).

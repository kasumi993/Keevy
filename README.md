# Keevy

*Save your inspiration. Plan your moments.*

Keevy est une app mobile (iOS, Android et PWA) pour garder ses inspirations (reels Instagram, TikTok,
pages de prestataires, photos, notes) dans des boards privés, et planifier ses événements quand le moment
vient : mariage, baby shower, anniversaire, crémaillère.

- **Boards Inspiration** : sections horizontales, grille masonry, photos, liens avec aperçu, notes.
- **Mode Projet** : compte à rebours, checklist générée depuis des modèles, prestataires avec statut
  (Découvert → Contacté → Devis reçu → Confirmé), budget estimé.
- **Partage natif** : « Partager → Keevy » depuis n'importe quelle app (extension iOS et intents Android).
- **Contacts** : chaque prestataire existe une seule fois (dédoublonnage par Instagram, email ou téléphone)
  et se retrouve dans tous ses boards, avec son mini-board et ses tâches liées.
- **Liens** : tous les liens sauvegardés, filtrables par plateforme.
- **Partage de board** : lien en lecture seule (gratuit) ou collaboratif (Premium). Privé par défaut.
- **Freemium** : 3 boards Projet actifs en gratuit, Premium à 4,99 $/mois ou 39,99 $/an (RevenueCat).

**Stack** : Flutter 3, Riverpod 2, go_router, Supabase (Postgres + RLS, Auth, Storage, Edge Functions).

👉 Mise en route, déploiement et publication : [docs/SETUP.md](docs/SETUP.md)

```bash
cp dart_defines.example.json dart_defines.json   # puis remplis tes clés Supabase
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

Tests : `flutter test` (app), `deno test supabase/functions` (fonctions),
`supabase/tests/rls_smoke.sql` (sécurité de la base).

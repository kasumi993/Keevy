import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/tokens.dart';

enum LegalKind { privacy, terms }

/// Public privacy policy and terms (also served by the PWA at /privacy and /terms,
/// which is the URL to give the App Store and Google Play). Template — have it reviewed.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final sections = kind == LegalKind.privacy ? _privacy(s.isFr) : _terms(s.isFr);
    return Scaffold(
      appBar: AppBar(
        title: Text(kind == LegalKind.privacy ? s.privacy : s.terms),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(KSpacing.xl),
            children: [
              for (final (title, body) in sections) ...[
                Text(title, style: t.headlineSmall),
                const SizedBox(height: KSpacing.sm),
                Text(body, style: t.bodyLarge?.copyWith(color: KColors.t2)),
                const SizedBox(height: KSpacing.xl),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static List<(String, String)> _privacy(bool fr) => fr
      ? const [
          ('En bref', 'Keevy est un espace privé. Tes boards, contacts et images ne sont visibles que par toi, et par les personnes à qui tu envoies un lien de partage. Pas de publicité, pas de revente de données.'),
          ('Données collectées', 'Ton email (connexion), ton prénom si tu le renseignes, et le contenu que tu ajoutes : boards, sections, notes, liens, images importées depuis ta galerie, contacts de prestataires et tâches. Pour les liens Instagram, TikTok ou Pinterest, nous enregistrons l’adresse et l’aperçu public, jamais une copie de la publication.'),
          ('Hébergement', 'Les données sont hébergées par Supabase (base de données, authentification, stockage) dans l’Union européenne. Les images de ta galerie sont stockées de façon privée et servies par des liens temporaires.'),
          ('Paiements', 'Les abonnements sont gérés par l’App Store ou Google Play, via RevenueCat. Nous ne voyons jamais ta carte bancaire.'),
          ('Tes droits', 'Tu peux modifier ou supprimer chaque élément, et supprimer ton compte depuis Réglages → Supprimer mon compte : toutes tes données et images sont alors effacées. Pour toute question : contact@keevy.app.'),
        ]
      : const [
          ('In short', 'Keevy is a private space. Your boards, contacts and images are only visible to you, and to people you send a share link to. No ads, no data resale.'),
          ('What we collect', 'Your email (sign-in), your first name if you add it, and the content you add: boards, sections, notes, links, images imported from your gallery, vendor contacts and tasks. For Instagram, TikTok or Pinterest links we store the address and the public preview, never a copy of the post.'),
          ('Hosting', 'Data is hosted by Supabase (database, authentication, storage) in the European Union. Gallery images are stored privately and served through temporary links.'),
          ('Payments', 'Subscriptions are handled by the App Store or Google Play, through RevenueCat. We never see your card.'),
          ('Your rights', 'You can edit or delete any item, and delete your account from Settings → Delete my account: all your data and images are erased. Questions: contact@keevy.app.'),
        ];

  static List<(String, String)> _terms(bool fr) => fr
      ? const [
          ('Le service', 'Keevy permet de sauvegarder des inspirations, de les organiser en boards et de planifier des événements. Le plan gratuit inclut 3 boards Projet actifs et le partage en lecture seule.'),
          ('Keevy Premium', 'L’abonnement mensuel ou annuel débloque les boards Projet illimités et les liens collaboratifs. Il se renouvelle automatiquement et s’annule à tout moment depuis les réglages de ton store.'),
          ('Ton contenu', 'Tu restes propriétaire de ce que tu ajoutes. Tu es responsable des contenus que tu partages par lien. Les liens vers des publications tierces restent la propriété de leurs auteurs.'),
          ('Usage acceptable', 'Pas de contenu illégal, haineux ou portant atteinte aux droits d’autrui. Nous pouvons suspendre un compte en cas d’abus.'),
          ('Responsabilité', 'Le service est fourni en l’état. Nous faisons notre maximum pour sa disponibilité et la sauvegarde de tes données.'),
        ]
      : const [
          ('The service', 'Keevy lets you save inspiration, organise it in boards and plan events. The free plan includes 3 active Project boards and read-only sharing.'),
          ('Keevy Premium', 'The monthly or yearly subscription unlocks unlimited Project boards and collaborative links. It auto-renews and can be cancelled anytime from your store settings.'),
          ('Your content', 'You own what you add. You are responsible for content you share by link. Links to third-party posts remain the property of their authors.'),
          ('Acceptable use', 'No illegal or hateful content, nothing infringing others’ rights. We may suspend an account in case of abuse.'),
          ('Liability', 'The service is provided as is. We do our best to keep it available and your data backed up.'),
        ];
}

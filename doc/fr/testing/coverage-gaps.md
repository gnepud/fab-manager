# Limites de couverture

Ces limites ne déterminent pas la réussite ou l’échec. Si un cas exige un service indisponible, noter que le cas est bloqué.

## Non disponible dans l’environnement local de base

- **OpenLab et DoDoc distant :** Vérifier uniquement les paramètres locaux. Ne pas se connecter à une instance distante.
- **reCAPTCHA :** La connexion locale ne teste pas l’intégration à un site réel.
- **SSO :** Utiliser uniquement des fournisseurs de test OAuth2, OIDC et SAML. Les fournisseurs réels, les variantes de production, l’association ou la fusion de comptes existants et `send_code` sont hors périmètre.
- **SMTP :** Utiliser MailCatcher ou la boîte de test Rails. Cela ne teste pas la livraison en production.
- **Échéances PayZen suivantes :** Simuler le rapprochement localement. Ce test ne couvre ni les prélèvements suivants réels, ni le changement de carte entre comptes auprès de la passerelle, ni les paniers réellement expirés. Une réponse HTTP 422 simulée vérifie uniquement le traitement de l’erreur par la page.
- **Langues non prises en charge :** Ne pas confondre `zh` et `zh-CN`. L’application n’active pas `sv`. Ne pas établir d’assertions pour les langues non prises en charge. Pour les langues prises en charge, distinguer un texte de repli anglais d’une erreur d’exécution.

## Scénarios non couverts par ces cas

| Domaine | Scénarios |
| --- | --- |
| Calendrier | Afficher les événements internes. Modifier les étiquettes ou formules d’abonnement après création. Supprimer une occurrence et les suivantes. Modifier le premier jour de la semaine. |
| Événements | Payer par carte, y compris pour un événement famille payant. Envoyer un courriel aux membres après modification. Modifier toutes les occurrences suivantes d’un événement récurrent. |
| Abonnements et packs prépayés | Échéances Stripe ultérieures, authentification hors session, annulation d’échéancier, changement de carte et webhooks. Soumissions simultanées ou répétées et rapprochement des doubles débits. Réutilisation des crédits après renouvellement. Achat d’un pack par carte. Modification d’un pack pour espace. État de paiement d’un échéancier à montant nul. |
| Boutique | Parcourir les pages de produits. Acheter le dernier article simultanément. Rembourser une partie d’une ligne par montant ou quantité. Tester dans l’API toutes les combinaisons d’états de commande et de motifs de stock. Tester tous les ordres de catégories. |
| Courriels et tâches | Vérifier le planificateur le jour de l’expiration, de clôture comptable, de justificatifs, de formation et d’âge des enfants. Lancer une tâche manuellement ne teste pas la planification. Tester la livraison en production des mises à jour de la politique de confidentialité. |
| Projets | Signaler un projet sans connexion (l’application exige une connexion). Insérer un projet pendant la pagination. Vérifier le lien du projet dans la notification de signalement. |
| Flux externes et exploitation | Tester `/ical/reservations/:reservable_type` et le flux RSS des événements. Ces flux ne sont pas l’import du calendrier. Tester la vérification de version, les alertes, `/health` et `/admin/sidekiq`. |
| Open API | Tester les points d’accès autres que `GET /users` : `plans`, `plan_categories`, `prices`, `trainings`, `user_trainings`, `reservations`, `machines`, `spaces`, `bookable_machines`, `invoices`, `events`, `availabilities`, `accounting` et `subscriptions`. Tester le retour de la documentation API à l’application. |
| Administration | Tester toutes les créations, consultations, modifications et suppressions de machines et catégories, espaces, formations, formules d’abonnement et catégories, tarifs, catégories tarifaires et tranches d’âge, paramètres, factures, coupons et groupes. |
| Visites, langues et affichage mobile | Vérifier chaque page dans chaque langue prise en charge. Vérifier les messages d’échec 3DS dans chaque langue. Vérifier l’ensemble de l’affichage mobile. |

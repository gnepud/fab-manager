# Guide des tests navigateur Fab-manager

[English version](../../testing/README.md)

| Domaine | Cas de test |
| --- | --- |
| Comptes, membres, droits, tableau de bord, famille, calendrier, réservations, événements et formations | [Fonctions principales](core.md) |
| Abonnements, packs prépayés, factures, comptabilité, statistiques, boutique et paiements de test | [Paiements, boutique et rapports](commerce.md) |
| Projets, paramètres, pages publiques, visites, langues, courriels, tâches, SSO et Open API | [Plateforme et intégrations](platform.md) |
| Limites et services externes | [Limites de couverture](coverage-gaps.md) |

## Préparer les tests

1. Noter le commit de l’application, le navigateur, la taille d’affichage, la langue, le fuseau horaire du site et la passerelle de paiement.
2. Sélectionner le français pour ces cas. Le texte entre guillemets reprend le libellé exact de l’application. Utiliser les routes si aucun libellé n’est indiqué. Prendre les valeurs de `:id` et de `:slug` dans les données de test. Les montants d’exemple sont en euros.
3. Utiliser une base de développement isolée et temporaire, ainsi que des instances Redis et Elasticsearch isolées. Ne pas se connecter à la production. Ne pas importer de données réelles. Consulter le [guide de développement](../../development_readme.md).
4. Démarrer Rails et le client. Démarrer Sidekiq pour les PDF, les exports et les tâches de messagerie. Utiliser MailCatcher au lieu du serveur SMTP de production.
5. Charger les données ci-dessous. Rétablir le même état initial avant chaque cas qui modifie le solde, le stock, les créneaux ou les enregistrements. Utiliser un contexte de navigateur distinct par rôle.
6. Exécuter d’abord les cas `smoke`. Ajouter les cas `full` pour une régression complète. **Automatisable : Oui** indique un cas adapté à Playwright ou aux tests système Rails. Préparer les conditions avec des données Rails ou une tâche si nécessaire. **Non** indique une action manuelle, un environnement externe de test ou un contrôle visuel.
7. Utiliser l’identifiant du cas dans le nom du test automatisé. Préparer les conditions préalables. Transformer les résultats attendus en assertions. Noter le rôle, les entrées et le résultat observé. Noter Réussi, Échoué ou Bloqué. Si un service ou une donnée manque, indiquer pourquoi le cas est bloqué.

## Charger les données de test

Définir `ADMIN_EMAIL`, `ADMIN_PASSWORD` et `BROWSER_QA_PASSWORD` dans l’environnement local. Utiliser seulement des valeurs de test. Ne pas capturer ni enregistrer ces valeurs dans le dépôt. Utiliser des mots de passe de 12 à 128 caractères avec une majuscule, une minuscule, un chiffre et un caractère spécial.

Utiliser la configuration PostgreSQL, Redis et Elasticsearch du projet. Exécuter ces commandes depuis la racine du dépôt :

~~~sh
RAILS_ENV=development SKIP_TEST_DATABASE=1 bundle exec rails db:create db:schema:load db:migrate db:seed
RAILS_ENV=development bundle exec rails fablab:es:build_stats
RAILS_ENV=development bundle exec rails runner doc/testing/seed_browser_qa.rb
~~~

Exécuter `db:schema:load` uniquement sur une base vide. Exécuter `db:migrate` pour appliquer les migrations absentes du schéma. Désactiver le paiement en ligne avant d’exécuter le script. Le script active les espaces et rend la boutique visible aux membres. Il crée des créneaux à venir et les indexe après validation de la transaction. Une seconde exécution le même jour ne crée pas de doublons. Le script ne réinitialise pas les soldes, le stock, les mots de passe ni les réservations. Pour les cas qui consomment ou suppriment des données et les tests sur plusieurs dates, utiliser une base neuve ou restaurer une copie locale.

| Données de test | Utilisation |
| --- | --- |
| `qa-admin@example.com`, `qa-manager@example.com` | Administrateur et gestionnaire |
| `qa-member@example.com`, `qa-member2@example.com`, `qa-other@example.com` | Deux membres d’un même groupe et un membre d’un groupe aux tarifs différents |
| `qa-partner@example.com`, `qa-delete@example.com` | Partenaire et compte membre que l’application peut supprimer |
| `QA Browser`, `QA Browser Other` | Groupe principal et groupe de comparaison |
| `QA Machine`, `QA Open Machine`, `QA Training`, `QA Space` | Machine avec formation obligatoire, machine sans cette restriction, formation et espace, avec des créneaux à venir |
| `QA Plan`, pack prépayé de `QA Machine` | Abonnement, crédits et temps de machine prépayé |
| `QA Standard Event`, `QA Family Event`, `QA Product`, `QA Browser Project` | Événement standard payant, événement famille gratuit, produit en stock et projet publié |

Les comptes de test utilisent `BROWSER_QA_PASSWORD` à la création. Créer toute donnée supplémentaire dans la copie isolée propre au cas. Pour un paiement par porte-monnaie, se connecter en tant qu’administrateur. Ouvrir `/admin/members/:id/edit`. Ajouter des fonds dans l’onglet « Porte-monnaie ». Noter le solde avant le paiement. Pour un paiement mixte, créditer seulement une partie du montant.

Laisser les passerelles externes désactivées par défaut. Pour Stripe, utiliser une instance TEST locale distincte. Fournir `STRIPE_API_KEY` et `STRIPE_PUBLISHABLE_KEY`. Configurer les paramètres TEST et synchroniser les objets de test. Pour PayZen, utiliser une autre instance TEST locale. Fournir les valeurs de configuration avec `PAYZEN_TEST_USERNAME`, `PAYZEN_TEST_PASSWORD`, `PAYZEN_TEST_ENDPOINT`, `PAYZEN_TEST_PUBLIC_KEY`, `PAYZEN_TEST_HMAC` et `PAYZEN_TEST_CURRENCY`. L’application ne lit pas automatiquement ces variables PayZen. Ne pas utiliser de vraies cartes. Ne pas écrire les jetons ou les clés dans les journaux. Si la messagerie de test demande des identifiants, utiliser `SMTP_USER_NAME` et `SMTP_PASSWORD`. La configuration par défaut de MailCatcher n’en a pas besoin.

## Règles métier

- L’annulation d’une réservation de machine standard ne recrédite pas le porte-monnaie. La règle d’annulation automatique d’une formation est différente.
- Un avoir est un document comptable. Il ne déclenche pas de remboursement bancaire, par la passerelle ou par le porte-monnaie. L’annulation ou le remboursement en boutique ne rajoute pas de stock.
- L’application doit bloquer la suppression d’un compte qui a une réservation future ou un abonnement actif. Elle doit afficher une erreur dans la langue sélectionnée.
- L’annulation automatique d’une formation ne rend pas les crédits de formation de l’abonnement. Une formation gratuite ou réglée uniquement par crédit ne donne pas lieu à un remboursement dans le porte-monnaie.
- Les administrateurs et gestionnaires peuvent réserver pour un membre sans autorisation de formation. Un membre qui réserve pour lui-même doit toujours disposer de l’autorisation si la machine l’exige.

## Vérifier les libellés de l’application

Depuis la racine du dépôt, exécuter `ruby doc/testing/check_ui_labels.rb`. Mettre les libellés français exacts entre guillemets français. Utiliser des accents graves pour les routes, identifiants et données de test. La commande compare les libellés cités dans les deux guides aux valeurs des fichiers de traduction correspondants. Utiliser la clé de traduction de la page pour ajouter ou modifier un libellé. Une valeur identique ne prouve pas à elle seule que le libellé apparaît sur cette page.

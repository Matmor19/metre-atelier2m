# Référence des points validés — métré Atelier 2M

À relire avant chaque modification. Tout changement doit laisser ces points intacts.
Lancer les tests : `python3 tests/regression.py` (doit afficher « TOUT EST OK »).

## Configurateur → métré
- **Installation de chantier** (lot en tête) : eau OUV-0485, électricité OUV-0486, base vie OUV-0484, grue OUV-0492, benne gravats OUV-0487 (u = bennes), benne triée OUV-0488 (u = bennesTri).
- **Terrassement** : fouille en tranchée OUV-0008 (rigole) et massif OUV-0010 ; décapage OUV-0007 ; réseaux OUV-0018 (eau), OUV-0016 (EU), OUV-0524 (EP), OUV-0879 (élec).
- **Gros œuvre lié** : chaque fouille crée sa semelle (OUV-0040 filante, OUV-0041 isolée), même quantité, suit les modifications, disparaît avec la fouille. Plateforme exclue. Rigole = champ rigLin uniquement.
- **Clôture (OUV-0004)** : jamais créée automatiquement. Ajout uniquement à la main depuis la bibliothèque.
- **Lots** : ordre de la bibliothèque, installation de chantier en premier.

## Surbrillance (écran seulement, jamais à l'impression)
- Pas de couleur : lignes produites directement par le configurateur (décapage, réseaux, installation…).
- **Mauve** : ligne ajoutée à cause d'une autre ligne (semelle liée à une fouille ; ligne de bibliothèque reliée à une case).
- **Ambre** : saisie à la main.

## Saisie à la main d'un ouvrage déjà produit par le configurateur
- Une confirmation est demandée. OK = la saisie remplace la ligne du configurateur (une seule ligne, en ambre), et le configurateur ne la recrée plus. Annuler = rien n'est ajouté.

## Synchronisation
- Messages : un par chantier affiché ; chantiers supprimés masqués.
- À l'ouverture : silencieuse (pas de message, pas de dialogue).
- Bouton manuel : barre d'avancement en % avec bande verte, qui avance à chaque requête, masquée 1,5 s après la fin.
- Conflit (clic explicite seulement) : 1) « Garder la version de ce téléphone » ; 2) si refusé, « Reprendre la version de Drive » ; 3) si refusé, le conflit reste.
- « Synchroniser le métré » (en haut de la vue Tableau) : met à jour le configurateur puis synchronise.

## Points ouverts (pas encore validés)
- Doublon de clôture sur « Test configurateur » : à supprimer à la main, puis à vérifier avec le nouveau remplacement.
- Lignes de clôture déjà présentes avec l'ancien libellé de décapage : sans importance, chantier de test.

## Configurateur de pièces
- **Bloc A (ancien configurateur de pièces)** : EN VEILLE (`PIECES_ANCIEN_VEILLE = true` dans app.js). Ses données sont conservées, il ne produit plus aucune ligne, et la synchronisation ne retire rien. Pour le réactiver : passer le drapeau à `false`, puis relancer les tests.
- **Bloc C (nouveau configurateur de pièces)** : par pièce, surface au sol et revêtement, portes fin de chantier 83×204, menuiseries extérieures (fenêtre), appareillage de la pièce (prises, RJ45, interrupteurs, points lumineux). Bouton « Ajouter au métré » : régénère les lignes de la pièce (elles portent `pieceNv`, sans surbrillance) sans jamais les doubler.
- Non encore câblé : les plâtreries liées au revêtement, et les plinthes.

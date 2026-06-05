# Tests métier — dbt_nyc_taxi

Ce dossier contient les tests singuliers dbt (« singular tests »). Chaque fichier est une requête SQL qui **retourne les lignes en violation** : 0 ligne = test OK, au moins 1 ligne = échec.

Les tests génériques (`not_null`, `unique`, `accepted_values`, `relationships`, `dbt_utils.unique_combination_of_columns`) sont déclarés directement dans les fichiers `_models.yml` de chaque couche.

---

## Convention de nommage

```
assert_<modèle>_<ce_qui_est_vérifié>.sql
```

---

## Tests par modèle

### `stg_yellow_trips` (staging)

#### `assert_no_negative_amounts`
**Type** : cohérence des données brutes  
**Règle** : `fare_amount >= 0` et `total_amount >= 0`  
Vérifie qu'aucun montant négatif n'a traversé le nettoyage du staging. Un montant négatif est soit une erreur de saisie TLC, soit un remboursement non filtré.

---

### `hourly_patterns` (mart)

#### `assert_rush_hour_above_average_trips`
**Type** : pattern métier temporel  
**Règle** : pour chaque mois, la moyenne de trajets par heure de pointe (7h-9h, 16h-19h) dépasse la moyenne hors pointe, **sur les jours ouvrés uniquement**.  
Les heures de pointe correspondent aux flux domicile-travail et travail-domicile, mécaniquement les plus chargées en semaine dans tous les datasets TLC historiques.

---

### `zone_analysis` (mart)

#### `assert_zone_activity_coherent`
**Type** : invariant mathématique du modèle  
**Règle** : `total_zone_activity >= trips_as_origin` pour toutes les zones.  
`total_zone_activity = trips_as_origin + trips_as_destination`, les deux termes étant des `COUNT(*)` donc toujours ≥ 0. Toute violation indique une incohérence arithmétique dans le modèle.

---

### `daily_summary` (mart)

#### `assert_daily_summary_manhattan_busiest_borough`
**Type** : pattern métier géographique  
**Règle** : Manhattan a plus de départs que tout autre borough chaque mois.  
~70 % des trajets Yellow Taxi démarrent à Manhattan (source : TLC historical data). Si un autre borough dépasse Manhattan, c'est une anomalie dans les données ou le pipeline.

#### `assert_daily_summary_weekday_trips_exceed_weekend`
**Type** : pattern métier temporel  
**Règle** : le total des trajets en semaine dépasse le total du week-end chaque mois.  
Deux facteurs combinés : (1) ~22 jours ouvrés contre ~9 jours de week-end par mois, (2) le Yellow Taxi sert principalement les voyageurs d'affaires en semaine — Uber/Lyft ont capturé l'essentiel du marché loisir/nuit.

> **Attention** : contrairement à l'intuition, les vendredis ne sont pas les jours les plus chargés pour les Yellow Taxis. Le pic est en milieu de semaine (mardi-jeudi).

#### `assert_daily_summary_manhattan_card_tips_positive`
**Type** : pattern métier financier  
**Règle** : la moyenne mensuelle du taux de pourboire carte (`avg_tip_pct_card`) à Manhattan est toujours **≥ 15 %**.  
Les terminaux POS des taxis NYC affichent par défaut des boutons à 20 %, 25 % et 30 %. 15 % est la norme culturelle minimale à NYC. La clientèle touristique et d'affaires de Manhattan tip systématiquement au-dessus de ce seuil.

> **Périmètre** : seuls les paiements carte (`payment_type_id = 1`) sont pris en compte — `tip_percentage` est déjà `NULL` pour les autres modes de paiement dans le staging.

---

## Pièges connus

| Hypothèse intuitive | Réalité sur les données TLC 2024-2025 |
|---|---|
| NYE a plus de trajets que les autres jours de décembre | Faux — Uber/Lyft dominent le 31/12 |
| Les week-ends ont des trajets plus longs que la semaine | Faux — les longs trajets aéroport sont surtout en semaine (voyageurs d'affaires) |
| Manhattan a le tarif/km le plus élevé | Faux — le Bronx a un tarif/km élevé sur de très courts trajets (tarif minimum $3 / 0,5 km) |
| Les vendredis sont plus chargés que les mardis | Faux pour le Yellow Taxi — le marché de nuit appartient aux VTC |

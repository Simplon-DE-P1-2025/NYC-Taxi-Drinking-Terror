# Présentation Marp

Slides de présentation au format [Marp](https://marp.app/).

## Prévisualiser (VS Code)

Installer l'extension **Marp for VS Code**, puis ouvrir `slides.md` et cliquer sur l'icône de prévisualisation.

## Exporter en PDF / HTML

```bash
# Via npx (sans installation globale)
npx @marp-team/marp-cli slides.md --pdf
npx @marp-team/marp-cli slides.md --html

# Ou avec marp-cli installé globalement
marp slides.md --pdf
```

## Compléter les slides

Les sections marquées `<!-- TODO -->` sont à remplir une fois la branche `develop` finalisée :
- Chiffres clés réels (volume, KPIs)
- Captures d'écran du dashboard Streamlit

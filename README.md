# Never Give Up Mining ⛏💎

Jeu Roblox inspiré du mème du mineur qui abandonne à un bloc des diamants.

## Le concept
- Chaque joueur a son **propre tunnel** (maintiens le clic / le doigt pour creuser).
- Les blocs rapportent des pièces → on améliore la pioche pour creuser plus vite.
- Quelque part, entre 150 et 300 blocs de profondeur, se cache un **filon de diamants**. Sa profondeur est secrète (jamais envoyée au client). Seule une faible lueur bleue sur le dernier bloc le trahit.
- **Abandonner** te ramène à la surface et remet ta profondeur à 0, mais le filon reste au même endroit. Le jeu te dit à combien de blocs tu t'es arrêté.
- Arrivé au filon, prends le gros diamant : récompense + **renaissance** (le filon suivant est plus profond, les gains sont multipliés).

## Lancer le projet
1. Installer [Rojo](https://rojo.space) et le plugin Rojo dans Roblox Studio.
2. Dans ce dossier : `rojo serve`, puis « Connect » depuis le plugin dans Studio.
3. Play (le DataStore nécessite « Enable Studio Access to API Services » pour sauvegarder en Studio ; sans, le jeu fonctionne mais ne sauvegarde pas).

## Structure
- `src/shared/Config.lua` : tout l'équilibrage (profondeurs, coûts, dégâts, matériaux).
- `src/server/Main.server.lua` : génération des tunnels, minage, boutique, sauvegarde, caverne.
- `src/client/Main.client.lua` : interface et input.

## Idées pour la suite
Sons et animation de pioche, mineurs « abandonneurs » (PNJ) croisés dans le tunnel, skins de pioche, pets, classement de la profondeur max, game passes.

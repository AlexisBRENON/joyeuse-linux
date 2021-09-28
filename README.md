# 🎙️ Joyeuse Linux 🐧
> Scripts Linux pour utiliser la compteuse merveilleuse.

## Moulinette

Le script [`moulinette.sh`](./moulinette.sh) utilise ffmpeg pour convertir à peu près n'importe quel fichier d'entrée (audio ou video) en un fichier MP3 compatible.

### Usage

```bash
./moulinette.sh ~/Musique/mon_audio.aac /run/media/alexis/JOYEUSE-507/FR/LION/mon_audio.mp3
```

## Versionneuse

Le script [`updade.sh`](./update.sh) permet de mettre à jour la compteuse.
Pour l'instant les fonctionnalités sont limitées : sauvegarde du contenu, mise à jour, restauration.
Ce script fait appel à plusieurs utilitaires dont `curl`, `7z`, `rsync`, `objcopy`, `dfu-util`, etc. qui doivent être installé avant la mise à jour.

### Usage

```bash
./update.sh
```

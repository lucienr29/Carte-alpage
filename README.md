# Cartes de terrain

Cartes des réseaux d'eau des alpages sur le téléphone, publiés avec GitHub Pages.

- `index.html` : page d'accueil qui liste les outils.
- `serin/` : réseau d'eau de l'alpage de Serin (conduites, vannes, purges, bassins). Protégé par mot de passe : le plan est chiffré dans la page (AES-GCM) et le fichier DXF source n'est pas publié ici.
- `supabase/schema.sql` : base des modifications faites sur le site. Chaque outil a son propre code de site dans la colonne `site`.

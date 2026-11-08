# AVIONIX
Liste de commandes écrit en Pascal (Turbo Pascal ou Free Pascal) pour l'aviation. 

Voici un aperçu d'OpenVSP (OPENVSP.PAS) :

<img width="638" height="478" alt="image" src="https://github.com/user-attachments/assets/8bd3002b-e9c8-4593-b261-22bcbd7047be" />

Voici un aperçu de la soufflerie comme SOUFFLE.PAS (Soufflerie) :

<img width="638" height="479" alt="image" src="https://github.com/user-attachments/assets/3743114c-fac7-4b00-8142-903e68449ffa" />

Voici un aperçu de FLIGHT.PAS (Simulateur de vol) :

<img width="636" height="481" alt="image" src="https://github.com/user-attachments/assets/a14dca95-10e5-4ec6-bbea-4871b3d0dc7a" />

<img width="643" height="477" alt="image" src="https://github.com/user-attachments/assets/66e0aa7e-3d11-4391-aa70-e304b47236bf" />

<img width="645" height="482" alt="image" src="https://github.com/user-attachments/assets/6bea64b1-062e-430d-8032-c609b55c4f1c" />

<h3>Liste des fichiers</h3>

Voici la liste des différents fichiers proposés dans l'aviation :

<table>
	<tr>
		<th>Nom</th>
		<th>Description</th>
	</tr>
	<tr>
		<td><b>ATMOSPH.PAS</b></td>
		<td>Cette commande permet de calculer l'atmosphère standard (température, pression, densité, vitesse du son), les altitudes-pression et -densité, la conversion des vitesses IAS, CAS, EAS, TAS et Mach, ainsi que le calage altimétrique (QNH, QFE).</td>
	</tr>
	<tr>
		<td><b>ATTERRI.PAS</b></td>
		<td>Cette commande permet de calculer la distance d'atterrissage d'un avion (phase aérienne, roulage libre et freiné, vent, pente, état de piste, marge de sécurité).</td>
	</tr>
	<tr>
		<td><b>CARBU.PAS</b></td>
		<td>Cette commande permet de calculer l'autonomie, la portée et le rayon d'action d'un avion (carburant, vent, réserves, déroutement, formule de Breguet).</td>
	</tr>
	<tr>
		<td><b>CAS.PAS</b></td>
		<td>Cette commande permet de calculer la vitesse anémométrique corrigée (Calibrate Airspeed).</td>
	</tr>
	<tr>
		<td><b>CHARGE.PAS</b></td>
		<td>Cette commande permet de calculer le centre de gravité d'un avion à partir de son chargement (masse et bras de levier de chaque poste, % MAC, enveloppe, consommation du carburant).</td>
	</tr>
	<tr>
		<td><b>DECOL.PAS</b></td>
		<td>Cette commande permet d'effectuer l'estimation de la distance de décollage.</td>
	</tr>
	<tr>
		<td><b>DECROCH.PAS</b></td>
		<td>Cette commande permet de calculer la vitesse de décrochage et les performances en virage d'un avion (facteur de charge, rayon, taux de virage, inclinaison).</td>
	</tr>
	<tr>
		<td><b>DESCENTE.PAS</b></td>
		<td>Cette commande permet d'effectuer la simulation de la descente d'un avion.</td>
	</tr>
	<tr>
		<td><b>FINDPLN.PAS</b></td>
		<td>Cette commande permet de détecter les avions mentionné dans un texte.</td>
	</tr>
	<tr>
		<td><b>FLIGHT.PAS</b></td>
		<td>Cette commande permet de lancer un clone de Flight Simulator, un simulateur de vol en mode graphique avec vue 3D (cockpit, externe, tour de contr&ocirc;le et carte), instruments de bord, relief, villes, a&eacute;roports, nuages, vent, m&eacute;t&eacute;o (ensoleill&eacute;, nuageux, pluie, orage, tornade ou al&eacute;atoire), vol de nuit, ILS, pilote automatique et tous les avions du r&eacute;pertoire <code>SAMPLES/FLIGHT</code> (une fiche <code>.FLT</code> par avion de <code>SAMPLES/OPENVSP</code>) &agrave; choisir dans la liste du menu. Les instruments (anémomètre, variomètre, moteurs, post-combustion, remorquage...) s'adaptent au type d'appareil. La langue est choisie avec la variable d'environnement <code>LANGUAGE</code> (fran&ccedil;ais par d&eacute;faut, <code>EN</code>, <code>GR</code> (allemand), <code>SP</code> (espagnol), <code>IT</code>, <code>ALB</code> ou <code>SQ</code> (albanais), <code>PT</code> ou <code>PRT</code> (portugais), <code>SE</code> ou <code>SWE</code> (su&eacute;dois), <code>DK</code> ou <code>DAN</code> (danois), <code>JP</code> ou <code>JPN</code> (japonais en r&omacr;maji)). Le portugais et le japonais s'affichent sans le tilde ni les macrons, absents du jeu de caract&egrave;res de l'&eacute;cran.</td>
	</tr>
	<tr>
		<td><b>ISA.PAS</b></td>
		<td>Cette commande permet d'indiquer la pression atmosphérique.</td>
	</tr>
	<tr>
		<td><b>KM2MILES.PAS</b></td>
		<td>Cette commande permet de convertir des Km en miles.</td>
	</tr>
	<tr>
		<td><b>MILES2KM.PAS</b></td>
		<td>Cette commande permet de convertir des miles en Km.</td>
  	</tr>
	<tr>
		<td><b>MACH.PAS</b></td>
		<td>Cette commande permet de calculer la vitesse d'un avion.</td>
	</tr>
	<tr>
		<td><b>METAR.PAS</b></td>
		<td>Cette commande permet de décoder les messages météorologiques aéronautiques METAR, SPECI et TAF (vent, visibilité, RVR, temps présent, nuages, température, pression, catégorie de vol).</td>
	</tr>
	<tr>
		<td><b>NAV.PAS</b></td>
		<td>Cette commande permet de calculer la distance et les caps du grand cercle entre deux points (aérodromes ou coordonnées), une route à plusieurs segments, un point d'arrivée, avec déclinaison magnétique et correction de vent.</td>
	</tr>
	<tr>
		<td><b>MONTEE.PAS</b></td>
		<td>Cette commande permet de calculer le taux de montée, la pente de montée, les plafonds (absolu, pratique, de croisière) et le temps de montée d'un avion à hélice ou à réaction.</td>
	</tr>
	<tr>
		<td><b>OPENVSP.PAS</b></td>
		<td>Cette commande permet de lancer un clone d'OpenVSP, un modeleur paramétrique de géométrie d'avions (ailes, fuselages, pods, hélices, conduits) avec vue 3D, analyses (géométrie calculée, masse et centrage, traînée parasite, aérodynamique) et exports STL/OBJ/CSV. Sous Turbo Pascal 7, la version allégée (LITE) est compilée en raison de la limite de 64 Ko de code.</td>
	</tr>
	<tr>
    		<td><b>PLANE.PAS</b></td>
    		<td>Cette commande permet de calculer la durée du vol d'un avion entre deux villes.</td>
	</tr>
	<tr>
		<td><b>PLANEGRA.PAS</b></td>
		<td>Cette commande permet de calculer les limites du centre de gravité d'un avion à partir d'une enveloppe masse/centre de gravité au format XAML (Avionix).</td>
	</tr>
	<tr>
		<td><b>PORTANCE.PAS</b></td>
		<td>Cette commande permet de calculer la portance des ailes d'un avion.</td>
    	</tr>
	<tr>
		<td><b>SOUFFLE.PAS</b></td>
		<td>Cette commande permet de lancer un simulateur de soufflerie en aérodynamique 2D.</td>
	</tr>
	<tr>
		<td><b>TRAJECT.PAS</b></td>
		<td>Cette commande permet d'effectuer la simulation de la trajectoire d'un avion.</td>
	</tr>
	<tr>
		<td><b>VENT.PAS</b></td>
		<td>Cette commande permet de résoudre le triangle des vents (cap à tenir, dérive, vitesse sol, vent mesuré, composantes du vent sur les pistes).</td>
	</tr>
	<tr>
		<td><b>VITESSES.PAS</b></td>
		<td>Cette commande permet de convertir les vitesses aéronautiques IAS, CAS, EAS, TAS et Mach (avec température statique ou totale), de calculer l'altitude de croisement CAS/Mach, un tableau des vitesses selon l'altitude et les unités de vitesse.</td>
	</tr>
</table>

<h2>Fiches d'avions de FLIGHT.PAS</h2>

Le r&eacute;pertoire <code>SAMPLES/FLIGHT</code> contient une fiche de vol (<code>.FLT</code>) pour chacun des avions de <code>SAMPLES/OPENVSP</code> (m&ecirc;me nom de fichier : <code>C172.VSP</code> donne <code>C172.FLT</code>). Chaque fiche est un fichier texte de lignes <code>CLE=VALEUR</code> (masse, surface alaire, motorisation, trains, volets, vitesses limites, gouvernes, dimensions du mod&egrave;le 3D, etc.) qu'il est possible de modifier ou d'ajouter : <code>FLIGHT.PAS</code> en cherche la liste au d&eacute;marrage (dans <code>SAMPLES/FLIGHT</code> ou <code>../SAMPLES/FLIGHT</code>) et, si le r&eacute;pertoire est absent, utilise quatre avions int&eacute;gr&eacute;s.

<code>FLIGHT.PAS</code> accepte deux options, disponibles uniquement avec Free Pascal : <code>-maxcolors</code> utilise le nombre maximal de couleurs (couleurs vraies 24 bits : maillage des avions plus fin, normales liss&eacute;es, &eacute;clairage ambiant et solaire avec reflets sur la carrosserie et la verri&egrave;re, h&eacute;lices anim&eacute;es avec effet de flou, flamme de post-combustion, ombre port&eacute;e color&eacute;e, feux de navigation de nuit et d&eacute;grad&eacute; de ciel) et <code>-maxscreen</code> utilise la r&eacute;solution maximale disponible (la vue 3D occupe tout l'&eacute;cran, le tableau de bord reste centr&eacute; en bas). Elles se combinent : <code>FLIGHT -maxscreen -maxcolors</code>.

<p>
Sous Windows (Free Pascal, directive <code>WINDOWS</code>), avec <code>-maxcolors</code>, <code>FLIGHT.PAS</code> cherche <code>d3d9.dll</code> au d&eacute;marrage (chargement dynamique, aucune unit&eacute; ajout&eacute;e) : si la carte vid&eacute;o est significative (pilote mat&eacute;riel, shaders 2.0 ou plus, grandes textures, au moins 256 Mo de m&eacute;moire vid&eacute;o, pas de pilote logiciel ni virtuel), l'avion est dessin&eacute; par Direct3D 9 avec lissage mat&eacute;riel (multi-&eacute;chantillonnage 4x ou 2x) puis recopi&eacute; dans la vue 3D ; le nom de la carte s'affiche au menu. Sinon, aucune API propre &agrave; Windows n'est utilis&eacute;e. <code>-nogpu</code> d&eacute;sactive cette acc&eacute;l&eacute;ration, <code>-gpu</code> la force m&ecirc;me si la carte n'est pas jug&eacute;e significative. Ces deux options sont sans effet ailleurs que sous Windows.
</p>
<p>
Le menu de pause de <code>FLIGHT.PAS</code> (touche <code>Echap</code> en vol) propose, en plus de <i>Reprendre le vol</i>, <i>Menu principal</i> et <i>Quitter</i>, un <i>D&eacute;collage automatique</i> (avion au sol seulement) : roulage au cap de la piste plein gaz, rotation &agrave; la vitesse Vr, rentr&eacute;e du train et des volets puis mont&eacute;e jusqu'&agrave; 250 m au-dessus du sol (hélicopt&egrave;re : stationnaire &agrave; 45 m). Un message clignotant du tableau de bord indique que le pilote automatique d&eacute;colle, puis que le pilotage est redevenu manuel (l'avion est alors r&eacute;gl&eacute; en vol stabilis&eacute;). Toute commande de vol (manche, palonnier, manette, <code>A</code>...) reprend la main imm&eacute;diatement.
</p>


<p>
La ligne <b>M&eacute;t&eacute;o</b> du menu de <code>FLIGHT.PAS</code> propose six conditions : <i>Ensoleill&eacute;</i> (peu de nuages), <i>Nuageux</i> (plafond plus bas, brume qui r&eacute;duit la visibilit&eacute;), <i>Pluie</i> (ciel gris, tra&icirc;n&eacute;es de pluie, piste glissante donc freinage moins efficace, turbulence l&eacute;g&egrave;re), <i>Orage</i> (pluie forte, &eacute;clairs avec flash d'&eacute;cran, rafales, forte turbulence, courants ascendants et descendants), <i>Tornade</i> (entonnoir mobile dessin&eacute; au sol dont la zone d'aspiration et de rotation peut d&eacute;truire l'avion, avec avertissement &agrave; l'approche) et <i>Al&eacute;atoire</i> (une condition tir&eacute;e &agrave; chaque vol, qui change ensuite en cours de vol).
</p>

Les avions sont dessin&eacute;s en 3D &agrave; partir de la g&eacute;om&eacute;trie r&eacute;elle de <code>SAMPLES/OPENVSP/*.VSP</code> (ailes &agrave; profil NACA, fuselages arrondis, nacelles, h&eacute;lices, roues, verri&egrave;res) avec ombrage &agrave; cinq tons de gris, et un aper&ccedil;u tournant est affich&eacute; dans la liste des avions. Le niveau de d&eacute;tail du menu r&egrave;gle la finesse du maillage.

<h2>Compilation</h2>
	
Les fichiers Pascal n'ont aucune dépendances, il suffit de télécharger le fichier désiré et de le compiler avec Free Pascal avec la syntaxe de commande  :

<pre><b>fpc</b> <i>LEFICHIER.PAS</i></pre>
	
Sinon, vous pouvez également le compiler avec le Turbo Pascal à l'aide de la syntaxe de commande suivante :	

<pre><b>tpc</b> <i>LEFICHIER.PAS</i></pre>
	
Par exemple, si vous voulez compiler PLANE.PAS, vous devrez tapez la commande suivante :

<pre><b>fpc</b> PLANE.PAS</pre>

<h2>Licence</h2>
<ul>
 <li>Le code source est publié sous la licence <a href="https://github.com/gladir/AVIONIX/blob/main/LICENSE">MIT</a>.</li>
 <li>Le paquet original est publié sous la licence <a href="https://github.com/gladir/AVIONIX/blob/main/LICENSE">MIT</a>.</li>
</ul>

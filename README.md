# AVIONIX
Liste de commandes écrit en Pascal (Turbo Pascal ou Free Pascal) pour l'aviation. 

Voici un aperçu d'OpenVSP (OPENVSP.PAS) :

<img width="638" height="478" alt="image" src="https://github.com/user-attachments/assets/8bd3002b-e9c8-4593-b261-22bcbd7047be" />

Voici un aperçu de la soufflerie comme SOUFFLE.PAS (Soufflerie) :

<img width="638" height="479" alt="image" src="https://github.com/user-attachments/assets/3743114c-fac7-4b00-8142-903e68449ffa" />

<h3>Liste des fichiers</h3>

Voici la liste des différents fichiers proposés dans l'aviation :

<table>
	<tr>
		<th>Nom</th>
		<th>Description</th>
	</tr>
	<tr>
		<td><b>CAS.PAS</b></td>
		<td>Cette commande permet de calculer la vitesse anémométrique corrigée (Calibrate Airspeed).</td>
	</tr>
	<tr>
		<td><b>DECOL.PAS</b></td>
		<td>Cette commande permet d'effectuer l'estimation de la distance de décollage.</td>
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
		<td><b>OPENVSP.PAS</b></td>
		<td>Cette commande permet de lancer un clone d'OpenVSP, un modeleur paramétrique de géométrie d'avions (ailes, fuselages, pods, hélices, conduits) avec vue 3D, analyses (géométrie calculée, masse et centrage, traînée parasite, aérodynamique) et exports STL/OBJ/CSV. Sous Turbo Pascal 7, la version allégée (LITE) est compilée en raison de la limite de 64 Ko de code.</td>
	</tr>
	<tr>
    		<td><b>PLANE.PAS</b></td>
    		<td>Cette commande permet de calculer la durée du vol d'un avion entre deux villes.</td>
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
</table>

<h2>Fiches d'avions de FLIGHT.PAS</h2>

Le r&eacute;pertoire <code>SAMPLES/FLIGHT</code> contient une fiche de vol (<code>.FLT</code>) pour chacun des avions de <code>SAMPLES/OPENVSP</code> (m&ecirc;me nom de fichier : <code>C172.VSP</code> donne <code>C172.FLT</code>). Chaque fiche est un fichier texte de lignes <code>CLE=VALEUR</code> (masse, surface alaire, motorisation, trains, volets, vitesses limites, gouvernes, dimensions du mod&egrave;le 3D, etc.) qu'il est possible de modifier ou d'ajouter : <code>FLIGHT.PAS</code> en cherche la liste au d&eacute;marrage (dans <code>SAMPLES/FLIGHT</code> ou <code>../SAMPLES/FLIGHT</code>) et, si le r&eacute;pertoire est absent, utilise quatre avions int&eacute;gr&eacute;s.

<code>FLIGHT.PAS</code> accepte deux options, disponibles uniquement avec Free Pascal : <code>-maxcolors</code> utilise le nombre maximal de couleurs (couleurs vraies 24 bits : maillage des avions plus fin, normales liss&eacute;es, &eacute;clairage ambiant et solaire avec reflets sur la carrosserie et la verri&egrave;re, h&eacute;lices anim&eacute;es avec effet de flou, flamme de post-combustion, ombre port&eacute;e color&eacute;e, feux de navigation de nuit et d&eacute;grad&eacute; de ciel) et <code>-maxscreen</code> utilise la r&eacute;solution maximale disponible (la vue 3D occupe tout l'&eacute;cran, le tableau de bord reste centr&eacute; en bas). Elles se combinent : <code>FLIGHT -maxscreen -maxcolors</code>.

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

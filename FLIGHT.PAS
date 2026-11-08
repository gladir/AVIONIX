{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/avionix)
  @abstract(Target: Turbo Pascal 7, Free Pascal)
  @description: Flight - clone de Flight Simulator, un simulateur de vol
                en mode graphique (vue 3D, instruments, relief, villes,
                aeroports, nuages, vent, pilote automatique, ...).

  Langues : variable d'environnement LANGUAGE
            (aucune = francais, EN, GR, SP ou IT)

  Ligne de commande :
    FLIGHT
}

Program Flight;

{$IFDEF FPC}
 {$MODE TP}
 {$Q-}
 {$R-}
{$ENDIF}

Uses
 {$IFDEF FPC}
  Crt, PtcGraph, PtcCrt, Dos
 {$ELSE}
  Crt, Graph, Dos
 {$ENDIF};

Const
 PROG_TITLE  = 'Flight 1.00 - Avionix';

 SCR_W       = 640;           { largeur de l'ecran }
 VIEW_H      = 336;           { hauteur de la vue 3D }
 FOC0        = 520.0;         { focale de base, en pixels }
 NEAR_Z      = 1.0;           { plan de coupe proche }
 G0          = 9.80665;       { gravite }
 KT          = 1.943844;      { m/s -> noeuds }
 FT          = 3.28084;       { metres -> pieds }
 NMILE       = 1852.0;        { metres dans un mille nautique }

 NB_AIRPORT  = 4;
 NB_PLANE    = 4;           { avions integres (si SAMPLES/FLIGHT absent) }
 SLOT_CUR    = 4;           { emplacement de l'avion charge }
 MAX_AC      = 240;
 MAX_MTN     = 10;
 MAX_BLD     = 128;
 MAX_CLD     = 30;
 MAX_LAKE    = 3;
 MAX_STAR    = 60;
 MAX_OBJ     = 180;

 { Types d'objets 3D tries }
 OBJ_MTN     = 1;
 OBJ_BLD     = 2;
 OBJ_CLD     = 3;
 OBJ_PLANE   = 4;

 { Vues }
 VIEW_COCKPIT = 0;
 VIEW_CHASE   = 1;
 VIEW_TOWER   = 2;
 VIEW_MAP     = 3;

Const
 M_SUB = 1;
 M_AIRCRAFT = 2;
 M_AIRPORT = 3;
 M_START = 4;
 M_TIME = 5;
 M_WIND = 6;
 M_DETAIL = 7;
 M_ASSIST = 8;
 M_FLY = 9;
 M_QUIT = 10;
 M_HELP = 11;
 M_NAVHINT = 12;
 M_ST_RUNWAY = 13;
 M_ST_FINAL = 14;
 M_ST_CRUISE = 15;
 M_DAY = 16;
 M_NIGHT = 17;
 M_CALM = 18;
 M_LIGHT = 19;
 M_STRONG = 20;
 M_ON = 21;
 M_OFF = 22;
 M_LOW = 23;
 M_MED = 24;
 M_HIGH = 25;
 L_SPEED = 26;
 L_ALT = 27;
 L_HDG = 28;
 L_VS = 29;
 L_THR = 30;
 L_FUEL = 31;
 L_GEAR = 32;
 L_FLAPS = 33;
 L_BRAKE = 34;
 L_AP = 35;
 L_STAB = 36;
 L_DEST = 37;
 L_DIST = 38;
 V_COCKPIT = 39;
 V_CHASE = 40;
 V_TOWER = 41;
 V_MAP = 42;
 W_STALL = 43;
 W_PULLUP = 44;
 W_GEAR = 45;
 W_OVERSPD = 46;
 W_OVERG = 47;
 W_NOFUEL = 48;
 W_PARK = 49;
 W_PAUSE = 50;
 W_TAIL = 51;
 W_APON = 52;
 W_APOFF = 53;
 C_TITLE = 54;
 C_TERRAIN = 55;
 C_BUILDING = 56;
 C_WATER = 57;
 C_HARD = 58;
 C_WING = 59;
 C_NOSE = 60;
 C_OVERG = 61;
 C_OVERSPD = 62;
 C_BELLY = 63;
 C_AGAIN = 64;
 T_TD = 65;
 T_EXCEL = 66;
 T_GOOD = 67;
 T_FIRM = 68;
 T_HARD = 69;
 T_OFF = 70;
 T_ONRWY = 71;
 T_STOP = 72;
 H_TITLE = 73;
 H_1 = 74;
 H_2 = 75;
 H_3 = 76;
 H_4 = 77;
 H_5 = 78;
 H_6 = 79;
 H_7 = 80;
 H_8 = 81;
 H_9 = 82;
 H_ANY = 83;
 P_RESUME = 84;
 P_MENU = 85;
 L_AB = 86;
 L_STAM = 87;
 L_TOW = 88;
 W_TOWREL = 89;
 T_WATER = 90;
 C_HULL = 91;
 K_P = 92;
 K_T = 93;
 K_J = 94;
 K_A = 95;
 K_R = 96;
 K_U = 97;
 K_G = 98;
 K_H = 99;
 K_C = 100;
 D_ENG = 101;
 D_VMAX = 102;
 D_MASS = 103;
 D_SPAN = 104;
 D_LEN = 105;
 D_YEAR = 106;
 D_SELHINT = 107;
 M_ACLIST = 108;
 NB_MSG = 108;

Const
 Msgs : Array[1..NB_MSG] Of Array[0..4] Of String[58] = (
  ('Simulateur de vol',
   'Flight simulator',
   'Flugsimulator',
   'Simulador de vuelo',
   'Simulatore di volo'),
  ('Avion',
   'Aircraft',
   'Flugzeug',
   'Avi~3n',
   'Aereo'),
  ('A~eroport',
   'Airport',
   'Flughafen',
   'Aeropuerto',
   'Aeroporto'),
  ('D~epart',
   'Start',
   'Start',
   'Inicio',
   'Partenza'),
  ('Heure',
   'Time of day',
   'Tageszeit',
   'Hora',
   'Ora'),
  ('Vent',
   'Wind',
   'Wind',
   'Viento',
   'Vento'),
  ('D~etail du d~ecor',
   'Scenery detail',
   'Szenerie',
   'Detalle',
   'Dettaglio'),
  ('Stabilisateur',
   'Stabilizer',
   'Stabilisator',
   'Estabilizador',
   'Stabilizzatore'),
  ('Commencer le vol',
   'Start flying',
   'Flug beginnen',
   'Empezar a volar',
   'Inizia il volo'),
  ('Quitter',
   'Quit',
   'Beenden',
   'Salir',
   'Esci'),
  ('F1 : aide',
   'F1 : help',
   'F1 : Hilfe',
   'F1 : ayuda',
   'F1 : aiuto'),
  ('Haut/Bas : choisir  G/D : changer  Entr~ee : voler',
   'Up/Down : select  L/R : change  Enter : fly',
   'Auf/Ab : w~Ahlen  L/R : ~Andern  Enter : fliegen',
   'Arriba/Abajo : elegir  I/D : cambiar  Intro : volar',
   'Su/Gi~v : scegli  Sx/Dx : cambia  Invio : vola'),
  ('Sur la piste',
   'On the runway',
   'Auf der Piste',
   'En la pista',
   'In pista'),
  ('Approche finale',
   'Final approach',
   'Endanflug',
   'Aproximaci~3n final',
   'Avvicinamento finale'),
  ('En croisi~gre',
   'Cruising',
   'Reiseflug',
   'En crucero',
   'In crociera'),
  ('Jour',
   'Day',
   'Tag',
   'D~2a',
   'Giorno'),
  ('Nuit',
   'Night',
   'Nacht',
   'Noche',
   'Notte'),
  ('Calme',
   'Calm',
   'Windstill',
   'Calma',
   'Calmo'),
  ('L~eger',
   'Light',
   'Leicht',
   'Ligero',
   'Leggero'),
  ('Fort',
   'Strong',
   'Stark',
   'Fuerte',
   'Forte'),
  ('Oui',
   'On',
   'Ein',
   'S~2',
   'S~I'),
  ('Non',
   'Off',
   'Aus',
   'No',
   'No'),
  ('Bas',
   'Low',
   'Niedrig',
   'Bajo',
   'Basso'),
  ('Moyen',
   'Medium',
   'Mittel',
   'Medio',
   'Medio'),
  ('~Elev~e',
   'High',
   'Hoch',
   'Alto',
   'Alto'),
  ('VITESSE',
   'AIRSPEED',
   'FAHRT',
   'VELOC.',
   'VELOC.'),
  ('ALTITUDE',
   'ALTITUDE',
   'H~PHE',
   'ALTITUD',
   'QUOTA'),
  ('CAP',
   'HEADING',
   'KURS',
   'RUMBO',
   'ROTTA'),
  ('V.VERT',
   'V/S',
   'STEIGEN',
   'V.VERT',
   'V.VERT'),
  ('GAZ',
   'THR',
   'SCHUB',
   'GAS',
   'GAS'),
  ('CARB',
   'FUEL',
   'KRAFT',
   'COMB',
   'CARB'),
  ('TRAIN',
   'GEAR',
   'FAHRW',
   'TREN',
   'CARR.'),
  ('VOLETS',
   'FLAPS',
   'KLAPP',
   'FLAPS',
   'FLAP'),
  ('FREINS',
   'BRAKES',
   'BREMS',
   'FRENOS',
   'FRENI'),
  ('PA',
   'AP',
   'AP',
   'PA',
   'AP'),
  ('STAB',
   'STAB',
   'STAB',
   'ESTAB',
   'STAB'),
  ('DEST',
   'DEST',
   'ZIEL',
   'DEST',
   'DEST'),
  ('DIST',
   'DIST',
   'DIST',
   'DIST',
   'DIST'),
  ('Cockpit',
   'Cockpit',
   'Cockpit',
   'Cabina',
   'Cabina'),
  ('Externe',
   'Chase',
   'Extern',
   'Externa',
   'Esterna'),
  ('Tour',
   'Tower',
   'Turm',
   'Torre',
   'Torre'),
  ('Carte',
   'Map',
   'Karte',
   'Mapa',
   'Mappa'),
  ('D~ECROCHAGE !',
   'STALL !',
   '~DBERZIEHEN !',
   '~!P~ERDIDA !',
   'STALLO !'),
  ('TERRAIN ! CABREZ !',
   'TERRAIN ! PULL UP !',
   'GEL~QNDE ! HOCHZIEHEN !',
   '~!TERRENO ! ~!ARRIBA !',
   'TERRENO ! TIRA SU !'),
  ('SORTEZ LE TRAIN !',
   'GEAR DOWN !',
   'FAHRWERK AUSFAHREN !',
   '~!SAQUE EL TREN !',
   'ESTRAI IL CARRELLO !'),
  ('SURVITESSE !',
   'OVERSPEED !',
   'ZU SCHNELL !',
   '~!EXCESO DE VELOCIDAD !',
   'VELOCIT~a ECCESSIVA !'),
  ('FACTEUR DE CHARGE !',
   'OVER-G !',
   'ZU VIELE G !',
   '~!EXCESO DE G !',
   'TROPPI G !'),
  ('PLUS DE CARBURANT !',
   'OUT OF FUEL !',
   'KRAFTSTOFF LEER !',
   '~!SIN COMBUSTIBLE !',
   'CARBURANTE ESAURITO !'),
  ('Frein de parc : rel~bchez avec B',
   'Parking brake : release with B',
   'Feststellbremse : l~Osen mit B',
   'Freno de estacionamiento : B',
   'Freno di stazionamento : B'),
  ('PAUSE',
   'PAUSE',
   'PAUSE',
   'PAUSA',
   'PAUSA'),
  ('QUEUE AU SOL !',
   'TAIL STRIKE !',
   'HECKKONTAKT !',
   '~!GOLPE DE COLA !',
   'COLPO DI CODA !'),
  ('PILOTE AUTO ACTIV~E',
   'AUTOPILOT ON',
   'AUTOPILOT EIN',
   'PILOTO AUTOMATICO',
   'PILOTA AUTOMATICO'),
  ('PILOTE AUTO COUP~E',
   'AUTOPILOT OFF',
   'AUTOPILOT AUS',
   'PILOTO AUT. APAGADO',
   'PILOTA AUT. SPENTO'),
  ('ACCIDENT !',
   'CRASH !',
   'ABSTURZ !',
   '~!ACCIDENTE !',
   'INCIDENTE !'),
  ('Collision avec le relief',
   'You hit the terrain',
   'Aufprall auf das Gel~Ande',
   'Colisi~3n con el terreno',
   'Impatto col terreno'),
  ('Collision avec un b~btiment',
   'You hit a building',
   'Kollision mit einem Geb~Aude',
   'Colisi~3n con un edificio',
   'Collisione con un edificio'),
  ('Chute dans l''eau',
   'You crashed into the water',
   'Absturz ins Wasser',
   'Ca~2da al agua',
   'Caduta in acqua'),
  ('Atterrissage trop brutal',
   'Landing too hard',
   'Zu harte Landung',
   'Aterrizaje muy duro',
   'Atterraggio troppo duro'),
  ('Une aile a touch~e le sol',
   'A wing hit the ground',
   'Die Tragfl~Ache ber~Uhrte den Boden',
   'Un ala toc~3 el suelo',
   'Un''ala ha toccato il suolo'),
  ('Le nez a touch~e le sol',
   'The nose hit the ground',
   'Die Nase ber~Uhrte den Boden',
   'El morro toc~3 el suelo',
   'Il muso ha toccato il suolo'),
  ('Structure rompue (facteur de charge)',
   'Airframe broke up (G)',
   'Zelle zerbrochen (G-Kr~Afte)',
   'Estructura rota (G)',
   'Struttura spezzata (G)'),
  ('Structure rompue (vitesse)',
   'Airframe broke up (speed)',
   'Zelle zerbrochen (Geschwindigkeit)',
   'Estructura rota (velocidad)',
   'Struttura spezzata (velocit~a)'),
  ('Train rentr~e : atterrissage sur le ventre',
   'Gear up : belly landing',
   'Fahrwerk oben : Bauchlandung',
   'Sin tren : aterrizaje de panza',
   'Senza carrello : atterraggio di pancia'),
  ('R : recommencer   ESC : menu',
   'R : restart   ESC : menu',
   'R : neu starten   ESC : Men~U',
   'R : reiniciar   ESC : men~4',
   'R : riprova   ESC : menu'),
  ('Pose',
   'Touchdown',
   'Aufsetzen',
   'Toma de contacto',
   'Contatto'),
  ('Excellent',
   'Excellent',
   'Ausgezeichnet',
   'Excelente',
   'Eccellente'),
  ('Bon',
   'Good',
   'Gut',
   'Bien',
   'Buono'),
  ('Ferme',
   'Firm',
   'Hart',
   'Firme',
   'Deciso'),
  ('Brutal',
   'Hard',
   'Sehr hart',
   'Duro',
   'Duro'),
  ('hors piste',
   'off runway',
   'neben der Piste',
   'fuera de pista',
   'fuori pista'),
  ('sur la piste',
   'on runway',
   'auf der Piste',
   'en pista',
   'in pista'),
  ('Avion immobilis~e',
   'Aircraft stopped',
   'Flugzeug steht',
   'Avi~3n detenido',
   'Aereo fermo'),
  ('Commandes',
   'Controls',
   'Steuerung',
   'Controles',
   'Comandi'),
  ('Fl~gches : manche (haut = piquer, bas = cabrer)',
   'Arrows : stick (up = nose down, down = nose up)',
   'Pfeile : Steuer (oben = dr~Ucken, unten = ziehen)',
   'Flechas : palanca (arriba = picar, abajo = cabrar)',
   'Frecce : barra (su = picchiare, gi~v = cabrare)'),
  ('Z / X : palonnier gauche / droit',
   'Z / X : rudder left / right',
   'Z / X : Seitenruder links / rechts',
   'Z / X : tim~3n izquierda / derecha',
   'Z / X : timone sinistra / destra'),
  ('+ / - PgUp / PgDn : gaz   Home / End : max / ralenti',
   '+ / - PgUp / PgDn : throttle   Home / End : max / idle',
   '+ / - PgUp / PgDn : Schub   Pos1 / Ende : max / Leerlauf',
   '+ / - PgUp / PgDn : gas   Inicio / Fin : m~1x / ralent~2',
   '+ / - PgUp / PgDn : gas   Home / Fine : max / minimo'),
  ('F / D : volets sortis / rentr~es',
   'F / D : flaps down / up',
   'F / D : Klappen aus / ein',
   'F / D : flaps abajo / arriba',
   'F / D : flap fuori / dentro'),
  ('G : train   B : freins   Espace : centrer les commandes',
   'G : gear   B : brakes   Space : center the controls',
   'G : Fahrwerk   B : Bremsen   Leertaste : zentrieren',
   'G : tren   B : frenos   Espacio : centrar mandos',
   'G : carrello   B : freni   Spazio : centra i comandi'),
  ('V : vue   M : carte   TAB : a~eroport de destination',
   'V : view   M : map   TAB : destination airport',
   'V : Ansicht   M : Karte   TAB : Zielflughafen',
   'V : vista   M : mapa   TAB : aeropuerto de destino',
   'V : vista   M : mappa   TAB : aeroporto di destinazione'),
  ('A : pilote auto (fl~gches = cap / altitude)',
   'A : autopilot (arrows = heading / altitude)',
   'A : Autopilot (Pfeile = Kurs / H~Ohe)',
   'A : piloto autom~1tico (flechas = rumbo / altitud)',
   'A : pilota automatico (frecce = rotta / quota)'),
  ('S : stabilisateur   N : jour / nuit   P : pause',
   'S : stabilizer   N : day / night   P : pause',
   'S : Stabilisator   N : Tag / Nacht   P : Pause',
   'S : estabilizador   N : d~2a / noche   P : pausa',
   'S : stabilizzatore   N : giorno / notte   P : pausa'),
  ('ESC : menu',
   'ESC : menu',
   'ESC : Men~U',
   'ESC : men~4',
   'ESC : menu'),
  ('Appuyez sur une touche',
   'Press any key',
   'Beliebige Taste dr~Ucken',
   'Pulse una tecla',
   'Premi un tasto'),
  ('Reprendre le vol',
   'Resume flight',
   'Flug fortsetzen',
   'Reanudar el vuelo',
   'Riprendi il volo'),
  ('Menu principal',
   'Main menu',
   'Hauptmen~U',
   'Men~4 principal',
   'Menu principale'),
  ('PC',
   'A/B',
   'NB',
   'PC',
   'PC'),
  ('ENDU',
   'STAM',
   'AUSD',
   'ENDU',
   'ENDU'),
  ('REMORQ',
   'TOW',
   'SCHLEP',
   'REMOLQ',
   'TRAINO'),
  ('REMORQUEUR LARGU~E',
   'TOW RELEASED',
   'SCHLEPP GEL~PST',
   'REMOLCADOR SUELTO',
   'TRAINO RILASCIATO'),
  ('sur l''eau',
   'on water',
   'auf dem Wasser',
   'en el agua',
   'sull''acqua'),
  ('Hydravion sur terre : glissade sur la coque',
   'Flying boat on land : sliding on the hull',
   'Flugboot an Land : Rutschen auf dem Rumpf',
   'Hidroavi~3n en tierra : deslizando sobre el casco',
   'Idrovolante a terra : scivola sullo scafo'),
  ('Moteur ~a pistons',
   'Piston engine',
   'Kolbenmotor',
   'Motor de pistones',
   'Motore a pistoni'),
  ('Turbopropulseur',
   'Turboprop',
   'Turboprop',
   'Turboh~elice',
   'Turboelica'),
  ('R~eacteur',
   'Jet engine',
   'Strahltriebwerk',
   'Reactor',
   'Reattore'),
  ('R~eacteur ~a postcombustion',
   'Afterburning jet',
   'Triebwerk mit Nachbrenner',
   'Reactor con poscombusti~3n',
   'Reattore con postbruciatore'),
  ('Moteur-fus~ee',
   'Rocket engine',
   'Raketenantrieb',
   'Motor cohete',
   'Motore a razzo'),
  ('Pulsor~eacteur',
   'Pulsejet',
   'Pulsstrahltriebwerk',
   'Pulsorreactor',
   'Pulsoreattore'),
  ('Planeur',
   'Glider',
   'Segelflugzeug',
   'Planeador',
   'Aliante'),
  ('Propulsion humaine',
   'Human powered',
   'Muskelkraft',
   'Propulsi~3n humana',
   'Propulsione umana'),
  ('H~elicopt~gre',
   'Helicopter',
   'Hubschrauber',
   'Helic~3ptero',
   'Elicottero'),
  ('Moteurs',
   'Engines',
   'Triebwerke',
   'Motores',
   'Motori'),
  ('Vitesse max.',
   'Max speed',
   'H~Ochstgeschw.',
   'Veloc. m~1x.',
   'Veloc. max.'),
  ('Masse max.',
   'Max weight',
   'Max. Gewicht',
   'Masa m~1x.',
   'Massa max.'),
  ('Envergure',
   'Wingspan',
   'Spannweite',
   'Envergadura',
   'Apertura'),
  ('Longueur',
   'Length',
   'L~Ange',
   'Longitud',
   'Lunghezza'),
  ('Ann~ee',
   'Year',
   'Jahr',
   'A~no',
   'Anno'),
  ('Haut/Bas/PgUp/PgDn : choisir  Entr~ee : OK  Esc : sortir',
   'Up/Down/PgUp/PgDn : select  Enter : OK  Esc : cancel',
   'Auf/Ab/BildAuf/Ab : w~Ahlen  Enter : OK  Esc : Abbruch',
   'Flechas/ReP~1g/AvP~1g : elegir  Intro : OK  Esc : salir',
   'Su/Gi~v/PgSu/PgGi~v : scegli  Invio : OK  Esc : annulla'),
  ('Entr~ee : liste des avions',
   'Enter : aircraft list',
   'Enter : Flugzeugliste',
   'Intro : lista de aviones',
   'Invio : elenco aerei')
 );

Type
 TVec = Record
  X, Y, Z : Real;
 End;

 TPt2 = Record
  X, Y : Real;
 End;

 TPoly3 = Array[0..15] Of TVec;
 TPoly2 = Array[0..39] Of TPt2;

 TCam = Record
  P, F, R, U : TVec;       { position et axes (avant, droite, haut) }
  Foc        : Real;
  CX, CY     : Real;
 End;

 TSpec = Record
  Name      : String[40];
  Id        : String[10];
  Desc      : String[110];
  Cat       : Char;      { P T J A R U G H C (voir LoadSpecFile) }
  NEng      : Integer;   { nombre de moteurs }
  Year      : Integer;
  MTow      : Real;      { masse maximale, kg }
  VMaxKmh   : Real;
  Jet       : Boolean;
  Retract   : Boolean;
  HasFlaps  : Boolean;
  Float     : Boolean;   { hydravion ou ecranoplan }
  Amph      : Boolean;   { amphibie }
  Ab        : Boolean;   { post-combustion }
  Tow       : Boolean;   { planeur remorque }
  Delta     : Boolean;
  HighWing  : Boolean;
  Wings     : Integer;
  Sweep     : Real;      { fleche, degres }
  Empty     : Real;      { masse a vide + charge utile, kg }
  FuelCap   : Real;      { capacite en carburant, kg }
  FuelFrac  : Real;      { fraction de carburant au depart }
  FuelFlow  : Real;      { debit maximal, kg/s }
  S         : Real;      { surface alaire, m2 }
  CD0, K    : Real;      { trainee parasite et induite }
  CLa       : Real;      { pente de portance, par radian }
  Alpha0    : Real;      { incidence de portance nulle }
  NegK      : Real;      { rapport CLmax negatif / positif }
  CLmax     : Real;
  CLmaxF    : Real;      { CLmax volets sortis }
  CDFlap    : Real;
  CDGear    : Real;
  McritW    : Real;      { Mach critique (trainee d'onde) }
  WaveK     : Real;      { amplitude de la trainee d'onde }
  GroundFx  : Real;      { effet de sol }
  CritAlt   : Real;      { altitude de rapidite du moteur, m }
  Pwr       : Real;      { puissance de l'helice, W }
  Tstat     : Real;      { poussee statique, N }
  SpoolT    : Real;      { temps de reponse du moteur, s }
  MachK     : Real;      { perte de poussee avec le Mach }
  Boost     : Real;      { poussee d'aide au lancement, N }
  BoostV    : Real;      { vitesse de fin de l'aide, m/s }
  PMax      : Real;      { taux de roulis maximal, rad/s }
  Kq, Ks    : Real;      { gain de profondeur, stabilite }
  Kw, Krud  : Real;      { girouette, gouverne de direction }
  AlphaTrim : Real;
  Vref      : Real;      { vitesse de reference des gouvernes }
  NLim      : Real;      { facteur de charge limite }
  CrashVS   : Real;      { vitesse verticale d'impact maximale }
  MaxBank   : Real;      { inclinaison maximale au sol }
  TailAng   : Real;      { angle de garde au sol }
  BrakeMu   : Real;
  GearH     : Real;      { hauteur CG - roues }
  EyeF, EyeU: Real;      { position des yeux du pilote }
  Vne       : Real;      { vitesse limite, m/s }
  VsMax     : Real;      { vitesse verticale max du pilote auto }
  VDial     : Integer;   { echelle de l'anemometre, noeuds }
  VSScale   : Integer;   { echelle du variometre, ft/min }
  Len, Span : Real;      { dimensions du modele 3D }
  Col1, Col2: Integer;
 End;

 TAirport = Record
  Name  : String[22];
  Code  : String[4];
  X, Y  : Real;
  AxisX : Boolean;         { piste orientee Est-Ouest }
  Len   : Real;
  Wid   : Real;
 End;

 TMtn = Record
  X, Y, R, H : Real;
 End;

 TBld = Record
  X, Y, W, D : Real;       { centre et dimensions }
  Z0, H      : Real;       { base et hauteur }
  Col, Roof  : Integer;
 End;

 TCld = Record
  X, Y, Z, R : Real;
 End;

 TLake = Record
  X, Y, RX, RY : Real;
 End;

 TFlt = Record
  P, V       : TVec;       { position et vitesse sol }
  F, R, U    : TVec;       { axes de l'avion }
  Elev, Ail  : Real;
  Rud, Thr   : Real;
  Spool      : Real;       { regime moteur }
  Flaps      : Integer;
  GearPos    : Real;
  GearDn     : Boolean;
  Brakes     : Boolean;
  Fuel       : Real;
  OnGround   : Boolean;
  Air        : Boolean;    { a deja decolle }
  Crashed    : Boolean;
  Belly      : Boolean;
  CrashMsg   : Integer;
  CrashT     : Real;
  AP         : Boolean;
  APHdg      : Real;
  APAlt      : Real;
  APSpd      : Real;
  Assist     : Boolean;
  Alpha      : Real;
  Beta       : Real;
  GLoad      : Real;
  Mach       : Real;
  IAS        : Real;
  Stalled    : Boolean;
  Spec       : Integer;
  FlightT    : Real;
  TowDone    : Boolean;
 End;

Var
 { Langue : 0=FR 1=EN 2=GR 3=SP 4=IT }
 Lang       : Integer;

 Specs      : Array[0..NB_PLANE] Of TSpec;   { +1 : avion charge }

 { Liste des avions : fiches .FLT du repertoire SAMPLES/FLIGHT }
 AcFile     : Array[0..MAX_AC-1] Of String[8];
 NAc        : Integer;
 AcDir      : String;
 Aps        : Array[0..NB_AIRPORT-1] Of TAirport;
 Mtns       : Array[0..MAX_MTN-1] Of TMtn;
 Blds       : Array[0..MAX_BLD-1] Of TBld;
 NBld       : Integer;
 Clds       : Array[0..MAX_CLD-1] Of TCld;
 Lakes      : Array[0..MAX_LAKE-1] Of TLake;
 Stars      : Array[0..MAX_STAR-1] Of TVec;

 Fl         : TFlt;
 Cam        : TCam;
 Wind       : TVec;
 Sun        : TVec;

 { Options du menu }
 OptPlane   : Integer;
 OptAirport : Integer;
 OptStart   : Integer;
 OptNight   : Integer;
 OptWind    : Integer;
 OptDetail  : Integer;
 OptAssist  : Integer;

 ViewMode   : Integer;
 Night      : Boolean;
 Paused     : Boolean;
 DestAp     : Integer;
 MapZoom    : Real;
 InCloud    : Boolean;
 FrameNo    : LongInt;

 { Message affiche a l'ecran }
 MsgText    : String;
 MsgTime    : Real;
 MsgColor   : Integer;

 { Clipping de l'affichage }
 VX1, VY1, VX2, VY2 : Integer;
 ClipA, ClipB       : TPoly2;

 { Liste d'objets a trier }
 ObjKind    : Array[0..MAX_OBJ-1] Of Byte;
 ObjIdx     : Array[0..MAX_OBJ-1] Of Integer;
 ObjDist    : Array[0..MAX_OBJ-1] Of Real;
 NObj       : Integer;

 { Cache des instruments }
 InstKey    : Array[0..15] Of LongInt;

 { Etat du son }
 SoundOn    : Boolean;
 TouchedDown: Boolean;
 StopShown  : Boolean;

{ ------------------------------------------------------------------ }
{ Utilitaires                                                        }
{ ------------------------------------------------------------------ }

Function IntStr(N:LongInt):String;
Var
 S:String;
Begin
 Str(N,S);
 IntStr:=S;
End;

Function RealStr(R:Real;D:Integer):String;
Var
 S:String;
Begin
 Str(R:0:D,S);
 RealStr:=S;
End;

Function PadL(S:String;W:Integer):String;
Begin
 While Length(S)<W do S:=' '+S;
 PadL:=S;
End;

Function PadZ(N:LongInt;W:Integer):String;
Var
 S:String;
Begin
 Str(N,S);
 While Length(S)<W do S:='0'+S;
 PadZ:=S;
End;

Function UpStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S) do S[I]:=UpCase(S[I]);
 UpStr:=S;
End;

Function MinR(A,B:Real):Real;
Begin
 If A<B Then MinR:=A Else MinR:=B;
End;

Function MaxR(A,B:Real):Real;
Begin
 If A>B Then MaxR:=A Else MaxR:=B;
End;

Function Clamp(X,A,B:Real):Real;
Begin
 If X<A Then Clamp:=A Else If X>B Then Clamp:=B Else Clamp:=X;
End;

Function Sgn(X:Real):Real;
Begin
 If X<0.0 Then Sgn:=-1.0 Else Sgn:=1.0;
End;

Function ArcSin(X:Real):Real;
Begin
 If X>=1.0 Then ArcSin:=Pi/2.0 Else
 If X<=-1.0 Then ArcSin:=-Pi/2.0
            Else ArcSin:=ArcTan(X/Sqrt(1.0-X*X));
End;

Function ATan2(Y,X:Real):Real;
Begin
 If X>0.0 Then ATan2:=ArcTan(Y/X) Else
 If X<0.0 Then Begin
  If Y>=0.0 Then ATan2:=ArcTan(Y/X)+Pi
            Else ATan2:=ArcTan(Y/X)-Pi;
 End
  Else Begin
   If Y>0.0 Then ATan2:=Pi/2.0 Else
   If Y<0.0 Then ATan2:=-Pi/2.0
            Else ATan2:=0.0;
  End;
End;

Function Tan(X:Real):Real;
Begin
 Tan:=Sin(X)/Cos(X);
End;

Function WrapPi(A:Real):Real;
Begin
 While A>Pi do A:=A-2.0*Pi;
 While A<-Pi do A:=A+2.0*Pi;
 WrapPi:=A;
End;

Function RandR:Real;
Begin
 RandR:=Random(10000)/10000.0;
End;

Function NowSec:Real;
Var
 H,M,S,S100:Word;
Begin
 GetTime(H,M,S,S100);
 NowSec:=H*3600.0+M*60.0+S+S100/100.0;
End;

{ Densite de l'air (atmosphere standard) }
Function Density(H:Real):Real;
Begin
 If H<0.0 Then H:=0.0;
 If H>20000.0 Then H:=20000.0;
 Density:=1.225*Exp(4.2559*Ln(1.0-2.25577E-5*H));
End;

Function SoundSpeed(H:Real):Real;
Var
 T:Real;
Begin
 If H<0.0 Then H:=0.0;
 If H>11000.0 Then H:=11000.0;
 T:=288.15-0.0065*H;
 SoundSpeed:=340.29*Sqrt(T/288.15);
End;

{ ------------------------------------------------------------------ }
{ Traduction                                                         }
{ ------------------------------------------------------------------ }


{ Decode les accents ecrits '~x' en caracteres CP437 }
Function Accent(C:Char):Char;
Begin
 Case C of
  'e':Accent:=#130;  'g':Accent:=#138;  'h':Accent:=#136;
  'a':Accent:=#133;  'b':Accent:=#131;  'c':Accent:=#135;
  'o':Accent:=#147;  'i':Accent:=#140;  'j':Accent:=#139;
  'u':Accent:=#150;  'v':Accent:=#151;  'k':Accent:=#137;
  'E':Accent:=#144;  'U':Accent:=#129;  'O':Accent:=#148;
  'A':Accent:=#132;  'S':Accent:=#225;  'n':Accent:=#164;
  '1':Accent:=#160;  '2':Accent:=#161;  '3':Accent:=#162;
  '4':Accent:=#163;  '?':Accent:=#168;  '!':Accent:=#173;
  'D':Accent:=#154;  'P':Accent:=#153;  'Q':Accent:=#142;
  'd':Accent:=#248;  'I':Accent:=#141;
  Else Accent:=C;
 End;
End;

Function Tr(Id:Integer):String;
Var
 S,R:String;
 I:Integer;
Begin
 S:=Msgs[Id][Lang];
 R:='';
 I:=1;
 While I<=Length(S) do Begin
  If(S[I]='~')and(I<Length(S))Then Begin
   Inc(I);
   R:=R+Accent(S[I]);
  End
   Else
  R:=R+S[I];
  Inc(I);
 End;
 Tr:=R;
End;

Procedure DetectLanguage;
Var
 S:String;
Begin
 S:=UpStr(Copy(GetEnv('LANGUAGE'),1,2));
 Lang:=0;
 If S='EN' Then Lang:=1 Else
 If(S='GR')or(S='DE')Then Lang:=2 Else
 If(S='SP')or(S='ES')Then Lang:=3 Else
 If S='IT' Then Lang:=4;
End;

{ ------------------------------------------------------------------ }
{ Mathematiques vectorielles                                         }
{ ------------------------------------------------------------------ }

Function Dot(Const A,B:TVec):Real;
Begin
 Dot:=A.X*B.X+A.Y*B.Y+A.Z*B.Z;
End;

Procedure VSet(Var A:TVec;X,Y,Z:Real);
Begin
 A.X:=X; A.Y:=Y; A.Z:=Z;
End;

Procedure VNormalize(Var A:TVec);
Var
 L:Real;
Begin
 L:=Sqrt(A.X*A.X+A.Y*A.Y+A.Z*A.Z);
 If L>1E-9 Then Begin
  A.X:=A.X/L; A.Y:=A.Y/L; A.Z:=A.Z/L;
 End;
End;

Procedure VCross(Const A,B:TVec;Var C:TVec);
Var
 T:TVec;
Begin
 T.X:=A.Y*B.Z-A.Z*B.Y;
 T.Y:=A.Z*B.X-A.X*B.Z;
 T.Z:=A.X*B.Y-A.Y*B.X;
 C:=T;
End;

Procedure Orthonormalize(Var F,R,U:TVec);
Var
 D:Real;
Begin
 VNormalize(F);
 D:=Dot(R,F);
 R.X:=R.X-D*F.X; R.Y:=R.Y-D*F.Y; R.Z:=R.Z-D*F.Z;
 VNormalize(R);
 VCross(R,F,U);
End;

{ Axes de l'avion a partir du cap, de l'assiette et de l'inclinaison }
Procedure EulerToAxes(Psi,Th,Ph:Real;Var F,R,U:TVec);
Var
 SP,CP,ST,CT,SR,CR:Real;
 R0,U0:TVec;
Begin
 SP:=Sin(Psi); CP:=Cos(Psi);
 ST:=Sin(Th);  CT:=Cos(Th);
 SR:=Sin(Ph);  CR:=Cos(Ph);
 F.X:=SP*CT; F.Y:=CP*CT; F.Z:=ST;
 R0.X:=CP; R0.Y:=-SP; R0.Z:=0.0;
 VCross(R0,F,U0);
 R.X:=R0.X*CR-U0.X*SR;
 R.Y:=R0.Y*CR-U0.Y*SR;
 R.Z:=R0.Z*CR-U0.Z*SR;
 U.X:=U0.X*CR+R0.X*SR;
 U.Y:=U0.Y*CR+R0.Y*SR;
 U.Z:=U0.Z*CR+R0.Z*SR;
End;

Procedure AxesToEuler(Const F,R,U:TVec;Var Psi,Th,Ph:Real);
Begin
 Psi:=ATan2(F.X,F.Y);
 Th:=ArcSin(F.Z);
 Ph:=ATan2(-R.Z,U.Z);
End;

{ Cap en degres (0..359) }
Function HeadingDeg(Const F:TVec):Real;
Var
 H:Real;
Begin
 H:=ATan2(F.X,F.Y)*180.0/Pi;
 If H<0.0 Then H:=H+360.0;
 HeadingDeg:=H;
End;

{ ------------------------------------------------------------------ }
{ Description des avions                                             }
{ ------------------------------------------------------------------ }

Procedure InitSpecs;
Begin
 FillChar(Specs,SizeOf(Specs),0);

 With Specs[0] Do Begin
  Name:='Cessna 172 Skyhawk';
  Id:='C172'; Cat:='P'; NEng:=1; Wings:=1; HighWing:=True; Year:=1956;
  MTow:=1100.0; VMaxKmh:=226.0; WaveK:=0.5; GroundFx:=0.12; VSScale:=2000;
  Desc:='Avion de tourisme quadriplace (modele integre)';
  Jet:=False; Retract:=False; HasFlaps:=True;
  Empty:=830.0; FuelCap:=130.0; FuelFrac:=1.0; FuelFlow:=0.0075;
  S:=16.2; CD0:=0.031; K:=0.055; CLa:=4.8; Alpha0:=-0.05; NegK:=0.7;
  CLmax:=1.55; CLmaxF:=2.1; CDFlap:=0.05; CDGear:=0.0; McritW:=0.6;
  Pwr:=110000.0; Tstat:=2400.0; SpoolT:=0.6; MachK:=0.0;
  PMax:=0.8; Kq:=0.55; Ks:=2.2; Kw:=1.6; Krud:=0.35;
  AlphaTrim:=0.05; Vref:=35.0;
  NLim:=3.8; CrashVS:=5.0; MaxBank:=0.35; TailAng:=0.22; BrakeMu:=0.45;
  GearH:=1.1; EyeF:=0.3; EyeU:=0.8;
  Vne:=84.0; VsMax:=4.0; VDial:=200;
  Len:=8.3; Span:=11.0; Col1:=White; Col2:=Red;
 End;

 With Specs[1] Do Begin
  Name:='Pitts Special S-2B';
  Id:='S2B'; Cat:='P'; NEng:=1; Wings:=2; Year:=1983;
  MTow:=615.0; VMaxKmh:=250.0; WaveK:=0.5; GroundFx:=0.12; VSScale:=2000;
  Desc:='Biplan acrobatique (modele integre)';
  Jet:=False; Retract:=False; HasFlaps:=False;
  Empty:=560.0; FuelCap:=55.0; FuelFrac:=1.0; FuelFlow:=0.011;
  S:=11.5; CD0:=0.045; K:=0.075; CLa:=4.3; Alpha0:=0.0; NegK:=1.0;
  CLmax:=1.5; CLmaxF:=1.5; CDFlap:=0.0; CDGear:=0.0; McritW:=0.6;
  Pwr:=150000.0; Tstat:=3300.0; SpoolT:=0.4; MachK:=0.0;
  PMax:=3.5; Kq:=1.0; Ks:=3.0; Kw:=2.0; Krud:=0.5;
  AlphaTrim:=0.06; Vref:=40.0;
  NLim:=6.0; CrashVS:=4.5; MaxBank:=0.3; TailAng:=0.25; BrakeMu:=0.4;
  GearH:=1.0; EyeF:=0.2; EyeU:=0.8;
  Vne:=90.0; VsMax:=6.0; VDial:=220;
  Len:=6.1; Span:=6.1; Col1:=Yellow; Col2:=Red;
 End;

 With Specs[2] Do Begin
  Name:='Learjet 45';
  Id:='LJ45'; Cat:='J'; NEng:=2; Wings:=1; Sweep:=13.0; Year:=1998;
  MTow:=9300.0; VMaxKmh:=860.0; WaveK:=0.5; GroundFx:=0.12; VSScale:=2000;
  Desc:='Avion d''affaires a reaction (modele integre)';
  Jet:=True; Retract:=True; HasFlaps:=True;
  Empty:=6500.0; FuelCap:=2400.0; FuelFrac:=0.7; FuelFlow:=0.6;
  S:=29.1; CD0:=0.022; K:=0.05; CLa:=4.8; Alpha0:=-0.04; NegK:=0.6;
  CLmax:=1.5; CLmaxF:=2.2; CDFlap:=0.05; CDGear:=0.02; McritW:=0.77;
  Pwr:=0.0; Tstat:=30000.0; SpoolT:=2.0; MachK:=0.55;
  PMax:=0.8; Kq:=0.5; Ks:=2.0; Kw:=1.2; Krud:=0.3;
  AlphaTrim:=0.05; Vref:=60.0;
  NLim:=3.2; CrashVS:=4.0; MaxBank:=0.3; TailAng:=0.2; BrakeMu:=0.5;
  GearH:=1.7; EyeF:=5.0; EyeU:=0.9;
  Vne:=157.0; VsMax:=12.0; VDial:=400;
  Len:=17.7; Span:=14.5; Col1:=White; Col2:=Blue;
 End;

 With Specs[3] Do Begin
  Name:='Boeing 737-800';
  Id:='B738'; Cat:='J'; NEng:=2; Wings:=1; Sweep:=25.0; Year:=1998;
  MTow:=79000.0; VMaxKmh:=870.0; WaveK:=0.5; GroundFx:=0.12; VSScale:=2000;
  Desc:='Avion de ligne bireacteur (modele integre)';
  Jet:=True; Retract:=True; HasFlaps:=True;
  Empty:=52000.0; FuelCap:=20000.0; FuelFrac:=0.5; FuelFlow:=1.4;
  S:=125.0; CD0:=0.024; K:=0.04; CLa:=5.2; Alpha0:=-0.04; NegK:=0.6;
  CLmax:=1.6; CLmaxF:=2.5; CDFlap:=0.07; CDGear:=0.025; McritW:=0.78;
  Pwr:=0.0; Tstat:=240000.0; SpoolT:=3.0; MachK:=0.55;
  PMax:=0.35; Kq:=0.35; Ks:=1.6; Kw:=1.0; Krud:=0.15;
  AlphaTrim:=0.05; Vref:=80.0;
  NLim:=2.5; CrashVS:=3.8; MaxBank:=0.2; TailAng:=0.18; BrakeMu:=0.5;
  GearH:=3.4; EyeF:=14.0; EyeU:=1.2;
  Vne:=180.0; VsMax:=13.0; VDial:=400;
  Len:=39.5; Span:=35.8; Col1:=White; Col2:=LightBlue;
 End;
End;

{ ------------------------------------------------------------------ }
{ Fiches d'avions : SAMPLES/FLIGHT/*.FLT                             }
{ ------------------------------------------------------------------ }

Function ValR(Const S:String):Real;
Var
 R:Real;
 E:Integer;
Begin
 Val(S,R,E);
 If E<>0 Then R:=0.0;
 ValR:=R;
End;

{ Affecte une cle NOM=VALEUR d'une fiche a la description de l'avion }
Procedure ApplyKey(Var Sp:TSpec;Const K,V:String);
Var
 R:Real;
 N:Integer;
Begin
 R:=ValR(V);
 N:=Round(R);
 If K='NAME' Then Sp.Name:=Copy(V,1,40) Else
 If K='DESC' Then Sp.Desc:=Copy(V,1,110) Else
 If K='MODEL' Then Sp.Id:=Copy(V,1,10) Else
 If K='CAT' Then Begin If V<>'' Then Sp.Cat:=V[1]; End Else
 If K='ENGINES' Then Sp.NEng:=N Else
 If K='YEAR' Then Sp.Year:=N Else
 If K='MTOW' Then Sp.MTow:=R Else
 If K='VMAXKMH' Then Sp.VMaxKmh:=R Else
 If K='RETRACT' Then Sp.Retract:=(N<>0) Else
 If K='FLAPS' Then Sp.HasFlaps:=(N<>0) Else
 If K='FLOAT' Then Sp.Float:=(N<>0) Else
 If K='AMPH' Then Sp.Amph:=(N<>0) Else
 If K='WINGS' Then Sp.Wings:=N Else
 If K='SWEEP' Then Sp.Sweep:=R Else
 If K='DELTA' Then Sp.Delta:=(N<>0) Else
 If K='HIGHWING' Then Sp.HighWing:=(N<>0) Else
 If K='LEN' Then Sp.Len:=R Else
 If K='SPAN' Then Sp.Span:=R Else
 If K='S' Then Sp.S:=R Else
 If K='EMPTY' Then Sp.Empty:=R Else
 If K='FUELCAP' Then Sp.FuelCap:=R Else
 If K='FUELFRAC' Then Sp.FuelFrac:=R Else
 If K='FUELFLOW' Then Sp.FuelFlow:=R Else
 If K='CD0' Then Sp.CD0:=R Else
 If K='K' Then Sp.K:=R Else
 If K='CLA' Then Sp.CLa:=R Else
 If K='ALPHA0' Then Sp.Alpha0:=R Else
 If K='NEGK' Then Sp.NegK:=R Else
 If K='CLMAX' Then Sp.CLmax:=R Else
 If K='CLMAXF' Then Sp.CLmaxF:=R Else
 If K='CDFLAP' Then Sp.CDFlap:=R Else
 If K='CDGEAR' Then Sp.CDGear:=R Else
 If K='MCRIT' Then Sp.McritW:=R Else
 If K='WAVEK' Then Sp.WaveK:=R Else
 If K='GEFX' Then Sp.GroundFx:=R Else
 If K='PWR' Then Sp.Pwr:=R Else
 If K='TSTAT' Then Sp.Tstat:=R Else
 If K='SPOOLT' Then Sp.SpoolT:=R Else
 If K='MACHK' Then Sp.MachK:=R Else
 If K='AB' Then Sp.Ab:=(N<>0) Else
 If K='CRITALT' Then Sp.CritAlt:=R Else
 If K='BOOST' Then Sp.Boost:=R Else
 If K='BOOSTV' Then Sp.BoostV:=R Else
 If K='TOW' Then Sp.Tow:=(N<>0) Else
 If K='PMAX' Then Sp.PMax:=R Else
 If K='KQ' Then Sp.Kq:=R Else
 If K='KS' Then Sp.Ks:=R Else
 If K='KW' Then Sp.Kw:=R Else
 If K='KRUD' Then Sp.Krud:=R Else
 If K='ATRIM' Then Sp.AlphaTrim:=R Else
 If K='VREF' Then Sp.Vref:=R Else
 If K='NLIM' Then Sp.NLim:=R Else
 If K='CRASHVS' Then Sp.CrashVS:=R Else
 If K='MAXBANK' Then Sp.MaxBank:=R Else
 If K='TAILANG' Then Sp.TailAng:=R Else
 If K='BRAKEMU' Then Sp.BrakeMu:=R Else
 If K='GEARH' Then Sp.GearH:=R Else
 If K='EYEF' Then Sp.EyeF:=R Else
 If K='EYEU' Then Sp.EyeU:=R Else
 If K='VNE' Then Sp.Vne:=R Else
 If K='VSMAX' Then Sp.VsMax:=R Else
 If K='VDIAL' Then Sp.VDial:=N Else
 If K='VSSCALE' Then Sp.VSScale:=N Else
 If K='COL1' Then Sp.Col1:=N Else
 If K='COL2' Then Sp.Col2:=N;
End;

{ Lit une fiche .FLT ; retourne False si le fichier est introuvable }
Function LoadSpecFile(Const Id:String;Var Sp:TSpec):Boolean;
Var
 T:Text;
 L,K,V:String;
 P:Integer;
Begin
 LoadSpecFile:=False;
 FillChar(Sp,SizeOf(Sp),0);
 Sp.Id:=Id;
 Sp.Cat:='P';
 Sp.Wings:=1;
 Sp.NEng:=1;
 Sp.WaveK:=0.5;
 Sp.VSScale:=2000;
 Assign(T,AcDir+Id+'.FLT');
 {$I-}
 Reset(T);
 {$I+}
 If IOResult<>0 Then Exit;
 While Not Eof(T) do Begin
  ReadLn(T,L);
  P:=Pos('=',L);
  If(P>1)and(L[1]<>'#')Then Begin
   K:=Copy(L,1,P-1);
   V:=Copy(L,P+1,Length(L)-P);
   While(Length(V)>0)and(V[Length(V)]<=' ')do Dec(V[0]);
   ApplyKey(Sp,K,V);
  End;
 End;
 Close(T);
 Sp.Jet:=Sp.Cat in['J','A','R','U'];
 If Sp.SpoolT<0.1 Then Sp.SpoolT:=0.5;
 If Sp.S<1.0 Then Sp.S:=1.0;
 If Sp.Vref<1.0 Then Sp.Vref:=1.0;
 LoadSpecFile:=True;
End;

Procedure SortAc(N:Integer);
Var
 I,J:Integer;
 T:String[8];
Begin
 For I:=1 to N-1 do Begin
  T:=AcFile[I];
  J:=I-1;
  While(J>=0)and(AcFile[J]>T)do Begin
   AcFile[J+1]:=AcFile[J];
   Dec(J);
  End;
  AcFile[J+1]:=T;
 End;
End;

{ Cherche les fiches dans un repertoire ; retourne le nombre trouve }
Function ScanDir(Const Dir:String):Integer;
Var
 SR:SearchRec;
 N,P:Integer;
 S:String;
Begin
 N:=0;
 FindFirst(Dir+'*.FLT',AnyFile,SR);
 While(DosError=0)and(N<MAX_AC)do Begin
  S:=SR.Name;
  P:=Pos('.',S);
  If P>1 Then Begin
   AcFile[N]:=UpStr(Copy(S,1,P-1));
   Inc(N);
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
  FindClose(SR);
 {$ENDIF}
 ScanDir:=N;
End;

{ Construit la liste des avions : SAMPLES/FLIGHT, sinon avions integres }
Procedure ScanAircraft;
Var
 D:DirStr;
 Nm:NameStr;
 Ex:ExtStr;
 Base:String;
 I,N:Integer;
Begin
 FSplit(ParamStr(0),D,Nm,Ex);
 N:=0;
 For I:=0 to 3 do Begin
  Case I of
   0:Base:='SAMPLES/FLIGHT/';
   1:Base:='../SAMPLES/FLIGHT/';
   2:Base:=D+'SAMPLES/FLIGHT/';
   Else Base:=D+'../SAMPLES/FLIGHT/';
  End;
  If N=0 Then Begin
   N:=ScanDir(Base);
   If N>0 Then AcDir:=Base;
  End;
 End;
 If N=0 Then Begin
  For I:=0 to NB_PLANE-1 do AcFile[I]:='*'+Chr(48+I);
  N:=NB_PLANE;
  AcDir:='';
 End
  Else SortAc(N);
 NAc:=N;
End;

{ Charge l'avion numero I de la liste dans l'emplacement SLOT_CUR }
Procedure LoadAircraft(I:Integer);
Begin
 If(I<0)or(I>=NAc)Then I:=0;
 If AcFile[I][1]='*' Then Specs[SLOT_CUR]:=Specs[Ord(AcFile[I][2])-48]
 Else If Not LoadSpecFile(AcFile[I],Specs[SLOT_CUR])Then
  Specs[SLOT_CUR]:=Specs[0];
End;

{ ------------------------------------------------------------------ }
{ Le monde : aeroports, relief, villes, lacs, nuages                 }
{ ------------------------------------------------------------------ }

Procedure SetAirport(I:Integer;Const N,C:String;PX,PY:Real;AxX:Boolean;
                     PLen,PWid:Real);
Begin
 Aps[I].Name:=N; Aps[I].Code:=C; Aps[I].X:=PX; Aps[I].Y:=PY;
 Aps[I].AxisX:=AxX; Aps[I].Len:=PLen; Aps[I].Wid:=PWid;
End;

Procedure AddBld(PX,PY,PW,PD,PZ0,PH:Real;PCol,PRoof:Integer);
Begin
 If NBld>=MAX_BLD Then Exit;
 Blds[NBld].X:=PX; Blds[NBld].Y:=PY;
 Blds[NBld].W:=PW; Blds[NBld].D:=PD;
 Blds[NBld].Z0:=PZ0; Blds[NBld].H:=PH;
 Blds[NBld].Col:=PCol; Blds[NBld].Roof:=PRoof;
 Inc(NBld);
End;

{ Ajoute un batiment dans le repere de la piste (A=long, B=lateral) }
Procedure AddBldLocal(I:Integer;A,B,WA,WB,Z0,H:Real;Col,Roof:Integer);
Begin
 If Aps[I].AxisX Then
  AddBld(Aps[I].X+A,Aps[I].Y+B,WA,WB,Z0,H,Col,Roof)
 Else
  AddBld(Aps[I].X+B,Aps[I].Y+A,WB,WA,Z0,H,Col,Roof);
End;

{ Coordonnees locales par rapport au centre de la piste }
Procedure AirportLocal(I:Integer;X,Y:Real;Var A,B:Real);
Begin
 If Aps[I].AxisX Then Begin
  A:=X-Aps[I].X; B:=Y-Aps[I].Y;
 End
  Else
 Begin
  A:=Y-Aps[I].Y; B:=X-Aps[I].X;
 End;
End;

{ Seuil de piste : E=0 premiere extremite, E=1 seconde extremite }
Procedure RunwayEnd(I,E:Integer;Var RX,RY,Hdg:Real);
Var
 HL:Real;
Begin
 HL:=Aps[I].Len/2.0;
 If Aps[I].AxisX Then Begin
  RY:=Aps[I].Y;
  If E=0 Then Begin RX:=Aps[I].X-HL; Hdg:=90.0; End
         Else Begin RX:=Aps[I].X+HL; Hdg:=270.0; End;
 End
  Else
 Begin
  RX:=Aps[I].X;
  If E=0 Then Begin RY:=Aps[I].Y-HL; Hdg:=0.0; End
         Else Begin RY:=Aps[I].Y+HL; Hdg:=180.0; End;
 End;
End;

{ Surface en dur (piste, bretelles et aire de stationnement) ? }
Function OnPaved(X,Y:Real):Boolean;
Var
 I:Integer;
 A,B:Real;
Begin
 OnPaved:=False;
 For I:=0 to NB_AIRPORT-1 do Begin
  AirportLocal(I,X,Y,A,B);
  If(Abs(A)<=Aps[I].Len/2.0+60.0)and(Abs(B)<=Aps[I].Wid/2.0+4.0)Then
   OnPaved:=True;
  If(Abs(A)<=300.0)and(B>=50.0)and(B<=160.0)Then OnPaved:=True;
  If(Abs(A-120.0)<=12.0)and(B>=0.0)and(B<=160.0)Then OnPaved:=True;
 End;
End;

{ Sur la piste proprement dite ? }
Function OnRunway(X,Y:Real;Var Ap:Integer):Boolean;
Var
 I:Integer;
 A,B:Real;
Begin
 OnRunway:=False;
 Ap:=-1;
 For I:=0 to NB_AIRPORT-1 do Begin
  AirportLocal(I,X,Y,A,B);
  If(Abs(A)<=Aps[I].Len/2.0)and(Abs(B)<=Aps[I].Wid/2.0)Then Begin
   OnRunway:=True;
   Ap:=I;
  End;
 End;
End;

Function TerrainH(X,Y:Real):Real;
Var
 I:Integer;
 D,H,Best:Real;
Begin
 Best:=0.0;
 For I:=0 to MAX_MTN-1 do Begin
  D:=Sqrt(Sqr(X-Mtns[I].X)+Sqr(Y-Mtns[I].Y));
  If D<Mtns[I].R Then Begin
   H:=Mtns[I].H*(1.0-D/Mtns[I].R);
   If H>Best Then Best:=H;
  End;
 End;
 TerrainH:=Best;
End;

Function InLake(X,Y:Real):Boolean;
Var
 I:Integer;
Begin
 InLake:=False;
 For I:=0 to MAX_LAKE-1 do
  If Sqr((X-Lakes[I].X)/Lakes[I].RX)+Sqr((Y-Lakes[I].Y)/Lakes[I].RY)<1.0 Then
   InLake:=True;
End;

Procedure SetMtn(I:Integer;X,Y,R,H:Real);
Begin
 Mtns[I].X:=X; Mtns[I].Y:=Y; Mtns[I].R:=R; Mtns[I].H:=H;
End;

Procedure SetLake(I:Integer;X,Y,RX,RY:Real);
Begin
 Lakes[I].X:=X; Lakes[I].Y:=Y; Lakes[I].RX:=RX; Lakes[I].RY:=RY;
End;

Procedure AddTown(CX,CY,Rad:Real;Count:Integer;MaxH:Real);
Var
 I:Integer;
 A,D,X,Y,H,W,Dp:Real;
 C,R:Integer;
Begin
 For I:=1 to Count do Begin
  A:=RandR*2.0*Pi;
  D:=RandR*Rad;
  X:=CX+Cos(A)*D;
  Y:=CY+Sin(A)*D;
  H:=MaxH*(1.0-D/Rad)*(0.3+RandR*0.7)+8.0;
  W:=18.0+RandR*40.0;
  Dp:=18.0+RandR*40.0;
  Case Random(6) of
   0:C:=LightGray;
   1:C:=White;
   2:C:=Brown;
   3:C:=LightRed;
   4:C:=Cyan;
  Else C:=DarkGray;
  End;
  If Random(2)=0 Then R:=DarkGray Else R:=LightGray;
  AddBld(X,Y,W,Dp,0.0,H,C,R);
 End;
End;

Procedure InitAirportBuildings;
Var
 I:Integer;
Begin
 For I:=0 to NB_AIRPORT-1 do Begin
  { terminal }
  AddBldLocal(I,0.0,150.0,170.0,36.0,0.0,14.0,LightGray,DarkGray);
  { tour de controle : fut puis cabine }
  AddBldLocal(I,120.0,175.0,12.0,12.0,0.0,34.0,White,LightGray);
  AddBldLocal(I,120.0,175.0,20.0,20.0,34.0,7.0,Cyan,DarkGray);
  { hangars }
  AddBldLocal(I,-220.0,150.0,80.0,50.0,0.0,16.0,Brown,LightGray);
  If I<2 Then
   AddBldLocal(I,-130.0,150.0,60.0,45.0,0.0,14.0,LightRed,DarkGray);
 End;
End;

Procedure InitWorld;
Var
 I:Integer;
 A,E:Real;
Begin
 RandSeed:=4242;
 SetAirport(0,'Gladir Intl','GLAD',0.0,0.0,True,4000.0,45.0);
 SetAirport(1,'Mont-Blanc','MBLC',30000.0,40000.0,False,3200.0,45.0);
 SetAirport(2,'Port-Neuf','PNEF',-40000.0,25000.0,True,1800.0,30.0);
 SetAirport(3,'Val-Vert','VVRT',15000.0,-45000.0,False,1200.0,25.0);

 SetMtn(0,-20000.0,-30000.0,9000.0,2600.0);
 SetMtn(1,50000.0,10000.0,8000.0,2200.0);
 SetMtn(2,-60000.0,-20000.0,12000.0,3200.0);
 SetMtn(3,25000.0,5000.0,5000.0,1700.0);
 SetMtn(4,-30000.0,60000.0,7000.0,2000.0);
 SetMtn(5,60000.0,-40000.0,10000.0,2800.0);
 SetMtn(6,-10000.0,55000.0,6000.0,1800.0);
 SetMtn(7,45000.0,70000.0,7000.0,2100.0);
 SetMtn(8,-70000.0,50000.0,9000.0,2500.0);
 SetMtn(9,5000.0,-60000.0,8000.0,2300.0);

 SetLake(0,13000.0,9000.0,6500.0,2500.0);
 SetLake(1,-30000.0,5000.0,5000.0,3000.0);
 SetLake(2,40000.0,-20000.0,6000.0,3500.0);

 NBld:=0;
 InitAirportBuildings;
 AddTown(7000.0,4000.0,1500.0,26,90.0);
 AddTown(27000.0,36000.0,1200.0,12,30.0);
 AddTown(-38000.0,30000.0,1000.0,10,25.0);
 AddTown(17000.0,-41000.0,900.0,8,20.0);
 AddTown(-15000.0,-12000.0,2500.0,18,35.0);
 AddTown(55000.0,25000.0,1500.0,12,25.0);

 For I:=0 to MAX_CLD-1 do Begin
  Clds[I].X:=(RandR-0.5)*150000.0;
  Clds[I].Y:=(RandR-0.5)*150000.0;
  Clds[I].Z:=1600.0+RandR*1000.0;
  Clds[I].R:=500.0+RandR*900.0;
 End;

 For I:=0 to MAX_STAR-1 do Begin
  A:=RandR*2.0*Pi;
  E:=0.05+RandR*1.2;
  Stars[I].X:=Cos(E)*Sin(A);
  Stars[I].Y:=Cos(E)*Cos(A);
  Stars[I].Z:=Sin(E);
 End;

 VSet(Sun,0.55,-0.45,0.70);
 VNormalize(Sun);
 Randomize;
End;

{ ------------------------------------------------------------------ }
{ Messages a l'ecran                                                 }
{ ------------------------------------------------------------------ }

Procedure SetMsg(Const S:String;Col:Integer;Secs:Real);
Begin
 MsgText:=S;
 MsgColor:=Col;
 MsgTime:=Secs;
End;

{ ------------------------------------------------------------------ }
{ Aerodynamique et moteur                                            }
{ ------------------------------------------------------------------ }

{ Coefficients de portance et de trainee, avec decrochage }
Procedure Aero(Const Sp:TSpec;Alpha,FlapF,GearF,Mach:Real;
               Var CL,CD:Real;Var Stall:Boolean;Var StallWarn:Boolean);
Var
 A,Cmax,Cneg,Cf,Lin,Ex,Cs,Sn,Blend,AsPos:Real;
Begin
 Cmax:=Sp.CLmax+(Sp.CLmaxF-Sp.CLmax)*FlapF;
 Cneg:=-Cmax*Sp.NegK;
 Cf:=0.8*(Sp.CLmaxF-Sp.CLmax)*FlapF;
 A:=WrapPi(Alpha-Sp.Alpha0);
 Lin:=Sp.CLa*A+Cf;
 AsPos:=(Cmax-Cf)/Sp.CLa;
 Stall:=False;
 StallWarn:=(A>0.85*AsPos)and(A<Pi/2.0);
 Blend:=0.0;
 If Lin>Cmax Then Begin
  Ex:=(Lin-Cmax)/Sp.CLa;
  Cs:=Cmax*(1.0-3.5*Ex);
  If Cs<0.55*Cmax Then Cs:=0.55*Cmax;
  If A>0.6 Then Begin
   Sn:=1.1*Sin(2.0*A);
   If Sn<Cs Then Cs:=Sn;
  End;
  CL:=Cs;
  Stall:=True;
  Blend:=Clamp(Ex*6.0,0.0,1.0);
 End
  Else
 If Lin<Cneg Then Begin
  Ex:=(Cneg-Lin)/Sp.CLa;
  Cs:=Cneg*(1.0-3.5*Ex);
  If Cs>0.55*Cneg Then Cs:=0.55*Cneg;
  If A<-0.6 Then Begin
   Sn:=1.1*Sin(2.0*A);
   If Sn>Cs Then Cs:=Sn;
  End;
  CL:=Cs;
  Stall:=True;
  Blend:=Clamp(Ex*6.0,0.0,1.0);
 End
  Else
 CL:=Lin;
 CD:=Sp.CD0+Sp.K*CL*CL+Sp.CDFlap*FlapF+Sp.CDGear*GearF;
 If Mach>Sp.McritW Then Begin
  If Mach<1.05 Then
   CD:=CD+Sp.WaveK*Sqr(Clamp((Mach-Sp.McritW)/(1.05-Sp.McritW),0.0,1.0))
  Else
   CD:=CD+Sp.WaveK*(1.0-0.6*Clamp((Mach-1.05)/0.8,0.0,1.0));
 End;
 CD:=CD+Blend*1.3*Sqr(Sin(A));
End;

Function ThrustFun(Const Sp:TSpec;Spool,V,Rho,Mach:Real):Real;
Var
 Sig,SigC,T,Pa,Core,ABf:Real;
Begin
 Sig:=Rho/1.225;
 SigC:=1.0;
 If Sp.CritAlt>0.0 Then SigC:=Density(Sp.CritAlt)/1.225;
 Case Sp.Cat of
  'J','A','U':Begin
     If Sp.Ab Then Begin
      ABf:=Clamp((Spool-0.85)/0.15,0.0,1.0);
      Core:=MinR(Spool,0.85)/0.85;
      T:=Sp.Tstat*(0.62*(0.03+0.97*Core)+0.38*ABf);
     End
      Else T:=Sp.Tstat*(0.03+0.97*Spool);
     T:=T*Exp(0.7*Ln(Sig))*Clamp(1.0-Sp.MachK*Mach,0.2,1.8);
    End;
  'R','G':T:=Sp.Tstat*Spool;
  'C':T:=Sp.Tstat*Spool*Exp(0.8*Ln(Sig));
  Else Begin
     Pa:=Sp.Pwr*Spool*MinR(1.0,Sig/SigC);
     T:=MinR(Sp.Tstat*Spool*MinR(1.0,Sig/SigC),0.8*Pa/MaxR(V,1.0));
     T:=T-0.08*Sp.Tstat*(1.0-Spool)*MinR(V/50.0,1.0);
    End;
 End;
 If(Sp.Boost>0.0)and(Spool>0.9)and(V<Sp.BoostV)Then T:=T+Sp.Boost;
 ThrustFun:=T;
End;

Procedure DoCrash(Var F:TFlt;Id:Integer);
Begin
 If F.Crashed Then Exit;
 F.Crashed:=True;
 F.CrashMsg:=Id;
 F.CrashT:=0.0;
 VSet(F.V,0.0,0.0,0.0);
 F.AP:=False;
End;

Procedure RotateZ(Var A:TVec;C,S:Real);
Var
 X,Y:Real;
Begin
 X:=A.X; Y:=A.Y;
 A.X:=X*C+Y*S;
 A.Y:=-X*S+Y*C;
End;

{ Compte rendu de la pose }
Procedure TouchdownReport(Sink:Real;Const Sp:TSpec;OnWater:Boolean);
Var
 Fpm:LongInt;
 Rate,Loc:String;
 Col,Ap:Integer;
Begin
 TouchedDown:=True;
 Fpm:=Round(Sink*FT*60.0);
 If Sink<1.0 Then Begin Rate:=Tr(T_EXCEL); Col:=LightGreen; End Else
 If Sink<2.0 Then Begin Rate:=Tr(T_GOOD);  Col:=LightGreen; End Else
 If Sink<Sp.CrashVS*0.7 Then Begin Rate:=Tr(T_FIRM); Col:=Yellow; End
 Else Begin Rate:=Tr(T_HARD); Col:=LightRed; End;
 If OnWater Then Loc:=Tr(T_WATER) Else
 If OnRunway(Fl.P.X,Fl.P.Y,Ap) Then Loc:=Tr(T_ONRWY) Else Loc:=Tr(T_OFF);
 SetMsg(Tr(T_TD)+' : '+IntStr(Fpm)+' ft/min - '+Rate+' ('+Loc+')',
        Col,7.0);
End;

{ Un pas de simulation physique }
Procedure StepPhysics(Var F:TFlt;Dt:Real);
Var
 Sp:TSpec;
 M,Rho,V,Q,Al,Be,CL,CD,Lm,Dm,Ym,Tm,FlapF,GearF,Ce,Ce2,Tgt:Real;
 Vf,Vr,Vu,Tmp,Tur:Real;
 Va,Vh,Ll,Acc,OldF,OldR,OldU,Td:TVec;
 Ps,Th,Rl,Pr,Qr,Yr,Gam:Real;
 Stall,SWarn:Boolean;
 Hgt,TerH,Heff,Mu,Nf,Hs,Sp2,Sink,Yg,Fx,Fy,Fn:Real;
 ABf,Idle,Gf,AGL:Real;
 Wat:Boolean;
 I:Integer;
Begin
 If F.Crashed Then Exit;
 Sp:=Specs[F.Spec];
 TerH:=TerrainH(F.P.X,F.P.Y);

 { train d'atterrissage }
 If Sp.Retract Then Begin
  If F.GearDn Then F.GearPos:=MinR(1.0,F.GearPos+0.25*Dt)
              Else F.GearPos:=MaxR(0.0,F.GearPos-0.25*Dt);
 End
  Else
 F.GearPos:=1.0;

 { remorquage des planeurs : largage a 600 m }
 If Sp.Tow and(F.Thr>0.0)and(F.P.Z-TerH>600.0)Then Begin
  F.Thr:=0.0;
  F.TowDone:=True;
  SetMsg(Tr(W_TOWREL),LightCyan,4.0);
 End;

 { moteur et carburant }
 Tgt:=F.Thr;
 If F.Fuel<=0.0 Then Tgt:=0.0;
 F.Spool:=F.Spool+(Tgt-F.Spool)*MinR(1.0,Dt/Sp.SpoolT);
 ABf:=0.0;
 If Sp.Ab Then ABf:=Clamp((F.Spool-0.85)/0.15,0.0,1.0);
 If Sp.Cat in['R','H','G']Then Idle:=0.0 Else Idle:=0.08;
 If(F.Fuel>0.0)and(Sp.FuelFlow>0.0)Then Begin
  F.Fuel:=F.Fuel-Sp.FuelFlow*(Idle+(1.0-Idle)*F.Spool)*(1.0+1.4*ABf)*Dt;
  If F.Fuel<0.0 Then F.Fuel:=0.0;
 End;

 M:=Sp.Empty+F.Fuel;
 Rho:=Density(F.P.Z);

 { vitesse par rapport a l'air }
 Va.X:=F.V.X-Wind.X; Va.Y:=F.V.Y-Wind.Y; Va.Z:=F.V.Z-Wind.Z;
 V:=Sqrt(Va.X*Va.X+Va.Y*Va.Y+Va.Z*Va.Z);
 If V<0.5 Then V:=0.5;
 Vh.X:=Va.X/V; Vh.Y:=Va.Y/V; Vh.Z:=Va.Z/V;
 If V<1.0 Then VSet(Vh,F.F.X,F.F.Y,F.F.Z);
 Vf:=Dot(Va,F.F); Vr:=Dot(Va,F.R); Vu:=Dot(Va,F.U);
 If V<1.0 Then Begin Vf:=1.0; Vr:=0.0; Vu:=0.0; End;
 Al:=ATan2(-Vu,Vf);
 Be:=ATan2(Vr,Sqrt(Vf*Vf+Vu*Vu));
 F.Mach:=V/SoundSpeed(F.P.Z);
 F.IAS:=V*Sqrt(Rho/1.225);
 Q:=0.5*Rho*V*V;
 FlapF:=0.0;
 If Sp.HasFlaps Then FlapF:=F.Flaps/3.0;
 GearF:=0.0;
 If Sp.Retract Then GearF:=F.GearPos;
 Aero(Sp,Al,FlapF,GearF,F.Mach,CL,CD,Stall,SWarn);
 { effet de sol }
 AGL:=F.P.Z-TerH-Sp.GearH;
 Gf:=Clamp(1.0-AGL/Sp.Span,0.0,1.0)*Sp.GroundFx;
 CL:=CL*(1.0+Gf);
 CD:=CD*(1.0-0.5*Gf);
 F.Alpha:=Al; F.Beta:=Be;
 F.Stalled:=(Stall or SWarn)and(Sp.Cat<>'C');
 Lm:=Q*Sp.S*CL;
 Dm:=Q*Sp.S*CD;
 Ym:=-Q*Sp.S*0.6*Be;

 { direction de la portance }
 Tmp:=Dot(F.U,Vh);
 Ll.X:=F.U.X-Tmp*Vh.X; Ll.Y:=F.U.Y-Tmp*Vh.Y; Ll.Z:=F.U.Z-Tmp*Vh.Z;
 If Sqrt(Dot(Ll,Ll))>0.05 Then VNormalize(Ll)
                          Else Ll:=F.U;

 Tm:=ThrustFun(Sp,F.Spool,V,Rho,F.Mach);

 If Sp.Cat='C' Then Td:=F.U Else Td:=F.F;
 Acc.X:=(Lm*Ll.X-Dm*Vh.X+Ym*F.R.X+Tm*Td.X)/M;
 Acc.Y:=(Lm*Ll.Y-Dm*Vh.Y+Ym*F.R.Y+Tm*Td.Y)/M;
 Acc.Z:=(Lm*Ll.Z-Dm*Vh.Z+Ym*F.R.Z+Tm*Td.Z)/M-G0;
 F.GLoad:=(Lm*Dot(Ll,F.U)-Dm*Dot(Vh,F.U)+Tm*Dot(Td,F.U))/(M*G0);

 { turbulence }
 If(Wind.X<>0.0)or(Wind.Y<>0.0)Then Begin
  Tur:=0.6;
  If Sqrt(Wind.X*Wind.X+Wind.Y*Wind.Y)>7.0 Then Tur:=1.6;
  If F.P.Z<3000.0 Then Begin
   Acc.X:=Acc.X+(RandR-0.5)*Tur;
   Acc.Y:=Acc.Y+(RandR-0.5)*Tur;
   Acc.Z:=Acc.Z+(RandR-0.5)*Tur*1.5;
  End;
 End;

 { vitesses de rotation }
 Ce:=Clamp(V*V/(Sp.Vref*Sp.Vref),0.02,1.2);
 Ce2:=Clamp(V*V/(Sp.Vref*Sp.Vref),0.05,1.0);
 Gam:=ArcSin(Clamp(Vh.Z,-1.0,1.0));
 Qr:=(Sp.Kq*F.Elev+Sp.Ks*(Sp.AlphaTrim-Al-0.12*Gam))*Ce;
 AxesToEuler(F.F,F.R,F.U,Ps,Th,Rl);
 Pr:=Sp.PMax*F.Ail*Ce-0.5*Be*Ce2;
 If F.Assist and(Abs(F.Ail)<0.05)and(Abs(Rl)<1.3)Then
  Pr:=Pr-0.35*Sin(Rl)*Ce2;
 Yr:=Sp.Krud*F.Rud*Ce+Sp.Kw*Be*Ce2;
 If Sp.Cat='C' Then Begin
  { helicoptere : pas de stabilite aerodynamique }
  Qr:=Sp.Kq*F.Elev;
  Pr:=Sp.PMax*F.Ail;
  Yr:=Sp.Krud*F.Rud+Sp.Kw*Be;
  If F.Assist Then Begin
   If Abs(F.Elev)<0.05 Then Qr:=Qr-1.2*Sin(Th);
   If Abs(F.Ail)<0.05 Then Pr:=Pr-1.2*Sin(Rl);
  End;
 End;
 If F.OnGround Then Qr:=Qr-0.8*Th;

 OldF:=F.F; OldR:=F.R; OldU:=F.U;
 F.F.X:=OldF.X+(Qr*OldU.X+Yr*OldR.X)*Dt;
 F.F.Y:=OldF.Y+(Qr*OldU.Y+Yr*OldR.Y)*Dt;
 F.F.Z:=OldF.Z+(Qr*OldU.Z+Yr*OldR.Z)*Dt;
 F.R.X:=OldR.X+(-Pr*OldU.X-Yr*OldF.X)*Dt;
 F.R.Y:=OldR.Y+(-Pr*OldU.Y-Yr*OldF.Y)*Dt;
 F.R.Z:=OldR.Z+(-Pr*OldU.Z-Yr*OldF.Z)*Dt;
 Orthonormalize(F.F,F.R,F.U);

 { integration }
 F.V.X:=F.V.X+Acc.X*Dt;
 F.V.Y:=F.V.Y+Acc.Y*Dt;
 F.V.Z:=F.V.Z+Acc.Z*Dt;
 F.P.X:=F.P.X+F.V.X*Dt;
 F.P.Y:=F.P.Y+F.V.Y*Dt;
 F.P.Z:=F.P.Z+F.V.Z*Dt;

 { contact avec le sol }
 TerH:=TerrainH(F.P.X,F.P.Y);
 If Sp.Retract and(F.GearPos<0.85)Then Heff:=0.4*Sp.GearH
                                  Else Heff:=Sp.GearH;
 Hgt:=F.P.Z-Heff-TerH;
 If Hgt>1.5 Then F.Air:=True;
 If Hgt<=0.001 Then Begin
  If F.Air Then Begin
   F.Air:=False;
   Sink:=-F.V.Z;
   AxesToEuler(F.F,F.R,F.U,Ps,Th,Rl);
   Wat:=InLake(F.P.X,F.P.Y);
   If TerH>4.0 Then DoCrash(F,C_TERRAIN) Else
   If Wat and(Not Sp.Float)Then DoCrash(F,C_WATER) Else
   If Sink>Sp.CrashVS*1.5 Then DoCrash(F,C_HARD) Else
   If Abs(Rl)>Sp.MaxBank Then DoCrash(F,C_WING) Else
   If Th<-0.15 Then DoCrash(F,C_NOSE) Else
   If Sp.Retract and(F.GearPos<0.85)Then Begin
    If Sink>2.5 Then DoCrash(F,C_HARD) Else Begin
     F.Belly:=True;
     SetMsg(Tr(C_BELLY),LightRed,8.0);
    End;
   End
    Else
   If Sp.Float and(Not Wat)and(Not Sp.Amph)Then Begin
    F.Belly:=True;
    SetMsg(Tr(C_HULL),LightRed,8.0);
   End
    Else
   TouchdownReport(Sink,Sp,Wat);
  End;
  If Not F.Crashed Then Begin
   F.OnGround:=True;
   F.P.Z:=TerH+Heff;
   If F.V.Z<0.0 Then F.V.Z:=0.0;
   Wat:=InLake(F.P.X,F.P.Y);

   { assiette : roulis nul, tangage entre 0 et la garde au sol }
   AxesToEuler(F.F,F.R,F.U,Ps,Th,Rl);
   If Th<0.0 Then Th:=0.0;
   If Th>Sp.TailAng Then Begin
    Th:=Sp.TailAng;
    If MsgTime<=0.0 Then SetMsg(Tr(W_TAIL),LightRed,2.0);
   End;
   EulerToAxes(Ps,Th,0.0,F.F,F.R,F.U);

   { direction par la roue avant }
   Hs:=Sqrt(F.V.X*F.V.X+F.V.Y*F.V.Y);
   If Not F.Belly Then Begin
    Yg:=F.Rud*0.5*MinR(1.0,Hs/8.0)/(1.0+Sqr(Hs/45.0));
    RotateZ(F.F,Cos(Yg*Dt),Sin(Yg*Dt));
    RotateZ(F.R,Cos(Yg*Dt),Sin(Yg*Dt));
    RotateZ(F.U,Cos(Yg*Dt),Sin(Yg*Dt));
   End;
   Fx:=F.F.X; Fy:=F.F.Y;
   Fn:=Sqrt(Fx*Fx+Fy*Fy);
   If Fn>0.01 Then Begin
    Fx:=Fx/Fn; Fy:=Fy/Fn;
    Sp2:=F.V.X*Fx+F.V.Y*Fy;
    If Sp2<0.0 Then Sp2:=0.0;
    If Wat and Sp.Float Then Mu:=0.03+0.0003*Hs Else
    If F.Belly Then Mu:=0.45 Else
    If OnPaved(F.P.X,F.P.Y)Then Mu:=0.02 Else Mu:=0.07;
    If Sp.Cat='C' Then Mu:=0.15;
    If F.Brakes and(Not F.Belly)and(Not Wat)Then Mu:=Mu+Sp.BrakeMu;
    Nf:=Clamp(1.0-Lm*Ll.Z/(M*G0),0.0,1.0);
    Sp2:=Sp2-Mu*Nf*G0*Dt;
    If Sp2<0.0 Then Sp2:=0.0;
    F.V.X:=Sp2*Fx;
    F.V.Y:=Sp2*Fy;
   End;
  End;
 End
  Else
 If Hgt>0.3 Then F.OnGround:=False;

 { collision avec les batiments }
 If Not F.Crashed Then
  For I:=0 to NBld-1 do
   If(Abs(F.P.X-Blds[I].X)<Blds[I].W/2.0+3.0)and
     (Abs(F.P.Y-Blds[I].Y)<Blds[I].D/2.0+3.0)and
     (F.P.Z-Heff<Blds[I].Z0+Blds[I].H)and
     (F.P.Z+2.0>Blds[I].Z0)Then DoCrash(F,C_BUILDING);

 { rupture de la structure }
 If Not F.Crashed Then Begin
  If(F.GLoad>Sp.NLim*1.7)or(F.GLoad<-Sp.NLim*0.8)Then DoCrash(F,C_OVERG)
  Else
  If(F.IAS>Sp.Vne*1.4)or((F.Mach>Sp.McritW+0.25)and(Sp.WaveK>0.3))Then
   DoCrash(F,C_OVERSPD);
 End;
 F.FlightT:=F.FlightT+Dt;
End;

{ ------------------------------------------------------------------ }
{ Pilote automatique                                                 }
{ ------------------------------------------------------------------ }

Procedure UpdateAutopilot(Var F:TFlt;Dt:Real);
Var
 Sp:TSpec;
 Ph,Th,Ps,Err,BankCmd,Pd,Ce,V,Vt,Gam,GamD,VsDes,Q,Rho,M,FlapF,Cf,
 CLreq,AlphaReq,ElevFF,Cmax,Vs1,Vmin:Real;
Begin
 Sp:=Specs[F.Spec];
 If F.OnGround or F.Crashed or(Sp.Cat='C')Then Begin
  F.AP:=False;
  Exit;
 End;
 AxesToEuler(F.F,F.R,F.U,Ps,Th,Ph);
 V:=Sqrt(Sqr(F.V.X-Wind.X)+Sqr(F.V.Y-Wind.Y)+Sqr(F.V.Z-Wind.Z));
 If V<10.0 Then V:=10.0;
 Vt:=Sqrt(F.V.X*F.V.X+F.V.Y*F.V.Y+F.V.Z*F.V.Z);
 If Vt<10.0 Then Vt:=10.0;
 Ce:=Clamp(V*V/(Sp.Vref*Sp.Vref),0.02,1.2);

 { cap : inclinaison commandee puis ailerons }
 Err:=WrapPi(F.APHdg*Pi/180.0-Ps);
 BankCmd:=Clamp(Err*1.1,-0.45,0.45);
 Pd:=1.2*(BankCmd-Ph);
 F.Ail:=Clamp(Pd/(Sp.PMax*Ce),-1.0,1.0);
 F.Rud:=0.0;

 { altitude : vitesse verticale puis profondeur }
 M:=Sp.Empty+F.Fuel;
 Rho:=Density(F.P.Z);
 Q:=0.5*Rho*V*V;
 FlapF:=0.0;
 If Sp.HasFlaps Then FlapF:=F.Flaps/3.0;
 Cmax:=Sp.CLmax+(Sp.CLmaxF-Sp.CLmax)*FlapF;
 Vs1:=Sqrt(2.0*M*G0/(1.225*Sp.S*Cmax));
 Vmin:=1.25*Vs1;
 VsDes:=Clamp(0.12*(F.APAlt-F.P.Z),-Sp.VsMax,Sp.VsMax);
 If(V<Vmin)and(VsDes>0.0)Then VsDes:=0.0;
 Gam:=ArcSin(F.V.Z/Vt);
 GamD:=ArcSin(Clamp(VsDes/Vt,-0.5,0.5));
 Cf:=0.8*(Sp.CLmaxF-Sp.CLmax)*FlapF;
 CLreq:=M*G0*Cos(Gam)/(Q*Sp.S*MaxR(0.3,Cos(Ph)));
 CLreq:=Clamp(CLreq,-0.5,Cmax*0.85);
 AlphaReq:=(CLreq-Cf)/Sp.CLa+Sp.Alpha0;
 ElevFF:=(AlphaReq-Sp.AlphaTrim)*Sp.Ks/Sp.Kq;
 If Not Sp.Tow Then F.Elev:=Clamp(ElevFF+5.0*(GamD-Gam),-1.0,1.0);

 { vitesse : automanette }
 If Not Sp.Tow Then Begin
  F.Thr:=Clamp(F.Thr+0.01*(F.APSpd-V)*Dt,0.0,1.0);
 End;
End;

{ ------------------------------------------------------------------ }
{ Preparation du vol                                                 }
{ ------------------------------------------------------------------ }

{ Regle manette et profondeur pour un vol stabilise (vitesse V, pente Gam) }
Procedure TrimFlight(Var F:TFlt;V:Real;Var Gam:Real);
Var
 Sp:TSpec;
 M,Rho,Q,CL,CD,Al,Cf,FlapF,GearF,Treq,Mach,S0,S1,Sm:Real;
 Stall,SW:Boolean;
 I:Integer;
Begin
 Sp:=Specs[F.Spec];
 M:=Sp.Empty+F.Fuel;
 Rho:=Density(F.P.Z);
 Q:=0.5*Rho*V*V;
 Mach:=V/SoundSpeed(F.P.Z);
 FlapF:=0.0;
 If Sp.HasFlaps Then FlapF:=F.Flaps/3.0;
 GearF:=0.0;
 If Sp.Retract Then GearF:=F.GearPos;
 CL:=M*G0*Cos(Gam)/(Q*Sp.S);
 Cf:=0.8*(Sp.CLmaxF-Sp.CLmax)*FlapF;
 Al:=(CL-Cf)/Sp.CLa+Sp.Alpha0;
 Aero(Sp,Al,FlapF,GearF,Mach,CL,CD,Stall,SW);
 If Sp.Tow Then Begin
  { planeur : vol plane, la pente est imposee par la finesse }
  Gam:=-ArcTan(CD/CL);
  CL:=M*G0*Cos(Gam)/(Q*Sp.S);
  Al:=(CL-Cf)/Sp.CLa+Sp.Alpha0;
  Aero(Sp,Al,FlapF,GearF,Mach,CL,CD,Stall,SW);
 End;
 Treq:=Q*Sp.S*CD+M*G0*Sin(Gam);
 S0:=0.0; S1:=1.0;
 For I:=1 to 24 do Begin
  Sm:=(S0+S1)/2.0;
  If ThrustFun(Sp,Sm,V,Rho,Mach)<Treq Then S0:=Sm Else S1:=Sm;
 End;
 F.Thr:=(S0+S1)/2.0;
 If Sp.Tow Then F.Thr:=0.0;
 F.Spool:=F.Thr;
 F.Elev:=Clamp((Al-Sp.AlphaTrim+0.12*Gam)*Sp.Ks/Sp.Kq,-1.0,1.0);
 F.Alpha:=Al;
End;

Procedure SetupFlight(Var F:TFlt);
Var
 Sp:TSpec;
 X,Y,Hdg,Psi,Dist,Spd,Gam,Cr:Real;
 WS,WD:Real;
 Ap:Integer;
Begin
 FillChar(F,SizeOf(F),0);
 LoadAircraft(OptPlane);
 F.Spec:=SLOT_CUR;
 Sp:=Specs[F.Spec];
 F.Fuel:=Sp.FuelCap*Sp.FuelFrac;
 F.Assist:=(OptAssist=1);
 F.GearDn:=True;
 F.GearPos:=1.0;
 Night:=(OptNight=1);

 { vent : direction d'ou il vient, vitesse }
 Case OptWind of
  1:Begin WS:=8.0/KT;  WD:=250.0; End;
  2:Begin WS:=20.0/KT; WD:=300.0; End;
  Else Begin WS:=0.0; WD:=0.0; End;
 End;
 VSet(Wind,-Sin(WD*Pi/180.0)*WS,-Cos(WD*Pi/180.0)*WS,0.0);

 Ap:=OptAirport;
 DestAp:=(Ap+1)mod NB_AIRPORT;
 RunwayEnd(Ap,0,X,Y,Hdg);
 Psi:=Hdg*Pi/180.0;

 Spd:=0.0;
 If(Sp.Cat='C')and(OptStart>0)Then Begin
  { helicoptere : vol stationnaire au-dessus de l'aeroport }
  If OptStart=1 Then Dist:=60.0 Else Dist:=400.0;
  VSet(F.P,X+Sin(Psi)*200.0,Y+Cos(Psi)*200.0,Dist);
  EulerToAxes(Psi,0.0,0.0,F.F,F.R,F.U);
  F.Thr:=Clamp((Sp.Empty+F.Fuel)*G0/(Sp.Tstat*Exp(0.8*Ln(Density(Dist)/1.225))),
               0.0,1.0);
  F.Spool:=F.Thr;
  F.Air:=True;
  F.GearDn:=True;
 End
  Else
 Case OptStart of
  0:Begin
     If Sp.Float and(Not Sp.Amph)Then Begin
      { depart sur l'eau, au bord ouest du premier lac }
      X:=Lakes[0].X-Lakes[0].RX*0.8;
      Y:=Lakes[0].Y;
      Psi:=Pi/2.0;
      VSet(F.P,X,Y,Sp.GearH);
     End
      Else
     VSet(F.P,X+Sin(Psi)*80.0,Y+Cos(Psi)*80.0,Sp.GearH);
     EulerToAxes(Psi,0.0,0.0,F.F,F.R,F.U);
     F.Brakes:=True;
     F.OnGround:=True;
     SetMsg(Tr(W_PARK),Yellow,6.0);
    End;
  1:Begin
     Dist:=9000.0;
     Gam:=-3.0*Pi/180.0;
     If Sp.Retract Then Begin
      F.GearDn:=False; F.GearPos:=0.0;
     End;
     If Sp.HasFlaps Then F.Flaps:=2;
     Spd:=1.35*Sqrt(2.0*(Sp.Empty+F.Fuel)*G0/
          (1.225*Sp.S*(Sp.CLmax+(Sp.CLmaxF-Sp.CLmax)*F.Flaps/3.0)));
     VSet(F.P,X-Sin(Psi)*Dist,Y-Cos(Psi)*Dist,Dist*Tan(3.0*Pi/180.0)+20.0);
     TrimFlight(F,Spd,Gam);
     EulerToAxes(Psi,Gam+F.Alpha,0.0,F.F,F.R,F.U);
     VSet(F.V,Sin(Psi)*Cos(Gam)*Spd,Cos(Psi)*Cos(Gam)*Spd,Sin(Gam)*Spd);
     F.V.X:=F.V.X+Wind.X; F.V.Y:=F.V.Y+Wind.Y;
     F.Air:=True;
    End;
  Else Begin
     VSet(F.P,X+Sin(Psi)*100.0,Y+Cos(Psi)*100.0,1500.0);
     Spd:=MinR(0.62*Sp.Vne,0.85*Sp.McritW*SoundSpeed(1500.0));
     Cr:=Sqrt(2.0*(Sp.Empty+F.Fuel)*G0/(1.225*Sp.S*Sp.CLmax));
     Spd:=MaxR(Spd,1.4*Cr);
     If Sp.Retract Then Begin
      F.GearDn:=False; F.GearPos:=0.0;
     End;
     Gam:=0.0;
     TrimFlight(F,Spd,Gam);
     EulerToAxes(Psi,Gam+F.Alpha,0.0,F.F,F.R,F.U);
     VSet(F.V,Sin(Psi)*Cos(Gam)*Spd,Cos(Psi)*Cos(Gam)*Spd,Sin(Gam)*Spd);
     F.V.X:=F.V.X+Wind.X; F.V.Y:=F.V.Y+Wind.Y;
     F.Air:=True;
    End;
 End;
 F.APSpd:=Spd;
 F.APAlt:=F.P.Z;
 F.APHdg:=Hdg;
 ViewMode:=VIEW_COCKPIT;
 Paused:=False;
 TouchedDown:=False;
 StopShown:=False;
End;

{ ------------------------------------------------------------------ }
{ Moteur 3D : projection, decoupage, polygones                      }
{ ------------------------------------------------------------------ }

Function DarkOf(C:Integer):Integer;
Begin
 Case C of
  15:DarkOf:=7;   7:DarkOf:=8;    14:DarkOf:=6;   6:DarkOf:=8;
  12:DarkOf:=4;   4:DarkOf:=8;    11:DarkOf:=3;   3:DarkOf:=1;
  10:DarkOf:=2;   2:DarkOf:=8;    9:DarkOf:=1;    8:DarkOf:=0;
  13:DarkOf:=5;   5:DarkOf:=8;    1:DarkOf:=0;
  Else DarkOf:=0;
 End;
End;

Procedure ToCam(Const C:TCam;Const P:TVec;Var Q:TVec);
Var
 DX,DY,DZ:Real;
Begin
 DX:=P.X-C.P.X; DY:=P.Y-C.P.Y; DZ:=P.Z-C.P.Z;
 Q.X:=DX*C.R.X+DY*C.R.Y+DZ*C.R.Z;
 Q.Y:=DX*C.U.X+DY*C.U.Y+DZ*C.U.Z;
 Q.Z:=DX*C.F.X+DY*C.F.Y+DZ*C.F.Z;
End;

{ Projette un point ; retourne False s'il est derriere la camera }
Function Proj(Const C:TCam;Const P:TVec;Var SX,SY,Z:Real):Boolean;
Var
 Q:TVec;
Begin
 ToCam(C,P,Q);
 Z:=Q.Z;
 If Q.Z<NEAR_Z Then Proj:=False
 Else Begin
  SX:=C.CX+C.Foc*Q.X/Q.Z;
  SY:=C.CY-C.Foc*Q.Y/Q.Z;
  Proj:=True;
 End;
End;

{ Decoupage de Sutherland-Hodgman contre un cote du rectangle }
Function ClipSide(Var Src:TPoly2;N:Integer;Var Dst:TPoly2;Side:Integer;
                  Lim:Real):Integer;
Var
 I,M,J:Integer;
 Sc,Ec,T:Real;
 SIn,EIn:Boolean;
Begin
 M:=0;
 For I:=0 to N-1 do Begin
  J:=(I+N-1)mod N;
  If Side<2 Then Begin Sc:=Src[J].X; Ec:=Src[I].X; End
            Else Begin Sc:=Src[J].Y; Ec:=Src[I].Y; End;
  If Odd(Side)Then Begin SIn:=Sc<=Lim; EIn:=Ec<=Lim; End
              Else Begin SIn:=Sc>=Lim; EIn:=Ec>=Lim; End;
  If EIn<>SIn Then Begin
   T:=(Lim-Sc)/(Ec-Sc);
   Dst[M].X:=Src[J].X+T*(Src[I].X-Src[J].X);
   Dst[M].Y:=Src[J].Y+T*(Src[I].Y-Src[J].Y);
   Inc(M);
  End;
  If EIn Then Begin
   Dst[M]:=Src[I];
   Inc(M);
  End;
 End;
 ClipSide:=M;
End;

{ Remplit le polygone de l'ecran contenu dans ClipA[0..N-1] }
Procedure FillScreenPoly(N:Integer;Fill,Line:Integer);
Var
 I:Integer;
 Pts:Array[0..39] Of PointType;
Begin
 N:=ClipSide(ClipA,N,ClipB,0,VX1);
 If N<3 Then Exit;
 N:=ClipSide(ClipB,N,ClipA,1,VX2);
 If N<3 Then Exit;
 N:=ClipSide(ClipA,N,ClipB,2,VY1);
 If N<3 Then Exit;
 N:=ClipSide(ClipB,N,ClipA,3,VY2);
 If N<3 Then Exit;
 For I:=0 to N-1 do Begin
  Pts[I].X:=Round(ClipA[I].X);
  Pts[I].Y:=Round(ClipA[I].Y);
 End;
 SetFillStyle(SolidFill,Fill);
 If Line>=0 Then SetColor(Line) Else SetColor(Fill);
 FillPoly(N,Pts);
End;

{ Polygone 3D plein, decoupe par le plan proche et par l'ecran }
Procedure DrawPoly3D(Const C:TCam;Var Pts:TPoly3;N:Integer;
                     Fill,Line:Integer);
Var
 Cv,Cw:Array[0..31] Of TVec;
 I,M,J:Integer;
 T:Real;
 SIn,EIn:Boolean;
Begin
 For I:=0 to N-1 do ToCam(C,Pts[I],Cv[I]);
 M:=0;
 For I:=0 to N-1 do Begin
  J:=(I+N-1)mod N;
  SIn:=Cv[J].Z>=NEAR_Z;
  EIn:=Cv[I].Z>=NEAR_Z;
  If SIn<>EIn Then Begin
   T:=(NEAR_Z-Cv[J].Z)/(Cv[I].Z-Cv[J].Z);
   Cw[M].X:=Cv[J].X+T*(Cv[I].X-Cv[J].X);
   Cw[M].Y:=Cv[J].Y+T*(Cv[I].Y-Cv[J].Y);
   Cw[M].Z:=NEAR_Z;
   Inc(M);
  End;
  If EIn Then Begin
   Cw[M]:=Cv[I];
   Inc(M);
  End;
 End;
 If M<3 Then Exit;
 For I:=0 to M-1 do Begin
  ClipA[I].X:=C.CX+C.Foc*Cw[I].X/Cw[I].Z;
  ClipA[I].Y:=C.CY-C.Foc*Cw[I].Y/Cw[I].Z;
 End;
 FillScreenPoly(M,Fill,Line);
End;

Function ClipT(P,Q:Real;Var T0,T1:Real):Boolean;
Var
 R:Real;
Begin
 ClipT:=True;
 If P=0.0 Then Begin
  If Q<0.0 Then ClipT:=False;
 End
  Else
 Begin
  R:=Q/P;
  If P<0.0 Then Begin
   If R>T1 Then ClipT:=False Else If R>T0 Then T0:=R;
  End
   Else
  Begin
   If R<T0 Then ClipT:=False Else If R<T1 Then T1:=R;
  End;
 End;
End;

{ Segment 3D }
Procedure DrawLine3D(Const C:TCam;Const A,B:TVec;Col:Integer);
Var
 QA,QB:TVec;
 T,X1,Y1,X2,Y2,DX,DY,T0,T1:Real;
Begin
 ToCam(C,A,QA);
 ToCam(C,B,QB);
 If(QA.Z<NEAR_Z)and(QB.Z<NEAR_Z)Then Exit;
 If QA.Z<NEAR_Z Then Begin
  T:=(NEAR_Z-QA.Z)/(QB.Z-QA.Z);
  QA.X:=QA.X+T*(QB.X-QA.X); QA.Y:=QA.Y+T*(QB.Y-QA.Y); QA.Z:=NEAR_Z;
 End
  Else
 If QB.Z<NEAR_Z Then Begin
  T:=(NEAR_Z-QB.Z)/(QA.Z-QB.Z);
  QB.X:=QB.X+T*(QA.X-QB.X); QB.Y:=QB.Y+T*(QA.Y-QB.Y); QB.Z:=NEAR_Z;
 End;
 X1:=C.CX+C.Foc*QA.X/QA.Z; Y1:=C.CY-C.Foc*QA.Y/QA.Z;
 X2:=C.CX+C.Foc*QB.X/QB.Z; Y2:=C.CY-C.Foc*QB.Y/QB.Z;
 DX:=X2-X1; DY:=Y2-Y1;
 T0:=0.0; T1:=1.0;
 If ClipT(-DX,X1-VX1,T0,T1)and ClipT(DX,VX2-X1,T0,T1)and
    ClipT(-DY,Y1-VY1,T0,T1)and ClipT(DY,VY2-Y1,T0,T1)Then Begin
  SetColor(Col);
  Line(Round(X1+T0*DX),Round(Y1+T0*DY),Round(X1+T1*DX),Round(Y1+T1*DY));
 End;
End;

{ Point lumineux (feu de piste) }
Procedure DrawLight3D(Const C:TCam;Const P:TVec;Col:Integer;Size:Real);
Var
 SX,SY,Z:Real;
 R:Integer;
Begin
 If Not Proj(C,P,SX,SY,Z)Then Exit;
 If(SX<VX1+2)or(SX>VX2-2)or(SY<VY1+2)or(SY>VY2-2)Then Exit;
 R:=Round(Size*C.Foc/Z);
 If R>6 Then R:=6;
 If R<1 Then Begin
  PutPixel(Round(SX),Round(SY),Col);
  PutPixel(Round(SX)+1,Round(SY),Col);
  PutPixel(Round(SX),Round(SY)+1,Col);
  PutPixel(Round(SX)+1,Round(SY)+1,Col);
 End
  Else Begin
  SetColor(Col);
  SetFillStyle(SolidFill,Col);
  FillEllipse(Round(SX),Round(SY),R,R);
 End;
End;

{ Quadrilatere au sol }
Procedure GroundQuad(Const C:TCam;X1,Y1,X2,Y2,X3,Y3,X4,Y4,Z:Real;
                     Col,Line:Integer);
Var
 P:TPoly3;
Begin
 VSet(P[0],X1,Y1,Z); VSet(P[1],X2,Y2,Z);
 VSet(P[2],X3,Y3,Z); VSet(P[3],X4,Y4,Z);
 DrawPoly3D(C,P,4,Col,Line);
End;

{ Coordonnees locales de piste -> monde }
Procedure LocalToWorld(I:Integer;A,B,Z:Real;Var P:TVec);
Begin
 If Aps[I].AxisX Then VSet(P,Aps[I].X+A,Aps[I].Y+B,Z)
                 Else VSet(P,Aps[I].X+B,Aps[I].Y+A,Z);
End;

{ Rectangle [A1,A2]x[B1,B2] dans le repere de la piste }
Procedure LQuad(Const C:TCam;I:Integer;A1,B1,A2,B2:Real;Col:Integer);
Var
 P:TPoly3;
Begin
 LocalToWorld(I,A1,B1,0.1,P[0]);
 LocalToWorld(I,A2,B1,0.1,P[1]);
 LocalToWorld(I,A2,B2,0.1,P[2]);
 LocalToWorld(I,A1,B2,0.1,P[3]);
 DrawPoly3D(C,P,4,Col,-1);
End;

{ ------------------------------------------------------------------ }
{ Ciel, sol, champs, lacs                                            }
{ ------------------------------------------------------------------ }

Procedure DrawSky(Const C:TCam);
Var
 A,B,C0,G0v,G1v:Real;
 I,J,M:Integer;
 Q:TVec;
 SX,SY,Z:Real;
 V:TVec;
 SkyCol,GndCol:Integer;
Begin
 If Night Then Begin SkyCol:=Black; GndCol:=Black; End
          Else Begin SkyCol:=LightCyan; GndCol:=Green; End;
 SetFillStyle(SolidFill,SkyCol);
 Bar(VX1,VY1,VX2,VY2);

 { le sol est le demi-plan ou  A*sx + B*sy + C0 < 0 }
 A:=C.R.Z/C.Foc;
 B:=-C.U.Z/C.Foc;
 C0:=-C.CX*C.R.Z/C.Foc+C.CY*C.U.Z/C.Foc+C.F.Z;
 ClipB[0].X:=VX1; ClipB[0].Y:=VY1;
 ClipB[1].X:=VX2; ClipB[1].Y:=VY1;
 ClipB[2].X:=VX2; ClipB[2].Y:=VY2;
 ClipB[3].X:=VX1; ClipB[3].Y:=VY2;
 M:=0;
 For I:=0 to 3 do Begin
  J:=(I+3)mod 4;
  G0v:=A*ClipB[J].X+B*ClipB[J].Y+C0;
  G1v:=A*ClipB[I].X+B*ClipB[I].Y+C0;
  If(G0v<=0.0)<>(G1v<=0.0)Then Begin
   Z:=G0v/(G0v-G1v);
   ClipA[M].X:=ClipB[J].X+Z*(ClipB[I].X-ClipB[J].X);
   ClipA[M].Y:=ClipB[J].Y+Z*(ClipB[I].Y-ClipB[J].Y);
   Inc(M);
  End;
  If G1v<=0.0 Then Begin
   ClipA[M]:=ClipB[I];
   Inc(M);
  End;
 End;
 If M>=3 Then FillScreenPoly(M,GndCol,-1);

 If Night Then Begin
  For I:=0 to MAX_STAR-1 do Begin
   VSet(V,C.P.X+Stars[I].X*1000.0,C.P.Y+Stars[I].Y*1000.0,
        C.P.Z+Stars[I].Z*1000.0);
   If Proj(C,V,SX,SY,Z)Then
    If(SX>=VX1)and(SX<=VX2)and(SY>=VY1)and(SY<=VY2)Then
     If A*SX+B*SY+C0>0.0 Then PutPixel(Round(SX),Round(SY),White);
  End;
 End
  Else
 Begin
  VSet(V,C.P.X+Sun.X*50000.0,C.P.Y+Sun.Y*50000.0,C.P.Z+Sun.Z*50000.0);
  If Proj(C,V,SX,SY,Z)Then
   If(SX>VX1-20)and(SX<VX2+20)and(SY>VY1-20)and(SY<VY2+20)Then Begin
    SetFillStyle(SolidFill,Yellow);
    SetColor(Yellow);
    FillEllipse(Round(SX),Round(SY),12,12);
   End;
 End;
End;

{ Un point est-il proche d'un aeroport ? }
Function NearAirport(X,Y,Margin:Real):Boolean;
Var
 I:Integer;
Begin
 NearAirport:=False;
 For I:=0 to NB_AIRPORT-1 do
  If(Abs(X-Aps[I].X)<Aps[I].Len/2.0+Margin+300.0)and
    (Abs(Y-Aps[I].Y)<Aps[I].Len/2.0+Margin+300.0)Then NearAirport:=True;
End;

{ Champs : damier de grandes parcelles }
Procedure DrawFields(Const C:TCam);
Var
 CS,R,CXc,CYc,H:Real;
 IX,IY,AX,AY,N,Hs:LongInt;
 Q,V:TVec;
 Col:Integer;
 Lim:Real;
Begin
 If Night or(OptDetail<2)Then Exit;
 If OptDetail=2 Then Begin CS:=1200.0; R:=9000.0; End
                Else Begin CS:=800.0;  R:=8000.0; End;
 If C.P.Z>2500.0 Then Begin CS:=CS*2.0; R:=R*2.0; End;
 AX:=Trunc(C.P.X/CS);
 AY:=Trunc(C.P.Y/CS);
 N:=Trunc(R/CS)+1;
 For IX:=AX-N to AX+N do
  For IY:=AY-N to AY+N do Begin
   Hs:=Abs(IX*7+IY*13+IX*IY*3)mod 12;
   If Hs<5 Then Continue;
   If Hs<9 Then Col:=LightGreen Else If Hs<11 Then Col:=Brown
                                                Else Col:=Yellow;
   CXc:=(IX+0.5)*CS; CYc:=(IY+0.5)*CS;
   If Sqr(CXc-C.P.X)+Sqr(CYc-C.P.Y)>R*R Then Continue;
   If NearAirport(CXc,CYc,CS)Then Continue;
   VSet(V,CXc,CYc,0.0);
   ToCam(C,V,Q);
   If Q.Z<-CS Then Continue;
   Lim:=0.7*Q.Z+CS*1.5;
   If Abs(Q.X)>Lim Then Continue;
   GroundQuad(C,IX*CS,IY*CS,(IX+1)*CS,IY*CS,(IX+1)*CS,(IY+1)*CS,
              IX*CS,(IY+1)*CS,0.0,Col,-1);
  End;
End;

Procedure DrawLakes(Const C:TCam);
Var
 I,K:Integer;
 P:TPoly3;
 A,D:Real;
 Col:Integer;
Begin
 If Night Then Col:=Blue Else Col:=Blue;
 For I:=0 to MAX_LAKE-1 do Begin
  D:=Sqrt(Sqr(Lakes[I].X-C.P.X)+Sqr(Lakes[I].Y-C.P.Y));
  If D>Lakes[I].RX+60000.0 Then Continue;
  For K:=0 to 13 do Begin
   A:=K*2.0*Pi/14.0;
   VSet(P[K],Lakes[I].X+Cos(A)*Lakes[I].RX*(1.0+0.12*Sin(3.0*A)),
        Lakes[I].Y+Sin(A)*Lakes[I].RY*(1.0+0.12*Cos(2.0*A)),0.05);
  End;
  DrawPoly3D(C,P,14,Col,-1);
 End;
End;

{ ------------------------------------------------------------------ }
{ Aeroports                                                          }
{ ------------------------------------------------------------------ }

Procedure DrawAirport(Const C:TCam;I:Integer);
Var
 D,L,W,T,HL:Real;
 K:Integer;
 P:TVec;
 Near,Mid:Boolean;
 Gr:Integer;
Begin
 D:=Sqrt(Sqr(Aps[I].X-C.P.X)+Sqr(Aps[I].Y-C.P.Y));
 If D>90000.0 Then Exit;
 L:=Aps[I].Len; W:=Aps[I].Wid; HL:=L/2.0;
 Near:=(D<L/2.0+7000.0);
 Mid:=(D<L/2.0+16000.0);

 { aire de stationnement et bretelles }
 If Mid Then Begin
  LQuad(C,I,-300.0,50.0,300.0,160.0,LightGray);
  LQuad(C,I,108.0,W/2.0-1.0,132.0,52.0,LightGray);
  LQuad(C,I,-HL*0.6-12.0,W/2.0-1.0,-HL*0.6+12.0,52.0,LightGray);
 End;
 { piste }
 LQuad(C,I,-HL,-W/2.0,HL,W/2.0,DarkGray);

 If Mid Then Begin
  { lignes de rive }
  LQuad(C,I,-HL+3.0,-W/2.0+0.6,HL-3.0,-W/2.0+1.5,White);
  LQuad(C,I,-HL+3.0,W/2.0-1.5,HL-3.0,W/2.0-0.6,White);
  { seuils }
  For K:=-3 to 3 do
   If K<>0 Then Begin
    T:=K*(W/9.0);
    LQuad(C,I,-HL+6.0,T-1.0,-HL+36.0,T+1.0,White);
    LQuad(C,I,HL-36.0,T-1.0,HL-6.0,T+1.0,White);
   End;
 End;
 If Near Then Begin
  { axe de piste en tirets }
  T:=-HL+60.0;
  While T<HL-90.0 do Begin
   LQuad(C,I,T,-0.5,T+30.0,0.5,White);
   T:=T+60.0;
  End;
  { point de vise }
  LQuad(C,I,-HL+300.0,W/6.0,-HL+345.0,W/6.0+3.0,White);
  LQuad(C,I,-HL+300.0,-W/6.0-3.0,-HL+345.0,-W/6.0,White);
  LQuad(C,I,HL-345.0,W/6.0,HL-300.0,W/6.0+3.0,White);
  LQuad(C,I,HL-345.0,-W/6.0-3.0,HL-300.0,-W/6.0,White);
 End;

 { feux de nuit }
 If Night and(D<30000.0)Then Begin
  T:=-HL;
  While T<=HL do Begin
   If T<-HL+100.0 Then Gr:=LightGreen Else
   If T>HL-100.0 Then Gr:=LightRed Else Gr:=White;
   LocalToWorld(I,T,-W/2.0-1.0,1.0,P);
   DrawLight3D(C,P,Gr,0.6);
   LocalToWorld(I,T,W/2.0+1.0,1.0,P);
   DrawLight3D(C,P,Gr,0.6);
   LocalToWorld(I,T,0.0,1.0,P);
   DrawLight3D(C,P,White,0.5);
   T:=T+60.0;
  End;
  { rampes d'approche }
  For K:=1 to 20 do Begin
   LocalToWorld(I,-HL-K*30.0,0.0,1.0,P);
   DrawLight3D(C,P,White,0.7);
   LocalToWorld(I,HL+K*30.0,0.0,1.0,P);
   DrawLight3D(C,P,White,0.7);
   If K mod 5=0 Then Begin
    LocalToWorld(I,-HL-K*30.0,6.0,1.0,P); DrawLight3D(C,P,White,0.7);
    LocalToWorld(I,-HL-K*30.0,-6.0,1.0,P); DrawLight3D(C,P,White,0.7);
    LocalToWorld(I,HL+K*30.0,6.0,1.0,P); DrawLight3D(C,P,White,0.7);
    LocalToWorld(I,HL+K*30.0,-6.0,1.0,P); DrawLight3D(C,P,White,0.7);
   End;
  End;
  LocalToWorld(I,120.0,175.0,48.0,P);
  If Odd(FrameNo div 8)Then DrawLight3D(C,P,LightRed,1.5);
 End;
End;

{ ------------------------------------------------------------------ }
{ Relief, batiments, nuages                                         }
{ ------------------------------------------------------------------ }

Procedure DrawMountain(Const C:TCam;I:Integer);
Const
 NSEG = 10;
Var
 K:Integer;
 A0,A1,Am,R,H,NX,NY,NZ,NL,S:Real;
 MX,MY:Real;
 Ap,FC:TVec;
 P:TPoly3;
 CL,CU,CC,OL:Integer;
Begin
 MX:=Mtns[I].X; MY:=Mtns[I].Y; R:=Mtns[I].R; H:=Mtns[I].H;
 VSet(Ap,MX,MY,H);
 For K:=0 to NSEG-1 do Begin
  A0:=K*2.0*Pi/NSEG;
  A1:=(K+1)*2.0*Pi/NSEG;
  Am:=(A0+A1)/2.0;
  NX:=H*Cos(Am); NY:=H*Sin(Am); NZ:=R;
  NL:=Sqrt(NX*NX+NY*NY+NZ*NZ);
  NX:=NX/NL; NY:=NY/NL; NZ:=NZ/NL;
  VSet(FC,MX+0.8*R*Cos(Am),MY+0.8*R*Sin(Am),0.2*H);
  If(C.P.X-FC.X)*NX+(C.P.Y-FC.Y)*NY+(C.P.Z-FC.Z)*NZ<=0.0 Then Continue;
  S:=NX*Sun.X+NY*Sun.Y+NZ*Sun.Z;
  If Night Then Begin
   CL:=Black; CU:=Black; CC:=Black; OL:=DarkGray;
  End
   Else
  Begin
   OL:=-1;
   If S>0.45 Then Begin CL:=Brown; CU:=LightGray; CC:=White; End Else
   If S>0.1  Then Begin CL:=Green; CU:=Brown;     CC:=LightGray; End
            Else Begin CL:=DarkGray; CU:=DarkGray; CC:=LightGray; End;
   If H<1900.0 Then CC:=CU;
  End;
  { pente basse }
  VSet(P[0],MX+R*Cos(A0),MY+R*Sin(A0),0.0);
  VSet(P[1],MX+R*Cos(A1),MY+R*Sin(A1),0.0);
  VSet(P[2],MX+0.62*R*Cos(A1),MY+0.62*R*Sin(A1),0.38*H);
  VSet(P[3],MX+0.62*R*Cos(A0),MY+0.62*R*Sin(A0),0.38*H);
  DrawPoly3D(C,P,4,CL,OL);
  { pente haute }
  VSet(P[0],MX+0.62*R*Cos(A0),MY+0.62*R*Sin(A0),0.38*H);
  VSet(P[1],MX+0.62*R*Cos(A1),MY+0.62*R*Sin(A1),0.38*H);
  VSet(P[2],MX+0.2*R*Cos(A1),MY+0.2*R*Sin(A1),0.8*H);
  VSet(P[3],MX+0.2*R*Cos(A0),MY+0.2*R*Sin(A0),0.8*H);
  DrawPoly3D(C,P,4,CU,OL);
  { sommet }
  VSet(P[0],MX+0.2*R*Cos(A0),MY+0.2*R*Sin(A0),0.8*H);
  VSet(P[1],MX+0.2*R*Cos(A1),MY+0.2*R*Sin(A1),0.8*H);
  P[2]:=Ap;
  DrawPoly3D(C,P,3,CC,OL);
 End;
End;

Procedure DrawBuilding(Const C:TCam;I:Integer);
Var
 X0,X1,Y0,Y1,ZB,ZT,D:Real;
 P:TPoly3;
 Col,Roof,Lit,Shade,OL:Integer;
 K,J:Integer;
 Q:TVec;
 L:TVec;
Begin
 X0:=Blds[I].X-Blds[I].W/2.0; X1:=Blds[I].X+Blds[I].W/2.0;
 Y0:=Blds[I].Y-Blds[I].D/2.0; Y1:=Blds[I].Y+Blds[I].D/2.0;
 ZB:=Blds[I].Z0; ZT:=Blds[I].Z0+Blds[I].H;
 Col:=Blds[I].Col; Roof:=Blds[I].Roof;
 If Night Then Begin
  Lit:=Black; Shade:=Black; Roof:=DarkGray; OL:=DarkGray;
 End
  Else
 Begin
  Lit:=Col; Shade:=DarkOf(Col); OL:=DarkOf(Shade);
 End;
 { cote +X (eclaire) }
 If C.P.X>X1 Then Begin
  VSet(P[0],X1,Y0,ZB); VSet(P[1],X1,Y1,ZB);
  VSet(P[2],X1,Y1,ZT); VSet(P[3],X1,Y0,ZT);
  DrawPoly3D(C,P,4,Lit,OL);
 End;
 { cote -X (ombre) }
 If C.P.X<X0 Then Begin
  VSet(P[0],X0,Y0,ZB); VSet(P[1],X0,Y1,ZB);
  VSet(P[2],X0,Y1,ZT); VSet(P[3],X0,Y0,ZT);
  DrawPoly3D(C,P,4,Shade,OL);
 End;
 { cote -Y (eclaire) }
 If C.P.Y<Y0 Then Begin
  VSet(P[0],X0,Y0,ZB); VSet(P[1],X1,Y0,ZB);
  VSet(P[2],X1,Y0,ZT); VSet(P[3],X0,Y0,ZT);
  DrawPoly3D(C,P,4,Lit,OL);
 End;
 { cote +Y (ombre) }
 If C.P.Y>Y1 Then Begin
  VSet(P[0],X0,Y1,ZB); VSet(P[1],X1,Y1,ZB);
  VSet(P[2],X1,Y1,ZT); VSet(P[3],X0,Y1,ZT);
  DrawPoly3D(C,P,4,Shade,OL);
 End;
 { toit }
 If C.P.Z>ZT Then Begin
  VSet(P[0],X0,Y0,ZT); VSet(P[1],X1,Y0,ZT);
  VSet(P[2],X1,Y1,ZT); VSet(P[3],X0,Y1,ZT);
  DrawPoly3D(C,P,4,Roof,OL);
 End;
 { fenetres et feux la nuit }
 If Night Then Begin
  D:=Sqrt(Sqr(C.P.X-Blds[I].X)+Sqr(C.P.Y-Blds[I].Y));
  If D<7000.0 Then Begin
   For K:=1 to Trunc(Blds[I].H/7.0) do
    For J:=0 to 2 do Begin
     If((I*5+K*3+J)mod 3)=0 Then Continue;
     If C.P.X>X1 Then
      VSet(L,X1+0.2,Y0+(J+0.5)*(Y1-Y0)/3.0,ZB+K*6.0-2.0)
     Else
      VSet(L,X0+(J+0.5)*(X1-X0)/3.0,Y0-0.2,ZB+K*6.0-2.0);
     DrawLight3D(C,L,Yellow,0.5);
    End;
   If Blds[I].H>30.0 Then Begin
    VSet(L,Blds[I].X,Blds[I].Y,ZT+3.0);
    DrawLight3D(C,L,LightRed,1.0);
   End;
  End;
 End;
End;

Procedure DrawCloud(Const C:TCam;I:Integer);
Var
 K:Integer;
 V:TVec;
 SX,SY,Z,R:Real;
 RR,XR:Integer;
Begin
 For K:=0 to 2 do Begin
  VSet(V,Clds[I].X+C.R.X*(K-1)*Clds[I].R*0.7,
         Clds[I].Y+C.R.Y*(K-1)*Clds[I].R*0.7,
         Clds[I].Z+(K mod 2)*Clds[I].R*0.15);
  If Proj(C,V,SX,SY,Z)Then Begin
   R:=Clds[I].R*0.75*C.Foc/Z;
   If R>2000.0 Then R:=2000.0;
   XR:=Round(R);
   RR:=Round(R*0.45);
   If XR<1 Then Continue;
   If Night Then Begin
    SetFillStyle(SolidFill,DarkGray); SetColor(DarkGray);
   End
    Else
   Begin
    SetFillStyle(SolidFill,LightGray); SetColor(LightGray);
   End;
   FillEllipse(Round(SX),Round(SY+R*0.12),XR,RR);
   If Not Night Then Begin
    SetFillStyle(SolidFill,White); SetColor(White);
   End;
   FillEllipse(Round(SX),Round(SY-R*0.05),Round(R*0.9),Round(R*0.4));
  End;
 End;
End;

{ ------------------------------------------------------------------ }
{ Modele 3D de l'avion                                               }
{ ------------------------------------------------------------------ }

Type
 TMPoly = Record
  N    : Integer;
  P    : Array[0..3] Of TVec;
  Col  : Integer;
  Line : Integer;
  Key  : Real;
 End;

Var
 MP  : Array[0..79] Of TMPoly;
 MPN : Integer;
 MPO : Array[0..79] Of Integer;
 MBase : TFlt;

Procedure LocW(Lx,Ly,Lz:Real;Var W:TVec);
Begin
 W.X:=MBase.P.X+MBase.F.X*Lx+MBase.R.X*Ly+MBase.U.X*Lz;
 W.Y:=MBase.P.Y+MBase.F.Y*Lx+MBase.R.Y*Ly+MBase.U.Y*Lz;
 W.Z:=MBase.P.Z+MBase.F.Z*Lx+MBase.R.Z*Ly+MBase.U.Z*Lz;
End;

Procedure AddQ(X1,Y1,Z1,X2,Y2,Z2,X3,Y3,Z3,X4,Y4,Z4:Real;Col,Line:Integer);
Begin
 If MPN>=80 Then Exit;
 MP[MPN].N:=4;
 LocW(X1,Y1,Z1,MP[MPN].P[0]);
 LocW(X2,Y2,Z2,MP[MPN].P[1]);
 LocW(X3,Y3,Z3,MP[MPN].P[2]);
 LocW(X4,Y4,Z4,MP[MPN].P[3]);
 MP[MPN].Col:=Col; MP[MPN].Line:=Line;
 Inc(MPN);
End;

Procedure AddT(X1,Y1,Z1,X2,Y2,Z2,X3,Y3,Z3:Real;Col,Line:Integer);
Begin
 If MPN>=80 Then Exit;
 MP[MPN].N:=3;
 LocW(X1,Y1,Z1,MP[MPN].P[0]);
 LocW(X2,Y2,Z2,MP[MPN].P[1]);
 LocW(X3,Y3,Z3,MP[MPN].P[2]);
 MP[MPN].Col:=Col; MP[MPN].Line:=Line;
 Inc(MPN);
End;

{ Boite orientee (moteurs) : 4 faces laterales }
Procedure AddEngine(CX,CY,CZ,L,Rd:Real;Col:Integer);
Begin
 AddQ(CX+L,CY-Rd,CZ+Rd, CX+L,CY+Rd,CZ+Rd, CX-L,CY+Rd,CZ+Rd,
      CX-L,CY-Rd,CZ+Rd,Col,DarkGray);
 AddQ(CX+L,CY-Rd,CZ-Rd, CX+L,CY+Rd,CZ-Rd, CX-L,CY+Rd,CZ-Rd,
      CX-L,CY-Rd,CZ-Rd,DarkOf(Col),DarkGray);
 AddQ(CX+L,CY+Rd,CZ-Rd, CX+L,CY+Rd,CZ+Rd, CX-L,CY+Rd,CZ+Rd,
      CX-L,CY+Rd,CZ-Rd,Col,DarkGray);
 AddQ(CX+L,CY-Rd,CZ-Rd, CX+L,CY-Rd,CZ+Rd, CX-L,CY-Rd,CZ+Rd,
      CX-L,CY-Rd,CZ-Rd,Col,DarkGray);
 AddQ(CX+L,CY-Rd,CZ-Rd, CX+L,CY+Rd,CZ-Rd, CX+L,CY+Rd,CZ+Rd,
      CX+L,CY-Rd,CZ+Rd,Black,DarkGray);
End;

{ Helice : deux pales tournantes dans le plan Y-Z }
Procedure AddProp(CX,CY,CZ,Rad:Real);
Var
 Ang:Real;
Begin
 If MBase.Spool>0.1 Then Ang:=FrameNo*0.9 Else Ang:=0.6;
 AddQ(CX,CY+Sin(Ang)*Rad,CZ+Cos(Ang)*Rad,
      CX,CY+Sin(Ang)*Rad*0.9+0.1*Rad,CZ+Cos(Ang)*Rad*0.9,
      CX,CY-Sin(Ang)*Rad,CZ-Cos(Ang)*Rad,
      CX,CY-Sin(Ang)*Rad*0.9-0.1*Rad,CZ-Cos(Ang)*Rad*0.9,DarkGray,-1);
End;

{ Construit les polygones de l'avion a partir de sa fiche }
Procedure BuildPlane(Var F:TFlt);
Var
 Sp:TSpec;
 L,Sx,Rf,Sw,Zw,Ts,HF,Cm,Cr,Ct,Xle,Yk,Xk,Hl,Rd,Ang:Real;
 WC,K,N,Pairs:Integer;
Begin
 Sp:=Specs[F.Spec];
 MBase:=F;
 MPN:=0;
 L:=Sp.Len;
 Sx:=Sp.Span/2.0;
 { rayon du fuselage }
 Case Sp.Cat of
  'C':Rf:=L*0.12;
  'A','R','U':Rf:=L*0.05;
  'J':If(Sp.NEng>=2)and(Sp.MTow>20000.0)Then Rf:=L*0.075 Else Rf:=L*0.06;
  'G','H':Rf:=L*0.06;
  Else If Sp.NEng=1 Then Rf:=L*0.09 Else Rf:=L*0.07;
 End;
 WC:=DarkOf(Sp.Col1);
 If WC=Black Then WC:=DarkGray;

 { fuselage }
 AddT(0.5*L,0,0, 0.28*L,0,Rf, 0.28*L,Rf,0, Sp.Col2,-1);
 AddT(0.5*L,0,0, 0.28*L,Rf,0, 0.28*L,0,-Rf, Sp.Col2,-1);
 AddT(0.5*L,0,0, 0.28*L,0,-Rf, 0.28*L,-Rf,0, Sp.Col2,-1);
 AddT(0.5*L,0,0, 0.28*L,-Rf,0, 0.28*L,0,Rf, Sp.Col2,-1);
 AddQ(0.28*L,0,Rf, 0.28*L,Rf,0, -0.3*L,0.55*Rf,0.02*L,
      -0.3*L,0,0.55*Rf+0.02*L, Sp.Col1,-1);
 AddQ(0.28*L,Rf,0, 0.28*L,0,-Rf, -0.3*L,0,-0.55*Rf+0.02*L,
      -0.3*L,0.55*Rf,0.02*L, Sp.Col1,-1);
 AddQ(0.28*L,0,-Rf, 0.28*L,-Rf,0, -0.3*L,-0.55*Rf,0.02*L,
      -0.3*L,0,-0.55*Rf+0.02*L, DarkOf(Sp.Col1),-1);
 AddQ(0.28*L,-Rf,0, 0.28*L,0,Rf, -0.3*L,0,0.55*Rf+0.02*L,
      -0.3*L,-0.55*Rf,0.02*L, Sp.Col1,-1);
 AddT(-0.3*L,0,0.55*Rf+0.02*L, -0.3*L,0.55*Rf,0.02*L, -0.5*L,0,0.04*L,
      Sp.Col1,-1);
 AddT(-0.3*L,0.55*Rf,0.02*L, -0.3*L,0,-0.55*Rf+0.02*L, -0.5*L,0,0.04*L,
      Sp.Col1,-1);
 AddT(-0.3*L,0,-0.55*Rf+0.02*L, -0.3*L,-0.55*Rf,0.02*L, -0.5*L,0,0.04*L,
      DarkOf(Sp.Col1),-1);
 AddT(-0.3*L,-0.55*Rf,0.02*L, -0.3*L,0,0.55*Rf+0.02*L, -0.5*L,0,0.04*L,
      Sp.Col1,-1);

 { ailes : surface, fleche et position tirees de la fiche }
 If Sp.Cat<>'C' Then Begin
  Cm:=Sp.S/Sp.Span;
  If Sp.Delta Then Begin
   Cr:=MinR(0.65*L,1.9*Cm); Ct:=0.1*Cm;
  End
   Else Begin
    Cr:=MinR(0.4*L,1.6*Cm); Ct:=0.4*Cm;
   End;
  Sw:=Sx*Tan(Sp.Sweep*Pi/180.0)+(Cr-Ct)/4.0;
  If Sw>0.35*L Then Sw:=0.35*L;
  If Sp.Delta Then Xle:=-0.45*L+Cr Else
  If Sp.Cat in['A','R','U']Then Xle:=0.02*L+Cr*0.3 Else
  If Sp.Sweep>20.0 Then Xle:=0.12*L Else Xle:=0.16*L;
  If Sp.HighWing or Sp.Float Then Zw:=0.7*Rf Else
  If(Sp.Cat='J')and(Sp.MTow>20000.0)Then Zw:=-0.5*Rf Else Zw:=-0.15*Rf;
  If Sp.Wings>=2 Then Zw:=-0.4*Rf;
  If Sx<0.9*Rf Then Sx:=0.9*Rf;
  AddQ(Xle,0.8*Rf,Zw, Xle-Sw,Sx,Zw+0.03*Sx, Xle-Sw-Ct,Sx,Zw+0.03*Sx,
       Xle-Cr,0.8*Rf,Zw, WC,DarkGray);
  AddQ(Xle,-0.8*Rf,Zw, Xle-Sw,-Sx,Zw+0.03*Sx, Xle-Sw-Ct,-Sx,Zw+0.03*Sx,
       Xle-Cr,-0.8*Rf,Zw, WC,DarkGray);
  If Sp.Wings>=2 Then Begin
   AddQ(Xle,0.8*Rf,Rf*1.1, Xle,Sx*0.9,Rf*1.1, Xle-Cr,Sx*0.9,Rf*1.1,
        Xle-Cr,0.8*Rf,Rf*1.1, WC,DarkGray);
   AddQ(Xle,-0.8*Rf,Rf*1.1, Xle,-Sx*0.9,Rf*1.1, Xle-Cr,-Sx*0.9,Rf*1.1,
        Xle-Cr,-0.8*Rf,Rf*1.1, WC,DarkGray);
  End;
 End;

 { empennage }
 If Sp.Cat in['C','A','J','R','U']Then HF:=L*0.15 Else HF:=L*0.14;
 If Not Sp.Delta Then Begin
  Ts:=MaxR(Sx*0.35,Sp.Span*0.12);
  If Sp.Cat='C' Then Ts:=Rf*0.7;
  AddQ(-0.38*L,0.3*Rf,0.03*L, -0.42*L,Ts,0.03*L, -0.48*L,Ts,0.03*L,
       -0.48*L,0.3*Rf,0.03*L, WC,DarkGray);
  AddQ(-0.38*L,-0.3*Rf,0.03*L, -0.42*L,-Ts,0.03*L, -0.48*L,-Ts,0.03*L,
       -0.48*L,-0.3*Rf,0.03*L, WC,DarkGray);
 End;
 AddQ(-0.33*L,0,0.5*Rf, -0.48*L,0,0.5*Rf, -0.5*L,0,HF, -0.44*L,0,HF,
      Sp.Col2,DarkGray);

 { moteurs }
 N:=Sp.NEng;
 If N>6 Then N:=6;
 If Sp.Cat='C' Then Begin
  { rotor principal }
  If F.Spool>0.1 Then Ang:=FrameNo*0.7 Else Ang:=0.4;
  AddQ(Cos(Ang)*Sx,Sin(Ang)*Sx,Rf*1.4,
       Cos(Ang)*Sx-0.04*Sx*Sin(Ang),Sin(Ang)*Sx+0.04*Sx*Cos(Ang),Rf*1.4,
       -Cos(Ang)*Sx+0.04*Sx*Sin(Ang),-Sin(Ang)*Sx-0.04*Sx*Cos(Ang),Rf*1.4,
       -Cos(Ang)*Sx,-Sin(Ang)*Sx,Rf*1.4,DarkGray,-1);
 End
  Else
 If Sp.Cat in['P','T','H']Then Begin
  If(N=1)or Odd(N)Then AddProp(0.52*L,0,0,Rf*1.7);
  Pairs:=N div 2;
  If Sp.Cat='H' Then Pairs:=0;
  Hl:=0.045*L; Rd:=0.022*L;
  If Rd<0.25 Then Rd:=0.25;
  If Hl<0.5 Then Hl:=0.5;
  For K:=0 to Pairs-1 do Begin
   Yk:=Sx*(0.22+0.2*K);
   Xk:=Xle-Sw*Yk/Sx+0.02*L;
   AddEngine(Xk,Yk,Zw-0.1*Rf,Hl,Rd,WC);
   AddEngine(Xk,-Yk,Zw-0.1*Rf,Hl,Rd,WC);
   AddProp(Xk+Hl+0.01*L,Yk,Zw-0.1*Rf,Rd*2.2);
   AddProp(Xk+Hl+0.01*L,-Yk,Zw-0.1*Rf,Rd*2.2);
  End;
 End
  Else
 If(Sp.Cat='J')and(N>=2)and(Sp.MTow>20000.0)Then Begin
  Hl:=0.045*L; Rd:=0.022*L;
  For K:=0 to (N div 2)-1 do Begin
   Yk:=Sx*(0.28+0.18*K);
   Xk:=Xle-Sw*Yk/Sx+0.02*L;
   AddEngine(Xk,Yk,Zw-1.6*Rd,Hl,Rd,WC);
   AddEngine(Xk,-Yk,Zw-1.6*Rd,Hl,Rd,WC);
  End;
 End;

 { flotteurs ou coque }
 If Sp.Float Then Begin
  If Sp.MTow<8000.0 Then Begin
   AddEngine(0.0,0.28*Sx,Zw-Rf*1.4,0.28*L,0.04*L,LightGray);
   AddEngine(0.0,-0.28*Sx,Zw-Rf*1.4,0.28*L,0.04*L,LightGray);
  End
   Else Begin
    AddEngine(0.05*L,0.92*Sx,Zw-0.02*L,0.05*L,0.015*L,LightGray);
    AddEngine(0.05*L,-0.92*Sx,Zw-0.02*L,0.05*L,0.015*L,LightGray);
   End;
 End;
End;

Procedure SortAndDrawModel(Const C:TCam);
Var
 I,J,T:Integer;
 Q:TVec;
 K:Integer;
 Pts:TPoly3;
 Sum:Real;
Begin
 For I:=0 to MPN-1 do Begin
  Sum:=0.0;
  For K:=0 to MP[I].N-1 do Begin
   ToCam(C,MP[I].P[K],Q);
   Sum:=Sum+Q.Z;
  End;
  MP[I].Key:=Sum/MP[I].N;
  MPO[I]:=I;
 End;
 For I:=1 to MPN-1 do Begin
  T:=MPO[I];
  J:=I-1;
  While(J>=0)and(MP[MPO[J]].Key<MP[T].Key)do Begin
   MPO[J+1]:=MPO[J];
   Dec(J);
  End;
  MPO[J+1]:=T;
 End;
 For I:=0 to MPN-1 do Begin
  T:=MPO[I];
  For K:=0 to MP[T].N-1 do Pts[K]:=MP[T].P[K];
  DrawPoly3D(C,Pts,MP[T].N,MP[T].Col,MP[T].Line);
 End;
End;

Procedure DrawPlane(Const C:TCam;Var F:TFlt);
Var
 Sp:TSpec;
 A,B,P:TVec;
 K:Integer;
 Sh:TPoly3;
 Ang,R:Real;
Begin
 Sp:=Specs[F.Spec];
 { ombre au sol }
 R:=Sp.Span*0.5;
 For K:=0 to 9 do Begin
  Ang:=K*2.0*Pi/10.0;
  VSet(Sh[K],F.P.X+Cos(Ang)*R,F.P.Y+Sin(Ang)*R*0.6,
       TerrainH(F.P.X,F.P.Y)+0.2);
 End;
 If(Not Night)and(Not InLake(F.P.X,F.P.Y))Then
  DrawPoly3D(C,Sh,10,DarkGray,-1);
 BuildPlane(F);
 SortAndDrawModel(C);
 { train d'atterrissage }
 If(F.GearPos>0.5)and((Not Sp.Float)or Sp.Amph)Then Begin
  LocW(0.05*Sp.Len,0.2*Sp.Span/2.0,-Sp.GearH*0.2,A);
  LocW(0.05*Sp.Len,0.2*Sp.Span/2.0,-Sp.GearH,B);
  DrawLine3D(C,A,B,Black);
  LocW(0.05*Sp.Len,-0.2*Sp.Span/2.0,-Sp.GearH*0.2,A);
  LocW(0.05*Sp.Len,-0.2*Sp.Span/2.0,-Sp.GearH,B);
  DrawLine3D(C,A,B,Black);
  LocW(0.3*Sp.Len,0,-Sp.GearH*0.2,A);
  LocW(0.3*Sp.Len,0,-Sp.GearH,B);
  DrawLine3D(C,A,B,Black);
 End;
End;

{ ------------------------------------------------------------------ }
{ Camera et scene                                                    }
{ ------------------------------------------------------------------ }

Procedure LookAt(Var C:TCam;Const Tgt:TVec);
Var
 Z:TVec;
Begin
 C.F.X:=Tgt.X-C.P.X; C.F.Y:=Tgt.Y-C.P.Y; C.F.Z:=Tgt.Z-C.P.Z;
 VNormalize(C.F);
 VSet(Z,0.0,0.0,1.0);
 VCross(C.F,Z,C.R);
 If Sqrt(Dot(C.R,C.R))<0.01 Then VSet(C.R,1.0,0.0,0.0);
 VNormalize(C.R);
 VCross(C.R,C.F,C.U);
End;

Function NearestAirport(Const P:TVec):Integer;
Var
 I,Best:Integer;
 D,BD:Real;
Begin
 Best:=0; BD:=1E30;
 For I:=0 to NB_AIRPORT-1 do Begin
  D:=Sqr(Aps[I].X-P.X)+Sqr(Aps[I].Y-P.Y);
  If D<BD Then Begin BD:=D; Best:=I; End;
 End;
 NearestAirport:=Best;
End;

Procedure BuildCamera(Var C:TCam;Var F:TFlt);
Var
 Sp:TSpec;
 Tw:TVec;
 D,Dist:Real;
 Ap:Integer;
Begin
 Sp:=Specs[F.Spec];
 C.Foc:=FOC0;
 C.CX:=SCR_W/2.0;
 C.CY:=VIEW_H/2.0;
 Case ViewMode of
  VIEW_CHASE:Begin
     Dist:=Sp.Len*2.0+5.0;
     C.P.X:=F.P.X-F.F.X*Dist;
     C.P.Y:=F.P.Y-F.F.Y*Dist;
     C.P.Z:=F.P.Z-F.F.Z*Dist+Dist*0.3;
     LookAt(C,F.P);
    End;
  VIEW_TOWER:Begin
     Ap:=NearestAirport(F.P);
     LocalToWorld(Ap,120.0,175.0,43.0,Tw);
     C.P:=Tw;
     D:=Sqrt(Sqr(F.P.X-Tw.X)+Sqr(F.P.Y-Tw.Y)+Sqr(F.P.Z-Tw.Z));
     If D>60000.0 Then Begin
      Dist:=Sp.Len*2.0+5.0;
      C.P.X:=F.P.X-F.F.X*Dist;
      C.P.Y:=F.P.Y-F.F.Y*Dist;
      C.P.Z:=F.P.Z-F.F.Z*Dist+Dist*0.3;
     End
      Else
     C.Foc:=FOC0*Clamp(D/(Sp.Len*8.0),1.0,14.0);
     LookAt(C,F.P);
    End;
  Else Begin
     C.P.X:=F.P.X+F.F.X*Sp.EyeF+F.U.X*Sp.EyeU;
     C.P.Y:=F.P.Y+F.F.Y*Sp.EyeF+F.U.Y*Sp.EyeU;
     C.P.Z:=F.P.Z+F.F.Z*Sp.EyeF+F.U.Z*Sp.EyeU;
     C.F:=F.F; C.R:=F.R; C.U:=F.U;
    End;
 End;
End;

{ Ajoute un objet a la liste a trier }
Procedure AddObj(Kind,Idx:Integer;Dist:Real);
Begin
 If NObj>=MAX_OBJ Then Exit;
 ObjKind[NObj]:=Kind;
 ObjIdx[NObj]:=Idx;
 ObjDist[NObj]:=Dist;
 Inc(NObj);
End;

Procedure SortObjects;
Var
 I,J,K,Ix:Integer;
 Kd:Byte;
 D:Real;
Begin
 For I:=1 to NObj-1 do Begin
  Kd:=ObjKind[I]; Ix:=ObjIdx[I]; D:=ObjDist[I];
  J:=I-1;
  While(J>=0)and(ObjDist[J]<D)do Begin
   ObjKind[J+1]:=ObjKind[J];
   ObjIdx[J+1]:=ObjIdx[J];
   ObjDist[J+1]:=ObjDist[J];
   Dec(J);
  End;
  ObjKind[J+1]:=Kd; ObjIdx[J+1]:=Ix; ObjDist[J+1]:=D;
 End;
End;

Procedure CollectObjects(Const C:TCam;Var F:TFlt);
Var
 I:Integer;
 Q,V:TVec;
 D:Real;
Begin
 NObj:=0;
 InCloud:=False;
 For I:=0 to MAX_MTN-1 do Begin
  VSet(V,Mtns[I].X,Mtns[I].Y,0.0);
  ToCam(C,V,Q);
  D:=Sqrt(Q.X*Q.X+Q.Y*Q.Y+Q.Z*Q.Z);
  If(D<120000.0)and(Q.Z+Mtns[I].R>0.0)Then
   AddObj(OBJ_MTN,I,MaxR(0.0,D-0.7*Mtns[I].R));
 End;
 For I:=0 to NBld-1 do Begin
  VSet(V,Blds[I].X,Blds[I].Y,Blds[I].Z0+Blds[I].H/2.0);
  ToCam(C,V,Q);
  D:=Sqrt(Q.X*Q.X+Q.Y*Q.Y+Q.Z*Q.Z);
  If(D<18000.0)and(Q.Z>-Blds[I].W-Blds[I].D)Then AddObj(OBJ_BLD,I,D);
 End;
 For I:=0 to MAX_CLD-1 do Begin
  VSet(V,Clds[I].X,Clds[I].Y,Clds[I].Z);
  ToCam(C,V,Q);
  D:=Sqrt(Q.X*Q.X+Q.Y*Q.Y+Q.Z*Q.Z);
  If D<Clds[I].R*0.8 Then InCloud:=True;
  If(D<40000.0)and(Q.Z>-Clds[I].R)Then AddObj(OBJ_CLD,I,D);
 End;
 If ViewMode<>VIEW_COCKPIT Then Begin
  D:=Sqrt(Sqr(F.P.X-C.P.X)+Sqr(F.P.Y-C.P.Y)+Sqr(F.P.Z-C.P.Z));
  AddObj(OBJ_PLANE,0,D);
 End;
 SortObjects;
End;

{ Cadre du cockpit : tableau de bord }
Procedure DrawCockpitFrame;
Var
 P:Array[0..3] Of PointType;
Begin
 P[0].X:=0;   P[0].Y:=VIEW_H-22;
 P[1].X:=200; P[1].Y:=VIEW_H-30;
 P[2].X:=440; P[2].Y:=VIEW_H-30;
 P[3].X:=639; P[3].Y:=VIEW_H-22;
 SetFillStyle(SolidFill,DarkGray);
 SetColor(Black);
 Bar(0,VIEW_H-21,639,VIEW_H-1);
 FillPoly(4,P);
 SetColor(White);
 Line(320,VIEW_H-44,320,VIEW_H-34);
 Line(310,VIEW_H-39,330,VIEW_H-39);
End;

Procedure RenderScene(Var C:TCam;Var F:TFlt);
Var
 I,K:Integer;
Begin
 SetViewPort(0,0,SCR_W-1,VIEW_H-1,True);
 VX1:=0; VY1:=0; VX2:=SCR_W-1; VY2:=VIEW_H-1;
 DrawSky(C);
 DrawFields(C);
 DrawLakes(C);
 For I:=0 to NB_AIRPORT-1 do DrawAirport(C,I);
 CollectObjects(C,F);
 For K:=0 to NObj-1 do
  Case ObjKind[K] of
   OBJ_MTN:DrawMountain(C,ObjIdx[K]);
   OBJ_BLD:DrawBuilding(C,ObjIdx[K]);
   OBJ_CLD:DrawCloud(C,ObjIdx[K]);
   OBJ_PLANE:DrawPlane(C,F);
  End;
 If InCloud and(ViewMode=VIEW_COCKPIT)Then Begin
  If Night Then SetFillStyle(SolidFill,DarkGray)
           Else SetFillStyle(SolidFill,LightGray);
  Bar(0,0,SCR_W-1,VIEW_H-1);
 End;
 If ViewMode=VIEW_COCKPIT Then DrawCockpitFrame;
 SetViewPort(0,0,SCR_W-1,479,True);
End;

{ ------------------------------------------------------------------ }
{ Navigation                                                         }
{ ------------------------------------------------------------------ }

{ Distance, relevement et guidage ILS vers l'aeroport Ap }
Procedure ComputeNav(Var F:TFlt;Ap:Integer;Var Dist,Brg,LocDev,GsDev:Real;
                     Var Ils:Boolean);
Var
 DX,DY,A,B,S,AT,DD,Roff,DAim:Real;
Begin
 DX:=Aps[Ap].X-F.P.X;
 DY:=Aps[Ap].Y-F.P.Y;
 Dist:=Sqrt(DX*DX+DY*DY);
 Brg:=ATan2(DX,DY)*180.0/Pi;
 If Brg<0.0 Then Brg:=Brg+360.0;
 AirportLocal(Ap,F.P.X,F.P.Y,A,B);
 If A<0.0 Then S:=1.0 Else S:=-1.0;
 AT:=-S*Aps[Ap].Len/2.0;
 DD:=(AT-A)*S;
 If Aps[Ap].AxisX Then Roff:=-S*B Else Roff:=S*B;
 Ils:=False;
 LocDev:=0.0;
 GsDev:=0.0;
 If(DD>200.0)and(DD<30000.0)and(Abs(Roff)<DD*0.25)Then Begin
  Ils:=True;
  DAim:=DD+300.0;
  LocDev:=ArcTan(Roff/DD)*180.0/Pi;
  GsDev:=ArcTan(MaxR(F.P.Z,1.0)/DAim)*180.0/Pi-3.0;
 End;
End;

{ Avertissement le plus important (0 = aucun) }
Function CurrentWarning(Var F:TFlt):Integer;
Var
 Sp:TSpec;
 H1,H2,AGL:Real;
Begin
 CurrentWarning:=0;
 If F.Crashed Then Exit;
 Sp:=Specs[F.Spec];
 AGL:=F.P.Z-TerrainH(F.P.X,F.P.Y);
 If F.Fuel<=0.0 Then CurrentWarning:=W_NOFUEL;
 If(F.IAS>Sp.Vne)or((F.Mach>Sp.McritW+0.07)and(Sp.WaveK>0.3))Then
  CurrentWarning:=W_OVERSPD;
 If(F.GLoad>Sp.NLim)or(F.GLoad<-Sp.NLim*0.5)Then CurrentWarning:=W_OVERG;
 If Sp.Retract and(Not F.GearDn)and(AGL<250.0)and(F.V.Z<-1.0)and
    (F.Thr<0.4)and(Not F.OnGround)Then CurrentWarning:=W_GEAR;
 If Not F.OnGround Then Begin
  H1:=TerrainH(F.P.X+F.V.X*6.0,F.P.Y+F.V.Y*6.0);
  H2:=TerrainH(F.P.X+F.V.X*3.0,F.P.Y+F.V.Y*3.0);
  If((H1>60.0)and(F.P.Z+F.V.Z*6.0<H1+40.0))or
    ((H2>60.0)and(F.P.Z+F.V.Z*3.0<H2+30.0))or
    ((AGL<150.0)and(F.V.Z<-9.0))Then CurrentWarning:=W_PULLUP;
  If F.Stalled Then CurrentWarning:=W_STALL;
 End;
End;

{ ------------------------------------------------------------------ }
{ Instruments                                                        }
{ ------------------------------------------------------------------ }

Const
 PNL_Y  = 336;
 CY_I   = 392;       { centre vertical des cadrans }
 R_I    = 46;

Var
 LastTxt : Array[0..3] Of String;

Function InstChanged(Idx:Integer;Key:LongInt):Boolean;
Begin
 If InstKey[Idx]<>Key Then Begin
  InstKey[Idx]:=Key;
  InstChanged:=True;
 End
  Else InstChanged:=False;
End;

Procedure InvalidatePanel;
Var
 I:Integer;
Begin
 For I:=0 to 15 do InstKey[I]:=-99999;
 For I:=0 to 3 do LastTxt[I]:='';
End;

Procedure DrawPanelBackground;
Begin
 SetViewPort(0,0,SCR_W-1,479,True);
 SetFillStyle(SolidFill,Black);
 Bar(0,PNL_Y,SCR_W-1,479);
 SetColor(LightGray);
 Line(0,PNL_Y,SCR_W-1,PNL_Y);
 SetColor(DarkGray);
 Line(0,PNL_Y+1,SCR_W-1,PNL_Y+1);
 InvalidatePanel;
End;

Procedure PutText(X,Y:Integer;Const S:String;Col:Integer);
Begin
 SetColor(Col);
 OutTextXY(X,Y,S);
End;

Procedure PutTextC(CX,Y:Integer;Const S:String;Col:Integer);
Begin
 SetColor(Col);
 OutTextXY(CX-Length(S)*4,Y,S);
End;

{ Position sur un cadran : angle en degres depuis midi, sens horaire }
Procedure DialPt(CX,CY:Integer;Ang,Rad:Real;Var X,Y:Integer);
Begin
 X:=CX+Round(Rad*Sin(Ang*Pi/180.0));
 Y:=CY-Round(Rad*Cos(Ang*Pi/180.0));
End;

Procedure Needle(CX,CY:Integer;Ang,R1,R2:Real;Col:Integer);
Var
 X1,Y1,X2,Y2:Integer;
Begin
 DialPt(CX,CY,Ang,R1,X1,Y1);
 DialPt(CX,CY,Ang,R2,X2,Y2);
 SetColor(Col);
 Line(X1,Y1,X2,Y2);
End;

Procedure DialFace(CX:Integer);
Begin
 SetFillStyle(SolidFill,Black);
 Bar(CX-R_I-3,CY_I-R_I-3,CX+R_I+3,CY_I+R_I+3);
 SetColor(LightGray);
 Circle(CX,CY_I,R_I);
 SetColor(DarkGray);
 Circle(CX,CY_I,R_I+1);
End;

{ Arc colore sur un cadran (angles de cadran) }
Procedure DialArc(CX:Integer;A1,A2:Real;Col:Integer);
Var
 A:Real;
Begin
 A:=A1;
 While A<=A2 do Begin
  Needle(CX,CY_I,A,R_I-2,R_I-4,Col);
  A:=A+3.0;
 End;
End;

Function SpdAng(Kn:Real;Max:Integer):Real;
Begin
 SpdAng:=-135.0+270.0*Clamp(Kn/Max,0.0,1.05);
End;

{ Anemometre }
Procedure DrawASI(Var F:TFlt);
Var
 Sp:TSpec;
 CX,K,N:Integer;
 Spd,Vs1,Vs0,M:Real;
 S:String;
 X,Y:Integer;
Begin
 CX:=56;
 Sp:=Specs[F.Spec];
 Spd:=F.IAS*KT;
 If Not InstChanged(0,Round(Spd*2.0)+OptNight*100000)Then Exit;
 DialFace(CX);
 M:=Sp.Empty+F.Fuel;
 Vs1:=Sqrt(2.0*M*G0/(1.225*Sp.S*Sp.CLmax))*KT;
 Vs0:=Sqrt(2.0*M*G0/(1.225*Sp.S*Sp.CLmaxF))*KT;
 DialArc(CX,SpdAng(Vs1,Sp.VDial),SpdAng(Sp.Vne*KT*0.8,Sp.VDial),LightGreen);
 DialArc(CX,SpdAng(Sp.Vne*KT*0.8,Sp.VDial),SpdAng(Sp.Vne*KT,Sp.VDial),Yellow);
 If Sp.HasFlaps Then
  DialArc(CX,SpdAng(Vs0,Sp.VDial),SpdAng(Vs0*1.7,Sp.VDial),White);
 Needle(CX,CY_I,SpdAng(Sp.Vne*KT,Sp.VDial),R_I,R_I-8,LightRed);
 N:=Sp.VDial div 10;
 For K:=0 to 10 do Begin
  If K mod 2=0 Then Begin
   Needle(CX,CY_I,SpdAng(K*N,Sp.VDial),R_I-5,R_I-9,White);
   If Sp.VDial>=1000 Then Str(Round(K*N/100.0),S) Else Str(K*N,S);
   DialPt(CX,CY_I,SpdAng(K*N,Sp.VDial),R_I-17,X,Y);
   PutTextC(X,Y-4,S,White);
  End
   Else Needle(CX,CY_I,SpdAng(K*N,Sp.VDial),R_I-5,R_I-7,LightGray);
 End;
 Str(Round(Spd),S);
 PutTextC(CX,CY_I+14,S,LightCyan);
 If Sp.VDial>=1000 Then PutTextC(CX,CY_I+25,'kt x100',LightGray)
                  Else PutTextC(CX,CY_I+25,'kt',LightGray);
 Needle(CX,CY_I,SpdAng(Spd,Sp.VDial),0,R_I-7,White);
 SetFillStyle(SolidFill,LightGray);
 Bar(CX-1,CY_I-1,CX+1,CY_I+1);
End;

{ Horizon artificiel }
Procedure DrawAH(Var F:TFlt);
Const
 AX = 108;
 AY = 342;
 AS_ = 100;
Var
 Ps,Th,Ph,SR,CR,Dpx:Real;
 CXl,CYl,I,X1,Y1,X2,Y2:Integer;
 Pts:Array[0..3] Of PointType;
 HX,HY,DX,DY,NX,NY,Pp:Real;
 K:Integer;
Begin
 AxesToEuler(F.F,F.R,F.U,Ps,Th,Ph);
 If Not InstChanged(1,Round(Th*180.0/Pi*4.0)*1000+Round(Ph*180.0/Pi*2.0)+
                    OptNight*7)Then Exit;
 SetViewPort(AX,AY,AX+AS_,AY+AS_,True);
 CXl:=AS_ div 2; CYl:=AS_ div 2;
 SetFillStyle(SolidFill,LightBlue);
 Bar(0,0,AS_,AS_);
 { sol : demi-plan du cote "bas" }
 Dpx:=Th*180.0/Pi*1.8;
 SR:=Sin(Ph); CR:=Cos(Ph);
 DX:=CR; DY:=-SR;
 NX:=SR; NY:=CR;
 HX:=CXl+NX*Dpx; HY:=CYl+NY*Dpx;
 Pts[0].X:=Round(HX-DX*200.0); Pts[0].Y:=Round(HY-DY*200.0);
 Pts[1].X:=Round(HX+DX*200.0); Pts[1].Y:=Round(HY+DY*200.0);
 Pts[2].X:=Round(HX+DX*200.0+NX*200.0);
 Pts[2].Y:=Round(HY+DY*200.0+NY*200.0);
 Pts[3].X:=Round(HX-DX*200.0+NX*200.0);
 Pts[3].Y:=Round(HY-DY*200.0+NY*200.0);
 SetFillStyle(SolidFill,Brown);
 SetColor(Brown);
 FillPoly(4,Pts);
 SetColor(White);
 Line(Pts[0].X,Pts[0].Y,Pts[1].X,Pts[1].Y);
 { echelle de tangage }
 For K:=-3 to 3 do
  If K<>0 Then Begin
   Pp:=K*10.0;
   HX:=CXl+NX*(Th*180.0/Pi-Pp)*1.8;
   HY:=CYl+NY*(Th*180.0/Pi-Pp)*1.8;
   If Abs(K)=2 Then Dpx:=14.0 Else Dpx:=8.0;
   X1:=Round(HX-DX*Dpx); Y1:=Round(HY-DY*Dpx);
   X2:=Round(HX+DX*Dpx); Y2:=Round(HY+DY*Dpx);
   SetColor(White);
   Line(X1,Y1,X2,Y2);
  End;
 { repere d'inclinaison }
 For K:=-6 to 6 do Begin
  Pp:=K*10.0;
  If Abs(K)<=3 Then Begin
   X1:=CXl+Round(46.0*Sin(Pp*Pi/180.0));
   Y1:=CYl-Round(46.0*Cos(Pp*Pi/180.0));
   X2:=CXl+Round(41.0*Sin(Pp*Pi/180.0));
   Y2:=CYl-Round(41.0*Cos(Pp*Pi/180.0));
   SetColor(White);
   Line(X1,Y1,X2,Y2);
  End;
 End;
 X1:=CXl+Round(38.0*Sin(-Ph));
 Y1:=CYl-Round(38.0*Cos(-Ph));
 SetColor(Yellow);
 Line(X1,Y1,CXl+Round(32.0*Sin(-Ph-0.12)),CYl-Round(32.0*Cos(-Ph-0.12)));
 Line(X1,Y1,CXl+Round(32.0*Sin(-Ph+0.12)),CYl-Round(32.0*Cos(-Ph+0.12)));
 { avion fixe }
 SetColor(Yellow);
 Line(CXl-30,CYl,CXl-10,CYl);
 Line(CXl+10,CYl,CXl+30,CYl);
 Line(CXl-10,CYl,CXl-10,CYl+5);
 Line(CXl+10,CYl,CXl+10,CYl+5);
 SetFillStyle(SolidFill,Yellow);
 Bar(CXl-1,CYl-1,CXl+1,CYl+1);
 SetColor(LightGray);
 Rectangle(0,0,AS_,AS_);
 SetViewPort(0,0,SCR_W-1,479,True);
End;

{ Altimetre }
Procedure DrawALT(Var F:TFlt);
Var
 CX,K:Integer;
 Ft_:Real;
 S:String;
 X,Y:Integer;
Begin
 CX:=262;
 Ft_:=F.P.Z*FT;
 If Not InstChanged(2,Round(Ft_/5.0))Then Exit;
 DialFace(CX);
 For K:=0 to 49 do
  If K mod 5=0 Then Needle(CX,CY_I,K*7.2,R_I-2,R_I-8,White)
               Else Needle(CX,CY_I,K*7.2,R_I-2,R_I-5,LightGray);
 For K:=0 to 9 do Begin
  Str(K,S);
  DialPt(CX,CY_I,K*36.0,R_I-15,X,Y);
  PutTextC(X,Y-4,S,White);
 End;
 Str(Round(Ft_),S);
 PutTextC(CX,CY_I+14,S,LightCyan);
 PutTextC(CX,CY_I+25,'ft',LightGray);
 Needle(CX,CY_I,Frac(Ft_/10000.0)*360.0,0,R_I-24,LightGray);
 Needle(CX,CY_I,Frac(Ft_/1000.0)*360.0,0,R_I-6,White);
 SetFillStyle(SolidFill,LightGray);
 Bar(CX-1,CY_I-1,CX+1,CY_I+1);
End;

{ Conservateur de cap }
Procedure DrawHDG(Var F:TFlt);
Var
 CX,K,X,Y,X2,Y2:Integer;
 Hd,A,Dst,Brg,Loc,Gs:Real;
 S:String;
 Ils:Boolean;
Begin
 CX:=366;
 Hd:=HeadingDeg(F.F);
 ComputeNav(F,DestAp,Dst,Brg,Loc,Gs,Ils);
 If Not InstChanged(3,Round(Hd*2.0)*1000+Round(Brg)+Ord(F.AP)*300000+
                    Round(F.APHdg)*7)Then Exit;
 DialFace(CX);
 For K:=0 to 35 do Begin
  A:=K*10.0-Hd;
  If K mod 3=0 Then Begin
   Needle(CX,CY_I,A,R_I-2,R_I-8,White);
   If K=0 Then S:='N' Else If K=9 Then S:='E' Else
   If K=18 Then S:='S' Else If K=27 Then S:='W'
   Else Str(K,S);
   DialPt(CX,CY_I,A,R_I-17,X,Y);
   PutTextC(X,Y-4,S,White);
  End
   Else Needle(CX,CY_I,A,R_I-2,R_I-5,LightGray);
 End;
 { index de cap du pilote automatique }
 If F.AP Then Begin
  DialPt(CX,CY_I,F.APHdg-Hd-4.0,R_I+1,X,Y);
  DialPt(CX,CY_I,F.APHdg-Hd+4.0,R_I+1,X2,Y2);
  SetColor(LightCyan);
  Line(X,Y,X2,Y2);
  Needle(CX,CY_I,F.APHdg-Hd,R_I,R_I-6,LightCyan);
 End;
 { aiguille vers la destination }
 Needle(CX,CY_I,Brg-Hd,R_I-26,R_I-34,LightMagenta);
 Needle(CX,CY_I,Brg-Hd,0,R_I-34,LightMagenta);
 { cap numerique au centre }
 Str(Round(Hd),S);
 While Length(S)<3 do S:='0'+S;
 SetFillStyle(SolidFill,Black);
 Bar(CX-13,CY_I-6,CX+13,CY_I+6);
 SetColor(DarkGray);
 Rectangle(CX-13,CY_I-6,CX+13,CY_I+6);
 PutTextC(CX,CY_I-4,S,LightCyan);
 SetColor(Yellow);
 Line(CX,CY_I-R_I-3,CX-4,CY_I-R_I-9);
 Line(CX,CY_I-R_I-3,CX+4,CY_I-R_I-9);
End;

{ Variometre }
Procedure DrawVSI(Var F:TFlt);
Var
 Sp:TSpec;
 CX,K,X,Y,Sc:Integer;
 Vs,A,Ratio:Real;
 S:String;
Begin
 CX:=470;
 Sp:=Specs[F.Spec];
 Sc:=Sp.VSScale;
 If Sc<100 Then Sc:=2000;
 Vs:=F.V.Z*FT*60.0;
 If Not InstChanged(4,Round(Vs/20.0))Then Exit;
 DialFace(CX);
 For K:=-4 to 4 do Begin
  A:=-90.0+K/4.0*170.0;
  Needle(CX,CY_I,A,R_I-2,R_I-8,White);
  If(K<>0)and(K mod 2=0)Then Begin
   Ratio:=Abs(K)/4.0*Sc;
   If Sc>=1000 Then Str(Round(Ratio/1000.0),S) Else Str(Round(Ratio/100.0),S);
   DialPt(CX,CY_I,A,R_I-16,X,Y);
   PutTextC(X,Y-4,S,White);
  End;
 End;
 For K:=-8 to 8 do
  If K mod 2<>0 Then
   Needle(CX,CY_I,-90.0+K/8.0*170.0,R_I-2,R_I-5,LightGray);
 If Sc>=1000 Then PutTextC(CX,CY_I-26,'x1000',LightGray)
             Else PutTextC(CX,CY_I-26,'x100',LightGray);
 Str(Round(Vs/10.0)*10,S);
 PutTextC(CX,CY_I+14,S,LightCyan);
 PutTextC(CX,CY_I+25,'ft/min',LightGray);
 Needle(CX,CY_I,-90.0+Clamp(Vs,-Sc,Sc)/Sc*170.0,0,R_I-6,LightGreen);
 SetFillStyle(SolidFill,LightGray);
 Bar(CX-1,CY_I-1,CX+1,CY_I+1);
End;

Procedure VBarN(X:Integer;Frac_:Real;Col:Integer);
Var
 H:Integer;
Begin
 SetFillStyle(SolidFill,DarkGray);
 Bar(X,350,X+11,430);
 H:=Round(Clamp(Frac_,0.0,1.0)*78.0);
 SetFillStyle(SolidFill,Col);
 If H>0 Then Bar(X+1,429-H,X+10,429);
 SetColor(LightGray);
 Rectangle(X,350,X+11,430);
End;

Procedure VBar(X:Integer;Frac_:Real;Col:Integer;Const Lbl:String);
Var
 H:Integer;
Begin
 SetFillStyle(SolidFill,DarkGray);
 Bar(X,350,X+14,430);
 H:=Round(Clamp(Frac_,0.0,1.0)*78.0);
 SetFillStyle(SolidFill,Col);
 If H>0 Then Bar(X+1,429-H,X+13,429);
 SetColor(LightGray);
 Rectangle(X,350,X+14,430);
 SetFillStyle(SolidFill,Black);
 Bar(X-8,432,X+24,441);
 PutTextC(X+7,433,Copy(Lbl,1,4),LightGray);
End;

{ Manette, regime moteur (un par moteur, 4 au plus), carburant }
Procedure DrawBars(Var F:TFlt);
Var
 Sp:TSpec;
 Fu:Real;
 Col,N,I,X:Integer;
 L:String;
Begin
 Sp:=Specs[F.Spec];
 Fu:=F.Fuel/Sp.FuelCap;
 If Not InstChanged(5,Round(F.Thr*100.0)*100000+Round(F.Spool*100.0)*1000+
                    Round(Fu*100.0)*10+Ord(F.Fuel<=0.0))Then Exit;
 SetFillStyle(SolidFill,Black);
 Bar(520,340,SCR_W-1,445);
 N:=Sp.NEng;
 If N>4 Then N:=4;
 If N<1 Then N:=1;
 If Sp.Cat='G' Then Begin
  { planeur : seule la manette de remorquage }
  VBar(528,F.Thr,Yellow,Tr(L_TOW));
  Exit;
 End;
 Case Sp.Cat of
  'P':L:='RPM';
  'T':L:='TRQ';
  'R':L:='RKT';
  'C':L:='NR';
  'H':L:='PED';
  Else L:='N1';
 End;
 If Sp.Cat='H' Then Begin
  VBar(536,F.Thr,Yellow,Tr(L_THR));
  VBar(580,F.Fuel/Sp.FuelCap,LightCyan,Tr(L_STAM));
  Exit;
 End;
 VBar(522,F.Thr,Yellow,Tr(L_THR));
 For I:=0 to N-1 do Begin
  X:=544+I*17;
  If Sp.Cat='J' Then VBarN(X,F.Spool,LightGreen) Else
  If Sp.Cat='A' Then Begin
   If F.Spool>0.85 Then VBarN(X,F.Spool,LightRed)
                   Else VBarN(X,F.Spool,LightGreen);
  End
   Else VBarN(X,F.Spool,LightGreen);
 End;
 SetFillStyle(SolidFill,Black);
 Bar(544,432,544+N*17,441);
 PutText(544,433,L,LightGray);
 If Fu<0.1 Then Col:=LightRed Else Col:=LightCyan;
 VBar(616,Fu,Col,Tr(L_FUEL));
End;

Procedure Lamp(X,Y,W:Integer;Const S:String;On:Boolean;Col:Integer);
Begin
 If On Then Begin
  SetFillStyle(SolidFill,Col);
  Bar(X,Y,X+W,Y+9);
  PutText(X+4,Y+1,S,Black);
 End
  Else Begin
   SetFillStyle(SolidFill,Black);
   Bar(X,Y,X+W,Y+9);
   SetColor(DarkGray);
   Rectangle(X,Y,X+W,Y+9);
   PutText(X+4,Y+1,S,DarkGray);
  End;
End;

Procedure TextLine(Idx,Y:Integer;Const S:String;Col:Integer);
Var
 T:String;
Begin
 T:=S;
 While Length(T)<78 do T:=T+' ';
 If LastTxt[Idx]<>T Then Begin
  LastTxt[Idx]:=T;
  SetFillStyle(SolidFill,Black);
  Bar(0,Y,SCR_W-1,Y+8);
  PutText(6,Y,S,Col);
 End;
End;

Procedure DrawStatus(Var F:TFlt);
Var
 Sp:TSpec;
 W,Id:Integer;
 Dst,Brg,Loc,Gs:Real;
 Ils:Boolean;
 S,S2:String;
 Fl_,Gr:Boolean;
 Key:LongInt;
Begin
 Sp:=Specs[F.Spec];
 Id:=CurrentWarning(F);
 Fl_:=Odd(FrameNo div 6);
 Key:=Ord(F.GearDn)+2*Ord(F.GearPos>0.99)+4*F.Flaps+16*Ord(F.Brakes)+
      32*Ord(F.AP)+64*Ord(F.Assist)+128*Ord(Fl_)+256*Id+
      100000*Ord(F.Spool>0.85)+200000*Ord(F.Thr>0.0);
 If F.GearPos>0.01 Then Key:=Key+1000*Ord(F.GearPos<0.99);
 If InstChanged(6,Key)Then Begin
 
  If Not Sp.Retract Then Lamp(6,449,56,Tr(L_GEAR),True,LightGreen)
  Else If F.GearPos>=0.99 Then Lamp(6,449,56,Tr(L_GEAR),True,LightGreen)
  Else If F.GearPos<=0.01 Then Lamp(6,449,56,Tr(L_GEAR),False,0)
  Else Lamp(6,449,56,Tr(L_GEAR),Fl_,LightRed);
  If Sp.HasFlaps Then
   Lamp(68,449,76,Copy(Tr(L_FLAPS),1,5)+' '+IntStr(F.Flaps),F.Flaps>0,White)
  Else Lamp(68,449,76,Copy(Tr(L_FLAPS),1,5)+' -',False,0);
  Lamp(150,449,56,Tr(L_BRAKE),F.Brakes,Yellow);
  Lamp(212,449,28,Tr(L_AP),F.AP,LightCyan);
  Lamp(246,449,44,Tr(L_STAB),F.Assist,LightGreen);
  SetFillStyle(SolidFill,Black);
  Bar(296,447,SCR_W-1,458);
  If Sp.Ab Then Lamp(296,449,28,Tr(L_AB),F.Spool>0.85,LightRed);
  If Sp.Tow Then Lamp(296,449,52,Tr(L_TOW),F.Thr>0.0,Yellow);
  If Id<>0 Then Begin
   If Fl_ or(Id<>W_STALL)Then PutText(360,449,Tr(Id),LightRed);
  End;
 End;
 ComputeNav(F,DestAp,Dst,Brg,Loc,Gs,Ils);
 S:=Tr(L_DEST)+' '+Aps[DestAp].Code+'  '+Tr(L_DIST)+' '+
    RealStr(Dst/NMILE,1)+' NM  BRG '+PadZ(Round(Brg),3);
 If Ils Then S:=S+'  ILS '+RealStr(Loc,1)+' / '+RealStr(Gs,1);
 If F.AP Then
  S:=S+'   AP: '+PadZ(Round(F.APHdg),3)+' / '+IntStr(Round(F.APAlt*FT))+
     ' ft / '+IntStr(Round(F.APSpd*KT))+' kt';
 TextLine(0,459,S,LightMagenta);
 S:='GS '+IntStr(Round(Sqrt(F.V.X*F.V.X+F.V.Y*F.V.Y)*KT))+' kt   G '+
    RealStr(F.GLoad,1);
 If F.Mach>0.3 Then S:=S+'   MACH '+RealStr(F.Mach,2);
 S:=S+'   '+Tr(L_FUEL)+' '+IntStr(Round(F.Fuel))+' kg   ';
 Case ViewMode of
  VIEW_COCKPIT:S:=S+Tr(V_COCKPIT);
  VIEW_CHASE:S:=S+Tr(V_CHASE);
  VIEW_TOWER:S:=S+Tr(V_TOWER);
  Else S:=S+Tr(V_MAP);
 End;
 S:=S+'   '+Copy(Specs[F.Spec].Name,1,22)+'   '+
    PadZ(Trunc(F.FlightT) div 60,2)+':'+PadZ(Trunc(F.FlightT) mod 60,2);
 TextLine(1,469,S,LightGray);
End;

Procedure DrawPanel(Var F:TFlt);
Begin
 SetTextStyle(DefaultFont,HorizDir,1);
 DrawASI(F);
 DrawAH(F);
 DrawALT(F);
 DrawHDG(F);
 DrawVSI(F);
 DrawBars(F);
 DrawStatus(F);
End;

{ ------------------------------------------------------------------ }
{ Superpositions sur la vue 3D                                       }
{ ------------------------------------------------------------------ }

Procedure BigText(CX,Y:Integer;Const S:String;Size,Col:Integer);
Begin
 SetTextStyle(DefaultFont,HorizDir,Size);
 SetColor(Black);
 OutTextXY(CX-Length(S)*4*Size+Size,Y+Size,S);
 SetColor(Col);
 OutTextXY(CX-Length(S)*4*Size,Y,S);
 SetTextStyle(DefaultFont,HorizDir,1);
End;

{ Indicateur ILS dans le coin de la vue }
Procedure DrawILSBox(Var F:TFlt);
Var
 Dst,Brg,Loc,Gs:Real;
 Ils:Boolean;
 X0,Y0,X,Y:Integer;
Begin
 ComputeNav(F,DestAp,Dst,Brg,Loc,Gs,Ils);
 If Not Ils Then Exit;
 X0:=584; Y0:=8;
 SetFillStyle(SolidFill,Black);
 Bar(X0,Y0,X0+50,Y0+50);
 SetColor(LightGray);
 Rectangle(X0,Y0,X0+50,Y0+50);
 SetColor(DarkGray);
 Line(X0+25,Y0+2,X0+25,Y0+48);
 Line(X0+2,Y0+25,X0+48,Y0+25);
 X:=X0+25-Round(Clamp(Loc,-2.5,2.5)*9.0);
 Y:=Y0+25+Round(Clamp(Gs,-1.5,1.5)*14.0);
 SetColor(LightMagenta);
 Line(X,Y0+3,X,Y0+47);
 Line(X0+3,Y,X0+47,Y);
 PutTextC(X0+25,Y0+53,'ILS '+Aps[DestAp].Code,LightMagenta);
End;

Procedure DrawOverlay(Var F:TFlt);
Var
 Sp:TSpec;
 R:Integer;
Begin
 SetViewPort(0,0,SCR_W-1,479,True);
 SetTextStyle(DefaultFont,HorizDir,1);
 If ViewMode<>VIEW_MAP Then DrawILSBox(F);
 If F.Crashed Then Begin
  SetFillStyle(SolidFill,Red);
  Bar(120,80,520,190);
  SetColor(Yellow);
  Rectangle(122,82,518,188);
  BigText(320,92,Tr(C_TITLE),3,Yellow);
  BigText(320,132,Tr(F.CrashMsg),1,White);
  BigText(320,160,Tr(C_AGAIN),1,LightGray);
  Exit;
 End;
 If MsgTime>0.0 Then BigText(320,40,MsgText,1,MsgColor);
 If Paused Then BigText(320,150,Tr(W_PAUSE),3,White);
 If F.Belly Then BigText(320,60,Tr(C_BELLY),1,LightRed);
End;

{ ------------------------------------------------------------------ }
{ Carte                                                              }
{ ------------------------------------------------------------------ }

Procedure MapXY(Var F:TFlt;X,Y:Real;Var SX,SY:Integer);
Begin
 SX:=SCR_W div 2+Round((X-F.P.X)/MapZoom);
 SY:=VIEW_H div 2-Round((Y-F.P.Y)/MapZoom);
End;

Procedure DrawMap(Var F:TFlt);
Var
 I,K,X,Y,X2,Y2,Rx,Ry:Integer;
 Pts:Array[0..3] Of PointType;
 Hd,CH,SH,PX,PY:Real;
 Ex,Ey,Hl:Real;
Begin
 SetViewPort(0,0,SCR_W-1,VIEW_H-1,True);
 SetFillStyle(SolidFill,Green);
 Bar(0,0,SCR_W-1,VIEW_H-1);
 { lacs }
 SetFillStyle(SolidFill,Blue); SetColor(Blue);
 For I:=0 to MAX_LAKE-1 do Begin
  MapXY(F,Lakes[I].X,Lakes[I].Y,X,Y);
  FillEllipse(X,Y,Round(Lakes[I].RX/MapZoom)+1,Round(Lakes[I].RY/MapZoom)+1);
 End;
 { montagnes }
 For I:=0 to MAX_MTN-1 do Begin
  MapXY(F,Mtns[I].X,Mtns[I].Y,X,Y);
  Rx:=Round(Mtns[I].R/MapZoom)+1;
  SetFillStyle(SolidFill,Brown); SetColor(Brown);
  FillEllipse(X,Y,Rx,Rx);
  SetFillStyle(SolidFill,LightGray); SetColor(LightGray);
  FillEllipse(X,Y,Round(Rx*0.6),Round(Rx*0.6));
  If Mtns[I].H>1900.0 Then Begin
   SetFillStyle(SolidFill,White); SetColor(White);
   FillEllipse(X,Y,Round(Rx*0.25)+1,Round(Rx*0.25)+1);
  End;
 End;
 { villes }
 SetFillStyle(SolidFill,DarkGray);
 For I:=0 to NBld-1 do Begin
  MapXY(F,Blds[I].X,Blds[I].Y,X,Y);
  If(X>0)and(X<SCR_W-1)and(Y>0)and(Y<VIEW_H-1)Then Bar(X-1,Y-1,X+1,Y+1);
 End;
 { aeroports }
 SetTextStyle(DefaultFont,HorizDir,1);
 For I:=0 to NB_AIRPORT-1 do Begin
  MapXY(F,Aps[I].X,Aps[I].Y,X,Y);
  Hl:=Aps[I].Len/2.0/MapZoom;
  If Hl<4.0 Then Hl:=4.0;
  If Aps[I].AxisX Then Begin
   Ex:=Hl; Ey:=0.0;
  End
   Else Begin Ex:=0.0; Ey:=Hl; End;
  SetColor(Yellow);
  Line(X-Round(Ex),Y-Round(Ey),X+Round(Ex),Y+Round(Ey));
  Line(X-Round(Ex)+1,Y-Round(Ey)+1,X+Round(Ex)+1,Y+Round(Ey)+1);
  If I=DestAp Then Begin
   SetColor(LightMagenta);
   Circle(X,Y,10);
  End;
  PutText(X+12,Y-4,Aps[I].Code,White);
 End;
 { route vers la destination }
 MapXY(F,F.P.X,F.P.Y,X,Y);
 MapXY(F,Aps[DestAp].X,Aps[DestAp].Y,X2,Y2);
 SetColor(LightMagenta);
 SetLineStyle(DashedLn,0,NormWidth);
 Line(X,Y,X2,Y2);
 SetLineStyle(SolidLn,0,NormWidth);
 { avion }
 Hd:=ATan2(F.F.X,F.F.Y);
 CH:=Cos(Hd); SH:=Sin(Hd);
 Pts[0].X:=X+Round(10*SH);
 Pts[0].Y:=Y-Round(10*CH);
 Pts[1].X:=X+Round(-6*CH-7*SH);
 Pts[1].Y:=Y+Round(-6*SH+7*CH);
 Pts[2].X:=X+Round(-3*SH);
 Pts[2].Y:=Y+Round(3*CH);
 Pts[3].X:=X+Round(6*CH-7*SH);
 Pts[3].Y:=Y+Round(6*SH+7*CH);
 SetFillStyle(SolidFill,White);
 SetColor(Black);
 FillPoly(4,Pts);
 { echelle }
 SetFillStyle(SolidFill,Black);
 Bar(8,VIEW_H-22,128,VIEW_H-6);
 SetColor(White);
 Line(14,VIEW_H-12,14+Round(10000.0/MapZoom),VIEW_H-12);
 PutText(14,VIEW_H-20,'10 km',White);
 SetViewPort(0,0,SCR_W-1,479,True);
End;

{ ------------------------------------------------------------------ }
{ Menus                                                             }
{ ------------------------------------------------------------------ }

Procedure InitGraphicsMode;
Var
 Driver,Mode,Err:Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 Err:=GraphResult;
 If Err<>grOk Then Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(Err));
  Halt(1);
 End;
 SetTextStyle(DefaultFont,HorizDir,1);
End;

Procedure RotPt(CX,CY:Integer;X,Y,Ang,Sc:Real;Var P:PointType);
Begin
 P.X:=CX+Round((X*Cos(Ang)-Y*Sin(Ang))*Sc);
 P.Y:=CY+Round((X*Sin(Ang)+Y*Cos(Ang))*Sc);
End;

{ Silhouette d'avion vue de dessus }
Procedure DrawLogoPlane(CX,CY:Integer;Ang,Sc:Real;Col,Col2:Integer);
Var
 P:Array[0..7] Of PointType;
 K:Integer;
Begin
 SetFillStyle(SolidFill,Col);
 SetColor(Black);
 { ailes }
 RotPt(CX,CY,4,-6,Ang,Sc,P[0]);   RotPt(CX,CY,52,14,Ang,Sc,P[1]);
 RotPt(CX,CY,52,22,Ang,Sc,P[2]);  RotPt(CX,CY,4,16,Ang,Sc,P[3]);
 FillPoly(4,P);
 RotPt(CX,CY,-4,-6,Ang,Sc,P[0]);  RotPt(CX,CY,-52,14,Ang,Sc,P[1]);
 RotPt(CX,CY,-52,22,Ang,Sc,P[2]); RotPt(CX,CY,-4,16,Ang,Sc,P[3]);
 FillPoly(4,P);
 { empennage }
 RotPt(CX,CY,4,28,Ang,Sc,P[0]);   RotPt(CX,CY,20,36,Ang,Sc,P[1]);
 RotPt(CX,CY,20,40,Ang,Sc,P[2]);  RotPt(CX,CY,4,38,Ang,Sc,P[3]);
 FillPoly(4,P);
 RotPt(CX,CY,-4,28,Ang,Sc,P[0]);  RotPt(CX,CY,-20,36,Ang,Sc,P[1]);
 RotPt(CX,CY,-20,40,Ang,Sc,P[2]); RotPt(CX,CY,-4,38,Ang,Sc,P[3]);
 FillPoly(4,P);
 { fuselage }
 SetFillStyle(SolidFill,Col2);
 RotPt(CX,CY,0,-50,Ang,Sc,P[0]);  RotPt(CX,CY,8,-32,Ang,Sc,P[1]);
 RotPt(CX,CY,8,34,Ang,Sc,P[2]);   RotPt(CX,CY,0,46,Ang,Sc,P[3]);
 RotPt(CX,CY,-8,34,Ang,Sc,P[4]);  RotPt(CX,CY,-8,-32,Ang,Sc,P[5]);
 FillPoly(6,P);
End;

Procedure DrawTitleBackground;
Const
 Bands:Array[0..7] Of Integer=(Blue,Blue,LightBlue,LightBlue,Cyan,Cyan,
                               LightCyan,LightCyan);
Var
 I:Integer;
 P:Array[0..3] Of PointType;
Begin
 For I:=0 to 7 do Begin
  SetFillStyle(SolidFill,Bands[I]);
  Bar(0,I*40,SCR_W-1,I*40+40);
 End;
 SetFillStyle(SolidFill,Green);
 Bar(0,330,SCR_W-1,479);
 P[0].X:=312; P[0].Y:=330; P[1].X:=328; P[1].Y:=330;
 P[2].X:=560; P[2].Y:=479; P[3].X:=80;  P[3].Y:=479;
 SetFillStyle(SolidFill,DarkGray);
 SetColor(DarkGray);
 FillPoly(4,P);
 SetColor(White);
 For I:=0 to 5 do Begin
  Line(320,340+I*I*4+I*6,320,346+I*I*4+I*6+I*2);
  Line(321,340+I*I*4+I*6,321,346+I*I*4+I*6+I*2);
 End;
 DrawLogoPlane(520,95,0.45,1.2,LightGray,White);
End;

Procedure CenterBig(Y:Integer;Const S:String;Size,Col:Integer);
Begin
 SetTextStyle(DefaultFont,HorizDir,Size);
 SetColor(Black);
 OutTextXY((SCR_W-Length(S)*8*Size) div 2+Size,Y+Size,S);
 SetColor(Col);
 OutTextXY((SCR_W-Length(S)*8*Size) div 2,Y,S);
 SetTextStyle(DefaultFont,HorizDir,1);
End;

Function OnOff(V:Integer):String;
Begin
 If V<>0 Then OnOff:=Tr(M_ON) Else OnOff:=Tr(M_OFF);
End;

Function OptionText(Row:Integer):String;
Begin
 Case Row of
  0:OptionText:=Tr(M_AIRCRAFT)+' : '+Specs[SLOT_CUR].Name;
  1:OptionText:=Tr(M_AIRPORT)+' : '+Aps[OptAirport].Name+' ('+
                Aps[OptAirport].Code+')';
  2:Begin
     Case OptStart of
      0:OptionText:=Tr(M_START)+' : '+Tr(M_ST_RUNWAY);
      1:OptionText:=Tr(M_START)+' : '+Tr(M_ST_FINAL);
      Else OptionText:=Tr(M_START)+' : '+Tr(M_ST_CRUISE);
     End;
    End;
  3:Begin
     If OptNight=1 Then OptionText:=Tr(M_TIME)+' : '+Tr(M_NIGHT)
                   Else OptionText:=Tr(M_TIME)+' : '+Tr(M_DAY);
    End;
  4:Begin
     Case OptWind of
      0:OptionText:=Tr(M_WIND)+' : '+Tr(M_CALM);
      1:OptionText:=Tr(M_WIND)+' : '+Tr(M_LIGHT);
      Else OptionText:=Tr(M_WIND)+' : '+Tr(M_STRONG);
     End;
    End;
  5:Begin
     Case OptDetail of
      1:OptionText:=Tr(M_DETAIL)+' : '+Tr(M_LOW);
      2:OptionText:=Tr(M_DETAIL)+' : '+Tr(M_MED);
      Else OptionText:=Tr(M_DETAIL)+' : '+Tr(M_HIGH);
     End;
    End;
  6:OptionText:=Tr(M_ASSIST)+' : '+OnOff(OptAssist);
  7:OptionText:=Tr(M_FLY);
  Else OptionText:=Tr(M_QUIT);
 End;
End;

Procedure ChangeOption(Row,Dir:Integer);
Begin
 Case Row of
  0:Begin
     OptPlane:=(OptPlane+Dir+NAc)mod NAc;
     LoadAircraft(OptPlane);
    End;
  1:OptAirport:=(OptAirport+Dir+NB_AIRPORT)mod NB_AIRPORT;
  2:OptStart:=(OptStart+Dir+3)mod 3;
  3:OptNight:=1-OptNight;
  4:OptWind:=(OptWind+Dir+3)mod 3;
  5:Begin
     OptDetail:=OptDetail+Dir;
     If OptDetail<1 Then OptDetail:=3;
     If OptDetail>3 Then OptDetail:=1;
    End;
  6:OptAssist:=1-OptAssist;
 End;
End;

Procedure ShowHelp;
Var
 I:Integer;
 Ch:Char;
Begin
 SetViewPort(0,0,SCR_W-1,479,True);
 SetFillStyle(SolidFill,Black);
 Bar(0,0,SCR_W-1,479);
 SetColor(LightCyan);
 Rectangle(10,10,SCR_W-11,469);
 CenterBig(24,Tr(H_TITLE),3,Yellow);
 SetTextStyle(DefaultFont,HorizDir,1);
 For I:=0 to 8 do Begin
  SetColor(White);
  OutTextXY(36,100+I*28,Tr(H_1+I));
 End;
 SetColor(LightGreen);
 OutTextXY((SCR_W-Length(Tr(H_ANY))*8) div 2,430,Tr(H_ANY));
 Ch:=ReadKey;
 If Ch=#0 Then Ch:=ReadKey;
End;

Function CatMsg(C:Char):Integer;
Begin
 CatMsg:=K_P+Pos(C,'PTJARUGHC')-1;
End;

{ Lit uniquement le nom d'une fiche }
Function AcName(I:Integer):String;
Var
 T:Text;
 L:String;
 N:Integer;
Begin
 AcName:='';
 If AcFile[I][1]='*' Then Begin
  AcName:=Specs[Ord(AcFile[I][2])-48].Name;
  Exit;
 End;
 Assign(T,AcDir+AcFile[I]+'.FLT');
 {$I-}
 Reset(T);
 {$I+}
 If IOResult<>0 Then Exit;
 N:=0;
 While(Not Eof(T))and(N<8)do Begin
  ReadLn(T,L);
  Inc(N);
  If Copy(L,1,5)='NAME=' Then Begin
   AcName:=Copy(L,6,40);
   N:=99;
  End;
 End;
 Close(T);
End;

{ Texte coupe en lignes de largeur W (en caracteres) }
Procedure DrawWrap(X,Y,W,MaxL:Integer;Const S:String;Col:Integer);
Var
 L,Wd:String;
 P,N:Integer;
 T:String;
Begin
 T:=S+' ';
 L:='';
 N:=0;
 While(Length(T)>0)and(N<MaxL)do Begin
  P:=Pos(' ',T);
  Wd:=Copy(T,1,P-1);
  Delete(T,1,P);
  If(Length(L)+Length(Wd)+1>W)and(L<>'')Then Begin
   PutText(X,Y+N*10,L,Col);
   Inc(N);
   L:='';
  End;
  If L='' Then L:=Wd Else L:=L+' '+Wd;
 End;
 If(L<>'')and(N<MaxL)Then PutText(X,Y+N*10,L,Col);
End;

{ Liste des avions : choix du modele a piloter }
Function PickAircraft:Boolean;
Const
 ROWS = 18;
Var
 Sel,Top,I,Y,Old,L:Integer;
 Ch:Char;
 Done:Boolean;
 Sp:TSpec;
 S:String;
Begin
 Old:=OptPlane;
 Sel:=OptPlane;
 Top:=0;
 Done:=False;
 PickAircraft:=False;
 SetViewPort(0,0,SCR_W-1,479,True);
 SetTextStyle(DefaultFont,HorizDir,1);
 While Not Done do Begin
  If Sel<Top Then Top:=Sel;
  If Sel>=Top+ROWS Then Top:=Sel-ROWS+1;
  LoadAircraft(Sel);
  Sp:=Specs[SLOT_CUR];
  SetFillStyle(SolidFill,Black);
  Bar(0,0,SCR_W-1,479);
  SetColor(LightCyan);
  Rectangle(4,4,SCR_W-5,475);
  CenterBig(10,Tr(M_AIRCRAFT)+' ('+IntStr(Sel+1)+'/'+IntStr(NAc)+')',2,Yellow);
  For I:=Top to Top+ROWS-1 do
   If I<NAc Then Begin
    Y:=44+(I-Top)*21;
    If I=Sel Then Begin
     SetFillStyle(SolidFill,Blue);
     Bar(10,Y-3,400,Y+10);
     SetColor(White);
    End
     Else SetColor(LightGray);
    S:=AcFile[I];
    If S[1]='*' Then S:='';
    While Length(S)<9 do S:=S+' ';
    OutTextXY(14,Y,S+Copy(AcName(I),1,40));
   End;
  { barre de defilement }
  SetColor(DarkGray);
  Rectangle(404,40,410,420);
  SetFillStyle(SolidFill,LightGray);
  L:=Round(380.0*Sel/MaxR(1.0,NAc-1.0));
  Bar(405,40+L-3,409,40+L+3);
  { fiche technique }
  SetColor(LightCyan);
  Rectangle(418,40,SCR_W-12,420);
  DrawWrap(426,48,26,2,Sp.Name,Yellow);
  PutText(426,76,Tr(CatMsg(Sp.Cat)),LightGreen);
  PutText(426,98,Tr(D_ENG)+' : '+IntStr(Sp.NEng),White);
  PutText(426,112,Tr(D_VMAX)+' : '+IntStr(Round(Sp.VMaxKmh))+' km/h',White);
  PutText(426,126,Tr(D_MASS)+' : '+IntStr(Round(Sp.MTow))+' kg',White);
  PutText(426,140,Tr(D_SPAN)+' : '+RealStr(Sp.Span,1)+' m',White);
  PutText(426,154,Tr(D_LEN)+' : '+RealStr(Sp.Len,1)+' m',White);
  If Sp.Year>0 Then PutText(426,168,Tr(D_YEAR)+' : '+IntStr(Sp.Year),White);
  If Sp.Float Then PutText(426,182,'~~ '+Tr(T_WATER),LightCyan);
  DrawWrap(426,208,26,10,Sp.Desc,LightGray);
  SetColor(LightGreen);
  OutTextXY((SCR_W-Length(Tr(D_SELHINT))*8) div 2,440,Tr(D_SELHINT));
  Ch:=ReadKey;
  If Ch=#0 Then Begin
   Ch:=ReadKey;
   Case Ord(Ch) of
    72:If Sel>0 Then Dec(Sel);
    80:If Sel<NAc-1 Then Inc(Sel);
    73:Sel:=Sel-ROWS;
    81:Sel:=Sel+ROWS;
    71:Sel:=0;
    79:Sel:=NAc-1;
   End;
   If Sel<0 Then Sel:=0;
   If Sel>NAc-1 Then Sel:=NAc-1;
  End
   Else
  Case Ch of
   #13:Begin PickAircraft:=True; Done:=True; OptPlane:=Sel; End;
   #27:Begin Done:=True; OptPlane:=Old; End;
   Else Begin
    { saisie d'une lettre : saute au premier modele correspondant }
    For I:=1 to NAc do
     If(AcFile[(Sel+I)mod NAc][1]=UpCase(Ch))and
       (AcFile[Sel][1]<>'*')and(Done=False)Then Begin
      Sel:=(Sel+I)mod NAc;
      Done:=False;
      Break;
     End;
   End;
  End;
 End;
 LoadAircraft(OptPlane);
End;

{ Menu principal : retourne 1 pour voler, 0 pour quitter }
Function MainMenu:Integer;
Var
 Row,I,Y:Integer;
 Ch:Char;
 Done:Boolean;
 S:String;
Begin
 Row:=7;
 Done:=False;
 MainMenu:=0;
 NoSound;
 While Not Done do Begin
  SetViewPort(0,0,SCR_W-1,479,True);
  DrawTitleBackground;
  CenterBig(20,'FLIGHT',6,White);
  CenterBig(78,Tr(M_SUB),2,Yellow);
  SetFillStyle(SolidFill,Blue);
  Bar(20,142,SCR_W-21,402);
  SetColor(LightCyan);
  Rectangle(20,142,SCR_W-21,402);
  Rectangle(23,145,SCR_W-24,399);
  For I:=0 to 8 do Begin
   Y:=150+I*28;
   S:=OptionText(I);
   If Length(S)*16>SCR_W-70 Then SetTextStyle(DefaultFont,HorizDir,1)
                            Else SetTextStyle(DefaultFont,HorizDir,2);
   If I=Row Then Begin
    SetFillStyle(SolidFill,Yellow);
    Bar(30,Y-3,SCR_W-31,Y+19);
    SetColor(Black);
   End
    Else SetColor(White);
   If Length(S)*16>SCR_W-70 Then OutTextXY((SCR_W-Length(S)*8) div 2,Y+4,S)
                            Else OutTextXY((SCR_W-Length(S)*16) div 2,Y,S);
  End;
  SetTextStyle(DefaultFont,HorizDir,1);
  SetFillStyle(SolidFill,Black);
  Bar(0,406,SCR_W-1,479);
  If Row=0 Then Begin
   SetColor(Yellow);
   OutTextXY((SCR_W-Length(Tr(M_ACLIST))*8) div 2,416,Tr(M_ACLIST));
   SetColor(LightGray);
   OutTextXY((SCR_W-Length(Specs[SLOT_CUR].Desc)*8) div 2,432,
             Specs[SLOT_CUR].Desc);
  End;
  SetColor(LightGray);
  OutTextXY(6,466,Tr(M_NAVHINT));
  OutTextXY(SCR_W-6-Length(Tr(M_HELP))*8,466,Tr(M_HELP));
  Ch:=ReadKey;
  If Ch=#0 Then Begin
   Ch:=ReadKey;
   Case Ord(Ch) of
    72:Row:=(Row+8)mod 9;
    80:Row:=(Row+1)mod 9;
    75:ChangeOption(Row,-1);
    77:ChangeOption(Row,1);
    73:If Row=0 Then Begin
        OptPlane:=(OptPlane+NAc-10)mod NAc;
        LoadAircraft(OptPlane);
       End;
    81:If Row=0 Then Begin
        OptPlane:=(OptPlane+10)mod NAc;
        LoadAircraft(OptPlane);
       End;
    59:ShowHelp;
   End;
  End
   Else
  Case Ch of
   #13:Begin
        If Row=8 Then Begin MainMenu:=0; Done:=True; End
        Else If Row=7 Then Begin MainMenu:=1; Done:=True; End
        Else If Row=0 Then PickAircraft
        Else Begin
         ChangeOption(Row,1);
        End;
       End;
   #27:Begin MainMenu:=0; Done:=True; End;
   ' ':ChangeOption(Row,1);
   'h','H','?':ShowHelp;
  End;
 End;
End;

{ Menu pause : 0 reprendre, 1 menu principal, 2 quitter }
Function PauseMenu:Integer;
Var
 Row,I:Integer;
 Ch:Char;
 Done:Boolean;
 S:String;
Begin
 Row:=0;
 Done:=False;
 PauseMenu:=0;
 NoSound;
 SetViewPort(0,0,SCR_W-1,479,True);
 While Not Done do Begin
  SetFillStyle(SolidFill,Blue);
  Bar(150,110,490,230);
  SetColor(Yellow);
  Rectangle(152,112,488,228);
  SetTextStyle(DefaultFont,HorizDir,2);
  For I:=0 to 2 do Begin
   Case I of
    0:S:=Tr(P_RESUME);
    1:S:=Tr(P_MENU);
    Else S:=Tr(M_QUIT);
   End;
   If I=Row Then Begin
    SetFillStyle(SolidFill,LightBlue);
    Bar(160,128+I*32,480,128+I*32+22);
    SetColor(White);
   End
    Else SetColor(LightGray);
   OutTextXY(320-Length(S)*8,131+I*32,S);
  End;
  SetTextStyle(DefaultFont,HorizDir,1);
  Ch:=ReadKey;
  If Ch=#0 Then Begin
   Ch:=ReadKey;
   If Ord(Ch)=72 Then Row:=(Row+2)mod 3
   Else If Ord(Ch)=80 Then Row:=(Row+1)mod 3;
  End
   Else
  Case Ch of
   #13:Begin PauseMenu:=Row; Done:=True; End;
   #27:Begin PauseMenu:=0; Done:=True; End;
   '1':Begin PauseMenu:=0; Done:=True; End;
   '2':Begin PauseMenu:=1; Done:=True; End;
   '3':Begin PauseMenu:=2; Done:=True; End;
  End;
 End;
End;

{ ------------------------------------------------------------------ }
{ Commandes du clavier                                               }
{ ------------------------------------------------------------------ }

Procedure ToggleAP(Var F:TFlt);
Begin
 If F.OnGround or F.Crashed or(Specs[F.Spec].Cat='C')Then Exit;
 F.AP:=Not F.AP;
 If F.AP Then Begin
  F.APHdg:=Round(HeadingDeg(F.F)/5.0)*5.0;
  If F.APHdg>=360.0 Then F.APHdg:=0.0;
  F.APAlt:=Round(F.P.Z*FT/100.0)*100.0/FT;
  F.APSpd:=Sqrt(Sqr(F.V.X-Wind.X)+Sqr(F.V.Y-Wind.Y)+Sqr(F.V.Z-Wind.Z));
  SetMsg(Tr(W_APON),LightCyan,3.0);
 End
  Else Begin
   SetMsg(Tr(W_APOFF),LightCyan,3.0);
  End;
End;

{ Traite les touches. Retourne 0 = continuer, 1 = menu, 2 = quitter }
Function HandleKeys(Var F:TFlt):Integer;
Var
 Ch:Char;
 Sp:TSpec;
 Res,R:Integer;
Begin
 Res:=0;
 Sp:=Specs[F.Spec];
 While KeyPressed and(Res=0) do Begin
  Ch:=ReadKey;
  If Ch=#0 Then Begin
   Ch:=ReadKey;
   Case Ord(Ch) of
    72:If F.AP Then F.APAlt:=F.APAlt+30.48
       Else F.Elev:=Clamp(F.Elev-0.06,-1.0,1.0);
    80:If F.AP Then F.APAlt:=MaxR(100.0,F.APAlt-30.48)
       Else F.Elev:=Clamp(F.Elev+0.06,-1.0,1.0);
    75:If F.AP Then Begin
        F.APHdg:=F.APHdg-5.0;
        If F.APHdg<0.0 Then F.APHdg:=F.APHdg+360.0;
       End
       Else F.Ail:=Clamp(F.Ail-0.35,-1.0,1.0);
    77:If F.AP Then Begin
        F.APHdg:=F.APHdg+5.0;
        If F.APHdg>=360.0 Then F.APHdg:=F.APHdg-360.0;
       End
       Else F.Ail:=Clamp(F.Ail+0.35,-1.0,1.0);
    73:F.Thr:=Clamp(F.Thr+0.1,0.0,1.0);
    81:F.Thr:=Clamp(F.Thr-0.1,0.0,1.0);
    71:F.Thr:=1.0;
    79:F.Thr:=0.0;
    59:Begin ShowHelp; Paused:=False; DrawPanelBackground; End;
   End;
  End
   Else
  Case UpCase(Ch) of
   #27:Begin
        R:=PauseMenu;
        DrawPanelBackground;
        If R<>0 Then Res:=R;
       End;
   '+','=':If F.AP Then F.APSpd:=F.APSpd+2.5
           Else F.Thr:=Clamp(F.Thr+0.05,0.0,1.0);
   '-','_':If F.AP Then F.APSpd:=MaxR(30.0,F.APSpd-2.5)
           Else F.Thr:=Clamp(F.Thr-0.05,0.0,1.0);
   'Z',',':F.Rud:=Clamp(F.Rud-0.35,-1.0,1.0);
   'X','.':F.Rud:=Clamp(F.Rud+0.35,-1.0,1.0);
   ' ':Begin F.Elev:=0.0; F.Ail:=0.0; F.Rud:=0.0; End;
   'F':If Sp.HasFlaps and(F.Flaps<3)Then Inc(F.Flaps);
   'D':If Sp.HasFlaps and(F.Flaps>0)Then Dec(F.Flaps);
   'G':If Sp.Retract Then Begin
        If F.OnGround and F.GearDn Then Begin
         { on ne rentre pas le train au sol }
        End
         Else F.GearDn:=Not F.GearDn;
       End;
   'B':F.Brakes:=Not F.Brakes;
   'P':Paused:=Not Paused;
   'V':Begin
        ViewMode:=(ViewMode+1)mod 4;
       End;
   'M':If ViewMode=VIEW_MAP Then ViewMode:=VIEW_COCKPIT
       Else ViewMode:=VIEW_MAP;
   '[':MapZoom:=Clamp(MapZoom*0.7,20.0,1000.0);
   ']':MapZoom:=Clamp(MapZoom/0.7,20.0,1000.0);
   #9:DestAp:=(DestAp+1)mod NB_AIRPORT;
   'A':ToggleAP(F);
   'S':F.Assist:=Not F.Assist;
   'N':Night:=Not Night;
   'R':Begin SetupFlight(F); DrawPanelBackground; End;
   'H','?':Begin ShowHelp; DrawPanelBackground; End;
  End;
 End;
 HandleKeys:=Res;
End;

{ Son : alarme de decrochage }
Procedure UpdateSound(Var F:TFlt);
Var
 W:Integer;
 Want:Boolean;
Begin
 W:=CurrentWarning(F);
 Want:=(W<>0)and Odd(FrameNo div 4)and(Not Paused)and(Not F.Crashed);
 If Want and(Not SoundOn)Then Begin Sound(880); SoundOn:=True; End
 Else If(Not Want)and SoundOn Then Begin NoSound; SoundOn:=False; End;
End;

{ ------------------------------------------------------------------ }
{ Boucle de vol                                                      }
{ ------------------------------------------------------------------ }

Function FlyLoop:Integer;
Var
 T0,T1,Dt,Sub:Real;
 Res,N,I:Integer;
Begin
 SetupFlight(Fl);
 DrawPanelBackground;
 MapZoom:=250.0;
 T0:=NowSec;
 Res:=0;
 FlyLoop:=1;
 While Res=0 do Begin
  T1:=NowSec;
  Dt:=T1-T0;
  If Dt<0.0 Then Dt:=0.04;
  T0:=T1;
  Dt:=Clamp(Dt,0.001,0.1);
  Res:=HandleKeys(Fl);
  If Res<>0 Then Break;
  If Not Paused Then Begin
   If Fl.AP Then UpdateAutopilot(Fl,Dt);
   N:=Trunc(Dt/0.025)+1;
   Sub:=Dt/N;
   For I:=1 to N do StepPhysics(Fl,Sub);
   If Not Fl.AP Then Begin
    Fl.Ail:=Fl.Ail*Exp(-2.5*Dt);
    Fl.Rud:=Fl.Rud*Exp(-2.5*Dt);
   End;
   MsgTime:=MsgTime-Dt;
   If TouchedDown and(Not StopShown)and Fl.OnGround and(Not Fl.Crashed)and
      (Sqrt(Sqr(Fl.V.X)+Sqr(Fl.V.Y))<0.3)and(Fl.Thr<0.05)Then Begin
    StopShown:=True;
    SetMsg(Tr(T_STOP),LightGreen,6.0);
   End;
   If Fl.Crashed Then Fl.CrashT:=Fl.CrashT+Dt;
  End;
  BuildCamera(Cam,Fl);
  If ViewMode=VIEW_MAP Then DrawMap(Fl)
                       Else RenderScene(Cam,Fl);
  DrawOverlay(Fl);
  DrawPanel(Fl);
  UpdateSound(Fl);
  Inc(FrameNo);
  Delay(1);
 End;
 NoSound;
 SoundOn:=False;
 FlyLoop:=Res;
End;

{ ------------------------------------------------------------------ }
{ Point d'entree                                                     }
{ ------------------------------------------------------------------ }

Var
 Rc:Integer;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 DetectLanguage;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('FLIGHT - Cette commande permet de lancer un simulateur de vol ',
          '(clone de Flight Simulator).');
  WriteLn;
  WriteLn('Syntaxe : FLIGHT');
  WriteLn;
  WriteLn(' LANGUAGE=EN, GR, SP ou IT  Variable d''environnement pour ',
          'choisir la langue');
  Halt;
 End;
 InitSpecs;
 InitWorld;
 ScanAircraft;
 OptPlane:=0;
 For Rc:=0 to NAc-1 do
  If AcFile[Rc]='C172' Then OptPlane:=Rc;
 LoadAircraft(OptPlane);
 OptAirport:=0;
 OptStart:=0;
 OptNight:=0;
 OptWind:=0;
 OptDetail:=2;
 OptAssist:=1;
 MsgTime:=0.0;
 SoundOn:=False;
 InitGraphicsMode;
 Repeat
  If MainMenu=0 Then Rc:=2
                Else Rc:=FlyLoop;
 Until Rc=2;
 NoSound;
 CloseGraph;
END.
